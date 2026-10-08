/* App Store slides v2 - real marketing designs (eyebrow, headline with accent, sub-line, feature bullets, floating callouts,
   zoomed detail card, device frame, glow + ornaments), for he/en/fr/ru, dark and light, iPhone 6.9" and iPad 13".
   usage: node scripts/appstore-slides.mjs [he,en,fr,ru] [dark|light]
   Raw sources, first match wins: docs/appstore/raw-device[-light][-ipad]/<lang>-<NN>-<name>.png (simulator / iPhone),
   then raw-web[-light][-ipad]/. Optional real-device slide: <lang>-10-widgets.png.
   Output: docs/appstore/slides[-light]/<lang>/<iphone-6.9|ipad-13>/<NN>-<key>.png  (upload in numeric order, max 10). */
import {chromium} from 'playwright';
import fs from 'fs';
const langs=(process.argv[2]||'he,en,fr,ru').split(',');
const LIGHT=process.argv[3]==='light'; const SFX=LIGHT?'-light':'';
const TH=LIGHT
 ? {bg:'radial-gradient(120% 70% at 50% 0%,#fffaf0 0%,#f3e8d0 55%,#e6dac0 100%)',ink:'#22314e',soft:'#46557a',gold:'#8a6414',goldText:'linear-gradient(180deg,#a47a1c,#7a5812)',chip:'rgba(255,255,255,.7)',card:'rgba(255,252,244,.94)',cardInk:'#22314e',bezel:'#d9cdb2',ring:'rgba(138,100,20,.5)',shadow:'0 40px 90px rgba(80,60,20,.35)',glowA:.35}
 : {bg:'radial-gradient(120% 70% at 50% 0%,#1b2a5c 0%,#0b1226 55%,#05080f 100%)',ink:'#f6f1e4',soft:'#b8c2dc',gold:'#e6c874',goldText:'linear-gradient(180deg,#fff3cf,#e6c874 70%,#c9a24b)',chip:'rgba(255,255,255,.08)',card:'rgba(16,26,56,.94)',cardInk:'#f6f1e4',bezel:'#0a0f1f',ring:'rgba(230,200,116,.55)',shadow:'0 50px 120px rgba(0,0,0,.75)',glowA:.5};
