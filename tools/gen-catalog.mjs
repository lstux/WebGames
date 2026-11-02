#!/usr/bin/env node
// Génère les catalogues JSON lus par le lanceur (le navigateur ne peut pas
// lister un dossier : l'ESP32 ne sert que des fichiers statiques).
//
//   node tools/gen-catalog.mjs arcade <dossier LittleJS Arcade> <sortie.json>
//   node tools/gen-catalog.mjs roms   <dossier roms>            <sortie.json> [systems.json]
//
// « roms » peut être relancé directement sur la carte SD après avoir ajouté
// des ROMs : node gen-catalog.mjs roms /media/sd/roms /media/sd/roms.json
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const [mode, input, output, systemsPath] = process.argv.slice(2);

if (!mode || !input || !output) {
  console.error('Usage : gen-catalog.mjs <arcade|roms> <entrée> <sortie.json> [systems.json]');
  process.exit(2);
}

function arcade(dir) {
  // games.js déclare « const GAMES = [...] » : on l'évalue dans un bac à sable
  // sans accès au système de fichiers ni au réseau.
  const code = readFileSync(join(dir, 'games.js'), 'utf8');
  const games = vm.runInNewContext(`${code}\n;GAMES`, {}, { timeout: 2000 });
  return games
    // On écarte les jeux hébergés ailleurs (url:) : ils ne marchent pas hors ligne.
    .filter((g) => !g.url && typeof g.file === 'string' && g.file.endsWith('.html'))
    .filter((g) => statSync(join(dir, 'games', g.file), { throwIfNoEntry: false }))
    .map((g) => ({
      id: g.file.replace(/\.html$/, ''),
      file: g.file,
      name: g.name,
      emoji: g.emoji,
      category: g.category,
      desc: g.desc,
      tags: g.tags ?? [],
    }))
    .sort((a, b) => a.name.localeCompare(b.name, 'en'));
}

function roms(dir, systemsFile) {
  const systems = JSON.parse(readFileSync(systemsFile ?? join(here, '..', 'web', 'data', 'systems.json'), 'utf8'));
  const out = {};
  for (const system of Object.keys(systems)) {
    const folder = join(dir, system);
    let entries = [];
    try { entries = readdirSync(folder, { withFileTypes: true }); } catch { continue; }
    const exts = new Set([...systems[system].exts, 'zip', '7z']);
    const list = entries
      .filter((e) => e.isFile() && exts.has(extname(e.name).slice(1).toLowerCase()))
      .map((e) => ({
        name: basename(e.name, extname(e.name)),
        file: e.name,
        size: statSync(join(folder, e.name)).size,
      }))
      .sort((a, b) => a.name.localeCompare(b.name, 'fr'));
    if (list.length) out[system] = list;
  }
  return out;
}

const data = mode === 'arcade' ? arcade(resolve(input))
  : mode === 'roms' ? roms(resolve(input), systemsPath)
  : (console.error(`Mode inconnu : ${mode}`), process.exit(2));

writeFileSync(output, JSON.stringify(data));
const count = Array.isArray(data) ? data.length : Object.values(data).reduce((n, l) => n + l.length, 0);
console.log(`${output} : ${count} entrée(s)`);
