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
})();
