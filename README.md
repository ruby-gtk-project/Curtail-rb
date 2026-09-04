# Curtail — Ruby port

A Ruby GTK4 / Libadwaita port of [Curtail](https://github.com/Huluti/Curtail),
Hugo Posnic's image compressor. It compresses PNG, JPEG, WebP and SVG by
driving the same external tools upstream does — `oxipng`, `pngquant`,
`jpegoptim`, `cwebp` and `scour`.

Feature parity with upstream is the goal: every view, dialog, menu item,
keyboard shortcut, preference, action, error state and translation the
original has.

## Running

```sh
nix develop          # Ruby, GTK4, Libadwaita, and the five compressors
rake schema          # compile the GSettings schema into tmp/share
./bin/curtail-rb     # or: ./bin/curtail-rb some-image.png
```

`nix run .` builds and runs the packaged app, which carries its own compiled
schema and puts the compressors on `PATH`.

## Tests

```sh
rake                 # units, then the UI drives, then rubocop
rake test            # minitest: filenames, commands, timeouts, formatting
rake drive           # runs the app headlessly and drives its UI
rake lint            # rubocop, including the custom cops in cops/
```

`rake drive` writes screenshots to `tmp/shots/`. They are the point — read
them.

## Layout

| Path | What |
|------|------|
| `bin/curtail-rb` | entry point |
| `lib/curtail_rb/application.rb` | `Gtk::Application`, activate and open handlers |
| `lib/curtail_rb/window.rb` | the main window: header bar, banner, home/loading/results views |
| `lib/curtail_rb/preferences_dialog.rb` | the two-page preferences sheet |
| `lib/curtail_rb/result_item.rb` | one row's state |
| `lib/curtail_rb/result_item_manager.rb` | Gio::File → ResultItem, destination and temp paths |
| `lib/curtail_rb/result_item_row.rb` | the row widget |
| `lib/curtail_rb/compressor.rb` | the four command builders and the run/collect cycle |
| `lib/curtail_rb/compression_manager.rb` | one worker per core, reporting on the main loop |
| `lib/curtail_rb/settings.rb` | GSettings accessors |
| `lib/curtail_rb/tools.rb` | thumbnails, file filters, directory walks, version probing |
| `data/` | GSettings schema, icons, desktop entry |

## Translations

All 40 of upstream's catalogues ship, and the app reads `po/*.po` directly —
there is no gettext binding in the Ruby GTK stack and no msgfmt step, so the
files the translators wrote are the files that ship. The desktop entry and the
metainfo do get the usual `msgfmt` merge at build time, so the app's name,
comment and keywords are localised in the shell too.

Marking follows gettext's own names, which is what `rake pot` needs to see:

| Call | Means |
|------|-------|
| `_('Preferences')` | translate |
| `p_('shortcuts dialog', 'General')` | translate in a context (upstream's `C_`) |
| `N_('Suffix')` | mark for extraction; a `_()` at the point of use translates |

    rake i18n      # drive the UI in fr, es, de and zh_CN
    rake po        # msgfmt --check every catalogue
    rake pot       # regenerate po/curtail.pot from the Ruby sources
    rake merge     # merge that template into every catalogue

Two messages translate here that do not upstream. Upstream builds them with
f-strings and then calls gettext, so the finished sentence never matches a
msgid; here the placeholder form is looked up and the value substituted after.
That is what the translators who wrote `{}` and `{suffix_prefix}` into their
catalogues meant to happen.

## Differences from upstream

- **Structure.** Upstream's abstract `Compressor` plus four subclasses is one
  module with four command builders here, and the GObject property bindings
  between `ResultItem` and its row are an explicit `refresh`. No behaviour
  changes either way.
- **Two upstream bugs are not reproduced.** A drop carrying no files, and a
  directory containing no images, leave upstream stuck on the "Analyzing
  Images" view; this port returns to whichever view it came from.
- **Error details show the tool's own output.** Upstream's info popover
  displays Python's `CalledProcessError` string ("Command '…' returned
  non-zero exit status 1"); this port shows what the compressor actually
  printed, which is what you need to know.
- **Compression timeouts kill the child.** Upstream's `subprocess` timeout
  does too; the naive Ruby translation (`Timeout.timeout`) would not, so the
  deadline is enforced by joining the wait thread and killing the process.
