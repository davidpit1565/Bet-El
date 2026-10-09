#!/usr/bin/env node
// Generates data/manifest.json - a flat list of every file under data/
// (except manifest.json itself). The native app's background prefetch
// (syncNativeTabBar's sibling, startBackgroundDataPrefetch() in
// index.html) downloads exactly this list on every launch so the whole
// app becomes fully offline-capable automatically, not just section by
// section - see CLAUDE.md's "data/ is not bundled into native builds"
// note for why data/ is fetched remotely at all instead of just reading
// local files directly.
//
// Re-run this (`node scripts/generate-data-manifest.mjs`) any time a
// file is added to, removed from, or renamed under data/ - GitHub Pages
// only serves whatever is actually committed, so a stale manifest would
// either 404 on a removed/renamed path (harmless - skipped and logged,
// see index.html) or simply miss prefetching a newly added file (it
// would still work when the user opens that section, just not be
// pre-downloaded in the background ahead of time).
import { readdirSync, statSync, writeFileSync } from 'fs';
import { join, relative } from 'path';
import { fileURLToPath } from 'url';

const root = fileURLToPath(new URL('..', import.meta.url));
const dataDir = join(root, 'data');
const out = [];

function walk(dir) {
  for (const name of readdirSync(dir).sort()) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) { if (full !== join(dataDir, 'booklet')) walk(full); }   // the weekly booklet is replaced every week - never prefetched/cached
    else if (name !== 'manifest.json') out.push('data/' + relative(dataDir, full).split(/\\|\//).join('/'));
  }
}
walk(dataDir);

writeFileSync(join(dataDir, 'manifest.json'), JSON.stringify(out));
console.log(`data/manifest.json: ${out.length} files listed`);
