#!/usr/bin/env node
/* French "Chnayim Mikra ve'E'had Targoum" booklet (A5 PDF), entirely in Latin letters: every verse of each parasha
   twice in French phonetic transcription (mikra x2) and once as the Targum Onkelos transcription - the same text the
   app shows in French mode (data/torah-fr.json). No Hebrew script anywhere.

   usage: node scripts/fr-booklet/build.mjs [--out file.pdf] [--from "Bereshit"] [--to "Vezot Haberakhah"]
            [--name "First Last"] [--no-days] [--same-size]
   --from/--to take the app's parasha keys (data/leyning-data.json). Default = the whole Torah (54 parshiot).
   A smaller range (e.g. one book) gets its own table of contents and its own page numbers.
   Needs: playwright (devDependency; set CHROMIUM_PATH if its browser isn't installed) and poppler-utils (pdftotext, pdfinfo). */
import fs from 'fs';
import path from 'path';
import os from 'os';
import {execFileSync} from 'child_process';
import {fileURLToPath, pathToFileURL} from 'url';
import {chromium} from 'playwright';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf('--' + n); return i >= 0 ? argv[i + 1] : d; };
const flag = n => argv.includes('--' + n);

const OUT = path.resolve(opt('out', path.join(ROOT, 'docs/fr-booklet/chnayim-mikra-fr.pdf')));
const OWNER_NAME = opt('name', 'David Pitchkhadze');          // printed on the copyright page - must be the Latin spelling
const SHOW_DAYS = !flag('no-days');
const SAME_SIZE = flag('same-size');
const APP_URL = 'https://davidpit1565.github.io/Bet-El/get.html';

/* ---------- data ---------- */
const TF = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/torah-fr.json'), 'utf8'));   // [chapter][verse] = [mikra, targum]
const LEY = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/leyning-data.json'), 'utf8'));
const indexHtml = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const PARSHA_FR = JSON.parse(indexHtml.match(/const PARSHA_FR_NAMES=(\{[^}]*\});/)[1]);   // same names as the app's French UI

const BOOKS = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'];
const BOOK_FR = {Genesis: ['Béréchit', 'Genèse'], Exodus: ['Chémot', 'Exode'], Leviticus: ['Vayyikra', 'Lévitique'],
  Numbers: ['Bémidbar', 'Nombres'], Deuteronomy: ['Dévarim', 'Deutéronome']};
const DAYS = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Chabbat'];
const ALIYOT = ['Richon', 'Chéni', 'Chelichi', 'Révi’i', '’Hamichi', 'Chichi', 'Chevi’i'];

const keys = Object.keys(LEY).filter(k => LEY[k].parsha.length === 1);        // 54, in Torah order
const iFrom = keys.indexOf(opt('from', keys[0])), iTo = keys.indexOf(opt('to', keys[keys.length - 1]));
if (iFrom < 0 || iTo < iFrom) { console.error('bad --from/--to; keys:', keys.join(', ')); process.exit(1); }
const PARSHIOT = keys.slice(iFrom, iTo + 1);

const cv = r => r.split(':').map(Number);
function versesBetween(book, a, b) {
  const [c0, v0] = cv(a), [c1, v1] = cv(b), out = [];
  for (let c = c0; c <= c1; c++) {
    const n = TF[book][c - 1].length;
    for (let v = (c === c0 ? v0 : 1); v <= (c === c1 ? v1 : n); v++) out.push([c, v]);
  }
  return out;
}
function parashaData(key) {
  const e = LEY[key], book = e.book;
  const days = e.aliyot.filter(Boolean).map((r, i) => ({idx: i, range: r, verses: versesBetween(book, r[0], r[1])}));
  return {key, book, he: e.heName, fr: PARSHA_FR[key] || key, days,
    first: e.aliyot[0][0], last: e.aliyot[e.aliyot.length - 1][1]};
}
const DATA = PARSHIOT.map(parashaData);
const nVerses = DATA.reduce((n, p) => n + p.days.reduce((m, d) => m + d.verses.length, 0), 0);
console.error(`${DATA.length} parshiot, ${nVerses} verses`);

/* ---------- html ---------- */
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const file = p => pathToFileURL(path.join(HERE, p)).href;
const asset = p => pathToFileURL(path.join(HERE, 'assets', p)).href;
const range = r => `${r[0]} – ${r[1]}`.replace(/:/g, ',');

