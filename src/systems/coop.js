/**
 * Koop-System: wer darf was, wo.
 *
 * Jeder Spieler steht an seiner eigenen Station:
 *   BOUNCER  - draussen an der Tür (Ausweis, Gespräch, Schlange)
 *   SECURITY - drinnen in der Schleuse (Scan, Abtasten, Alkoholtest)
 * Im Solo-Modus gibt es nur die Tür, und der Bouncer macht alles.
 *
 * Alle Aktionen laufen über `tryAction`, damit lokale Eingaben und
 * Netzwerk-Kommandos denselben Weg nehmen.
 */

import { rolesFor, PATDOWN_KEYS, TUNING, AREA_CHECKS } from '../data/config.js';
import { actionSpeed, addToast, addRadio, isSolo } from './state.js';
import { requestId, markField, inspectionVerdict, idSummary } from './identity.js';
import { scanGuest } from './scanner.js';
import { startPatdown, openZone, pickItem, patdownResult, pendingZones } from './security.js';
import { talkTo, alcoholTest } from './alcohol.js';
import { admitGuest, rejectGuest, passGuest, coopVerification, soloVerification } from './decision.js';
import { calmQueue, airlockFull } from './queue.js';
import { guestLine } from './guests.js';
import { resolveArtistDecision } from './artists.js';

export function createPlayers(mode = 'solo') {
  return rolesFor(mode).map((role, index) => ({
    index,
    id: role.id,
    role,
    area: role.area,
    busy: 0,
    busyTotal: 0,
    busyLabel: '',
    pending: null,
    flash: 0,
    idlePhase: index * 1.7,
    lastResult: null,
    lastResultTime: 0
  }));
}

/** Die Station, an der dieser Spieler arbeitet. */
export function stationOf(game, player) {
  const night = game.state.night;
  if (!night) return null;
  if (isSolo(game.state)) return night.stations.door;
  return player.area === 'airlock' ? night.stations.airlock : night.stations.door;
}

export function playerByRole(game, roleId) {
  return game.players.find((p) => p.id === roleId) ?? game.players[0];
}

export function updatePlayers(game, dt, input) {
  const night = game.state.night;
  if (!night) return;

  for (const player of game.players) {
    player.idlePhase += dt;
    if (player.flash > 0) player.flash -= dt;

    if (player.busy > 0) {
      player.busy -= dt;
      if (player.busy <= 0) {
        player.busy = 0;
        const pending = player.pending;
        player.pending = null;
        player.busyLabel = '';
        if (pending) completeAction(game, player, pending);
      }
      continue;
    }

    if (!input || player.remote) continue;

    for (const action of player.role.actions) {
      if (input.justPressed(action.key)) tryAction(game, player, action.code);
    }
    // Abtast-Zonen: nur Zonen, die dieser Gast überhaupt hat.
    const station = stationOf(game, player);
    const pat = station?.patdown;
    if (pat && !pat.complete && canDo(game, player, 'search')) {
      for (const zoneKey of PATDOWN_KEYS) {
        if (!pat.zones[zoneKey.zone]) continue;
        if (input.justPressed(zoneKey.key)) {
          tryAction(game, player, 'zone', { zone: zoneKey.zone, label: zoneKey.label });
        }
      }
      // Solo: Ziffern greifen direkt in die offene Zone (kein Konflikt, weil
      // gerade nichts anderes ansteht). Im Koop läuft die Auswahl per Maus.
      const open = pat.active ? pat.zones[pat.active] : null;
      if (open && isSolo(game.state)) {
        if (input.justPressed('Digit0')) tryAction(game, player, 'pick', { zone: open.id, itemId: null });
        (open.items ?? []).forEach((item, index) => {
          if (index < 9 && input.justPressed(`Digit${index + 1}`)) {
            tryAction(game, player, 'pick', { zone: open.id, itemId: item.id });
          }
        });
      }
    }
  }
}

/** Darf dieser Spieler diese Kontrolle überhaupt ausführen? */
export function canDo(game, player, code) {
  if (isSolo(game.state)) return true;
  const area = player.area;
  if (code === 'id' || code === 'talk' || code === 'calm' || code === 'pass') return area === 'outside';
  if (AREA_CHECKS.airlock.includes(code) || code === 'admit') return area === 'airlock';
  return true; // reject dürfen beide
}

