/* App Store screenshots built from REAL native captures of the app (iOS simulator, Liquid Glass UI).
   usage: node scripts/appstore-native.mjs [he,en,fr,ru,ka]
   Raw sources: docs/appstore/raw-native/<lang>-<screen>.png (1320x2868, light theme, status bar 9:41) - see
   docs/appstore/NATIVE.md for how they are captured (SIMCTL_CHILD_BETEL_SHOT_* env vars, no taps needed).
   Output: docs/appstore/native/<lang>/iphone-6.9/NN-name.png (1320x2868). Slide 06 (widget sizes) is NOT regenerated
   here - it stays the existing docs/appstore/widgets slide. Slide 07 (Live Activity) is drawn from
   ios/App/BetElWidget/BetElLiveActivityWidget.swift (same layout, colours and strings). */
import {chromium} from 'playwright';
import fs from 'fs';

const langs=(process.argv[2]||'he,en,fr,ru,ka').split(',');
const W=1320,H=2868;
const bg='radial-gradient(120% 70% at 50% 0%,#1b2a5c 0%,#0b1226 55%,#05080f 100%)';
const gold='background:linear-gradient(180deg,#fff3cf,#e6c874 70%,#c9a24b);-webkit-background-clip:text;color:transparent';
const font="'Noto Sans Hebrew','Noto Sans Georgian',-apple-system,'Helvetica Neue',sans-serif";
const b64=f=>fs.readFileSync(f).toString('base64');
const raw=(l,s)=>`docs/appstore/raw-native/${l}-${s}.png`;

/* headline + small chip per slide */
const T={
 home:{he:['כל הלימוד היומי','במקום אחד'],en:['Your whole daily study','in one place'],fr:['Tout votre étude','au même endroit'],ru:['Всё ежедневное','изучение в одном месте'],ka:['მთელი ყოველდღიური','სწავლა ერთ აპში']},
 chok:{he:['חוק לישראל','כל יום, בקצב אחד'],en:['Chok LeYisrael','every day, one steady pace'],fr:['Ḥok LeYisraël','chaque jour, un seul rythme'],ru:['Хок ле-Исраэль','каждый день в одном ритме'],ka:['ჰოკ ლეისრაელი','ყოველდღე ერთი რიტმით']},
 calendar:{he:['לוח עברי','וזמני היום'],en:['Hebrew calendar','and daily times'],fr:['Calendrier hébraïque','et horaires du jour'],ru:['Еврейский календарь','и времена дня'],ka:['ებრაული კალენდარი','და დღის დროები']},
 siddur:{he:['סידור, ברכות','ותפילות'],en:['Siddur, blessings','and prayers'],fr:['Sidour, bénédictions','et prières'],ru:['Сидур, благословения','и молитвы'],ka:['სიდური, კურთხევები','და ლოცვები']},
 reading:{he:['ברכות בנוסח','עדות המזרח'],en:['Blessings in','Edot HaMizrach nusach'],fr:['Bénédictions selon','le rite séfarade oriental'],ru:['Благословения','по нусах мизрах'],ka:['კურთხევები','აღმოსავლური წესით']},
 live:{he:['הזמן הבא','ישר במסך הנעילה'],en:['The next zman,','right on your Lock Screen'],fr:['Le prochain horaire,','sur l’écran verrouillé'],ru:['Ближайшее время','прямо на экране блокировки'],ka:['შემდეგი დრო','პირდაპირ ჩაკეტილ ეკრანზე']},
 langs:{he:['חמש שפות','בלחיצה אחת'],en:['Five languages,','one tap'],fr:['Cinq langues,','en un geste'],ru:['Пять языков','одним касанием'],ka:['ხუთი ენა','ერთი შეხებით']},
};

/* Live Activity strings (ios/App/BetElWidget/Localization.swift) */
const LA={
 he:{title:'הַזְּמַן הַבָּא',label:'זְרִיחָה',date:'יום ראשון, 15 בנובמבר'},
 en:{title:'Next zman',label:'Sunrise',date:'Sunday, 15 November'},
 fr:{title:'Prochain horaire',label:'Lever du soleil',date:'dimanche 15 novembre'},
 ru:{title:'Следующее время',label:'Восход',date:'воскресенье, 15 ноября'},
 ka:{title:'შემდეგი დრო',label:'მზის ამოსვლა',date:'კვირა, 15 ნოემბერი'},
};
const sun=(c1,c2,s)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24"><g stroke="${c2}" stroke-width="1.8" stroke-linecap="round">${[0,45,90,135,180,225,270,315].map(a=>`<line x1="12" y1="2.4" x2="12" y2="4.9" transform="rotate(${a} 12 12)"/>`).join('')}</g><circle cx="12" cy="12" r="4.6" fill="${c1}"/></svg>`;

