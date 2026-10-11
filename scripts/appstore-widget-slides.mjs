/* App Store widget slides - same look as appstore-slides.mjs (gold accent headline, glow, real device frame) with
   zoomed widget call-outs and a different layout per slide: Home Screen (device + zoom), sizes (floating widget cards),
   Live Activity (Dynamic Island + Lock Screen). For he/en/fr, dark and light, iPhone 6.9" and iPad 13".
   usage: CHROME=<chromium path> node scripts/appstore-widget-slides.mjs [he,en,fr] [dark|light]
   Raw sources (simulator captures, widgets added through Customize): docs/appstore/raw-widgets[-light][-ipad]/<lang>-<name>.jpg
   with name = home1 (Large), home2 (StandBy S + candle S + Large), home3 (Tehillim S + zmanim S + Medium), island, lock.
   The iPad has every widget on one page (home) plus lock, and no Dynamic Island.
   Output: docs/appstore/widgets[-light]/<lang>/<iphone-6.9|ipad-13>/NN-<key>.png */
import {chromium} from 'playwright';
import fs from 'fs';
const langs=(process.argv[2]||'he,en,fr').split(',');
const LIGHT=process.argv[3]==='light'; const SFX=LIGHT?'-light':'';
const TH=LIGHT
 ? {bg:'radial-gradient(120% 70% at 50% 0%,#fffaf0 0%,#f3e8d0 55%,#e6dac0 100%)',ink:'#22314e',soft:'#46557a',gold:'#8a6414',goldText:'linear-gradient(180deg,#a47a1c,#7a5812)',chip:'rgba(255,252,244,.94)',ring:'rgba(138,100,20,.55)',shadow:'0 40px 90px rgba(80,60,20,.35)',glowA:.35}
 : {bg:'radial-gradient(120% 70% at 50% 0%,#1b2a5c 0%,#0b1226 55%,#05080f 100%)',ink:'#f6f1e4',soft:'#b8c2dc',gold:'#e6c874',goldText:'linear-gradient(180deg,#fff3cf,#e6c874 70%,#c9a24b)',chip:'rgba(16,26,56,.94)',ring:'rgba(230,200,116,.6)',shadow:'0 50px 120px rgba(0,0,0,.75)',glowA:.5};
const C={
 he:{home:{h:'ווידג׳טים *למסך הבית*',s:'תאריך עברי, זמני היום, תהילים ונרות שבת – במבט אחד'},
     sizes:{h:'קטן, בינוני *או גדול*',s:'בוחרים את הגודל ואת המידע שמתאימים לכם',sz:['קטן','בינוני','גדול']},
     live:{h:'הזמן הבא, *בספירה חיה*',s:'במסך הנעילה וב־Dynamic Island, בלי לפתוח את האפליקציה'}},
 en:{home:{h:'Widgets for your *Home Screen*',s:'Hebrew date, daily times, Tehillim and Shabbat candles at a glance'},
     sizes:{h:'Small, medium *or large*',s:'Pick the size and the details that suit you',sz:['Small','Medium','Large']},
     live:{h:'The next zman, *counting down live*',s:'On the Lock Screen and in the Dynamic Island, without opening the app'}},
 fr:{home:{h:'Des widgets *pour l’écran d’accueil*',s:'Date hébraïque, horaires, Tehilim et bougies de Chabbat d’un coup d’œil'},
     sizes:{h:'Petit, moyen *ou grand*',s:'Choisissez la taille et les infos qui vous conviennent',sz:['Petit','Moyen','Grand']},
     live:{h:'Le prochain horaire, *en direct*',s:'Sur l’écran verrouillé et dans la Dynamic Island, sans ouvrir l’app'}}};
/* crop boxes in pixels of the raw capture: [file, x0, y0, x1, y1] */
const CROPS={
 phone:{W:1320,H:2868,L:['home1',90,270,1236,1468],standby:['home2',96,278,630,805],candle:['home2',697,278,1231,805],
        M:['home3',96,936,1230,1462],teh:['home3',96,278,630,805],zm:['home3',697,278,1231,805],
        island:['island',40,45,1280,295],live:['lock',36,1988,1274,2190],acc:['lock',370,2262,1215,2482]},
 ipad:{W:2064,H:2752,teh:['home',267,99,604,436],candle:['home',665,99,1002,436],zm:['home',1068,99,1794,436],
       standby:['home',267,490,604,827],M:['home',1068,490,1794,827],L:['home',273,885,999,1607],live:['lock',527,2408,1537,2555]}};
