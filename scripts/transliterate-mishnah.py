#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates English transliteration for the Mishnah, one Seder (of the 6) at
a time, reusing the same rule-based Hebrew->Latin transliterator built for
Nevi'im/Ketuvim/Rambam (see scripts/transliterate-neviim-ketuvim.py -
qof='k', Tetragrammaton/"יי" always "Adonai", HTML-citation-aware, 57.9%
exact match validated against the Torah's own data).

Source: data/mishnah-index.json (a derived re-grouping of the chok-leyisrael
text into seder -> tractate -> chapter -> mishnah, see index.html's own
comment above ensureMishnahIndex() and scripts/build-mishnah-index.mjs -
not re-fetched here, just read as-is).

Output: data/mishnah-en.json, a flat {"<Masechet> <ch>:<n>": "english"} map,
e.g. "Berakhot 1:1" - one key per mishnah, added to incrementally (one
Seder's tractates at a time) the same way as rambam-en.json/neviim-en.json.

Usage:
    python3 scripts/transliterate-mishnah.py --list-sedarim
    python3 scripts/transliterate-mishnah.py --seder Zeraim --lang en
"""
import json, os, argparse, importlib.util

ROOT = os.path.join(os.path.dirname(__file__), '..')

spec = importlib.util.spec_from_file_location(
    "nk_translit", os.path.join(os.path.dirname(__file__), "transliterate-neviim-ketuvim.py"))
nk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nk)


def load_index():
    with open(os.path.join(ROOT, 'data', 'mishnah-index.json'), encoding='utf-8') as f:
        return json.load(f)


def sedarim_list(idx):
    return [s['seder'] for s in idx['sedarim']]


def generate(seder_key, lang):
    idx = load_index()
    seder = next((s for s in idx['sedarim'] if s['seder'] == seder_key), None)
    if seder is None:
        raise SystemExit(f'Seder {seder_key!r} not found. Known: {sedarim_list(idx)}')

    out_path = os.path.join(ROOT, 'data', 'mishnah-en.json' if lang == 'en' else f'mishnah-{lang}.json')
    existing = {}
    if os.path.exists(out_path):
        with open(out_path, encoding='utf-8') as f:
            existing = json.load(f)

    nmishnayot = 0
    for tractate in seder['tractates']:
        for chapter in tractate['chapters']:
            for m in chapter['mishnayot']:
                key = f"{tractate['masechet']} {chapter['ch']}:{m['n']}"
                existing[key] = nk.cap_first(nk.transliterate_verse(m['text']))
                nmishnayot += 1

    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=0)
        f.write('\n')
    print(f'Wrote {seder_key} ({len(seder["tractates"])} tractates, {nmishnayot} mishnayot) into {out_path}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--seder')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--list-sedarim', action='store_true')
    args = ap.parse_args()
    if args.list_sedarim:
        for s in sedarim_list(load_index()):
            print(s)
    elif args.seder:
        generate(args.seder, args.lang)
    else:
        ap.error('pass --seder (see --list-sedarim) or --list-sedarim')
