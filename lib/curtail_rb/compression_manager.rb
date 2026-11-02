# frozen_string_literal: true

require 'etc'

require_relative 'compressor'

module CurtailRb
  # Ported from src/compression_manager.py — holds one instance of each
  # registered compressor, keyed by file type, and runs the queued items off
  # the main loop at most one per core. Each compressor reports its own item
  # back on the main loop; this reports only the "all done" at the end.
  class CompressionManager
    MIME_TYPES = {
      'image/jpeg'    => 'jpeg',
      'image/png'     => 'png',
      'image/webp'    => 'webp',
      'image/svg+xml' => 'svg',
    }.freeze

    # The registered instances, keyed by file type — public because that is
    # what upstream's `self.compressors` is.
    attr_reader :compressors

    def initialize(settings)
      @settings = settings
      @compressors = {}
    end

    def mime_type_to_compressor_type(mime_type) = MIME_TYPES[mime_type]

    # One instance per file type, built from the class and kept — upstream
    # registers the classes from the window and ignores a repeat registration.
    def register_compressor(compressor_class)
      compressor_class.file_type.then do |file_type|
        @compressors[file_type] ||= compressor_class.new(@settings)
      end
    end

    # Returns immediately; `on_item` fires per item and `on_finished` once,
    # both on the GTK main loop.
    def compress(items, on_item, on_finished)
      Thread.new do
        run_pool(items, on_item)
        GLib::Idle.add do
          on_finished.call(true)
          false
        end
      end
    end

    private

      def run_pool(items, on_item)
        Queue.new.tap do |queue|
          items.each { |item| queue << item }
          workers(queue, on_item).each(&:join)
        end
      end

      def workers(queue, on_item)
        Array.new([Etc.nprocessors, queue.size].min) do
          Thread.new do
            # `pop(true)` raises rather than blocking once the queue drains,
            # which is how each worker knows there is nothing left to take.
            loop do
              compress_one(queue.pop(true), on_item)
            rescue ThreadError
              break
            end
          end
        end
      end

      def compress_one(item, on_item)
        @compressors[mime_type_to_compressor_type(item.mime_type)]
          .run(item, on_item)
      end
  end
end
