# French "Chnayim Mikra ve'E'had Targoum" booklet

A5 PDF entirely in Latin letters (no Hebrew script): every verse of each parasha **twice in French phonetic
transcription** (mikra x2) and **once as the Targum Onkelos transcription**, i.e. the same text the app shows in
French mode (`data/torah-fr.json`). Cover, copyright page, blank page and table of contents follow the Hebrew "Tamid"
booklets, all in French, with Arabic page numbers.

```
node scripts/fr-booklet/build.mjs                     # whole Torah -> docs/fr-booklet/chnayim-mikra-fr.pdf (gitignored)
node scripts/fr-booklet/build.mjs --from Bereshit --to Vayechi --out genesis.pdf     # one volume, own TOC + numbering
```

Options: `--name "First Last"`, `--no-days` (drop the Sunday...Shabbat dividers), `--same-size` (both mikra lines the same
size). `--from/--to` take the app's parasha keys (`data/leyning-data.json`).

Needs Playwright's Chromium (`CHROMIUM_PATH` if not at the default location) and poppler (`pdftotext`, `pdfinfo`).
The table of contents is filled in by a second layout pass, so its page numbers always match the printed ones.
Fonts: EB Garamond + Cormorant Garamond (OFL). `assets/` holds the cover corners and flourish (cut from the Hebrew
booklet) and an offline QR of the app's smart link.
