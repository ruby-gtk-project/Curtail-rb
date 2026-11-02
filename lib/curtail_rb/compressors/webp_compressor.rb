# frozen_string_literal: true

require_relative '../compressor'

module CurtailRb
  module Compressors
    # Ported from src/compressors/webp_compressor.py — cwebp takes its own
    # output flag, so there is no redirect, and lossless is a flag rather than
    # a separate binary.
    class WebpCompressor < Compressor
      def self.file_type = 'webp'

      def build_command(item)
        (+"cwebp #{quote(item.filename)}").tap do |command|
          # cwebp doesn't preserve any metadata by default.
          case settings.metadata
          when true then command << ' -metadata all'
          end

          quality(command).then do |level|
            # multithreaded, (lossless) compression mode, quality, output
            command << " -mt -m #{settings.webp_lossless_level}"
            command << " -q #{level}"
            command << " -o #{quote(item.tmp_filename)}"
          end
        end
      end

      private

        # Upstream decides the quality and appends `-lossless` in the same
        # branch, before the `-mt -m` group — hence the flag going onto the
        # command here rather than being returned alongside the number.
        def quality(command)
          case settings.lossy
          when true then settings.webp_lossy_level
          else
            command << ' -lossless'
            100 # maximum cpu power for lossless
          end
        end
    end
  end
end
