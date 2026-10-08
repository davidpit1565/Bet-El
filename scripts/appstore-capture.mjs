/* Captures the raw App Store screenshots from the web build (served on http://localhost:8899 via `npm run serve:local`).
   usage: node scripts/appstore-capture.mjs [he,en,fr,ru,ka] [phone|ipad]
   Output: docs/appstore/raw-web/<lang>-<NN>-<name>.png (phone) or raw-web-ipad/ (ipad).
   The native-only screens (real Liquid Glass home, widgets, lock screen) cannot be rendered here: take those on
   the iPhone and drop them into docs/appstore/raw-device/<lang>-<NN>-<name>.png - they override the web ones. */
import {chromium} from 'playwright';
import fs from 'fs';
const langs=(process.argv[2]||'he,en,fr,ru,ka').split(',');
const ipad=process.argv[3]==='ipad';
const THEME=process.argv[4]==='light'?'light':'dark';   // 3rd arg: light|dark
const out=`docs/appstore/${ipad?'raw-web-ipad':'raw-web'}${THEME==='light'?'-light':''}`; fs.mkdirSync(out,{recursive:true});
const vp=ipad?{width:1032,height:1376}:{width:430,height:932}, dsf=ipad?2:3;
const b=await chromium.launch({executablePath:process.env.CHROME||'/opt/pw-browsers/chromium'});
for(const lang of langs){
  const ctx=await b.newContext({viewport:vp,deviceScaleFactor:dsf,hasTouch:true,isMobile:!ipad});
  const p=await ctx.newPage();
  await p.addInitScript(([l,TH])=>{
    localStorage.setItem('betel_settings',JSON.stringify({lang:l,theme:TH}));
    localStorage.setItem('betel_onboard_v1','1'); localStorage.setItem('betel_chok_pace_v1','1');
    localStorage.setItem('betel_loc',JSON.stringify({lat:31.7683,lon:35.2137,tz:'Asia/Jerusalem',name:'ירושלים',auto:false}));
  },[lang,THEME]);
  await p.goto('http://localhost:8899/index.html'); await p.waitForTimeout(2500);
  const shot=async(name,fn,wait)=>{ try{ await p.evaluate(fn); }catch(e){ console.log('ERR',name,e.message); }
    await p.waitForTimeout(wait||2000); await p.evaluate(()=>window.scrollTo(0,0));
    await p.screenshot({path:`${out}/${lang}-${name}.png`}); console.log('ok',lang,name); };
  await shot('01-home',()=>window.go('home'),2500);
  await p.click('[data-home-item="chok"] .q-tile'); await p.waitForTimeout(9000); await p.evaluate(()=>window.scrollTo(0,0));
  await p.screenshot({path:`${out}/${lang}-02-chok.png`}); console.log('ok',lang,'02-chok');
  await shot('03-calendar',()=>window.go('calendar'),2500);
  await shot('04-tehillim',()=>window.go('tehillim'),2500);
  await shot('05-prayers',()=>window.go('prayers'),2000);
  await shot('06-meein',()=>window.openPrayer('birkatMeeinShalosh','brachot'),2000);
  await shot('07-settings',()=>window.go('settings'),2000);
  await shot('08-library',()=>window.go('library'),2000);
  // the shareable QR card (image only, used by the bonus slide)
  try{ await p.evaluate(()=>window.shareQR()); await p.waitForSelector('.overlay img',{timeout:20000});
    const src=await p.evaluate(()=>document.querySelector('.overlay img').src);
    fs.writeFileSync(`${out}/${lang}-09-qr.png`,Buffer.from(src.split(',')[1],'base64')); console.log('ok',lang,'09-qr'); }catch(e){ console.log('ERR qr',e.message); }
  await ctx.close();
}
await b.close();
