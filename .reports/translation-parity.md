# Translation parity — Curtail-rb

| | |
|---|---|
| Upstream | `origin/main` @ `1536d90` |
| Port | `ruby` (this audit) |
| Languages shipped | 40/40 — `po/*.po`, `po/LINGUAS` are byte-identical to upstream |
| Ruby-source msgids | parity, confirmed line by line |
| **Catalogue pipeline** | **gap** — see below |

## The `.po` files themselves: clean

```sh
diff -rq <upstream-worktree>/po <port>/po
```

returns no differences in any `*.po` file or `LINGUAS`. All 40 catalogues
the port ships are upstream's, unmodified. Every translator's existing work
survives today, in the files as committed.

## Ruby-sourced strings: spot-checked and confirmed matching

The scanner's raw msgid diff between the two trees is dominated by
`!unresolved` noise (f-string interpolations upstream, variable references
in the port's factored helpers) that resolves to nothing wrong on inspection
— e.g. upstream's `_(f"Safe mode with "{suffix_prefix}" suffix")` has no
live msgid in the current `.pot` either (the only matching entries are
`#~`-obsolete in `fr.po`), so upstream's own build already shows this
string in English in every locale. The port's `affixed()`
(`lib/curtail_rb/i18n.rb` consumer at `lib/curtail_rb/window.rb:181-199`)
reproduces the same effective behaviour and documents why in a comment
naming the exact obsolete-entry mechanics. Checked by hand and confirmed
correct:

- `"Analyzing Images"` / `"Analyzing your images before compression…"` —
  byte-identical, including the real ellipsis character, between
  `window.blp:119-120` and `window.rb:624-625`.
- `"An unknown error has occurred."` — byte-identical (with the trailing
  period) between `compressor.py:43` and `compressor.rb:58,86`.
- `"Set the level of compression, 6 is the highest but slowest level"` —
  byte-identical between the *current* `preferences.blp:84,130` and the
  port's `LEVEL_SUBTITLE` constant. (The committed `curtail.pot` disagrees
  with upstream's own current source here — it still has the pre-blueprint
  wording "level of **the** compression" against a `data/ui/preferences.ui`
  path that no longer exists upstream. That is upstream's own `.pot` being
  stale against its own sources, already called out in
  `lib/curtail_rb/i18n.rb`'s header comment, and the port correctly matches
  upstream's *current source*, not its stale catalogue.)
- `"Lossless Compression"` / `"Lossy Compression"` (preferences group
  titles) — byte-identical.

No reworded or unmarked Ruby-source string was found.

## The real gap: three file categories upstream translates that the port's pipeline cannot reach

Upstream's `po/POTFILES.in` lists seven files, **three of them not Ruby
sources**:

```
data/com.github.huluti.Curtail.appdata.xml.in
data/com.github.huluti.Curtail.desktop.in
data/com.github.huluti.Curtail.gschema.xml
data/ui/preferences.blp
data/ui/result-item-row.blp
data/ui/shortcuts-dialog.blp
data/ui/window.blp
```

The port's `po/POTFILES.in` lists only the seven Ruby sources, and says why
it stops there:

> `# The Ruby sources, which is where every string the app renders lives. The`
> `# data files (.desktop, .metainfo, .gschema) carry a handful of strings too,`
> `# but xgettext needs a separate pass per format for those; their entries are`
> `# already in the catalogues and change about once a release.`

This is the excuse this org's `accountability-ensurance` skill exists to
catch, and the automated `find-excuses.sh` scan did **not** catch it —
it is prose in a `.po/` comment, outside the file types the script greps.
It is caught here by hand, which is the point of running this skill rather
than trusting the script alone.

The claim in the comment is checkable, and it is false in the way that
matters:

1. **"Already in the catalogues"** — true only by accident, and only for
   now. The `.po` files still carry these entries because nobody has run
   `rake merge` against the committed `.pot` yet. The committed
   `po/curtail.pot` **already lacks them**:

   ```
   $ grep -c '^msgid "' <upstream-worktree>/po/curtail.pot
   106
   $ grep -c '^msgid "' po/curtail.pot
   73
   ```

   The 33-entry gap is exactly the `.gschema.xml`/`.desktop.in`/
   `.metainfo.xml.in`-derived strings: `"Save into a new file"`,
   `"Enable lossy mode"`, `"PNG Lossy Compression Level"`,
   `"WebP Lossless Compression Level"`, `"Suffix/Prefix to append at new
   file"`, `"compress;optimize;image;photo;"` (desktop `Keywords`), and
   their descriptions — one `<summary>`/`<description>` pair per GSettings
   key (`new-file`, `naming-mode`, `recursive`, `metadata`,
   `file-attributes`, `lossy`, `suffix-prefix`, `png-lossy-level`,
   `png-lossless-level`, `jpg-lossy-level`, `webp-lossy-level`,
   `webp-lossless-level`, `jpg-progressive`, `svg-maximum-level`,
   `compression-timeout`), confirmed present verbatim in
   `data/com.github.huluti.Curtail.Rb.gschema.xml` — the port's own
   schema file carries byte-identical English text to upstream's, it is
   just never extracted.

2. **The next `rake merge`** (`sh 'msgmerge', '--update', ...` against this
   incomplete `.pot`, for all 40 `.po` files) will mark every one of those
   ~20-30 entries `#~` (obsolete) in all 40 languages, the same fate the
   `"Safe mode with…"` strings already suffered upstream after a rename. At
   that point the translations are not just unextracted — they are retired,
   and the port's own `i18n.rb` (correctly, per its own `#obsolete entries
   are ignored` behaviour, unit-tested in `units_test.rb`) will never load
   them again. This is a **latent, self-inflicted translation regression**
   sitting one `rake merge` away, not a hypothetical.

3. **Even if the `.pot` were fixed, there is no merge step that would ever
   apply the result.** Upstream is built with Meson, which wires
   `i18n.merge_file()` for `data/*.desktop.in` and
   `data/*.appdata.xml.in` (producing localized `Name[xx]=`/`Comment[xx]=`
   lines and `<summary xml:lang="xx">` blocks respectively) and installs
   compiled `.mo` catalogues that `glib-compile-schemas`'
   `gettext-domain="curtail"` attribute reads at runtime for the schema's
   own summary/description. The port has:
   - `data/com.github.huluti.Curtail.Rb.desktop` — a **static** file with a
     single `Name=`/`Comment=`, no `Name[xx]=` lines, and no build step
     that would add any.
   - `data/com.github.huluti.Curtail.Rb.metainfo.xml` — likewise static,
     zero `xml:lang` attributes.
   - No `msgfmt`-to-`.mo` compile step anywhere in the `Rakefile` (`grep -n
     msgfmt Rakefile` finds only the `--check` validation task) and no
     install step that would place a `.mo` where `glib-compile-schemas`'
     gettext-domain lookup or the desktop/AppStream parsers could find it.

   So independent of the `POTFILES.in` gap, **these three files have no
   mechanism to ever surface a translation in the port, in any locale**,
   structurally — not "not yet wired", a standing fact about how the
   `Rakefile` and the data files are built today.

This contradicts `.reports/component-inventory.md`'s data-files row for the
translation catalogue, which reads "Yes — all 40 carried over unchanged...
`rake po`/`rake pot`/`rake merge`/`rake i18n` drive them." That line is true
of the `.po` files' current bytes and false of the pipeline's ability to
keep them that way, and a reader who stops at "Yes" would not know the
pipeline is one `rake merge` away from discarding the schema/desktop/
metainfo translations it just said were carried over.

## Census summary

| | Upstream | Port |
|---|---:|---:|
| `.po`/`LINGUAS` files | 40 + 1 | 40 + 1, byte-identical |
| `.pot` msgids (committed) | 106 | 73 |
| Ruby/`.blp`-sourced UI strings | — | byte-identical, spot-checked |
| `.gschema.xml`/`.desktop.in`/`.metainfo.xml.in`-sourced strings | translated via Meson `i18n.merge_file` + installed `.mo` | **never translated — no extraction, no merge, no compile, no install** |

## Rules followed

- The reworded-string false leads (stale upstream `.pot` vs. current
  upstream source) were resolved by reading the *current* source on both
  sides, not by trusting either committed `.pot` as ground truth.
- A msgid difference was traced to its root cause (extraction pipeline, not
  wording) before being written down as fine or as a gap.
- The gap is recorded against the message categories and the files that own
  them, not laundered through "not applicable" — the `POTFILES.in` comment
  that tried to do exactly that is quoted and refuted, not repeated.
