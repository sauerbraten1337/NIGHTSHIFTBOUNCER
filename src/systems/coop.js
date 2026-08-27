/**
 * Koop-System: zwei Spieler, zwei Rollen, gemeinsame Tür.
 * Bewegung, Aktions-Timer und die Team-Verifikation laufen hier zusammen.
 */

import { ROLES, PATDOWN_KEYS, TUNING } from '../data/config.js';
import { LAYOUT, WORLD, stationFor, inStation, nearQueue } from '../render/layout.js';
import { actionSpeed, addToast, addRadio } from './state.js';
import { checkId, idSummary } from './identity.js';
import { scanGuest } from './scanner.js';
import { startPatdown, patZone, patdownResult } from './security.js';
import { talkTo, alcoholTest } from './alcohol.js';
import { admitGuest, rejectGuest, coopVerification } from './decision.js';
import { calmQueue } from './queue.js';
import { resolveArtistDecision } from './artists.js';
import { guestLine } from './guests.js';
import { clamp } from '../core/rng.js';

const SPEED = 190;

export function createPlayers() {
  return [makePlayer(ROLES.bouncer, 592, 452), makePlayer(ROLES.security, 726, 452)];
}

function makePlayer(role, x, y) {
  return {
    id: role.id, role, x, y, vx: 0, vy: 0, facing: 1, walkPhase: 0,
    busy: 0, busyTotal: 0, busyLabel: '', pending: null, flash: 0, lastResult: null
  };
}

export function updatePlayers(game, dt, input) {
  const { state } = game;
  const night = state.night;
  if (!night) return;

  for (const p of game.players) {
    // --- Bewegung ---
    const k = p.role.keys;
    let dx = (input.isDown(k.right) ? 1 : 0) - (input.isDown(k.left) ? 1 : 0);
    let dy = (input.isDown(k.down) ? 1 : 0) - (input.isDown(k.up) ? 1 : 0);
    if (p.busy > 0) { dx = 0; dy = 0; }
    const len = Math.hypot(dx, dy) || 1;
    p.vx = (dx / len) * SPEED;
    p.vy = (dy / len) * SPEED;
    p.x = clamp(p.x + p.vx * dt, 40, WORLD.width - 40);
    p.y = clamp(p.y + p.vy * dt, LAYOUT.street.y + 20, WORLD.height - 30);
    if (dx !== 0) p.facing = dx > 0 ? 1 : -1;
    p.walkPhase += (Math.abs(dx) + Math.abs(dy) > 0 ? dt * 10 : dt * 1.4);
    if (p.flash > 0) p.flash -= dt;

    // --- Laufende Aktion ---
    if (p.busy > 0) {
      p.busy -= dt;
      if (p.busy <= 0) {
        p.busy = 0;
        const pending = p.pending;
        p.pending = null;
        p.busyLabel = '';
        if (pending) completeAction(game, p, pending);
      }
      continue;
    }

    // --- Eingaben ---
    for (const action of p.role.actions) {
      if (input.justPressed(action.key)) tryAction(game, p, action.code);
    }
    if (p.role.id === 'security' && night.patdown && !night.patdown.complete) {
      for (const zoneKey of PATDOWN_KEYS) {
        if (input.justPressed(zoneKey.key)) startZone(game, p, zoneKey.zone, zoneKey.label);
      }
    }
  }
}

function duration(state, key) {
  return TUNING.actionTime[key] * actionSpeed(state);
}

function begin(state, player, label, key, payload) {
  const t = duration(state, key);
  player.busy = t;
  player.busyTotal = t;
  player.busyLabel = label;
  player.pending = { key, ...payload };
}

