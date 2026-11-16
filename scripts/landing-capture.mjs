/* Regenerates the marketing-site screens (landing/screens.js + landing/img/*.webp, and the same for landing/en/) from the
   WEB app itself: index.html rendered in Chromium (Playwright) at an iPhone-like 393px viewport, light theme, with a fixed
   fake clock (Tuesday 2026-11-17 09:41, Asia/Jerusalem, Jerusalem location), no browser chrome.

   usage:  node scripts/landing-capture.mjs [he|en|all]      (default: all)   needs playwright + python3 with Pillow (webp)

   How the landing page uses the result (landing/index.html, window.TAMID_SCREENS):
     home / daily / calendar.top / calendar.detail / library / siddur / compassPieces   = "pieces": every tile/card of the screen
         screenshotted on its own (transparent background, device scale 2) and placed at its x,y,w,h in a 393px-wide coordinate
         space, so the page can fly the pieces in and scroll the whole screen inside the phone mockup;
     nav = the bottom tab bar, celebrate = the "I finished" card, langs.<l> = full 393x852 screenshots of the home screen in
         each UI language (hero phone + language fan), wid / mirror = marketing art that is NOT a web-app screen.
   Pieces are webp (quality 80), named by the SHA-1 of their bytes. Old, no longer referenced files in img/ are deleted.
   wid (widget slides) and mirror (faceless tefillin-mirror art) are carried over untouched from the existing screens.js. */
import {chromium} from 'playwright';
import fs from 'fs';
import path from 'path';
import http from 'http';
import crypto from 'crypto';
import {execFileSync} from 'child_process';
import {fileURLToPath} from 'url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const which=process.argv[2]||'all';
const SITES=which==='all'?['he','en']:[which];
const LANGS=['he','en','fr','ru','ka'];
const NOW=Date.parse('2026-11-17T09:41:00+02:00');
const CHROME=process.env.CHROME||'/opt/pw-browsers/chromium-1243/chrome-linux64/chrome';
const DSF=2, WEBP_Q=80;

