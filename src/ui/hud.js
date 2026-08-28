/**
 * HUD: Schichtplan (Gäste), Geld/Ruf/Schlange, Aktionsleisten, die grossen
 * Entscheidungs-Buttons unten in der Mitte, Tutorial, Toasts.
 *
 * Bewusst NICHT mehr im HUD: der Tages-Timer (die Schicht endet, wenn die
 * Gästeliste abgearbeitet ist), Belegung des Clubs, Ausbaustufe und die alte
 * Übersichtskarte - das steht jetzt alles auf dem Notizzettel bzw. gar nicht.
 */

import { CLUB_NAME } from '../data/config.js';
import { currentPhase } from '../systems/nightcycle.js';
import { repBand } from '../systems/reputation.js';
import { createNotepad } from './notepad.js';
import { actionIcon } from './icons.js';

const DECISION_CODES = new Set(['admit', 'reject', 'pass']);

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
    queue: document.getElementById('hud-queue'),
    effects: document.getElementById('hud-effects'),
    toasts: document.getElementById('toasts'),
    bar1: document.getElementById('bar-p1'),
    bar2: document.getElementById('bar-p2'),
    decisions: document.getElementById('decisions'),
    tutorial: document.getElementById('tutorial'),
    tutStep: document.getElementById('tut-step'),
    tutTitle: document.getElementById('tut-title'),
    tutBody: document.getElementById('tut-body'),
    tutHint: document.getElementById('tut-hint'),
    net: document.getElementById('netstatus')
  };

  el.club.textContent = CLUB_NAME;
  const notepad = createNotepad(game);

  let builtFor = '';
  let lastToastKey = '';
  let lastTutorial = '';

  // Alle Aktionen sind anklickbar - Tastatur bleibt gleichwertig.
  for (const node of [el.decisions, el.bar1, el.bar2]) {
    node.addEventListener('click', (event) => {
      const btn = event.target.closest('[data-code]');
      if (!btn) return;
      game.act(btn.dataset.role, btn.dataset.code);
    });
  }

  function buildBars() {
    const key = `${game.state.mode}|${game.localRole ?? ''}`;
    if (builtFor === key) return;
    builtFor = key;
    el.bar1.innerHTML = '';
    el.bar2.innerHTML = '';
    el.decisions.innerHTML = '';

    for (const player of game.players) {
      if (!game.controls(player.id)) continue;
      const container = player.area === 'airlock' ? el.bar2 : el.bar1;
      const cls = player.area === 'airlock' ? 'p2' : 'p1';

      // Kontrollen als Icon-Buttons. Die Tastenbelegung steht nicht mehr im
      // Bild - die steht komplett im Pausenmenü.
      for (const action of player.role.actions) {
        if (DECISION_CODES.has(action.code)) continue;
        const btn = document.createElement('button');
        btn.className = `act ${cls}`;
        btn.dataset.code = action.code;
        btn.dataset.role = player.id;
        btn.title = action.label;
        btn.innerHTML =
          `<span class="act-icon">${actionIcon(action.code)}</span>` +
          `<span class="act-name">${action.label}</span>`;
        container.appendChild(btn);
      }

      // Entscheidungen wandern in die Mitte - gross und anklickbar.
      const group = document.createElement('div');
      group.className = `dec-group ${cls}`;
      if (game.players.filter((p) => game.controls(p.id)).length > 1) {
        group.innerHTML = `<span class="dec-role">${player.role.label}</span>`;
      }
      for (const action of player.role.actions) {
        if (!DECISION_CODES.has(action.code)) continue;
        const kind = action.code === 'reject' ? 'no' : 'yes';
        const btn = document.createElement('button');
        btn.className = `dec ${kind}`;
        btn.dataset.code = action.code;
        btn.dataset.role = player.id;
        btn.innerHTML =
          `<span class="dec-icon">${actionIcon(action.code)}</span>` +
          `<span class="dec-label">${action.label}</span>`;
        group.appendChild(btn);
      }
      el.decisions.appendChild(group);
    }
  }

  function update() {
    const state = game.state;
    const night = state.night;
    buildBars();

    el.money.textContent = `€${Math.round(state.money).toLocaleString('de-DE')}`;
    el.rep.textContent = Math.round(state.reputation);
    el.repbar.style.width = `${state.reputation}%`;
    el.repbar.style.background = state.reputation > 66 ? 'var(--green)'
      : state.reputation > 33 ? 'var(--cyan)' : 'var(--red)';

    if (!night) return;

    // Kein Timer mehr: die Schicht misst sich in Gästen, nicht in Minuten.
    const quota = night.quota ?? 0;
    const done = Math.min(night.processed ?? 0, quota);
    el.clock.textContent = `${done}/${quota}`;
    const phase = currentPhase(quota ? done / quota : 0);
    el.phase.textContent = `${phase.label} · ${repBand(state.reputation)}`;
    el.status.textContent =
      `NIGHT ${String(state.nightIndex).padStart(2, '0')} · ${night.event?.label ?? ''}`;
    el.nightbar.style.width = `${quota ? (done / quota) * 100 : 0}%`;
    el.queue.textContent = `${night.queueLength ?? night.queue.length}`;

    el.effects.innerHTML = (night.activeEffects ?? [])
      .map((e) => `<div class="effect-row"><span>${escapeHtml(e.label)}</span><span>${Math.ceil(e.remaining)}s</span></div>`)
      .join('');

    const toasts = night.toasts ?? [];
    const toastKey = toasts.map((t) => t.text).join('|');
    if (toastKey !== lastToastKey) {
      lastToastKey = toastKey;
      el.toasts.innerHTML = toasts.map((t) => `<div class="toast ${t.kind}">${escapeHtml(t.text)}</div>`).join('');
    }

    updateTutorialPanel(game, el, () => lastTutorial, (v) => { lastTutorial = v; });
    notepad.update();
    updateActionBars(game, el);
    updateDecisions(game, el);
  }

  function show() { el.root.classList.remove('hidden'); }
  function hide() { el.root.classList.add('hidden'); }

  function setNet(text, bad = false) {
    if (!text) return el.net.classList.add('hidden');
    el.net.textContent = text;
    el.net.classList.toggle('bad', bad);
    el.net.classList.remove('hidden');
  }

  return { update, show, hide, setNet, el, rebuild: () => { builtFor = ''; } };
}

