#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates English transliteration for the Talmud Bavli (Daf Yomi HaOlami
order, data/chok-cycles.json's "daf"), one masechet (tractate) at a time -
reusing the same rule-based transliterator (see
scripts/transliterate-neviim-ketuvim.py). The full Shas is enormous
(2711 dapim / roughly 118k text segments total, extrapolated from
Berakhot's 2749 segments across 63 dapim) - far too much for one pass, so
this generates incrementally like Rambam/Mishnah did, tractate by tractate.

Source: data/chok-daf/<block>.json, keyed by POSITIONAL INDEX (not a named
ref like Rambam/Mishnah/Tanya) - {"<i>": {"g": {"a": [...], "b": [...]}}}.
data/chok-cycles.json's daf.order[i] gives {t: masechet, daf: N, whole?}.

Output: data/daf-en.json, keyed the same positional way:
{"<i>": {"a": [...], "b": [...]}}, consumed directly by ckDafSideItems()-
style lookup in index.html.

Usage:
    python3 scripts/transliterate-gemara.py --list-masechtot
    python3 scripts/transliterate-gemara.py --masechet Berakhot --lang en
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


def masechtot_list(cyc):
    seen = []
    for e in cyc['daf']['order']:
        if e['t'] not in seen:
            seen.append(e['t'])
    return seen


def generate(masechet, lang):
    cyc = load_cycles()
    order = cyc['daf']['order']
    block_size = cyc['daf']['block']
    indices = [i for i, e in enumerate(order) if e['t'] == masechet]
    if not indices:
        raise SystemExit(f'Masechet {masechet!r} not found. Known: {masechtot_list(cyc)}')
    blocks = sorted(set(i // block_size for i in indices))

    hebrew = {}
    for b in blocks:
        with open(os.path.join(ROOT, 'data', 'chok-daf', f'{b}.json'), encoding='utf-8') as f:
            blk = json.load(f)
        for i in indices:
            rec = blk.get(str(i))
            if rec:
                hebrew[i] = rec.get('g', {})
    missing = set(indices) - set(hebrew.keys())
    if missing:
        raise SystemExit(f'Missing {len(missing)} daf indices in chok-daf blocks: {sorted(missing)}')

    out_path = os.path.join(ROOT, 'data', 'daf-en.json' if lang == 'en' else f'daf-{lang}.json')
    existing = {}
    if os.path.exists(out_path):
        with open(out_path, encoding='utf-8') as f:
            existing = json.load(f)
    nsegs = 0
    for i in indices:
        g = hebrew[i]
        out_g = {}
        for side in ('a', 'b'):
            segs = g.get(side)
            if segs:
                out_g[side] = [nk.cap_first(nk.transliterate_verse(s)) for s in segs]
                nsegs += len(segs)
        existing[str(i)] = out_g
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=0)
        f.write('\n')
    print(f'Wrote {masechet} ({len(indices)} dapim, {nsegs} segments) into {out_path}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--masechet')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--list-masechtot', action='store_true')
    args = ap.parse_args()
    if args.list_masechtot:
        for m in masechtot_list(load_cycles()):
            print(m)
    elif args.masechet:
        generate(args.masechet, args.lang)
    else:
        ap.error('pass --masechet (see --list-masechtot) or --list-masechtot')
