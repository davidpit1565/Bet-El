/* Builds the final captioned App Store screenshots from raw screenshots.
   usage: node scripts/appstore-compose.mjs [he,en,fr,ru,ka]
   Raw sources (first match wins): docs/appstore/raw-device/<lang>-NN-name.png (taken on the iPhone), then raw-web/.
   Output: docs/appstore/screenshots/<lang>/iphone-6.9/NN.png (1320x2868) and ipad-13/NN.png (2064x2752, he/en only
   unless raw-web-ipad has the language). Upload each folder to App Store Connect in numeric order. */
import {chromium} from 'playwright';
import fs from 'fs';
import path from 'path';
const langs=(process.argv[2]||'he,en,fr,ru,ka').split(',');
const C={
 he:['כל הלימוד היומי במקום אחד','חוק לישראל – כל יום, בקצב אחד','לוח עברי וזמני היום','תהילים יומי עם מעקב','סידור, ברכות ותפילות','ברכות בנוסח עדות המזרח','מותאם אליך: שפות, תזכורות ומיקום','ספרייה מלאה של ספרי קודש'],
 en:['Your whole daily study in one place','Chok LeYisrael – every day, one steady pace','Hebrew calendar and daily times','Daily Tehillim with progress tracking','Siddur, blessings and prayers','Blessings in Edot HaMizrach nusach','Made for you: languages, reminders, location','A full library of holy books'],
 fr:['Tout votre étude quotidienne au même endroit','Ḥok LeYisraël – chaque jour, un seul rythme','Calendrier hébraïque et horaires du jour','Tehilim quotidiens avec suivi','Sidour, bénédictions et prières','Bénédictions selon le rite séfarade oriental','Pensé pour vous : langues, rappels, lieu','Une bibliothèque complète de livres saints'],
 ru:['Всё ежедневное изучение в одном месте','Хок ле-Исраэль – каждый день в одном ритме','Еврейский календарь и времена дня','Ежедневные Теилим с отслеживанием','Сидур, благословения и молитвы','Благословения по нусах мизрах','Для вас: языки, напоминания, местоположение','Полная библиотека священных книг'],
 ka:['მთელი ყოველდღიური სწავლა ერთ აპში','ჰოკ ლეისრაელი – ყოველდღე ერთი რიტმით','ებრაული კალენდარი და დღის დროები','ყოველდღიური თეჰილიმი პროგრესის თვალყურით','სიდური, კურთხევები და ლოცვები','კურთხევები აღმოსავლური წესით','თქვენთვის: ენები, შეხსენებები, მდებარეობა','წმინდა წიგნების სრული ბიბლიოთეკა'],
};
const names=['01-home','02-chok','03-calendar','04-tehillim','05-prayers','06-meein','07-settings','08-library'];
const find=(lang,n,ipad)=>{
  const c=ipad?[`docs/appstore/raw-device-ipad/${lang}-${n}.png`,`docs/appstore/raw-web-ipad/${lang}-${n}.png`]
              :[`docs/appstore/raw-device/${lang}-${n}.png`,`docs/appstore/raw-web/${lang}-${n}.png`];
  return c.find(f=>fs.existsSync(f));
};
const b=await chromium.launch({executablePath:process.env.CHROME||'/opt/pw-browsers/chromium'});
for(const lang of langs){
  const rtl=lang==='he';
  for(const ipad of [false,true]){
    const W=ipad?2064:1320, H=ipad?2752:2868, imgW=ipad?1560:1100;
    const dir=`docs/appstore/screenshots/${lang}/${ipad?'ipad-13':'iphone-6.9'}`; fs.mkdirSync(dir,{recursive:true});
    const page=await b.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});
    for(let i=0;i<names.length;i++){
      const src=find(lang,names[i],ipad); if(!src) continue;
      const data=fs.readFileSync(src).toString('base64');
      const html=`<html dir="${rtl?'rtl':'ltr'}"><body style="margin:0;width:${W}px;height:${H}px;overflow:hidden;position:relative;
        background:radial-gradient(120% 70% at 50% 0%,#1b2a5c 0%,#0b1226 55%,#05080f 100%);font-family:'Noto Sans Hebrew','Noto Sans Georgian','Noto Sans',sans-serif">
        <div style="position:absolute;top:${ipad?60:70}px;height:${ipad?400:360}px;display:flex;align-items:center;justify-content:center;left:60px;right:60px;text-align:center;font-weight:800;font-size:${ipad?104:92}px;line-height:1.18;
          background:linear-gradient(180deg,#fff3cf,#e6c874 70%,#c9a24b);-webkit-background-clip:text;color:transparent">${C[lang][i]}</div>
        <div style="position:absolute;left:50%;transform:translateX(-50%);top:${ipad?470:450}px;width:${imgW}px;border-radius:${ipad?64:84}px;overflow:hidden;
          border:12px solid #0a0f1f;box-shadow:0 0 0 3px rgba(230,200,116,.55),0 50px 120px rgba(0,0,0,.75);">
          <img src="data:image/png;base64,${data}" style="display:block;width:100%"/></div></body></html>`;
      await page.setContent(html); await page.waitForTimeout(150);
      await page.screenshot({path:`${dir}/${String(i+1).padStart(2,'0')}.png`});
    }
    await page.close();
  }
}

