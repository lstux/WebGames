# WebGames

Des jeux jouables dans le navigateur, **servis par un ESP32 depuis une carte SD**.
Tout le code s'exécute côté client : le microcontrôleur ne sert que des fichiers statiques.

- **Arcade** : jeux originaux libres ([LittleJS Arcade](https://github.com/KilledByAPixel/LittleJSArcade), MIT).
- **Émulateurs** : NES, SNES, Game Boy / Color / Advance, Mega Drive, Master System,
  Game Gear, PC Engine, Amstrad CPC via [EmulatorJS](https://github.com/EmulatorJS/EmulatorJS).
  Les ROMs sont fournies par l'utilisateur.
- **Apps perso** : MathPulse, Slovingo, TravelBook, WebApps, construites depuis GitHub.

## Démarrage rapide

```bash
cp ~/mes_roms/... roms/nes/          # optionnel : voir roms/README.md
tools/build-sd.sh --out /exemple/sd  # tout en une commande
```

Le script télécharge EmulatorJS et LittleJS Arcade, construit tes apps GitHub
(`tools/apps.d/*.json`) et produit :

```
/exemple/sd/
├── index.html     page d'accueil, une tuile par site
├── webgames/      Arcade + Émulateurs (+ tes ROMs)
├── mathpulse/  slovingo/  travelbook/  webapps/
```

Copie ensuite le **contenu** du dossier à la racine de la carte SD (FAT32).
⚠️ Le dossier de sortie est **vidé** à chaque lancement : vise un dossier de travail,
pas la carte elle-même. Options : `--gzip` (copies `.gz` de `webgames/`),
`--no-apps` (hors ligne, sans les apps GitHub).

### Tes apps GitHub

Un fichier JSON par app dans `tools/apps.d/` (repo, branche, commandes de build, dossier
publié, titre, icône) ; le script les clone, les construit avec `BASE_PATH=/<nom>/` et les
copie dans `<sortie>/<nom>/`. `tools/build-apps.sh --help` détaille le format. Une app qui
échoue n'empêche pas les autres ; ajouter une app = ajouter un fichier JSON.

Pour tester sans ESP32 :

```bash
python3 -m http.server 8080 --directory sd   # puis http://localhost:8080
```

Prérequis : `bash`, `curl`, `git`, `node` ≥ 18, `jq`, `flock`, `python3` (builds des apps), et `7z` (p7zip) ou `py7zr`.

## Structure

```
web/        lanceur et page d'émulation (publiés dans webgames/)
tools/      build-sd.sh (point d'entrée), build-apps.sh + apps.d/ (apps GitHub),
            fetch-vendor.sh + vendor.conf (versions épinglées), gen-catalog.mjs
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