const FONTS = `
${[[400, 'normal'], [500, 'normal'], [600, 'normal'], [700, 'normal'], [400, 'italic'], [600, 'italic']].map(([w, s]) =>
    `@font-face{font-family:'EB Garamond';font-weight:${w};font-style:${s};src:url('${file(`fonts/eb-garamond-latin-${w}-${s}.woff2`)}')}`).join('\n')}
${[600, 700].map(w => `@font-face{font-family:'Cormorant Garamond';font-weight:${w};src:url('${file(`fonts/cormorant-garamond-latin-${w}-normal.woff2`)}')}`).join('\n')}`;

const BASE_CSS = `
*{box-sizing:border-box;margin:0;padding:0}
html{-webkit-print-color-adjust:exact;print-color-adjust:exact}
body{font-family:'EB Garamond',serif;color:#1c1c1c;font-variant-numeric:lining-nums}
`;

/* page chrome (thin page frame, header band with flourishes, dotted rules) = the @page background, an SVG image.
   Chromium places an @page background at the content-box origin, hence the negative background-position. */
const flourishB64 = fs.readFileSync(path.join(HERE, 'assets/flourish.png')).toString('base64');
const CHROME_SVG = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="420" height="595" viewBox="0 0 420 595">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#e6e6e6"/></linearGradient>
<pattern id="d" width="3.2" height="3" patternUnits="userSpaceOnUse"><rect width="1.2" height="3" fill="#8a8a8a" opacity=".55"/></pattern></defs>
<rect x="14" y="14" width="392" height="567" fill="none" stroke="#9a9a9a" stroke-width=".8"/>
<rect x="34" y="28" width="352" height="3" fill="url(#d)"/><rect x="34" y="59" width="352" height="3" fill="url(#d)"/>
<rect x="34" y="35" width="352" height="19" fill="url(#g)" stroke="#444" stroke-width=".6"/>
<rect x="152" y="35.4" width="116" height="18.2" fill="#f4f4f4"/>
<image x="179" y="22.5" width="62" height="12.3" xlink:href="data:image/png;base64,${flourishB64}"/>
<image x="179" y="54.2" width="62" height="12.3" transform="translate(0 120.7) scale(1 -1)" xlink:href="data:image/png;base64,${flourishB64}"/>
</svg>`;
const PAGE_BG = `url("data:image/svg+xml;base64,${Buffer.from(CHROME_SVG).toString('base64')}") no-repeat -40pt -78pt/420pt 595pt`;

const bodyCss = `
@page{size:420pt 595pt}
${DATA.map((p, i) => `@page p${i}{margin:78pt 40pt 58pt 40pt;background:${PAGE_BG};
  @top-left{content:"Parachat ${p.fr.replace(/"/g, '')}";font:600 9.5pt 'EB Garamond';color:#333;vertical-align:top;padding-top:39.5pt;width:120pt;text-align:left}
  @top-center{content:"Chnayim Mikra";font:700 15pt 'Cormorant Garamond';letter-spacing:.9pt;color:#2b2b2b;vertical-align:top;padding-top:36.5pt;text-align:center;white-space:nowrap;overflow:visible}
  @top-right{content:"${BOOK_FR[p.book][0]}";font:600 9.5pt 'EB Garamond';color:#333;vertical-align:top;padding-top:39.5pt;width:120pt;text-align:right}
  @bottom-center{content:"— " counter(page) " —";font:500 10pt 'EB Garamond';color:#777;vertical-align:top;padding-top:6pt}
}`).join('\n')}
.parasha{page-break-before:always}
.ptitle{text-align:center;padding-top:20pt;break-after:avoid}
.ptitle img{width:112pt;display:block;margin:0 auto 8pt}
.ptitle .k{font:600 10pt 'EB Garamond';letter-spacing:3.4pt;text-transform:uppercase;color:#555}
.ptitle .n{font:700 33pt/1.08 'Cormorant Garamond';color:#222;margin:2pt 0 3pt}
.ptitle .m{font:italic 400 10.5pt 'EB Garamond';color:#555;margin-top:4pt}
.ptitle hr{border:0;border-top:.7pt solid #999;margin:12pt 30pt 8pt}
.day{display:flex;align-items:center;gap:8pt;margin:15pt 0 9pt;break-after:avoid;break-inside:avoid}
.day:before,.day:after{content:"";flex:1;height:1.6pt;background:linear-gradient(90deg,transparent,#555)}
.day:after{background:linear-gradient(270deg,transparent,#555)}
.day .lab{border:.7pt solid #444;border-radius:6pt;padding:3pt 14pt 2pt;text-align:center;box-shadow:0 0 0 1.6pt #fff,0 0 0 2.2pt #aaa;background:linear-gradient(#fff,#ededed)}
.day .lab b{display:block;font:700 12.5pt/1.2 'EB Garamond';letter-spacing:.4pt}
.day .lab span{display:block;font:italic 400 8.5pt/1.2 'EB Garamond';color:#555}
.chap{text-align:center;font:600 8.5pt 'EB Garamond';letter-spacing:2.2pt;text-transform:uppercase;color:#666;margin:10pt 0 6pt;break-after:avoid}
.v{position:relative;margin:0 0 9pt;padding-left:22pt;break-inside:avoid}
.vn{position:absolute;left:0;top:3pt;font:700 9.5pt 'EB Garamond';color:#555}
.m1,.m2{direction:ltr;text-align:left;hyphens:manual}
.m1{font:700 ${SAME_SIZE ? 14 : 15.5}pt/1.34 'EB Garamond';color:#111}
.m2{font:500 ${SAME_SIZE ? 14 : 13.5}pt/1.34 'EB Garamond';color:#2a2a2a;margin-top:2pt}
.tg{font:italic 400 11pt/1.32 'EB Garamond';color:#3a3a3a;margin-top:4pt;border-left:1.2pt solid #bbb;padding-left:7pt}
`;

const dayLabel = (d, p) => !SHOW_DAYS ? '' :
  `<div class="day"><div class="lab"><b>${DAYS[d.idx]} · ${ALIYOT[d.idx]}</b><span>${range(d.range)}</span></div></div>`;

function parashaHtml(p, i) {
  const book = p.book;
  let h = `<section class="parasha" style="page:p${i}">
<div class="ptitle"><img src="${asset('flourish.png')}"><div class="k">Parachat</div><h2 class="n">${esc(p.fr)}</h2><div class="m">${BOOK_FR[book][0]} · ${BOOK_FR[book][1]} · ${range([p.first, p.last])}</div><hr></div>`;
  let lastChap = null;
  for (const d of p.days) {
    h += dayLabel(d, p);
    for (const [c, v] of d.verses) {
      if (c !== lastChap && v === 1) h += `<div class="chap">Chapitre ${c}</div>`;
      lastChap = c;
      const [mk, tg] = TF[book][c - 1][v - 1], cap = t => t.charAt(0).toUpperCase() + t.slice(1);
      h += `<div class="v"><span class="vn">${v}</span><p class="m1">${esc(cap(mk))}</p><p class="m2">${esc(cap(mk))}</p><p class="tg">${esc(cap(tg))}</p></div>`;
    }
  }
  return h + '</section>';
}

/* ---------- front matter (cover, copyright, blank page, table of contents) ---------- */
const GRAD = 'linear-gradient(180deg,#8d8d8d 0%,#2e2e2e 46%,#111 58%,#5b5b5b 100%)';
function frontHtml(toc) {
  const cover = `
<section class="cover">
  <i class="f1"></i><i class="f2"></i>
  <img class="co tl" src="${asset('corner-tl.png')}"><img class="co tr" src="${asset('corner-tr.png')}">
  <img class="co bl" src="${asset('corner-bl.png')}"><img class="co br" src="${asset('corner-br.png')}">
  <div class="ctitle"><h1>Chnayim Mikra</h1><h2>vé’E’had Targoum</h2></div>
  <div class="csub">Deux fois le texte · Une fois la traduction</div>
  <div class="cmain"><div class="a">La Torah complète</div><div class="b">Les cinq livres · ${DATA.length} parachiot</div>
    <div class="c">Texte en phonétique française · Targoum Onkelos</div></div>
  <div class="cqr"><div class="qr"><img src="${asset('qr-app.svg')}"></div><div class="cap">Télécharger l’application Tamid</div></div>
</section>`;
  const copyright = `
<section class="plain copy">
  <div class="arch"><img class="af" src="${asset('flourish.png')}">
    <div class="band"><b>Tous droits réservés © Tamid</b><span>Créé à partir de l’application Tamid</span>
      <em>Tous les textes sont tirés des sources présentées dans l’application.</em></div>
    <p class="note">Ce livret peut être diffusé pour le mérite du public, à condition qu’aucune modification ne soit apportée au contenu ni à la mise en page.</p>
    <div class="q"><b>Pour toute question ou correction :</b><div>${esc(OWNER_NAME)}</div><div>+32 484 10 50 07</div><div>info@bet-el.be</div></div>
    <img class="af bot" src="${asset('flourish.png')}"></div>
</section>`;
  const blank = '<section class="plain"></section>';
  const groups = BOOKS.map(b => ({b, items: DATA.filter(p => p.book === b)})).filter(g => g.items.length);
  const tocHtml = `
<section class="plain toc"><img class="tf" src="${asset('flourish.png')}"><h3>Table des matières</h3>
  <div class="cols ${DATA.length > 20 ? 'two' : ''}">
  ${groups.map(g => `<div class="grp"><div class="gh">${BOOK_FR[g.b][0]} <span>${BOOK_FR[g.b][1]}</span></div>
    ${g.items.map(p => `<div class="row"><span class="nm">${esc(p.fr)}</span><i></i><span class="pg">${toc[p.key] ?? 0}</span></div>`).join('')}</div>`).join('')}
  </div></section>`;
  const css = `
@page front{margin:0}
.cover,.plain{position:relative;width:420pt;height:595pt;overflow:hidden;page-break-after:always;break-after:page}
.cover{background:radial-gradient(ellipse 75% 70% at 50% 50%,#fdfdfd 0%,#f6f6f6 55%,#ebebeb 100%)}
.cover .f1{position:absolute;left:12.8pt;top:12.6pt;right:12.6pt;bottom:12.6pt;border:2.6pt solid #343434}
.cover .f2{position:absolute;left:22.4pt;top:22.4pt;right:22.8pt;bottom:22.8pt;border:.9pt solid #343434}
.co{position:absolute;width:132pt}
.co.tl{left:0;top:0}.co.tr{right:0;top:0}.co.bl{left:0;bottom:0}.co.br{right:0;bottom:0}
.ctitle{position:absolute;top:150pt;left:0;right:0;text-align:center}
.ctitle h1{font:700 52pt/1 'Cormorant Garamond';letter-spacing:.5pt;background:${GRAD};-webkit-background-clip:text;background-clip:text;color:transparent;filter:drop-shadow(0 1.4pt 0 #cfcfcf) drop-shadow(0 -.5pt 0 #fff);padding:0 8pt}
.ctitle h2{font:700 29pt/1.1 'Cormorant Garamond';margin-top:4pt;background:${GRAD};-webkit-background-clip:text;background-clip:text;color:transparent;filter:drop-shadow(0 1pt 0 #cfcfcf)}
.csub{position:absolute;top:262pt;left:0;right:0;text-align:center;font:600 9pt 'EB Garamond';letter-spacing:3.2pt;text-transform:uppercase;color:#333}
.cmain{position:absolute;top:342pt;left:0;right:0;text-align:center}
.cmain .a{font:700 27pt/1.1 'Cormorant Garamond';color:#1d1d1d}
.cmain .b{font:600 14pt 'EB Garamond';margin-top:9pt;color:#222}
.cmain .c{font:italic 400 10.5pt 'EB Garamond';margin-top:7pt;color:#555}
.cqr{position:absolute;bottom:56pt;left:0;right:0;text-align:center}
.cqr .qr{width:84pt;height:84pt;margin:0 auto;padding:6pt;background:#fff;border:.8pt solid #bbb;border-radius:7pt;box-shadow:0 1pt 3pt rgba(0,0,0,.18)}
.cqr .qr img{width:100%;height:100%;display:block}
.cqr .cap{font:italic 400 9.5pt 'EB Garamond';margin-top:7pt;color:#444;letter-spacing:.3pt}
.plain{background:#fff}
.arch{position:absolute;left:46pt;right:46pt;top:36pt;bottom:36pt;border:1pt solid #333;border-radius:170pt 170pt 6pt 6pt;box-shadow:0 0 0 3pt #fff,0 0 0 4pt #777;text-align:center}
.arch .af{position:absolute;left:50%;top:18pt;width:70pt;transform:translateX(-50%)}
.arch .af.bot{top:auto;bottom:18pt;transform:translateX(-50%) scaleY(-1)}
.band{position:absolute;left:-22pt;right:-22pt;top:150pt;padding:13pt 16pt 11pt;background:linear-gradient(#fbfbfb,#bdbdbd);border-top:1pt solid #333;border-bottom:1pt solid #333}
.band b{display:block;font:700 15pt 'Cormorant Garamond';letter-spacing:.3pt}
.band span{display:block;font:600 10.5pt 'EB Garamond';margin-top:5pt}
.band em{display:block;font:italic 400 8.4pt/1.3 'EB Garamond';margin-top:5pt;color:#333}
.copy .note{position:absolute;left:34pt;right:34pt;top:262pt;font:400 10pt/1.45 'EB Garamond'}
.copy .q{position:absolute;left:30pt;right:30pt;top:322pt;font:400 10.5pt/1.55 'EB Garamond'}
.copy .q b{display:block;font:700 11pt 'EB Garamond';margin-bottom:3pt}
.toc{padding:54pt 44pt 0}
.toc .tf{display:block;width:84pt;margin:0 auto 6pt}
.toc h3{font:700 25pt 'Cormorant Garamond';text-align:center;margin-bottom:16pt}
.cols.two{column-count:2;column-gap:30pt}
.grp{break-inside:auto;margin-bottom:9pt}
.gh{font:700 11.5pt 'Cormorant Garamond';letter-spacing:.8pt;text-transform:uppercase;border-bottom:.8pt solid #444;padding-bottom:1.5pt;margin-bottom:3pt;break-after:avoid}
.gh span{font:italic 400 9pt 'EB Garamond';text-transform:none;letter-spacing:0;color:#555;margin-left:3pt}
.row{display:flex;align-items:baseline;gap:4pt;font:400 10.4pt/1.55 'EB Garamond';break-inside:avoid}
.row i{flex:1;border-bottom:.8pt dotted #888;transform:translateY(-2.5pt)}
.row .pg{font-weight:600}
`;
  return {css, html: [cover, copyright, blank, tocHtml].join('\n').replace(/<section class="(cover|plain)/g, '<section style="page:front" class="$1')};
}

/* ---------- render ---------- */
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'frbooklet-'));
const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || (fs.existsSync('/opt/pw-browsers/chromium-1194/chrome-linux/chrome') ? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' : undefined)});
async function render(html, out, extra = {}) {
  const f = path.join(TMP, path.basename(out) + '.html');
  fs.writeFileSync(f, html);
  const page = await browser.newPage();
  await page.goto(pathToFileURL(f).href);
  await page.evaluate(() => Promise.all([...document.fonts].map(f => f.load())));   // margin boxes only see fonts that are already loaded
  await page.pdf({path: out, preferCSSPageSize: true, printBackground: true, outline: true, tagged: true, ...extra});
  await page.close();
}
const pages = f => +execFileSync('pdfinfo', [f]).toString().match(/Pages:\s+(\d+)/)[1];

const docHtml = toc => { const f = frontHtml(toc);
  return `<!doctype html><html lang="fr"><meta charset="utf-8"><title>Chnayim Mikra vé’E’had Targoum</title><style>${FONTS}${BASE_CSS}${bodyCss}${f.css}</style><body>${f.html}${DATA.map(parashaHtml).join('\n')}</body></html>`; };

const pdf = path.join(TMP, 'booklet.pdf');
let toc = {};
/* pass 1: lay everything out and find the first page of each parasha; pass 2: print those page numbers in the table of contents */
await render(docHtml(toc), pdf);
const nPages = pages(pdf);
const pageTexts = execFileSync('pdftotext', ['-layout', pdf, '-'], {maxBuffer: 1 << 30}).toString().split('\f').map(t => t.replace(/\s+/g, ' '));
let cursor = 4;                                             // body pages start after cover, copyright, blank page, table of contents
for (const p of DATA) {
  const re = new RegExp('Parachat ' + p.fr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(?![\\p{L}’-])', 'u');
  for (let n = cursor; n < nPages; n++) if (re.test(pageTexts[n])) { toc[p.key] = n + 1; cursor = n; break; }
  if (!toc[p.key]) throw new Error('could not locate ' + p.key);
}
await render(docHtml(toc), pdf);
if (pages(pdf) !== nPages) throw new Error('page count changed between passes');
await browser.close();

fs.mkdirSync(path.dirname(OUT), {recursive: true});
fs.copyFileSync(pdf, OUT);
if (!process.env.KEEP_TMP) fs.rmSync(TMP, {recursive: true, force: true}); else console.error('kept', TMP);
console.error(`wrote ${OUT}: ${nPages} pages; TOC`, JSON.stringify(toc));
