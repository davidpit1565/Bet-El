/* Builds fastlane/metadata/<locale>/*.txt from docs/appstore/LISTING.md (store texts) and
   docs/release-update-checklist.md section 3 (What's New), and copies the App Store slides into
   fastlane/screenshots/<locale>/ for `fastlane deliver`.
   usage: node scripts/fastlane-metadata.mjs            (he, en-US, fr-FR, ru; screenshots for he + en-US)
   Georgian is skipped - App Store Connect has no Georgian localization. */
import fs from 'fs';
import path from 'path';

const LOCALES = [['עברית', 'he', 'עברית'], ['English', 'en-US', 'English'], ['Français', 'fr-FR', 'Français'], ['Русский', 'ru', 'Русский']];
const SHOT_LANGS = { he: 'he', 'en-US': 'en' };   // screenshots only for these locales
const listing = fs.readFileSync('docs/appstore/LISTING.md', 'utf8');
const checklist = fs.readFileSync('docs/release-update-checklist.md', 'utf8');

const section = (md, head) => {
  const i = md.search(new RegExp('^## ' + head, 'm'));
  if (i < 0) throw new Error('missing section ' + head);
  const rest = md.slice(i + 3);
  const j = rest.search(/^## /m);
  return j < 0 ? rest : rest.slice(0, j);
};
const inline = (sec, field) => (sec.match(new RegExp('\\*\\*' + field + '\\*\\*[^`]*`([^`]+)`')) || [])[1];
const block = (sec, field) => (sec.match(new RegExp('\\*\\*' + field + '\\*\\*[^\\n]*\\n```\\n([\\s\\S]*?)\\n```')) || [])[1];
const url = field => (listing.match(new RegExp('\\*\\*' + field + ':\\*\\*\\s*(\\S+)')) || [])[1];

const whatsNew = checklist.slice(checklist.indexOf("### מה חדש (What's New)"), checklist.indexOf('### Review Notes'));
const notesFor = label => (whatsNew.match(new RegExp('\\*\\*' + label + '\\*\\*\\n```\\n([\\s\\S]*?)\\n```')) || [])[1];

const LIMITS = { name: 30, subtitle: 30, promotional_text: 170, keywords: 100, description: 4000, release_notes: 4000 };
const out = 'fastlane/metadata';
for (const [head, locale, notesLabel] of LOCALES) {
  const sec = section(listing, head);
  const fields = {
    name: inline(sec, 'Name'),
    subtitle: inline(sec, 'Subtitle'),
    promotional_text: block(sec, 'Promotional Text'),
    keywords: block(sec, 'Keywords'),
    description: block(sec, 'Description'),
    release_notes: notesFor(notesLabel),
    support_url: url('Support URL'),
    marketing_url: url('Marketing URL'),
    privacy_url: url('Privacy Policy URL'),
  };
  fs.mkdirSync(path.join(out, locale), { recursive: true });
  for (const [k, v] of Object.entries(fields)) {
    if (!v) throw new Error(`${locale}: missing ${k}`);
    if (LIMITS[k] && [...v].length > LIMITS[k]) throw new Error(`${locale}: ${k} is ${[...v].length} > ${LIMITS[k]}`);
    fs.writeFileSync(path.join(out, locale, k + '.txt'), v.trim() + '\n');
  }
  console.log('metadata', locale);
}
fs.writeFileSync(path.join(out, 'copyright.txt'), (listing.match(/\*\*Copyright:\*\*\s*(.+)/) || [])[1].trim() + '\n');

for (const [locale, lang] of Object.entries(SHOT_LANGS)) {
  const dst = path.join('fastlane/screenshots', locale);
  fs.rmSync(dst, { recursive: true, force: true });
  fs.mkdirSync(dst, { recursive: true });
  for (const dev of ['iphone-6.9', 'ipad-13']) {
    const src = `docs/appstore/slides/${lang}/${dev}`;
    if (!fs.existsSync(src)) continue;
    for (const f of fs.readdirSync(src).filter(f => f.endsWith('.png')).sort()) fs.copyFileSync(path.join(src, f), path.join(dst, `${dev}-${f}`));
  }
  console.log('screenshots', locale, fs.readdirSync(dst).length);
}
