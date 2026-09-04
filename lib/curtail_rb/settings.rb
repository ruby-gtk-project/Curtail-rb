# frozen_string_literal: true

module CurtailRb
  # Upstream's SettingsManager: one accessor pair per GSettings key. The
  # accessors are generated from the key table rather than hand-written, so a
  # new key in the gschema is one line here instead of six.
  class Settings
    SCHEMA_ID = 'com.github.huluti.Curtail.Rb'

    # GSettings key => the type suffix Gio::Settings uses for it.
    KEYS = {
      'new-file'            => :boolean,
      'naming-mode'         => :int,
      'recursive'           => :boolean,
      'metadata'            => :boolean,
      'file-attributes'     => :boolean,
      'lossy'               => :boolean,
      'suffix-prefix'       => :string,
      'png-lossy-level'     => :int,
      'png-lossless-level'  => :int,
      'jpg-lossy-level'     => :int,
      'webp-lossy-level'    => :int,
      'webp-lossless-level' => :int,
      'jpg-progressive'     => :boolean,
      'svg-maximum-level'   => :boolean,
      'compression-timeout' => :int,
    }.freeze

    KEYS.each do |key, type|
      name = key.tr('-', '_')

      define_method(name) { @settings.send("get_#{type}", key) }
      define_method("#{name}=") { |value| write(key, value) }
    end

    def initialize
      @settings = Gio::Settings.new(SCHEMA_ID)
    end

    def reset(key)
      @settings.reset(key)
    end

    # The dialog hands back the raw GSettings key, so writes go through one
    # entry point that looks the type up rather than four typed setters.
    def write(key, value)
      case KEYS.fetch(key)
      when :boolean then @settings.set_boolean(key, value ? true : false)
      when :int then @settings.set_int(key, value.to_i)
      when :string then @settings.set_string(key, value.to_s)
      end
    end
  end
end
