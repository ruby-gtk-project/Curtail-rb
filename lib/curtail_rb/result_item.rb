# frozen_string_literal: true

module CurtailRb
  # One row's worth of state: where the file is, how big it was, how big it
  # became, and how it went. Upstream made this a GObject so the row could
  # bind_property against it; here the row owns the item and refreshes itself,
  # so plain accessors do.
  class ResultItem
    attr_accessor :file,
      :mime_type,
      :name,
      :filename,
      :new_filename,
      :tmp_filename,
      :size,
      :new_size,
      :subtitle_label,
      :savings,
      :running,
      :skipped,
      :error,
      :error_message,
      :error_details,
      :error_details_message

    def initialize
      @name = ''
      @filename = ''
      @new_filename = ''
      @tmp_filename = ''
      @size = 0
      @new_size = 0
      @subtitle_label = +''
      @savings = ''
      @running = true
      @skipped = false
      @error = false
      @error_message = ''
      @error_details = false
      @error_details_message = ''
    end

    def to_s = @name.to_s

    def set_error(message)
      @error = true
      @error_message = message
    end
  end
end
