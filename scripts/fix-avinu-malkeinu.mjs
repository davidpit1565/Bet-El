#!/usr/bin/env node
/* Avinu Malkeinu: data/siddur.json has 33 lines, the transliterations in
 * data/prayers-<en|fr|ru|ka>.json had 32 - the line "סתום פיות משטינינו
 * ומקטריגינו" was missing (everything after it was shifted up by one).
 * Inserts it after the "kalle kol tzar umastin" line (Hebrew index 7).
 * Idempotent: only acts on a 32-line list. Then run
 * scripts/check-avinu-malkeinu.mjs to verify the alignment.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LINE = {
  en: 'Abinu malkenu, satom piyot mastinenu umeqatrigenu:',
  fr: 'Abinou malkenou satom piyot mastinenou oumeqatrigenou:',
  ru: 'Авину малкену, сатом пийот мастинену умекатригену:',
  ka: 'ავინუ მალქენუ სათომ ფიიოთ მასთინენუ უმექათრიგენუ:',
};
const AT = 8; // index of the Hebrew line "אָבִינוּ מַלְכֵּנוּ סְתוֹם פִּיּוֹת ..."
for (const [lang, line] of Object.entries(LINE)) {
  const f = path.join(ROOT, `data/prayers-${lang}.json`);
  const raw = fs.readFileSync(f, 'utf8');
  const d = JSON.parse(raw);
  if (JSON.stringify(d) !== raw) throw new Error(f + ': compact serializer does not round-trip');
  const a = d.avinuMalkeinu;
  if (a.length !== 32) { console.log(lang, 'already', a.length, 'lines - skipped'); continue; }
  a.splice(AT, 0, line);
  fs.writeFileSync(f, JSON.stringify(d));
  console.log(lang, 'inserted ->', a.length, 'lines');
}
