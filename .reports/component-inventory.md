# Curtail-rb — upstream component inventory

Upstream: `origin/main` (Curtail 1.16.2, PyGObject + blueprint).
Port: the `ruby` branch, `lib/curtail_rb/*.rb`.

Upstream splits every component across two files — a `.blp` holding the widget
tree, CSS classes and ids, and a `.py` holding the template children,
bindings and callbacks. The port carries both halves in one file, so the rows
below are the union of each pair.

## Component map

| Upstream | Port file | Kind | Exists |
|---|---|---|---|
| `src/main.py` | `lib/curtail_rb/application.rb` | application | yes |
| `data/ui/window.blp` + `src/window.py` | `lib/curtail_rb/window.rb` | window | yes |
| `data/ui/window.blp` (`menu main_menu`) | `lib/curtail_rb/window.rb` (`main_menu`) | menu | yes |
| `src/window.py` (`on_results_right_click`) | `lib/curtail_rb/window.rb` (`context_menu`) | context menu | yes |
| `src/window.py` (`_create_warning_dialog`) | `lib/curtail_rb/window.rb` (`warning_dialog`) | dialog | yes |
| `src/window.py` (`on_about`) | `lib/curtail_rb/window.rb` (`about_dialog`) | dialog | yes |
| `data/ui/shortcuts-dialog.blp` | `lib/curtail_rb/window.rb` (`shortcuts_dialog`) | dialog | yes (not its own file) |
| `data/ui/preferences.blp` + `src/preferences.py` | `lib/curtail_rb/preferences_dialog.rb` | dialog | yes |
| `data/ui/result-item-row.blp` + `src/result_item_row.py` | `lib/curtail_rb/result_item_row.rb` | row | yes |
| `src/result_item.py` | `lib/curtail_rb/result_item.rb` | model | yes |
| `src/result_item_manager.py` | `lib/curtail_rb/result_item_manager.rb` | model | yes |
| `src/settings_manager.py` + `data/…gschema.xml` | `lib/curtail_rb/settings.rb` + `data/com.github.huluti.Curtail.Rb.gschema.xml` | settings | yes |
| `src/compression_manager.py` | `lib/curtail_rb/compression_manager.rb` | support | yes |
| `src/compressor.py` + `src/compressors/{png,jpeg,webp,svg}_compressor.py` | `lib/curtail_rb/compressor.rb` | support | yes (5 files folded into 1) |
| `src/tools.py` | `lib/curtail_rb/tools.rb` | support | yes |
| `po/*` (40 locales, `po/POTFILES.in`) | `po/*` + `lib/curtail_rb/i18n.rb` | i18n | yes |
| `data/curtail.gresource.xml` | — (no GResource in the port; widgets are built in Ruby) | resource | n/a |

Every user-facing component upstream has a counterpart on `ruby`. What remains
is parity inside the components, not missing components.

## src/main.py → lib/curtail_rb/application.rb — the application

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| — (`Adw.Application`) | 1 | — | `activate`, `open` | `HANDLES_OPEN`; `open` presents then compresses the argv files |

The port uses `Gtk::Application` plus an explicit `Adwaita.init`, because the
Ruby bindings cannot subclass `Adwaita::Application` nor hand it to a window.
Actions all live on the window (`win.*`), as upstream.

