/** HUD: Uhr, Club-Status, Geld/Ruf/Schlange, Aktionsleisten, Funk, Tutorial, Toasts. */

import { CLUB_NAME, TUNING, AREAS } from '../data/config.js';
import { clubTier, isSolo } from '../systems/state.js';
import { clockString, currentPhase } from '../systems/nightcycle.js';
import { repBand } from '../systems/reputation.js';
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
    queue: document.getElementById('hud-queue'),
    effects: document.getElementById('hud-effects'),
    radio: document.getElementById('hud-radio'),
    radioPanel: document.getElementById('radio-panel'),
    dossier: document.getElementById('dossier-body'),
    dossierTitle: document.getElementById('dossier-title'),
    toasts: document.getElementById('toasts'),
    bar1: document.getElementById('bar-p1'),
    bar2: document.getElementById('bar-p2'),
    coop: document.getElementById('coop-status'),
    tutorial: document.getElementById('tutorial'),
    tutStep: document.getElementById('tut-step'),
    tutTitle: document.getElementById('tut-title'),
    tutBody: document.getElementById('tut-body'),
    tutHint: document.getElementById('tut-hint'),
    net: document.getElementById('netstatus'),
    hint: document.getElementById('hint')
  };

  el.club.textContent = CLUB_NAME;

  let builtFor = '';
  let lastRadioKey = '';
  let lastToastKey = '';
  let lastTutorial = '';

  function buildBars() {
    const key = `${game.state.mode}|${game.localRole ?? ''}`;
    if (builtFor === key) return;
    builtFor = key;
    el.bar1.innerHTML = '';
    el.bar2.innerHTML = '';

    for (const player of game.players) {
      const own = game.controls(player.id);
      const container = player.area === 'airlock' ? el.bar2 : el.bar1;
      const cls = player.area === 'airlock' ? 'p2' : 'p1';
      const tag = document.createElement('div');
      tag.className = `role-tag ${cls}`;
      tag.innerHTML = `${player.role.label}<small>${areaLabel(player.area)}${own ? '' : ' · PARTNER'}</small>`;
      container.appendChild(tag);
      if (!own) continue;

      for (const action of player.role.actions) {
        const div = document.createElement('div');
        div.className = `act ${cls}`;
        div.dataset.code = action.code;
        div.dataset.role = player.id;
        div.innerHTML = `<span class="key">${keyLabel(action.key)}</span><span class="name">${action.label}</span>`;
        container.appendChild(div);
      }
    }
    el.hint.innerHTML = hintLine(game);
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

    el.clock.textContent = clockString(night.clock);
    const phase = currentPhase(night.clock);
    el.phase.textContent = `${phase.label} · ${repBand(state.reputation)}`;
    el.status.textContent =
      `NIGHT ${String(state.nightIndex).padStart(2, '0')} · ${night.event?.label ?? ''} · ${clubTier(state).label}`;
    el.nightbar.style.width = `${(night.clock / TUNING.nightEndMinute) * 100}%`;
    el.queue.textContent = `${night.queueLength ?? night.queue.length}`;

    el.effects.innerHTML = (night.activeEffects ?? [])
      .map((e) => `<div class="effect-row"><span>${escapeHtml(e.label)}</span><span>${Math.ceil(e.remaining)}s</span></div>`)
      .join('');

    const radio = night.radio ?? [];
    const radioKey = radio.map((r) => r.speaker + r.text).join('|');
    if (radioKey !== lastRadioKey) {
      lastRadioKey = radioKey;
      el.radio.innerHTML = radio.map((r) => `<li><b>${escapeHtml(r.speaker)}</b> ${escapeHtml(r.text)}</li>`).join('');
      el.radioPanel.classList.toggle('hidden', radio.length === 0);
    }

    const toasts = night.toasts ?? [];
    const toastKey = toasts.map((t) => t.text).join('|');
    if (toastKey !== lastToastKey) {
      lastToastKey = toastKey;
      el.toasts.innerHTML = toasts.map((t) => `<div class="toast ${t.kind}">${escapeHtml(t.text)}</div>`).join('');
    }

    updateTutorialPanel(game, el, () => lastTutorial, (v) => { lastTutorial = v; });
    renderDossier(el.dossier, el.dossierTitle, game);
    updateActionBars(game, el);
    updateCoop(game, el);
  }

  function show() { el.root.classList.remove('hidden'); el.hint.classList.remove('hidden'); }
  function hide() { el.root.classList.add('hidden'); el.hint.classList.add('hidden'); }

  function setNet(text, bad = false) {
    if (!text) return el.net.classList.add('hidden');
    el.net.textContent = text;
    el.net.classList.toggle('bad', bad);
    el.net.classList.remove('hidden');
  }

  return { update, show, hide, setNet, el, rebuild: () => { builtFor = ''; } };
}

function areaLabel(area) {
  return area === 'airlock' ? AREAS.airlock.sub : AREAS.outside.sub;
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
  const night = game.state.night;
  if (!night) return;

  for (const node of el.root.querySelectorAll('.act')) {
    const code = node.dataset.code;
    const roleId = node.dataset.role;
    const player = game.players.find((p) => p.id === roleId);
    if (!player) continue;
    const station = game.stationFor(roleId);
    const checks = station?.checks;
    const hasGuest = !!station?.guest;

    const done = checks && (
      (code === 'id' && checks.id) ||
      (code === 'scan' && checks.scan) ||
      (code === 'alcohol' && checks.alcohol) ||
      (code === 'search' && station.patdown?.complete)
    );
    const locked = game.state.unlocks[code] === false;
    node.classList.toggle('locked', !!locked);
    node.classList.toggle('done', !!done);
    node.classList.toggle('ready', hasGuest && !done && !locked);
    node.classList.toggle('active', player.busy > 0 && player.busyLabel && isFor(player, code));
  }
}

function isFor(player, code) {
  const key = player.pending?.key;
  if (!key) return player.busyLabel?.toLowerCase().includes(code);
  if (code === 'pass') return key === 'admit';
  if (code === 'search') return key === 'search';
  return key === code;
}

function updateCoop(game, el) {
  const night = game.state.night;
  if (!night) return;
  const station = game.stationFor(game.dossierRole ?? game.players[0].id);
  const checks = station?.checks;
  el.coop.classList.remove('verified', 'conflict');

  if (checks?.verified) {
    el.coop.textContent = 'SECURITY VERIFIED';
    el.coop.classList.add('verified');
  } else if (checks?.conflict) {
    el.coop.textContent = 'CHECK AGAIN';
    el.coop.classList.add('conflict');
  } else if (isSolo(game.state)) {
    el.coop.textContent = station?.guest ? 'AUSWEIS + SCAN = VERIFIED' : 'TÜR FREI';
  } else {
    const waiting = night.airlockQueue?.length ?? 0;
    el.coop.textContent = `SCHLEUSE: ${waiting} WARTEN`;
  }
}

function hintLine(game) {
  const parts = [];
  for (const player of game.players) {
    if (!game.controls(player.id)) continue;
    const keys = player.role.actions.map((a) => `${keyLabel(a.key)} ${a.label}`).join(' · ');
    parts.push(`<span><b>${player.role.label}</b> ${keys}</span>`);
  }
  parts.push('<span><b>SYSTEM</b> ESC PAUSE · M TON · H HILFE</span>');
  return parts.join('');
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
