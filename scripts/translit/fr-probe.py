# Reverse-engineered probe of the existing French transliteration convention (A). Not the production engine.
# Reproduces 98.8% of 5.47M aligned tokens in data/. Evidence tool for spec-fr.json; see FR-NOTES.md.
# Usage: python3 -c "import fr_probe; print(fr_probe.tl('וְאָסוּר'))"
import re,collections,pickle,sys
SP='/tmp/claude-0/-home-user/3151a7b9-ad24-54e8-aa44-c519d5e1d6d7/scratchpad/'
V={'ְ':'shva','ֱ':'hsegol','ֲ':'hpatach','ֳ':'hqamatz','ִ':'chirik','ֵ':'tsere','ֶ':'segol','ַ':'patach','ָ':'qamatz','ֹ':'cholam','ֺ':'cholam','ֻ':'kubutz','ׇ':'qamatzkatan'}
LET='אבגדהוזחטיכךלמםנןסעפףצץקרשת'
LONG={'qamatz','tsere','cholam','ou','chirikmale','cholammale'}
def parse(w):
    out=[];cur=None
    for ch in w:
        if ch in LET:
            cur={'l':ch,'d':False,'s':None,'v':[]};out.append(cur)
        elif ch=='ּ' and cur: cur['d']=True
        elif ch=='ׁ' and cur: cur['s']='sh'
        elif ch=='ׂ' and cur: cur['s']='sin'
        elif ch in V and cur: cur['v'].append(V[ch])
        elif ch=='־' or ch=='-':
            out.append({'l':'-','d':False,'s':None,'v':[]}); cur=None
    return out
VOW={'patach':'a','hpatach':'a','qamatz':'a','hqamatz':'o','qamatzkatan':'o','segol':'é','hsegol':'é','tsere':'é','chirik':'i','cholam':'o','kubutz':'ou'}
CONS={'א':'','ע':'','ב':'v','ג':'g','ד':'d','ה':'h','ו':'v','ז':'z','ח':'kh','ט':'t','י':'y','כ':'kh','ך':'kh','ל':'l','מ':'m','ם':'m','נ':'n','ן':'n','ס':'s','פ':'f','ף':'f','צ':'ts','ץ':'ts','ק':'k','ר':'r','ש':'ch','ת':'t'}
def tl(w,opt={}):
    cl=parse(w)
    # split by maqaf into words
    words=[[]]
    for c in cl:
        if c['l']=='-': words.append([])
        else: words[-1].append(c)
    return '-'.join(tlw(x,opt) for x in words)
