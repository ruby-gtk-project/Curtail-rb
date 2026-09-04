# frozen_string_literal: true

require_relative 'compression_manager'
require_relative 'paths'
require_relative 'preferences_dialog'
require_relative 'result_item_manager'
require_relative 'result_item_row'
require_relative 'tools'

module CurtailRb
  # The main window: a header bar, an overwrite-mode warning banner, and three
  # mutually exclusive views (home, loading, results) stacked in a box the way
  # upstream's window.blp has them.
  class Window
    APP_ID = 'com.github.huluti.Curtail.Rb'

    ACTIONS = {
      'select-file'        => '<Primary>o',
      'clear-results'      => nil,
      'banner-change-mode' => nil,
      'preferences'        => '<Primary>comma',
      # GTK binds Ctrl+? to its own app.shortcuts action; upstream inherits
      # that from Adw.Application, which this port cannot use.
      'shortcuts'          => '<Primary>question',
      'about'              => nil,
      'quit'               => '<Primary>q',
      'convert-dir'        => '<Primary>d',
    }.freeze

    # The result rows, in the order they were added. Public so tests can see
    # what the list is showing without reaching through the ListBox.
    attr_reader :rows

    def initialize(app, settings)
      @app = app
      @settings = settings
      @rows = []
      @prefs_dialog = nil
      @manager = CompressionManager.new(settings)
      @result_item_manager = ResultItemManager.new(settings)
    end

    def build
      window.tap do |win|
        win.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = toolbar_view

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = mainbox

            header_bar.tap do |bar|
              bar.pack_start(filechooser_button)
              bar.pack_start(clear_button)
              bar.title_widget = window_title
              bar.pack_end(menu_button)
            end

            mainbox.tap do |box|
              box.append(warning_banner)
              box.append(homebox)
              box.append(loadingbox)
              box.append(resultbox)

              # Drops land anywhere over the content area, not just the home
              # page, which is why the target sits on the box and not on
              # homebox.
              box.add_controller(drop_target)

              drop_target.tap do |target|
                target.signal_connect('drop') do |_, value, _x, _y|
                  on_drop(value)
                end
              end

              homebox.tap do |page|
                page.child = homebox_content

                homebox_content.tap do |content|
                  content.append(browse_button)
                  content.append(toggle_lossy)

                  toggle_lossy.tap do |group|
                    group.add(lossless_toggle)
                    group.add(lossy_toggle)

                    group.signal_connect('notify::active-name') do
                      @settings.write('lossy', group.active_name == 'lossy')
                    end
                  end
                end
              end

              resultbox.tap do |scrolled|
                scrolled.child = clamp

                clamp.tap do |c|
                  c.child = listbox

                  # Right-click on a finished row offers Open Image and Show in
                  # Folder.
                  listbox.tap do |list|
                    list.add_controller(right_click)

                    right_click.signal_connect('pressed') do |_, _n, x, y|
                      on_results_right_click(x, y)
                    end
                  end
                end
              end
            end
          end
        end

        sync_lossy_toggle
        register_icons
        create_actions
        set_saving_subtitle
        show_warning_banner
        show_view(:home)
      end
    end

    def present
      window.present
    end

    # Called by the application when files arrive on the command line.
    def compress_files(files)
      handle_files(files).then do |resolved|
        case resolved.empty?
        when true then toast_overlay.add_toast(Adwaita::Toast.new('No files found'))
        else start_compression(resolved)
        end
      end
    end

    # Kept public because the preferences dialog re-syncs both when Safe Mode
    # is switched.
    def set_saving_subtitle(new_file = nil)
      window_title.subtitle = saving_subtitle(
        new_file.nil? ? @settings.new_file : new_file,
      )
    end

    def show_warning_banner(show = nil)
      if show.nil?
        warning_banner.revealed = !@settings.new_file
      else
        warning_banner.revealed = show
      end
    end


    def saving_subtitle(new_file)
      case new_file
      when false then 'Overwrite mode'
      else affix_subtitle
      end
    end

    def affix_subtitle
      @settings.suffix_prefix.then do |affix|
        case @settings.naming_mode.zero?
        when true then "Safe mode with “#{affix}” suffix"
        else "Safe mode with “#{affix}” prefix"
        end
      end
    end

    # Upstream ships two symbolic icons inside its GResource; this port
    # reads them off disk, so the theme needs the directory added. The default
    # icon name is what a window manager falls back to for the taskbar entry.
    def register_icons
      Gtk::Window.set_default_icon_name(APP_ID)
      Gtk::IconTheme.get_for_display(Gdk::Display.default)
                    .add_search_path(Paths.icon_dir)
    end

    def create_actions
      ACTIONS.each do |name, shortcut|
        window.add_action(
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { activate_action(name) }
          end,
        )

        shortcut.then do |accel|
          if accel
            @app.set_accels_for_action("win.#{name}", [accel])
          end
        end
      end
    end

    def activate_action(name)
      case name
      when 'select-file' then on_select
      when 'clear-results' then clear_results
      when 'banner-change-mode' then banner_change_mode
      when 'preferences' then on_preferences
      when 'shortcuts' then on_shortcuts
      when 'about' then on_about
      when 'quit' then @app.quit
      when 'convert-dir' then on_select_folder
      end
    end

    def enable_compression(enable)
      filechooser_button.sensitive = enable
      clear_button.sensitive = enable
    end

    def show_view(view)
      homebox.visible = view == :home
      loadingbox.visible = view == :loading
      resultbox.visible = view == :results
      clear_button.visible = view == :results
    end

    def clear_results
      show_view(:home)
      @rows.each { |row| listbox.remove(row.row) }
      @rows.clear
    end

    # The row's own view of its item, once the compressor is done with it.
    def update_result_item(item)
      item.running = false

      case
      when item.error then item.subtitle_label = item.error_message
      when item.skipped then item.savings = 'Skipped'
      else record_savings(item)
      end

      @rows.find { |row| row.item.equal?(item) }
           .then { |row| row&.refresh }
    end

    def record_savings(item)
      item.savings =
        "#{(100 - ((item.new_size * 100.0) / item.size)).round(2)}%"
      item.subtitle_label += " → #{Tools.sizeof_fmt(item.new_size)}"
    end

    def on_results_right_click(x, y)
      listbox.get_row_at_y(y)
             .then { |row| row&.tooltip_text }
             .then do |filename|
               if filename && File.exist?(filename)
                 show_context_menu(filename, x, y)
               end
             end
    end

    def show_context_menu(filename, x, y)
      window.insert_action_group(
        'context-menu',
        context_actions(filename),
      )

      context_popover.tap do |popover|
        popover.menu_model = context_menu
        popover.pointing_to = Gdk::Rectangle.new(
          x.to_i,
          y.to_i,
          1,
          1,
        )
        popover.set_offset(x.to_i, y.to_i)
        popover.has_arrow = false
        popover.unparent
        popover.parent = listbox
        popover.popup
      end
    end

    def context_actions(filename)
      Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(
          Gio::SimpleAction.new('open-image').tap do |action|
            action.signal_connect('activate') { xdg_open(filename) }
          end,
        )

        group.add_action(
          Gio::SimpleAction.new('open-folder').tap do |action|
            action.signal_connect('activate') do
              xdg_open(File.dirname(filename))
            end
          end,
        )
      end
    end

    def xdg_open(path)
      system('xdg-open', path)
    end

    def on_select
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = 'Browse Files'
        Tools.add_filechooser_filters(dialog)

        dialog.open_multiple(window) do |_, result|
          open_multiple_finished(dialog, result)
        end
      end
    end

    def open_multiple_finished(dialog, result)
      show_view(:loading)
      compress_files(dialog.open_multiple_finish(result).to_a)
    rescue StandardError => e
      warn("Could not open files: #{e.message}")
      show_view(@rows.empty? ? :home : :results)
    end

    def on_select_folder
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = 'Browse Directories'

        dialog.select_multiple_folders(window) do |_, result|
          select_folders_finished(dialog, result)
        end
      end
    end

    def select_folders_finished(dialog, result)
      dialog.select_multiple_folders_finish(result).to_a
            .then { |folders| confirm_folders(folders) }
    rescue StandardError => e
      warn("Could not open files: #{e.message}")
    end

    # Bulk-compressing directories is the one destructive-by-default path,
    # so it always asks first.
    def confirm_folders(folders)
      warning_dialog.tap do |dialog|
        dialog.signal_connect('response') do |_, response|
          if response == 'compress'
            show_view(:loading)
            compress_files(folders)
          end
        end

        dialog.present(window)
      end
    end

    def warning_dialog
      Adwaita::AlertDialog.new(
        'Are you sure you want to compress images in these directories?',
        warning_body,
      ).tap do |dialog|
        dialog.add_response('cancel', 'Cancel')
        dialog.add_response('compress', 'Compress')
        dialog.set_response_appearance('compress', warning_appearance)
      end
    end

    def warning_body
      case @settings.new_file
      when true
        'All of the images in the directories selected and their ' \
          'subdirectories will be compressed. The original images will ' \
          'not be modified.'
      else
        'All of the images in the directories selected and their ' \
          'subdirectories will be compressed and overwritten!'
      end
    end

    def warning_appearance
      case @settings.new_file
      when true then Adwaita::ResponseAppearance::SUGGESTED
      else Adwaita::ResponseAppearance::DESTRUCTIVE
      end
    end

    def on_drop(value)
      show_view(:loading)
      value.files.to_a.then do |files|
        case files.empty?
        when true then show_view(@rows.empty? ? :home : :results)
        else compress_files(files)
        end
      end
      true
    end

    # Directories expand to the images inside them; everything else is
    # taken as given and rejected later if it is not an image.
    def handle_files(files)
      files.flat_map do |file|
        case Tools.directory?(file)
        when true then folder_images(file)
        else [file]
        end
      end
    end

    def folder_images(folder)
      case @settings.recursive
      when true then Tools.image_files_from_folder_recursive(folder)
      else Tools.image_files_from_folder(folder)
      end
    end

    def start_compression(files)
      files.map { |file| add_row(@result_item_manager.build(file)) }
           .then { |items| begin_or_report(items) }
    end

    def add_row(item)
      ResultItemRow.new(item).tap do |row|
        @rows << row
        listbox.append(row.build)
      end.item
    end

    # Items that failed validation never reach a compressor; they just get
    # their row updated so the error shows immediately.
    def begin_or_report(items)
      show_view(:results)
      enable_compression(false)

      items.partition(&:error).then do |failed, pending|
        failed.each { |item| update_result_item(item) }

        @manager.compress(
          pending,
          method(:update_result_item),
          method(:enable_compression),
        )
      end
    end

    def banner_change_mode
      @settings.new_file = true
      show_warning_banner
      set_saving_subtitle
    end

    def on_preferences
      @prefs_dialog&.force_close

      PreferencesDialog.new(self, @settings).tap do |dialog|
        @prefs_dialog = dialog
        dialog.build
        dialog.present(window)
      end
    end

    def on_shortcuts
      shortcuts_dialog.present(window)
    end

    def on_about
      about_dialog.present(window)
    end

    # Widgets

    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = 'Curtail'
        win.icon_name = APP_ID
        win.set_default_size(650, 500)
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def window_title
      @window_title ||= Adwaita::WindowTitle.new('Curtail', '')
    end

    def filechooser_button
      @filechooser_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'document-open-symbolic'
        button.action_name = 'win.select-file'
        button.tooltip_text = 'Browse Files'
      end
    end

    def clear_button
      @clear_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'view-refresh-symbolic'
        button.action_name = 'win.clear-results'
        button.tooltip_text = 'Clear Results'
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.primary = true
        button.tooltip_text = 'Main Menu'
        button.menu_model = main_menu
      end
    end

    def main_menu
      @main_menu ||= Gio::Menu.new.tap do |menu|
        menu.append('Bulk Compress Directory', 'win.convert-dir')
        menu.append('Preferences', 'win.preferences')
        menu.append('Keyboard Shortcuts', 'win.shortcuts')
        menu.append('About Curtail', 'win.about')
      end
    end

    def mainbox = @mainbox ||= Gtk::Box.new(:vertical, 0)

    def warning_banner
      @warning_banner ||= Adwaita::Banner.new(
        'Images will be overwritten, proceed carefully',
      ).tap do |banner|
        banner.action_name = 'win.banner-change-mode'
        banner.button_label = '_Change Mode'
      end
    end

    def homebox
      @homebox ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
        page.icon_name = APP_ID
        page.title = 'Curtail'
        page.description = 'Drop images here to compress them'
        page.add_css_class('icon-dropshadow')
      end
    end

    def homebox_content
      @homebox_content ||= Gtk::Box.new(:vertical, 36)
    end

    def browse_button
      @browse_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Browse Files'
        button.use_underline = true
        button.halign = :center
        button.action_name = 'win.select-file'
        button.add_css_class('suggested-action')
        button.add_css_class('pill')
      end
    end

    def toggle_lossy
      @toggle_lossy ||= Adwaita::ToggleGroup.new.tap do |group|
        group.halign = :center
      end
    end

    # Set after the toggles are added, since the group has nothing to select
    # until then. Index 0 is Lossless, 1 is Lossy — the order they go in.
    def sync_lossy_toggle
      if @settings.lossy
        toggle_lossy.active = 1
      else
        toggle_lossy.active = 0
      end
    end

    def lossless_toggle
      @lossless_toggle ||= Adwaita::Toggle.new.tap do |toggle|
        toggle.label = 'Lossless'
        toggle.name = 'lossless'
      end
    end

    def lossy_toggle
      @lossy_toggle ||= Adwaita::Toggle.new.tap do |toggle|
        toggle.label = 'Lossy'
        toggle.name = 'lossy'
      end
    end

    def loadingbox
      @loadingbox ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
        page.title = 'Analyzing Images'
        page.description = 'Analyzing your images before compression…'
        page.paintable = Adwaita::SpinnerPaintable.new(page)
      end
    end

    def resultbox
      @resultbox ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.vexpand = true
        scrolled.hscrollbar_policy = :never
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |c|
        c.margin_start = 10
        c.margin_end = 10
        c.margin_top = 20
        c.margin_bottom = 20
      end
    end

    def listbox
      @listbox ||= Gtk::ListBox.new.tap do |box|
        box.hexpand = true
        box.valign = :start
        box.selection_mode = :none
        box.add_css_class('boxed-list')
      end
    end

    def drop_target
      @drop_target ||= Gtk::DropTarget.new(
        Gdk::FileList.gtype,
        Gdk::DragAction::COPY,
      )
    end

    def right_click
      @right_click ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = Gdk::BUTTON_SECONDARY
      end
    end

    def context_popover
      @context_popover ||= Gtk::PopoverMenu.new
    end

    def context_menu
      @context_menu ||= Gio::Menu.new.tap do |menu|
        menu.append('Open Image', 'context-menu.open-image')
        menu.append('Show in Folder', 'context-menu.open-folder')
      end
    end

    SHORTCUTS = [
      ['Select File', 'win.select-file'],
      ['Preferences', 'win.preferences'],
      ['Keyboard Shortcuts', 'win.shortcuts'],
      ['Quit', 'win.quit'],
    ].freeze

    def shortcuts_dialog
      @shortcuts_dialog ||= Adwaita::ShortcutsDialog.new.tap do |dialog|
        dialog.add(shortcuts_section)

        shortcuts_section.tap do |section|
          shortcuts_items.each_value { |item| section.add(item) }
        end
      end
    end

    # Two things to work around. The two-argument constructor has two utf8
    # overloads — (title, accelerator) and (title, action_name) — and
    # introspection picks the accelerator one, so the action name goes in as a
    # property instead. And the badge that should resolve from the action's
    # accelerator comes out blank, so the accelerator is filled in explicitly
    # from the same place the action would have read it.
    def shortcuts_item(title, action_name)
      Adwaita::ShortcutsItem.new(title, '').tap do |item|
        item.action_name = action_name
        item.accelerator = @app.get_accels_for_action(action_name).first.to_s
      end
    end

    # Keyed by action name so a test can ask what a given shortcut renders.
    def shortcuts_items
      @shortcuts_items ||= SHORTCUTS.to_h do |title, action_name|
        [action_name, shortcuts_item(title, action_name)]
      end
    end

    def shortcuts_section
      @shortcuts_section ||= Adwaita::ShortcutsSection.new.tap do |section|
        section.title = 'General'
      end
    end

    CONTRIBUTORS = [
      'Steven Teskey',
      'Andrey Kozlovskiy',
      'Balló György',
      'olokelo',
      'Archisman Panigrahi',
      'Maximiliano',
      'ARAKHNID',
    ].freeze

    def about_dialog
      @about_dialog ||= Adwaita::AboutDialog.new.tap do |about|
        about.application_name = 'Curtail'
        about.application_icon = APP_ID
        about.developer_name = 'Hugo Posnic'
        about.license_type = Gtk::License::GPL_3_0
        about.website = 'https://github.com/Huluti/Curtail'
        about.issue_url = 'https://github.com/Huluti/Curtail/issues/new'
        about.version = '1.16.2'
        about.developers = ['Hugo Posnic https://github.com/Huluti']
        about.designers = [
          'Jakub Steiner https://github.com/jimmac',
          'Tobias Bernard https://github.com/bertob',
        ]
        about.copyright = '© Hugo Posnic'
        about.add_credit_section('Contributors', CONTRIBUTORS)
        about.debug_info = Tools.debug_infos
      end
    end
  end
end
