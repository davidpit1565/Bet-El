#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates English transliteration for Mishneh Torah (Rambam) halachot,
one "Sefer" (of the 14 top-level books) at a time, reusing the same
rule-based Hebrew->Latin transliterator built for Nevi'im/Ketuvim (see
scripts/transliterate-neviim-ketuvim.py - qof='k', Tetragrammaton always
"Adonai", validated at 57.9% exact match against the Torah's own data).

Rambam's halacha text lives chunked into data/chok-rambam/<block>.json
files (26 "blocks" of the 3-year daily-study cycle), keyed by the full
Sefaria ref (e.g. "Mishneh Torah, Foundations of the Torah 1") rather than
by book, so this script first works out which blocks hold a given Sefer's
chapters from data/chok-cycles.json's rambam.order/rambam.sefarim, then
pulls just those refs out of the relevant block files.

Output: data/rambam-en.json, a flat {ref: [english paragraph strings]} map
- one key per chapter, matching the key shape of data/chok-rambam/<block>.json
itself so index.html's ckCycleSegs() can look a ref up directly.

Usage:
    python3 scripts/transliterate-rambam.py --list-sefarim
    python3 scripts/transliterate-rambam.py --sefer "סֵפֶר הַמַּדָּע" --lang en
"""
import json, os, argparse, importlib.util

ROOT = os.path.join(os.path.dirname(__file__), '..')

spec = importlib.util.spec_from_file_location(
    "nk_translit", os.path.join(os.path.dirname(__file__), "transliterate-neviim-ketuvim.py"))
nk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nk)


def skeleton(s):
    return ''.join(c for c in s if 'א' <= c <= 'ת')


def load_cycles():
    with open(os.path.join(ROOT, 'data', 'chok-cycles.json'), encoding='utf-8') as f:
        return json.load(f)


def sefarim_list(cyc):
    # de-duplicate while keeping first-seen order
    seen = []
    for v in cyc['rambam']['sefarim'].values():
        if v not in seen:
            seen.append(v)
    return seen


def refs_for_sefer(cyc, sefer_he):
    skel = skeleton(sefer_he)
    target = next((v for v in sefarim_list(cyc) if skeleton(v) == skel), None)
    if target is None:
        raise SystemExit(f'Sefer {sefer_he!r} not found. Known: {sefarim_list(cyc)}')
    books = [b for b, s in cyc['rambam']['sefarim'].items() if s == target]
    order = cyc['rambam']['order']
    indices = [i for i, e in enumerate(order) if e['book'] in books]
    refs = [order[i]['ref'] for i in indices]
    blocks = sorted(set(i // cyc['block'] for i in indices))
    return target, refs, blocks


def generate(sefer_he, lang):
    nk.DIALECT = lang
    cyc = load_cycles()
    target, refs, blocks = refs_for_sefer(cyc, sefer_he)
    refs_needed = set(refs)
    hebrew = {}
    for b in blocks:
        with open(os.path.join(ROOT, 'data', 'chok-rambam', f'{b}.json'), encoding='utf-8') as f:
            blk = json.load(f)
        for k, v in blk.items():
            if k in refs_needed:
                hebrew[k] = v
    missing = refs_needed - set(hebrew.keys())
    if missing:
        raise SystemExit(f'Missing {len(missing)} refs in chok-rambam blocks: {missing}')

    out_path = os.path.join(ROOT, 'data', 'rambam-en.json' if lang == 'en' else f'rambam-{lang}.json')
    existing = {}
    if os.path.exists(out_path):
        with open(out_path, encoding='utf-8') as f:
            existing = json.load(f)
    for ref in refs:
        existing[ref] = [nk.cap_first(nk.transliterate_verse(p)) for p in hebrew[ref]]
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=0)
        f.write('\n')
    nparas = sum(len(existing[r]) for r in refs)
    print(f'Wrote {target} ({len(refs)} chapters, {nparas} halachot) into {out_path}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--sefer', help='Hebrew name of the Sefer, e.g. סֵפֶר הַמַּדָּע')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--list-sefarim', action='store_true')
    args = ap.parse_args()
    if args.list_sefarim:
        for s in sefarim_list(load_cycles()):
            print(s)
    elif args.sefer:
        generate(args.sefer, args.lang)
    else:
        ap.error('pass --sefer (see --list-sefarim) or --list-sefarim')