function duration(state, key) {
  return (TUNING.actionTime[key] ?? 1) * actionSpeed(state);
}

function begin(game, player, label, key, payload = {}) {
  const t = duration(game.state, key);
  player.busy = t;
  player.busyTotal = t;
  player.busyLabel = label;
  player.pending = { key, ...payload };
}

function deny(game, player, reason) {
  player.flash = 0.5;
  setResult(player, 'deny', reason);
  addToast(game.state.night, reason, 'warn', 2.2);
  game.bus.emit('sfx', 'beep');
  return reason;
}

function setResult(player, kind, text) {
  player.lastResult = { kind, text };
  player.lastResultTime = 0;
}

/**
 * Führt eine Aktion aus (oder lehnt sie mit Begründung ab).
 * payload: { zone } für 'zone', { field } für 'mark'.
 */
export function tryAction(game, player, code, payload = {}) {
  const { state } = game;
  const night = state.night;
  if (!night || !night.running) return 'KEINE SCHICHT';
  if (player.busy > 0) return 'BESCHÄFTIGT';

  const station = stationOf(game, player);
  const guest = station?.guest;

  if (code === 'calm') {
    if (!canDo(game, player, 'calm')) return deny(game, player, 'NUR DER BOUNCER KANN DIE SCHLANGE BERUHIGEN');
    if (!state.unlocks.calm) return deny(game, player, 'NOCH NICHT FREIGESCHALTET');
    begin(game, player, 'SCHLANGE BERUHIGEN', 'calm');
    return null;
  }

  if (!canDo(game, player, code)) {
    return deny(game, player, code === 'admit'
      ? 'NUR DIE SECURITY LÄSST IN DEN CLUB'
      : 'NICHT DEIN BEREICH');
  }
  if (!guest) return deny(game, player, 'NIEMAND VOR DIR');
  if (state.unlocks[code] === false) return deny(game, player, 'NOCH NICHT FREIGESCHALTET');

  const checks = station.checks;

  switch (code) {
    case 'id':
      if (checks.id) return deny(game, player, 'AUSWEIS LIEGT SCHON VOR');
      guest.said = guestLine(game.rng, guest, 'idAsk');
      guest.saidTimer = 3.2;
      begin(game, player, 'AUSWEIS VERLANGEN', 'id', { guestId: guest.id });
      game.bus.emit('sfx', 'beep');
      return null;

    case 'mark': {
      if (!checks.id) return deny(game, player, 'ERST DEN AUSWEIS VERLANGEN');
      if (checks.id.guestId !== guest.id) return deny(game, player, 'ANDERER GAST');
      const res = markField(checks.id, guest, payload.field);
      if (res.already) return null;
      if (res.correct) {
        setResult(player, 'ok', `GEFUNDEN: ${res.reason}`);
        addToast(night, `AUFFÄLLIGKEIT: ${res.reason}`, 'good', 3);
        game.bus.emit('sfx', 'ok');
      } else {
        setResult(player, 'deny', `${res.label}: NICHTS ZU BEANSTANDEN`);
        player.flash = 0.4;
        game.bus.emit('sfx', 'beep');
      }
      game.bus.emit('idMark', { field: payload.field, correct: res.correct });
      return null;
    }

    case 'talk':
      begin(game, player, 'ANSPRECHEN', 'talk', { guestId: guest.id });
      return null;

    case 'scan':
      if (checks.scan) return deny(game, player, 'BEREITS GESCANNT');
      begin(game, player, 'SCAN', 'scan', { guestId: guest.id });
      game.bus.emit('sfx', 'scan');
      return null;

    case 'alcohol':
      if (checks.alcohol) return deny(game, player, 'TEST BEREITS GEMACHT');
      begin(game, player, 'ALKOHOLTEST', 'alcohol', { guestId: guest.id });
      game.bus.emit('sfx', 'beep');
      return null;

    case 'search':
      if (station.patdown?.complete) return deny(game, player, 'KONTROLLE ABGESCHLOSSEN');
      if (!station.patdown) {
        station.patdown = startPatdown(state, guest);
        guest.said = guestLine(game.rng, guest, 'search');
        guest.saidTimer = 3;
        game.bus.emit('sfx', 'radio');
        if (station.patdown.autoResolved) finishPatdown(game, player, station);
        else {
          const keys = Object.keys(station.patdown.zones)
            .map((z) => ({ jacket: 'J', pockets: 'K', bag: 'L' }[z])).join(' / ');
          addToast(night, `ZONE WÄHLEN: ${keys}`, 'info', 3.5);
        }
      }
      return null;

    case 'zone': {
      const pat = station.patdown;
      if (!pat || pat.complete) return null;
      const zone = pat.zones[payload.zone];
      if (!zone || zone.state === 'done') return null;
      if (pat.active && pat.active !== payload.zone) {
        return deny(game, player, 'ERST DEN AKTUELLEN INHALT KLÄREN');
      }
      if (zone.state === 'open') return null;
      const label = payload.zone === 'bag' ? 'TASCHE HERVORHOLEN' : `ABTASTEN: ${zone.label}`;
      begin(game, player, label, payload.zone === 'bag' ? 'bag' : 'search',
        { zone: payload.zone, guestId: guest.id });
      game.bus.emit('sfx', 'radio');
      return null;
    }

    case 'pick': {
      const pat = station.patdown;
      const zone = pat?.zones[payload.zone ?? pat?.active];
      if (!pat || !zone || zone.state !== 'open') return null;
      const res = pickItem(pat, guest, zone.id, payload.itemId ?? null);
      if (!res) return null;

      if (res.item && res.correct) {
        setResult(player, 'bad', `GEFUNDEN: ${res.item.label}`);
        addToast(night, `VERBOTEN: ${res.item.label.toUpperCase()}`, 'bad', 4);
        addRadio(night, 'SECURITY', `${res.item.label} sichergestellt.`);
        game.bus.emit('sfx', 'alarm');
      } else if (res.item && !res.correct) {
        setResult(player, 'deny', `${res.item.label}: völlig harmlos`);
        addToast(night, `${res.item.label.toUpperCase()} IST ERLAUBT`, 'warn', 3);
        player.flash = 0.4;
        game.bus.emit('sfx', 'beep');
      } else if (res.missed) {
        setResult(player, 'deny', 'ZONE FREIGEGEBEN - DA WAR ETWAS');
        game.bus.emit('sfx', 'beep');
      } else {
        setResult(player, 'ok', `${zone.label}: sauber`);
        game.bus.emit('sfx', 'ok');
      }

      station.checks.search = patdownResult(pat);
      if (pat.complete) updateVerification(game, guest, station);
      game.bus.emit('itemPicked', res);
      return null;
    }

    case 'pass':
      if (isSolo(state)) return deny(game, player, 'IM SOLO GIBT ES KEINE SCHLEUSE');
      if (airlockFull(state)) return deny(game, player, 'SCHLEUSE IST VOLL');
      begin(game, player, 'DURCHLASSEN', 'admit', { guestId: guest.id, pass: true });
      return null;

    case 'admit':
      begin(game, player, 'EINLASSEN', 'admit', { guestId: guest.id });
      return null;

    case 'reject':
      begin(game, player, 'ABWEISEN', 'reject', { guestId: guest.id });
      return null;

    default:
      return deny(game, player, 'UNBEKANNTE AKTION');
  }
}

