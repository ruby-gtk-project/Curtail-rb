# frozen_string_literal: true

require_relative 'i18n'
require_relative 'tools'

module CurtailRb
  # One row in the results list: thumbnail, name, size, and whichever of the
  # spinner / skipped-info / error indicators applies. Upstream drove these
  # from GObject property bindings; here the row owns its item and `refresh`
  # pushes the current state into the widgets.
  class ResultItemRow
    include I18n

    THUMBNAIL_SIZE = 48


    attr_reader :item

    def initialize(item)
      @item = item
    end

    def build
      row.tap do |r|
        thumbnail.then do |image|
          if image
            r.add_prefix(image)
          end
        end

        r.add_suffix(skipped_info_button)
        r.add_suffix(error_info_button)
        r.add_suffix(savings_label)
        r.add_suffix(spinner)
        r.add_suffix(error_image)

        skipped_info_button.tap do |button|
          button.popover = skipped_popover

          skipped_popover.tap { |popover| popover.child = skipped_label }
        end

        error_info_button.tap do |button|
          button.popover = error_popover

          error_popover.tap { |popover| popover.child = error_popover_label }
        end

        refresh
      end
    end

    # Mirrors upstream's bindings: every widget that depended on a ResultItem
    # property is set from that property here.
    def refresh
      row.subtitle = @item.subtitle_label
      savings_label.label = @item.savings.to_s
      error_popover_label.label = @item.error_details_message.to_s
      spinner.visible = @item.running
      skipped_info_button.visible = @item.skipped
      error_image.visible = @item.error
      error_info_button.visible = @item.error_details
    end

    def row
      @row ||= Adwaita::ActionRow.new.tap do |r|
        r.title = @item.name.to_s
        r.tooltip_text = @item.new_filename.to_s
        r.subtitle = @item.subtitle_label.to_s
      end
    end

    # nil when the file is missing or gdk-pixbuf cannot decode it — an
    # unsupported-format row still has to render, just without a preview.
    def thumbnail
      @thumbnail ||= build_thumbnail
    end

    def build_thumbnail
      case @item.new_filename.to_s.empty?
      when true then nil
      else
        Tools.create_image_from_file(
          @item.filename,
          THUMBNAIL_SIZE,
          THUMBNAIL_SIZE,
        )
      end
    end

    def skipped_info_button
      @skipped_info_button ||= info_button
    end

    def error_info_button
      @error_info_button ||= info_button
    end

    def info_button
      Gtk::MenuButton.new.tap do |button|
        button.valign = :center
        button.tooltip_text = _('More Information')
        button.icon_name = 'info-outline-symbolic'
        button.visible = false
        button.add_css_class('flat')
      end
    end

    def skipped_popover = @skipped_popover ||= Gtk::Popover.new
    def error_popover = @error_popover ||= Gtk::Popover.new

    def skipped_label
      @skipped_label ||= popover_label.tap do |label|
        label.label = _(
          'Compression was skipped because compressing the file would have ' \
          'resulted in a larger file size.',
        )
      end
    end

    def error_popover_label = @error_popover_label ||= popover_label

    def popover_label
      Gtk::Label.new.tap do |label|
        label.halign = :center
        label.valign = :center
        label.margin_top = 6
        label.margin_bottom = 6
        label.margin_start = 6
        label.margin_end = 6
        label.max_width_chars = 50
        label.wrap = true
      end
    end

    def savings_label
      @savings_label ||= Gtk::Label.new.tap do |label|
        label.add_css_class('success')
      end
    end

    def spinner = @spinner ||= Adwaita::Spinner.new

    def error_image
      @error_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'x-circular-symbolic'
        image.visible = false
        image.add_css_class('error')
      end
    end
  end
end
