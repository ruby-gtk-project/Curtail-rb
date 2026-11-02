# frozen_string_literal: true

require_relative '../compressor'

module CurtailRb
  module Compressors
    # Ported from src/compressors/jpeg_compressor.py — jpegoptim writes to
    # stdout, so the temp file is a shell redirect rather than an output flag,
    # and the quality cap is the only difference between the two paths.
    class JpegCompressor < Compressor
      LOSSY = 'jpegoptim --max=%s -o --stdout %s > %s'
      LOSSLESS = 'jpegoptim -o --stdout %s > %s'

      def self.file_type = 'jpeg'

      def build_command(item)
        case settings.lossy
        when true
          format(
            flags(LOSSY),
            settings.jpg_lossy_level,
            quote(item.filename),
            quote(item.tmp_filename),
          )
        else
          format(flags(LOSSLESS), quote(item.filename), quote(item.tmp_filename))
        end
      end

      private

        # Upstream appends the same three flag groups to both templates, so
        # they are applied here once, to whichever template is in play. They go
        # after the redirect, which is where upstream puts them too — the shell
        # takes the redirect wherever it appears in the line.
        def flags(template)
          (+template).tap do |command|
            case settings.jpg_progressive
            when true then command << ' --all-progressive'
            end

            case settings.metadata
            when false then command << ' --strip-all --keep-icc'
            end

            case settings.file_attributes
            when true then command << ' --preserve --preserve-perms'
            end
          end
        end
    end
  end
end
