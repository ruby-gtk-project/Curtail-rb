# frozen_string_literal: true

require_relative 'i18n'
require_relative 'result_item'
require_relative 'tools'

module CurtailRb
  # Turns a Gio::File into a ResultItem: reads its size and content type,
  # rejects what Curtail cannot compress, and works out the destination and
  # temp paths the compressors will write to.
  class ResultItemManager
    include I18n

    ALLOWED_MIME_TYPES = %w[
      image/jpeg
      image/png
      image/webp
      image/svg+xml
    ].freeze

    QUERY_ATTRIBUTES = [
      'standard::display-name',
      'standard::size',
      'standard::content-type',
      'xattr::document-portal.host-path',
    ].join(',').freeze

    def initialize(settings)
      @settings = settings
    end

    def build(file)
      ResultItem.new.tap do |item|
        item.file = file

        case file.query_exists
        when false then item.set_error(_("This file doesn't exist."))
        else populate(item, file)
        end
      end
    end


    def populate(item, file)
      file.query_info(QUERY_ATTRIBUTES, :none).then do |info|
        # Inside a Flatpak sandbox the portal path is the one the
        # compressors have to be handed; outside it the attribute is unset.
        item.filename = info.get_attribute_string(
          'xattr::document-portal.host-path',
        ) || file.path
        item.name = info.display_name || file.basename
        item.size = info.size
        item.mime_type = info.content_type

        case supported?(item)
        when false then item.set_error(_('Format of this file is not supported.'))
        else set_paths(item)
        end
      end
    end

    def supported?(item)
      ALLOWED_MIME_TYPES.include?(item.mime_type) && item.size.positive?
    end

    def set_paths(item)
      item.subtitle_label = +Tools.sizeof_fmt(item.size)
      item.new_filename = create_new_filename(item.filename)

      File.split(item.new_filename).then do |base_dir, fname|
        item.tmp_filename = File.join(base_dir, ".#{fname}.tmp")
      end
    end

    # Safe mode writes beside the original with the configured affix;
    # overwrite mode writes back over the original.
    def create_new_filename(path)
      case @settings.new_file
      when false then path
      else affixed_filename(path)
      end
    end

    def affixed_filename(path)
      File.dirname(path).then do |parent|
        File.extname(path).then do |extension|
          File.basename(path, extension).then do |stem|
            File.join(parent, affix(stem, extension))
          end
        end
      end
    end

    def affix(stem, extension)
      case @settings.naming_mode.zero?
      when true then "#{stem}#{@settings.suffix_prefix}#{extension}"
      else "#{@settings.suffix_prefix}#{stem}#{extension}"
      end
    end
  end
end