const ACC={chok:'#6f83d6',home:'#d4af5f',cal:'#d4af5f',teh:'#d4af5f',pray:'#8a9a3a',meein:'#8a9a3a',lib:'#c98a3f',set:'#6f83d6',lang:'#38a3a5',qr:'#d4af5f',wid:'#e0562e',hero:'#d4af5f'};
/* ---- copy (he / en / fr / ru). `*word*` = accent colour ---- */
const C={
he:{hero:{h:'הלימוד היומי שלך, *בכל מקום*',s:'חוק לישראל · תהילים · זוהר · בן איש חי · מוסר · סידור',pills:['חוק לישראל','תהילים יומי','זוהר יומי','בן איש חי','מוסר','סידור וברכות']},
 home:{e:'הכל במקום אחד',h:'כל הלימוד היומי *במקום אחד*',s:'תאריך עברי, זמני היום וכל הלימוד שלך – בלחיצה אחת',co:[['🗓','תאריך עברי וזמני היום','l',560],['📚','6 תחומי לימוד','r',1260],['🕯','הדלקת נרות ופרשת השבוע','l',1700]]},
 chok:{e:'חוק לישראל',h:'לימוד יומי, *בקצב אחד*',s:'תורה עם רש״י ואור החיים, נביאים, משנה, גמרא, זוהר והלכה',b:['רש״י ואור החיים בלחיצה','תרגום ותעתיק בכל שפה','מעקב התקדמות ותזכורות']},
 cal:{e:'לוח עברי',h:'לוח עברי *וזמני היום*',s:'התאריך, הפרשה והזמנים – לפי המקום שלך',co:[['📖','פרשת השבוע והקריאה היומית','r',1500],['📍','זמנים לפי המקום – אוטומטי','l',2050]]},
 teh:{e:'תהילים',h:'תהילים *יומי*',s:'חלוקה חודשית או שבועית, מעקב פרקים ותזכורת עדינה',b:['חלוקה חודשית / שבועית','סימון פרקים שנקראו','שיתוף פרק בלחיצה']},
 meein:{e:'נוסח עדות המזרח',h:'ברכות ותפילות *בנוסח עדות המזרח*',s:'ברכת המזון · ברכה מעין שלוש · ברכות הנהנין · סידור מלא',co:[['✦','נוסח עדות המזרח','r',700]]},
 lib:{e:'ספרייה',h:'ספרייה *מלאה* של ספרי קודש',s:'תורה, נביאים, כתובים, משנה, גמרא, רמב״ם, זוהר ותניא',b:['מעל 6 תחומים וספרים','חיפוש בכל הספרים','קריאה בנוחות, בערכה בהירה וכהה']},
 wid:{e:'ווידג׳טים',h:'ווידג׳טים *לבית ולמסך הנעילה*',s:'תאריך עברי, זמני היום, תהילים, נרות שבת וספירת העומר'},
 set:{e:'מותאם אליך',h:'מותאם *אליך*',s:'חמש שפות · ערכה בהירה וכהה · תזכורות · מיקום אוטומטי',b:['עברית, אנגלית, צרפתית, רוסית וגאורגית','תזכורות יומיות עדינות','מיקום אוטומטי']},
 lang:{e:'חמש שפות',h:'חמש שפות, *לחיצה אחת*',s:'עברית · English · Français · Русский · ქართული'},
 qr:{e:'שיתוף',h:'שתפו עם *קוד QR*',s:'קוד מעוצב לשיתוף האפליקציה – גם בלי אינטרנט'}},
en:{hero:{h:'Your daily study, *anywhere*',s:'Chok LeYisrael · Tehillim · Zohar · Ben Ish Chai · Musar · Siddur',pills:['Chok LeYisrael','Daily Tehillim','Daily Zohar','Ben Ish Chai','Musar','Siddur & blessings']},
 home:{e:'All in one place',h:'Your whole daily study *in one place*',s:'Hebrew date, daily times and all your learning - one tap away',co:[['🗓','Hebrew date & daily times','l',560],['📚','6 study tracks','r',1260],['🕯','Candle lighting & parasha','l',1700]]},
 chok:{e:'Chok LeYisrael',h:'Daily learning, *one steady pace*',s:'Torah with Rashi and Ohr HaChaim, Nevi\'im, Mishnah, Gemara, Zohar and Halacha',b:['Rashi & Ohr HaChaim on tap','Transliteration in every language','Progress tracking & reminders']},
 cal:{e:'Hebrew calendar',h:'Hebrew calendar *& daily times*',s:'The date, the parasha and the times - for your place',co:[['📖','Parasha & daily reading','r',1500],['📍','Times for your location - automatic','l',2050]]},
 teh:{e:'Tehillim',h:'Daily *Tehillim*',s:'Monthly or weekly division, chapter tracking and a gentle reminder',b:['Monthly / weekly division','Mark chapters as read','Share a chapter in one tap']},
 meein:{e:'Edot HaMizrach nusach',h:'Blessings & prayers *in Edot HaMizrach nusach*',s:'Birkat HaMazon · Meein Shalosh · Blessings before eating · Full siddur',co:[['✦','Edot HaMizrach nusach','r',700]]},
 lib:{e:'Library',h:'A *full library* of holy books',s:'Torah, Nevi\'im, Ketuvim, Mishnah, Gemara, Rambam, Zohar and Tanya',b:['6+ study tracks and books','Search across all books','Comfortable reading, light & dark']},
 wid:{e:'Widgets',h:'Widgets for the *Home & Lock Screen*',s:'Hebrew date, daily times, Tehillim, Shabbat candles and the Omer count'},
 set:{e:'Made for you',h:'Made *for you*',s:'Five languages · light & dark · reminders · automatic location',b:['Hebrew, English, French, Russian, Georgian','Gentle daily reminders','Automatic location']},
 lang:{e:'Five languages',h:'Five languages, *one tap*',s:'עברית · English · Français · Русский · ქართული'},
 qr:{e:'Share',h:'Share with a *QR code*',s:'A designed code to share the app - works offline too'}},
fr:{hero:{h:'Votre étude quotidienne, *partout*',s:'Ḥok LeYisraël · Tehilim · Zohar · Ben Ich ‘Haï · Moussar · Sidour',pills:['Ḥok LeYisraël','Tehilim','Zohar','Ben Ich ‘Haï','Moussar','Sidour']},
 home:{e:'Tout au même endroit',h:'Tout votre étude quotidienne *au même endroit*',s:'Date hébraïque, horaires et tout votre étude, en un geste',co:[['🗓','Date hébraïque et horaires','l',560],['📚','6 parcours d’étude','r',1260],['🕯','Bougies et paracha','l',1700]]},
 chok:{e:'Ḥok LeYisraël',h:'Étude quotidienne, *un seul rythme*',s:'Torah avec Rachi et Or HaḤaïm, Prophètes, Michna, Guemara, Zohar',b:['Rachi et Or HaḤaïm en un geste','Translittération dans chaque langue','Suivi et rappels']},
 cal:{e:'Calendrier',h:'Calendrier hébraïque *et horaires*',s:'La date, la paracha et les horaires de votre lieu',co:[['📖','Paracha et lecture du jour','r',1500],['📍','Horaires selon votre lieu','l',2050]]},
 teh:{e:'Tehilim',h:'Tehilim *quotidiens*',s:'Division mensuelle ou hebdomadaire, suivi et rappel discret',b:['Mensuel / hebdomadaire','Chapitres lus','Partage en un geste']},
 meein:{e:'Rite séfarade oriental',h:'Bénédictions et prières *rite séfarade oriental*',s:'Birkat HaMazon · Méèn Chalosh · Bénédictions avant de manger · Sidour',co:[['✦','Rite séfarade oriental','r',700]]},
 lib:{e:'Bibliothèque',h:'Une *bibliothèque complète*',s:'Torah, Prophètes, Hagiographes, Michna, Guemara, Rambam, Zohar',b:['Plus de 6 parcours','Recherche dans tous les livres','Mode clair et sombre']},
 wid:{e:'Widgets',h:'Widgets pour l’*écran d’accueil et verrouillé*',s:'Date hébraïque, horaires, Tehilim, bougies et Omer'},
 set:{e:'Pour vous',h:'Pensé *pour vous*',s:'Cinq langues · clair et sombre · rappels · localisation automatique',b:['Hébreu, anglais, français, russe, géorgien','Rappels quotidiens discrets','Localisation automatique']},
 lang:{e:'Cinq langues',h:'Cinq langues, *un seul geste*',s:'עברית · English · Français · Русский · ქართული'},
 qr:{e:'Partager',h:'Partagez avec un *QR code*',s:'Un code élégant pour partager l’app – même hors ligne'}},
ru:{hero:{h:'Ваше ежедневное изучение – *везде*',s:'Хок ле-Исраэль · Теилим · Зоар · Бен Иш Хай · Мусар · Сидур',pills:['Хок ле-Исраэль','Теилим','Зоар','Бен Иш Хай','Мусар','Сидур']},
 home:{e:'Всё в одном месте',h:'Всё ежедневное изучение *в одном месте*',s:'Еврейская дата, времена дня и всё ваше изучение – одним касанием',co:[['🗓','Еврейская дата и времена дня','l',560],['📚','6 направлений','r',1260],['🕯','Свечи и недельная глава','l',1700]]},
 chok:{e:'Хок ле-Исраэль',h:'Ежедневное изучение, *в одном ритме*',s:'Тора с Раши и Ор ха-Хаим, Пророки, Мишна, Гемара, Зоар',b:['Раши и Ор ха-Хаим одним касанием','Транслитерация на каждом языке','Прогресс и напоминания']},
 cal:{e:'Календарь',h:'Еврейский календарь *и времена дня*',s:'Дата, глава недели и времена для вашего места',co:[['📖','Глава недели и чтение дня','r',1500],['📍','Времена для вашего места','l',2050]]},
 teh:{e:'Теилим',h:'Ежедневные *Теилим*',s:'Месячное или недельное деление, отслеживание и мягкое напоминание',b:['Месяц / неделя','Отметка прочитанных глав','Поделиться главой']},
 meein:{e:'Нусах мизрах',h:'Благословения и молитвы *по нусах мизрах*',s:'Биркат ха-мазон · Меэйн шалош · Благословения перед едой · Сидур',co:[['✦','Нусах мизрах','r',700]]},
 lib:{e:'Библиотека',h:'*Полная* библиотека священных книг',s:'Тора, Пророки, Писания, Мишна, Гемара, Рамбам, Зоар',b:['Более 6 направлений','Поиск по всем книгам','Светлая и тёмная тема']},
 wid:{e:'Виджеты',h:'Виджеты для *экрана и блокировки*',s:'Еврейская дата, времена дня, Теилим, свечи и счёт Омера'},
 set:{e:'Для вас',h:'Настроено *для вас*',s:'Пять языков · светлая и тёмная тема · напоминания · геолокация',b:['Иврит, английский, французский, русский, грузинский','Мягкие ежедневные напоминания','Автоматическое местоположение']},
 lang:{e:'Пять языков',h:'Пять языков, *одно касание*',s:'עברית · English · Français · Русский · ქართული'},
 qr:{e:'Поделиться',h:'Поделитесь по *QR-коду*',s:'Красивый код для обмена приложением – работает и офлайн'}}};