/** Versucht eine Aktion. Gibt einen Fehlergrund zurück, wenn sie nicht geht. */
export function tryAction(game, player, code) {
  const { state, bus } = game;
  const night = state.night;
  const guest = night.door;

  if (code === 'calm') {
    if (!nearQueue(player)) return deny(game, player, 'ZU WEIT VON DER SCHLANGE');
    begin(state, player, 'BERUHIGEN', 'calm', {});
    return null;
  }

  if (!inStation(player)) return deny(game, player, `NICHT AN POSITION (${stationFor(player.role.id).label})`);
  if (!guest) return deny(game, player, 'KEIN GAST AN DER TÜR');

  const checks = night.doorChecks;
  switch (code) {
    case 'id':
      if (checks.id) return deny(game, player, 'AUSWEIS BEREITS GEPRUEFT');
      guest.said = guestLine(game.rng, guest, 'idAsk');
      guest.saidTimer = 3;
      begin(state, player, 'AUSWEIS PRÜFEN', 'id', { guestId: guest.id });
      bus.emit('sfx', 'beep');
      return null;
    case 'talk':
      begin(state, player, 'GESPRÄCH', 'talk', { guestId: guest.id });
      return null;
    case 'admit':
      begin(state, player, 'EINLASSEN', 'admit', { guestId: guest.id });
      return null;
    case 'reject':
      begin(state, player, 'ABWEISEN', 'reject', { guestId: guest.id });
      return null;
    case 'scan':
      if (checks.scan) return deny(game, player, 'BEREITS GESCANNT');
      begin(state, player, 'SCAN', 'scan', { guestId: guest.id });
      bus.emit('sfx', 'scan');
      return null;
    case 'alcohol':
      if (checks.alcohol) return deny(game, player, 'TEST BEREITS GEMACHT');
      begin(state, player, 'ALKOHOLTEST', 'alcohol', { guestId: guest.id });
      bus.emit('sfx', 'beep');
      return null;
    case 'search':
      if (night.patdown && night.patdown.complete) return deny(game, player, 'KONTROLLE ABGESCHLOSSEN');
      if (!night.patdown) {
        night.patdown = startPatdown(state, guest);
        guest.said = guestLine(game.rng, guest, 'search');
        guest.saidTimer = 3;
        bus.emit('sfx', 'radio');
        if (night.patdown.autoResolved) finishPatdown(game, player);
        else addToast(night, 'ABTASTEN: J / K / L', 'info', 3);
      }
      return null;
    default:
      return deny(game, player, 'UNBEKANNTE AKTION');
  }
}

function startZone(game, player, zone, label) {
  const { state } = game;
  const night = state.night;
  if (!inStation(player)) return deny(game, player, 'NICHT AN POSITION');
  if (!night.door || !night.patdown) return null;
  if (night.patdown.zones[zone] !== null) return null;
  begin(state, player, `ABTASTEN: ${label}`, 'search', { zone, guestId: night.door.id });
  return null;
}

function deny(game, player, reason) {
  player.flash = 0.5;
  player.lastResult = { kind: 'deny', text: reason };
  addToast(game.state.night, reason, 'warn', 2);
  game.bus.emit('sfx', 'beep');
  return reason;
}

