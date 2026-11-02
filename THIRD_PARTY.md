# Composants tiers

Le code de ce dépôt est sous **GPL v3** (voir `LICENSE`). Les composants ci-dessous
ne sont **pas** versionnés ici : `tools/fetch-vendor.sh` les télécharge dans `vendor/`
(versions épinglées dans `tools/vendor.conf`) et `tools/build-sd.sh` les copie dans la
sortie destinée à la carte SD, avec leurs licences dans `licenses/`.

## EmulatorJS 4.2.3 — GPL v3

Interface web pour RetroArch/libretro. <https://github.com/EmulatorJS/EmulatorJS>

Cores WASM embarqués (compilés par le projet EmulatorJS, sources dans les dépôts liés).
Les licences indiquées sont celles des projets amont, **à vérifier avant toute
redistribution** :

| Core | Systèmes | Dépôt |
|---|---|---|
| fceumm | NES / Famicom | <https://github.com/EmulatorJS/libretro-fceumm> |
| nestopia | NES / Famicom | <https://github.com/EmulatorJS/nestopia> |
| snes9x | Super Nintendo | <https://github.com/EmulatorJS/snes9x> |
| gambatte | Game Boy / Color | <https://github.com/EmulatorJS/gambatte-libretro> |
| mgba | Game Boy / Color / Advance | <https://github.com/EmulatorJS/mgba> |
| genesis_plus_gx | Mega Drive, Master System, Game Gear | <https://github.com/EmulatorJS/Genesis-Plus-GX> |
| picodrive | Mega Drive, 32X | <https://github.com/EmulatorJS/picodrive> |
| smsplus | Master System, Game Gear | <https://github.com/EmulatorJS/smsplus-gx> |
| mednafen_pce | PC Engine | <https://github.com/EmulatorJS/beetle-pce-libretro> |
| cap32 | Amstrad CPC | <https://github.com/EmulatorJS/libretro-cap32> |
| crocods | Amstrad CPC | <https://github.com/EmulatorJS/libretro-crocods> |

> ⚠️ Attention : plusieurs de ces cores (notamment Snes9x, Genesis Plus GX et PicoDrive,
> à ma connaissance) ont des licences **non commerciales** ou propres, distinctes de la
> GPL. Usage personnel et non lucratif : aucun souci. Pour une redistribution ou un usage
> commercial, relis leurs fichiers de licence ou retire ces cores de `EJS_CORES`
> dans `tools/vendor.conf`.

Les ROMs et BIOS ne sont **pas** fournis : l'utilisateur apporte les siens et doit en
avoir le droit.

## LittleJS Arcade — MIT

Collection de petits jeux d'arcade basés sur le moteur LittleJS, © Frank Force.
<https://github.com/KilledByAPixel/LittleJSArcade> (commit épinglé dans `tools/vendor.conf`).
Les emojis inclus utilisent Twemoji (licence dans `games/TWEMOJI-LICENSE.txt` du dépôt amont).
Seuls les jeux hébergés dans le dépôt sont repris ; les entrées « hors site » (itch.io) sont
écartées car elles ne fonctionnent pas hors ligne.
