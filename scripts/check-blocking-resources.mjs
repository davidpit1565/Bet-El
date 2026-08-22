#!/usr/bin/env node
// Guards against a real bug that shipped: an external stylesheet/script
// that blocks page rendering will leave the ENTIRE app blank forever if
// that host is ever slow or unreachable (flaky network, firewall, CDN
// hiccup). Run this before every push that touches index.html.
import { readFileSync } from 'fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const problems = [];

// 1. External <link rel="stylesheet"> that isn't the async preload+onload pattern.
for (const m of html.matchAll(/<link\s+[^>]*rel="stylesheet"[^>]*href="(https?:\/\/[^"]+)"[^>]*>/g)) {
  problems.push(`Render-blocking external stylesheet: ${m[1]}\n  -> use <link rel="preload" as="style" href="..." onload="this.rel='stylesheet'"> instead (see the Google Fonts link).`);
}

// 2. <script type="module"> importing from an external host without async.
// Anchored to the start of a line so mentions of "<script type=..." inside
// a comment or string mid-line (e.g. explanatory prose) aren't flagged.
for (const m of html.matchAll(/^<script\s+type="module"([^>]*)>/gm)) {
  if (!/\basync\b/.test(m[1])) {
    problems.push(`<script type="module"> without async - delays DOMContentLoaded/load (and anything gated on window 'load', like the service-worker registration) if its imports are slow/unreachable.`);
  }
}

// 3. External <script src="http..."> without async or defer.
for (const m of html.matchAll(/^<script\s+[^>]*src="(https?:\/\/[^"]+)"([^>]*)>/gm)) {
  if (!/\b(async|defer)\b/.test(m[2])) {
    problems.push(`Blocking external script (no async/defer): ${m[1]}`);
  }
}

if (problems.length) {
  console.error(`\n✗ ${problems.length} render/load-blocking issue(s) found in index.html:\n`);
  problems.forEach((p, i) => console.error(`${i + 1}. ${p}\n`));
  console.error('These can make the ENTIRE app go blank indefinitely on a slow/blocked connection - see the fix in commit f8321c9.');
  process.exit(1);
} else {
  console.log('✓ No render/load-blocking external resources found.');
}
