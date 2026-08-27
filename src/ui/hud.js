/** HUD: Uhrzeit, Club-Status, Geld/Ruf/Kapazität, Aktionsleiste, Funk, Toasts. */

import { CLUB_NAME, TUNING } from '../data/config.js';
import { capacity, clubTier, queueCapacity } from '../systems/state.js';
import { clockString, currentPhase } from '../systems/nightcycle.js';
import { queueMood } from '../systems/queue.js';
import { repBand } from '../systems/reputation.js';
import { coopVerification } from '../systems/decision.js';
import { renderDossier } from './panels.js';

export function createHud(game) {
  const el = {
    root: document.getElementById('hud'),
    clock: document.getElementById('hud-clock'),
    phase: document.getElementById('hud-phase'),
    club: document.getElementById('hud-club'),
    status: document.getElementById('hud-status'),
    nightbar: document.getElementById('hud-nightbar'),
    money: document.getElementById('hud-money'),
    rep: document.getElementById('hud-rep'),
    repbar: document.getElementById('hud-repbar'),
    cap: document.getElementById('hud-cap'),
    queue: document.getElementById('hud-queue'),
    moodbar: document.getElementById('hud-moodbar'),
    mood: document.getElementById('hud-mood'),
    effects: document.getElementById('hud-effects'),
    radio: document.getElementById('hud-radio'),
    dossier: document.getElementById('dossier-body'),
    toasts: document.getElementById('toasts'),
    bar1: document.getElementById('bar-p1'),
    bar2: document.getElementById('bar-p2'),
    coop: document.getElementById('coop-status')
  };

  el.club.textContent = CLUB_NAME;
  buildActionBar(el.bar1, game.players[0], 'p1');
  buildActionBar(el.bar2, game.players[1], 'p2');
  el.bar2.classList.add('p2');

  let lastRadioKey = '';
  let lastToastKey = '';

  function update() {
    const state = game.state;
    const night = state.night;

    el.money.textContent = `€${Math.round(state.money).toLocaleString('de-DE')}`;
    el.rep.textContent = Math.round(state.reputation);
    el.repbar.style.width = `${state.reputation}%`;
    el.repbar.style.background = state.reputation > 66 ? 'var(--green)'
      : state.reputation > 33 ? 'var(--cyan)' : 'var(--red)';

    if (!night) return;

    el.clock.textContent = clockString(night.clock);
    const phase = currentPhase(night.clock);
    el.phase.textContent = `${phase.label} · ${repBand(state.reputation)}`;
    el.status.textContent =
      `NIGHT ${String(state.nightIndex).padStart(2, '0')} · ${night.event.label} · ${clubTier(state).label}`;
    el.nightbar.style.width = `${(night.clock / TUNING.nightEndMinute) * 100}%`;

    el.cap.textContent = `${night.inside.length}/${capacity(state)}`;
    el.queue.textContent = `${night.queue.length}`;
    const mood = queueMood(night);
    el.moodbar.style.width = `${mood * 100}%`;
    el.moodbar.style.background = mood > 0.6 ? 'var(--green)' : mood > 0.3 ? 'var(--amber)' : 'var(--red)';
    el.mood.textContent = `STIMMUNG ${Math.round(mood * 100)}% · MAX ${queueCapacity(state)}`;

    // Aktive Effekte
    el.effects.innerHTML = night.activeEffects
      .map((e) => `<div class="effect-row"><span>${e.label}</span><span>${Math.ceil(e.remaining)}s</span></div>`)
      .join('');

    // Funk
    const radioKey = night.radio.map((r) => r.speaker + r.text).join('|');
    if (radioKey !== lastRadioKey) {
      lastRadioKey = radioKey;
      el.radio.innerHTML = night.radio
        .map((r) => `<li><b>${r.speaker}</b> ${escapeHtml(r.text)}</li>`).join('');
      el.radio.parentElement.classList.toggle('hidden', night.radio.length === 0);
    }

    // Toasts
    const toastKey = night.toasts.map((t) => t.text).join('|');
    if (toastKey !== lastToastKey) {
      lastToastKey = toastKey;
      el.toasts.innerHTML = night.toasts
        .map((t) => `<div class="toast ${t.kind}">${escapeHtml(t.text)}</div>`).join('');
    }

    renderDossier(el.dossier, game);
    updateActionBars(game, el);
    updateCoop(game, el);
  }

  function show() { el.root.classList.remove('hidden'); }
  function hide() { el.root.classList.add('hidden'); }

  return { update, show, hide, el };
}

function buildActionBar(container, player, cls) {
  container.innerHTML = '';
  const tag = document.createElement('div');
  tag.className = `role-tag ${cls}`;
  tag.textContent = player.role.label;
  container.appendChild(tag);

  for (const action of player.role.actions) {
    const div = document.createElement('div');
    div.className = `act ${cls}`;
    div.dataset.code = action.code;
    div.innerHTML =
      `<span class="key">${keyLabel(action.key)}</span><span class="name">${action.label}</span>`;
    container.appendChild(div);
  }
}

function updateActionBars(game, el) {
  const night = game.state.night;
  const checks = night?.doorChecks;
  const hasGuest = !!night?.door;

  game.players.forEach((player, i) => {
    const container = i === 0 ? el.bar1 : el.bar2;
    const nodes = container.querySelectorAll('.act');
    nodes.forEach((node) => {
      const code = node.dataset.code;
      const done = checks && (
        (code === 'id' && checks.id) ||
        (code === 'scan' && checks.scan) ||
        (code === 'alcohol' && checks.alcohol) ||
        (code === 'search' && night.patdown?.complete)
      );
      node.classList.toggle('done', !!done);
      node.classList.toggle('ready', hasGuest && !done);
      node.classList.toggle('active', player.pending?.key === code && player.busy > 0);
    });
  });
}

function updateCoop(game, el) {
  const night = game.state.night;
  if (!night) return;
  const verify = coopVerification(night.doorChecks);
  el.coop.classList.remove('verified', 'conflict');
  if (verify.state === 'verified') {
    el.coop.textContent = 'SECURITY VERIFIED';
    el.coop.classList.add('verified');
  } else if (verify.state === 'conflict') {
    el.coop.textContent = 'CHECK AGAIN';
    el.coop.classList.add('conflict');
  } else if (night.door) {
    el.coop.textContent = 'ID + SCAN FÜR VERIFIKATION';
  } else {
    el.coop.textContent = 'TEAM BEREIT';
  }
}

export function keyLabel(code) {
  if (code.startsWith('Digit')) return code.slice(5);
  if (code.startsWith('Key')) return code.slice(3);
  return { ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' }[code] ?? code;
}

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
