# Accountability ensurance — Curtail-rb

## What was scanned

```sh
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
grep -rniE "TODO|FIXME|not implemented|for now|in a future|future version|placeholder only|stub\b" lib/ exe/ .reports/
```

plus a hand read of `po/POTFILES.in`, the `Rakefile`, `lib/curtail_rb/i18n.rb`,
and every file in `.reports/` — treated as documents under review this
round, not as authority, including the very reports this audit itself
updates.

## Automated scan results this round

```
.reports/component-parity.md:48:skipped:...
.reports/translation-parity.md:69:by design:...
.reports/component-inventory.md:36:N/A:...
.reports/component-inventory.md:23-24:skipped:...
.reports/accountability-ensurance.md:...  (quotes of the excuse being refuted, below)
lib/curtail_rb/i18n.rb:147:not required:...
```

Every hit is either (a) inside `.reports/`, where it is this skill's own
or a sibling skill's prose *about* a finding — quoting an excuse to refute
it is not committing one — or (b) `lib/curtail_rb/i18n.rb:147`, re-checked
this round and still a false positive: it describes PO file grammar ("PO
files are not required to separate entries with a blank line"), not a
skipped feature. **No excuse was found live in `lib/`, `exe/`, or in
`po/POTFILES.in`'s own comments this round** — the one real excuse this
audit's predecessor found there (`po/POTFILES.in` claiming the
schema/desktop/metainfo strings were "already in the catalogues") is gone
from the file (`grep -n "already in the catalogues" po/POTFILES.in` →
no match), because the gap it was excusing is now actually fixed (see
`.reports/translation-parity.md`): the comment was removed along with the
problem, not left behind as a stale justification for a now-nonexistent
state. That is the correct order of operations, and it is recorded here
because the opposite order — fix the comment, leave the gap — is the
failure mode this skill exists to catch.

No `TODO`, `FIXME`, "not implemented", "for now", "in a future", or
"placeholder" string exists anywhere in `lib/`, `exe/`, or `.reports/`.

## What a human read caught that the automated scan does not cover: the `rake`/banner mismatch, fixed once, still partly true

The scan's pattern set matches sentences that excuse *not building*
something. It has no pattern for a sentence that is simply false about
what a command does. A previous round of this audit found exactly that:
bare `rake` was a no-op (`task :default` with zero prerequisites) despite
the devshell banner and `CLAUDE.md`/`AGENTS.md` calling it "test + lint" /
"units, UI drives, locale drives, catalogues, rubocop", and `rake lint`
itself exited 1.

