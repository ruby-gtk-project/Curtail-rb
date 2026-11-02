# frozen_string_literal: true

require_relative '../compressor'

module CurtailRb
  module Compressors
    # Ported from src/compressors/svg_compressor.py — scour has no lossy mode,
    # so the only switch is the "Maximum SVG Level" preference, which turns on
    # the transformations that can change the markup rather than just reformat
    # it.
    class SvgCompressor < Compressor
      def self.file_type = 'svg'

      def build_command(item)
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
    end
  end
end
