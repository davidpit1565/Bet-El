import qrcode,base64,json,sys
URL='https://davidpit1565.github.io/Bet-El/get.html'
q=qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_Q,border=0,box_size=1); q.add_data(URL); q.make(fit=True)
M=q.get_matrix(); N=len(M)
logo=base64.b64encode(open('logo.png','rb').read()).decode()
def qr_svg(fg):
    u=100/N; parts=[]
    def finder(r,c):
        return (r<7 and c<7) or (r<7 and c>=N-7) or (r>=N-7 and c<7)
    for r in range(N):
        for c in range(N):
            if M[r][c] and not finder(r,c): parts.append(f'<rect x="{c*u:.3f}" y="{r*u:.3f}" width="{u+.02:.3f}" height="{u+.02:.3f}"/>')
    for (r,c) in [(0,0),(0,N-7),(N-7,0)]:
        x,y=c*u,r*u
        parts.append(f'<path fill-rule="evenodd" d="M{x+1.6*u},{y} h{3.8*u} a{1.6*u},{1.6*u} 0 0 1 {1.6*u},{1.6*u} v{3.8*u} a{1.6*u},{1.6*u} 0 0 1 -{1.6*u},{1.6*u} h-{3.8*u} a{1.6*u},{1.6*u} 0 0 1 -{1.6*u},-{1.6*u} v-{3.8*u} a{1.6*u},{1.6*u} 0 0 1 {1.6*u},-{1.6*u} z M{x+1.6*u},{y+u} a{.6*u},{.6*u} 0 0 0 -{.6*u},{.6*u} v{3.8*u} a{.6*u},{.6*u} 0 0 0 {.6*u},{.6*u} h{3.8*u} a{.6*u},{.6*u} 0 0 0 {.6*u},-{.6*u} v-{3.8*u} a{.6*u},{.6*u} 0 0 0 -{.6*u},-{.6*u} z"/>')
        parts.append(f'<rect x="{x+2*u}" y="{y+2*u}" width="{3*u}" height="{3*u}" rx="{.8*u}"/>')
    return f'<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges" fill="{fg}">{"".join(parts)}</svg>'
TH={'dark':dict(bg='radial-gradient(90% 55% at 50% 12%,#22346e 0%,#0e1832 55%,#060a15 100%)',ink='#f6f1e4',soft='#b9c3de',gold='#e6c874',gtext='linear-gradient(180deg,#fff3cf,#e6c874 60%,#c9a24b)',line='rgba(230,200,116,.55)',line2='rgba(230,200,116,.2)',card='#f8f3e6',qr='#0d1730',cardline='#c9a24b',chip='rgba(255,255,255,.07)',glow='rgba(230,200,116,.22)'),
    'light':dict(bg='radial-gradient(90% 55% at 50% 12%,#fffaf0 0%,#f3e8d0 55%,#e4d7b9 100%)',ink='#1f2d4d',soft='#4a5a80',gold='#8a6414',gtext='linear-gradient(180deg,#b88a22,#7a5812)',line='rgba(138,100,20,.6)',line2='rgba(138,100,20,.22)',card='#ffffff',qr='#0d1730',cardline='#b88a22',chip='rgba(138,100,20,.08)',glow='rgba(184,138,34,.2)')}
T={'he':dict(dir='rtl',lang='he',head='תמיד',sub='הלימוד היומי שלך, תמיד איתך',chips=['חוק לישראל','תהילים יומי','זוהר יומי','לוח עברי'],scan='סרקו והורידו',avail='זמין לאייפון ולאנדרואיד',langs='עברית · English · Français · Русский · ქართული',font='"Frank Ruhl Libre"',body='"Heebo"'),
   'en':dict(dir='ltr',lang='en',head='Tamid',sub='Your daily Torah study, always with you',chips=['Chok LeYisrael','Daily Tehillim','Daily Zohar','Hebrew calendar'],scan='Scan to download',avail='Available on the App Store and Google Play',langs='עברית · English · Français · Русский · ქართული',font='"Frank Ruhl Libre"',body='"Heebo"')}
