# frozen_string_literal: true

require_relative '../compressor'

module CurtailRb
  module Compressors
    # Ported from src/compressors/png_compressor.py — oxipng alone for
    # lossless, pngquant feeding oxipng for lossy.
    class PngCompressor < Compressor
      PNGQUANT = 'pngquant --quality=0-%s -f %s --output %s'
      OXIPNG = 'oxipng -o %s -i 1 %s --out %s'

      def self.file_type = 'png'

      def build_command(item)
        case settings.lossy
        when true then lossy_pipeline(item)
        else lossless(item.filename, item.tmp_filename)
        end
      end

      private

        # pngquant writes the temp file, then oxipng rewrites it in place.
        def lossy_pipeline(item)
          [
            format(
              pngquant,
              settings.png_lossy_level,
              quote(item.filename),
              quote(item.tmp_filename),
            ),
            lossless(item.tmp_filename, item.tmp_filename),
          ].join(' && ')
        end

        def lossless(source, destination)
          format(
            oxipng,
            settings.png_lossless_level,
            quote(source),
            quote(destination),
          )
        end

        def pngquant
          case settings.metadata
          when false then "#{PNGQUANT} --strip"
          else PNGQUANT
          end
        end

        def oxipng
          (+OXIPNG).tap do |template|
            case settings.metadata
            when false then template << ' --strip safe'
            end

            case settings.file_attributes
            when true then template << ' --preserve'
            end
          end
        end
    end
  end
end
