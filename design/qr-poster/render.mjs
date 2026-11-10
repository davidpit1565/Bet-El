import {chromium} from 'playwright';
import fs from 'fs';
const b=await chromium.launch({executablePath:process.env.CHROME});
for(const f of fs.readdirSync('.').filter(x=>x.endsWith('.html'))){
  const story=f.includes('story'); const vp=story?{width:540,height:960}:{width:826,height:1169};
  const p=await b.newPage({viewport:vp,deviceScaleFactor:story?2:3});
  await p.goto('file://'+process.cwd()+'/'+f); await p.evaluate(()=>document.fonts.ready); await p.waitForTimeout(1200);
  await p.screenshot({path:f.replace('.html','.png')}); console.log('ok',f); await p.close();
}
await b.close();
