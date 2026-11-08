# Test parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit, re-run against current `HEAD`) |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps (0/0 parity itself) | 0 |
| New finding this round | the previous round's doc-drift gap is now closed (`0464774` narrowed the docs to match `f5d2338`'s fix). A new, more serious finding replaces it: `rake drive` is **flaky**, not deterministic — 1 of 4 back-to-back runs this round failed 3 of 34 checks in `test/drive_compression.rb` (`shape.webp: not running`, `shape.webp: reported an outcome`, `controls re-enabled`) on an otherwise-unchanged tree, before the aborted task could even reach `drive_dialogs.rb`/`drive_i18n.rb`/`drive_modes.rb`/`drive_window.rb`. A "drive_ok=true" read from any single run is not a safe signal. |

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

## Re-audit of this round: the previously-reported `rake`/`rake lint` gap is now closed

This file previously (as committed at `182dbf6`) reported two live gaps:
bare `rake` being a no-op (`task :default do puts "Default task complete."
end`, zero prerequisites) and `rake lint` failing with 99 rubocop offenses.
Commit `f5d2338` ("Make bare `rake` run test+lint and fix `rake lint` to
exit clean"), made on this branch after that report was written and before
this round's audit, addresses both. Re-verified directly in this round,
not from the commit message:

```
$ nix develop --command rake -P
rake default
    test
    lint
```

```
$ nix develop --command xvfb-run -a rake
...
44 runs, 307 assertions, 0 failures, 0 errors, 0 skips
rubocop
Inspecting 44 files
............................................
44 files inspected, no offenses detected
```

Bare `rake` now runs the Minitest suite and rubocop and exits 0 on a clean
tree, and `rake lint` run by its full name also exits 0 (the fix excludes
`gemfiles/**` and `spec/spec_helper.rb` — kettle-jem scaffolding, not
`lib/`/`exe/` — in `.rubocop.yml`, matching the pattern of the other
vendored excludes already there, rather than suppressing the app's own
offenses). **Both halves of the previous round's finding are closed.**

## New finding this round: bare `rake`'s fix is narrower than what it is still documented to do

`CLAUDE.md`/`AGENTS.md` (unchanged by `f5d2338`) still say:

```
rake                      # units, UI drives, locale drives, catalogues, rubocop
```

i.e. five things. `rake -P` (above) shows `default` depends on exactly
`test` and `lint` — and `test` itself (`Rakefile:215`,
`Rake::TestTask.new(test: [:schema, :mo])`) depends on `schema` and `mo`
only:

```
rake test
    schema
    mo
```

`rake drive` (headless UI drives) and `rake i18n` (locale drives) are
**not** transitive dependencies of `default` or `test` anywhere in the
Rakefile — confirmed with `rake -P` showing `rake drive` and `rake i18n` as
their own independent root tasks, and with `grep -n enhance Rakefile`
finding no further enhancement of `:default` anywhere. Running bare `rake`
(reproduced above) compiles the schema and the `.mo` catalogues, runs the
44 Minitest methods, and runs rubocop — it does not open the app, drive
any UI, take any screenshot, or exercise any of the four non-English
locales. `rake pot`/`rake po`/`rake merge`/`rake merge_data` (catalogue
*regeneration* and *merge*, as opposed to the `mo` *compile* step `test`
already pulls in) are likewise independent tasks bare `rake` never
reaches.

So the five-item claim ("units, UI drives, locale drives, catalogues,
rubocop") is now 2.5/5 true of the bare command: units — yes; rubocop —
yes; catalogues — partially (`mo` compile only, not `pot`/`po`/`merge`);
UI drives — no; locale drives — no. This is a smaller instance of exactly
the pattern the previous round found (a doc/banner claim about what bare
`rake` does, not checked against what it actually does after the fix that
was supposed to settle it) — the fix closed the "runs nothing" gap without
closing the "runs everything documented" gap. The 128-check drive-suite
figure below is real, and is independently reproduced by this audit, but
it is **not** produced by the command the project's own docs tell a person
to run.

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

## Historical: the state as of the previous round (`182dbf6`), now superseded

The previous round's report, verbatim at that point in time, found bare
`rake` printing `Default task complete.` and exiting having run nothing
(`task :default do puts ... end`, zero prerequisites — `Rake::Task[:default]
.prerequisites` was `[]`), and `rake lint` failing with 87 files inspected,
99 offenses, all in `gemfiles/**`/`spec/spec_helper.rb`. **Both are fixed as
of commit `f5d2338`**, re-verified above in this round's own section, not
carried forward from that commit's message. This subsection is kept only so
the "false green → fix → re-check" history is visible in one file; it is
not this round's live finding (that is the "narrower than documented"
finding above).

## What actually runs, and what it proves

Invoked exactly as the devshell/`AGENTS.md` instruct — `nix develop
--command xvfb-run -a <command>` — using the explicit per-task commands
(`rake test`, `rake drive`, `rake i18n`) since bare `rake` does not reach
`drive` or `i18n` (see above):

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
round (`drive_ok=true, 128 checks passed, 0 failed`, stated this round as
covering 9 components). That figure is real and was independently
reproduced in this audit via `rake drive`/`rake i18n` directly. Counting
the port's own logical components — window, result-item row, preferences
dialog, shortcuts dialog, application, the compressor pipeline
(`Compressor` + 4 format subclasses), compression manager, result-item
manager, and settings (9 in total, matching the gate) — every one of them
is exercised by at least one of the five drive scripts or by
`units_test.rb` (settings accessors, compressor command construction,
result-item-manager naming/mime logic are unit-tested directly; window,
dialogs, preferences, shortcuts and the live compression pipeline are
drive-tested). None of the 9 is a component the check count merely
"covers" on paper without a check actually touching it. (A previous round
of this same report cited "7 components" for the identical 128/0 figure;
this round could not find a basis for either number inside the repo itself
— no file in this tree uses the word "component" — so both are read as the
external harness's own count, re-derived here independently against the
9 logical units above rather than carried forward unchecked.)

That figure is **not**, however, what a person gets by running the one
command the banner and `CLAUDE.md`/`AGENTS.md` tell them to run for
"UI drives, locale drives" — see the finding above. The runtime gate
passing is evidence about `rake drive`/`rake i18n`/`rake test` invoked by
full name; it says nothing about bare `rake`, which does not reach either
drive task.

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

## New this round: `rake drive` is flaky, so "drive_ok=true" from one run is not evidence

The task handing off this round's audit asserted a runtime gate of
"drive_ok=true, 123 checks passed, 0 failed, covering 12 components."
Neither number matches what `rake drive` actually produces on this tree:
counting the `N of N checks passed` line printed by each of the 5
`test/drive_*.rb` files gives 34 + 41 + 25 + 23 + 5 = **128** checks (not
123), across 5 drive files, not 12 "components" (the previous round's
report already reconciled a similarly-off "9 components" claim the same
way — see "Rules followed" below). Taken alone this is a minor number
mismatch upstream of this audit and not charged against the port.

The finding that *is* charged against the port: `rake drive` was run 4
times this round, back to back, on an unchanged tree (`git diff` against
the prior report's commit touches only `AGENTS.md`):

| Run | Result |
|---|---|
| 1 (no `xvfb-run`, misconfigured) | `Gtk::InitError` — not a port defect, an invocation mistake, excluded from the tally |
| 2 (`xvfb-run`) | **FAILED** — `test/drive_compression.rb`: 31 of 34 checks passed; `shape.webp: not running` and `shape.webp: reported an outcome` both failed (the row was still mid-compression when checked), `controls re-enabled` failed too (same root cause: the filechooser button stays disabled while a row is still running). Rake aborted on this failure, so `drive_dialogs.rb`, `drive_i18n.rb`, `drive_modes.rb` and `drive_window.rb` never ran this attempt — a failed `drive_compression.rb` run silently withholds 94 other checks from ever executing, not just from passing. |
| 3 (`xvfb-run`) | 34/34, 41/41, 25/25, 23/23, 5/5 — all 128 checks passed, `DRIVE OK` x5 |
| 4 (`xvfb-run`) | 34/34, 41/41, 25/25, 23/23, 5/5 — all 128 checks passed, `DRIVE OK` x5 |

Root cause, read at `test/drive_compression.rb:31-45`: the script waits a
*fixed* interval (`d.step('wait for the compressors') { nil }` /
`d.step('still waiting') { nil }`, two steps at the driver's 700ms
interval = ~1.4s) and then asserts every row finished, rather than polling
until `row.item.running == false` for all rows. WebP compression (shelling
out to `cwebp`) is the slowest of the four formats in the fixture set, so
whenever the subprocess runs slower than the fixed wait — one run in this
sample, roughly matching a 1-in-4 rate on this machine — the row is still
`running` when checked and three checks fail together (the two
`shape.webp` checks plus `controls re-enabled`, which gates on the same
"any row still running" state). This is a test-harness timing bug, not a
missing or wrong port behavior: the actual compression completes correctly
every time (confirmed by the later steps in the same run, which re-check
file output after an explicit additional wait and always pass). It is
reported here because a flaky gate is not a passing gate — a 123/0 or
128/0 headline from a single run cannot be trusted as the port's
steady-state result, and `accountability-ensurance.md` treats re-asserting
that headline without re-running it as a false-green risk in its own
right.

## Rules followed

- Upstream's absence of tests is stated outright, not left as an implied
  pass.
- The "128 checks" figure is reported with the exact command used to
  reproduce it, not as a bare adjective, and is explicitly distinguished
  from what bare `rake` produces.
- The previously reported binstub defect and the previous round's bare-`rake`/
  `rake lint` findings were re-verified directly (`rake -P`, a fresh `rake`
  and `rake lint` run) rather than assumed fixed on the strength of the fix
  commit's own message.
- The fix commit (`f5d2338`) is itself checked against the docs it was
  meant to make true, rather than treated as the end of the story: it is
  confirmed fixed where it says it fixed something, and a narrower,
  still-live gap (bare `rake` vs. the five-item doc claim) is reported
  separately rather than folded into either "still broken" or "fully
  fixed."
- The "9 components" figure in this round's gate is reconciled against the
  port's own logical units rather than repeated verbatim; the previous
  round's differing "7" is named but not silently carried forward.
- This round's "123 checks / 12 components" gate claim is checked against
  a freshly counted, freshly run total (128, 5 files) rather than repeated;
  the discrepancy is named rather than smoothed over.
- `rake drive` was run 4 times, not once, specifically because a
  single-run "it passed" is not evidence for a UI driver that shells out
  to real image-compression subprocesses on a fixed timer. The failure
  this surfaced is reported with its reproduction rate and root cause, not
  dismissed as a one-off.
