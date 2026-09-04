# frozen_string_literal: true

require 'open3'
require 'shellwords'

module CurtailRb
  # Upstream has an abstract Compressor plus one subclass per format, each
  # supplying a `build_command`. The shared `run` is the only behaviour they
  # have, so here the four command builders are four methods on one module and
  # `run` dispatches on the item's mime type.
  module Compressor
    module_function

    def run(item, settings)
      execute(build_command(item, settings), settings)
        .then { |error| record_failure(item, error) }

      case item.error
      when false then collect_output(item, settings)
      end
    end

    # Runs the shell pipeline the way upstream's subprocess call does — shell
    # true, because the PNG lossy path is two commands joined with `&&` and
    # jpegoptim writes through a `>` redirect. Returns nil on success, or the
    # [message, details] pair to record.
    def execute(command, settings)
      Open3.popen2e(command) do |stdin, output, waiter|
        stdin.close
        wait(output, waiter, settings.compression_timeout)
      end
    rescue StandardError => e
      ['An unknown error has occurred.', escape(e.to_s)]
    end

    # Timeout.timeout would leave the compressor running in the background, so
    # the deadline is enforced by joining the wait thread and killing the whole
    # process group when it does not finish in time.
    def wait(output, waiter, timeout)
      case waiter.join(timeout)
      when nil
        terminate(waiter)
        ["Compression has reached the configured timeout of #{timeout} " \
         'seconds.', nil
]
      else finish(output, waiter)
      end
    end

    def finish(output, waiter)
      output.read.then do |text|
        case waiter.value.success?
        when true then nil
        else ['An unknown error has occurred.', escape(text)]
        end
      end
    end

    def terminate(waiter)
      Process.kill('KILL', waiter.pid)
      waiter.join
    rescue Errno::ESRCH
      nil
    end

    def record_failure(item, failure)
      failure.then do |message, details|
        if message
          warn(details || message)
          item.error_message = message
          item.error = true
          item.error_details = !details.nil?
          item.error_details_message = details.to_s
        end
      end
    end

    # The command wrote to a temp file. Keep it only if it actually came out
    # smaller, then move it into place and clean up either way.
    def collect_output(item, settings)
      Gio::File.new_for_path(item.tmp_filename).then do |new_file|
        case new_file.query_exists
        when false
          item.error_message = "Can't find the compressed file"
          item.error = true
        else
          adopt_output(item, new_file, settings)
          new_file.delete
        end
      end
    end

    def adopt_output(item, new_file, settings)
      item.new_size = new_file.query_info('standard::size', :none).size

      case item.new_size >= item.size
      when true then item.skipped = true
      else copy_over(item, new_file, settings)
      end
    end

    def copy_over(item, new_file, settings)
      if settings.new_file
        final_path = item.new_filename
      else
        final_path = item.filename
      end

      new_file.copy(
        Gio::File.new_for_path(final_path),
        Gio::FileCopyFlags::OVERWRITE | Gio::FileCopyFlags::ALL_METADATA,
      )
    end

    # HTML-escaped because the details popover renders Pango markup.
    def escape(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def build_command(item, settings)
      case item.mime_type
      when 'image/png' then png_command(item, settings)
      when 'image/jpeg' then jpeg_command(item, settings)
      when 'image/webp' then webp_command(item, settings)
      when 'image/svg+xml' then svg_command(item, settings)
      end
    end

    # PNG: oxipng alone for lossless, pngquant piped into oxipng for lossy.
    def png_command(item, settings)
      pngquant = +'pngquant --quality=0-%s -f %s --output %s'
      oxipng = +'oxipng -o %s -i 1 %s --out %s'

      case settings.metadata
      when false
        pngquant << ' --strip'
        oxipng << ' --strip safe'
      end

      case settings.file_attributes
      when true then oxipng << ' --preserve'
      end

      png_pipeline(
        item,
        settings,
        pngquant,
        oxipng,
      )
    end

    def png_pipeline(item, settings, pngquant, oxipng)
      lossless = format(
        oxipng,
        settings.png_lossless_level,
        quote(item.tmp_filename),
        quote(item.tmp_filename),
      )

      case settings.lossy
      when true
        [format(
          pngquant,
          settings.png_lossy_level,
          quote(item.filename),
          quote(item.tmp_filename),
        ), lossless
].join(' && ')
      else
        format(
          oxipng,
          settings.png_lossless_level,
          quote(item.filename),
          quote(item.tmp_filename),
        )
      end
    end

    # JPEG: jpegoptim writes to stdout, so the temp file is a shell redirect.
    def jpeg_command(item, settings)
      lossy = +'jpegoptim --max=%s -o --stdout %s > %s'
      lossless = +'jpegoptim -o --stdout %s > %s'

      case settings.jpg_progressive
      when true
        lossy << ' --all-progressive'
        lossless << ' --all-progressive'
      end

      case settings.metadata
      when false
        lossy << ' --strip-all --keep-icc'
        lossless << ' --strip-all --keep-icc'
      end

      case settings.file_attributes
      when true
        lossy << ' --preserve --preserve-perms'
        lossless << ' --preserve --preserve-perms'
      end

      jpeg_pipeline(
        item,
        settings,
        lossy,
        lossless,
      )
    end

    def jpeg_pipeline(item, settings, lossy, lossless)
      case settings.lossy
      when true
        format(
          lossy,
          settings.jpg_lossy_level,
          quote(item.filename),
          quote(item.tmp_filename),
        )
      else
        format(lossless, quote(item.filename), quote(item.tmp_filename))
      end
    end

    def webp_command(item, settings)
      command = +"cwebp #{quote(item.filename)}"

      # cwebp doesn't preserve any metadata by default.
      case settings.metadata
      when true then command << ' -metadata all'
      end

      quality = webp_quality(command, settings)

      # multithreaded, (lossless) compression mode, quality, output
      command << " -mt -m #{settings.webp_lossless_level}"
      command << " -q #{quality}"
      command << " -o #{quote(item.tmp_filename)}"
    end

    def webp_quality(command, settings)
      case settings.lossy
      when true then settings.webp_lossy_level
      else
        command << ' -lossless'
        100 # maximum cpu power for lossless
      end
    end

    def svg_command(item, settings)
      (+format(
        'scour -i %s -o %s',
        quote(item.filename),
        quote(item.tmp_filename),
      )).tap do |command|
        case settings.svg_maximum_level
        when true
          command << ' --enable-viewboxing --enable-id-stripping'
          command << ' --enable-comment-stripping --shorten-ids --indent=none'
        end
      end
    end

    def quote(path) = Shellwords.escape(path)
  end
end
