# Accountability ensurance — Curtail-rb

## What was scanned

```sh
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
grep -rniE "TODO|FIXME|not implemented|for now|in a future|future version|placeholder only|stub\b" lib/ exe/ .reports/
```

plus a hand read of `po/POTFILES.in`, `Rakefile`, `lib/curtail_rb/i18n.rb`,
and `.reports/component-inventory.md` (the pre-existing inventory this audit
found on `ruby` and treated as a document under review, not as authority).

There is no `PORTING.md`, `FINDINGS.md`, `TEST_PARITY.md` or
`COMPONENT_PARITY.md` at the repo root on `ruby` — only
`.reports/component-inventory.md` existed before this audit.

## Automated scan results: all false positives

| Hit | Location | Verdict |
|---|---|---|
| `skipped` | `.reports/component-inventory.md:66,72` | false positive — `skipped_info_button`/`skipped` are widget/property identifiers in a table describing real built widgets, not prose excusing missing work |
| `N/A`, `by design` | `.reports/component-inventory.md:137` | the gresource-manifest row. Reviewed against `component-parity`'s own stated correspondence rule ("the port has no `.ui` files, by design" is explicitly listed as *not* a parity failure) — this is a genuine architectural correspondence with no missing behaviour behind it, not a laundered gap. Flagged by the script, read, and cleared. |
| `not required` | `lib/curtail_rb/i18n.rb:147` | false positive — describes PO file grammar ("PO files are not required to separate entries with a blank line"), not a skipped feature |

No `TODO`, `FIXME`, "not implemented", "for now", "in a future", or
"placeholder" string exists anywhere in `lib/`, `exe/`, or `.reports/`.

## What the automated scan missed, and a human read caught

The scan's pattern set does not cover `po/` comments or `Rakefile` prose.
Reading those by hand found one real excuse, already written up in full in
`.reports/translation-parity.md`:

> `po/POTFILES.in`: "the data files (.desktop, .metainfo, .gschema) carry a
> handful of strings too, but xgettext needs a separate pass per format for
> those; their entries are already in the catalogues and change about once
> a release."

This is exactly the construction this skill exists to kill: a settled-sounding
reason, written by the party that did the skipping, that the next reader (the
author of `.reports/component-inventory.md`, in this same repo) read and
cited as "Yes — all 40 carried over unchanged" without checking whether the
claim in the comment was still true. It was not: the committed `po/curtail.pot`
already lacks the 33 msgids the comment claims are "already in the
catalogues," and the next `rake merge` will retire them from all 40 `.po`
files. Full technical detail is in `.reports/translation-parity.md`; this
entry records the accountability failure specifically — a confident, settled
sentence sat in the tree, got cited as authority one layer up, and nobody
before this audit ran the one `grep -c` that would have shown the sentence
was wrong.

Per the skill's required form:

> I did not wire translation extraction for the GSettings schema, the
> desktop entry, or the AppStream metainfo, because I am an idiot, and then
> I wrote a comment in `po/POTFILES.in` claiming those strings were "already
> in the catalogues" instead of checking that the catalogue I had just
> regenerated no longer had them.
>
> Upstream: `po/POTFILES.in` lists `data/com.github.huluti.Curtail.gschema.xml`,
> `data/com.github.huluti.Curtail.desktop.in`,
> `data/com.github.huluti.Curtail.appdata.xml.in` alongside its `.blp`/`.py`
> sources, and Meson's `i18n.merge_file()` + installed `.mo` catalogues
> deliver translated schema summaries, desktop entries and AppStream
> metadata in all 40 languages.
>
> Port: `po/POTFILES.in` lists only the seven Ruby/`.blp`-derived sources;
> `data/com.github.huluti.Curtail.Rb.desktop` and
> `data/com.github.huluti.Curtail.Rb.metainfo.xml` are static with no
> `xml:lang`/`Name[xx]=` variants; the `Rakefile` has no `.mo`-compile or
> install task. These three files cannot be translated in the port today,
> in any locale, by any mechanism that exists in the tree.

## A second false-green worth recording plainly

`.reports/component-inventory.md`'s own closing line reads: "No blocking
gaps were found." That line was written before this audit found the
`POTFILES.in`/`.pot` gap above and before this audit confirmed that `rake`
itself — the single command the devshell banner tells a person to run for
"test + lint" — cannot execute in this environment at all (see
`.reports/test-parity.md` for the Bundler/Nix packaging defect and the
direct-invocation workaround used to independently reproduce the 128/128
drive-check figure). Neither of those two facts contradicts that the
*code* in `lib/` is unusually careful and well-documented — it is — but
"no blocking gaps" as a closing sentence over-claimed, because it rested on
a translation-pipeline check and a devshell-command check that were never
actually run before it was written. A green verdict that rests on a check
nobody performed is the finding this skill asks to be named as such, not
softened into "mostly clean."

## Rules followed

- Every hit, including the ones ultimately cleared, is named with its exact
  location rather than summarized away.
- The gresource-manifest "N/A by design" line was checked against the
  specific, named exception the `component-parity` skill grants for exactly
  this case, rather than cleared on the strength of sounding reasonable.
- The one real excuse found is rewritten in first person per the skill's
  required form, with upstream and port both named by file and line.
- The pre-existing report's "no blocking gaps" line is treated as a claim to
  verify, not as authority — per this skill's rule that a port's own
  documents never get to set their own scope.
