#!/usr/bin/env bash
# Assemble le contenu à copier à la racine de la carte SD de l'ESP32.
#
# Usage : tools/build-sd.sh [--out DIR] [--gzip]
#   --out DIR  dossier de sortie (défaut : ./sd)
#   --gzip     crée aussi des copies .gz (js, css, html, json, wasm.js) pour un
#              serveur qui envoie « Content-Encoding: gzip » (ex. ESPAsyncWebServer)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$ROOT/sd"
GZIP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$(realpath -m "$2")"; shift 2 ;;
    --gzip) GZIP=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

[[ -d vendor/emulatorjs && -d vendor/littlejs-arcade ]] || tools/fetch-vendor.sh

case "$OUT" in "$ROOT"|"/"|"$HOME") echo "Sortie refusée : $OUT" >&2; exit 2 ;; esac
rm -rf "$OUT"
mkdir -p "$OUT"

# 1. Lanceur et page de jeu.
cp -r web/. "$OUT/"

# 2. EmulatorJS (code + cores sélectionnés).
mkdir -p "$OUT/emulatorjs"
cp -r vendor/emulatorjs/data "$OUT/emulatorjs/data"

# 3. LittleJS Arcade : uniquement ce dont les jeux ont besoin.
A="vendor/littlejs-arcade"
mkdir -p "$OUT/arcade" "$OUT/catalog"
cp -r "$A/games" "$A/templates" "$OUT/arcade/"
mkdir -p "$OUT/arcade/dist" "$OUT/arcade/images"
for f in littlejs.release.js box2d.wasm.js box2d.wasm.wasm; do
  cp "$A/dist/$f" "$OUT/arcade/dist/"
done
cp "$A"/images/*.png "$OUT/arcade/images/"
node tools/gen-catalog.mjs arcade "$A" "$OUT/catalog/arcade.json"

# 4. ROMs de l'utilisateur (optionnelles) + leur catalogue.
mkdir -p "$OUT/roms"
if [[ -d roms ]]; then
  find roms -mindepth 1 -maxdepth 1 ! -name README.md -exec cp -r {} "$OUT/roms/" \;
fi
node tools/gen-catalog.mjs roms "$OUT/roms" "$OUT/roms.json" web/data/systems.json

# 5. Licences (obligation de redistribution : GPL, MIT).
mkdir -p "$OUT/licenses"
cp LICENSE "$OUT/licenses/WebGames-GPL-3.0.txt"
cp vendor/emulatorjs/LICENSE "$OUT/licenses/EmulatorJS-GPL-3.0.txt"
cp "$A/LICENSE" "$OUT/licenses/LittleJSArcade-MIT.txt"
cp THIRD_PARTY.md "$OUT/licenses/THIRD_PARTY.md"

# 6. Pré-compression optionnelle.
if [[ $GZIP -eq 1 ]]; then
  find "$OUT" -type f \( -name '*.js' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) \
    ! -path "$OUT/licenses/*" -print0 | xargs -0 -n1 -P4 gzip -9 -k -f
fi

echo "Terminé : $OUT ($(du -sh "$OUT" | cut -f1)). Copie son contenu à la racine de la carte SD."
