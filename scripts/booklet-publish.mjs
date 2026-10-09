#!/usr/bin/env node
/* Publish this week's booklet AND archive it.
   usage: node scripts/booklet-publish.mjs <file.pdf> <shabbat YYYY-MM-DD> <parasha he> <slug> [title-en] [hebrew-year]
   e.g.:  node scripts/booklet-publish.mjs ~/Desktop/noach.pdf 2026-10-17 "נח" noach "Parashat Noach"
   1. data/booklet/: removes every old PDF, copies the new one, writes current.json (the app shows it from netz
      on the Sunday before that Shabbat until netz on the Sunday after - see bookletWindow() in index.html).
   2. booklets-archive branch: <Hebrew year>/<slug>_<date>.pdf + index.json entry (kept forever, never deployed).
   Commits both; push yourself afterwards: git push origin HEAD booklets-archive */
import fs from 'fs';
import path from 'path';
import {execSync, execFileSync} from 'child_process';
import {fileURLToPath} from 'url';

const [src, shabbat, parasha, slug, titleEn] = process.argv.slice(2);
if(!src || !/^\d{4}-\d{2}-\d{2}$/.test(shabbat||'') || !parasha || !/^[a-z0-9-]+$/.test(slug||'')){
  console.error('usage: node scripts/booklet-publish.mjs <file.pdf> <shabbat YYYY-MM-DD> <parasha he> <slug> [title-en]'); process.exit(1);
}
if(!fs.existsSync(src) || fs.readFileSync(src).subarray(0,4).toString()!=='%PDF'){ console.error('not a PDF: '+src); process.exit(1); }

const root = fileURLToPath(new URL('..', import.meta.url));
const sh = (c, cwd=root) => execSync(c, {cwd, stdio:['ignore','pipe','inherit']}).toString().trim();
const git = (args, cwd=root) => execFileSync('git', args, {cwd, stdio:['ignore','pipe','inherit']}).toString().trim();   // no shell quoting issues with Hebrew/quotes

// Hebrew year of that Shabbat: Rosh Hashana falls between Sept 5 and Oct 5, so only Shabbatot in that window
// are ambiguous - pass the Hebrew year as the 6th argument then (the script refuses to guess).
const [gy,gm,gd] = shabbat.split('-').map(Number);
let year = process.argv[7] || (gm>=10 || (gm===9 && gd>=6) ? null : String(gy+3760));
if(!year && (gm>10 || (gm===10 && gd>5))) year = String(gy+3761);
if(!year){ console.error('Shabbat is between Sept 6 and Oct 5 - add the Hebrew year (e.g. 5787) as the last argument'); process.exit(1); }
const gem = n => { const L=[[400,'ת'],[300,'ש'],[200,'ר'],[100,'ק'],[90,'צ'],[80,'פ'],[70,'ע'],[60,'ס'],[50,'נ'],[40,'מ'],[30,'ל'],[20,'כ'],[10,'י'],[9,'ט'],[8,'ח'],[7,'ז'],[6,'ו'],[5,'ה'],[4,'ד'],[3,'ג'],[2,'ב'],[1,'א']];
  let s=''; n%=1000; for(const [v,c] of L) while(n>=v){ s+=c; n-=v; } s=s.replace('יה','טו').replace('יו','טז'); return s.length>1 ? s.slice(0,-1)+'"'+s.slice(-1) : s+"'"; };
const yearHe = gem(+year);

// 1) the live booklet
const bdir = path.join(root, 'data/booklet');
fs.mkdirSync(bdir, {recursive:true});
for(const f of fs.readdirSync(bdir)) if(f.endsWith('.pdf')) fs.unlinkSync(path.join(bdir, f));
const live = `${year}-${slug}.pdf`;
fs.copyFileSync(src, path.join(bdir, live));
const title = titleEn ? {he:'פרשת '+parasha, en:titleEn} : 'פרשת '+parasha;
fs.writeFileSync(path.join(bdir, 'current.json'), JSON.stringify({id:`${year}-${slug}`, shabbat, title, pdf:`data/booklet/${live}`}, null, 2)+'\n');
git(['add','-A','data/booklet']); git(['commit','-qm',`Weekly booklet: ${slug} ${shabbat}`]);

// 2) the archive branch, through a temporary worktree
const wt = fs.mkdtempSync(path.join(root, '.archive-'));
try{
  try{ sh('git fetch -q origin booklets-archive'); }catch(e){}
  sh(`git worktree add -q "${wt}" ${sh('git rev-parse --verify -q origin/booklets-archive || git rev-parse --verify booklets-archive')}`);
  const rel = `${year}/${slug}_${shabbat}.pdf`;
  fs.mkdirSync(path.join(wt, year), {recursive:true});
  fs.copyFileSync(src, path.join(wt, rel));
  const idxPath = path.join(wt, 'index.json');
  const idx = JSON.parse(fs.readFileSync(idxPath, 'utf8')).filter(x=>x.file!==rel);
  idx.push({year, yearHe, parasha, slug, shabbat, file: rel});
  idx.sort((a,b)=>a.shabbat.localeCompare(b.shabbat));
  fs.writeFileSync(idxPath, JSON.stringify(idx, null, 2)+'\n');
  git(['add','-A'], wt); git(['commit','-qm',`Archive booklet: ${parasha} ${yearHe} (${shabbat})`], wt); git(['push','-q','origin','HEAD:booklets-archive'], wt);
  console.log(`published data/booklet/${live} (commit on this branch - push it) and archived ${rel} on booklets-archive`);
} finally {
  try{ sh(`git worktree remove --force "${wt}"`); }catch(e){ fs.rmSync(wt, {recursive:true, force:true}); }
}
