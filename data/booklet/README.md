# Weekly booklet

The home screen tile beside Ben Ish Chai shows the current weekly booklet.

Each week:
1. Delete last week's PDF from this folder.
2. Add the new PDF (e.g. `5787-bereshit.pdf`).
3. Update `current.json`:

```json
{ "id": "5787-bereshit", "title": { "he": "פרשת בראשית", "en": "Parashat Bereshit" }, "pdf": "data/booklet/5787-bereshit.pdf" }
```

`title` may also be a plain string. No `current.json` (or no `pdf`) = the tile stays hidden and the slot stays empty.
This folder is left out of `data/manifest.json` on purpose (never prefetched, never kept on the device).
