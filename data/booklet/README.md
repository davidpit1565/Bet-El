# Weekly booklet

The home screen tile beside Ben Ish Chai shows the current weekly booklet.

Each week:
1. Delete last week's PDF from this folder.
2. Add the new PDF (e.g. `5787-bereshit.pdf`).
3. Update `current.json`:

```json
{ "id": "5787-bereshit", "shabbat": "2026-10-10", "title": { "he": "פרשת בראשית", "en": "Parashat Bereshit" }, "pdf": "data/booklet/5787-bereshit.pdf" }
```

`shabbat` = that week's Shabbat. The booklet appears at netz hachama (sunrise) on the Sunday before it and is removed
at netz on the Sunday after it - even if no new booklet was published (no date = 7 days after the app first saw it).
`current.json` may also be an array of two booklets (this week + next week uploaded early); the app shows the one
whose week is now. Remove past weeks' PDFs from this folder. `title` may also be a plain string. No `current.json` (or no `pdf`) = the tile stays hidden and the slot stays empty.
This folder is left out of `data/manifest.json` on purpose (never prefetched, never kept on the device).