/* ---------- bonus slides: designed pictures (no plain screen) ---------- */
const T6={he:['חוק לישראל','תהילים יומי','זוהר יומי','בן איש חי','מוסר','סידור וברכות'],en:['Chok LeYisrael','Daily Tehillim','Daily Zohar','Ben Ish Chai','Musar','Siddur & blessings'],
 fr:['Ḥok LeYisraël','Tehilim quotidiens','Zohar quotidien','Ben Ich ‘Haï','Moussar','Sidour et bénédictions'],ru:['Хок ле-Исраэль','Теилим на каждый день','Зоар на каждый день','Бен Иш Хай','Мусар','Сидур и благословения'],
 ka:['ჰოკ ლეისრაელი','ყოველდღიური თეჰილიმი','ყოველდღიური ზოჰარი','ბენ იშ ჰაი','მუსარი','სიდური და კურთხევები']};
const COL=['#6f83d6','#d4af5f','#e0562e','#38a3a5','#9662a8','#8a9a3a'];
const BT={he:{hero:'הלימוד היומי שלך, בכל מקום',feat:'הכל במקום אחד',lang:'חמש שפות בלחיצה אחת',qr:'שתפו את האפליקציה עם קוד QR'},
 en:{hero:'Your daily study, anywhere',feat:'Everything in one place',lang:'Five languages, one tap',qr:'Share the app with a QR code'},
 fr:{hero:'Votre étude quotidienne, partout',feat:'Tout au même endroit',lang:'Cinq langues, un seul geste',qr:'Partagez l’app avec un QR code'},
 ru:{hero:'Ваше ежедневное изучение – везде',feat:'Всё в одном месте',lang:'Пять языков одним касанием',qr:'Поделитесь приложением по QR-коду'},
 ka:{hero:'თქვენი ყოველდღიური სწავლა – ყველგან',feat:'ყველაფერი ერთ ადგილას',lang:'ხუთი ენა ერთი შეხებით',qr:'გააზიარეთ აპი QR კოდით'}};
