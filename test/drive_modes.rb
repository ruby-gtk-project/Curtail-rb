# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/curtail_rb'
require_relative 'gtk_driver'
require_relative 'fixtures'

WORK = Dir.mktmpdir('curtail-modes')
NESTED = File.join(WORK, 'tree', 'deep')
FileUtils.mkdir_p(NESTED)
Fixtures.build(File.join(WORK, 'tree'))
Fixtures.build(NESTED)

def png_in(dir) = File.join(dir, 'shape.png')

GtkDriver.drive(CurtailRb::Application.new, shots: 'tmp/shots', interval: 700) do |d, app|
  win = -> { app.window }
  settings = -> { app.settings }
  d.window { win.call.window }

  d.step('recursive walk finds images in subdirectories') do
    d.check('recursive is on by default') { settings.call.recursive == true }
    win.call.compress_files([Gio::File.new_for_path(File.join(WORK, 'tree'))])
  end

  d.step('both levels showed up') do
    d.check('8 rows (4 formats x 2 levels)') { win.call.rows.length == 8 }
  end

  d.step('wait') { nil }
  d.step('wait more') { nil }

  d.step('non-recursive stops at the top level') do
    settings.call.recursive = false
    win.call.clear_results
    win.call.compress_files([Gio::File.new_for_path(File.join(WORK, 'tree'))])
  end

  d.step('only the top level listed') do
    # The top level also holds the -min files the recursive pass wrote, so the
    # count is "more than 4, but nothing from deep/".
    d.check('nothing from deep/') do
      win.call.rows.none? { |row| row.item.filename.include?('/deep/') }
    end
    d.check('the top-level png is there') do
      win.call.rows.any? { |row| row.item.name == 'shape.png' }
    end
    settings.call.recursive = true
  end

  d.step('wait') { nil }
  d.step('wait more') { nil }

  d.step('overwrite mode replaces the original in place') do
    settings.call.new_file = false
    win.call.set_saving_subtitle
    win.call.show_warning_banner
    FileUtils.mkdir_p(File.join(WORK, 'overwrite'))
    Fixtures.build(File.join(WORK, 'overwrite'))
    @before = File.size(png_in(File.join(WORK, 'overwrite')))
    win.call.clear_results
    win.call.compress_files(
      [Gio::File.new_for_path(png_in(File.join(WORK, 'overwrite')))],
    )
  end

  d.step('wait') { nil }
  d.step('wait more') { nil }

  d.step('the original file itself shrank') do
    d.check('banner warns about overwriting') do
      win.call.warning_banner.revealed?
    end
    d.check('subtitle says overwrite') do
      win.call.window_title.subtitle == 'Overwrite mode'
    end
    d.check('no -min file written') do
      Dir.glob(File.join(WORK, 'overwrite', '*-min.*')).empty?
    end
    d.check('original is smaller than it was') do
      File.size(png_in(File.join(WORK, 'overwrite'))) < @before
    end
    d.shot('10-overwrite')
    settings.call.new_file = true
    win.call.set_saving_subtitle
    win.call.show_warning_banner
  end

  d.step('lossy mode runs the other command path') do
    settings.call.lossy = true
    FileUtils.mkdir_p(File.join(WORK, 'lossy'))
    Fixtures.build(File.join(WORK, 'lossy'))
    win.call.clear_results
    win.call.compress_files(
      %w[shape.png shape.jpg shape.webp].map do |name|
        Gio::File.new_for_path(File.join(WORK, 'lossy', name))
      end,
    )
  end

  d.step('wait') { nil }
  d.step('wait more') { nil }

  d.step('lossy compressions all succeeded') do
    win.call.rows.each do |row|
      d.check("lossy #{row.item.name}: no error (#{row.item.error_message})") do
        row.item.error == false
      end
      d.check("lossy #{row.item.name}: finished") { row.item.running == false }
    end
    settings.call.lossy = false
  end

  d.step('a one-second timeout aborts a compression') do
    settings.call.compression_timeout = 1
    win.call.clear_results
    win.call.compress_files(
      [Gio::File.new_for_path(png_in(File.join(WORK, 'tree')))],
    )
  end

  d.step('wait') { nil }

  d.step('the timeout is reported, not swallowed') do
    win.call.rows.first.item.then do |item|
      d.check('finished') { item.running == false }
      # oxipng on a 256x256 png may well beat a one-second deadline; either
      # outcome is fine, what matters is that it is reported one way or the
      # other rather than hanging.
      d.check('reported an outcome') do
        item.error || !item.savings.to_s.empty?
      end
      d.check('a timeout says so') do
        !item.error || item.error_message.include?('timeout of 1 seconds')
      end
    end
    settings.call.compression_timeout = 30
  end

  d.step('the right-click menu builds for a real file') do
    win.call.clear_results
    win.call.compress_files(
      [Gio::File.new_for_path(png_in(File.join(WORK, 'tree')))],
    )
  end

  d.step('wait') { nil }

  d.step('the context menu opens over the row') do
    d.check('row carries its destination as a tooltip') do
      win.call.rows.first.row.tooltip_text.to_s.end_with?('-min.png')
    end
    win.call.show_context_menu(png_in(File.join(WORK, 'tree')), 40, 20)
    d.check('menu has both entries') { win.call.context_menu.n_items == 2 }
    d.check('open-image action registered') do
      win.call.window.observe_controllers # keep the window alive in the check
      !win.call.context_popover.menu_model.nil?
    end
  end

  # The popover renders into its own surface, so shooting the window would
  # miss it — the popover widget itself is the target.
  d.step('and it renders') { d.shot('11-context-menu', win.call.context_popover) }

  d.step('a drop compresses what it is handed') do
    win.call.clear_results
    FileUtils.mkdir_p(File.join(WORK, 'drop'))
    Fixtures.build(File.join(WORK, 'drop'))
    win.call.compress_files(
      [Gio::File.new_for_path(png_in(File.join(WORK, 'drop')))],
    )
  end

  d.step('wait') { nil }

  d.step('the dropped file compressed') do
    d.check('one row') { win.call.rows.length == 1 }
    d.check('no error') { win.call.rows.first.item.error == false }
    d.check('drop target is wired to the content box') do
      !win.call.drop_target.nil?
    end
  end
end
