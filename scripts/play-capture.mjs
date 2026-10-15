/* Google Play screenshots (1080x1920, 9:16 - Play allows up to 2:1, the iPhone 6.9" shots are too tall) from the web build
   on http://localhost:8899 (npm run serve:local). usage: node scripts/play-capture.mjs [he,en] [dark|light]
   Output: docs/play/screenshots/<lang>/NN-name.png. Android has no native Liquid Glass/widgets, so these show the real web UI. */
import {chromium} from 'playwright';
import fs from 'fs';
const langs=(process.argv[2]||'he,en').split(',');
const THEME=process.argv[3]==='light'?'light':'dark';
const b=await chromium.launch({executablePath:process.env.CHROME||'/opt/pw-browsers/chromium'});
for(const lang of langs){
  const out=`docs/play/screenshots/${lang}`; fs.mkdirSync(out,{recursive:true});
  const ctx=await b.newContext({viewport:{width:360,height:640},deviceScaleFactor:3,hasTouch:true,isMobile:true});
  const p=await ctx.newPage();
  await p.addInitScript(([l,TH])=>{
    localStorage.setItem('betel_settings',JSON.stringify({lang:l,theme:TH}));
    localStorage.setItem('betel_onboard_v1','1'); localStorage.setItem('betel_chok_pace_v1','1');
    localStorage.setItem('betel_loc',JSON.stringify({lat:31.7683,lon:35.2137,tz:'Asia/Jerusalem',name:'ירושלים',auto:false}));
  },[lang,THEME]);
  await p.goto('http://localhost:8899/index.html'); await p.waitForTimeout(2500);
  const shot=async(name,fn,wait)=>{ try{ await p.evaluate(fn); }catch(e){ console.log('ERR',name,e.message); }
    await p.waitForTimeout(wait||2000); await p.evaluate(()=>window.scrollTo(0,0));
    await p.screenshot({path:`${out}/${name}.png`}); console.log('ok',lang,name); };
  await shot('01-home',()=>window.go('home'),2500);
  await p.click('[data-home-item="chok"] .q-tile'); await p.waitForTimeout(9000); await p.evaluate(()=>window.scrollTo(0,0));
  await p.screenshot({path:`${out}/02-chok.png`}); console.log('ok',lang,'02-chok');
  await shot('03-calendar',()=>window.go('calendar'),2500);
  await shot('04-tehillim',()=>window.go('tehillim'),2500);
  await shot('05-prayers',()=>window.go('prayers'),2000);
  await shot('06-library',()=>window.go('library'),2000);
  await shot('07-settings',()=>window.go('settings'),2000);
  await ctx.close();
}
await b.close();
