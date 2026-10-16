# French "Chnayim Mikra ve'E'had Targoum" booklet

A5 PDF for French-speaking learners: every verse of each parasha **twice in Hebrew** (with cantillation, from
`data/torah-data.json`) and **once in French** (Bible du Rabbinat 1899 / Zadoc Kahn - public domain, fetched from
Sefaria). Cover and front pages follow the Hebrew "Tamid" booklets; everything printed around the text is French and
page numbers are Arabic numerals.

```
node scripts/fr-booklet/fetch-french-torah.mjs        # only needed to refresh torah-rabbinat-fr.json
node scripts/fr-booklet/build.mjs                     # whole Torah -> docs/fr-booklet/chnayim-mikra-fr.pdf (gitignored)
node scripts/fr-booklet/build.mjs --from Bereshit --to Vayechi --out genesis.pdf     # one volume, own TOC + numbering
```

Options: `--name "First Last"` (name printed on the copyright page, Latin letters), `--no-days` (drop the
Sunday...Shabbat dividers), `--same-size` (both Hebrew lines the same size). `--from/--to` take the app's parasha keys
(`data/leyning-data.json`).

Needs Playwright's Chromium (`CHROMIUM_PATH` if it isn't at the default location) and poppler (`pdftotext`, `pdfinfo`).
The table of contents is filled in with a second layout pass, so its page numbers always match the printed ones.

Notes
- The French text gets typographic clean-up only (guillemets, non-breaking spaces before `: ; ! ?`, a few mojibake
  fixes); the wording is the source's. See `cleanFr()`.
- Parasha names are the app's own French names (`PARSHA_FR_NAMES` in index.html).
- Day dividers follow the usual Shnayim Mikra split: one aliyah per day, Sunday = Richon ... Friday = Chichi,
  Shabbat = Chevi'i (ranges from `data/leyning-data.json`).
- Fonts: Taamey Frank CLM (GPL, `fonts/`), EB Garamond + Cormorant Garamond (OFL, `scripts/fr-booklet/fonts/`).
  `assets/` holds the cover corners and flourish (cut from the Hebrew booklet) and an offline QR of the app's smart link.
