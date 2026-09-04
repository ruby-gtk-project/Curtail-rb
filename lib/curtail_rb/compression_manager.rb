# frozen_string_literal: true

require 'etc'
require_relative 'compressor'

module CurtailRb
  # Runs the compressions off the main loop, at most one per core, and reports
  # each one back on the main loop as it lands. Upstream registered compressor
  # classes into a dict keyed by file type; Compressor dispatches on mime type
  # itself, so this is just the pool.
  class CompressionManager
    def initialize(settings)
      @settings = settings
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
          Compressor.run(item, @settings)
          GLib::Idle.add do
            on_item.call(item)
            false
          end
        end
  end
end
