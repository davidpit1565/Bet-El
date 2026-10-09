# Weekly booklets archive (חוברות שבועיות - ארכיון)

Every weekly booklet ever published in the Tamid app is kept here, forever - the app itself only ever shows the current
week's file (`data/booklet/` on `main`).

Layout: `<Hebrew year>/<parasha-slug>_<Shabbat date>.pdf`, e.g. `5787/bereshit_2026-10-10.pdf`.
`index.json` lists every booklet: `{ "year": "5787", "yearHe": "תשפ\"ז", "parasha": "בראשית", "slug": "bereshit", "shabbat": "2026-10-10", "file": "5787/bereshit_2026-10-10.pdf" }`.

This branch is never deployed (no GitHub Pages, no Vercel - see vercel.json). Add booklets with
`node scripts/booklet-publish.mjs` on `main` (it publishes the week's booklet AND archives it here).

To keep a copy on your computer: `git clone -b booklets-archive --single-branch https://github.com/davidpit1565/Bet-El.git Bet-El-booklets`
(then `git pull` in that folder any time to get the new ones).
