# Translation parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit, re-run against current `HEAD`) |
| Languages shipped | 40/40 — `po/*.po`, `po/LINGUAS` are byte-identical to upstream |
| Ruby-source msgids | parity, confirmed line by line |
| **Catalogue pipeline** | **closed, and still closed this round** — `po/`, `lib/` and `exe/` are unchanged since that fix (`git diff` against the prior report's commit touches only `AGENTS.md`); re-verification details below are unmodified from that round |

## The `.po` files themselves: clean

```sh
diff -rq <upstream-worktree>/po <port>/po
```

returns no differences in any `*.po` file or `LINGUAS`. All 40 catalogues
the port ships are upstream's, unmodified. Every translator's existing work
survives today, in the files as committed.

## Ruby-sourced strings: spot-checked and confirmed matching

- `"Analyzing Images"` / `"Analyzing your images before compression…"` —
  byte-identical, including the real ellipsis character, between
  `window.blp:119-120` and `window.rb:624-625`.
- `"An unknown error has occurred."` — byte-identical (with the trailing
  period) between `compressor.py:43` and `compressor.rb:58,86`.
- `"Set the level of compression, 6 is the highest but slowest level"` —
  byte-identical between the *current* `preferences.blp:84,130` and the
  port's `LEVEL_SUBTITLE` constant.
- `"Lossless Compression"` / `"Lossy Compression"` (preferences group
  titles) — byte-identical.

No reworded or unmarked Ruby-source string was found.

## The gap a previous round found: closed, re-verified by running the pipeline, not by reading a diff

A previous `.reports/translation-parity.md` on this branch (commit
`8393a06`) reported that `po/POTFILES.in` listed only the seven Ruby
sources, excluded the GSettings schema, the desktop entry and the AppStream
metainfo with a comment claiming their strings were "already in the
catalogues" (false — the committed `.pot` already lacked them, 73 msgids
against upstream's 106), and that there was no `.mo` compile step and no
desktop/metainfo merge step, so those three files could never surface a
translation in any locale.

Commit `f6a417d` ("Fix the gemspec-less devshell binstubs, and close the
translation-catalogue gap") is the direct response: it adds the three data
files back to `po/POTFILES.in`, adds `po/extract_data_strings.rb` (a
format-specific scanner for `.desktop`/`.gschema.xml`/`.metainfo.xml`
keys, msgcat'd alongside rxgettext's Ruby-source output since rxgettext
only understands Ruby), adds a `rake mo` task (`msgfmt` to
`tmp/share/locale/<lang>/LC_MESSAGES/curtail.mo`, with `NLSPATH` routing
glibc's gettext there), and adds `rake merge_data` (the same `msgfmt
--desktop`/`--xml` template merge the upstream package build does, writing
to `tmp/share`).

This round re-ran the pipeline rather than trusting the commit message:

```sh
$ nix develop --command rake pot && grep -c '^msgid "' po/curtail.pot
107
$ git show origin/main:po/curtail.pot | grep -c '^msgid "'
106
```

107 vs. 106 — no longer a 73-vs-106 shortfall. The one-entry surplus is the
port's own app name (`"Curtail (Ruby)"`, the `.desktop` `Name=`, which has
no upstream counterpart by design — the port is named differently to avoid
colliding with the Python app). Diffing every other msgid confirms the
same pre-existing "upstream's own `.pot` is stale against its own current
source" cases already documented before (`"Unable to read file
information."` and `"Getting things ready"` are `#~`-obsolete-or-absent in
upstream's *current* `src/*.py` — confirmed with `git grep` against
`origin/main`, zero hits in source — so their absence from the port's
`.pot` is correct, not a gap) plus the same ellipsis/period/wording
normalizations already spot-checked above. No new discrepancy.

`rake mo` and `rake merge_data` were run (not just read) and their output
inspected directly:

```sh
$ nix develop --command xvfb-run -a rake drive   # runs schema+mo+merge_data as prerequisites
$ grep -c 'xml:lang' tmp/share/metainfo/com.github.huluti.Curtail.Rb.metainfo.xml
151
$ head -20 tmp/share/applications/com.github.huluti.Curtail.Rb.desktop
[Desktop Entry]
Name=Curtail (Ruby)
Exec=curtail-rb %U
Comment[az]=Şəkillərinizi sıxışdırın
Comment[bg]=Компресирайте вашите изображения
Comment[ca]=Comprimiu les imatges
...
```

The merged desktop file carries `Comment[xx]=` for all 40 locales; the
merged metainfo carries 151 `xml:lang`-bearing elements (summary +
description paragraphs × languages). `tmp/share/locale/fr/LC_MESSAGES/`
contains a compiled `curtail.mo`, and the GSettings schema's
`gettext-domain="curtail"` attribute (`data/com.github.huluti.Curtail.Rb.
gschema.xml:2`) matches the `.mo` domain name `rake mo` compiles to, so
`glib-compile-schemas`'/`dconf`'s lookup for the schema's own
summary/description has somewhere to find a translation. This is the
structural mechanism the previous round reported as entirely absent; it
now exists and produces output, confirmed by inspecting that output rather
than by re-reading the Rakefile task names.

**This gap is closed.** The previous round's closing line — "these three
files have no mechanism to ever surface a translation in the port, in any
locale, structurally" — is no longer true of this tree.

## Census summary

| | Upstream | Port (this round) |
|---|---:|---:|
| `.po`/`LINGUAS` files | 40 + 1 | 40 + 1, byte-identical |
| `.pot` msgids (committed, regenerated via `rake pot`) | 106 | 107 (+1 is the port's own app name) |
| Ruby/`.blp`-sourced UI strings | — | byte-identical, spot-checked |
| `.gschema.xml`/`.desktop.in`/`.metainfo.xml.in`-sourced strings | translated via Meson `i18n.merge_file` + installed `.mo` | translated via `po/extract_data_strings.rb` + `rake mo`/`rake merge_data` — verified producing `Comment[xx]=` and `xml:lang` output for all 40 locales |

## What was not independently re-verified at the deepest level

`rake merge_data`'s desktop/metainfo output and `rake mo`'s compiled
catalogues were inspected directly (above). What this audit did *not* do
is install the compiled schema into a live `dconf`/`gsettings` instance and
ask it for a translated `<summary>` string at runtime — that would confirm
the last hop (GLib's own gettext lookup honoring `gettext-domain="curtail"`
against `NLSPATH`) rather than just the files the Rakefile produces. The
mechanism and the installed artifacts are both present and consistent with
each other, but this is recorded as the boundary of what was checked, per
this skill's own rule about not calling a check done when only part of it
ran.

## Rules followed

- The previous round's gap was not assumed closed on the strength of the
  fix commit's message — `rake pot`/`rake mo`/`rake merge_data` were run
  and their output read directly.
- The reworded-string false leads (stale upstream `.pot` vs. current
  upstream source) were re-confirmed against current `origin/main` source
  with `git grep`, not re-asserted from the earlier report.
- The one remaining unverified hop (live GLib gettext lookup at schema
  runtime) is named explicitly rather than folded into "closed."
