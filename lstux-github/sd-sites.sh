#!/bin/sh
# Prepare le contenu web d'une carte SD pour sd-server (ESP32-C6) : clone, build et copie les sites GitHub
# de sites.d/*.json dans <dossier>/<nom>/, et genere la page d'accueil <dossier>/index.html.
# A lancer sur le PC, avec la carte montee (FAT32). Depots publics uniquement. Remplace github-pages.sh
# (publication par sous-domaine + liens symboliques) et gen-index.sh (page d'accueil).
#
# Usage : sd-sites.sh <dossier-sd> [options] [site ...]
#   --conf DIR     dossier des conf *.json (defaut : sites.d a cote du script)
#   --only a,b     ne (re)construire que ces sites (equivalent a lister les noms apres le dossier)
#   --title TXT    titre de la page d'accueil (defaut : lslinux.org)
#   --no-index     ne pas regenerer index.html
#   --index-only   ne regenerer que index.html (sites deja presents sur la carte)
#   --list         lister les sites presents sur la carte
#   --remove NOM   supprimer un site de la carte (et regenerer la page d'accueil)
#   -h, --help
#
# conf.json (un fichier par site) :
#   repo      (obligatoire) https://github.com/<owner>/<repo>[.git]
#   branch    branche a cloner (defaut : branche par defaut du depot)
#   name      nom du site = dossier sur la carte, servi en /<name>/ ; defaut = nom du depot en minuscules ([a-z0-9-]+)
#   build     liste de commandes (sh -e), lancees dans le clone, dans l'ordre ; le clone est un enfant du dossier
#             de travail (".." est inscriptible). Variables fournies : BASE_PATH (ex. /mathpulse/), SITE_NAME
#   output    dossier a publier, relatif au clone (defaut : "." = le clone)
#   base_path chemin ou le site sera servi (defaut : /<name>/ ; commence et finit par /)
#   keep      liste de chemins (relatifs au site) a conserver quand le site est remplace, s'ils existent sur la
#             carte et ne sont pas produits par le build (ex. ["roms", "roms.json"] : fichiers ajoutes a la main)
#   title, desc, icon (emoji), listed:false   presentation sur la page d'accueil
# Le contenu publie doit avoir un index.html a sa racine.
#
# Differences avec le serveur : la C6 n'a pas de sous-domaines, les sites sont donc servis en /<name>/ (le
# build doit accepter un chemin de base : utiliser $BASE_PATH) ; la carte est en FAT : pas de liens symboliques,
# pas de releases ni de rollback (on remplace le dossier du site, le precedent n'est pas conserve).
# L'administration de la carte (explorateur de fichiers) est sur /admin.

set -eu
umask 022

SELF="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="${SELF}/sites.d"
TITLE="lslinux.org"
RESERVED=" admin "

die() { printf "ERREUR : %s\n" "$*" >&2; exit 1; }
warn() { printf "attention : %s\n" "$*" >&2; }
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

command -v jq >/dev/null 2>&1 || die "jq requis"

MODE=build; DEST=""; ONLY=""; DO_INDEX=1; REMOVE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --conf) [ "$#" -ge 2 ] || die "--conf demande un dossier"; CONF_DIR="$2"; shift 2 ;;
    --only) [ "$#" -ge 2 ] || die "--only demande une liste"; ONLY="${ONLY} $(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
    --title) [ "$#" -ge 2 ] || die "--title demande un texte"; TITLE="$2"; shift 2 ;;
    --no-index) DO_INDEX=0; shift ;;
    --index-only) MODE=index; shift ;;
    --list) MODE=list; shift ;;
    --remove) [ "$#" -ge 2 ] || die "--remove demande un nom"; MODE=remove; REMOVE="$2"; shift 2 ;;
    -*) die "option inconnue : $1 (voir --help)" ;;
    *) if [ -z "${DEST}" ]; then DEST="$1"; else ONLY="${ONLY} $1"; fi; shift ;;
  esac
done

[ -n "${DEST}" ] || { usage >&2; exit 1; }
[ -d "${DEST}" ] || die "dossier introuvable : ${DEST}"
DEST="$(cd "${DEST}" && pwd)"
[ -w "${DEST}" ] || die "dossier non inscriptible : ${DEST}"
[ -d "${CONF_DIR}" ] || die "dossier de conf introuvable : ${CONF_DIR}"

