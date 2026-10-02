#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates English transliteration for the entire Tanya (only 124 units
total, small enough to do in one pass - unlike Rambam/Mishnah there's no
natural "do one part, check in" split point), reusing the same rule-based
transliterator (see scripts/transliterate-neviim-ketuvim.py).

Source: data/chok-tanya-index.json (order/parts metadata, keyed the same
way as data/chok-cycles.json's rambam.order) plus the actual halacha/text
blocks in data/chok-tanya/<block>.json (same {ref: [paragraphs]} shape as
chok-rambam).

Output: data/tanya-en.json, a flat {ref: [english paragraphs]} map, same
shape as rambam-en.json, consumed the same way by ckCycleSegs()-style
lookup in index.html (ckTanyaSegs()).

Usage:
    python3 scripts/transliterate-tanya.py --lang en
"""
import json, os, argparse, importlib.util

ROOT = os.path.join(os.path.dirname(__file__), '..')

spec = importlib.util.spec_from_file_location(
    "nk_translit", os.path.join(os.path.dirname(__file__), "transliterate-neviim-ketuvim.py"))
nk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nk)


def generate(lang):
    with open(os.path.join(ROOT, 'data', 'chok-tanya-index.json'), encoding='utf-8') as f:
        idx = json.load(f)
    block_size = idx['block']
    refs = [e['ref'] for e in idx['order']]
    blocks = sorted(set(i // block_size for i in range(len(refs))))

    hebrew = {}
    for b in blocks:
        with open(os.path.join(ROOT, 'data', 'chok-tanya', f'{b}.json'), encoding='utf-8') as f:
            blk = json.load(f)
        hebrew.update(blk)
    missing = set(refs) - set(hebrew.keys())
    if missing:
        raise SystemExit(f'Missing {len(missing)} refs in chok-tanya blocks: {missing}')

    out_path = os.path.join(ROOT, 'data', 'tanya-en.json' if lang == 'en' else f'tanya-{lang}.json')
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
    print(f'Wrote Tanya ({len(refs)} units, {nparas} paragraphs) into {out_path}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--lang', default='en')
    args = ap.parse_args()
    generate(args.lang)