## data/ui/window.blp + src/window.py → lib/curtail_rb/window.rb — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | — | title "Curtail", 650×500, default icon name set in code |
| `Adw.ToastOverlay` | 1 | — | — | hosts the "No files found" toast |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.Button` (filechooser) | 1 | — | `win.select-file` | `document-open-symbolic`, tooltip "Browse Files" |
| `Gtk.Button` (clear) | 1 | — | `win.clear-results` | `view-refresh-symbolic`, visible only in the results view |
| `Adw.WindowTitle` | 1 | — | — | subtitle is the saving mode: safe-mode suffix/prefix, or "Overwrite mode" |
| `Gtk.MenuButton` | 1 | — | `main_menu` | `open-menu-symbolic`, primary |
| `Gtk.Box` (mainbox) | 1 | — | `drop` (`Gtk.DropTarget`, `Gdk.FileList`, COPY) | the drag-and-drop surface |
| `Adw.Banner` | 1 | — | `win.banner-change-mode` | "Images will be overwritten…", button "_Change Mode"; revealed when safe mode is off |
| `Adw.StatusPage` (homebox) | 1 | `icon-dropshadow` | — | app icon, "Drop images here to compress them" — the **empty state** |
| `Gtk.Box` (homebox content) | 1 | — | — | spacing 36 |
| `Gtk.Button` (browse) | 1 | `suggested-action`, `pill` | `win.select-file` | "_Browse Files", underline |
| `Adw.ToggleGroup` | 1 | — | `notify::active-name` → writes `lossy` | |
| `Adw.Toggle` | 2 | — | — | names `lossless`, `lossy` |
| `Adw.StatusPage` (loadingbox) | 1 | — | — | "Analyzing Images", `Adw.SpinnerPaintable` on itself — the **loading state** |
| `Gtk.ScrolledWindow` (resultbox) | 1 | — | — | `hscrollbar-policy: never` |
| `Adw.Clamp` | 1 | — | — | margins 10/10/20/20 |
| `Gtk.ListBox` | 1 | `boxed-list` | `Gtk.GestureClick` (secondary button) → `pressed` | `selection-mode: none`; bound to the `ResultItem` model |
| `CurtailResultItemRow` | N | — | — | **repeater**: one per result item (see below) |
| `Gtk.PopoverMenu` | 1 | — | `context-menu.open-image`, `context-menu.open-folder` | built per right-click, no arrow, pointed at the click |
| `Adw.AlertDialog` | 1 | — | responses `cancel`, `compress` | bulk-directory confirmation; `compress` is SUGGESTED in safe mode, DESTRUCTIVE in overwrite mode, and the body text differs per mode |
| `Adw.AboutDialog` | 1 | — | — | developer, designers, contributors credit section, `debug_info` from `tools` |
| `Adw.ShortcutsDialog` | 1 | — | — | see the shortcuts unit |
| `Gtk.FileDialog` | 2 uses | — | — | "Browse Files" (multiple, 5 mime filters) and "Browse Directories" (multiple folders) |

Views: `home`, `loading`, `results` — `show_view` toggles visibility of the
three boxes and of the clear button. Not a `Gtk.Stack`.

Menu `main_menu` — 4 items: "Bulk Compress Directory" (`win.convert-dir`),
"Preferences" (`win.preferences`), "Keyboard Shortcuts" (`app.shortcuts`),
"About Curtail" (`win.about`).

Actions and accelerators installed on the window:

| Action | Accel | Does |
|---|---|---|
| `win.select-file` | `<Primary>o` | file dialog, then compress |
| `win.clear-results` | — | back to home, empty the model |
| `win.banner-change-mode` | — | turn safe mode on, hide the banner, refresh the subtitle |
| `win.preferences` | `<Primary>comma` | force-close then present the preferences dialog |
| `win.about` | — | about dialog |
| `win.quit` | `<Primary>q` | quit |
| `win.convert-dir` | `<Primary>d` | folder dialog, then the warning alert |

Error states: a per-item error (unsupported format, missing file) surfaces on
the row, not as a dialog; an empty selection surfaces as the toast.

## data/ui/shortcuts-dialog.blp → lib/curtail_rb/window.rb — the shortcuts dialog

A standalone blueprint object with no backing Python file.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | |
| `Adw.ShortcutsSection` | 1 | — | — | title "General" (`shortcuts dialog` msgctxt) |
| `Adw.ShortcutsItem` | 4 | — | — | Select File, Preferences, Keyboard Shortcuts, Quit |

## data/ui/preferences.blp + src/preferences.py → lib/curtail_rb/preferences_dialog.rb

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | title "Preferences" |
| `Adw.PreferencesPage` | 2 | — | — | General (`applications-system-symbolic`), Formats (`image-x-generic-symbolic`) |
| `Adw.PreferencesGroup` | 5 | — | — | one unnamed on General; PNG, JPG, WebP, SVG on Formats |
| `Adw.SwitchRow` | 6 | — | `notify::active` → bool key | Safe Mode, Recursive, Keep Metadata, Keep File Attributes, Progressive Encode, Maximum SVG Level |
| `Adw.ComboRow` | 1 | — | `notify::selected-item` → `naming-mode` | `Gtk.StringList` ["Suffix", "Prefix"]; insensitive when safe mode is off |
| `Adw.EntryRow` | 1 | — | `changed` → `suffix-prefix` | resets to default when emptied; insensitive when safe mode is off |
| `Adw.SpinRow` | 6 | — | `notify::value` → int key | timeout 1–300/1/10; PNG lossy 0–100, PNG lossless 0–6, JPG lossy 0–100, WebP lossy 0–100, WebP lossless 0–6 |

Cross-component behaviour: toggling Safe Mode also refreshes the window
subtitle, reveals/hides the warning banner, and flips the sensitivity of the
naming-mode and suffix/prefix rows.

## data/ui/result-item-row.blp + src/result_item_row.py → lib/curtail_rb/result_item_row.rb

One row per image being compressed.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title = display name, tooltip = new filename, subtitle = size (→ new size) |
| `Gtk.Image` (prefix) | 1 | — | — | 48×48 thumbnail, only when a new filename exists and the pixbuf loads |
| `Gtk.MenuButton` (skipped) | 1 | `flat` | — | `info-outline-symbolic`, visible ← `skipped` |
| `Gtk.MenuButton` (error) | 1 | `flat` | — | `info-outline-symbolic`, visible ← `error_details` |
| `Gtk.Popover` | 2 | — | — | one fixed "compression was skipped…" label, one bound to `error_details_message` |
| `Gtk.Label` (popover) | 2 | — | — | wrap, max 50 chars, margins 6 |
| `Gtk.Label` (savings) | 1 | `success` | — | "NN%" or "Skipped" |
| `Adw.Spinner` | 1 | — | — | visible ← `running` |
| `Gtk.Image` (error) | 1 | `error` | — | `x-circular-symbolic`, visible ← `error` |

Upstream drives all of this with 7 `bind_property` calls; the port refreshes
from the item instead, since the Ruby bindings have no plain GObject property
on a Ruby-side model.

## Non-widget units

- `src/result_item.py` → `lib/curtail_rb/result_item.rb` — 16 fields, `set_error`.
- `src/result_item_manager.py` → `lib/curtail_rb/result_item_manager.rb` — 4 allowed mime types, portal host-path lookup, suffix/prefix naming, tmp path, the two error strings.
- `src/settings_manager.py` → `lib/curtail_rb/settings.rb` — 15 GSettings keys.
- `src/compression_manager.py` → `lib/curtail_rb/compression_manager.rb` — one worker per core (`Etc.nprocessors`, matching upstream's `os.cpu_count()`), results marshalled back on the main loop.
- `src/compressor.py` + `src/compressors/*.py` → `lib/curtail_rb/compressor.rb` — pngquant/oxipng, jpegoptim, cwebp, scour.
- `src/tools.py` → `lib/curtail_rb/tools.rb` — file filters, thumbnail, folder walk (flat and recursive), `debug_infos`.

## Open items

1. **`app.shortcuts` has no installer upstream.** The window menu and the
   shortcuts dialog both target `app.shortcuts`, but no upstream source file
   installs it, so the item is dead on upstream. The port installs it as
   `win.shortcuts` — a deliberate divergence, and the port's shortcuts item
   labels must still read as upstream's do.
2. **The shortcuts dialog has no file of its own.** It is a standalone
   blueprint with no backing source file, which the house rule makes its own
   unit; it currently lives inside `window.rb`. Candidate split:
   `lib/curtail_rb/shortcuts_dialog.rb`, and likewise `about_dialog.rb`.
3. **Stale scaffold.** `lib/curtail.rb`, `lib/curtail/application.rb` and
   `exe/curtail` are the kettle-jem packaging stub — a status page saying the
   port is unwritten. They shadow the real app (`lib/curtail_rb.rb`,
   `exe/curtail-rb`) and should go.
4. **GResource and the icons.** Upstream ships `x-circular-symbolic` and
   `info-outline-symbolic` through GResource; the port loads them from
   `Paths.icon_dir`, and both SVGs are present under
   `data/icons/scalable/actions/`. No gap.
5. **`po/POTFILES.in` omits `lib/curtail_rb/compression_manager.rb`** and the
   data files; worth confirming against the catalogue in the translation step.