fstype="$(stat -f -c %T "${DEST}" 2>/dev/null || true)"
case "${fstype}" in
  msdos|vfat|fat|exfat|fuseblk|"") ;;
  *) warn "${DEST} est en ${fstype} : la carte du module doit etre en FAT32 (verifie que c'est bien le point de montage de la SD)" ;;
esac

valid_name() {
  case "$1" in ''|-*|*-|*[!a-z0-9-]*) return 1 ;; esac
  [ "${#1}" -le 40 ] || return 1
  case "${RESERVED}" in *" $1 "*) die "nom reserve : $1 (/admin est l'explorateur du module)" ;; esac
}

conf_name() { # conf.json -> nom du site (vide si le JSON est invalide)
  n="$(jq -r '.name // empty' "$1" 2>/dev/null || true)"
  [ -n "${n}" ] || n="$(jq -r '.repo // empty | sub("\\.git$";"") | split("/") | last | ascii_downcase' "$1" 2>/dev/null || true)"
  printf '%s' "${n}"
}

html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# ---------------------------------------------------------------- page d'accueil

gen_index() {
  out="${DEST}/index.html"
  cards=""
  n_cards=0
  for f in "${CONF_DIR}"/*.json; do
    [ -f "${f}" ] || continue
    jq -e . "${f}" >/dev/null 2>&1 || { warn "JSON invalide ignore : ${f}"; continue; }
    name="$(conf_name "${f}")"
    [ -f "${DEST}/${name}/index.html" ] || continue                 # seulement les sites presents sur la carte
    card="$(jq -r --arg n "${name}" '
      select(.listed != false)
      | "<a class=\"card\" href=\"\($n)/\"><span class=\"ico\" aria-hidden=\"true\">\(.icon // "🌐")</span><span class=\"txt\"><b>\(.title // $n | @html)</b><small>\(.desc // "" | @html)</small></span></a>"
    ' "${f}")"
    [ -n "${card}" ] || continue
    cards="${cards}${card}
"
    n_cards=$((n_cards + 1))
  done
  cards="$(printf '%s' "${cards}" | sort)"

  case "${TITLE}" in
    *.*) t_pre="${TITLE%.*}"; t_suf=".${TITLE##*.}" ;;
    *)   t_pre="${TITLE}"; t_suf="" ;;
  esac
  t_pre_h="$(printf '%s' "${t_pre}" | html_escape)"; t_suf_h="$(printf '%s' "${t_suf}" | html_escape)"
  t_all_h="$(printf '%s' "${TITLE}" | html_escape)"

  tmp="${out}.new"
  cat > "${tmp}" <<HTML
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${t_all_h}</title>
<meta name="description" content="Hébergement perso, Linux, électronique, embarqué.">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cellipse cx='16' cy='18' rx='10' ry='12' fill='%231d2433'/%3E%3Cellipse cx='16' cy='21' rx='6' ry='8' fill='%23e8eef7'/%3E%3Cpath d='M12 13l4 4 4-4z' fill='%23ff9f1c'/%3E%3C/svg%3E">
<style>
:root{--bg:#0b1220;--fg:#e8eef7;--mut:#8da2c0;--acc:#ff9f1c;--line:#1c2a44;--card:#111b30}
*{box-sizing:border-box}
html{background:var(--bg);color:var(--fg)}
body{margin:0;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2rem;padding:2rem 1rem;
font:16px/1.4 system-ui,sans-serif;
background:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cg fill='none' stroke='%231c2a44' stroke-width='2'%3E%3Cpath d='M0 40h50l12 12h98M80 0v70l14 14v76M0 120h30l12-12h60'/%3E%3C/g%3E%3Cg fill='%231c2a44'%3E%3Ccircle cx='62' cy='52' r='4'/%3E%3Ccircle cx='94' cy='84' r='4'/%3E%3Ccircle cx='42' cy='108' r='4'/%3E%3C/g%3E%3C/svg%3E") var(--bg)}
header{text-align:center}
svg.tux{width:clamp(110px,26vw,170px);height:auto;filter:drop-shadow(0 0 28px #ff9f1c33)}
.wave{transform-origin:128px 82px;animation:wave 2.2s ease-in-out infinite}
@keyframes wave{0%,100%{transform:rotate(0)}50%{transform:rotate(-16deg)}}
h1{margin:.4rem 0 0;font:600 clamp(1.6rem,5vw,2.4rem)/1.1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.02em}
h1 span{color:var(--acc)}
nav{display:grid;grid-template-columns:repeat(auto-fit,minmax(15rem,1fr));gap:.9rem;width:min(52rem,100%)}
a.card{display:flex;gap:.9rem;align-items:center;padding:.9rem 1.1rem;background:var(--card);border:1px solid var(--line);border-radius:.7rem;color:inherit;text-decoration:none;transition:transform .15s,border-color .15s}
a.card:hover,a.card:focus-visible{transform:translateY(-2px);border-color:var(--acc);outline:none}
.ico{font-size:1.9rem;line-height:1}
.txt{display:flex;flex-direction:column}
.txt b{font-size:1.05rem}
.txt small{color:var(--mut)}
footer{color:var(--mut);font:.8rem ui-monospace,SFMono-Regular,Menlo,monospace}
footer a{color:var(--mut)}
@media (prefers-reduced-motion:reduce){a.card{transition:none}.wave{animation:none}}
</style>
</head>
<body>
<header>
<svg class="tux" viewBox="0 0 160 180" role="img" aria-label="Un pingouin qui salue">
<defs>
<linearGradient id="bd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#34436b"/><stop offset="1" stop-color="#141b2e"/></linearGradient>
<linearGradient id="bl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#cfd9ea"/></linearGradient>
</defs>
<ellipse cx="80" cy="170" rx="44" ry="6" fill="#000" opacity=".28"/>
<ellipse cx="56" cy="162" rx="17" ry="7" fill="#ff9f1c"/>
<ellipse cx="104" cy="162" rx="17" ry="7" fill="#ff9f1c"/>
<ellipse cx="32" cy="104" rx="11" ry="30" transform="rotate(16 32 82)" fill="#2e3c66"/>
<ellipse cx="80" cy="96" rx="50" ry="66" fill="url(#bd)"/>
<ellipse cx="80" cy="120" rx="33" ry="38" fill="url(#bl)"/>
<g class="wave"><ellipse cx="128" cy="104" rx="11" ry="30" transform="rotate(-28 128 82)" fill="#2e3c66"/></g>
<circle cx="49" cy="70" r="7" fill="#ff7a90" opacity=".4"/>
<circle cx="111" cy="70" r="7" fill="#ff7a90" opacity=".4"/>
<circle cx="64" cy="54" r="11" fill="#fff"/><circle cx="96" cy="54" r="11" fill="#fff"/>
<circle cx="66" cy="55" r="5.5" fill="#0b1220"/><circle cx="94" cy="55" r="5.5" fill="#0b1220"/>
<circle cx="68" cy="52" r="2" fill="#fff"/><circle cx="96" cy="52" r="2" fill="#fff"/>
<path d="M68 66Q80 59 92 66Q92 80 80 85Q68 80 68 66Z" fill="#ffb02e"/>
<path d="M71 73Q80 78 89 73" fill="none" stroke="#e07f00" stroke-width="2" stroke-linecap="round"/>
</svg>
<h1>${t_pre_h}<span>${t_suf_h}</span></h1>
</header>
<nav>
${cards}
</nav>
<footer>root@lslng:~# _ &middot; <a href="admin/">admin</a></footer>
</body>
</html>
HTML
  mv -f "${tmp}" "${out}" || die "ecriture de ${out} impossible"
  printf "Page d'accueil : %s (%s site(s))\n" "${out}" "${n_cards}"
}

# ---------------------------------------------------------------- un site

build_site() { # conf.json  (execute dans un sous-shell : die n'arrete que ce site)
  conf="$1"
  jq -e . "${conf}" >/dev/null 2>&1 || die "JSON invalide : ${conf}"
  get() { jq -r --arg k "$1" '.[$k] // empty' "${conf}"; }

  repo="$(get repo)"; branch="$(get branch)"; output="$(get output)"; base="$(get base_path)"
  [ -n "${repo}" ] || die "champ repo obligatoire"
  repo="${repo%.git}"
  printf '%s' "${repo}" | grep -Eq '^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' \
    || die "repo doit etre https://github.com/<owner>/<repo>"
  name="$(conf_name "${conf}")"
  valid_name "${name}" || die "nom de site invalide : '${name}' ([a-z0-9-], pas de tiret en bord)"
  printf '%s\n' "${branch}" | grep -Eq '^[A-Za-z0-9._/-]*$' || die "caracteres interdits dans branch"
  case "${branch}" in *..*|-*) die "branch invalide" ;; esac
  output="${output:-.}"
  case "${output}" in /*|*..*) die "output invalide" ;; esac
  base="${base:-/${name}/}"
  printf '%s' "${base}" | grep -Eq '^/([A-Za-z0-9._-]+/)*$' || die "base_path invalide : '${base}' (doit commencer et finir par /)"

  [ -e "${DEST}/${name}" ] && [ ! -d "${DEST}/${name}" ] && die "${DEST}/${name} existe et n'est pas un dossier : refus"

  work="$(mktemp -d "${TMPDIR:-/tmp}/sd-sites.XXXXXX")"
  trap 'rm -rf "${work}"' EXIT INT TERM
  src="${work}/src"

  # Environnement minimal pour git et le build : pas d'heritage de l'appelant, sauf le PATH (pyenv, nvm...)
  run() { env -i PATH="${PATH}" HOME="${work}" LANG=C.UTF-8 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL=https \
           BASE_PATH="${base}" SITE_NAME="${name}" "$@"; }

  printf "[%s] clone : %s %s\n" "${name}" "${repo}" "${branch:+(${branch})}"
  run git clone -q --depth 1 --single-branch ${branch:+--branch "${branch}"} -c advice.detachedHead=false "${repo}.git" "${src}" \
    || die "git clone impossible"

  jq -r 'if (.build|type)=="array" then .build[] elif (.build|type)=="string" then .build else empty end' "${conf}" > "${work}/build.list"
  while IFS= read -r cmd <&3; do
    printf "[%s] build : %s\n" "${name}" "${cmd}"
    ( cd "${src}" && run timeout 900 sh -ec "${cmd}" </dev/null ) || die "commande de build en echec : ${cmd}"
  done 3< "${work}/build.list"

  root="${src}/${output}"
  [ -d "${root}" ] || die "dossier output absent : ${output}"
  [ -f "${root}/index.html" ] || die "pas d'index.html a la racine de ${output} : rien de publie"

  # Nettoyage : pas de liens (FAT n'en a pas), ni depot git, ni CI dans l'arbre servi
  nl="$(find "${root}" -type l | wc -l)"
  [ "${nl}" -eq 0 ] || { warn "[${name}] ${nl} lien(s) symbolique(s) supprime(s)"; find "${root}" -type l -delete; }
  rm -rf "${root}/.git" "${root}/.github"

  # Compatibilite FAT et limites du module
  bad="$(find "${root}" -name '*[:*?"<>|\\]*' | head -n 5)"
  [ -z "${bad}" ] || die "noms de fichiers impossibles sur FAT (: * ? \" < > | \\) : $(printf '%s' "${bad}" | tr '\n' ' ')"
  dup="$(find "${root}" -type f | tr 'A-Z' 'a-z' | sort | uniq -d | head -n 3)"
  [ -z "${dup}" ] || die "noms identiques a la casse pres (FAT les confond) : $(printf '%s' "${dup}" | tr '\n' ' ')"
  big="$(find "${root}" -type f -size +4194303k | head -n 1)"
  [ -z "${big}" ] || die "fichier de plus de 4 Go (limite FAT32) : ${big}"
  long="$(cd "${root}" && find . -type f | awk -v n="${#name}" 'length($0)+n+3 > 300 {print; exit}')"
  [ -z "${long}" ] || die "chemin trop long pour le module (300 caracteres max) : ${long}"

  need_kb="$(du -sk "${root}" | cut -f1)"
  free_kb="$(df -Pk "${DEST}" | awk 'NR==2 {print $4}')"
  old_kb=0; [ -d "${DEST}/${name}" ] && old_kb="$(du -sk "${DEST}/${name}" | cut -f1)"
  [ "$((free_kb + old_kb))" -gt "$((need_kb + 1024))" ] || die "place insuffisante sur la carte : ${need_kb} Ko a ecrire, $((free_kb + old_kb)) Ko disponibles"

  # Copie dans <nom>.new puis remplacement (un renommage FAT : si la copie echoue, l'ancienne version reste)
  new="${DEST}/${name}.new"
  rm -rf "${new}"
  mkdir -p "${new}" || die "creation de ${new} impossible"
  cp -R "${root}/." "${new}/" || { rm -rf "${new}"; die "copie sur la carte impossible"; }

  # Chemins a conserver (renommage FAT, donc instantane meme pour de gros fichiers)
  jq -r 'if (.keep|type)=="array" then .keep[] elif (.keep|type)=="string" then .keep else empty end' "${conf}" > "${work}/keep.list"
  while IFS= read -r kp <&3; do
    case "${kp}" in ''|/*|*..*|*[!A-Za-z0-9._/-]*) rm -rf "${new}"; die "chemin keep invalide : '${kp}'" ;; esac
    kp="${kp%/}"
    if [ -e "${DEST}/${name}/${kp}" ] && [ ! -e "${new}/${kp}" ]; then
      mkdir -p "${new}/$(dirname "${kp}")"
      mv "${DEST}/${name}/${kp}" "${new}/${kp}" || { rm -rf "${new}"; die "conservation de ${kp} impossible"; }
      printf "[%s] conserve : %s\n" "${name}" "${kp}"
    fi
  done 3< "${work}/keep.list"

  rm -rf "${DEST:?}/${name}"
  mv "${new}" "${DEST}/${name}" || die "remplacement de ${DEST}/${name} impossible"
  printf "[%s] publie : %s  (%s Ko, servi en %s)\n" "${name}" "${DEST}/${name}" "${need_kb}" "${base}"
}

# ---------------------------------------------------------------- actions

case "${MODE}" in
  list)
    for d in "${DEST}"/*/; do
      [ -f "${d}index.html" ] || continue
      printf "%-24s %8s Ko  %s\n" "$(basename "${d}")" "$(du -sk "${d}" | cut -f1)" "$(date -r "${d}index.html" '+%Y-%m-%d %H:%M' 2>/dev/null || true)"
    done
    exit 0 ;;
  remove)
    valid_name "${REMOVE}" || die "nom invalide : ${REMOVE}"
    [ -d "${DEST}/${REMOVE}" ] || die "${REMOVE} n'est pas sur la carte"
    rm -rf "${DEST:?}/${REMOVE}"
    printf "%s supprime de %s\n" "${REMOVE}" "${DEST}"
    gen_index
    sync
    exit 0 ;;
  index)
    gen_index
    sync
    exit 0 ;;
