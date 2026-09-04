# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/curtail_rb'
require_relative 'gtk_driver'
require_relative 'fixtures'

WORK = Dir.mktmpdir('curtail-drive')
FIXTURES = Fixtures.build(WORK)

GtkDriver.drive(CurtailRb::Application.new, shots: 'tmp/shots', interval: 700) do |d, app|
  win = -> { app.window }
  d.window { win.call.window }

  d.step('compress one of each format') do
    win.call.compress_files(FIXTURES.map { |p| Gio::File.new_for_path(p) })
  end

  d.step('results view took over') do
    d.check('results visible') { win.call.resultbox.visible? }
    d.check('home hidden') { !win.call.homebox.visible? }
    d.check('clear button shown') { win.call.clear_button.visible? }
    d.check('a row per file') { win.call.rows.length == FIXTURES.length }
  end

  d.step('wait for the compressors') { nil }
  d.step('still waiting') { nil }

  d.step('every row finished') do
    win.call.rows.each do |row|
      d.check("#{row.item.name}: not running") { row.item.running == false }
      d.check("#{row.item.name}: no error (#{row.item.error_message})") do
        row.item.error == false
      end
      d.check("#{row.item.name}: reported an outcome") do
        !row.item.savings.to_s.empty?
      end
    end
    d.check('controls re-enabled') { win.call.filechooser_button.sensitive? }
    d.shot('02-results')
  end

  d.step('safe mode wrote new files, originals untouched') do
    FIXTURES.each do |path|
      d.check("#{File.basename(path)}: original still there") do
        File.exist?(path)
      end
    end
    d.check('at least one -min file was written') do
      !Dir.glob(File.join(WORK, '*-min.*')).empty?
    end
    d.check('no .tmp files left behind') do
      Dir.glob(File.join(WORK, '.*.tmp')).empty?
    end
  end

  d.step('unsupported files report an error') do
    File.write(File.join(WORK, 'notes.txt'), 'not an image')
    win.call.clear_results
    win.call.compress_files([Gio::File.new_for_path(File.join(WORK, 'notes.txt'))])
  end

  d.step('the error row rendered') do
    win.call.rows.first.then do |row|
      d.check('marked as error') { row.item.error }
      d.check('says unsupported') do
        row.item.error_message == 'Format of this file is not supported.'
      end
      d.check('error icon visible') { row.error_image.visible? }
      d.check('spinner stopped') { !row.spinner.visible? }
    end
    d.shot('03-error-row')
  end

  d.step('a missing file reports its own error') do
    win.call.clear_results
    win.call.compress_files([Gio::File.new_for_path(File.join(WORK, 'nope.png'))])
  end

  d.step('missing-file row') do
    d.check('says it does not exist') do
      win.call.rows.first.item.error_message == "This file doesn't exist."
    end
  end

  d.step('a folder with no images toasts instead of showing results') do
    FileUtils.mkdir_p(File.join(WORK, 'empty'))
    win.call.clear_results
    win.call.compress_files([Gio::File.new_for_path(File.join(WORK, 'empty'))])
  end

  d.step('back to home, nothing listed') do
    d.check('no rows') { win.call.rows.empty? }
    d.check('home still showing') { win.call.homebox.visible? }
  end

  d.step('clear results empties the list') do
    win.call.compress_files([Gio::File.new_for_path(FIXTURES.first)])
  end

  d.step('and then clears') do
    d.check('one row') { win.call.rows.length == 1 }
    win.call.clear_results
    d.check('cleared') { win.call.rows.empty? }
    d.check('home visible again') { win.call.homebox.visible? }
    d.check('clear button hidden again') { !win.call.clear_button.visible? }
    d.shot('04-cleared')
  end
end
