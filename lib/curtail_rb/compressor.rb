# frozen_string_literal: true

require 'open3'
require 'shellwords'

require_relative 'i18n'

module CurtailRb
  # Ported from src/compressor.py — the abstract base behind every format
  # compressor. A concrete compressor supplies two things and nothing else:
  # `self.file_type`, the key CompressionManager registers it under, and
  # `#build_command(item)`, the shell line that writes the item's temp file.
  # Everything here is the run they share — spawn the command under the
  # configured timeout, then adopt the temp file if it came out smaller than
  # the original.
  class Compressor
    include I18n

    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    # Called on a worker thread; `on_item` is handed back on the main loop
    # once the item is in its final state, exactly as upstream's
    # `GLib.idle_add(c_update_result_item, …)` does.
    def run(item, on_item)
      execute(build_command(item))
        .then { |failure| record_failure(item, failure) }

      case item.error
      when false then collect_output(item)
      end

      report(item, on_item)
    end

    private

      def report(item, on_item)
        GLib::Idle.add do
          on_item.call(item)
          false
        end
      end

      # Runs the shell pipeline the way upstream's subprocess call does — shell
      # true, because the PNG lossy path is two commands joined with `&&` and
      # jpegoptim writes through a `>` redirect. Returns nil on success, or the
      # [message, details] pair to record.
      def execute(command)
        Open3.popen2e(command) do |stdin, output, waiter|
          stdin.close
          wait(output, waiter)
        end
      rescue StandardError => e
        [_('An unknown error has occurred.'), escape(e.to_s)]
      end

      # Timeout.timeout would leave the compressor running in the background,
      # so the deadline is enforced by joining the wait thread and killing the
      # process when it does not finish in time.
      def wait(output, waiter)
        case waiter.join(settings.compression_timeout)
        when nil
          terminate(waiter)
          [timeout_message, nil]
        else finish(output, waiter)
        end
      end

      # The catalogues carry this one with a `{}` placeholder, so the number is
      # substituted after the lookup. Upstream interpolates first and then
      # looks the finished sentence up, which never matches — so upstream shows
      # this in English in every locale.
      def timeout_message
        _('Compression has reached the configured timeout of {} seconds.')
          .sub('{}', settings.compression_timeout.to_s)
      end

      def finish(output, waiter)
        output.read.then do |text|
          case waiter.value.success?
          when true then nil
          else [_('An unknown error has occurred.'), escape(text)]
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
      def collect_output(item)
        Gio::File.new_for_path(item.tmp_filename).then do |new_file|
          case new_file.query_exists
          when false
            item.error_message = _("Can't find the compressed file")
            item.error = true
          else
            adopt_output(item, new_file)
            new_file.delete
          end
        end
      end

      def adopt_output(item, new_file)
        item.new_size = new_file.query_info('standard::size', :none).size

        case item.new_size >= item.size
        when true then item.skipped = true
        else copy_over(item, new_file)
        end
      end

      def copy_over(item, new_file)
        new_file.copy(
          Gio::File.new_for_path(final_path(item)),
          Gio::FileCopyFlags::OVERWRITE | Gio::FileCopyFlags::ALL_METADATA,
        )
      end

      def final_path(item)
        case settings.new_file
        when true then item.new_filename
        else item.filename
        end
      end

      # HTML-escaped because the details popover renders Pango markup.
      def escape(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end

      # shlex.quote, as every upstream compressor uses on both paths.
      def quote(path) = Shellwords.escape(path)
  end
end