esac

command -v git >/dev/null 2>&1 || die "git requis"

# un seul lancement a la fois par carte
lock="${TMPDIR:-/tmp}/sd-sites.$(printf '%s' "${DEST}" | cksum | cut -d' ' -f1).lock"
exec 9>"${lock}"
flock -n 9 || die "une publication est deja en cours vers ${DEST}"

failed=""; done_n=0
for f in "${CONF_DIR}"/*.json; do
  [ -f "${f}" ] || continue
  if [ -n "${ONLY}" ]; then
    n="$(conf_name "${f}")"
    [ -n "${n}" ] || continue
    case " ${ONLY} " in *" ${n} "*) ;; *) continue ;; esac
  fi
  if ( build_site "${f}" ); then done_n=$((done_n + 1)); else failed="${failed} $(basename "${f}")"; fi
done

if [ -n "${ONLY}" ] && [ "${done_n}" -eq 0 ] && [ -z "${failed}" ]; then die "aucun site ne correspond a :${ONLY}"; fi
[ "${DO_INDEX}" -eq 0 ] || gen_index
sync
printf "%s site(s) publie(s) dans %s\n" "${done_n}" "${DEST}"
if [ -n "${failed}" ]; then printf "ECHEC :%s\n" "${failed}" >&2; exit 1; fi
