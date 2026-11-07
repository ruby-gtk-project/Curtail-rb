# Curtail — Ruby port

This branch holds the Ruby GTK4 / Libadwaita port of Curtail. The upstream
Python implementation — the spec this port is measured against — is on the
`main` branch of this same repo; read it with `git show origin/main:<path>`.

See `README.md` for the layout and for the deliberate differences from
upstream.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Setup

`nix develop` gets Ruby, GTK4, Libadwaita, the introspection typelibs and the
five compressors the app shells out to (`oxipng`, `pngquant`, `jpegoptim`,
`cwebp`, `scour`). Gems come from `nix/gemset.nix`, not the root `gemset.nix`
— the root `Gemfile` carries a bare `gemspec` directive, and the Gemfile
bundlerEnv copies into the nix store for every rake/bundle/rubocop binstub
has no `.gemspec` file beside it there, so any of them crash with "There are
no gemspecs at ...gemfile-and-lockfile" the moment they run. `nix/Gemfile` is
the runtime-only bundle (no `gemspec` directive) that sidesteps this. After
changing the runtime gem list, regenerate `nix/Gemfile`/`nix/gemset.nix` from
`curtail-rb.gemspec` and `git add` the result — the flake reads them through
`bundlerEnv`, so an untracked `nix/gemset.nix` is invisible to Nix. Rubocop,
RSpec and Minitest are separate nixpkgs packages in the devshell (flake.nix),
not bundled gems, since `nix/Gemfile` is runtime-only.

`rake schema` compiles the GSettings schema into `tmp/share`, which the
devshell puts on `XDG_DATA_DIRS`. Without it `Gio::Settings.new` aborts the
process rather than raising.

## Running and testing

    ./bin/curtail-rb          # or with image paths as arguments
    rake                      # units, UI drives, locale drives, catalogues, rubocop
    rake drive                # headless UI runs; screenshots land in tmp/shots
    rake i18n                 # the same, in fr, es, de and zh_CN

Strings are marked with `_()`, `p_(context, text)` for upstream's `C_`, and
`N_()` where a literal lives in a constant and is looked up elsewhere. Keep the
literals at the call site — `rake pot` extracts with rxgettext, which cannot
see a string that reaches `_()` through a variable.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `rake lint` (or a bare `rubocop`) before
committing — not `bundle exec rubocop`: `BUNDLE_GEMFILE` in this devshell is
`nix/Gemfile`, the runtime-only bundle, which doesn't carry rubocop.