const logo=fs.existsSync('assets/logo.png')?fs.readFileSync('assets/logo.png').toString('base64'):'';
const b64=f=>fs.readFileSync(f).toString('base64');
const bg='radial-gradient(120% 70% at 50% 0%,#1b2a5c 0%,#0b1226 55%,#05080f 100%)';
const gold='background:linear-gradient(180deg,#fff3cf,#e6c874 70%,#c9a24b);-webkit-background-clip:text;color:transparent';
const head=(t,ipad)=>`<div style="position:absolute;top:70px;height:${ipad?400:360}px;display:flex;align-items:center;justify-content:center;left:60px;right:60px;text-align:center;font-weight:800;font-size:${ipad?104:92}px;line-height:1.18;${gold}">${t}</div>`;
const phone=(f,w,extra)=>`<div style="position:absolute;width:${w}px;border-radius:84px;overflow:hidden;border:12px solid #0a0f1f;box-shadow:0 0 0 3px rgba(230,200,116,.55),0 50px 120px rgba(0,0,0,.75);${extra}"><img src="data:image/png;base64,${b64(f)}" style="display:block;width:100%"/></div>`;
for(const lang of langs){
  const rtl=lang==='he';
  for(const ipad of [false,true]){
    const W=ipad?2064:1320, H=ipad?2752:2868;
    const dir=`docs/appstore/screenshots/${lang}/${ipad?'ipad-13':'iphone-6.9'}`; fs.mkdirSync(dir,{recursive:true});
    const page=await b.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});
    const wrap=inner=>`<html dir="${rtl?'rtl':'ltr'}"><body style="margin:0;width:${W}px;height:${H}px;overflow:hidden;position:relative;background:${bg};font-family:'Noto Sans Hebrew','Noto Sans Georgian','Noto Sans',sans-serif">${inner}</body></html>`;
    const other=lang==='en'?'he':'en';
    const slides={};
    // A: hero (logo, name, tagline, feature pills)
    slides['bonus-A-hero']=wrap(`${logo?`<img src="data:image/png;base64,${logo}" style="position:absolute;left:50%;transform:translateX(-50%);top:${ipad?330:300}px;width:${ipad?640:620}px"/>`:''}
      <div style="position:absolute;left:0;right:0;top:${ipad?1050:960}px;text-align:center;font-weight:900;font-size:${ipad?210:200}px;${gold}">${lang==='he'?'תמיד':'Tamid'}</div>
      <div style="position:absolute;left:80px;right:80px;top:${ipad?1330:1250}px;text-align:center;font-weight:700;font-size:${ipad?78:70}px;color:#f6f1e4;line-height:1.25">${BT[lang].hero}</div>
      <div style="position:absolute;left:70px;right:70px;top:${ipad?1700:1560}px;display:flex;flex-wrap:wrap;gap:22px;justify-content:center">${T6[lang].map((t,i)=>`<span style="padding:20px 38px;border-radius:60px;font-size:${ipad?50:46}px;font-weight:700;color:#fff;background:linear-gradient(135deg,${COL[i]}cc,${COL[i]}55);border:2px solid ${COL[i]}">${t}</span>`).join('')}</div>`);
    // B: features grid (the app's own colours)
    slides['bonus-B-features']=wrap(`${head(BT[lang].feat,ipad)}
      <div style="position:absolute;left:${ipad?160:90}px;right:${ipad?160:90}px;top:${ipad?560:520}px;display:grid;grid-template-columns:1fr 1fr;gap:34px">${T6[lang].map((t,i)=>`<div style="height:${ipad?330:360}px;border-radius:56px;display:flex;align-items:flex-end;padding:44px;box-sizing:border-box;font-size:${ipad?64:62}px;font-weight:800;color:#fff;line-height:1.15;background:linear-gradient(150deg,${COL[i]}cc,${COL[i]}33 70%,#0b1226);border:3px solid ${COL[i]}99;border-top:12px solid ${COL[i]}">${t}</div>`).join('')}</div>`);
    // C: two languages side by side
    const f1=find(lang,'01-home',ipad), f2=find(other,'01-home',ipad);
    if(f1&&f2) slides['bonus-C-languages']=wrap(`${head(BT[lang].lang,ipad)}${phone(f1,ipad?760:520,`left:${ipad?220:90}px;top:${ipad?620:640}px;transform:rotate(-4deg)`)}${phone(f2,ipad?760:520,`right:${ipad?220:90}px;top:${ipad?760:800}px;transform:rotate(4deg)`)}`);
    // D: QR card
    const q=find(lang,'09-qr',ipad)||find(lang,'09-qr',false);
    if(q) slides['bonus-D-qr']=wrap(`${head(BT[lang].qr,ipad)}<img src="data:image/png;base64,${b64(q)}" style="position:absolute;left:50%;top:${ipad?520:520}px;width:${ipad?980:860}px;transform:translateX(-50%) rotate(-2deg);border-radius:48px;box-shadow:0 50px 120px rgba(0,0,0,.75),0 0 0 3px rgba(230,200,116,.55)"/>`);
    for(const [n,html] of Object.entries(slides)){ await page.setContent(html); await page.waitForTimeout(200); await page.screenshot({path:`${dir}/${n}.png`}); }
    await page.close();
  }
}
await b.close(); console.log('done');
