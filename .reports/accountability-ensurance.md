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

## What a human read caught that the automated scan does not cover: the `rake`/banner mismatch

The scan's pattern set matches sentences that excuse *not building*
something. It has no pattern for a sentence that is simply false about
what a command does — and that is the real finding this round, written up
in full in `.reports/test-parity.md`:

- The `nix develop` devshell banner says `rake    test + lint`.
- This branch's `CLAUDE.md`/`AGENTS.md` says `rake    # units, UI drives,
  locale drives, catalogues, rubocop`.
- `Rakefile:61-65` defines `task :default` with **zero** prerequisites and
  a single `puts "Default task complete."` action — confirmed by loading
  the Rakefile and reading `Rake::Task[:default].prerequisites` (`[]`) and
  `.actions.length` (`1`) directly, not by reading the source and guessing.
- Running bare `rake` prints `NOTE: kettle-dev isn't installed, or is
  disabled...` followed by `Default task complete.` and exits 0, having run
  no test and no lint.

Per the skill's required form:

> I did not wire `rake`'s default task to actually run `test` and `lint`
> (or left that wiring dependent on the `kettle-dev` gem being installed,
> which it is not in this devshell), because I am an idiot, and then I let
> the devshell banner and `CLAUDE.md`/`AGENTS.md` both go on telling a
> person that bare `rake` is "test + lint" without ever running bare `rake`
> myself to check.
>
> Upstream: has no Rake/Make default task at all to compare against — this
> is a port-side-only claim, checked against the port's own documentation
> of itself.
>
> Port: `Rakefile:63-65` — `task :default do puts "Default task complete."
> end`, no prerequisites; `CLAUDE.md` and the `flake.nix` devshell banner
> both claim bare `rake` runs test, UI drives, locale drives, catalogue
> work and rubocop. It runs none of them. `rake test`, `rake drive`, `rake
> lint` exist and (bar `rake lint`, see below) work when invoked by full
> name — but nothing invokes them for you, and nothing before this audit
> ran the bare command the banner advertises to find that out.

A second, related finding in the same area: `rake lint` itself currently
exits 1 (99 rubocop offenses) when run by its full name, all of them in
`gemfiles/**` and `spec/spec_helper.rb` — gem-template scaffolding, not
`lib/`/`exe/` (which are rubocop-clean, 21 files, 0 offenses). Commit
`f6a417d`'s own message claims "`rake schema/test/po/pot/lint/drive/i18n`
and `rake` all run clean"; re-run today, `rake lint` does not, and `rake`
bare never attempts it. That commit message is itself a second, smaller
instance of the same pattern as the first: a confident, settled claim
about command behavior, offered without having just run the command.

## The previous round's two false-greens: re-checked, one resolved correctly, one is the template for this round's finding

A previous `.reports/accountability-ensurance.md` on this branch (commit
`8393a06`) recorded two false-greens: (1) `.reports/component-inventory.md`
citing the translation catalogue as "Yes" without checking the `.pot`
count, and (2) that same report's closing "No blocking gaps were found"
line, written before `rake` itself was confirmed broken.

Re-checked this round:

1. **Resolved correctly.** The translation gap is closed (verified by
   running the pipeline, not reading a diff — see
   `.reports/translation-parity.md`), and the excusing comment was removed
   from `po/POTFILES.in` along with the problem it excused, not left
   standing. This is the one half of the previous round's work that fully
   closes out.
2. **The underlying pattern recurred, in a new place.** The previous round
   flagged bare `rake` as *broken* (a Bundler crash). The fix for that
   (`f6a417d`) made bare `rake` *run*, but never gave it the test+lint
   prerequisites the banner and docs claim it has — so the command went
   from "crashes, so obviously not test+lint" to "succeeds silently,
   plausibly test+lint, actually a no-op." A reader who only checks "does
   `rake` exit 0 now" (which is exactly what the previous round's fix
   commit message implicitly invites) would call this fixed. It is only
   half fixed, and the half that remains broken is more dangerous than the
   crash it replaced, because a crash is visible and a silent no-op is not.

## Rules followed

- Every automated-scan hit this round is named with its exact location,
  including the ones that are this report's own prose quoting a resolved
  excuse, rather than silently filtered.
- The resolved excuse (`po/POTFILES.in`) was checked for whether the
  excusing text was removed *because the gap closed* versus removed while
  the gap persisted — the distinction this skill treats as the whole
  point — and confirmed to be the former.
- The new finding (bare `rake`) is traced to a command actually run twice
  (bare, and by full task name) rather than inferred from reading the
  Rakefile alone, and is written in the skill's required first-person form
  with both the false public claim and the true behavior named by file and
  line.
- A fix commit's own "all run clean" claim was treated as a claim to
  verify, not as evidence, consistent with this skill's standing rule that
  no commit message gets to set its own scope.
