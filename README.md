# WebGames

Des jeux jouables dans le navigateur, **servis par un ESP32 depuis une carte SD**.
Tout le code s'exécute côté client : le microcontrôleur ne sert que des fichiers statiques.

- **Arcade** : jeux originaux libres ([LittleJS Arcade](https://github.com/KilledByAPixel/LittleJSArcade), MIT).
- **Émulateurs** : NES, SNES, Game Boy / Color / Advance, Mega Drive, Master System,
  Game Gear, PC Engine, Amstrad CPC via [EmulatorJS](https://github.com/EmulatorJS/EmulatorJS).
  Les ROMs sont fournies par l'utilisateur.

## Démarrage rapide

```bash
tools/fetch-vendor.sh      # télécharge EmulatorJS (cores) et LittleJS Arcade dans vendor/
cp ~/mes_roms/... roms/nes/ # optionnel : voir roms/README.md
tools/build-sd.sh          # produit sd/ ; option --gzip pour des copies .gz
```

Copie ensuite le **contenu** de `sd/` à la racine de la carte SD (FAT32).

### Avec l'installeur de sites (`lstux-github/`)

WebGames est aussi un site comme les autres pour `lstux-github/sd-sites.sh` : la conf
`lstux-github/sites.d/webgames.json` clone ce dépôt, lance `tools/build-sd.sh` et publie le
résultat dans `<carte>/webgames/`, à côté de tes autres apps. La page d'accueil de la carte
affiche une tuile « WebGames ».

```bash
cd lstux-github
./sd-sites.sh /media/sd                 # tous les sites de sites.d/
./sd-sites.sh /media/sd --only webgames # seulement WebGames (mise à jour)
```

Chaque mise à jour remplace le dossier `webgames/`, mais l'option `keep` de la conf conserve
`roms/` et `roms.json`. Tes ROMs se déposent donc **directement sur la carte**, sans repasser par git :

```bash
cp ~/roms/nes/*.nes /media/sd/webgames/roms/nes/
node tools/gen-catalog.mjs roms /media/sd/webgames/roms /media/sd/webgames/roms.json
```

Prérequis supplémentaires : `jq`, `flock`. L'archive EmulatorJS (~300 Mo) est retéléchargée à
chaque mise à jour de WebGames.

Pour tester sans ESP32 :

```bash
python3 -m http.server 8080 --directory sd   # puis http://localhost:8080
```

Prérequis : `bash`, `curl`, `git`, `node` ≥ 18, et `7z` (p7zip) ou `python3` + `py7zr`.

## Structure

```
web/        lanceur et page d'émulation (copiés tels quels à la racine de la carte)
tools/      fetch-vendor.sh, build-sd.sh, gen-catalog.mjs, vendor.conf (versions épinglées)
roms/       tes ROMs (ignorées par git)
vendor/     composants tiers téléchargés (ignorés par git)
sd/         sortie prête pour la carte SD (ignorée par git)
```

## Contraintes liées à l'ESP32

- **HTTP sur IP locale = contexte non sécurisé** : pas de `SharedArrayBuffer`, de service
  worker ni de threads WASM. On n'embarque donc que les cores sans threads, et
  `EJS_threads` est désactivé.
- **Types MIME** : le serveur doit envoyer `application/wasm` pour `.wasm` et
  `text/javascript` pour `.js`. Les fichiers `.data` (cores) peuvent être `application/octet-stream`.
- **Débit** : un core pèse ~1 Mo ; le WiFi de l'ESP32 plafonne autour de 0,3–1 Mo/s.
  Le premier chargement d'un système prend quelques secondes, puis le navigateur met en cache.
- **Compression** : `--gzip` crée des `.gz` à côté des originaux. À toi d'envoyer
  `Content-Encoding: gzip` côté firmware (ex. ESPAsyncWebServer le gère pour les `.gz`).
- **Plusieurs connexions** : le serveur HTTP de l'ESP32 gère mal les requêtes parallèles ;
  limite le nombre de sockets simultanés si le chargement échoue.
- **Accès Internet** : EmulatorJS tente une vérification de version vers son CDN au
  démarrage. Hors ligne, la requête échoue sans conséquence (simple message dans la console).
- **Noms de fichiers longs** : active les noms longs (LFN) de FatFs, sinon les cores
  (`genesis_plus_gx-wasm.data`…) ne seront pas trouvés.

## Licences

Code du projet : [GPL v3](LICENSE). Composants tiers et réserves sur les licences de
certains cores : voir [THIRD_PARTY.md](THIRD_PARTY.md).
