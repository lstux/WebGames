#!/usr/bin/env bash
# Télécharge EmulatorJS (cores sélectionnés) et LittleJS Arcade dans vendor/.
# Usage : tools/fetch-vendor.sh
# Prérequis : curl, git, et 7z/7zz/7za ou python3 + py7zr.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=tools/vendor.conf
source tools/vendor.conf

VENDOR="$ROOT/vendor"
CACHE="$VENDOR/.cache"
mkdir -p "$CACHE"

extract_7z() { # extract_7z archive destdir
  local archive="$1" dest="$2"
  mkdir -p "$dest"
  for bin in 7zz 7z 7za; do
    if command -v "$bin" >/dev/null 2>&1; then
      "$bin" x -y -bd -o"$dest" "$archive" >/dev/null
      return
    fi
  done
  if python3 -c 'import py7zr' >/dev/null 2>&1; then
    python3 -I -c 'import sys, py7zr
with py7zr.SevenZipFile(sys.argv[1]) as z:
    z.extractall(path=sys.argv[2])' "$archive" "$dest"
    return
  fi
  echo "Erreur : installe 7z (p7zip) ou « pip install py7zr »." >&2
  exit 1
}

# --- EmulatorJS -------------------------------------------------------------
EJS_DIR="$VENDOR/emulatorjs"
if [[ -f "$EJS_DIR/VERSION" && "$(cat "$EJS_DIR/VERSION")" == "$EJS_VERSION" ]]; then
  echo "EmulatorJS $EJS_VERSION déjà présent."
else
  echo "Téléchargement d'EmulatorJS $EJS_VERSION…"
  ARCHIVE="$CACHE/emulatorjs-$EJS_VERSION.7z"
  [[ -s "$ARCHIVE" ]] || curl -fSL --retry 3 -o "$ARCHIVE" "$EJS_URL"

  TMP="$(mktemp -d "$CACHE/ejs-extract.XXXXXX")"
  trap 'rm -rf "$TMP"' EXIT
  extract_7z "$ARCHIVE" "$TMP"

  rm -rf "$EJS_DIR"
  mkdir -p "$EJS_DIR/data/cores"
  # Tout data/ sauf cores/, src/ (le code source est déjà dans emulator.min.js).
  for item in "$TMP"/data/*; do
    case "$(basename "$item")" in cores|src) continue ;; esac
    cp -r "$item" "$EJS_DIR/data/"
  done
  cp "$TMP/data/cores/cores.json" "$EJS_DIR/data/cores/"
  mkdir -p "$EJS_DIR/data/cores/reports"
  for core in $EJS_CORES; do
    cp "$TMP/data/cores/reports/${core}.json" "$EJS_DIR/data/cores/reports/"
    for variant in "" "-legacy"; do
      f="$TMP/data/cores/${core}${variant}-wasm.data"
      [[ -f "$f" ]] || { echo "Core introuvable : $f" >&2; exit 1; }
      cp "$f" "$EJS_DIR/data/cores/"
    done
  done
  cp "$TMP/LICENSE" "$EJS_DIR/LICENSE"
  echo "$EJS_VERSION" > "$EJS_DIR/VERSION"
  rm -rf "$TMP"; trap - EXIT
fi

# --- LittleJS Arcade --------------------------------------------------------
LJSA_DIR="$VENDOR/littlejs-arcade"
if [[ -d "$LJSA_DIR/.git" && "$(git -C "$LJSA_DIR" rev-parse HEAD 2>/dev/null)" == "$LJSA_COMMIT" ]]; then
  echo "LittleJS Arcade ${LJSA_COMMIT:0:7} déjà présent."
else
  echo "Téléchargement de LittleJS Arcade ${LJSA_COMMIT:0:7}…"
  rm -rf "$LJSA_DIR"
  mkdir -p "$LJSA_DIR"
  git -C "$LJSA_DIR" init -q
  git -C "$LJSA_DIR" remote add origin "$LJSA_REPO"
  git -C "$LJSA_DIR" fetch -q --depth 1 origin "$LJSA_COMMIT"
  git -C "$LJSA_DIR" checkout -q FETCH_HEAD
fi

echo "OK : vendor/ prêt. Étape suivante : tools/build-sd.sh"
