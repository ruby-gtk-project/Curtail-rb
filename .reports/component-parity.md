# Component parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit) |
| Units with parity | 6 / 6 UI units, with one structural gap outside any single unit (see below) |

Each unit below was checked on all four axes (count, style, behaviour, text),
plus the two axes `component-parity` adds beyond the scan: CSS rules actually
rendering (Step 4) and signals actually firing (Step 5, via the drive suite
that already exercises these units — see `.reports/test-parity.md`).

## Unit: main window — `data/ui/window.blp` + `src/window.py` → `lib/curtail_rb/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | `activate`×3, `open` | ✓ | parity |
| `Adw.Banner` | 1 | 1 | — | `notify::active` wiring via `banner-change-mode` | ✓ | parity |
| `Adw.StatusPage` (home) | 1 | 1 | `icon-dropshadow` | `select-file` | ✓ | parity |
| `Adw.StatusPage` (loading) | 1 | 1 | — | — | ✓ | parity |
| `Adw.ToggleGroup` | 1 | 1 | — | `notify::active-name` | ✓ | parity |
| `Gtk.ListBox` | 1 | 1 | `boxed-list` | `row-activated` (via right-click gesture) | — | parity |
| `Gtk.Button`×3 (filechooser, clear, browse) | 3 | 3 | `suggested-action`, `pill` on browse | `clicked`→actions | ✓ | parity |
| `Gtk.MenuButton` (main menu) | 1 | 1 | — | menu model | ✓ | parity |
| `Gtk.DropTarget` (controller) | 1 | 1 | — | `drop` | — | parity |
| `Gtk.GestureClick` (controller) | 1 | 1 | — | `pressed` | — | parity |
| `Adw.AlertDialog` (folder-compress warning) | 1 dialog, 2 message branches | 1 call site, 2 branches | — | `response` | ✓ | parity |
| `Adw.AboutDialog` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.PopoverMenu` (context menu) | 1 | 1 | — | `open-image`/`open-folder` actions | ✓ | parity |

Menu: `win.shortcuts` vs upstream's `app.shortcuts` — a correspondence, not a
gap. GTK reserves `<Primary>question` for `app.shortcuts` on the window's own
`Gtk.Application`-subclass instance, which the Ruby bindings build as a plain
`Gtk::Application` rather than `Adw::Application` (binding limitation: Ruby
cannot subclass `Adw.Application`). The port moves the action and its
accelerator to the window instead, keeping the same label and menu position.
Confirmed at `lib/curtail_rb/window.rb:29-33` and `:548-551`, and both the
menu model and the shortcuts dialog (below) agree on the swap.

**Verdict: parity.**

## Unit: result item row — `data/ui/result-item-row.blp` + `src/result_item_row.py` → `lib/curtail_rb/result_item_row.rb`

| Widget | Up × | Port × | CSS | Signals/bindings | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.MenuButton`×2 (skipped/error info) | 2 | 2 (factored) | `flat` | `visible` bound to `skipped`/`error_details` | ✓ | parity |
| `Gtk.Label`×2 (savings, popover) | 2 | 2 | `success` on savings | bound to `savings`/`error_details_message` | ✓ | parity |
| `Adw.Spinner` | 1 | 1 | — | `visible` bound to `running` | — | parity |
| `Gtk.Image` (error) | 1 | 1 | `error` | `visible` bound to `error` | — | parity |
| `Gtk.Image` (thumbnail prefix) | conditional on `new_filename` | conditional, same guard | — | — | — | parity |

Upstream drives these with `GObject` property bindings (`bind_property`);
the port's `refresh` method sets the same seven widget states from the same
seven `ResultItem` properties, called once at build and again every time
`update_result_item` fires (`window.rb:263-274`). Confirmed by reading, not
just "has a method called refresh" — the call sites that mutate `ResultItem`
state (`compression_manager` callbacks) all route back through
`update_result_item`.

**Verdict: parity.**

