#!/usr/bin/env bash
# Assemble l'arborescence complète à copier à la racine de la carte SD de l'ESP32 :
#
#   <sortie>/index.html      page d'accueil (une tuile par site)
#   <sortie>/webgames/       lanceur Arcade + Émulateurs (EmulatorJS, LittleJS Arcade, tes ROMs)
#   <sortie>/<app>/          une app par fichier de tools/apps.d/*.json (clonée depuis GitHub et construite)
#
# Usage : tools/build-sd.sh [--out DIR] [--gzip] [--no-apps]
#   --out DIR   dossier de sortie, VIDÉ puis recréé (défaut : ./sd)
#   --gzip      crée aussi des copies .gz pour webgames/ (js, css, html, json)
#   --no-apps   n'installe pas les apps GitHub (hors ligne) ; la page d'accueil est quand même générée
#
# Prérequis : curl, git, node ≥ 18, jq, flock, python3 (apps), et 7z ou py7zr.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$ROOT/sd"
GZIP=0
APPS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) [[ $# -ge 2 ]] || { echo "--out demande un dossier" >&2; exit 2; }; OUT="$(realpath -m "$2")"; shift 2 ;;
    --gzip) GZIP=1; shift ;;
    --no-apps) APPS=0; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

[[ -d vendor/emulatorjs && -d vendor/littlejs-arcade ]] || tools/fetch-vendor.sh

case "$OUT" in "$ROOT"|"/"|"$HOME") echo "Sortie refusée : $OUT" >&2; exit 2 ;; esac
rm -rf "$OUT"
WG="$OUT/webgames"
mkdir -p "$WG"

# 1. Lanceur et page de jeu.
cp -r web/. "$WG/"

# 2. EmulatorJS (code + cores sélectionnés).
mkdir -p "$WG/emulatorjs"
cp -r vendor/emulatorjs/data "$WG/emulatorjs/data"

# 3. LittleJS Arcade : uniquement ce dont les jeux ont besoin.
A="vendor/littlejs-arcade"
mkdir -p "$WG/arcade" "$WG/catalog"
cp -r "$A/games" "$A/templates" "$WG/arcade/"
mkdir -p "$WG/arcade/dist" "$WG/arcade/images"
for f in littlejs.release.js box2d.wasm.js box2d.wasm.wasm; do
  cp "$A/dist/$f" "$WG/arcade/dist/"
done
cp "$A"/images/*.png "$WG/arcade/images/"
node tools/gen-catalog.mjs arcade "$A" "$WG/catalog/arcade.json"

# 4. ROMs de l'utilisateur (optionnelles) + leur catalogue.
if [[ -d roms ]] && [[ -n "$(find roms -mindepth 1 -maxdepth 1 ! -name README.md -print -quit)" ]]; then
  mkdir -p "$WG/roms"
  find roms -mindepth 1 -maxdepth 1 ! -name README.md -exec cp -r {} "$WG/roms/" \;
  node tools/gen-catalog.mjs roms "$WG/roms" "$WG/roms.json" web/data/systems.json
fi

# 5. Licences (obligation de redistribution : GPL, MIT).
mkdir -p "$WG/licenses"
cp LICENSE "$WG/licenses/WebGames-GPL-3.0.txt"
cp vendor/emulatorjs/LICENSE "$WG/licenses/EmulatorJS-GPL-3.0.txt"
cp "$A/LICENSE" "$WG/licenses/LittleJSArcade-MIT.txt"
cp THIRD_PARTY.md "$WG/licenses/THIRD_PARTY.md"

# 6. Pré-compression optionnelle.
if [[ $GZIP -eq 1 ]]; then
  find "$WG" -type f \( -name '*.js' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) \
    ! -path "$WG/licenses/*" -print0 | xargs -0 -n1 -P4 gzip -9 -k -f
fi

# 7. Apps GitHub (tools/apps.d) et page d'accueil.
export SKIP_FS_CHECK=1   # la sortie est un dossier de travail, pas forcément la carte FAT32
APPS_FAILED=0
if [[ $APPS -eq 1 ]]; then
  tools/build-apps.sh "$OUT" || APPS_FAILED=1
else
  tools/build-apps.sh "$OUT" --index-only
fi

echo "Terminé : $OUT ($(du -sh "$OUT" | cut -f1)). Copie son contenu à la racine de la carte SD (FAT32)."
if [[ $APPS_FAILED -eq 1 ]]; then
  echo "Attention : au moins une app a échoué (voir « ECHEC » ci-dessus) ; les autres sont en place." >&2
  exit 1
fi