function completeAction(game, player, pending) {
  const { state, rng, bus } = game;
  const night = state.night;
  const guest = night.door;

  if (pending.key === 'calm') {
    const n = calmQueue(state);
    player.lastResult = { kind: 'ok', text: `${n} GÄSTE BERUHIGT` };
    addToast(night, `SCHLANGE BERUHIGT (${n})`, 'good', 2.5);
    bus.emit('sfx', 'radio');
    return;
  }

  // Gast ist inzwischen weg? Aktion verfaellt.
  if (!guest || guest.id !== pending.guestId) {
    player.lastResult = { kind: 'deny', text: 'GAST NICHT MEHR DA' };
    return;
  }

  const checks = night.doorChecks;
  switch (pending.key) {
    case 'id': {
      const result = checkId(state, guest);
      checks.id = result;
      player.lastResult = { kind: result.ok ? 'ok' : 'bad', text: idSummary(result) };
      addRadio(night, 'BOUNCER', idSummary(result));
      bus.emit('sfx', result.ok ? 'ok' : 'deny');
      checkVerification(game);
      break;
    }
    case 'scan': {
      const result = scanGuest(state, guest);
      checks.scan = result;
      player.lastResult = { kind: result.ok === false ? 'bad' : 'ok', text: result.text };
      addRadio(night, 'SECURITY', result.text);
      bus.emit('sfx', result.offline ? 'deny' : 'scan');
      checkVerification(game);
      break;
    }
    case 'talk': {
      const result = talkTo(rng, state, guest);
      checks.talk = result;
      guest.said = result.line;
      guest.saidTimer = 3.4;
      player.lastResult = { kind: 'info', text: result.hint.toUpperCase() };
      break;
    }
    case 'alcohol': {
      const result = alcoholTest(state, guest);
      checks.alcohol = result;
      player.lastResult = { kind: result.overLimit ? 'bad' : 'ok', text: `${result.promille} - ${result.text}` };
      addRadio(night, 'SECURITY', `Alkoholtest: ${result.promille}`);
      bus.emit('sfx', result.overLimit ? 'deny' : 'ok');
      break;
    }
    case 'search': {
      if (!night.patdown) break;
      patZone(night.patdown, guest, pending.zone);
      const res = patdownResult(night.patdown);
      checks.search = res;
      if (night.patdown.found) {
        player.lastResult = { kind: 'bad', text: res.text };
        addRadio(night, 'SECURITY', res.text);
        addToast(night, res.text, 'bad', 4);
        bus.emit('sfx', 'alarm');
      } else if (night.patdown.complete) {
        player.lastResult = { kind: 'ok', text: 'KEINE AUFFÄLLIGKEITEN' };
        addRadio(night, 'SECURITY', 'Abtasten sauber.');
        bus.emit('sfx', 'ok');
      } else {
        player.lastResult = { kind: 'info', text: res.text };
        bus.emit('sfx', 'beep');
      }
      break;
    }
    case 'admit': {
      const isArtist = guest.isArtist;
      admitGuest(game, guest);
      if (isArtist) resolveArtistDecision(game, guest, true);
      guest.said = guestLine(rng, guest, 'admit');
      guest.saidTimer = 2;
      player.lastResult = { kind: 'ok', text: 'EINGELASSEN' };
      break;
    }
    case 'reject': {
      const isArtist = guest.isArtist;
      rejectGuest(game, guest);
      if (isArtist) resolveArtistDecision(game, guest, false);
      guest.said = guestLine(rng, guest, 'reject');
      guest.saidTimer = 2;
      player.lastResult = { kind: 'bad', text: 'ABGEWIESEN' };
      break;
    }
    default:
      break;
  }
}

function finishPatdown(game, player) {
  const night = game.state.night;
  const res = patdownResult(night.patdown);
  night.doorChecks.search = res;
  player.lastResult = { kind: res.found ? 'bad' : 'ok', text: res.text };
  addToast(night, `METALLDETEKTOR: ${res.text}`, res.found ? 'bad' : 'good', 4);
  game.bus.emit('sfx', res.found ? 'alarm' : 'ok');
}

/** Koop-Spezialsystem: ID-Check + Scan gleichzeitig = SECURITY VERIFIED. */
function checkVerification(game) {
  const night = game.state.night;
  const checks = night.doorChecks;
  if (checks.verifiedPair) return;
  const verify = coopVerification(checks);
  if (verify.state === 'verified') {
    checks.verifiedPair = true;
    addToast(night, 'SECURITY VERIFIED', 'good', 3);
    game.bus.emit('sfx', 'ok');
  } else if (verify.state === 'conflict') {
    checks.verifiedPair = false;
    checks.conflict = true;
    addToast(night, 'CHECK AGAIN - ERGEBNISSE WIDERSPRECHEN SICH', 'warn', 4);
    addRadio(night, 'FUNK', 'Das passt nicht zusammen. Nochmal prüfen.');
    game.bus.emit('sfx', 'alarm');
  }
}