function completeAction(game, player, pending) {
  const { state, rng, bus } = game;
  const night = state.night;
  const station = stationOf(game, player);

  if (pending.key === 'calm') {
    const n = calmQueue(state);
    setResult(player, 'ok', `${n} GÄSTE BERUHIGT`);
    addToast(night, `SCHLANGE BERUHIGT (${n})`, 'good', 2.5);
    bus.emit('sfx', 'radio');
    return;
  }

  const guest = station?.guest;
  if (!guest || guest.id !== pending.guestId) {
    setResult(player, 'deny', 'GAST NICHT MEHR DA');
    return;
  }
  const checks = station.checks;

  switch (pending.key) {
    case 'id': {
      checks.id = requestId(state, guest);
      setResult(player, 'info', 'AUSWEIS LIEGT VOR - SELBST PRÜFEN');
      if (checks.id.hint === 'any') addToast(night, 'GERÄT MELDET: DOKUMENT PRÜFEN', 'warn', 3);
      else if (checks.id.hint) {
        addToast(night, `GERÄT MARKIERT: ${checks.id.hint.toUpperCase()}`, 'warn', 3);
      }
      bus.emit('sfx', 'beep');
      break;
    }
    case 'talk': {
      const result = talkTo(rng, state, guest);
      checks.talk = result;
      guest.said = result.line;
      guest.saidTimer = 3.6;
      setResult(player, 'info', `SAGT: "${result.realName}" - ${result.hint}`);
      break;
    }
    case 'scan': {
      const result = scanGuest(state, guest);
      checks.scan = result;
      setResult(player, result.ok === false ? 'bad' : 'ok', result.text);
      addRadio(night, 'SECURITY', result.text);
      bus.emit('sfx', result.offline ? 'deny' : 'scan');
      updateVerification(game, guest, station);
      break;
    }
    case 'alcohol': {
      const result = alcoholTest(state, guest);
      checks.alcohol = result;
      setResult(player, result.overLimit ? 'bad' : 'ok', `${result.promille} ‰ — ${result.text}`);
      addRadio(night, 'SECURITY', `Alkoholtest: ${result.promille} ‰`);
      bus.emit('sfx', result.overLimit ? 'deny' : 'ok');
      break;
    }
    case 'bag':
    case 'search': {
      if (!station.patdown) break;
      const zone = openZone(station.patdown, guest, pending.zone);
      if (!zone) break;
      checks.search = patdownResult(station.patdown);
      setResult(player, 'info', `${zone.label}: ${zone.items.length} GEGENSTÄNDE`);
      if (!station.patdown.hintShown) {
        station.patdown.hintShown = true;
        addToast(night, 'WAS DAVON DARF NICHT REIN?', 'info', 3);
      }
      bus.emit('sfx', 'beep');
      bus.emit('zoneOpened', { zone: zone.id, items: zone.items });
      break;
    }
    case 'admit': {
      if (pending.pass) {
        passGuest(game, guest, station);
        setResult(player, 'ok', 'DURCHGELASSEN');
        guest.said = guestLine(rng, guest, 'admit');
        guest.saidTimer = 2;
      } else {
        const isArtist = guest.isArtist;
        admitGuest(game, guest, station);
        if (isArtist) resolveArtistDecision(game, guest, true);
        setResult(player, 'ok', 'EINGELASSEN');
      }
      bus.emit('decision', { outcome: pending.pass ? 'pass' : 'admit', guest });
      break;
    }
    case 'reject': {
      const isArtist = guest.isArtist;
      rejectGuest(game, guest, station);
      if (isArtist) resolveArtistDecision(game, guest, false);
      setResult(player, 'bad', 'ABGEWIESEN');
      bus.emit('decision', { outcome: 'reject', guest });
      break;
    }
    default:
      break;
  }
}

