# Curtail — upstream component inventory

Surveyed against `origin/main` (Python/GTK4/Libadwaita, upstream source tree
below), compared with `lib/` on the `ruby` branch as of this commit. This is a
survey only — no app code was written in this step.

```
git ls-tree -r --name-only origin/main
```
listed: `src/*.py` (+ `src/compressors/*.py`), `data/ui/*.blp`,
`data/com.github.huluti.Curtail.gschema.xml`,
`data/curtail.gresource.xml`, `data/com.github.huluti.Curtail.desktop.in`,
`data/com.github.huluti.Curtail.appdata.xml.in`, and `po/*`.

## Components

| # | Upstream file(s) | Kind | `lib/*.rb` target | Present? |
|---|---|---|---|---|
| 1 | `src/main.py` | `Adw.Application` subclass (app id, `do_startup`/`do_activate`/`do_open`) | `lib/curtail_rb/application.rb` | Yes |
| 2 | `src/window.py` + `data/ui/window.blp` | `Adw.ApplicationWindow` — main window: headerbar (open/clear buttons, main menu `MenuButton`), `Adw.Banner` warning banner, home `Adw.StatusPage` (browse button, `Adw.ToggleGroup` lossy/lossless), loading `Adw.StatusPage` w/ `Adw.SpinnerPaintable`, results `ScrolledWindow`→`Adw.Clamp`→`ListBox` (boxed-list), DnD drop target on the mainbox, right-click `Gtk.PopoverMenu` w/ its own `Gio.SimpleActionGroup` (open-image/open-folder), `Adw.AboutDialog`, `Adw.AlertDialog` (bulk-compress-directory warning), window actions (`select-file`, `clear-results`, `banner-change-mode`, `preferences`, `about`, `quit`, `convert-dir`) | `lib/curtail_rb/window.rb` | Yes |
| 3 | `src/preferences.py` + `data/ui/preferences.blp` | `Adw.PreferencesDialog` — "General" page (Safe Mode switch, Naming Mode combo, suffix/prefix entry, Recursive/Keep Metadata/Keep File Attributes switches, Compression Timeout spin) and "Formats" page (PNG/JPG/WebP/SVG groups of spin/switch rows) | `lib/curtail_rb/preferences_dialog.rb` | Yes |
| 4 | `data/ui/shortcuts-dialog.blp` (no backing `.py`) | `Adw.ShortcutsDialog` — one "General" `Adw.ShortcutsSection` with 4 `Adw.ShortcutsItem`s (select-file, preferences, shortcuts, quit) | `lib/curtail_rb/shortcuts_dialog.rb` | Yes — port's comment documents the `app.shortcuts` upstream wiring quirk (no upstream source installs that action) and retargets to `win.shortcuts` |
| 5 | `src/result_item_row.py` + `data/ui/result-item-row.blp` | `Adw.ActionRow` subclass — per-result row: prefix thumbnail image, skipped/error `MenuButton` info popovers, savings `Label` (`success` style), `Adw.Spinner`, error `Image` (`error` style), property bindings from `ResultItem` | `lib/curtail_rb/result_item_row.rb` | Yes |
| 6 | `src/result_item.py` | `GObject.Object` subclass — per-file compression state/properties (file, name, filename, sizes, savings, running/skipped/error flags, error messages) | `lib/curtail_rb/result_item.rb` | Yes |
| 7 | `src/result_item_manager.py` | Builds a `ResultItem` from a `Gio.File` (mime-type validation, display name, new/tmp filename computation) | `lib/curtail_rb/result_item_manager.rb` | Yes |
| 8 | `src/settings_manager.py` + `data/com.github.huluti.Curtail.gschema.xml` | GSettings wrapper — one property pair per schema key (15 keys) | `lib/curtail_rb/settings.rb`, `data/com.github.huluti.Curtail.Rb.gschema.xml` | Yes — all 15 keys present and matching upstream's gschema |
| 9 | `src/compression_manager.py` | Thread-pool dispatcher: registers compressors by file type, runs compression off the UI thread | `lib/curtail_rb/compression_manager.rb` | Yes |
| 10 | `src/compressor.py` | Abstract base: runs the shell command, handles timeout/error, compares sizes, copies/overwrites, cleans up tmp file | `lib/curtail_rb/compressor.rb` | Yes |
| 11 | `src/compressors/png_compressor.py` | `pngquant`/`oxipng` command builder | `lib/curtail_rb/compressors/png_compressor.rb` | Yes |
| 12 | `src/compressors/jpeg_compressor.py` | `jpegoptim` command builder | `lib/curtail_rb/compressors/jpeg_compressor.rb` | Yes |
| 13 | `src/compressors/webp_compressor.py` | `cwebp` command builder | `lib/curtail_rb/compressors/webp_compressor.rb` | Yes |
| 14 | `src/compressors/svg_compressor.py` | `scour` command builder | `lib/curtail_rb/compressors/svg_compressor.rb` | Yes |
| 15 | `src/tools.py` | Helpers: file-chooser filters (4 `Gtk.FileFilter`s + "All images"), thumbnail scaling (`GdkPixbuf`), recursive folder walk, `debug_infos` (tool version probing for the About dialog) | `lib/curtail_rb/tools.rb` | Yes |
| 16 | `data/com.github.huluti.Curtail.desktop.in` | Desktop entry (id, exec, mime types, keywords) | `data/com.github.huluti.Curtail.Rb.desktop` | Yes |
| 17 | `data/com.github.huluti.Curtail.appdata.xml.in` | AppStream metainfo | `data/com.github.huluti.Curtail.Rb.metainfo.xml` | Yes |
| 18 | `data/curtail.gresource.xml` + icons under `data/icons/` | GResource manifest bundling the `.ui` files and the two symbolic action icons | N/A (Ruby port has no GResource/.ui bundle by house style — widgets are built directly in code) | N/A by house style; icons present under `data/icons/` |
| 19 | `po/*.po`, `po/curtail.pot`, `po/POTFILES.in` | Translation catalogue (41 languages + template) | `po/*.po` | Present — all upstream locale files carried over; not re-verified msgid-by-msgid in this pass (that is `translation-parity`'s job) |

## Not a separate component

- `data/com.github.huluti.Curtail.service.in`, `Curtail.doap`, `com.github.huluti.Curtail.json` (Flatpak manifest), `oxipng-sources.json`, `pngquant-sources.json`, `scour-sources.json`, build files (`meson.build`, `Makefile`, `debian/*`) — packaging/build plumbing, not UI or app behavior.

## Bottom line

Every upstream user-facing source file already has a corresponding `lib/curtail_rb/*.rb` file on `ruby`, including the dialogs (preferences, shortcuts, about, alert), the main window's menu/banner/toggle/DnD/context-menu surface, the result row, the settings wrapper (all 15 gschema keys), the compression pipeline and all four format compressors, and the desktop/metainfo/icon data files. No missing component was found in this survey.

Two items flagged for other skills, not resolved here:
- `po/` parity (msgid-by-msgid) is unverified — hand to `translation-parity`.
- Widget-level parity (CSS classes, signals, exact action wiring) is unverified at the fine-grained level this survey operates at — hand to `component-parity`.