const b64=f=>fs.readFileSync(f).toString('base64');
const src=(lang,n,ipad)=>`docs/appstore/raw-widgets${SFX}${ipad?'-ipad':''}/${lang}-${n}.jpg`;
const acc=t=>t.replace(/\s*\*([^*]+)\*/g,`<br><span style="background:${TH.goldText};-webkit-background-clip:text;color:transparent">$1</span>`);
/* Realistic device: metal rim, black glass bezel, Dynamic Island (iPhone) / front camera (iPad). */
const frame=(f,w,pos,ipad)=>{ const rim=ipad?Math.round(w*.012):Math.round(w*.016), bez=ipad?Math.round(w*.03):Math.round(w*.014);
  const r=ipad?Math.round(w*.05):Math.round(w*.15), ri=r-rim, rs=Math.max(ri-bez,8), sw=w-2*rim-2*bez;
  const metal=LIGHT?'linear-gradient(135deg,#f1f1f3 0%,#a9abb2 22%,#e4e5e9 48%,#8e9098 74%,#d2d3d8 100%)':'linear-gradient(135deg,#5b5f68 0%,#23252b 24%,#4a4d55 50%,#1c1d22 76%,#3d4048 100%)';
  const island=ipad?`<div style="position:absolute;left:50%;top:${Math.round(bez*.5)}px;transform:translate(-50%,-50%);width:${Math.round(w*.011)}px;height:${Math.round(w*.011)}px;border-radius:50%;background:#1a2230"></div>`:'';
  return `<div style="position:absolute;${pos};width:${w}px;filter:drop-shadow(0 50px 70px rgba(0,0,0,${LIGHT?.3:.6}))"><div style="position:relative;padding:${rim}px;border-radius:${r}px;background:${metal}"><div style="padding:${bez}px;border-radius:${ri}px;background:#050506"><div style="position:relative;border-radius:${rs}px;overflow:hidden;line-height:0"><img src="data:image/jpeg;base64,${b64(f)}" style="display:block;width:${sw}px"/>${island}</div></div></div></div>`; };
/* a zoomed piece of a capture, `w` px wide, clipped to the widget's rounded corners */
const zoom=(lang,ipad,key,w,pos,{radius=.12,ring=true,rot=0}={})=>{ const cr=CROPS[ipad?'ipad':'phone'], [n,x0,y0,x1,y1]=cr[key];
  const s=w/(x1-x0), h=Math.round((y1-y0)*s);
  return `<div style="position:absolute;${pos};width:${w}px;height:${h}px;border-radius:${Math.round(Math.min(w,h)*radius)}px;overflow:hidden;transform:rotate(${rot}deg);box-shadow:${TH.shadow}${ring?`,0 0 0 4px ${TH.ring}`:''}"><img src="data:image/jpeg;base64,${b64(src(lang,n,ipad))}" style="position:absolute;width:${Math.round(cr.W*s)}px;left:${Math.round(-x0*s)}px;top:${Math.round(-y0*s)}px"/></div>`; };
