#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates English transliteration for the Zohar (data/chok-cycles.json's
"zohar", 1638 total daf-sides across 50 parasha-based parts), one part at
a time - reusing the same rule-based transliterator (see
scripts/transliterate-neviim-ketuvim.py). The Zohar's Aramaic text mixes
freely with Hebrew/Aramaic citations in parentheses (e.g. page/folio
cross-references like "(פנחס רלג)") - these are unvocalized and are
dropped automatically by the transliterator's general zero-nikud word
filter, with no Zohar-specific handling needed; verified clean.

Source: data/chok-zohar/<block>.json (block size = data/chok-cycles.json's
global "block", 40), keyed by POSITIONAL INDEX (not a named ref) - each
value is a flat list of paragraph strings (unlike Rambam/daf's dict shape).

Output: data/zohar-en.json, keyed the same positional way:
{"<index>": [english paragraphs]}, consumed directly by ckCycleSegs()'s
'zohar' branch in index.html.

Usage:
    python3 scripts/transliterate-zohar.py --list-parts
    python3 scripts/transliterate-zohar.py --part Introduction --lang en
"""
import json, os, argparse, importlib.util

ROOT = os.path.join(os.path.dirname(__file__), '..')

spec = importlib.util.spec_from_file_location(
    "nk_translit", os.path.join(os.path.dirname(__file__), "transliterate-neviim-ketuvim.py"))
nk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nk)


def load_cycles():
    with open(os.path.join(ROOT, 'data', 'chok-cycles.json'), encoding='utf-8') as f:
        return json.load(f)


def parts_list(cyc):
    seen = []
    for e in cyc['zohar']['order']:
        if e['part'] not in seen:
            seen.append(e['part'])
    return seen


def generate(part, lang):
    nk.DIALECT = lang
    cyc = load_cycles()
    order = cyc['zohar']['order']
    block_size = cyc['block']
    indices = [i for i, e in enumerate(order) if e['part'] == part]
    if not indices:
        raise SystemExit(f'Part {part!r} not found. Known: {parts_list(cyc)}')
    blocks = sorted(set(i // block_size for i in indices))

    hebrew = {}
    for b in blocks:
        with open(os.path.join(ROOT, 'data', 'chok-zohar', f'{b}.json'), encoding='utf-8') as f:
            blk = json.load(f)
        for i in indices:
            rec = blk.get(str(i))
            if rec is not None:
                hebrew[i] = rec
    missing = set(indices) - set(hebrew.keys())
    if missing:
        raise SystemExit(f'Missing {len(missing)} zohar indices in chok-zohar blocks: {sorted(missing)}')

    out_path = os.path.join(ROOT, 'data', 'zohar-en.json' if lang == 'en' else f'zohar-{lang}.json')
    existing = {}
    if os.path.exists(out_path):
        with open(out_path, encoding='utf-8') as f:
            existing = json.load(f)
    nparas = 0
    for i in indices:
        existing[str(i)] = [nk.cap_first(nk.transliterate_verse(p)) for p in hebrew[i]]
        nparas += len(hebrew[i])
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=0)
        f.write('\n')
    print(f'Wrote {part} ({len(indices)} daf-sides, {nparas} paragraphs) into {out_path}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--part')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--list-parts', action='store_true')
    args = ap.parse_args()
    if args.list_parts:
        for p in parts_list(load_cycles()):
            print(p)
    elif args.part:
        generate(args.part, args.lang)
    else:
        ap.error('pass --part (see --list-parts) or --list-parts')
