# Curtail-rb component inventory

Survey of `origin/main` (upstream Curtail, Python/PyGObject/blueprint) against
`lib/` on `ruby` (this port). One row per upstream unit: its source file(s),
the `lib/*.rb` file it maps to, its kind, and whether the port already has it.

Upstream has no separate app-id for the port; the port renames resources to
`com.github.huluti.Curtail.Rb.*` (desktop entry, metainfo, icons, gschema),
which is noted per row rather than treated as a gap.

## Application

| Upstream | Port | Kind | Present? |
|---|---|---|---|
| `src/main.py` (`Application(Adw.Application)`, `do_startup`/`do_activate`/`do_open`) | `lib/curtail_rb/application.rb` | application class | Yes — `Gtk::Application` + explicit `Adwaita.init` (Ruby bindings can't subclass `Adw.Application`); `activate`/`open` signals cover `do_activate`/`do_open` |
| `src/curtail.in` (entry point: locale/gettext bootstrap, gresource load, `main.main`) | `bin/curtail-rb` | entry point | Yes |

## Main window — `src/window.py` + `data/ui/window.blp`

One unit: `Adw.ApplicationWindow` template plus its backing class.

| Upstream element | Port (`lib/curtail_rb/window.rb`) | Kind | Present? |
|---|---|---|---|
| `headerbar` (`Adw.HeaderBar`) | `header_bar` | widget | Yes |
| `filechooser_button_headerbar` (`win.select-file`, tooltip "Browse Files") | `filechooser_button` | widget/action target | Yes |
| `clear_button_headerbar` (`win.clear-results`, tooltip "Clear Results") | `clear_button` | widget/action target | Yes |
| `window_title` (`Adw.WindowTitle`) | `window_title` | widget | Yes |
| menu button (`open-menu-symbolic`, `primary: true`, `main_menu`) | `menu_button` | widget | Yes |
| `main_menu` (`Gio.Menu`: Bulk Compress Directory, Preferences, Keyboard Shortcuts, About Curtail) | `main_menu` | menu model | Yes, with one binding difference: "Keyboard Shortcuts" is wired to `win.shortcuts` (upstream: `app.shortcuts`) — deliberate, since GTK reserves `app.shortcuts`'s accelerator; same label and position |
| `warning_banner` (`Adw.Banner`, `win.banner-change-mode`, "_Change Mode") | `warning_banner` | widget/action target | Yes |
| `homebox` (`Adw.StatusPage`, icon `com.github.huluti.Curtail`, css `icon-dropshadow`) | `homebox` | widget | Yes (icon name follows the port's own app id) |
| browse button inside homebox (`win.select-file`, css `suggested-action pill`) | `browse_button` | widget/action target | Yes |
| `toggle_lossy` (`Adw.ToggleGroup`: Lossless/Lossy toggles) | `toggle_lossy`, `lossless_toggle`, `lossy_toggle` | widget | Yes |
| `loadingbox` (`Adw.StatusPage` + `Adw.SpinnerPaintable`) | `loadingbox` | widget | Yes |
| `resultbox` → `Adw.Clamp` → `listbox` (`Gtk.ListBox`, css `boxed-list`, bound to `results_model`) | `resultbox`, `clamp`, `listbox` | widget | Yes |
| `mainbox` drag/drop (`Gtk.DropTarget`, signal `drop`) | `drop_target` | controller | Yes |
| right-click gesture on `listbox` (`Gtk.GestureClick`, button SECONDARY, signal `pressed`) | `right_click` | controller | Yes |
| `toast_overlay` (`Adw.ToastOverlay`) | `toast_overlay` | widget | Yes |
| `mainbox` / `Adw.ToolbarView` | `mainbox`, `toolbar_view` | widget | Yes |
| actions: `select-file` (`<Primary>o`), `clear-results`, `banner-change-mode`, `preferences` (`<Primary>comma`), `about`, `quit` (`<Primary>q`), `convert-dir` (`<Primary>d`) | `create_actions` / `activate_action` | action | Yes, plus `shortcuts` (`<Primary>question`) added at the window level since `app.shortcuts`'s own accel is GTK-reserved |
| context menu on right click (`Gio.SimpleActionGroup` "context-menu": `open-image`, `open-folder`; `Gtk.PopoverMenu`) | `show_context_menu`, `context_actions`, `context_popover`, `context_menu` | widget/action | Yes |
| `on_select` (`Gtk.FileDialog#open_multiple`, mime filters) | `on_select`, `open_multiple_finished` | behaviour | Yes |
| `on_select_folder` + `_create_warning_dialog` (`Adw.AlertDialog`, responses cancel/compress, appearance SUGGESTED/DESTRUCTIVE by `new_file`) | `on_select_folder`, `select_folders_finished`, `confirm_folders`, `warning_dialog`, `warning_body`, `warning_appearance` | dialog | Yes |
| `on_about` (`Adw.AboutDialog`, credits, contributors, `debug_infos()`) | `on_about` | dialog | Yes |
| `on_quit` | `activate_action('quit')` | action | Yes |
| `show_view` (home/loading/results) | `show_view` | behaviour | Yes |
| `set_saving_subtitle` / `show_warning_banner` | `set_saving_subtitle`, `saving_subtitle`, `affix_subtitle`, `affixed`, `show_warning_banner` | behaviour | Yes |
| `compress_files` / `handle_files` / `update_result_item` | `compress_files`, `handle_files`, `folder_images`, `start_compression`, `add_row`, `begin_or_report`, `update_result_item`, `record_savings` | behaviour | Yes |
| icon resource registration (`icon_theme.add_resource_path`) | `register_icons` | behaviour | Yes |

Repeaters: `listbox` rows, one `CurtailResultItemRow` per `ResultItem` — see
below. Conditional: warning banner only when `new_file` is false; context menu
only built on a right-click with a valid filename under the pointer.

## Result item row — `src/result_item_row.py` + `data/ui/result-item-row.blp`

| Upstream element | Port (`lib/curtail_rb/result_item_row.rb`) | Kind | Present? |
|---|---|---|---|
| `Adw.ActionRow` template root | row class itself | widget | Yes |
| `skipped_info_button` (`MenuButton`, css `flat`, popover with fixed label) | present | widget | Yes |
| `error_info_button` (`MenuButton`, css `flat`, popover with `error_popover_label`) | present | widget | Yes |
| `savings_label` (css `success`) | present | widget | Yes |
| `spinner` (`Adw.Spinner`) | present | widget | Yes |
| `error_image` (`Image`, icon `x-circular-symbolic`, css `error`) | present | widget | Yes |
| thumbnail prefix image (`create_image_from_file`, 48×48) | present | widget (conditional: only when `new_filename` is non-empty) | Yes |
| property bindings: `savings`→label, `subtitle_label`→subtitle, `running`→spinner visible, `skipped`→skipped button visible, `error`→error image visible, `error_details`→error button visible, `error_details_message`→popover label | explicit `refresh` method (README-documented difference from upstream's `bind_property` calls) | behaviour | Yes |

## Result item (state object) — `src/result_item.py`

| Upstream | Port | Kind | Present? |
|---|---|---|---|
| `ResultItem(GObject.Object)` properties: `file`, `mime_type`, `name`, `filename`, `new_filename`, `tmp_filename`, `size`, `new_size`, `subtitle_label`, `savings`, `running`, `skipped`, `error`, `error_message`, `error_details`, `error_details_message`; `set_error` | `lib/curtail_rb/result_item.rb` | model | Yes |

## Result item manager — `src/result_item_manager.py`

| Upstream | Port | Kind | Present? |
|---|---|---|---|
| `ResultItemManager#build` (file existence check, mime allow-list `image/jpeg,png,webp,svg+xml`, host-path via `xattr::document-portal.host-path`, `set_error` paths) | `lib/curtail_rb/result_item_manager.rb` | service | Yes |
| `create_new_filename` (suffix/prefix naming) | same file | behaviour | Yes |

## Preferences dialog — `src/preferences.py` + `data/ui/preferences.blp`

Two-page `Adw.PreferencesDialog`.

| Upstream element | Port (`lib/curtail_rb/preferences_dialog.rb`) | Kind | Present? |
|---|---|---|---|
| General page: `toggle_new_file` (`Adw.SwitchRow`, "Safe Mode") | present | widget | Yes |
| `toggle_naming_mode` (`Adw.ComboRow`, Suffix/Prefix) | present | widget | Yes |
| `entry_suffix_prefix` (`Adw.EntryRow`) | present | widget | Yes |
| `toggle_recursive` (`Adw.SwitchRow`) | present | widget | Yes |
| `toggle_metadata` (`Adw.SwitchRow`) | present | widget | Yes |
| `toggle_file_attributes` (`Adw.SwitchRow`) | present | widget | Yes |
| `spin_timeout` (`Adw.SpinRow`, 1–300) | present | widget | Yes |
| Formats page, PNG group: `spin_png_lossy_level` (0–100), `spin_png_lossless_level` (0–6) | present | widget | Yes |
| JPG group: `spin_jpg_lossy_level` (0–100), `toggle_jpg_progressive` | present | widget | Yes |
| WebP group: `spin_webp_lossy_level` (0–100), `spin_webp_lossless_level` (0–6) | present | widget | Yes |
| SVG group: `toggle_svg_maximum_level` | present | widget | Yes |
| signal wiring: every row's `notify::active`/`notify::selected-item`/`changed`/`notify::value` → settings key, plus `new-file` toggling sensitivity of naming-mode/entry and re-running `set_saving_subtitle`/`show_warning_banner` on the parent window | `on_bool_changed`-equivalent handlers | behaviour | Yes |

## Shortcuts dialog — `data/ui/shortcuts-dialog.blp` (no backing source file upstream)

Standalone named object, no `template`/backing class upstream (`shortcuts_dialog` top-level `Adw.ShortcutsDialog`); per the skill, this is its own unit.

| Upstream element | Port (`lib/curtail_rb/shortcuts_dialog.rb`) | Kind | Present? |
|---|---|---|---|
| `Adw.ShortcutsSection` "General" | present | widget | Yes |
| `Adw.ShortcutsItem` "Select File" → `win.select-file` | present | widget/action target | Yes |
| `Adw.ShortcutsItem` "Preferences" → `win.preferences` | present | widget/action target | Yes |
| `Adw.ShortcutsItem` "Keyboard Shortcuts" → `app.shortcuts` | present, bound to `win.shortcuts` (see window note above) | widget/action target | Yes, with the same window-vs-app action difference |
| `Adw.ShortcutsItem` "Quit" → `win.quit` | present | widget/action target | Yes |

## Compression pipeline — not UI, included for completeness since they feed `ResultItem` state the UI renders

| Upstream | Port | Kind | Present? |
|---|---|---|---|
| `src/compressor.py` (`Compressor` ABC + run/collect cycle) | `lib/curtail_rb/compressor.rb` | service | Yes (restructured as one module with four command builders — documented difference, no behaviour change) |
| `src/compressors/png_compressor.py` | `lib/curtail_rb/compressors/png_compressor.rb` | service | Yes |
| `src/compressors/jpeg_compressor.py` | `lib/curtail_rb/compressors/jpeg_compressor.rb` | service | Yes |
| `src/compressors/webp_compressor.py` | `lib/curtail_rb/compressors/webp_compressor.rb` | service | Yes |
| `src/compressors/svg_compressor.py` | `lib/curtail_rb/compressors/svg_compressor.rb` | service | Yes |
| `src/compression_manager.py` (thread pool, one worker per core, GLib idle callbacks) | `lib/curtail_rb/compression_manager.rb` | service | Yes |
| `src/settings_manager.py` | `lib/curtail_rb/settings.rb` | service | Yes |
| `src/tools.py` (`sizeof_fmt`, `add_filechooser_filters`, `create_image_from_file`, folder walks, `debug_infos`, `extract_version`) | `lib/curtail_rb/tools.rb` | service | Yes |
| — (no upstream equivalent; Ruby gettext has no binding, so the port writes its own) | `lib/curtail_rb/i18n.rb` | service | Extra, not a gap — supports the `_`/`p_`/`N_` marking the README documents |
| — | `lib/curtail_rb/paths.rb` | service | Extra — resource/path helpers for the Ruby packaging layout |

## Data files

| Upstream | Port | Kind | Present? |
|---|---|---|---|
| `data/com.github.huluti.Curtail.gschema.xml` (16 keys: `new-file`, `naming-mode`, `recursive`, `metadata`, `file-attributes`, `lossy`, `suffix-prefix`, `png-lossy-level`, `png-lossless-level`, `jpg-lossy-level`, `webp-lossy-level`, `webp-lossless-level`, `jpg-progressive`, `svg-maximum-level`, `compression-timeout`) | `data/com.github.huluti.Curtail.Rb.gschema.xml` | schema | Yes, under the port's own app id (`rake schema` compiles it) |
| `data/com.github.huluti.Curtail.desktop.in` | `data/com.github.huluti.Curtail.Rb.desktop` | desktop entry | Yes |
| `data/com.github.huluti.Curtail.appdata.xml.in` | `data/com.github.huluti.Curtail.Rb.metainfo.xml` | metainfo | Yes |
| `data/icons/hicolor/scalable/apps/com.github.huluti.Curtail.svg` + Devel variant | `data/icons/hicolor/scalable/apps/com.github.huluti.Curtail.Rb.svg` | icon | Yes (Devel variant not carried — not user-facing in a release build) |
| `data/icons/hicolor/symbolic/apps/com.github.huluti.Curtail-symbolic.svg` | `data/icons/hicolor/symbolic/apps/com.github.huluti.Curtail.Rb-symbolic.svg` | icon | Yes |
| `data/icons/scalable/actions/{info-outline,x-circular}-symbolic.svg` | same two files under `data/icons/scalable/actions/` | icon | Yes |
| `data/curtail.gresource.xml` (bundles the four `.ui` files + the two action icons) | — | resource manifest | N/A by design — the Ruby port builds widgets declaratively in code per the house style and never ships `.ui`/gresource files |
| `po/*.po` (40 catalogues) + `po/curtail.pot` + `po/LINGUAS` | `po/*.po` (40 catalogues) + `po/curtail.pot` + `po/LINGUAS` | translation catalogue | Yes — all 40 carried over unchanged, per README; `rake po`/`rake pot`/`rake merge`/`rake i18n` drive them |

## Summary

Every upstream user-facing component — the main window and its home/loading/
results views, the result-item row, the preferences dialog's two pages, the
shortcuts dialog, every menu item, keyboard shortcut, action, dialog
(file/folder choosers, the folder-compress warning alert, the about dialog,
the right-click context menu) and error/empty state — already has a
corresponding `lib/*.rb` file on `ruby`, and reading both sides line-by-line
turned up no missing widget, action or binding. The only differences are the
ones the README already documents (app-id renaming, the `Compressor` module
shape, the `win.shortcuts`/`app.shortcuts` action-name swap forced by GTK's
reserved accelerator, and the two upstream bugs this port deliberately does
not reproduce).

No blocking gaps were found. The one open question worth flagging to a human:
whether `app.shortcuts`'s accelerator being GTK-reserved is confirmed (vs.
worked around some other way), since both the window actions table and the
shortcuts dialog route "Keyboard Shortcuts" through `win.shortcuts` rather
than matching upstream's `app.shortcuts` literally.
