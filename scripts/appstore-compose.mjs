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
await b.close(); console.log('done');
