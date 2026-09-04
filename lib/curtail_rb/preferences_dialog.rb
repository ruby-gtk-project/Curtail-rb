# frozen_string_literal: true

module CurtailRb
  # Curtail's two-page preferences sheet. Every row writes its GSettings key
  # straight through; the Safe Mode switch additionally re-syncs the window's
  # subtitle, its warning banner, and the two rows that only apply in safe mode.
  class PreferencesDialog
    NAMING_MODES = %w[Suffix Prefix].freeze

    def initialize(window, settings)
      @window = window
      @settings = settings
    end

    def build
      dialog.tap do |d|
        d.add(general_page)
        d.add(formats_page)

        general_page.tap { |page| page.add(general_group) }

        general_group.tap do |group|
          group.add(new_file_row)
          group.add(naming_mode_row)
          group.add(suffix_prefix_row)
          group.add(recursive_row)
          group.add(metadata_row)
          group.add(file_attributes_row)
          group.add(timeout_row)
        end

        formats_page.tap do |page|
          page.add(png_group)
          page.add(jpg_group)
          page.add(webp_group)
          page.add(svg_group)
        end

        png_group.tap do |group|
          group.add(png_lossy_row)
          group.add(png_lossless_row)
        end

        jpg_group.tap do |group|
          group.add(jpg_lossy_row)
          group.add(jpg_progressive_row)
        end

        webp_group.tap do |group|
          group.add(webp_lossy_row)
          group.add(webp_lossless_row)
        end

        svg_group.tap { |group| group.add(svg_maximum_row) }

        connect_signals
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def force_close
      dialog.force_close
    end


    def connect_signals
      new_file_row.signal_connect('notify::active') do
        @settings.write('new-file', new_file_row.active?)
        sync_safe_mode
      end

      naming_mode_row.signal_connect('notify::selected') do
        @settings.write('naming-mode', naming_mode_row.selected)
        reset_if_default('naming-mode', @settings.naming_mode.zero?)
        @window.set_saving_subtitle
      end

      suffix_prefix_row.signal_connect('changed') do
        @settings.write('suffix-prefix', suffix_prefix_row.text)
        reset_if_default('suffix-prefix', @settings.suffix_prefix.empty?)
        @window.set_saving_subtitle
      end

      switch_bindings.each do |row, key|
        row.signal_connect('notify::active') do
          @settings.write(key, row.active?)
        end
      end

      spin_bindings.each do |row, key|
        row.signal_connect('notify::value') do
          @settings.write(key, row.value.to_i)
        end
      end
    end

    # Upstream clears a key back to its schema default rather than storing
    # the empty/zero value, so a later default change still takes effect.
    def reset_if_default(key, default)
      case default
      when true then @settings.reset(key)
      end
    end

    def switch_bindings
      {
        recursive_row       => 'recursive',
        metadata_row        => 'metadata',
        file_attributes_row => 'file-attributes',
        jpg_progressive_row => 'jpg-progressive',
        svg_maximum_row     => 'svg-maximum-level',
      }
    end

    def spin_bindings
      {
        timeout_row       => 'compression-timeout',
        png_lossy_row     => 'png-lossy-level',
        png_lossless_row  => 'png-lossless-level',
        jpg_lossy_row     => 'jpg-lossy-level',
        webp_lossy_row    => 'webp-lossy-level',
        webp_lossless_row => 'webp-lossless-level',
      }
    end

    def sync_safe_mode
      @settings.new_file.then do |new_file|
        @window.set_saving_subtitle(new_file)
        @window.show_warning_banner(!new_file)
        naming_mode_row.sensitive = new_file
        suffix_prefix_row.sensitive = new_file
      end
    end

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |d|
        d.title = 'Preferences'
      end
    end

    def general_page
      @general_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.name = 'general'
        page.title = 'General'
        page.icon_name = 'applications-system-symbolic'
      end
    end

    def formats_page
      @formats_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.name = 'formats'
        page.title = 'Formats'
        page.icon_name = 'image-x-generic-symbolic'
      end
    end

    def general_group = @general_group ||= Adwaita::PreferencesGroup.new

    def png_group
      @png_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'PNG'
      end
    end

    def jpg_group
      @jpg_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'JPG'
      end
    end

    def webp_group
      @webp_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'WebP'
      end
    end

    def svg_group
      @svg_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'SVG'
      end
    end

    def new_file_row
      @new_file_row ||= switch_row(
        'Safe Mode',
        'Save the compressed image in a new file',
        @settings.new_file,
      )
    end

    def naming_mode_row
      @naming_mode_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = 'Naming Mode'
        row.subtitle = 'Select between suffix and prefix'
        row.model = Gtk::StringList.new(NAMING_MODES)
        row.selected = @settings.naming_mode
        row.sensitive = @settings.new_file
      end
    end

    def suffix_prefix_row
      @suffix_prefix_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = 'New File Suffix/Prefix'
        row.text = @settings.suffix_prefix
        row.sensitive = @settings.new_file
      end
    end

    def recursive_row
      @recursive_row ||= switch_row(
        'Recursive Compression',
        'Enable or disable compression through subdirectories',
        @settings.recursive,
      )
    end

    def metadata_row
      @metadata_row ||= switch_row(
        'Keep Metadata',
        'Keep metadata chunks that do not affect rendering',
        @settings.metadata,
      )
    end

    def file_attributes_row
      @file_attributes_row ||= switch_row(
        'Keep File Attributes When Possible',
        'Ensure the new file has the same permissions and timestamps as ' \
        'the original file',
        @settings.file_attributes,
      )
    end

    def jpg_progressive_row
      @jpg_progressive_row ||= switch_row(
        'Progressive Encode',
        'Enable incremental image rendering, going from blurry to clear',
        @settings.jpg_progressive,
      )
    end

    def svg_maximum_row
      @svg_maximum_row ||= switch_row(
        'Maximum Compression Level',
        'This can be more destructive for the image',
        @settings.svg_maximum_level,
      )
    end

    def timeout_row
      @timeout_row ||= spin_row(
        'Compression Timeout',
        'Set the timeout between images',
        Gtk::Adjustment.new(
          @settings.compression_timeout,
          1,
          300,
          1,
          10,
          0,
        ),
      )
    end

    def png_lossy_row
      @png_lossy_row ||= spin_row(
        'Lossy Compression',
        QUALITY_SUBTITLE,
        quality_adjustment(@settings.png_lossy_level),
      )
    end

    def png_lossless_row
      @png_lossless_row ||= spin_row(
        'Lossless Compression',
        LEVEL_SUBTITLE,
        level_adjustment(@settings.png_lossless_level),
      )
    end

    def jpg_lossy_row
      @jpg_lossy_row ||= spin_row(
        'Lossy Compression',
        QUALITY_SUBTITLE,
        quality_adjustment(@settings.jpg_lossy_level),
      )
    end

    def webp_lossy_row
      @webp_lossy_row ||= spin_row(
        'Lossy Compression',
        QUALITY_SUBTITLE,
        quality_adjustment(@settings.webp_lossy_level),
      )
    end

    def webp_lossless_row
      @webp_lossless_row ||= spin_row(
        'Lossless Compression',
        LEVEL_SUBTITLE,
        level_adjustment(@settings.webp_lossless_level),
      )
    end

    QUALITY_SUBTITLE =
      'Set the quality of the generated image, 100 is the best quality'

    LEVEL_SUBTITLE =
      'Set the level of compression, 6 is the highest but slowest level'

    def quality_adjustment(value)
      Gtk::Adjustment.new(
        value,
        0,
        100,
        1,
        10,
        0,
      )
    end

    def level_adjustment(value)
      Gtk::Adjustment.new(
        value,
        0,
        6,
        1,
        6,
        0,
      )
    end

    def switch_row(title, subtitle, active)
      Adwaita::SwitchRow.new.tap do |row|
        row.title = title
        row.subtitle = subtitle
        row.active = active
      end
    end

    def spin_row(title, subtitle, adjustment)
      Adwaita::SpinRow.new(adjustment, 1, 0).tap do |row|
        row.title = title
        row.subtitle = subtitle
      end
    end
  end
end