function updateTutorialPanel(game, el, getLast, setLast) {
  const step = game.state.night?.tutorial?.step;
  if (!step) {
    el.tutorial.classList.add('hidden');
    setLast('');
    return;
  }
  const key = `${step.id}|${step.title}`;
  if (getLast() === key) return;
  setLast(key);
  el.tutorial.classList.remove('hidden');
  el.tutStep.textContent = `TUTORIAL · SCHRITT ${step.index + 1}/${step.total}`;
  el.tutTitle.textContent = step.title;
  el.tutBody.textContent = step.body;
  if (step.hint) {
    el.tutHint.classList.remove('hidden');
    el.tutHint.innerHTML = `TASTE <kbd>${escapeHtml(step.hint[0])}</kbd> — ${escapeHtml(step.hint[1])}`;
  } else {
    el.tutHint.classList.add('hidden');
  }
}

function updateActionBars(game, el) {
  if (!game.state.night) return;

  for (const node of el.root.querySelectorAll('.act')) {
    const code = node.dataset.code;
    const player = game.players.find((p) => p.id === node.dataset.role);
    if (!player) continue;
    const station = game.stationFor(node.dataset.role);
    const checks = station?.checks;
    const hasGuest = !!station?.guest;

    const done = checks && (
      (code === 'id' && checks.id) ||
      (code === 'alcohol' && checks.alcohol) ||
      (code === 'search' && station.patdown?.complete)
    );
    // Waehrend eines Uebergriffs ist alles gesperrt - es zaehlt nur die Abwehr.
    const attacked = !!station?.aggro;
    const locked = game.state.unlocks[code] === false || attacked;
    node.classList.toggle('locked', !!locked);
    node.classList.toggle('done', !!done);
    node.classList.toggle('ready', hasGuest && !done && !locked);
    node.classList.toggle('active', player.busy > 0 && isFor(player, code));
  }
}

function updateDecisions(game, el) {
  for (const btn of el.decisions.querySelectorAll('.dec')) {
    const station = game.stationFor(btn.dataset.role);
    const guest = station?.guest;
    const open = !!station?.patdown?.active;
    btn.classList.toggle('disabled', !guest || open || !!station?.aggro);
  }
}

function isFor(player, code) {
  const key = player.pending?.key;
  if (!key) return false;
  if (code === 'search') return key === 'search' || key === 'bag';
  return key === code;
}

export function keyLabel(code) {
  if (code.startsWith('Digit')) return code.slice(5);
  if (code.startsWith('Key')) return code.slice(3);
  return {
    ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→',
    Enter: 'ENTER', Backspace: 'BACK', Space: 'LEER'
  }[code] ?? code;
}

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
