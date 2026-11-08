# Component identification — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit) |

Re-audit note: `lib/` and `exe/` are unchanged since this inventory was
written (`git diff 8393a06 HEAD -- lib/ exe/` is empty against the commit
that introduced this file), so the tables below were re-read against
current `origin/main` @ `1536d90` and stand without modification. The
`rake`/devshell and translation-pipeline findings from this round live in
`.reports/test-parity.md`, `.reports/translation-parity.md` and
`.reports/accountability-ensurance.md` — they are app-wide/build-pipeline
findings, not widget-identification findings, so they do not change
anything below.

Re-audit note (next round): still true — `git diff` from this file's
introducing commit through current `HEAD` touches only `AGENTS.md`
(confirmed again this round). This round's own new finding (`rake drive`
is flaky — see `.reports/test-parity.md` and
`.reports/accountability-ensurance.md`) is a test-harness timing defect
in `test/drive_compression.rb`'s wait logic, not a widget-identification
finding, so it does not change any row below either.

Scan produced with the symbol table built from this machine's GTK4/Adwaita
GIR (`gir-symbols.sh`, 1205 symbols) and `component-scan.sh` run on an
`origin/main` worktree and on the `ruby` tree. Raw TSVs are reproducible with:

```sh
git worktree add --detach /tmp/up origin/main
bash .claude/skills/component-identification/scripts/component-scan.sh /tmp/up  > up.tsv
bash .claude/skills/component-identification/scripts/component-scan.sh .       > port.tsv
```

## Unit list (upstream `.blp` template roots + standalone objects)

| Upstream unit | Backing source | Port file |
|---|---|---|
| `template $CurtailWindow: Adw.ApplicationWindow` | `data/ui/window.blp` + `src/window.py` | `lib/curtail_rb/window.rb` |
| `template ResultItemRow: Adw.ActionRow` | `data/ui/result-item-row.blp` + `src/result_item_row.py` | `lib/curtail_rb/result_item_row.rb` |
| `Adw.PreferencesDialog` (two-page) | `data/ui/preferences.blp` + `src/preferences.py` | `lib/curtail_rb/preferences_dialog.rb` |
| `shortcuts_dialog` top-level `Adw.ShortcutsDialog` (no backing class upstream) | `data/ui/shortcuts-dialog.blp` | `lib/curtail_rb/shortcuts_dialog.rb` |
| `Application(Adw.Application)` | `src/main.py` + `src/curtail.in` | `lib/curtail_rb/application.rb` + `exe/curtail-rb` |
| `ResultItem(GObject.Object)` (state object, no widget) | `src/result_item.py` | `lib/curtail_rb/result_item.rb` |
| `ResultItemManager` (service) | `src/result_item_manager.py` | `lib/curtail_rb/result_item_manager.rb` |
| `Compressor` + 4 format subclasses (service) | `src/compressor.py`, `src/compressors/*.py` | `lib/curtail_rb/compressor.rb`, `lib/curtail_rb/compressors/*.rb` |
| `CompressionManager` (service) | `src/compression_manager.py` | `lib/curtail_rb/compression_manager.rb` |
| `SettingsManager` (service) | `src/settings_manager.py` | `lib/curtail_rb/settings.rb` |
| `tools.py` (helpers) | `src/tools.py` | `lib/curtail_rb/tools.rb` |

Every upstream unit maps to exactly one port file (Step 1's `.blp`/`.ui`-first
read, cross-checked against the scan). No upstream unit is missing a
corresponding port file.

## Per-file scan (widget stream), after reading past the known over/under-reports

### `data/ui/window.blp` + `src/window.py` → `lib/curtail_rb/window.rb`

