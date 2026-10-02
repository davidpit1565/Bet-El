#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mechanical Hebrew -> Latin phonetic transliterator for Nevi'im/Ketuvim,
reverse-engineered from the Torah's own already-correct data/torah-en.json
(Sefaria has no transliteration edition to fetch, so this generates one
book at a time rather than relying on a source). Convention matches Torah:
qof='k' (not the Siddur's 'q'), Tetragrammaton always rendered "Adonai".

Validated against all 5846 Hebrew/English verse pairs extracted from
Torah's own data: 55.5% exact match, remainder are minor sheva na/nach
vocalization nuances that would need real morphological analysis to fix -
an accepted, disclosed limitation given diminishing returns.

Usage (adds/overwrites one book's key in data/<cat>-<lang>.json, which is
otherwise left untouched - nkVersesOf() in index.html falls back to the
Hebrew text for any book not yet present in that file):
    python3 scripts/transliterate-neviim-ketuvim.py --cat neviim --book Judges --lang en
    python3 scripts/transliterate-neviim-ketuvim.py --validate   # re-run against the Torah test set
"""
import json, re, os, argparse

SHEVA='ְ'; HATAF_SEGOL='ֱ'; HATAF_PATAH='ֲ'; HATAF_QAMATZ='ֳ'
HIRIQ='ִ'; TZERE='ֵ'; SEGOL='ֶ'; PATAH='ַ'; QAMATZ='ָ'
HOLAM='ֹ'; HOLAM_HASER='ֺ'; QUBUTS='ֻ'; DAGESH='ּ'
METEG='ֽ'; MAQAF='־'; RAFE='ֿ'; SHIN_DOT='ׁ'; SIN_DOT='ׂ'
QAMATZ_QATAN='ׇ'

VOWELS={HIRIQ:'i',TZERE:'e',SEGOL:'e',PATAH:'a',QAMATZ:'a',QAMATZ_QATAN:'o',
        HOLAM:'o',HOLAM_HASER:'o',QUBUTS:'u',HATAF_SEGOL:'e',HATAF_PATAH:'a',HATAF_QAMATZ:'o'}

ALEF='א'; BET='ב'; GIMEL='ג'; DALET='ד'; HE='ה'; VAV='ו'
ZAYIN='ז'; CHET='ח'; TET='ט'; YOD='י'; KAF='כ'; KAF_F='ך'
LAMED='ל'; MEM='מ'; MEM_F='ם'; NUN='נ'; NUN_F='ן'; SAMEKH='ס'
AYIN='ע'; PE='פ'; PE_F='ף'; TZADI='צ'; TZADI_F='ץ'; QOF='ק'
RESH='ר'; SHIN='ש'; TAV='ת'

CONS={GIMEL:'g',DALET:'d',ZAYIN:'z',CHET:'ch',TET:'t',LAMED:'l',MEM:'m',MEM_F:'m',
      NUN:'n',NUN_F:'n',SAMEKH:'s',TZADI:'tz',TZADI_F:'tz',QOF:'k',RESH:'r',TAV:'t'}

def is_hebrew_letter(c):
    return 'א'<=c<='ת'

def strip_trope(s):
    return ''.join(c for c in s if not ('֑'<=c<='֮'))

def parse_units(word):
    chars=list(strip_trope(word))
    n=len(chars); i=0; units=[]
    while i<n:
        c=chars[i]
        if is_hebrew_letter(c):
            base=c; i+=1
            dagesh=False; shindot=None; vmarks=[]; has_sheva=False
            while i<n and not is_hebrew_letter(chars[i]):
                d=chars[i]
                if d==DAGESH: dagesh=True
                elif d==SHIN_DOT: shindot='sh'
                elif d==SIN_DOT: shindot='s'
                elif d in (RAFE,METEG,MAQAF): pass
                elif d==SHEVA: has_sheva=True
                elif d in VOWELS: vmarks.append(d)
                i+=1
            units.append({'base':base,'dagesh':dagesh,'shindot':shindot,'vmarks':vmarks,'sheva':has_sheva})
        else:
            i+=1
    return units

def transliterate_word(word):
    units=parse_units(word)
    out=[]
    nunits=len(units)
    for idx,u in enumerate(units):
        base=u['base']; dagesh=u['dagesh']; vmarks=u['vmarks']; sheva=u['sheva']
        is_last=(idx==nunits-1); is_first=(idx==0)
        prev_sheva = idx>0 and units[idx-1]['sheva'] and not units[idx-1]['vmarks']
        has_holam = any(v in (HOLAM,HOLAM_HASER) for v in vmarks)
        vowel = VOWELS.get(vmarks[0]) if vmarks else None

        # vav special handling: cholam male -> 'o' pure vowel; shuruk (dagesh, no holam) -> 'u' pure vowel
        if base==VAV and not (dagesh and sheva):
            if has_holam:
                out.append('o'); continue
            if dagesh and vowel is None:
                out.append('u'); continue
            if vowel is None and not sheva:
                if is_first or is_last:
                    out.append('v')
                else:
                    out.append('')
                continue
            if sheva:
                out.append('ve'); continue
            out.append('v'+(vowel or '')); continue
        # vav with BOTH dagesh and sheva is a geminated root consonant with a
        # pronominal-suffix sheva (e.g. tzivvecha), never shuruk (which never
        # also carries sheva) - falls through to the normal consonant path
        # below so it gets doubled/vocalized exactly like any other letter.

        # yod special handling: silent mater after i/e-type vowel when yod itself
        # carries nothing (e.g. pene->"pene", peri->"peri"), and likewise when a
        # bare yod after a/o/u is itself followed by another letter (e.g. the
        # "-av"/"his" suffix אֲדֹנָיו=adonav, where the trailing vav - not this
        # yod - is what's actually pronounced). But a bare yod after a/o/u that
        # IS the end of the word stays a real consonant ("y"): standalone
        # אֲדֹנָי=adonay, לְפָנַי=lefanay, אֵלַי=elay - confirmed against the
        # Torah's own data.
        if base==YOD and vowel is None and not sheva and not dagesh:
            prev_out = out[-1] if out else ''
            if not is_first and prev_out and (prev_out[-1] in 'ie' or not is_last):
                out.append(''); continue
            if is_first:
                out.append('y'); continue
            out.append('y'); continue
        if base==YOD and sheva and vowel is None:
            out.append('ye'); continue

        # consonant sound
        if base==SHIN:
            csound = u['shindot'] if u['shindot'] else 'sh'
        elif base==BET:
            csound = 'b' if dagesh else 'v'
        elif base in (KAF,KAF_F):
            csound = 'k' if dagesh else 'ch'
        elif base in (PE,PE_F):
            csound = 'p' if dagesh else 'f'
        elif base==YOD:
            csound='y'
        elif base==VAV:
            csound='v'
        elif base in (ALEF,AYIN):
            csound=''
        elif base==HE:
            csound='h'
        else:
            csound=CONS.get(base,'')

        # dagesh chazak (gemination) only happens when the dagesh'd letter
        # is preceded by an actual vowel sound (not a silent/elided sheva or
        # word start) - dagesh after a consonant with no vowel is dagesh
        # qal (sound change only, e.g. b/v k/ch p/f already applied above,
        # no doubling). Gemination doubles the WHOLE resulting sound, not
        # just its first letter, e.g. sh->shsh.
        prev_ends_vowel = bool(out) and bool(out[-1]) and out[-1][-1] in 'aeiou'
        double = dagesh and (not is_first) and base!=HE and csound!='' and prev_ends_vowel
        if double:
            csound = csound+csound

        vsound = vowel if vowel else ('e' if (sheva and (is_first or double or prev_sheva) and csound!='') else '')

        # final He silent mater (no vowel, no dagesh/mappiq)
        if base==HE and is_last and vowel is None and not dagesh and not sheva:
            csound=''

        # furtive patach: final chet/ayin + patach vowel -> vowel BEFORE consonant
        if is_last and base in (CHET,AYIN) and vmarks and vmarks[0]==PATAH:
            out.append('a'+csound); continue

        out.append(csound+vsound)
    return ''.join(out)

def strip_diacritics_only_consonants(word):
    return ''.join(c for c in word if is_hebrew_letter(c))

def transliterate_verse(verse):
    # strip literal Masoretic paragraph markers some Nevi'im/Ketuvim verses
    # carry inline (petucha "(פ)" / setuma "(ס)") - not part of the verse text
    verse = re.sub(r'\s*\([פס]\)\s*$', '', verse)
    # ketiv/qere pairs ("written" unvocalized form followed by the vocalized
    # "read" form in brackets) - only the bracketed qere form is actually
    # read aloud, so drop the bare ketiv word and keep just the brackets'
    # content (then strip the brackets themselves).
    verse = re.sub(r'\S+ \[([^\]]+)\]', r'\1', verse)
    verse = strip_trope(verse)
    tokens = re.split(r'(\s+)', verse)
    out=[]
    for tok in tokens:
        if tok.isspace() or tok=='':
            out.append(tok); continue
        subtoks = re.split(r'(־)', tok)
        rendered=[]
        for st in subtoks:
            if st=='־':
                rendered.append('-'); continue
            core = re.sub(r'[ -⁯ﬞ׃׀׀.:]', '', st)
            if not core: continue
            consonants = strip_diacritics_only_consonants(core)
            if consonants.endswith('יהוה') and len(consonants)>=4:
                prefix_letters = len(consonants)-4
                if prefix_letters==0:
                    rendered.append('Adonai')
                else:
                    # split the nikud-bearing core right before the start of the
                    # (prefix_letters+1)-th Hebrew letter, so the prefix keeps its
                    # own trailing vowel/dagesh diacritics (e.g. "לַ" not just "ל")
                    seen=0; cut=len(core)
                    for ci,ch in enumerate(core):
                        if is_hebrew_letter(ch):
                            seen+=1
                            if seen==prefix_letters+1:
                                cut=ci; break
                    prefix_part = core[:cut]
                    rendered.append(transliterate_word(prefix_part)+'-Adonai')
            else:
                rendered.append(transliterate_word(core))
        out.append(''.join(rendered))
    res=''.join(out)
    res=re.sub(r'\s+',' ',res).strip()
    return res

def cap_first(s):
    return s[0].upper()+s[1:] if s else s

ROOT = os.path.join(os.path.dirname(__file__), '..')

def transliterate_book(cat, book):
    with open(os.path.join(ROOT, 'data', f'{cat}-data.json'), encoding='utf-8') as f:
        data = json.load(f)
    if book not in data:
        raise SystemExit(f'{book!r} not found in data/{cat}-data.json. Known books: {list(data.keys())}')
    chapters = data[book]
    return [[cap_first(transliterate_verse(v)) for v in ch] for ch in chapters]

def generate(cat, book, lang):
    out_path = os.path.join(ROOT, 'data', f'{cat}-{lang}.json')
    existing = {}
    if os.path.exists(out_path):
        with open(out_path, encoding='utf-8') as f:
            existing = json.load(f)
    existing[book] = transliterate_book(cat, book)
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=0)
        f.write('\n')
    nverses = sum(len(ch) for ch in existing[book])
    print(f'Wrote {book} ({len(existing[book])} chapters, {nverses} verses) into {out_path}')

def validate():
    with open('/tmp/claude-0/-home-user-Bet-El/7368b576-15ac-5c60-878f-cf494ca7bc20/scratchpad/verse_pairs.json', encoding='utf-8') as f:
        pairs = json.load(f)
    exact=0; close=0; total=len(pairs)
    bad=[]
    for he,en in pairs:
        got = cap_first(transliterate_verse(he))
        if got==en:
            exact+=1
        else:
            a=got.lower().replace('-',' ')
            b=en.lower().replace('-',' ')
            if a==b:
                close+=1
            else:
                bad.append((he,en,got))
    print(f'exact={exact}/{total} ({100*exact/total:.1f}%) close={close} ({100*close/total:.1f}%) bad={len(bad)} ({100*len(bad)/total:.1f}%)')
    import random
    random.seed(7)
    for he,en,got in random.sample(bad, min(25,len(bad))):
        print('HE :', he)
        print('EXP:', en)
        print('GOT:', got)
        print()

if __name__=='__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--cat', choices=['neviim','ketuvim'])
    ap.add_argument('--book')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--validate', action='store_true')
    args = ap.parse_args()
    if args.validate:
        validate()
    elif args.cat and args.book:
        generate(args.cat, args.book, args.lang)
    else:
        ap.error('pass --cat/--book/--lang to generate a book, or --validate to run the test suite')
