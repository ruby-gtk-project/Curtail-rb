# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

module CurtailRb
  # Ported from data/ui/shortcuts-dialog.blp — upstream's one standalone
  # blueprint object, with no backing Python file: a single "General" section
  # listing the four window actions that carry an accelerator.
  #
  # Upstream's third item targets `app.shortcuts`, an action no upstream source
  # file installs, so the item is dead there. This port installs the action on
  # the window instead and points the item at `win.shortcuts`; the labels still
  # read as upstream's do.
  class ShortcutsDialog
    include I18n

    # The application is needed for nothing but the accelerators, which the
    # items render as badges.
    def initialize(app)
      @app = app
    end

    def build
      dialog.tap do |d|
        d.add(section)

        section.tap do |s|
          items.each_value { |item| s.add(item) }
        end
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    # Widgets

    def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

    def section
      @section ||= Adwaita::ShortcutsSection.new.tap do |s|
        s.title = p_('shortcuts dialog', 'General')
      end
    end

    # Keyed by action name so a test can ask what a given shortcut renders,
    # in the order upstream lists them. Spelled out rather than looped over a
    # table because rxgettext has no mark-only form of p_ — the context and
    # the message both have to be literals at the call site to reach the
    # template, which is also how upstream's blueprint lists them.
    def items
      @items ||= {
        'win.select-file' => item(
          p_('shortcuts dialog', 'Select File'),
          'win.select-file',
        ),
        'win.preferences' => item(
          p_('shortcuts dialog', 'Preferences'),
          'win.preferences',
        ),
        'win.shortcuts'   => item(
          p_('shortcuts dialog', 'Keyboard Shortcuts'),
          'win.shortcuts',
        ),
        'win.quit'        => item(
          p_('shortcuts dialog', 'Quit'),
          'win.quit',
        ),
      }
    end

    # Two things to work around. The two-argument constructor has two utf8
    # overloads — (title, accelerator) and (title, action_name) — and
    # introspection picks the accelerator one, so the action name goes in as a
    # property instead. And the badge that should resolve from the action's
    # accelerator comes out blank, so the accelerator is filled in explicitly
    # from the same place the action would have read it.
    def item(title, action_name)
      Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
        shortcut.action_name = action_name
        shortcut.accelerator = @app.get_accels_for_action(action_name).first.to_s
      end
    end
  end
end