const phone=(inner,w,extra='')=>`<div style="position:absolute;width:${w}px;border-radius:84px;overflow:hidden;border:12px solid #0a0f1f;box-shadow:0 0 0 3px rgba(230,200,116,.55),0 50px 120px rgba(0,0,0,.75),0 0 220px rgba(230,200,116,.14);${extra}">${inner}</div>`;
const shell=(lang,body)=>`<html dir="ltr" style="width:${W}px;height:${H}px;overflow:hidden"><body style="margin:0;width:${W}px;height:${H}px;overflow:hidden;position:relative;background:${bg};font-family:${font}">
  <div style="position:absolute;left:-200px;right:-200px;top:380px;height:900px;background:radial-gradient(50% 50% at 50% 50%,rgba(230,200,116,.16),transparent 70%)"></div>${body}</body></html>`;
const head=(t,lang)=>`<div dir="${lang==='he'?'rtl':'ltr'}" style="position:absolute;top:96px;left:60px;right:60px;height:380px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">
  <div style="font-weight:800;font-size:96px;line-height:1.14;${gold}">${t[0]}</div>
  <div style="margin-top:14px;font-weight:600;font-size:60px;line-height:1.2;color:#cdd6ec">${t[1]}</div></div>`;
const img=(f)=>`<img src="data:image/png;base64,${b64(f)}" style="display:block;width:100%"/>`;

/* the real captured screen, phone bleeding off the bottom edge */
const shot=(lang,screen,key)=>shell(lang,`${head(T[key][lang],lang)}${phone(img(raw(lang,screen)),1040,'left:140px;top:560px')}`);