## Unit: preferences dialog — `data/ui/preferences.blp` + `src/preferences.py` → `lib/curtail_rb/preferences_dialog.rb`

| Widget | Up × | Port × (real) | Signals | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Adw.SwitchRow`×6 | 6 | 6 | `notify::active` → settings write, via `switch_bindings` loop | ✓ | parity |
| `Adw.SpinRow`×6 | 6 | 6 | `notify::value` → settings write, via `spin_bindings` loop | ✓ | parity |
| `Adw.ComboRow` (naming mode) | 1 | 1 | `notify::selected` → settings write + `set_saving_subtitle` | ✓ | parity |
| `Adw.EntryRow` (suffix/prefix) | 1 | 1 | `changed` → settings write + `set_saving_subtitle` | ✓ | parity |

Safe-Mode re-sync (`sync_safe_mode`): toggling `new-file` upstream re-runs
`set_saving_subtitle`, `show_warning_banner`, and flips sensitivity on the
naming-mode combo and the suffix/prefix entry. The port's `sync_safe_mode`
(`preferences_dialog.rb:132-140`) does the same four things from the same
trigger.

**Verdict: parity.**

## Unit: shortcuts dialog — `data/ui/shortcuts-dialog.blp` (no backing source) → `lib/curtail_rb/shortcuts_dialog.rb`

4 `Adw.ShortcutsItem`s, same labels, same four action targets modulo the
documented `win.shortcuts`/`app.shortcuts` swap (see the main-window unit
above — both sides of that swap are consistent with each other).

**Verdict: parity.**

## Unit: application — `src/main.py` + `src/curtail.in` → `lib/curtail_rb/application.rb` + `exe/curtail-rb`

`do_startup`/`do_activate`/`do_open` ↔ `startup`/`activate`/`open` signals on
a `Gtk::Application` with explicit `Adwaita.init` (Ruby cannot subclass
`Adw.Application` — binding limitation, noted, not used to close any gap).

**Verdict: parity.**

## Unit: compression pipeline (non-UI, feeds the rows above)

`Compressor` + four format compressors, `CompressionManager`,
`ResultItemManager`, `SettingsManager`, `tools.py` → one Ruby file each.
Behaviour-checked against the drive suite (`test/drive_modes.rb`,
`test/drive_compression.rb`) and the unit suite (`test/units_test.rb`), both
green — see `.reports/test-parity.md`. No widget axis applies; restructuring
`Compressor` from a Python ABC into one module with four command builders is
a correspondence (same four external tool invocations, same flag logic),
confirmed by reading `lib/curtail_rb/compressor.rb` against
`src/compressor.py` and all four `src/compressors/*.py` files line by line.

**Verdict: parity.**

## The one gap this unit-by-unit pass does not surface

Component parity is scoped to widgets, and none of the six units above is
individually broken. But three **data files** that back no single widget
unit carry their own translatable strings, and the pipeline that is supposed
to keep them translated is incomplete — this is a gap that belongs to the
app as a whole rather than to any one unit, and it is documented in full in
`.reports/translation-parity.md` (the `po/POTFILES.in` exclusion of
`.gschema.xml`/`.desktop.in`/`.metainfo.xml.in`, and the absence of any
`.mo`-compile/install step). It does not fail any row in the tables above,
because none of those rows' widgets show this text — the GSettings schema's
`<summary>`/`<description>`, the desktop entry's `Name`/`Comment`, and the
metainfo's description are read by GNOME Settings, the shell's app chooser
and `dconf-editor`, not by any widget this port builds. Recorded here so a
reader of this ledger is not misled into thinking six parities add up to a
clean app; one more file-level finding sits outside the six units.

## Rules followed

- Every widget count difference the scan reported was read to a verdict
  (factory, loop, or conditional) before being called a parity or a gap —
  none were left as a bare number.
- The `win.shortcuts`/`app.shortcuts` swap is recorded once, with its binding
  reason, and not re-litigated per unit.
- No app-wide total substitutes for a per-unit verdict.