/* slide = [key, raw name, accent, zoom crop {y0,y1} of the raw image or null] */
const SLIDES=[['hero',null,'hero'],['home','01-home','home'],['chok','02-chok','chok',{y0:.26,y1:.56}],['cal','03-calendar','cal',{y0:.60,y1:.90}],['teh','04-tehillim','teh'],
 ['meein','06-meein','meein',{y0:.22,y1:.52}],['lib','08-library','lib'],['wid','10-widgets','wid'],['set','07-settings','set'],['lang',null,'lang'],['qr','09-qr','qr']];
const b64=f=>fs.readFileSync(f).toString('base64');
const pngSize=f=>{ const d=fs.readFileSync(f); return {w:d.readUInt32BE(16),h:d.readUInt32BE(20)}; };
const logo=fs.existsSync('assets/logo.png')?b64('assets/logo.png'):'';
const find=(lang,n,ipad)=>{ const d=ipad?['raw-device-ipad','raw-web-ipad']:['raw-device','raw-web']; for(const x of d){ const f=`docs/appstore/${x}${SFX}/${lang}-${n}.png`; if(fs.existsSync(f)) return f; } return null; };
const acc=(t,c)=>t.replace(/\s*\*([^*]+)\*/g,`<br><span style="background:${TH.goldText};-webkit-background-clip:text;color:transparent">$1</span>`);
const b=await chromium.launch({executablePath:process.env.CHROME||'/opt/pw-browsers/chromium'});
for(const lang of langs){ const rtl=lang==='he';
 for(const ipad of [false,true]){
  const W=ipad?2064:1320,H=ipad?2752:2868,k=ipad?1.25:1;                       // k scales text for iPad
  const dir=`docs/appstore/slides${SFX}/${lang}/${ipad?'ipad-13':'iphone-6.9'}`; fs.mkdirSync(dir,{recursive:true});
  const page=await b.newPage({viewport:{width:W,height:H}});
  let n=0;
  for(const [key,raw,ak,zoom] of SLIDES){
    if(key==='wid' && !find(lang,'10-widgets',ipad)) continue;
    if(key==='set' && find(lang,'10-widgets',ipad)) continue;               // widgets slide replaces the settings slide
    const T=C[lang][key]; const col=ACC[ak]; const src=raw?find(lang,raw,ipad):null;
    if(key==='lang'){ /* two phones */ }
    else if(raw && !src) continue;
    const glow=`<div style="position:absolute;right:-20%;top:-8%;width:90%;height:36%;border-radius:50%;background:#d4af5f;opacity:${LIGHT?.35:.38};filter:blur(170px)"></div>`+`<div style="position:absolute;left:-10%;top:30%;width:70%;height:40%;border-radius:50%;background:${col};opacity:${TH.glowA*.55};filter:blur(160px)"></div><div style="position:absolute;right:-15%;top:55%;width:60%;height:35%;border-radius:50%;background:${col};opacity:${TH.glowA*.4};filter:blur(150px)"></div>`;
    const orn=['12%,8%','88%,14%','8%,46%','93%,62%'].map((p,i)=>{const [x,y]=p.split(',');return `<div style="position:absolute;left:${x};top:${y};font-size:${34+i*6}px;color:${TH.gold};opacity:.55">✦</div>`}).join('');
    const eyebrow=T.e?`<div style="color:${TH.gold};font-size:${36*k}px;font-weight:700;letter-spacing:${lang==='he'?2:7}px;text-transform:uppercase">${T.e}</div>`:'';
    let body='';
    const headBlock=`<div style="position:absolute;top:${(ipad?110:120)}px;left:70px;right:70px;text-align:center">${eyebrow}<div style="margin-top:${34*k}px;font-weight:900;font-size:${(key==='hero'?118:100)*k}px;line-height:1.1;text-wrap:balance;color:${TH.ink}">${acc(T.h||'',col)}</div><div style="margin-top:${26*k}px;font-size:${40*k}px;line-height:1.35;color:${TH.soft};font-weight:500">${T.s||''}</div></div>`;
    const devW=ipad?1240:1090, devTop=ipad?800:800;
    const device=f=>`<div style="position:absolute;left:50%;transform:translateX(-50%);top:${devTop}px;width:${devW}px;border-radius:${ipad?64:96}px;overflow:hidden;border:${ipad?14:14}px solid ${LIGHT?'#1c1c1e':'#0a0a0c'};box-shadow:0 0 0 3px ${TH.ring},${TH.shadow}"><img src="data:image/png;base64,${b64(f)}" style="display:block;width:100%"/></div>`;
    if(key==='hero'){
      body=`${logo?`<img src="data:image/png;base64,${logo}" style="position:absolute;left:50%;transform:translateX(-50%);top:${ipad?330:300}px;width:${ipad?620:600}px;-webkit-mask-image:radial-gradient(circle at 50% 50%,#000 52%,transparent 70%)"/>`:''}
      <div style="position:absolute;left:0;right:0;top:${ipad?1010:930}px;text-align:center;font-weight:900;font-size:${(lang==='he'?230:200)*k}px;background:${TH.goldText};-webkit-background-clip:text;color:transparent">${lang==='he'?'תמיד':'Tamid'}</div>
      <div style="position:absolute;left:90px;right:90px;top:${ipad?1330:1230}px;text-align:center;font-weight:800;font-size:${78*k}px;line-height:1.2;color:${TH.ink}">${acc(T.h,col)}</div>
      <div style="position:absolute;left:90px;right:90px;top:${ipad?1560:1480}px;text-align:center;font-size:${42*k}px;color:${TH.soft}">${T.s}</div>
      <div style="position:absolute;left:70px;right:70px;top:${ipad?1760:1700}px;display:flex;flex-wrap:wrap;gap:24px;justify-content:center">${T.pills.map((p,i)=>`<span style="padding:${22*k}px ${40*k}px;border-radius:70px;font-size:${50*k}px;font-weight:700;color:${LIGHT?'#22314e':'#fff'};background:linear-gradient(135deg,${['#6f83d6','#d4af5f','#e0562e','#38a3a5','#9662a8','#8a9a3a'][i]}${LIGHT?'55':'cc'},${['#6f83d6','#d4af5f','#e0562e','#38a3a5','#9662a8','#8a9a3a'][i]}33);border:2px solid ${['#6f83d6','#d4af5f','#e0562e','#38a3a5','#9662a8','#8a9a3a'][i]}">${p}</span>`).join('')}</div>`;
    } else if(key==='lang'){
      const f1=find(lang,'01-home',ipad), f2=find(lang==='en'?'he':'en','01-home',ipad); if(!f1||!f2) continue;
      const pw=ipad?800:560;
      const ph=(f,s)=>`<div style="position:absolute;${s};width:${pw}px;border-radius:${ipad?56:84}px;overflow:hidden;border:14px solid ${TH.bezel};box-shadow:0 0 0 3px ${TH.ring},${TH.shadow}"><img src="data:image/png;base64,${b64(f)}" style="display:block;width:100%"/></div>`;
      body=headBlock+ph(f1,`left:${ipad?230:90}px;top:${ipad?900:1000}px;transform:rotate(-5deg)`)+ph(f2,`right:${ipad?230:90}px;top:${ipad?1080:1180}px;transform:rotate(5deg)`)
        +`<div style="position:absolute;left:60px;right:60px;bottom:${ipad?120:130}px;display:flex;gap:22px;justify-content:center;flex-wrap:wrap">${['עברית','English','Français','Русский','ქართული'].map(x=>`<span style="padding:${18*k}px ${34*k}px;border-radius:60px;background:${TH.card};color:${TH.cardInk};font-size:${44*k}px;font-weight:700;border:2px solid ${col};box-shadow:0 14px 40px rgba(0,0,0,.35)">${x}</span>`).join('')}</div>`;
    } else if(key==='qr'){
      body=headBlock+`<img src="data:image/png;base64,${b64(src)}" style="position:absolute;left:50%;top:${ipad?800:900}px;width:${ipad?1000:900}px;transform:translateX(-50%) rotate(-3deg);border-radius:52px;box-shadow:${TH.shadow},0 0 0 3px ${TH.ring}"/>`;
    } else {
      body=headBlock+(key==='wid'?`<img src="data:image/png;base64,${b64(src)}" style="position:absolute;left:50%;transform:translateX(-50%);top:${devTop}px;width:${devW}px;border-radius:90px;box-shadow:${TH.shadow},0 0 0 3px ${TH.ring}"/>`:device(src));
      if(false&&T.b) body+=`<div style="position:absolute;left:${ipad?160:90}px;right:${ipad?160:90}px;top:${ipad?620:700}px;display:flex;flex-direction:column;gap:${18*k}px">${T.b.map(x=>`<div style="display:flex;align-items:center;gap:22px;font-size:${46*k}px;color:${TH.ink};font-weight:600"><span style="flex:none;width:${60*k}px;height:${60*k}px;border-radius:50%;background:${col};display:grid;place-items:center;color:#fff;font-size:${38*k}px">✓</span><span>${x}</span></div>`).join('')}</div>`;
      for(const [ic,tx,side,top] of (process.env.CALLOUTS?(T.co||[]):[])){ const tp=ipad?Math.round(top*0.95)-40:top-(T.b?0:120); body+=`<div style="position:absolute;${side==='l'?'left':'right'}:${ipad?90:30}px;top:${tp}px;display:flex;align-items:center;gap:20px;padding:${24*k}px ${34*k}px;border-radius:44px;background:${TH.card};color:${TH.cardInk};font-size:${42*k}px;font-weight:700;border:3px solid ${col};box-shadow:0 24px 60px rgba(0,0,0,.4);max-width:${ipad?800:640}px"><span style="font-size:${56*k}px">${ic}</span><span>${tx}</span></div>`; }
      if(false && zoom && src){ const f=b64(src), sz=pngSize(src); const cw=ipad?1000:780, ch=ipad?520:420, iw=Math.round((devW-36)*1.5);
        body+=`<div style="position:absolute;${rtl?'right':'left'}:${ipad?100:50}px;top:${ipad?2080:2230}px;width:${cw}px;height:${ch}px;border-radius:48px;overflow:hidden;border:4px solid ${col};box-shadow:0 30px 80px rgba(0,0,0,.55);background:${TH.card}"><img src="data:image/png;base64,${f}" style="position:absolute;width:${iw}px;left:${-(iw-cw)/2}px;top:${-zoom.y0*iw*(sz.h/sz.w)}px"/></div>`; }
    }
    await page.setContent(`<html dir="${rtl?'rtl':'ltr'}" style="overflow:hidden"><body style="margin:0;overflow:hidden"><div style="position:absolute;left:0;top:0;width:${W}px;height:${H}px;overflow:hidden;background:${TH.bg};font-family:'Noto Sans Hebrew','Noto Sans','Noto Sans Georgian',sans-serif">${glow}${orn}${body}</div></body></html>`);
    await page.waitForTimeout(150); n++;
    await page.screenshot({path:`${dir}/${String(n).padStart(2,'0')}-${key}.png`});
  }
  await page.close();
 }}
await b.close(); console.log('done');
