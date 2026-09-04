# frozen_string_literal: true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/curtail_rb'
require_relative 'gtk_driver'

GtkDriver.drive(CurtailRb::Application.new, shots: 'tmp/shots') do |d, app|
  d.window { app.window.window }

  d.step('the home view is showing') do
    d.check('window built') { !app.window.window.nil? }
    d.check('home visible') { app.window.homebox.visible? }
    d.check('loading hidden') { !app.window.loadingbox.visible? }
    d.check('results hidden') { !app.window.resultbox.visible? }
    d.check('clear button hidden') { !app.window.clear_button.visible? }
    d.shot('01-home')
  end
end