| Widget | Up × | Port × | Note |
|---|---:|---:|---|
| `Adw.ApplicationWindow` | 1 | 1 | template root counted once (struck the duplicate `src/window.py` occurrence per Step 4) |
| `Adw.AboutDialog` | 1 | 1 | |
| `Adw.AlertDialog` | 2 (textual) → **1 real dialog, 2 message branches** | 1 call site, 2 branches | `_create_warning_dialog` upstream and `warning_dialog`/`warning_body` in the port are the same conditional-text pattern — read at `lib/curtail_rb/window.rb:371-410` |
| `Adw.Banner` | 1 | 1 | |
| `Adw.Clamp` | 1 | 1 | |
| `Adw.HeaderBar` | 1 | 1 | |
| `Adw.StatusPage` | 2 | 2 | |
| `Adw.ToastOverlay` | 1 | 1 | |
| `Adw.ToggleGroup` | 1 | 1 | |
| `Adw.ToolbarView` | 1 | 1 | |
| `Adw.WindowTitle` | 1 | 1 | |
| `Gtk.Box` | scanner says 1, hand count 2 (`mainbox` + the box inside `homebox`, `window.blp:65,85`) | 2 (`mainbox`, `homebox_content`, `window.rb:555,577`) | scanner under-counted upstream; hand count matches |
| `Gtk.Button` | 3 | 3 | |
| `Gtk.ListBox` | 1 | 1 | |
| `Gtk.MenuButton` | 1 | 1 | |
| `Gtk.PopoverMenu` | 1 | 1 | |
| `Gtk.ScrolledWindow` | 1 | 1 | |
| `Gtk.Window` (port scan only) | — | 1 | false positive: `Gtk::Window.set_default_icon_name` is a class-method call, not an instantiation (`window.rb:210`) |

Actions: `select-file`, `clear-results`, `banner-change-mode`, `convert-dir`,
`preferences`, `about`, `quit`, plus the port's own `shortcuts` — all built
from a name/accelerator hash in `create_actions` (`window.rb:215-235`),
so most never appear as scan literals on either side; verified by reading the
install site, not by the scan.

### `data/ui/result-item-row.blp` + `src/result_item_row.py` → `lib/curtail_rb/result_item_row.rb`

| Widget | Up × | Port × | Note |
|---|---:|---:|---|
| `Adw.ActionRow` | 1 | 1 | |
| `Adw.Spinner` | 1 | 1 | |
| `Gtk.Image` | 1 | 1 | |
| `Gtk.Label` | 2 | 2 | |
| `Gtk.MenuButton` | 2 (`skipped_info_button`, `error_info_button`) | 1 textual, **2 real** | both memoize through the shared `info_button` factory, `result_item_row.rb:93-105` — the under-report case the skill warns about, confirmed by reading |
| `Gtk.Popover` | 2 | 2 | |

CSS `flat` on both buttons: 1 textual occurrence in the factory, 2 live
attachments — same factory pattern.

### `data/ui/preferences.blp` + `src/preferences.py` → `lib/curtail_rb/preferences_dialog.rb`

| Widget | Up × | Port × (textual) | Port × (real, via factory) |
|---|---:|---:|---:|
| `Adw.SwitchRow` | 6 | 1 | 6 (`new_file_row`, `recursive_row`, `metadata_row`, `file_attributes_row`, `jpg_progressive_row`, `svg_maximum_row`, all through `switch_row`) |
| `Adw.SpinRow` | 6 | 1 | 6 (`timeout_row`, `png_lossy_row`, `png_lossless_row`, `jpg_lossy_row`, `webp_lossy_row`, `webp_lossless_row`, all through `spin_row`) |
| `Adw.ComboRow` | 1 | 1 | 1 |
| `Adw.EntryRow` | 1 | 1 | 1 |
| `Adw.PreferencesPage` | 2 | 2 | 2 |
| `Adw.PreferencesGroup` | 5 | 5 | 5 |

Verified by reading `preferences_dialog.rb:17-66` (the `build` method adds
all 12 factory-built rows by name) and `:220-270` (the two factories).

### `data/ui/shortcuts-dialog.blp` → `lib/curtail_rb/shortcuts_dialog.rb`

4 `Adw.ShortcutsItem`s upstream, 1 textual occurrence in the port's scan
(built in a loop over an array of 4 label/action pairs) — confirmed 4 real
items by reading `shortcuts_dialog.rb`.

## What this inventory does not cover

This file enumerates widgets, CSS, signals and actions only. Translatable
strings are censused separately in `.reports/translation-parity.md`, and the
four-axis correspondence judgement (does each matched widget behave and read
identically) is in `.reports/component-parity.md`.
