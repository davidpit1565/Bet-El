import { chromium } from 'playwright';
import fs from 'fs';
const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
const out=[];
const SCREENS={
  home:async p=>{},
  homeScroll:async p=>{ await p.evaluate(()=>{const s=document.body.scrollHeight>document.body.clientHeight+4?document.body:document.scrollingElement; s.scrollTop=700;}); },
  settings:async p=>{ await p.evaluate(()=>window.go('settings')); },
  setGeneral:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="general"]'); },
  setNotif:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="notifications"]'); },
  setStudy:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="study"]'); },
  setLoc:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="location"]'); },
  setPersonal:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="personal"]'); },
  setShare:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="share"]'); },
  setSupport:async p=>{ await p.evaluate(()=>window.go('settings')); await p.waitForTimeout(300); await p.click('[data-cat="support"]'); },
  calendar:async p=>{ await p.evaluate(()=>window.go('calendar')); },
  library:async p=>{ await p.evaluate(()=>window.go('library')); },
  tehillim:async p=>{ await p.evaluate(()=>window.go('tehillim')); },
  tracker:async p=>{ await p.evaluate(()=>window.go('tracker')); },
  chok:async p=>{ await p.click('#homeChokCard'); },
  chokNevi:async p=>{ await p.click('#homeChokCard'); await p.waitForTimeout(2500); await p.click('.ck-secchip:nth-of-type(2)'); },
  tehDaily:async p=>{ await p.click('#homeTehillimCard'); },
  edit:async p=>{ const it=await p.$('.home-item'); const bb=await it.boundingBox(); await p.mouse.move(bb.x+20,bb.y+20); await p.mouse.down(); await p.waitForTimeout(700); await p.mouse.up(); },
};
for(const theme of ['dark','light']){
 for(const native of [true,false]){
  for(const [name,fn] of Object.entries(SCREENS)){
    const p=await b.newPage({viewport:{width:390,height:844},hasTouch:true});
    await p.addInitScript((theme)=>{ localStorage.setItem('betel_onboard_v1','1'); localStorage.setItem('betel_chok_pace_v1','1'); localStorage.setItem('betel_settings',JSON.stringify({theme})); },theme);
    await p.goto('http://localhost:8899/index.html'); await p.waitForTimeout(1800);
    if(native) await p.evaluate(()=>document.documentElement.classList.add('has-native-tabbar'));
    try{ await fn(p); }catch(e){ continue; }
    await p.waitForTimeout(name.startsWith('chok')||name==='tehDaily'?2800:900);
    const items=await p.evaluate(()=>{
      const res=[]; const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
      const seen=new Set(); let n;
      while(n=w.nextNode()){
        const t=n.textContent.trim(); if(!t) continue; const el=n.parentElement; if(!el||seen.has(el)) continue;
        if(['SCRIPT','STYLE','NOSCRIPT'].includes(el.tagName)) continue;
        const cs=getComputedStyle(el); if(cs.visibility==='hidden'||cs.display==='none') continue;
        const r=el.getBoundingClientRect(); if(r.width<6||r.height<6||r.bottom<0||r.top>innerHeight||r.right<0||r.left>innerWidth) continue;
        seen.add(el);
        let op=1,e=el; while(e){ op*=parseFloat(getComputedStyle(e).opacity); e=e.parentElement; }
        res.push({t:t.slice(0,24),cls:(el.className&&el.className.baseVal===undefined?el.className:'').toString().slice(0,50),color:cs.color,op,x:r.left,y:r.top,w:r.width,h:r.height,fs:parseFloat(cs.fontSize),fw:cs.fontWeight});
      } return res; });
    await p.screenshot({path:`/tmp/au_${theme}_${native?'n':'w'}_${name}.png`});
    out.push({theme,native,name,items});
    await p.close();
  }
 }
}
fs.writeFileSync('/tmp/audit.json',JSON.stringify(out));
await b.close(); console.log('screens',out.length);