def tlw(cl,opt):
    n=len(cl)
    if n>=2 and cl[-1]['l']=='ל' and not cl[-1]['v'] and cl[-2]['l']=='כ' and cl[-2]['v']==['qamatz']: cl[-2]['v']=['qamatzkatan']
    for q in range(n-1):
        if cl[q]['v']==['qamatz'] and cl[q+1]['v']==['hqamatz']: cl[q]['v']=['qamatzkatan']
    # role assignment
    items=[]  # (cons string, vowel string, c, kind)
    i=0
    vowel_prev=None  # last vowel kind emitted (for shva / geminate decisions)
    toks=[]
    while i<n:
        c=cl[i];L=c['l'];v=c['v']
        nxt=cl[i+1] if i+1<n else None
        prv=cl[i-1] if i>0 else None
        if L=='ו' and c['d'] and not v:
            toks.append(('V','ou','shuruk',c)); i+=1; continue
        if L=='ו' and v==['cholam'] and not (prv is not None and prv['v'] and not prv['d'] or (prv is not None and prv['v'])):
            toks.append(('V','o','cholam',c)); i+=1; continue
        if L=='ו' and not v and not c['d'] and prv is not None and prv['v'] and prv['v'][-1]=='cholam' and False:
            i+=1; continue
        if L=='י' and not v and prv is not None and prv['v'] and prv['v'][-1]=='qamatz' and nxt is not None and nxt['l']=='ו' and not nxt['v'] and not nxt['d'] and i+2==n:
            toks.append(('S','','mater',c)); i+=1; continue
        if L=='י' and not v and not c['d'] and prv is not None and prv['v'] and prv['v'][-1] in ('chirik','tsere','segol'):
            toks.append(('S','','mater',c)); i+=1; continue
        if L=='ה' and not v and i==n-1 and (not opt.get('keephe') or (prv is not None and prv['v'] and prv['v'][-1] in ('qamatz',) and not c['d'])) and (not c['d'] or (prv is not None and prv['v'] and prv['v'][-1] in ('patach','tsere'))):
            toks.append(('S','','mater',c)); i+=1; continue
        if L in 'אע' and not v:
            toks.append(('S','','silent',c)); i+=1; continue
        toks.append(('C',CONS[L],c,i)); i+=1
    # assemble
    out=[]
    last_vowel_kind=None  # kind of vowel of previous consonant: 'long','short','none'
    for k,t in enumerate(toks):
        tr=opt.get('trace')
        if t[0]=='V':
            if tr is not None: tr.append(('vav','V:'+t[2],'',t[1],''))
            out.append(t[1]); last_vowel_kind='long'; continue
        if t[0]=='S':
            if tr is not None: tr.append((t[3]['l']+('+dagesh' if t[3]['d'] else ''),'S:'+t[2]+'/'+(t[3]['v'][0] if t[3]['v'] else ''),'','',''))
            continue
        _,s,c,idx=t
        L=c['l']; v=c['v']
        if L=='ב': s='b' if c['d'] else 'v'
        elif L in 'כך': s='k' if c['d'] else 'kh'
        elif L in 'פף': s='p' if c['d'] else 'f'
        elif L=='ש' and c['s']=='sin': s='s'
        elif L=='ג' : s='g'
        elif L=='ק' and opt.get('qof'): s=opt['qof']
        if opt.get('kafk') and L in 'כך' and not c['d']: s='k'
        if opt.get('bk') and L=='ב': s='b'
        if opt.get('pp') and L in 'פף': s='p'
        if opt.get('chet') and L=='ח': s=opt['chet']
        vv=[x for x in v if x!='shva']
        dbl=False
        if c['d'] and L not in 'אהחער':
            if L in 'בגדכךפףת':
                dbl = (last_vowel_kind in ('long','short')) and idx!=len(cl)-1
            else:
                dbl = k>0
        vs=''
        if vv:
            vs=VOW[vv[0]]
            if opt.get('ku') and vv[0]=='kubutz': vs='u'
        elif 'shva' in v:
            # na or nach
            first = (k==0)
            na=False
            if first: na=True
            elif k>=1 and toks[k-1][0]=='V' and toks[k-1][2]=='shuruk': na=True
            elif last_vowel_kind=='long' and L!='י' and opt.get('longna',False) and not (opt.get('longna')=='cholam' and False): na=True
            elif last_vowel_kind=='shvanach': na=True
            elif dbl: na=True
            elif idx>0 and cl[idx-1]['l']=='ה' and cl[idx-1]['v']==['patach'] and all(cl[q]['l'] in 'ובלכמשד' for q in range(idx-1)): na=True
            # two consecutive shvas or word-final: nach
            if 'shvamap' in opt and idx in opt['shvamap']: na=opt['shvamap'][idx]
            if idx==len(cl)-1: na=False
            vs='é' if na else ''
        # gemination
        dbl=False
        if c['d'] and L not in 'אהחער':
            if L in 'בגדכךפףת':
                dbl = (last_vowel_kind in ('long','short')) and idx!=len(cl)-1
            else:
                dbl = k>0
        # g softness
        if L=='ג' and vs in ('é','i') and not opt.get('nogu'): s='gu'
        # final furtive patach
        if idx==len(cl)-1 and L in 'חעה' and v==['patach'] and k>0:
            out.append('a'+s); last_vowel_kind='short'; continue
        s1=s
        if L in 'סש' and s=='s':
            j=k+1
            while j<len(toks) and toks[j][0]=='S' and toks[j][2]=='silent': j+=1
            nv = vs!='' or (j<len(toks) and (toks[j][0]=='V' or (toks[j][0]=='C' and toks[j][2]['v'] and toks[j][2]['v']!=['shva'] and (j>k+1 or toks[j][2]['l'] in 'אע'))))
            if out and out[-1] and out[-1][-1] in 'aéioueu' and nv and not dbl and not opt.get('noss'): s1='ss'
        if L=='ג' and vs in ('é','i') and not opt.get('nogu'):
            s=('g' if dbl else 'gu') if False else 'gu'
            s1=('g'+'gu') if dbl else 'gu'
        elif L=='ג' or (L=='ג'): s1='gg' if dbl else 'g'
        elif dbl: s1=s+s
        if vs=='i' and L in 'אע' and out and out[-1] and out[-1][-1] in 'ao': vs='ï'
        if tr is not None:
            fl=[]
            if dbl: fl.append('geminate')
            if s1=='ss': fl.append('ss')
            if L=='ג' and vs in ('é','i'): fl.append('gu')
            if vs=='ï': fl.append('ï')
            vk=(vv[0] if vv else ('shva-na' if (v==['shva'] and vs) else 'shva-nach' if v==['shva'] else 'none'))
            tr.append((L+('+dagesh' if c['d'] else '')+(('/'+c['s']) if c['s'] else ''),vk,s1,vs,','.join(fl)))
        out.append(s1+vs)
        if vs=='' and 'shva' in v: last_vowel_kind='shvanach'
        elif 'shva' in v: last_vowel_kind='shvana'
        elif vv: last_vowel_kind='long' if vv[0] in ('qamatz','tsere','cholam') else 'short'
        else: last_vowel_kind='none'
    return ''.join(out)
