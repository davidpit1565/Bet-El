#!/usr/bin/env python3
"""One-time data fix: fill the commentary (Targum / Rashi / Metzudat David /
Metzudat Zion) that the original data prep never fetched for the FIRST-chapter
verses of every Nevi'im/Ketuvim ref that crosses a chapter boundary (e.g.
"Proverbs 3:34-4:3" had nothing for 3:34 and 3:35) - 136 verses year-wide,
the same off-by-a-chapter bug chokVerseSegs() had in index.html.

For each (book, commentator) it first proves that Sefaria's default Hebrew
version is the SAME text the bundle already carries (on a verse that has it),
then fetches only the missing verses, by range, and inserts them into the
parasha bundle's `_comm` in the existing shape ({"<Book c:v>": {"rashi": [..],
...}}; a commentator with no text for a verse is left out, as elsewhere).
A commentator the bundle never carries for a book (Rashi on Joshua / Kings)
is not added.

    python3 scripts/fill-cross-chapter-comm.py          # dry run
    python3 scripts/fill-cross-chapter-comm.py --write
"""
import json, re, sys, time, ssl, urllib.request, urllib.error, urllib.parse, collections, os

WRITE = '--write' in sys.argv
CA = '/root/.ccr/ca-bundle.crt'
CTX = ssl.create_default_context(cafile=CA) if os.path.exists(CA) else ssl.create_default_context()
NEVIIM = {'Joshua','Judges','I Samuel','II Samuel','I Kings','II Kings','Isaiah','Jeremiah','Ezekiel','Hosea','Joel','Amos',
          'Obadiah','Jonah','Micah','Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi'}
SRC = {'rashi': 'Rashi on {}', 'mdavid': 'Metzudat David on {}', 'mzion': 'Metzudat Zion on {}'}
def src(w, book):
    if w == 'targum': return ('Targum Jonathan on {}' if book in NEVIIM else 'Aramaic Targum to {}').format(book)
    return SRC[w].format(book)

def slug(s): return re.sub(r'^-|-$', '', re.sub(r'[^A-Za-z0-9]+', '-', s))
def get(ref):
    u = 'https://www.sefaria.org/api/v3/texts/' + urllib.parse.quote(ref) + '?version=hebrew'
    for k in range(4):
        try: return json.load(urllib.request.urlopen(u, context=CTX, timeout=60))
        except urllib.error.HTTPError as e:
            if e.code == 404: print('  404 (no text):', ref); return {}
            if k == 3: raise
            time.sleep(2 + 2 * k)
        except Exception as e:
            if k == 3: raise
            time.sleep(2 + 2 * k)
def per_verse(ref, n):
    """list (one entry per verse of the range) of lists of comment strings"""
    d = get(ref); vs = d.get('versions') or []
    if not vs: return [[] for _ in range(n)]
    t = vs[0]['text']
    # a single verse comes back as that verse's comments (a flat list, or one
    # string for a Targum); a range as one entry per verse
    if n == 1:
        flat = [t] if isinstance(t, str) else [y for x in t for y in (x if isinstance(x, list) else [x])]
        return [[y for y in flat if isinstance(y, str) and y.strip()]]
    if isinstance(t, str): t = [t]
    out = []
    for x in t:
        if isinstance(x, str): out.append([x] if x.strip() else [])
        else: out.append([y for y in x if isinstance(y, str) and y.strip()])
    while len(out) < n: out.append([])
    return out[:n]

ix = json.load(open('data/chok-leyisrael-index.json', encoding='utf-8'))
rx = re.compile(r'^(.*?) (\d+):(\d+)-(\d+):(\d+)$')
bundles = {}
def bundle(pk):
    f = 'data/chok-leyisrael/' + slug(pk) + '.json'
    if f not in bundles: bundles[f] = json.load(open(f, encoding='utf-8'))
    return f, bundles[f]

# which commentators each book carries anywhere in the bundles
uses = collections.defaultdict(set)
for pk in ix['schedule']:
    f, b = bundle(pk)
    for i, v in b.get('_comm', {}).items(): uses[i.rsplit(' ', 1)[0]].update(v.keys())

# the missing first-chapter runs: (file, book, chapter, v_from, v_to)
runs = []
for pk, days in ix['schedule'].items():
    f, b = bundle(pk); cm = b.get('_comm', {})
    for d, e in days.items():
        for k in ('neviim', 'ketuvim'):
            for r in e.get(k) or []:
                m = rx.match(r)
                if not m: continue
                book, c1, v1, c2, v2 = m.group(1), *map(int, m.groups()[1:])
                n = len(b.get(r, []))
                if not n or c2 != c1 + 1: continue
                end = v1 + (n - v2) - 1
                miss = [v for v in range(v1, end + 1) if f'{book} {c1}:{v}' not in cm]
                if miss: runs.append((f, book, c1, miss[0], miss[-1]))
runs = sorted(set(runs))
print(len(runs), 'runs,', sum(r[4] - r[3] + 1 for r in runs), 'verses')

# prove each (book, commentator) source is the text already in the bundles
checked = {}
def verify(book, w):
    if (book, w) in checked: return checked[(book, w)]
    sample = None
    for f, b in bundles.items():
        for i, v in b.get('_comm', {}).items():
            if i.rsplit(' ', 1)[0] == book and v.get(w): sample = (i, v[w]); break
        if sample: break
    ok = False
    if sample:
        got = per_verse(src(w, book) + ' ' + sample[0].rsplit(' ', 1)[1], 1)[0]
        # the same edition, allowing only stray vowel/cantillation marks the
        # original copy carried (Metzudat David's text has had a few removed)
        nik = lambda x: re.sub(r'[\u0591-\u05C7]', '', x)
        ok = got == sample[1] or [nik(x) for x in got] == [nik(x) for x in sample[1]]
        print(f'  verify {src(w, book)} on {sample[0]}:', ('SAME TEXT' if got == sample[1] else 'SAME TEXT (nikud marks differ)') if ok else 'DIFFERENT - skipped')
    checked[(book, w)] = ok
    return ok

added = collections.Counter(); changed = set()
for f, book, c, a, z in runs:
    b = bundles[f]; cm = b.setdefault('_comm', {})
    ref_range = f'{c}:{a}' + (f'-{z}' if z > a else '')
    for w in ['targum', 'rashi', 'mdavid', 'mzion']:
        if w not in uses[book] or not verify(book, w): continue
        vals = per_verse(src(w, book) + ' ' + ref_range, z - a + 1)
        for k, v in enumerate(range(a, z + 1)):
            if vals[k]:
                cm.setdefault(f'{book} {c}:{v}', {})[w] = vals[k]; added[w] += 1; changed.add(f)
        time.sleep(0.25)
print('added comment lists:', dict(added))
print('files to change:', len(changed))
if WRITE:
    # the bundles' own format: compact, non-ASCII, no trailing newline
    for f in sorted(changed):
        with open(f, 'w', encoding='utf-8') as o: o.write(json.dumps(bundles[f], ensure_ascii=False, separators=(',', ':')))
    print('written')
