// Lanceur WebGames : lit les catalogues JSON, affiche des tuiles. Aucune dépendance.
(() => {
  'use strict';

  const view = document.getElementById('view');
  const search = document.getElementById('search');
  const state = { arcade: [], systems: {}, roms: {} };

  const getJSON = async (url, fallback) => {
    try {
      const r = await fetch(url);
      if (!r.ok) throw new Error(r.status);
      return await r.json();
    } catch {
      return fallback;
    }
  };

  // Crée un élément sans passer par innerHTML : les noms de fichiers sont non fiables.
  const el = (tag, attrs = {}, ...children) => {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === 'class') node.className = v;
      else node.setAttribute(k, v);
    }
    node.append(...children);
    return node;
  };

  const norm = (s) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const matches = (q, ...fields) => !q || fields.some((f) => norm(String(f ?? '')).includes(q));

  const formatSize = (n) => (n >= 1048576 ? `${(n / 1048576).toFixed(1)} Mo` : `${Math.max(1, Math.round(n / 1024))} Ko`);

  function renderArcade(q) {
    const games = state.arcade.filter((g) => matches(q, g.name, g.desc, g.category, ...g.tags));
    if (!games.length) return el('p', { class: 'empty' }, 'Aucun jeu trouvé.');
    const grid = el('div', { class: 'grid' });
    for (const g of games) {
      grid.append(
        el('a', { class: 'tile', href: `arcade/games/${encodeURIComponent(g.file)}` },
          el('span', { class: 'emoji', 'aria-hidden': 'true' }, g.emoji || '🎮'),
          el('strong', {}, g.name),
          el('small', {}, g.desc || ''))
      );
    }
    return grid;
  }

  function renderEmulators(q) {
    const wrap = el('div');
    let total = 0;
    for (const [id, sys] of Object.entries(state.systems)) {
      const roms = (state.roms[id] || []).filter((r) => matches(q, r.name, sys.label));
      if (!roms.length) continue;
      total += roms.length;
      const list = el('ul', { class: 'roms' });
      for (const r of roms) {
        const params = new URLSearchParams({
          core: sys.cores[0],
          rom: `roms/${id}/${r.file}`,
          name: r.name,
        });
        list.append(el('li', {},
          el('a', { href: `play.html?${params}` }, r.name),
          el('small', {}, formatSize(r.size))));
      }
      wrap.append(el('section', {}, el('h2', {}, `${sys.emoji} ${sys.label}`), list));
    }
    if (!total) {
      return el('div', { class: 'empty' },
        el('p', {}, 'Aucune ROM trouvée.'),
        el('p', {}, 'Copie tes ROMs dans roms/<système>/ sur la carte SD (ex. roms/nes/jeu.nes), '
          + 'puis régénère roms.json avec tools/gen-catalog.mjs.'));
    }
    return wrap;
  }

  function render() {
    const tab = location.hash === '#emulateurs' ? 'emulateurs' : 'arcade';
    for (const id of ['arcade', 'emulateurs']) {
      document.getElementById(`tab-${id}`).setAttribute('aria-selected', String(id === tab));
    }
    const q = norm(search.value.trim());
    view.replaceChildren(tab === 'arcade' ? renderArcade(q) : renderEmulators(q));
  }

  async function init() {
    [state.arcade, state.systems, state.roms] = await Promise.all([
      getJSON('catalog/arcade.json', []),
      getJSON('data/systems.json', {}),
      getJSON('roms.json', {}),
    ]);
    search.addEventListener('input', render);
    window.addEventListener('hashchange', render);
    render();
  }

  init();
})();
