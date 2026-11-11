import {chromium} from 'playwright';
const b=await chromium.launch({executablePath:process.env.CHROME});
const p=await b.newPage({viewport:{width:1800,height:860}});
await p.goto('file://'+process.cwd()+'/texts-en.html');await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(1500);
await p.screenshot({path:'texts-en.png',omitBackground:true});await b.close();
