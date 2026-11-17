/* Shared behaviour for the app pages: share button, scroll-to-top with the app-icon spin, English-return links for the Ben Ish Chai page. */
(function(){
 var d=document,b=d.body,lang=(d.documentElement.lang||'he').slice(0,2),he=lang==='he';
 var T={copied:he?'הקישור הועתק':'Link copied',fail:he?'לא הצלחנו להעתיק. אפשר להעתיק מסרגל הכתובת':'Could not copy. Copy it from the address bar'};
 var toast=null,tt=0;
 function say(m){if(!toast){toast=d.createElement('div');toast.className='toast';toast.setAttribute('role','status');toast.setAttribute('aria-live','polite');b.appendChild(toast);}
  toast.textContent=m;void toast.offsetWidth;toast.classList.add('on');clearTimeout(tt);tt=setTimeout(function(){toast.classList.remove('on')},2200);}
 function legacyCopy(u){var t=d.createElement('textarea');t.value=u;t.setAttribute('readonly','');t.style.cssText='position:fixed;opacity:0;top:0';b.appendChild(t);t.select();var ok=false;try{ok=d.execCommand('copy')}catch(e){}b.removeChild(t);return ok;}
 function share(){
  var url=location.origin&&location.origin!=='null'?location.origin+location.pathname:location.href.split(/[?#]/)[0];
  var title=(d.querySelector('meta[property="og:title"]')||{}).content||d.title;
  if(navigator.share){navigator.share({title:title,url:url}).catch(function(e){if(e&&e.name==='AbortError')return;copy(url)});return;}
  copy(url);
 }
 function copy(u){
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(u).then(function(){say(T.copied)},function(){say(legacyCopy(u)?T.copied:T.fail)});}
  else say(legacyCopy(u)?T.copied:T.fail);
 }
 d.querySelectorAll('[data-share]').forEach(function(el){el.addEventListener('click',share)});
 /* Ben Ish Chai is Hebrew only; when reached from an English page its back links return to the English pages. */
 if(b.hasAttribute('data-bic')){try{
  var q=/[?&]from=en/.test(location.search),r=/\/en\//.test(d.referrer);if(q)sessionStorage.setItem('lp_en','1');
  if(q||r||sessionStorage.getItem('lp_en')==='1'){d.querySelectorAll('a[data-en]').forEach(function(a){a.href=a.getAttribute('data-en')})}
 }catch(e){}}
 /* scroll to top with the app icon spinning over a tinted backdrop (same logic as the Tamid page) */
 var w=d.getElementById('warp'),up=d.getElementById('toTop');
 if(w&&up&&!b.hasAttribute('data-tamid')){
  var img=d.getElementById('warpImg'),jumping=0,reduce=window.matchMedia&&matchMedia('(prefers-reduced-motion:reduce)').matches;
  var tick=function(){up.classList.toggle('on',(window.scrollY||d.documentElement.scrollTop)>700)};
  window.addEventListener('scroll',tick,{passive:true});tick();
  up.addEventListener('click',function(){
   if(jumping)return;
   if(reduce){window.scrollTo({top:0,behavior:'instant'});return;}
   jumping=1;if(!img.getAttribute('src'))img.src=b.getAttribute('data-icon');
   w.className='warp s-spin act';void w.offsetWidth;w.classList.add('on');
   setTimeout(function(){window.scrollTo({top:0,behavior:'instant'});tick();},560);
   setTimeout(function(){w.classList.remove('on')},760);
   setTimeout(function(){w.className='warp';jumping=0},1500);
  });
 }
 /* ambient background: each app has its own gentle scene (sw: drifting light + rays, bic: twinkling sparks). Half resolution, ~30fps, paused when hidden. */
 (function(){
  var theme=b.classList.contains('t-sw')?'sw':b.classList.contains('t-bic')?'bic':'';if(!theme)return;
  var cv=d.createElement('canvas');cv.className='bgfx';cv.setAttribute('aria-hidden','true');b.insertBefore(cv,b.firstChild);
  var cx=cv.getContext('2d');if(!cx)return;
  var W=0,H=0,t=0,raf=0,last=0,rm=window.matchMedia&&matchMedia('(prefers-reduced-motion:reduce)').matches;
  function size(){W=cv.width=Math.max(1,Math.round(innerWidth/2));H=cv.height=Math.max(1,Math.round(innerHeight/2));}
  size();window.addEventListener('resize',function(){size();draw()});
  var R=function(a,b2){return a+Math.random()*(b2-a)};
  var orbs=[],sp=[];
  if(theme==='sw'){for(var i=0;i<6;i++)orbs.push({x:R(0,1),y:R(0,1),r:R(.22,.4),sx:R(.4,1)*(i%2?1:-1),sy:R(.3,.8),ph:R(0,6.28),c:[[89,230,255],[40,116,255],[255,255,255]][i%3]});}
  else{for(var j=0;j<60;j++)sp.push({x:R(0,1),y:R(0,1),s:R(.6,2),v:R(.004,.012),ph:R(0,6.28),w:R(.6,1.6),c:j%3?[245,238,218]:[79,179,165]});
   for(var k=0;k<3;k++)orbs.push({x:R(.1,.9),y:R(.2,.9),r:R(.3,.5),sx:R(.3,.7)*(k%2?1:-1),sy:R(.2,.5),ph:R(0,6.28)});}
  function blob(x,y,r,c,a){var g=cx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba('+c+','+a+')');g.addColorStop(1,'rgba('+c+',0)');cx.fillStyle=g;cx.fillRect(x-r,y-r,2*r,2*r);}
  function draw(){
   cx.clearRect(0,0,W,H);
   if(theme==='sw'){
    cx.globalCompositeOperation='source-over';
    orbs.forEach(function(o){var x=(o.x+Math.sin(t*o.sx+o.ph)*.12)*W,y=(o.y+Math.cos(t*o.sy+o.ph)*.1)*H;blob(x,y,o.r*Math.max(W,H),o.c.join(','),o.c[0]===255?.22:.14)});
    var px=W*.88,py=-H*.06;
    for(var n=0;n<5;n++){var ang=1.9+n*.2+Math.sin(t*.5+n)*.06,len=Math.max(W,H)*1.5,half=.05+n%2*.02;
     var g=cx.createLinearGradient(px,py,px+Math.cos(ang)*len,py+Math.sin(ang)*len);g.addColorStop(0,'rgba(255,255,255,.28)');g.addColorStop(.7,'rgba(255,255,255,.05)');g.addColorStop(1,'rgba(255,255,255,0)');
     cx.fillStyle=g;cx.beginPath();cx.moveTo(px,py);cx.lineTo(px+Math.cos(ang-half)*len,py+Math.sin(ang-half)*len);cx.lineTo(px+Math.cos(ang+half)*len,py+Math.sin(ang+half)*len);cx.closePath();cx.fill();}
   }else{
    cx.globalCompositeOperation='lighter';
    orbs.forEach(function(o){blob((o.x+Math.sin(t*o.sx+o.ph)*.15)*W,(o.y+Math.cos(t*o.sy+o.ph)*.1)*H,o.r*Math.max(W,H),'79,179,165',.055)});
    sp.forEach(function(q){var y=((q.y-t*q.v*8)%1+1)%1,x=q.x+Math.sin(t*.3+q.ph)*.01,a=(.35+.65*Math.abs(Math.sin(t*q.w+q.ph)))*.55*Math.sin(Math.PI*y),r=q.s*(W>600?1.6:1.1),X=x*W,Y=y*H;
     cx.fillStyle='rgba('+q.c.join(',')+','+a.toFixed(3)+')';
     cx.beginPath();cx.moveTo(X,Y-r*3);cx.quadraticCurveTo(X,Y,X+r*3,Y);cx.quadraticCurveTo(X,Y,X,Y+r*3);cx.quadraticCurveTo(X,Y,X-r*3,Y);cx.quadraticCurveTo(X,Y,X,Y-r*3);cx.fill();});
   }
  }
  function loop(ts){raf=requestAnimationFrame(loop);if(ts-last<33)return;last=ts;t+=.012;draw();}
  draw();
  if(!rm){raf=requestAnimationFrame(loop);d.addEventListener('visibilitychange',function(){cancelAnimationFrame(raf);if(!d.hidden)raf=requestAnimationFrame(loop)});}
 })();
})();