/* ---------- tiny static server for the repo root ---------- */
const MIME={'.html':'text/html;charset=utf-8','.js':'text/javascript','.json':'application/json','.css':'text/css','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp','.svg':'image/svg+xml','.woff2':'font/woff2','.woff':'font/woff','.ttf':'font/ttf'};
const server=http.createServer((req,res)=>{
  let p=decodeURIComponent(req.url.split('?')[0]); if(p.endsWith('/'))p+='index.html';
  const f=path.join(ROOT,p); if(!f.startsWith(ROOT)||!fs.existsSync(f)||fs.statSync(f).isDirectory()){res.writeHead(404);res.end();return;}
  res.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); fs.createReadStream(f).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const BASE=`http://127.0.0.1:${server.address().port}/index.html`;

/* ---------- png -> webp (Pillow) ---------- */
function webp(png,{width}={}){
  const py=`import sys,io\nfrom PIL import Image\nim=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert('RGBA')\nw=int(sys.argv[1])\nif w and im.width>w: im=im.resize((w,round(im.height*w/im.width)),Image.LANCZOS)\nb=io.BytesIO(); im.save(b,'WEBP',quality=${WEBP_Q},method=6); sys.stdout.buffer.write(b.getvalue())`;
  return execFileSync('python3',['-I','-c',py,String(width||0)],{input:png,maxBuffer:1<<28});
}

const browser=await chromium.launch({executablePath:CHROME,args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']});
async function mk(lang,h){
  const c=await browser.newContext({viewport:{width:393,height:h||852},deviceScaleFactor:DSF,hasTouch:true,isMobile:true,timezoneId:'Asia/Jerusalem',locale:lang==='he'?'he-IL':lang});
  const p=await c.newPage();
  await p.addInitScript(([l,T])=>{
    const R=Date,off=T-R.now();
    class D extends R{constructor(...a){if(a.length)super(...a);else super(R.now()+off);} static now(){return R.now()+off;}}
    window.Date=D;
    localStorage.setItem('betel_settings',JSON.stringify({lang:l,theme:'light',themeMode:'light'}));
    localStorage.setItem('betel_onboard_v1','1'); localStorage.setItem('betel_chok_pace_v1','1'); localStorage.setItem('betel_milestone_last','100000');
    localStorage.setItem('betel_loc',JSON.stringify({lat:31.7683,lon:35.2137,tz:'Asia/Jerusalem',name:'ירושלים',auto:false}));
  },[lang,NOW]);
  await p.goto(BASE); await p.waitForTimeout(3500);
  /* stable counters (the live ones come from Firebase, which is offline here) */
  await p.evaluate(()=>{const v=document.getElementById('visitCount'),l=document.getElementById('liveCount');if(v)v.textContent='1,372';if(l)l.textContent='7';});
  return p;
}
const TRANSP='html,body,#app{background:transparent!important} body::before,body::after{display:none!important}';
async function hideNav(p){
  await p.evaluate(()=>{[...document.querySelectorAll('body *')].forEach(e=>{const s=getComputedStyle(e);if(s.position==='fixed'){const r=e.getBoundingClientRect();if(r.width>300&&r.height<120&&r.bottom>window.innerHeight-130)e.setAttribute('data-navx','1');}});});
  await p.addStyleTag({content:'[data-navx]{visibility:hidden!important}'});
}
/* one entry per matching element: position in the 393px space + its own transparent screenshot */
async function pieces(p,sel,css=''){
  await p.addStyleTag({content:TRANSP+css});
  const res=[];
  for(const h of await p.$$(sel)){
    const r=await h.evaluate(e=>{const b=e.getBoundingClientRect();return {x:b.x,y:b.y+window.scrollY,w:b.width,h:b.height};});
    if(r.w<4||r.h<4) continue;
    res.push({...r,png:await h.screenshot({omitBackground:true})});
  }
  return res;
}

async function captureAll(lang){
  const out={};
  const tag=(s)=>console.log(`[${lang}] ${s}`);
  /* HOME (tall viewport so nothing scrolls) */
  {const p=await mk(lang,2000); await hideNav(p);
   out.home={w:393,h:await p.evaluate(()=>document.documentElement.scrollHeight),pieces:await pieces(p,'[data-home-item]')}; tag('home '+out.home.pieces.length); await p.context().close();}
  /* NAV BAR (fixed tab bar on a normal 852px viewport) */
  {const p=await mk(lang,852);
   await p.evaluate(()=>{let f=null;[...document.querySelectorAll('body *')].forEach(e=>{const s=getComputedStyle(e);if(s.position==='fixed'){const r=e.getBoundingClientRect();if(r.width>300&&r.height<120&&r.bottom>window.innerHeight-130&&!f)f=e;}});if(f)f.setAttribute('data-navy','1');});
   /* hide the page itself: the bar is translucent and would otherwise carry a ghost of the tile behind it */
   await p.addStyleTag({content:'html,body{background:transparent!important} #app{visibility:hidden!important}'});
   const h=await p.$('[data-navy]'); if(!h) throw new Error('nav bar not found');
   const r=await h.evaluate(e=>{const b=e.getBoundingClientRect();return {x:b.x,y:b.y,w:b.width,h:b.height};});
   out.nav={...r,png:await h.screenshot({omitBackground:true})}; tag('nav'); await p.context().close();}
  /* CALENDAR: top (header, switch, month bar, grid card + every day cell) and the selected-day detail */
  {const p=await mk(lang,2300); await p.evaluate(()=>window.go('calendar')); await p.waitForTimeout(2200); await hideNav(p);
   const top=await pieces(p,'#app > .topbar, .ical-seg, .ical-head');
   const grid=await pieces(p,'.ical-card','.cal-grid>*{visibility:hidden!important}');
   await p.addStyleTag({content:'.cal-grid>*{visibility:visible!important}'});
   const cells=await pieces(p,'.cal-grid > *');
   const detail=await pieces(p,'.day-detail > *:not(.zmanim-soon)');
   out.calendar={w:393,h:900,top:[...top,...grid,...cells],detail}; tag(`calendar top ${top.length+grid.length+cells.length} detail ${detail.length}`); await p.context().close();}
  /* LIBRARY + SIDDUR (header + every tile) */
  {const p=await mk(lang,1700); await p.evaluate(()=>window.go('library')); await p.waitForTimeout(2200); await hideNav(p);
   out.library={w:393,h:900,pieces:await pieces(p,'#app > .topbar, #app .q-tile')}; tag('library '+out.library.pieces.length); await p.context().close();}
  {const p=await mk(lang,2400); await p.evaluate(()=>window.go('siddurHome')); await p.waitForTimeout(3000); await hideNav(p);
   out.siddur={w:393,h:900,pieces:await pieces(p,'#app > .topbar, #app .q-tile')}; tag('siddur '+out.siddur.pieces.length); await p.context().close();}
  /* COMPASS (dark page): header, dial, cards, button */
  {const p=await mk(lang,852); await p.evaluate(()=>window.go('kotelCompass')); await p.waitForTimeout(2000);
   await p.addStyleTag({content:'.compass-full,.compass-fhead,.compass-fbody,.compass-wrap{background:transparent!important;box-shadow:none!important;border:0!important} .compass-dial{border-radius:50%!important;overflow:hidden}'});
   out.compassPieces=await pieces(p,'.compass-fhead, .compass-dial, .compass-deg, .compass-dirname, .compass-target-card, .compass-loc-card'); tag('compass '+out.compassPieces.length); await p.context().close();}
  /* DAILY TEHILLIM reader (every chapter card, dividers, nav, the "I finished" button) + the finish celebration card */
  {const p=await mk(lang,4700); await p.click('[data-home-item="tehillim"] .q-tile'); await p.waitForTimeout(2800); await hideNav(p);
   await p.addStyleTag({content:'.prayer.collapsed{display:none!important}'});
   out.daily={w:393,h:1000,pieces:await pieces(p,'.reader > .reader-head, .reader > .chapter, .reader > .orn-sep, .reader > .reader-nav, .reader > div:last-child')};
   tag('daily '+out.daily.pieces.length);
   await p.evaluate(()=>{const d=document.querySelector('.reader > div:last-child');(d.querySelector('button')||d).click();}); await p.waitForTimeout(2000);
   const ov=await p.$('body > .overlay .modal, body > .overlay > div, .celebrate, .cel-card');
   if(!ov) throw new Error('celebration card not found');
   await p.addStyleTag({content:'body > .overlay{background:transparent!important}'});
   const r=await ov.evaluate(e=>{const b=e.getBoundingClientRect();return {w:b.width,h:b.height};});
   out.celebrate={...r,png:await ov.screenshot({omitBackground:true})}; tag(`celebrate ${r.w}x${r.h}`); await p.context().close();}
  return out;
}

/* full 393x852 screenshots of the home screen per UI language (tab bar visible, like the real phone) */
async function captureLangs(){
  const o={};
  for(const l of LANGS){const p=await mk(l,852); await p.waitForTimeout(400); o[l]=await p.screenshot({type:'png'}); console.log('[langs] '+l); await p.context().close();}
  return o;
}

const langShots=await captureLangs();

for(const site of SITES){
  const dir=path.join(ROOT,'landing',site==='he'?'':'en'); const imgDir=path.join(dir,'img');
  const old=fs.existsSync(path.join(dir,'screens.js'))?JSON.parse(fs.readFileSync(path.join(dir,'screens.js'),'utf8').replace(/^window\.TAMID_SCREENS=/,'').replace(/;\s*$/,'')):{};
  const cap=await captureAll(site);
  const written=new Set();
  const save=(png,opt)=>{const b=webp(png,opt);const n='img/'+crypto.createHash('sha1').update(b).digest('hex').slice(0,12)+'.webp';fs.writeFileSync(path.join(dir,n),b);written.add(n);return n;};
  const r=(v)=>Math.round(v*1000)/1000;
  const conv=(arr)=>arr.map(({png,x,y,w,h})=>({x:r(x),y:r(y),w:r(w),h:r(h),src:save(png)}));
  /* compass pieces: the old page placed the group with no safe-area offset, so start the header at y=66 like before */
  const cp=cap.compassPieces, dyC=66-cp[0].y;
  const D={
    home:{w:393,h:cap.home.h,pieces:conv(cap.home.pieces)},
    nav:(({png,x,y,w,h})=>({x:r(x),y:r(y),w:r(w),h:r(h),src:save(png)}))(cap.nav),
    calendar:{w:393,h:900,top:conv(cap.calendar.top),detail:conv(cap.calendar.detail)},
    langs:Object.fromEntries(LANGS.map(l=>[l,save(langShots[l],{width:560})])),
    library:{w:393,h:900,pieces:conv(cap.library.pieces)},
    siddur:{w:393,h:900,pieces:conv(cap.siddur.pieces)},
    mirror:old.mirror,
    daily:{w:393,h:1000,pieces:conv(cap.daily.pieces)},
    celebrate:{w:r(cap.celebrate.w),h:r(cap.celebrate.h),src:save(cap.celebrate.png)},
    wid:old.wid,
    compassPieces:conv(cp.map(p=>({...p,y:p.y+dyC}))),
  };
  /* carry over the non-web-app art (and the files it points to) */
  for(const f of [...(old.wid||[]),old.mirror]) if(f) written.add(f);
  fs.writeFileSync(path.join(dir,'screens.js'),'window.TAMID_SCREENS='+JSON.stringify(D)+';');
  /* delete every webp/jpg in img/ that neither screens.js nor index.html references any more */
  const html=fs.readFileSync(path.join(dir,'index.html'),'utf8'); let removed=0;
  for(const f of fs.readdirSync(imgDir)){ if(!/\.(webp|jpg)$/.test(f)) continue; const n='img/'+f; if(!written.has(n)&&!html.includes(n)){fs.unlinkSync(path.join(imgDir,f));removed++;} }
  console.log(`[${site}] wrote ${written.size} images, removed ${removed} orphans`);
}
await browser.close(); server.close();
