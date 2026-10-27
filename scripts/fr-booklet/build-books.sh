#!/usr/bin/env bash
# Builds the five volumes (one per book) into docs/fr-booklet/: Bereshit, Shemot, Vayikra, Bamidbar, Devarim.
set -e
cd "$(dirname "$0")/../.."
OUT=docs/fr-booklet
build() { node scripts/fr-booklet/build.mjs --from "$1" --to "$2" --out "$OUT/$3.pdf" "${@:4}"; }
build "Bereshit" "Vayechi" 1-Berechit "$@"
build "Shemot" "Pekudei" 2-Chemot "$@"
build "Vayikra" "Bechukotai" 3-Vayikra "$@"
build "Bamidbar" "Masei" 4-Bemidbar "$@"
build "Devarim" "Vezot Haberakhah" 5-Devarim "$@"
