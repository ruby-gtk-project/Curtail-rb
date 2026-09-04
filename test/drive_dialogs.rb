# frozen_string_literal: true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
# dconf silently discards writes when its service is not reachable, which a
# headless run has no reason to have. The memory backend keeps them.
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/curtail_rb'
require_relative 'gtk_driver'

GtkDriver.drive(CurtailRb::Application.new, shots: 'tmp/shots') do |d, app|
  win = -> { app.window }
  settings = -> { app.settings }
  d.window { win.call.window }

  d.step('every menu action is registered') do
    CurtailRb::Window::ACTIONS.each_key do |name|
      d.check("win.#{name} exists") { win.call.window.lookup_action(name) }
    end
  end

  d.step('the accelerators upstream sets are set') do
    {
      # GTK normalises <Primary> to <Control> on the way in.
      'win.select-file' => '<Control>o',
      'win.preferences' => '<Control>comma',
      'win.quit'        => '<Control>q',
      'win.convert-dir' => '<Control>d',
    }.each do |action, accel|
      d.check("#{action} => #{accel}") do
        app.app.get_accels_for_action(action) == [accel]
      end
    end
  end

  d.step('open preferences') { win.call.window.activate_action('preferences') }

  d.step('the preferences sheet is up') do
    d.check('a dialog is showing') { !win.call.window.visible_dialog.nil? }
    d.shot('05-preferences')
  end

  d.step('safe mode off rewires the window') do
    win.call.instance_variable_get(:@prefs_dialog).then do |prefs|
      prefs.new_file_row.active = false
    end
  end

  d.step('subtitle, banner and the affix rows all followed') do
    d.check('setting written') { settings.call.new_file == false }
    d.check('subtitle says overwrite') do
      win.call.window_title.subtitle == 'Overwrite mode'
    end
    d.check('banner revealed') { win.call.warning_banner.revealed? }
    win.call.instance_variable_get(:@prefs_dialog).then do |prefs|
      d.check('naming mode row insensitive') { !prefs.naming_mode_row.sensitive? }
      d.check('affix row insensitive') { !prefs.suffix_prefix_row.sensitive? }
    end
    d.shot('06-preferences-overwrite')
  end

  d.step('a spin row writes its key') do
    win.call.instance_variable_get(:@prefs_dialog).png_lossy_row.value = 55
  end

  d.step('and it stuck') do
    d.check('png-lossy-level is 55') { settings.call.png_lossy_level == 55 }
  end

  d.step('the formats page has all four groups') do
    win.call.instance_variable_get(:@prefs_dialog).then do |prefs|
      d.check('png rows') { prefs.png_lossy_row && prefs.png_lossless_row }
      d.check('jpg rows') { prefs.jpg_lossy_row && prefs.jpg_progressive_row }
      d.check('webp rows') { prefs.webp_lossy_row && prefs.webp_lossless_row }
      d.check('svg row') { prefs.svg_maximum_row }
    end
    win.call.window.visible_dialog&.close
  end

  d.step('the banner button switches back to safe mode') do
    win.call.window.activate_action('banner-change-mode')
  end

  d.step('safe mode is back on') do
    d.check('setting written') { settings.call.new_file == true }
    d.check('banner hidden') { !win.call.warning_banner.revealed? }
    d.check('subtitle names the suffix') do
      win.call.window_title.subtitle == 'Safe mode with “-min” suffix'
    end
  end

  d.step('prefix mode renames the subtitle') do
    settings.call.naming_mode = 1
    win.call.set_saving_subtitle
  end

  d.step('subtitle says prefix') do
    d.check('prefix wording') do
      win.call.window_title.subtitle == 'Safe mode with “-min” prefix'
    end
    settings.call.naming_mode = 0
  end

  d.step('open the shortcuts window') { win.call.window.activate_action('shortcuts') }

  d.step('shortcuts is showing') do
    d.check('a dialog is showing') { !win.call.window.visible_dialog.nil? }
    # Assert against the items the SECTION holds, not a parallel set only the
    # test can see — the first version of this check passed while the visible
    # dialog was built from different, wrongly-constructed items.
    win.call.shortcuts_dialog
    section = win.call.shortcuts_section
    shown = (0...section.n_items).to_h do |i|
      section.get_item(i).then { |item| [item.action_name, item.accelerator] }
    end

    d.check('the section holds all four items') { shown.length == 4 }
    d.check('Select File shows its accelerator') do
      shown['win.select-file'] == '<Control>o'
    end
    d.check('Preferences shows its accelerator') do
      shown['win.preferences'] == '<Control>comma'
    end
    d.check('Quit shows its accelerator') do
      shown['win.quit'] == '<Control>q'
    end
    d.check('Keyboard Shortcuts shows its own') do
      shown['win.shortcuts'] == '<Control>question'
    end
    # The bug this replaces: the action name went in as the accelerator, so
    # every badge rendered blank.
    d.check('no action name leaked into an accelerator field') do
      shown.values.none? { |accel| accel.to_s.start_with?('win.') }
    end

    d.shot('07-shortcuts')
    win.call.window.visible_dialog&.close
  end

  d.step('open about') { win.call.window.activate_action('about') }

  d.step('about is showing, with the debug block filled in') do
    d.check('a dialog is showing') { !win.call.window.visible_dialog.nil? }
    d.check('debug info lists the tools') do
      win.call.about_dialog.debug_info.include?('Oxipng')
    end
    d.check('found real tool versions') do
      !win.call.about_dialog.debug_info.include?('Version not found')
    end
    d.shot('08-about')
    win.call.window.visible_dialog&.close
  end

  d.step('the bulk-directory warning asks before overwriting') do
    win.call.confirm_folders([Gio::File.new_for_path(Dir.tmpdir)])
  end

  d.step('the alert is up') do
    d.check('a dialog is showing') { !win.call.window.visible_dialog.nil? }
    d.shot('09-bulk-warning')
    win.call.window.visible_dialog&.close
  end

  d.step('the lossy toggle writes its setting') do
    win.call.toggle_lossy.active = 1
  end

  d.step('lossy is on') do
    d.check('active name is lossy') { win.call.toggle_lossy.active_name == 'lossy' }
    d.check('setting written') { settings.call.lossy == true }
    win.call.toggle_lossy.active = 0
    d.check('and back off') { settings.call.lossy == false }
  end
end