function finishPatdown(game, player, station) {
  const res = patdownResult(station.patdown);
  station.checks.search = res;
  setResult(player, res.found ? 'bad' : 'ok', res.text);
  addToast(game.state.night, `METALLDETEKTOR: ${res.text}`, res.found ? 'bad' : 'good', 4);
  game.bus.emit('sfx', res.found ? 'alarm' : 'ok');
}

/** SECURITY VERIFIED / CHECK AGAIN auswerten. */
function updateVerification(game, guest, station) {
  const night = game.state.night;
  const checks = station.checks;
  const verify = isSolo(game.state)
    ? soloVerification(checks)
    : coopVerification(guest, checks);

  if (verify.state === 'verified' && !checks.verified) {
    checks.verified = true;
    addToast(night, 'SECURITY VERIFIED', 'good', 3);
    game.bus.emit('sfx', 'ok');
  } else if (verify.state === 'conflict' && !checks.conflict) {
    checks.conflict = true;
    addToast(night, 'CHECK AGAIN — BEFUNDE WIDERSPRECHEN SICH', 'warn', 4);
    addRadio(night, 'FUNK', 'Das passt nicht zusammen. Nochmal prüfen.');
    game.bus.emit('sfx', 'alarm');
  }
}

export { idSummary, inspectionVerdict };
