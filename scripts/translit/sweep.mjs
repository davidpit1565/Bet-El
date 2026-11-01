#!/usr/bin/env node
// One-factor-at-a-time option sweep against the corpora (tuning aid, not part of the build).
//   node scripts/translit/sweep.mjs '{"bSoft":"b"}' '{"pSoft":"p"}' ...
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const base = JSON.parse(process.env.BASE || '{}');
for (const a of process.argv.slice(2)) {
  const o = { ...base, ...JSON.parse(a) };
  const r = spawnSync('node', [path.join(here, 'corpus-compare.mjs'), '--show', '0', '--corpus', process.env.CORP || 'bic,siddur', '--opts', JSON.stringify(o)], { encoding: 'utf8' });
  const rates = r.stdout.split('\n').filter((l) => /match=/.test(l)).map((l) => l.split(' ')[0] + ' ' + l.match(/match=[\d.]+%/)[0]);
  console.log(a.padEnd(60), rates.join(' | '));
}
