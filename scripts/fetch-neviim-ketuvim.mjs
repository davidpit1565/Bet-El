#!/usr/bin/env node
/* One-time fetch of the full Nevi'im + Ketuvim Hebrew text (with nikud and
 * cantillation) from Sefaria's API, using the exact same version already
 * used for data/torah-data.json - "Tanach with Ta'amei Hamikra", Sefaria's
 * license: "Public Domain" (verified per-book below; the Hebrew Masoretic
 * text itself carries no active copyright, and this specific Sefaria
 * digitization is explicitly marked Public Domain by Sefaria's own API).
 * Psalms is intentionally NOT fetched here - it is already fully present
 * in the app as window.TEHILLIM and is reused as-is for Ketuvim's Psalms
 * entry, rather than duplicated.
 *
 * Output shape matches data/torah-data.json's per-book chapter/verse
 * nesting, minus the Targum column Torah alone carries:
 *   { "<Book>": [ [ "verse 1", "verse 2", ... ],  // chapter 1
 *                 [ ... ] ]                        // chapter 2, ...
 *   }
 */
import { writeFileSync } from 'fs';

const VERSION = "Tanach_with_Ta%27amei_Hamikra";

const NEVIIM = ['Joshua','Judges','I Samuel','II Samuel','I Kings','II Kings',
  'Isaiah','Jeremiah','Ezekiel','Hosea','Joel','Amos','Obadiah','Jonah','Micah',
  'Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi'];

const KETUVIM = ['Proverbs','Job','Song of Songs','Ruth','Lamentations',
  'Ecclesiastes','Esther','Daniel','Ezra','Nehemiah','I Chronicles','II Chronicles'];
// Psalms deliberately excluded - already shipped as window.TEHILLIM.

async function fetchBook(name) {
  const url = `https://www.sefaria.org/api/v3/texts/${encodeURIComponent(name)}?version=hebrew|${VERSION}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
  const d = await res.json();
  const v = (d.versions || [])[0];
  if (!v) throw new Error(`${name}: no version returned (available: ${(d.available_versions||[]).map(x=>x.versionTitle).join(', ')})`);
  if (v.license !== 'Public Domain') throw new Error(`${name}: unexpected license "${v.license}", refusing to use`);
  let text = v.text;
  // Some books (e.g. those with alternate chapter/verse schemes) may come
  // back as a flat array (single "chapter") rather than nested - normalize
  // to always be chapters-of-verses.
  if (!Array.isArray(text[0])) text = [text];
  // Sefaria pads missing verses with '' at the end of some chapters; trim.
  text = text.map(ch => {
    while (ch.length && (ch[ch.length-1] === '' || ch[ch.length-1] == null)) ch.pop();
    return ch;
  });
  return { name, text, license: v.license, versionTitle: v.versionTitle };
}

async function buildFile(books, outPath) {
  const out = {};
  for (const name of books) {
    process.stdout.write(`Fetching ${name}... `);
    const { text, license } = await fetchBook(name);
    out[name] = text;
    const nCh = text.length, nV = text.reduce((s,c)=>s+c.length,0);
    console.log(`${nCh} chapters, ${nV} verses, license=${license}`);
    // be polite to the API
    await new Promise(r => setTimeout(r, 300));
  }
  writeFileSync(outPath, JSON.stringify(out));
  console.log('Wrote', outPath);
}

const which = process.argv[2];
if (which === 'neviim') await buildFile(NEVIIM, 'data/neviim-data.json');
else if (which === 'ketuvim') await buildFile(KETUVIM, 'data/ketuvim-data.json');
else { console.error('usage: node scripts/fetch-neviim-ketuvim.mjs neviim|ketuvim'); process.exit(1); }
