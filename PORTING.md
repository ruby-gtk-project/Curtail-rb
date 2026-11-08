# Curtail-rb — port status

## Upstream

Curtail, implemented in Python/GTK4/Libadwaita. Spec is the `origin/main`
ref of this same repo (`ruby-gtk-project/Curtail-rb`), currently at
`1536d90`. The port is written from scratch against that ref as the spec;
`origin/main` is never checked out or merged into `ruby`.

## Done

Components implemented and observed working (via `rake test` and/or
`rake drive`/`rake i18n`, re-run this session):

| `lib`/`exe` path | Ported from |
|---|---|
| `lib/curtail_rb/application.rb`, `exe/curtail-rb` | `src/main.py` + `src/curtail.in` |
| `lib/curtail_rb/window.rb` | `src/window.py` + `data/ui/window.blp` |
| `lib/curtail_rb/result_item_row.rb` | `src/result_item_row.py` + `data/ui/result-item-row.blp` |
| `lib/curtail_rb/result_item.rb` | `src/result_item.py` |
| `lib/curtail_rb/result_item_manager.rb` | `src/result_item_manager.py` |
| `lib/curtail_rb/preferences_dialog.rb` | `src/preferences.py` + `data/ui/preferences.blp` |
| `lib/curtail_rb/shortcuts_dialog.rb` | `data/ui/shortcuts-dialog.blp` |
| `lib/curtail_rb/settings.rb` + `data/com.github.huluti.Curtail.Rb.gschema.xml` | `src/settings_manager.py` + upstream gschema (all 15 keys) |
| `lib/curtail_rb/compression_manager.rb` | `src/compression_manager.py` |
| `lib/curtail_rb/compressor.rb` | `src/compressor.py` |
| `lib/curtail_rb/compressors/png_compressor.rb` | `src/compressors/png_compressor.py` |
| `lib/curtail_rb/compressors/jpeg_compressor.rb` | `src/compressors/jpeg_compressor.py` |
| `lib/curtail_rb/compressors/webp_compressor.rb` | `src/compressors/webp_compressor.py` |
| `lib/curtail_rb/compressors/svg_compressor.rb` | `src/compressors/svg_compressor.py` |
| `lib/curtail_rb/tools.rb` | `src/tools.py` |
| `data/com.github.huluti.Curtail.Rb.desktop` | `data/com.github.huluti.Curtail.desktop.in` |
| `data/com.github.huluti.Curtail.Rb.metainfo.xml` | `data/com.github.huluti.Curtail.appdata.xml.in` |
| `po/*.po`, `po/LINGUAS`, `po/extract_data_strings.rb`, `rake mo`/`rake merge_data` | `po/*.po` + upstream's Meson `i18n.merge_file` step (40 locales, verified producing `Comment[xx]=`/`xml:lang` output) |

`.reports/component-parity.md` records all 6 UI units (window, result-item
row, preferences dialog, shortcuts dialog, application, compression
pipeline) at parity on count/style/behaviour/text/CSS/signals, re-checked
against `origin/main` @ `1536d90`.

## Runtime

Commands (per the devshell banner and `AGENTS.md`; bare `rake` only runs
`test`+`lint`, not the drive suites — `rake drive`/`rake i18n` must be
invoked by name):

```
nix develop --command xvfb-run -a rake test
nix develop --command xvfb-run -a rake drive
nix develop --command xvfb-run -a rake i18n
```

Re-run this session, fresh:

- `rake test` → `test/units_test.rb`: 44 runs, 307 assertions, **0
  failures, 0 errors, 0 skips**.
- `rake drive` → exited 0 this run, all 5 drive scripts reporting
  `DRIVE OK` (`drive_window.rb` 5/5, `drive_compression.rb` 34/34,
  `drive_dialogs.rb` 41/41, `drive_modes.rb` 23/23, `drive_i18n.rb` 25/25
  per `.reports/test-parity.md`'s most recent full tally) = **128 checks
  passed, 0 failed, across 5 drive files covering 9 logical components**
  (window, result-item row, preferences dialog, shortcuts dialog,
  application, compressor pipeline, compression manager, result-item
  manager, settings) — **not** 123/12 as a prior handoff claimed; that
  figure does not reproduce (see Open gaps).
- drive_ok=true for this run.

## Not started

None. Every upstream source file (`src/*.py`, `src/compressors/*.py`,
`data/ui/*.blp`, the gschema, desktop entry, appdata/metainfo, and `po/*`)
has a corresponding `lib/`, `exe/`, `data/`, or `po/` counterpart on
`ruby`, per `.reports/component-inventory.md`.

## Open gaps

`.reports/` flags 1 open gap (clean=false), from
`.reports/accountability-ensurance.md` and `.reports/test-parity.md`:

- **`rake drive` is flaky, not deterministic.** `test/drive_compression.rb`
  (lines 31-45) waits a *fixed* ~1.4s interval for the compressors to
  finish instead of polling `row.item.running == false`. WebP (via
  `cwebp`) is the slowest of the four fixture formats; when it has not
  finished in that window, `shape.webp: not running`,
  `shape.webp: reported an outcome`, and `controls re-enabled` fail
  together. Reproduced at a rate of roughly 1 run in 4 across repeated
  back-to-back `rake drive` invocations on an unchanged tree (per
  `.reports/test-parity.md`); this session's own single re-run passed
  (128/128, `DRIVE OK` x5), consistent with that reported rate rather than
  contradicting it. This is a test-harness timing defect in the port's own
  UI driver, not a missing or incorrect widget behavior — the underlying
  compression itself completes correctly every time, confirmed by later
  steps in the same run. A `drive_ok=true` read from any single run is not
  sufficient evidence on its own; the flaky step still needs to be
  rewritten to poll for completion instead of sleeping a fixed interval.

All previously-reported gaps on this branch are closed and re-verified
this session or in the most recent `.reports/` round: the translation
catalogue pipeline (`.gschema.xml`/`.desktop.in`/`.metainfo.xml.in`
strings now flow through `po/extract_data_strings.rb` + `rake
mo`/`rake merge_data`), the devshell's gemspec-less Bundler crash, bare
`rake` being a no-op, `rake lint`'s 99 offenses, and the bare-`rake`
doc-scope mismatch (`CLAUDE.md`/`AGENTS.md` now correctly scope bare
`rake` to "schema compile, `.mo` compile, unit tests, rubocop" only).

## Blockers

None that block the port outright. One documented binding limitation,
already designed around rather than blocking anything: the Ruby GTK4
bindings cannot subclass `Adw.Application`, so `lib/curtail_rb/application.rb`
builds a plain `Gtk::Application` with explicit `Adwaita.init`, and the
`app.shortcuts` action/accelerator (reserved by GTK for the
`Gtk.Application`-subclass instance upstream uses) is moved to
`win.shortcuts` on the window instead — same label, same menu position,
consistent on both sides of the swap (`lib/curtail_rb/window.rb:29-33,548-551`
and `lib/curtail_rb/shortcuts_dialog.rb`).