def page(lang,th,fmt):
    t=T[lang]; c=TH[th]
    W,H=(826,1169) if fmt=='a4' else (540,960)
    k=1 if fmt=='a4' else .72
    css=f'''@import url("https://fonts.googleapis.com/css2?family=Frank+Ruhl+Libre:wght@700;900&family=Heebo:wght@400;500;700&display=swap");
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{width:{W}px;height:{H}px;background:#000}}
.p{{position:relative;width:{W}px;height:{H}px;overflow:hidden;background:{c['bg']};color:{c['ink']};font-family:{t['body']},sans-serif;direction:{t['dir']};text-align:center;display:flex;flex-direction:column;align-items:center}}
.fr1{{position:absolute;inset:{18*k}px;border:2px solid {c['line']}}}
.fr2{{position:absolute;inset:{28*k}px;border:1px solid {c['line2']}}}
.corner{{position:absolute;width:{46*k}px;height:{46*k}px;border:3px solid {c['gold']}}}
.c1{{top:{18*k}px;left:{18*k}px;border-right:0;border-bottom:0}}.c2{{top:{18*k}px;right:{18*k}px;border-left:0;border-bottom:0}}
.c3{{bottom:{18*k}px;left:{18*k}px;border-right:0;border-top:0}}.c4{{bottom:{18*k}px;right:{18*k}px;border-left:0;border-top:0}}
.glow{{position:absolute;top:{40*k}px;left:50%;width:{520*k}px;height:{520*k}px;transform:translateX(-50%);background:radial-gradient(circle,{c['glow']} 0%,transparent 65%)}}
.logo{{position:relative;margin-top:{{LOGOTOP}}px;width:{{LOGOW}}px;filter:drop-shadow(0 10px 26px rgba(0,0,0,.35))}}
h1{{position:relative;font-family:{t['font']},serif;font-weight:900;font-size:{{HEAD}}px;line-height:1;margin-top:{{HTOP}}px;background:{c['gtext']};-webkit-background-clip:text;background-clip:text;color:transparent;letter-spacing:{'0' if lang=='he' else '2px'}}}
.sub{{position:relative;font-size:{{SUB}}px;font-weight:500;margin-top:{14*k}px;color:{c['ink']};max-width:{W-140}px;line-height:1.35}}
.orn{{position:relative;display:flex;align-items:center;gap:12px;margin:{22*k}px 0 {20*k}px;width:{W*.56}px}}
.orn i{{flex:1;height:1px;background:{c['line']}}}.orn b{{color:{c['gold']};font-size:{18*k}px;font-weight:400}}
.chips{{position:relative;display:flex;gap:{8*k}px;flex-wrap:wrap;justify-content:center;max-width:{W-120}px}}
.chips span{{font-size:{{CHIP}}px;font-weight:500;padding:{6*k}px {14*k}px;border-radius:99px;background:{c['chip']};border:1px solid {c['line2']};color:{c['soft']}}}
.card{{position:relative;margin-top:{{CARDTOP}}px;width:{{CARDW}}px;padding:{{CARDPAD}}px;background:{c['card']};border-radius:{26*k}px;border:3px solid {c['cardline']};box-shadow:0 22px 60px rgba(0,0,0,.38),0 0 0 {8*k}px {c['line2']}}}
.card svg{{display:block;width:100%;height:auto}}
.scan{{position:relative;margin-top:{{SCANTOP}}px;font-family:{t['font']},serif;font-weight:900;font-size:{{SCAN}}px;background:{c['gtext']};-webkit-background-clip:text;background-clip:text;color:transparent}}
.avail{{position:relative;margin-top:{8*k}px;font-size:{{AVAIL}}px;color:{c['soft']};font-weight:500}}
.stores{{position:relative;display:flex;gap:{12*k}px;margin-top:{14*k}px}}
.stores span{{display:flex;align-items:center;gap:8px;padding:{9*k}px {20*k}px;border-radius:99px;border:2px solid {c['gold']};font-size:{{STORE}}px;font-weight:700;color:{c['ink']}}}
.stores svg{{width:{18*k}px;height:{18*k}px;fill:{c['gold']}}}
.langs{{position:absolute;bottom:{{LANGB}}px;font-size:{{LANG}}px;color:{c['soft']};letter-spacing:.5px;direction:ltr}}
'''
    P=dict(LOGOTOP=int(52*k),LOGOW=int(150*k),HEAD=int(92*k),HTOP=int(8*k),SUB=int(27*k),CHIP=int(15*k),CARDTOP=int(26*k),CARDW=int(380*k),CARDPAD=int(380*k*0.102),SCANTOP=int(28*k),SCAN=int(42*k),AVAIL=int(17*k),STORE=int(17*k),LANGB=int(52*k),LANG=int(15*k))
    for a,b in P.items(): css=css.replace('{'+a+'}',str(b))
    apple='<svg viewBox="0 0 24 24"><path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.700 2.400 2.900 2.300 1.200 0 1.600-.7 3-.7s1.800.7 3 .7c1.300 0 2.100-1.100 2.800-2.300.9-1.300 1.300-2.500 1.300-2.600-.1 0-2.500-1-2.500-3.800zM14.200 5.900c.6-.8 1.100-1.800.9-2.900-.9 0-2 .6-2.700 1.400-.6.700-1.100 1.800-.9 2.800 1 .1 2-.5 2.700-1.300z"/></svg>'
    play='<svg viewBox="0 0 24 24"><path d="M4 2.5v19c0 .4.4.6.7.4l16-9.500c.3-.2.3-.6 0-.8L4.700 2.100c-.3-.2-.7 0-.7.4z"/></svg>'
    chips=''.join(f'<span>{x}</span>' for x in t['chips'])
    return f'''<!doctype html><html lang="{t['lang']}" dir="{t['dir']}"><head><meta charset="utf-8"><style>{css}</style></head><body><div class="p">
<div class="fr1"></div><div class="fr2"></div><div class="corner c1"></div><div class="corner c2"></div><div class="corner c3"></div><div class="corner c4"></div><div class="glow"></div>
<img class="logo" src="data:image/png;base64,{logo}">
<h1>{t['head']}</h1><div class="sub">{t['sub']}</div>
<div class="orn"><i></i><b>✦</b><i></i></div><div class="chips">{chips}</div>
<div class="card">{qr_svg(c['qr'])}</div>
<div class="scan">{t['scan']}</div><div class="avail">{t['avail']}</div>
<div class="stores"><span>{apple}App Store</span><span>{play}Google Play</span></div>
<div class="langs">{t['langs']}</div></div></body></html>'''
for lang in T:
    for th in TH:
        open(f'poster-{lang}-{th}-a4.html','w',encoding='utf8').write(page(lang,th,'a4'))
open('poster-he-dark-story.html','w',encoding='utf8').write(page('he','dark','story'))
open('poster-he-light-story.html','w',encoding='utf8').write(page('he','light','story'))
print('ok',N)
