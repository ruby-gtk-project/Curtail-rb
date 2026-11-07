# Test parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit, re-run against current `HEAD`) |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps (0/0 parity itself) | 0 |
| New finding this round | the documented single entry point, bare `rake`, is a no-op |

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

## The binstub/Bundler defect a previous round of this audit found: now fixed

An earlier `.reports/test-parity.md` on this branch (commit `8393a06`)
reported that every Nix-wrapped binstub in this devshell hardcoded
`BUNDLE_GEMFILE` to a store path whose generated `Gemfile` had a bare
`gemspec` directive and no `.gemspec` beside it, so `rake`/`bundle exec
rubocop`/etc. all died with "There are no gemspecs at
...gemfile-and-lockfile" before running anything. Commit `f6a417d` ("Fix
the gemspec-less devshell binstubs, and close the translation-catalogue
gap") changed `flake.nix` to build the devshell's `bundlerEnv` from
`nix/Gemfile` (runtime-only, no `gemspec` directive) instead of the root
Gemfile, and moved rubocop/rspec/minitest to plain nixpkgs packages.
Re-verified in this round:

```
$ nix develop --command rake -T
curtail-rb devshell — ruby 3.3.10
  rake schema           compile the GSettings schema into tmp/share
  ./bin/curtail-rb      run the app
  rake                  test + lint
NOTE: kettle-dev isn't installed, or is disabled for 3.3.10 in the current environment
rake build  ...
```

`rake -T`, `rake schema`, `rake test`, `rake drive`, `rake i18n`, `rake po`,
`rake pot`, `rake mo`, `rake merge_data` all now run through the documented
`nix develop` entry point without the Bundler crash. That part of the
earlier finding is resolved and this round confirms it by direct
reproduction, not by trusting the commit message.

## New finding this round: bare `rake` does not do what it is advertised to do

The devshell banner (printed by `nix develop` itself, reproduced above)
says `rake    test + lint`. `CLAUDE.md`/`AGENTS.md` on this branch says:

> `rake    # units, UI drives, locale drives, catalogues, rubocop`

Both describe the **bare, no-argument** `rake` invocation. Reading
`Rakefile:61-65`:

```ruby
# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end
```

Nothing in the rest of the 343-line `Rakefile` adds a prerequisite to
`:default` (confirmed with `grep -ni default Rakefile` — the only other two
hits are the comment line and the `rake -T` doc-comment above the method
table; no `Rake::Task[:default].enhance`, no `task default: [...]`
anywhere). Loading the Rakefile and inspecting the task object directly
confirms this is not a doc-comment slip:

```
$ nix develop --command ruby -e '
    require "rake"; load "Rakefile"
    puts Rake::Task[:default].prerequisites.inspect
    puts Rake::Task[:default].actions.length'
[]
1
```

Running it bears this out — bare `rake` prints one line and exits,
regardless of test or lint state:

```
$ nix develop --command xvfb-run -a rake
...
NOTE: kettle-dev isn't installed, or is disabled for 3.3.10 in the current environment
Default task complete.
```

The "NOTE: kettle-dev isn't installed" line is the tell: the comment
("Define a base default task early so other files can enhance it") expects
the `kettle-dev` gem to wire `test`/`lint` onto `:default` once it loads,
and in this devshell it does not load, so the enhancement never happens and
the stub is all that is left. **This means the one command the devshell
banner and the project's own `CLAUDE.md`/`AGENTS.md` tell a person to run
for "test + lint" runs neither.** A person (or an agent) who trusts the
banner and runs bare `rake` gets a false "complete" with zero checks
executed, and would have no reason to suspect anything is wrong — there is
no error, no missing-coverage warning, just a one-line success message.

## `rake lint` itself currently fails — outside `lib/`, but a real failure

`rake test` runs clean through the documented command now (see below), but
`rake lint` (`sh 'rubocop'`, scanning the whole repo tree — `.rubocop.yml`
excludes `tmp/**/*`, `pkg/**/*`, `vendor/**/*` etc. but not `gemfiles/` or
`spec/`) currently exits 1:

