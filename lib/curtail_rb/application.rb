# frozen_string_literal: true

require_relative 'settings'
require_relative 'window'

module CurtailRb
  # Gtk::Application, not Adwaita::Application, which the Ruby bindings cannot
  # subclass or hand to a window. Adwaita is initialised explicitly instead,
  # which is what Adw.Application would otherwise have done on startup.
  class Application
    def initialize
      Adwaita.init
    end

    def build
      app.tap do |a|
        a.signal_connect('activate') do
          window.present
        end

        # HANDLES_OPEN: `curtail-rb image.png` compresses straight away.
        a.signal_connect('open') do |_, files, _hint|
          window.present
          window.compress_files(files.to_a)
        end
      end
    end

    def run(argv = ARGV)
      app.run([$PROGRAM_NAME, *argv])
    end

    def app
      @app ||= Gtk::Application.new(Window::APP_ID, :handles_open)
    end

    def window
      @window ||= Window.new(app, settings).tap(&:build)
    end

    def settings = @settings ||= Settings.new
  end
end
