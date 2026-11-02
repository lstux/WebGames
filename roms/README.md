# ROMs

Dépose ici **tes propres ROMs**, un dossier par système. Ce dossier est ignoré par git
(rien ne doit être publié).

```
roms/
├── nes/            .nes .fds .unf .unif
├── snes/           .smc .sfc .swc .fig
├── gb/  gbc/       .gb .dmg  /  .gbc
├── gba/            .gba
├── megadrive/      .md .smd .gen .bin
├── mastersystem/   .sms
├── gamegear/       .gg
├── pcengine/       .pce
└── cpc/            .dsk .sna .cdt .tap .cpr
```

Les archives `.zip` / `.7z` sont acceptées. `tools/build-sd.sh` copie ces fichiers vers
`webgames/roms/` et génère `webgames/roms.json` (le navigateur ne peut pas lister un dossier).

Pour ajouter des ROMs directement sur la carte, sans tout reconstruire :

```bash
node tools/gen-catalog.mjs roms /chemin/carte_sd/webgames/roms /chemin/carte_sd/webgames/roms.json
```