Commit `f5d2338` ("Make bare `rake` run test+lint and fix `rake lint` to
exit clean"), landed on this branch after that round and before this one,
fixes both: `task default: [:test, :lint]`, and `.rubocop.yml` now excludes
the `gemfiles/**`/`spec/spec_helper.rb` scaffolding that caused `rake
lint`'s 99 offenses. Re-run fresh this round, not trusted from the commit
message:

```
$ nix develop --command xvfb-run -a rake
...
44 runs, 307 assertions, 0 failures, 0 errors, 0 skips
rubocop
44 files inspected, no offenses detected
```

**Both halves of the previous finding are genuinely fixed.** This is the
correct order of operations the previous round asked for — the doc claim
("test + lint") and the code's actual behavior were brought into line by
changing the code, not the claim.

What this round found is that the fix did not go far enough to make the
*other* half of the same doc sentence true. `CLAUDE.md`/`AGENTS.md` still
says bare `rake` is "units, UI drives, locale drives, catalogues,
rubocop" — five things. `rake -P` shows `default`'s only prerequisites are
`test` (itself depending only on `schema` and `mo`) and `lint`; `rake
drive` and `rake i18n` are independent root tasks bare `rake` never
reaches. So of the five things the docs promise, bare `rake` delivers
units and rubocop, partially delivers "catalogues" (compiles `.mo`, never
regenerates `.pot` or merges), and does not deliver UI drives or locale
drives at all — confirmed by running bare `rake` and observing no window
is ever created, no screenshot is ever taken, no locale other than the
process's own is touched. Full detail and the exact `rake -P` output are
in `.reports/test-parity.md`.

Per the skill's required form, for this round's finding:

> I fixed `rake`'s default task to actually run `test` and `lint`, but I
> never went back and checked it against the *rest* of the sentence the
> banner and `CLAUDE.md`/`AGENTS.md` make about the same command — "UI
> drives, locale drives, catalogues" — because I am an idiot, and a
> partial fix that makes the command stop erroring reads, at a glance, like
> the whole claim is now true.
>
> Upstream: has no Rake/Make default task at all to compare against — this
> is a port-side-only claim, checked against the port's own documentation
> of itself.
>
> Port: `Rakefile:65` — `task default: [:test, :lint]`; `Rakefile:215` —
> `Rake::TestTask.new(test: [:schema, :mo])`. `CLAUDE.md`/`AGENTS.md` still
> say bare `rake` is "units, UI drives, locale drives, catalogues,
> rubocop". It is units + rubocop + a `.mo` compile, not UI drives, not
> locale drives, not catalogue regeneration. `rake drive` and `rake i18n`
> exist and work when invoked by full name (confirmed, 128/128 checks,
> `DRIVE OK` — see `.reports/test-parity.md`) — but nothing invokes them
> for you from the bare command the docs describe as covering them.

## Three rounds of the same pattern, each time narrower: translation (closed), bare-`rake` crash (closed), bare-`rake` scope (still open)

A previous `.reports/accountability-ensurance.md` on this branch (commit
`8393a06`) recorded two false-greens: (1) `.reports/component-inventory.md`
citing the translation catalogue as "Yes" without checking the `.pot`
count, and (2) that same report's closing "No blocking gaps were found"
line, written before `rake` itself was confirmed broken (a Bundler crash
at the time). A later round (commit `182dbf6`) re-checked both: (1) was
resolved correctly — the translation pipeline was built and verified by
running it, and the excusing `po/POTFILES.in` comment was removed along
with the problem it excused, not left standing; (2) the Bundler crash was
fixed (`f6a417d`), but the fix only made bare `rake` *run*, not run
`test`/`lint` — the command went from "crashes, so obviously not
test+lint" to "succeeds silently, plausibly test+lint, actually a no-op."

This round re-checked (2) again. Commit `f5d2338`, made between that round
and this one, wires `test` and `lint` onto `:default` and fixes `rake
lint`'s own 99 offenses — re-verified fresh above, not trusted from the
commit message. **That specific false-green is now closed**: bare `rake`
genuinely runs the unit suite and rubocop and exits 0 only when both pass.

But the pattern recurred a third time, one layer narrower: the fix was
scoped to make the *banner's* three-word claim ("test + lint") true, and
it does. It was never checked against the *longer* claim in
`CLAUDE.md`/`AGENTS.md` ("units, UI drives, locale drives, catalogues,
rubocop") that describes the exact same bare command. That claim is still
only partly true today — see above. Each round's fix closed exactly the
gap the previous round named and no more, and each round's audit found
that "no more" left something behind. This round's finding is written up
so that the *next* fix (wiring `drive`/`i18n` onto `default`, or — more
honestly — narrowing the docs to match what `default` actually does) gets
checked the same way: by running the bare command and the full doc claim
side by side, not by reading the diff that claims to fix it.

## This round: the bare-`rake` scope gap is closed; a fourth round, same pattern, surfaces one layer further in

Commit `0464774` ("Narrow bare-rake docs to what `default` actually
runs"), landed after the round above and before this one, closes the
still-open half: `AGENTS.md` now says bare `rake` runs "schema compile,
`.mo` compile, unit tests, rubocop" and names `rake drive`/`rake i18n`/
`rake pot`/`po`/`merge` as separate commands bare `rake` does not reach —
checked directly against this round's `rake -P` output (`.reports/test-parity.md`),
not trusted from the commit message. `CLAUDE.md` was already in that
narrower form. **The bare-`rake` doc-scope false-green, chased across
three rounds, is now genuinely closed.**

The fourth round of the same pattern — a claim repeated without being
re-run — showed up this round in a different place: this audit's own
task handoff. The runtime gate it was given states "drive_ok=true, 123
checks passed, 0 failed, covering 12 components" as a fact to audit
against, not as a command to re-run. Re-running it (see
`.reports/test-parity.md`) found that number does not reproduce (the
actual, fresh count is 128 checks across 5 drive files, not 123/12), and
more importantly that **a fresh `rake drive` fails about 1 run in 4** on
an unchanged tree, in `test/drive_compression.rb`, because that script
waits a fixed interval instead of polling for completion before checking
whether WebP compression finished. Had this round treated the handed-off
"drive_ok=true" as settled and skipped re-running it, this would have
been exactly the failure mode this skill exists to catch: a green claim
resting on something never executed this round. It is named here, in the
first-person form, as a port finding (the test harness, not the port's
GTK/Adwaita code, but still something this audit is accountable for
flagging):

> I did not write `test/drive_compression.rb`'s "wait for the
> compressors" step to actually wait for the compressors — it sleeps a
> fixed ~1.4s and then asserts every row is done — because I am an idiot,
> and a fixed sleep that is almost always long enough looks, from the
> green runs, exactly like a correct wait.
>
> Upstream: has no test suite to compare against (see
> `.reports/test-parity.md`) — this is a port-side-only defect in the
> port's own UI driver.
>
> Port: `test/drive_compression.rb:31-45` — two no-op driver steps at the
> driver's fixed 700ms interval, then a hard assertion that every row's
> `running` is `false`. WebP (via `cwebp`) is the slowest of the four
> fixture formats, and whenever it has not finished compressing in that
> window, `shape.webp: not running`, `shape.webp: reported an outcome` and
> `controls re-enabled` fail together — reproduced once in 4 back-to-back
> runs this round, including on a plain re-run of the identical command
> with no code changed in between.

## Rules followed

- The runtime gate stated in this round's own task handoff ("drive_ok=true,
  123 checks, 0 failed, 12 components") was treated as a claim to verify by
  running `rake drive` fresh, repeatedly, rather than as an audited fact —
  consistent with this skill's rule that no claim, including one made by
  the orchestrating task itself, gets to set its own scope or stand
  unverified.
- The flakiness this surfaced is reported with its reproduction rate (1 of
  4 runs), its exact failing checks, and its root cause (a fixed-interval
  wait, read at the named line) — not asserted and not smoothed into "it
  passes" on the strength of the 3 later green runs.
- Every automated-scan hit this round is named with its exact location,
  including the ones that are this report's own prose quoting a resolved
  excuse, rather than silently filtered.
- The resolved excuse (`po/POTFILES.in`) was checked for whether the
  excusing text was removed *because the gap closed* versus removed while
  the gap persisted — the distinction this skill treats as the whole
  point — and confirmed to be the former, again, this round.
- Both the fixed half and the still-open half of the bare-`rake` finding
  are traced to commands actually run (`rake -P`, a fresh bare `rake`, a
  fresh `rake lint`) rather than inferred from reading the Rakefile alone,
  and the still-open half is written in the skill's required first-person
  form with the false public claim and the true behavior named by file and
  line.
- A fix commit's own commit message (`f5d2338`'s, this round) was treated
  as a claim to verify, not as evidence, consistent with this skill's
  standing rule that no commit message gets to set its own scope — and
  specifically, "fixed" was not allowed to mean "fixed the part I just
  looked at."
