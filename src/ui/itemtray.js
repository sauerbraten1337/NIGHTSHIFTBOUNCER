/**
 * Der Kontrolltisch: alles, was aus einer Zone kommt, liegt gross vor dir.
 * Kaugummi neben Klinge - du markierst selbst, was nicht reindarf (nochmal
 * klicken nimmt die Markierung zurueck) und schliesst die Zone dann ab.
 * Ob deine Auswahl stimmt, sagt dir hier niemand.
 */

import { escapeHtml } from './hud.js';
import { drawItemIcon } from '../render/items.js';
import { isSolo } from '../systems/state.js';

export function createItemTray(game, { root, roleId = 'security' } = {}) {
  const el = root ?? document.getElementById('itemtray');
  const api = { el, roleId };
  let renderedKey = '';

  el.addEventListener('click', (event) => {
    const card = event.target.closest('[data-item]');
    const clear = event.target.closest('[data-clear]');
    const station = game.stationFor(api.roleId);
    const zoneId = station?.patdown?.active;
    if (!zoneId) return;
    if (card) game.act(api.roleId, 'pick', { zone: zoneId, itemId: card.dataset.item });
    else if (clear) game.act(api.roleId, 'closezone', { zone: zoneId });
  });

  function update() {
    const station = game.stationFor(api.roleId);
    const pat = station?.patdown;
    const zoneId = pat?.active;
    const zone = zoneId ? pat.zones[zoneId] : null;

    if (!zone || zone.state !== 'open') {
      if (renderedKey) {
        el.classList.add('hidden');
        el.innerHTML = '';
        renderedKey = '';
      }
      return;
    }

    const flagged = zone.flagged ?? [];
    const key = `${station.guest?.id}|${zoneId}|${zone.items.length}|${flagged.join(',')}`;
    if (key === renderedKey) return;
    renderedKey = key;

    el.classList.remove('hidden');
    el.innerHTML = `
      <div class="tray-head">
        <span class="tray-title">${escapeHtml(zone.label)} — INHALT</span>
        <span class="tray-hint">Markiere selbst, was nicht in den Club darf.</span>
      </div>
      <div class="tray-items">
        ${zone.items.map((item, i) => card(item, i, isSolo(game.state), flagged.includes(item.id))).join('')}
      </div>
      <button class="tray-clear" data-clear="1">
        ${isSolo(game.state) ? '<kbd>0</kbd> ' : ''}${flagged.length
          ? `ZONE ABSCHLIESSEN — ${flagged.length} BEANSTANDET`
          : 'ZONE ABSCHLIESSEN — NICHTS BEANSTANDET'}
      </button>
    `;
    paintIcons(el, zone.items);
  }

  api.update = update;
  return api;
}

function card(item, index, showKeys, flagged) {
  return `
    <button class="tray-item ${flagged ? 'flagged' : ''}" data-item="${escapeHtml(item.id)}" title="${escapeHtml(item.label)}">
      <canvas width="96" height="96"></canvas>
      <span class="tray-label">${escapeHtml(item.label)}</span>
      ${flagged ? '<span class="tray-flag">BEANSTANDET</span>' : ''}
      ${showKeys && index < 9 ? `<span class="tray-key">${index + 1}</span>` : ''}
    </button>`;
}

function paintIcons(el, items) {
  el.querySelectorAll('.tray-item canvas').forEach((canvas, index) => {
    const item = items[index];
    if (!item) return;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawItemIcon(ctx, item.id, canvas.width);
  });
}
