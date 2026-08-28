/**
 * Büro des Clubleiters - der Tag zwischen zwei Nächten.
 *
 * Drei Stellen sind anklickbar: der Kleiderschrank (Aussehen ändern), der
 * Laptop (Upgrades kaufen) und die Tür (nächste Nacht). Die Felder liegen
 * als Prozentrechtecke genau über dem, was `render/office.js` zeichnet.
 */

import { escapeHtml } from './hud.js';
import { drawOffice, OFFICE_HOTSPOTS, OFFICE_WORLD } from '../render/office.js';
import { clubTier, capacity, rank } from '../systems/state.js';
import { normalizeCharacter } from '../systems/character.js';
import { repBand } from '../systems/reputation.js';

/** opts: { onWardrobe, onLaptop, onDoor } */
export function renderOffice(game, opts = {}) {
  const { state } = game;
  const character = normalizeCharacter(state.character);
  const tier = clubTier(state);

  const wrap = document.createElement('div');
  wrap.className = 'office';
  wrap.innerHTML = `
    <div class="office-scene">
      <canvas id="office-canvas" width="${OFFICE_WORLD.width}" height="${OFFICE_WORLD.height}"></canvas>
      <div class="office-hits" id="office-hits"></div>

      <div class="office-head">
        <div class="office-day">TAG ${String(state.nightIndex + 1).padStart(2, '0')} · BÜRO DES CLUBLEITERS</div>
        <h1 class="office-title">FEIERABEND BIS ZUM ABEND</h1>
        <div class="office-sub">${escapeHtml(character.name)} · ${escapeHtml(rank(state).label)}</div>
      </div>

      <div class="office-stats">
        <div><span class="k">GELD</span><span class="v">€${Math.round(state.money).toLocaleString('de-DE')}</span></div>
        <div><span class="k">RUF</span><span class="v">${Math.round(state.reputation)} · ${repBand(state.reputation)}</span></div>
        <div><span class="k">CLUB</span><span class="v">STUFE ${tier.level} · ${escapeHtml(tier.label)}</span></div>
        <div><span class="k">KAPAZITÄT</span><span class="v">${capacity(state)}</span></div>
      </div>

      <div class="office-hint" id="office-hint">Sieh dich um: Schrank, Laptop, Tür.</div>
    </div>
  `;

  const hits = wrap.querySelector('#office-hits');
  const hint = wrap.querySelector('#office-hint');

  const spots = [
    { id: 'wardrobe', spot: OFFICE_HOTSPOTS.wardrobe, action: opts.onWardrobe,
      hint: 'Kleiderschrank: Aussehen und Name ändern.' },
    { id: 'laptop', spot: OFFICE_HOTSPOTS.laptop, action: opts.onLaptop,
      hint: 'Laptop: Upgrades, Talente und Acts.' },
    { id: 'door', spot: OFFICE_HOTSPOTS.door, action: opts.onDoor,
      hint: 'Tür: raus in die nächste Nacht.' }
  ];

  for (const entry of spots) {
    const btn = document.createElement('button');
    btn.className = `office-hit hit-${entry.id}`;
    btn.dataset.spot = entry.id;
    btn.style.left = `${entry.spot.x * 100}%`;
    btn.style.top = `${entry.spot.y * 100}%`;
    btn.style.width = `${entry.spot.w * 100}%`;
    btn.style.height = `${entry.spot.h * 100}%`;
    btn.innerHTML = `
      <span class="office-tag">
        <b>${escapeHtml(entry.spot.label)}</b>
        <i>${escapeHtml(entry.spot.note)}</i>
      </span>`;
    btn.addEventListener('mouseenter', () => { hint.textContent = entry.hint; });
    btn.addEventListener('focus', () => { hint.textContent = entry.hint; });
    btn.addEventListener('click', () => {
      game.bus?.emit('sfx', entry.id === 'door' ? 'door' : 'ok');
      entry.action?.();
    });
    hits.appendChild(btn);
  }

  /* ---------- Bild ---------- */

  const canvas = wrap.querySelector('#office-canvas');
  const ctx = canvas.getContext('2d');
  let t = 0;
  let last = performance.now();

  function frame(now) {
    if (!canvas.isConnected) return;
    t += Math.min(0.05, (now - last) / 1000);
    last = now;
    drawOffice(ctx, canvas.width, canvas.height, t, character);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  return wrap;
}