const zh=(ipad,key,w)=>{ const [,x0,y0,x1,y1]=CROPS[ipad?'ipad':'phone'][key]; return Math.round((y1-y0)*w/(x1-x0)); };
const b=await chromium.launch({executablePath:process.env.CHROME||undefined});
for(const lang of langs){ const rtl=lang==='he', T=C[lang];
 for(const ipad of [false,true]){
  if(!fs.existsSync(src(lang,ipad?'home':'home1',ipad))) continue;
  const W=ipad?2064:1320,H=ipad?2752:2868,k=ipad?1.25:1, S=rtl?'right':'left', E=rtl?'left':'right';
  const dir=`docs/appstore/widgets${SFX}/${lang}/${ipad?'ipad-13':'iphone-6.9'}`; fs.mkdirSync(dir,{recursive:true});
  const page=await b.newPage({viewport:{width:W,height:H}});
  const head=t=>`<div style="position:absolute;top:${ipad?110:120}px;left:70px;right:70px;text-align:center"><div style="font-weight:900;font-size:${100*k}px;line-height:1.1;text-wrap:balance;color:${TH.ink}">${acc(t.h)}</div><div style="margin-top:${26*k}px;font-size:${40*k}px;line-height:1.35;color:${TH.soft};font-weight:500;text-wrap:balance">${t.s}</div></div>`;
  const chip=(t,pos)=>`<div style="position:absolute;${pos};padding:${14*k}px ${34*k}px;border-radius:60px;background:${TH.chip};color:${TH.ink};font-size:${40*k}px;font-weight:800;border:3px solid ${TH.ring};box-shadow:0 14px 40px rgba(0,0,0,.35)">${t}</div>`;
  const slides=[];
  /* 1 - Home Screen: device off to one side, the candle widget zoomed out of it on the other */
  { const dw=ipad?1500:1000, top=ipad?640:820;
    let body=head(T.home)+frame(src(lang,ipad?'home':'home2',ipad),dw,`${S}:${ipad?80:40}px;top:${top}px`,ipad);
    const zw=ipad?760:600;
    body+=zoom(lang,ipad,'candle',zw,`${E}:${ipad?70:40}px;top:${ipad?1700:1960}px`,{rot:rtl?-3:3});
    body+=zoom(lang,ipad,'standby',Math.round(zw*.82),`${E}:${ipad?140:70}px;top:${ipad?1060:1290}px`,{rot:rtl?2:-2});
    slides.push(['wid-home',body]); }
  /* 2 - sizes: floating widget cards, no device (the iPad's zmanim widget is medium there, so its small pair is Tehillim + candles) */
  { const lw=ipad?820:860, mw=ipad?1050:1000, sw=ipad?460:450, z2=ipad?'candle':'zm', y1=ipad?600:690, y2=y1+zh(ipad,'L',lw)+(ipad?60:60), y3=y2+zh(ipad,'M',mw)+(ipad?70:70);
    let body=head(T.sizes);
    body+=zoom(lang,ipad,'L',lw,`left:${Math.round((W-lw)/2)}px;top:${y1}px`,{rot:-1.5})+chip(T.sizes.sz[2],`${E}:${ipad?150:40}px;top:${y1-40}px`);
    body+=zoom(lang,ipad,'M',mw,`left:${Math.round((W-mw)/2)}px;top:${y2}px`,{rot:1.2})+chip(T.sizes.sz[1],`${S}:${ipad?150:40}px;top:${y2-40}px`);
    const gap=ipad?90:60, x=Math.round((W-2*sw-gap)/2);
    body+=zoom(lang,ipad,rtl?z2:'teh',sw,`left:${x}px;top:${y3}px`,{rot:-2})+zoom(lang,ipad,rtl?'teh':z2,sw,`left:${x+sw+gap}px;top:${y3+30}px`,{rot:2});
    body+=chip(T.sizes.sz[0],`left:50%;transform:translateX(-50%);top:${y3+zh(ipad,'teh',sw)+(ipad?40:40)}px`);
    slides.push(['wid-sizes',body]); }
  /* 3 - Live Activity: the Dynamic Island blown up on top, the Lock Screen below with its banner zoomed
     (iPad: no Dynamic Island, so the Lock Screen alone, larger) */
  { const iw=1200, dw=ipad?1360:940, top=ipad?620:1200;
    let body=head(T.live);
    if(!ipad) body+=zoom(lang,ipad,'island',iw,`left:${Math.round((W-iw)/2)}px;top:780px`,{radius:.5,ring:false});
    body+=frame(src(lang,'lock',ipad),dw,`left:50%;transform:translateX(-50%);top:${top}px`,ipad);
    // the zoomed banner sits right over the device's own banner (same centre), so it is not shown twice
    const cr=CROPS[ipad?'ipad':'phone'], rim=Math.round(dw*(ipad?.012:.016)), bez=Math.round(dw*(ipad?.03:.014)), sc=(dw-2*rim-2*bez)/cr.W;
    const cy=top+rim+bez+(cr.live[2]+cr.live[4])/2*sc, lw=ipad?1700:1220;
    body+=zoom(lang,ipad,'live',lw,`left:${Math.round((W-lw)/2)}px;top:${Math.round(cy-zh(ipad,'live',lw)/2)}px`,{radius:.3});
    slides.push(['wid-live',body]); }
  let n=0;
  for(const [key,body] of slides){
    const glow=`<div style="position:absolute;right:-20%;top:-8%;width:90%;height:36%;border-radius:50%;background:#d4af5f;opacity:${LIGHT?.35:.38};filter:blur(170px)"></div><div style="position:absolute;left:-10%;top:30%;width:70%;height:40%;border-radius:50%;background:#e0562e;opacity:${TH.glowA*.45};filter:blur(160px)"></div><div style="position:absolute;right:-15%;top:60%;width:60%;height:35%;border-radius:50%;background:#6f83d6;opacity:${TH.glowA*.4};filter:blur(150px)"></div>`;
    const orn=['12%,8%','88%,14%','8%,46%','93%,62%'].map((p,i)=>{const [x,y]=p.split(',');return `<div style="position:absolute;left:${x};top:${y};font-size:${34+i*6}px;color:${TH.gold};opacity:.55">✦</div>`}).join('');
    await page.setContent(`<html dir="${rtl?'rtl':'ltr'}"><body style="margin:0;overflow:hidden"><div style="position:absolute;left:0;top:0;width:${W}px;height:${H}px;overflow:hidden;background:${TH.bg};font-family:'Noto Sans Hebrew','Noto Sans',sans-serif">${glow}${orn}${body}</div></body></html>`);
    await page.waitForTimeout(150); n++;
    await page.screenshot({path:`${dir}/${String(n).padStart(2,'0')}-${key}.png`});
  }
  await page.close();
 }}
await b.close(); console.log('done');