```
$ nix develop --command rake lint
...
87 files inspected, 99 offenses detected, 90 offenses autocorrectable
rake aborted!
Command failed with status (1): [rubocop]
```

Narrowed down: **every one of the 99 offenses is in `gemfiles/**` and
`spec/spec_helper.rb`** — gem-packaging scaffolding from the `kettle-jem`
template (predates the binstub fix; `git log -- spec/spec_helper.rb` shows
it landed in commit `90ed0cd`, well before `f6a417d`'s "all run clean"
claim), not in the ported app:

```
$ nix develop --command rubocop lib/ exe/
Inspecting 21 files
.....................
21 files inspected, no offenses detected
```

So the port's own code (`lib/`, `exe/`) is rubocop-clean, but `rake lint`
— the task the banner says bare `rake` runs — fails today. Commit
`f6a417d`'s message asserts "`rake schema/test/po/pot/lint/drive/i18n` and
`rake` all run clean"; `rake lint` does not, right now, on this tree, and
`rake` (bare) never even gets to try.

## What actually runs, and what it proves

Invoked exactly as the devshell/`AGENTS.md` instruct — `nix develop
--command xvfb-run -a <command>` — using the explicit per-task commands
(`rake test`, `rake drive`, `rake i18n`) since bare `rake` is a no-op:

```sh
nix develop --command xvfb-run -a rake test
nix develop --command xvfb-run -a rake drive
nix develop --command xvfb-run -a rake i18n   # runs the four-locale drive, uses the same 5 drive_*.rb scripts
```

Results, reproduced independently in this audit:

| Suite | Result |
|---|---|
| `rake test` → `test/units_test.rb` (Minitest, 44 methods) | 44 runs, 307 assertions, **0 failures, 0 errors, 0 skips** |
| `rake drive` → `test/drive_window.rb` | 5 of 5 checks passed, `DRIVE OK` |
| `rake drive` → `test/drive_compression.rb` | 34 of 34 checks passed, `DRIVE OK` |
| `rake drive` → `test/drive_dialogs.rb` | 41 of 41 checks passed, `DRIVE OK` |
| `rake drive` → `test/drive_modes.rb` | 23 of 23 checks passed, `DRIVE OK` |
| `rake drive` → `test/drive_i18n.rb` | 25 of 25 checks passed, `DRIVE OK` |

5 + 34 + 41 + 23 + 25 = **128 checks**, matching the runtime gate figure this
round (`drive_ok=true, 128 checks passed, 0 failed`, 7 components). That
figure is real and was independently reproduced in this audit via `rake
drive` directly (now that the binstub is fixed) — but it is **not** what a
person gets by running the one command the banner tells them to run. The
runtime gate passing is evidence about `rake drive`/`rake test`; it says
nothing about bare `rake`, and nothing in the gate's own numbers would
surface that bare `rake` (and therefore the documented default workflow) is
a no-op.

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
  cite its presence as evidence of coverage. It is also the source of 2 of
  the 99 `rake lint` offenses above.

## Rules followed

- Upstream's absence of tests is stated outright, not left as an implied
  pass.
- The "128 checks" figure is reported with the exact command used to
  reproduce it, not as a bare adjective, and is explicitly distinguished
  from what bare `rake` produces.
- The previously reported binstub defect was re-verified rather than
  assumed fixed on the strength of the commit message that claimed to fix
  it — and that same commit's "all run clean" claim is checked line by
  line, finding one part true (`rake test`/`rake drive`/`rake schema`) and
  one part still false (`rake lint`, and bare `rake` never reaching either).
- A narrow, reproducible scope (`rubocop lib/ exe/`) is used to separate the
  port's own code quality (clean) from the scaffold files failing lint
  (not clean), so the finding is not overstated into "the port fails lint."
