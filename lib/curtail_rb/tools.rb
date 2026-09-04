# frozen_string_literal: true

require 'open3'

module CurtailRb
  # Upstream's tools.py: formatting, file-filter construction, thumbnails,
  # directory walking and the About dialog's debug block.
  module Tools
    module_function

    def sizeof_fmt(num) = GLib.format_size(num)

    # The five filters the Browse Files dialog offers, in upstream's order.
    FILTERS = [
      ['All images', %w[image/jpeg image/png image/webp image/svg+xml]],
      ['PNG images', %w[image/png]],
      ['JPEG images', %w[image/jpeg]],
      ['WebP images', %w[image/webp]],
      ['SVG images', %w[image/svg+xml]],
    ].freeze

    def add_filechooser_filters(dialog)
      dialog.filters = Gio::ListStore.new(Gtk::FileFilter).tap do |store|
        FILTERS.each do |name, mime_types|
          store.append(
            Gtk::FileFilter.new.tap do |filter|
                        filter.name = name
                        mime_types.each { |mime_type| filter.add_mime_type(mime_type) }
                      end,
          )
        end
      end
    end

    # A thumbnail scaled to fit max_width x max_height, aspect preserved.
    # Returns nil when the file is not something gdk-pixbuf can decode.
    def create_image_from_file(filename, max_width, max_height)
      pixbuf = load_pixbuf(filename)

      pixbuf.then do |pb|
        if pb
          scale_to_image(pb, max_width, max_height)
        end
      end
    end

    def load_pixbuf(filename)
      GdkPixbuf::Pixbuf.new(file: filename)
    rescue StandardError => e
      warn(e.to_s)
      nil
    end

    def scale_to_image(pixbuf, max_width, max_height)
      scaled_size(
        pixbuf.width,
        pixbuf.height,
        max_width,
        max_height,
      )
        .then do |new_width, new_height|
          Gtk::Image.new(
            pixbuf: pixbuf.scale_simple(new_width, new_height, :bilinear),
          ).tap do |image|
            image.pixel_size = [new_width, new_height].max
          end
        end
    end

    # Wider than tall scales to the width, otherwise to the height.
    def scaled_size(width, height, max_width, max_height)
      case width > height
      when true then [max_width, (height * (max_width / width.to_f)).to_i]
      else [(width * (max_height / height.to_f)).to_i, max_height]
      end
    end

    # Every non-directory child of `folder`, one level deep.
    def image_files_from_folder(folder)
      each_child(folder).reject { |_info, file| directory?(file) }
                        .map { |_info, file| file }
    end

    # …and the same walk, descending into subdirectories.
    def image_files_from_folder_recursive(folder)
      each_child(folder).flat_map do |_info, file|
        case directory?(file)
        when true then image_files_from_folder_recursive(file)
        else [file]
        end
      end
    end

    # The Ruby binding exposes a bare next_file cursor, not an Enumerable, so
    # the walk is spelled out.
    def each_child(folder)
      folder.enumerate_children('standard::name', :none).then do |enumerator|
        [].tap do |children|
          while (info = enumerator.next_file)
            children << [info, folder.get_child(info.name)]
          end
        end
      end
    end

    def directory?(file)
      file.query_file_type(:none) == Gio::FileType::DIRECTORY
    end

    NOT_FOUND = 'Version not found'

    # The external binaries Curtail drives, in the order the About dialog
    # lists them: label => the command that prints its version.
    VERSION_COMMANDS = {
      'Jpegoptim' => %w[jpegoptim --version],
      'Oxipng'    => %w[oxipng --version],
      'pngquant'  => %w[pngquant --version],
      'Libwebp'   => %w[cwebp -version],
      'Scour'     => %w[scour --version],
    }.freeze

    def debug_infos
      gtk_version = [
        Gtk::Version::MAJOR,
        Gtk::Version::MINOR,
        Gtk::Version::MICRO,
      ].join('.')

      versions = VERSION_COMMANDS.map do |label, command|
        "#{label}: #{tool_version(command)}\n"
      end

      "Ruby: #{RUBY_VERSION}\n\nGtk: #{gtk_version}\n\n#{versions.join("\n")}"
    end

    def tool_version(command)
      Open3.capture2e(*command).then do |output, status|
        case status.success?
        when true then extract_version(output)
        else NOT_FOUND
        end
      end
    rescue StandardError
      NOT_FOUND
    end

    # Three dot-separated groups of digits, the way upstream's regex reads it.
    def extract_version(text)
      text[/\d+\.\d+\.\d+/] || NOT_FOUND
    end
  end
end