/* Lock Screen with the Live Activity banner (same layout as LockScreenView.fullLayout, scaled x3 from pt) */
const lockScreen=(lang)=>{
  const t=LA[lang], rtl=lang==='he';
  const countdown='0:46:12', end='06:07';
  return `<div dir="${rtl?'rtl':'ltr'}" style="width:1320px;height:2868px;position:relative;background:radial-gradient(90% 60% at 50% 20%,#27407f 0%,#10193a 55%,#070b16 100%);font-family:${font};color:#fff">
    <div style="position:absolute;top:210px;left:0;right:0;text-align:center;font-size:48px;font-weight:600;opacity:.85">${t.date}</div>
    <div style="position:absolute;top:262px;left:0;right:0;text-align:center;font-size:300px;font-weight:700;letter-spacing:-6px;line-height:1;direction:ltr">9:41</div>
    <div style="position:absolute;top:760px;left:48px;right:48px;border-radius:72px;background:#16224a;box-shadow:0 20px 60px rgba(0,0,0,.45);padding:48px 54px;box-sizing:border-box">
      <div style="display:flex;align-items:center;gap:42px">
        <div style="width:150px;height:150px;border-radius:50%;background:rgba(212,175,95,.16);border:3px solid rgba(212,175,95,.45);display:flex;align-items:center;justify-content:center;flex:none">${sun('#f3e3af','#d4af5f',78)}</div>
        <div style="flex:1;min-width:0">
          <div style="font-size:36px;color:#cdd6ec">${t.title}</div>
          <div style="font-size:60px;font-weight:700;color:#f6f1e4;margin:6px 0">${t.label}</div>
          <div style="font-size:39px;font-weight:500;color:#d4af5f;direction:ltr;text-align:${rtl?'right':'left'}">${end}</div>
        </div>
        <div style="font-size:90px;font-weight:700;color:#f3e3af;font-variant-numeric:tabular-nums;direction:ltr;flex:none">${countdown}</div>
      </div>
      <div style="margin-top:36px;height:12px;border-radius:6px;background:rgba(212,175,95,.22);overflow:hidden;direction:${rtl?'rtl':'ltr'}"><div style="width:62%;height:100%;background:#d4af5f;border-radius:6px"></div></div>
    </div>
    <div style="position:absolute;bottom:150px;left:150px;width:130px;height:130px;border-radius:50%;background:rgba(255,255,255,.14)"></div>
    <div style="position:absolute;bottom:150px;right:150px;width:130px;height:130px;border-radius:50%;background:rgba(255,255,255,.14)"></div>
  </div>`;
};
const liveSlide=(lang)=>{
  const t=LA[lang], rtl=lang==='he';
  const island=`<div dir="${rtl?'rtl':'ltr'}" style="position:absolute;left:90px;right:90px;top:2010px;border-radius:110px;background:#000;box-shadow:0 0 0 3px rgba(230,200,116,.55),0 40px 100px rgba(0,0,0,.8);padding:50px 66px 56px;box-sizing:border-box">
      <div style="display:flex;align-items:center;justify-content:space-between">
        <div>${sun('#f3e3af','#d4af5f',66)}</div>
        <div style="font-size:48px;font-weight:600;color:#f6f1e4">${t.label}</div>
        <div style="font-size:60px;font-weight:700;color:#f3e3af;font-variant-numeric:tabular-nums;direction:ltr">0:46:12</div>
      </div>
      <div style="margin-top:34px;height:12px;border-radius:6px;background:rgba(212,175,95,.22);overflow:hidden"><div style="width:62%;height:100%;background:#d4af5f;border-radius:6px"></div></div></div>
    <div style="position:absolute;left:50%;transform:translateX(-50%);top:2430px;width:560px;height:150px;border-radius:75px;background:#000;box-shadow:0 0 0 3px rgba(230,200,116,.45),0 30px 80px rgba(0,0,0,.7);display:flex;align-items:center;justify-content:space-between;padding:0 44px;box-sizing:border-box;direction:ltr">
      <div>${sun('#f3e3af','#d4af5f',54)}</div><div style="font-size:48px;font-weight:600;color:#f3e3af;font-variant-numeric:tabular-nums">46:12</div></div>`;
  return shell(lang,`${head(T.live[lang],lang)}${phone(`<div style="width:1100px;height:2390px;position:relative;overflow:hidden"><div style="transform:scale(.8333);transform-origin:0 0;width:1320px;height:2868px">${lockScreen(lang)}</div></div>`,1100,'left:110px;top:560px')}${island}`);
};
/* two languages side by side (real home captures) */
const langSlide=(lang)=>{
  const other=lang==='en'?'he':'en';
  return shell(lang,`${head(T.langs[lang],lang)}${phone(img(raw(lang,'home')),700,'left:70px;top:640px;transform:rotate(-4deg)')}${phone(img(raw(other,'home')),700,'right:70px;top:800px;transform:rotate(4deg)')}`);
};

const SLIDES=[
 ['01-home',l=>shot(l,'home','home')],
 ['02-chok',l=>shot(l,'chok','chok')],
 ['03-calendar',l=>shot(l,'calendar','calendar')],
 ['04-siddur',l=>shot(l,'brachot','siddur')],
 ['05-reading',l=>shot(l,'meein','reading')],
 /* 06 = widget sizes (kept, not generated here) */
 ['07-live-activity',liveSlide],
 ['08-languages',langSlide],
];
const b=await chromium.launch({executablePath:process.env.CHROME||undefined});
for(const lang of langs){
  const dir=`docs/appstore/native/${lang}/iphone-6.9`; fs.mkdirSync(dir,{recursive:true});
  const page=await b.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});
  for(const [n,fn] of SLIDES){
    const need=n==='07-live-activity'?[]:n==='08-languages'?[raw(lang,'home'),raw(lang==='en'?'he':'en','home')]:[raw(lang,n.split('-')[1]==='siddur'?'brachot':n.split('-')[1]==='reading'?'meein':n.split('-')[1])];
    if(need.some(f=>!fs.existsSync(f))){ console.log('skip',lang,n); continue; }
    fs.writeFileSync('/tmp/as-slide.html',fn(lang));
    await page.goto('file:///tmp/as-slide.html'); await page.waitForTimeout(250);
    await page.screenshot({path:`${dir}/${n}.png`});
  }
  await page.close();
}
await b.close(); console.log('done');
