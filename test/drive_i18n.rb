# frozen_string_literal: true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'
# Set before the app is built, so every widget is created in this locale.
ENV['LANGUAGE'] = ENV.fetch('CURTAIL_TEST_LANG', 'fr')
ENV['LC_ALL'] = ENV['LANGUAGE']

require_relative '../lib/curtail_rb'
require_relative 'gtk_driver'

LANG = ENV.fetch('LANGUAGE')

# Ground truth read straight out of the .po, so the checks below hold for any
# language rather than encoding what one catalogue happens to cover. Written
# with its own throwaway scanner on purpose — asserting the app's parser
# against itself would prove nothing.
module Catalogue
  TEXT = File.read(
    File.join(
      __dir__,
      '..',
      'po',
      "#{LANG}.po",
    ),
  )

  module_function

  # msgid => msgstr for entries that are live, non-fuzzy, and actually
  # translated to something different.
  def active
    @active ||= TEXT.scan(/^msgid "([^"\n]+)"\nmsgstr "([^"\n]+)"$/)
                    .to_h
                    .reject { |msgid, msgstr| msgid == msgstr }
  end

  # Messages a translator retired with `#~` and that were not later revived.
  def obsolete
    @obsolete ||= TEXT.scan(/^#~ msgid "([^"\n]+)"$/).flatten.uniq -
                  active.keys
  end

  # The catalogue's translation, or nil when it has none — which is the
  # difference between "the app failed to translate" and "nothing to translate".
  def [](msgid) = active[msgid]
end

GtkDriver.drive(CurtailRb::Application.new, shots: 'tmp/shots') do |d, app|
  win = -> { app.window }
  d.window { win.call.window }

  # Assert a widget shows the catalogue's translation, and skip cleanly when
  # this language simply has not translated that message.
  translated = lambda do |msgid, description, &actual|
    Catalogue[msgid].then do |expected|
      case expected
      when nil then d.check("#{description} (no #{LANG} translation)") { true }
      else d.check(description) { actual.call == expected }
      end
    end
  end

  d.step("the catalogue for #{LANG} loaded") do
    d.check('locale resolved') { CurtailRb::I18n.language == LANG }
    d.check('catalogue is populated') do
      CurtailRb::I18n.catalogue.length > 50
    end
    d.check('the .po has entries to check against') { !Catalogue.active.empty? }
  end

  d.step('the home view shows the catalogue text') do
    translated.call('_Browse Files', 'browse button') do
      win.call.browse_button.label
    end
    translated.call('Drop images here to compress them', 'drop hint') do
      win.call.homebox.description
    end
    translated.call(
      'Images will be overwritten, proceed carefully',
      'warning banner',
    ) { win.call.warning_banner.title }
    translated.call('Lossless', 'lossless toggle') do
      win.call.lossless_toggle.label
    end

    d.check('the subtitle substituted the affix, leaving no placeholder') do
      win.call.window_title.subtitle.include?('-min') &&
        !win.call.window_title.subtitle.include?('{suffix_prefix}')
    end
    # Retired msgids carry translations of a differently-worded subtitle, some
    # with markup a WindowTitle would render literally.
    d.check('the subtitle never shows markup from a retired msgid') do
      !win.call.window_title.subtitle.include?('<b>')
    end
    d.shot("20-home-#{LANG}")
  end

  d.step('open preferences') { win.call.window.activate_action('preferences') }

  d.step('the preferences sheet shows the catalogue text') do
    win.call.instance_variable_get(:@prefs_dialog).then do |prefs|
      translated.call('Safe Mode', 'Safe Mode row') do
        prefs.new_file_row.title
      end
      translated.call(
        'Enable or disable compression through subdirectories',
        'a row subtitle',
      ) { prefs.recursive_row.subtitle }
      translated.call('Suffix', 'the naming-mode model') do
        prefs.naming_mode_row.model.get_string(0)
      end
      # Upstream leaves the four format group titles unmarked, so they are the
      # same in every language.
      d.check('format group titles stay untranslated, as upstream has them') do
        prefs.png_group.title == 'PNG'
      end
    end
    d.shot("21-preferences-#{LANG}")
    win.call.window.visible_dialog&.close
  end

  d.step('open shortcuts') { win.call.window.activate_action('shortcuts') }

  d.step('the shortcuts dialog uses the contextual translations') do
    win.call.shortcuts_section.then do |section|
      items = (0...section.n_items).map { |i| section.get_item(i) }

      d.check('four items') { items.length == 4 }
      d.check('accelerators survived translation') do
        items.map(&:accelerator).include?('<Control>o')
      end
      # C_("shortcuts dialog", "Select File") is a different key from a plain
      # "Select File", so it must resolve through the context, not around it.
      d.check('titles come from the shortcuts-dialog context') do
        items.first.title ==
          CurtailRb::I18n.p_('shortcuts dialog', 'Select File')
      end
    end
  end

  d.step('and the shortcuts dialog renders') do
    d.shot("22-shortcuts-#{LANG}")
    win.call.window.visible_dialog&.close
  end

  d.step('open about') { win.call.window.activate_action('about') }

  d.step('about carries this locale translator credits') do
    d.check('the gettext marker is never shown to the user') do
      win.call.about_dialog.translator_credits != 'translator-credits'
    end
    translated.call('Contributors', 'the contributors section heading') do
      CurtailRb::I18n._('Contributors')
    end
  end

  d.step('and the about dialog renders') do
    d.shot("23-about-#{LANG}")
    win.call.window.visible_dialog&.close
  end

  d.step('catalogue semantics') do
    Catalogue.active.first(3).each do |msgid, msgstr|
      d.check("active entry translates: #{msgid[0, 32]}") do
        CurtailRb::I18n._(msgid) == msgstr
      end
    end

    # gettext ignores entries a translator retired with `#~`, and so must this
    # parser — otherwise a stale translation outlives the message it described.
    Catalogue.obsolete.first(3).each do |msgid|
      d.check("obsolete entry ignored: #{msgid[0, 32]}") do
        CurtailRb::I18n._(msgid) == msgid
      end
    end

    d.check('the timeout message substitutes after looking up') do
      CurtailRb::Compressor.timeout_message(7).then do |message|
        message.include?('7') && !message.include?('{}')
      end
    end
  end
end
