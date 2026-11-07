# Test parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit) |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

## Upstream has no test suite

Verified directly on an `origin/main` worktree:

- `find <upstream> -iname '*test*'` returns nothing.
- `test-census.sh <upstream>` (GLib `Test.add_func`, Python `unittest`/
  `pytest`, GJS Jasmine, Rust `#[test]`, Ruby `test_*`/`it`/`check`) returns
  **zero rows**.
- `pyproject.toml`, `meson.build` and both `.github/workflows/*.yml` have no
  test target, no `pytest` invocation, no `testpaths`.

Parity is 0/0 and is met trivially. **The port therefore inherits no safety
net from upstream** — every check the port runs was written for the port and
pins nothing upstream itself considered worth pinning down.

## What the port actually runs, and whether it runs

This is the part a 0/0 census must not let slide. The repo advertises a
single blessed command — the `nix develop` banner literally says
`rake    test + lint` — and **that command does not work**:

```
$ nix develop --command xvfb-run -a rake
...
/nix/store/.../bundler-2.7.2/.../dsl.rb:88:in `gemspec':
[!] There was an error parsing `Gemfile`: There are no gemspecs at
/nix/store/la7sgpmcsbbf06s5v6arqzyl64a1ff9h-gemfile-and-lockfile.
Bundler cannot continue.
```

Every Nix-wrapped binstub in this devshell hardcodes
`ENV["BUNDLE_GEMFILE"]` to a store path whose generated `Gemfile` still has
a bare `gemspec` directive but ships without the `.gemspec` file it points
at. This is **not overridable from the calling shell** — the binstub sets
the variable itself, after any shell export. Confirmed broken for every one
of: `rake` (bare), `rake -T`, `rake schema`, `bundle exec rake schema`,
`bundle exec rubocop`. This means, as shipped, **nobody can run `rake test`,
`rake drive`, `rake i18n`, `rake po`, `rake lint`, or `rake schema` through
the documented entry point** in this devshell. That is a devshell/flake
packaging defect, not a port-code defect, and it is reported here rather
than filed as a parity gap because it sits in `flake.nix`/`gemset.nix`, not
in `lib/`. But it is exactly the kind of thing this skill exists to catch:
a drive or test run that nobody can reproduce through the advertised
command is unverified, regardless of what a status line elsewhere claims.

**Worked around for this audit** by stepping around the broken binstubs:
schema compiled by hand (`glib-compile-schemas` directly, mirroring the
`rake schema` task's two lines) and each suite invoked directly with `ruby`:

```sh
nix develop --command bash -c 'mkdir -p tmp/share/glib-2.0/schemas && \
  cp data/com.github.huluti.Curtail.Rb.gschema.xml tmp/share/glib-2.0/schemas/ && \
  glib-compile-schemas tmp/share/glib-2.0/schemas'

nix develop --command xvfb-run -a ruby -Ilib -Itest test/units_test.rb
nix develop --command xvfb-run -a ruby test/drive_window.rb
nix develop --command xvfb-run -a ruby test/drive_compression.rb
nix develop --command xvfb-run -a ruby test/drive_dialogs.rb
nix develop --command xvfb-run -a ruby test/drive_modes.rb
nix develop --command xvfb-run -a ruby test/drive_i18n.rb
```

Results, reproduced independently in this audit:

| Suite | Result |
|---|---|
| `test/units_test.rb` (Minitest, 44 methods) | 44 runs, 307 assertions, **0 failures, 0 errors, 0 skips** |
| `test/drive_window.rb` | 5 of 5 checks passed, `DRIVE OK` |
| `test/drive_compression.rb` | 34 of 34 checks passed, `DRIVE OK` |
| `test/drive_dialogs.rb` | 41 of 41 checks passed, `DRIVE OK` |
| `test/drive_modes.rb` | 23 of 23 checks passed, `DRIVE OK` |
| `test/drive_i18n.rb` | 25 of 25 checks passed, `DRIVE OK` |

5 + 34 + 41 + 23 + 25 = **128 checks**, matching the runtime gate figure this
round (`drive_ok=true, 128 checks passed, 0 failed`). That figure is real
and independently reproducible — but only by bypassing `rake`, which is the
only command the repo tells a person to run.

## Extra (not part of any upstream count, since upstream has none)

- `test/units_test.rb` — 44 Minitest methods covering settings accessors,
  the four compressors' command construction, `result_item_manager`
  naming/mime logic, `tools.rb` (sizeof_fmt, version extraction, scaled
  size), and the `i18n.rb` PO parser (fuzzy/obsolete/context/multiline
  handling, LINGUAS-vs-po-files agreement).
- `test/drive_window.rb`, `drive_compression.rb`, `drive_dialogs.rb`,
  `drive_modes.rb`, `drive_i18n.rb` — 128 headless UI checks driving the
  real window, dialogs, preferences, shortcuts, drag-and-drop, folder
  recursion, timeouts, and four non-English locales.
- `spec/` contains only `spec_helper.rb` and a `README.md` — **no actual
  RSpec example files exist**. `rake spec` would run zero examples. This is
  not a parity gap (upstream has no RSpec suite to port either) but it is
  worth recording plainly: the `spec/` directory is scaffolding from the
  gem template (`kettle-jem`), not a second test suite, and nothing should
  cite its presence as evidence of coverage.

## Rules followed

- Upstream's absence of tests is stated outright, not left as an implied
  pass.
- The "128 checks" figure is reported with the exact command used to
  reproduce it, not as a bare adjective.
- The broken `rake`/`bundle` binstub is reported as a finding in its own
  right rather than silently worked around and left unmentioned.
