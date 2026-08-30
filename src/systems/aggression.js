/**
 * Übergriffe an der Tür.
 *
 * Selten - aber es passiert: ein Gast lässt sich das Abweisen nicht gefallen,
 * kommt auf den Türsteher zu und man hat wenige Sekunden Zeit. Auf dem
 * Bildschirm erscheinen nacheinander Tasten; wer sie schnell genug trifft,
 * wehrt den Gast ab. Wer zu langsam ist oder danebengreift, kassiert.
 *
 * Bewusst ohne Gewaltdarstellung: es geht um Reaktion und Abstand halten,
 * nicht um Schlagabtausch. Das Modul ist DOM-frei - Anzeige macht der
 * Renderer, Eingaben kommen über `defend()` (lokal wie über das Netz).
 */

import { AGGRESSION, DEFENSE_KEYS, FEATURES } from '../data/config.js';
import { addToast, pushLog, isSolo } from './state.js';
import { changeReputation } from './reputation.js';
import { fine, earn } from './economy.js';
import { difficultyProfile } from './difficulty.js';
import { rejectGuest } from './decision.js';
import { chance, randInt, pick, clamp } from '../core/rng.js';
import { cheats } from './admin.js';

/** Läuft an dieser Station gerade ein Angriff? */
export function aggressionActive(station) {
  const a = station?.aggro;
  return !!a && a.phase !== 'over';
}

/** Kann in dieser Nacht überhaupt jemand ausrasten? */
export function aggressionPossible(state) {
  if (!FEATURES.aggression) return false;
  // Admin-Testhilfe: niemand rastet mehr von selbst aus.
  if (cheats.unlocked && cheats.noAggro) return false;
  const night = state.night;
  if (!night || night.tutorial) return false;
  return state.nightIndex >= AGGRESSION.minNight
    && difficultyProfile(state.nightIndex).aggression;
}

/**
 * Wie explosiv ist dieser Gast? 0..1 - fliesst in beide Auslöser ein.
 * Betrunken, unter Einfluss, gereizt und riskant: das summiert sich.
 */
export function aggressionRisk(guest) {
  if (!guest) return 0;
  const t = guest.truth;
  let risk = t.risk * 0.5;
  if (guest.personality === 'aggressive') risk += 0.45;
  else if (guest.personality === 'annoyed') risk += 0.15;
  else if (guest.personality === 'arrogant') risk += 0.1;
  if (t.drunk > 0.6) risk += 0.25;
  if ((t.impaired ?? 0) > 0.5) risk += 0.2;
  if (t.underage) risk += 0.05;
  risk *= 1 - clamp(guest.mood ?? 0.6, 0, 1) * 0.3;
  return clamp(risk, 0, 1);
}

/**
 * Startet einen Angriff, falls der Zufall es will.
 * `cause`: 'reject' (Abweisung) oder 'idle' (rastet während der Kontrolle aus).
 * Gibt true zurück, wenn der Angriff läuft - der Aufrufer muss dann warten.
 */
export function maybeAggression(game, station, cause) {
  const { state, rng } = game;
  const guest = station?.guest;
  if (!guest || aggressionActive(station)) return false;
  if (!aggressionPossible(state)) return false;
  if (guest.tutorial || guest.isArtist) return false;

  const risk = aggressionRisk(guest);
  const p = cause === 'reject'
    ? AGGRESSION.rejectChance * (0.4 + risk * 1.8)
    : AGGRESSION.idleChancePerSecond * risk;
  if (!chance(rng, clamp(p, 0, 0.6))) return false;

  startAggression(game, station, cause);
  return true;
}

/** Baut den Angriff auf: Anlauf, dann die Tastenfolge. */
export function startAggression(game, station, cause = 'reject') {
  const { state, rng } = game;
  const guest = station?.guest;
  const night = state.night;
  if (!guest || !night) return null;

  const count = randInt(rng, AGGRESSION.keys[0], AGGRESSION.keys[1]);
  const keys = [];
  for (let i = 0; i < count; i++) {
    // Nie zweimal dieselbe Taste hintereinander - das liest sich sonst falsch.
    const pool = DEFENSE_KEYS.filter((k) => k.key !== keys[keys.length - 1]?.key);
    keys.push(pick(rng, pool));
  }

  station.aggro = {
    guestId: guest.id,
    cause,
    phase: 'charge',          // charge | defend | win | fail | over
    approach: 0,
    timer: AGGRESSION.chargeTime,
    keys,
    index: 0,
    keyTime: AGGRESSION.keyTime,
    keyLeft: AGGRESSION.keyTime,
    strikes: 0,
    maxStrikes: AGGRESSION.strikes,
    hitFlash: 0,
    missFlash: 0,
    shake: 0
  };

  // Der Gast ist damit objektiv nicht mehr tragbar - das Abweisen ist richtig.
  guest.truth.aggressive = true;
  guest.said = cause === 'reject' ? 'WAS SOLL DAS?!' : 'FASS MICH NICHT AN!';
  guest.saidTimer = 2.2;

  night.stats.attacks = (night.stats.attacks ?? 0) + 1;
  addToast(night, cause === 'reject' ? 'ER RASTET AUS - ABWEHREN!' : 'ANGRIFF - ABWEHREN!', 'bad', 3);
  game.bus.emit('sfx', 'alarm');
  game.bus.emit('aggression', { station: station.id, cause });
  return station.aggro;
}

/**
 * Eine Taste wurde gedrückt. `key` ist ein KeyboardEvent.code.
 * Gibt zurück, was passiert ist - für Ton und Anzeige.
 */
export function defend(game, station, key) {
  const a = station?.aggro;
  if (!a || a.phase !== 'defend') return null;

  const expected = a.keys[a.index];
  if (!expected) return null;

  if (key === expected.key) {
    a.index++;
    a.hitFlash = 0.25;
    a.shake = Math.min(1, a.shake + 0.35);
    game.bus.emit('sfx', 'ok');
    if (a.index >= a.keys.length) {
      finish(game, station, true);
      return { hit: true, done: true };
    }
    a.keyTime = Math.max(AGGRESSION.keyTimeMin, a.keyTime - AGGRESSION.keyTimeStep);
    a.keyLeft = a.keyTime;
    return { hit: true, done: false };
  }

  return strike(game, station, 'wrong');
}

/** Fehlgriff oder abgelaufenes Zeitfenster. */
function strike(game, station, reason) {
  const a = station.aggro;
  a.strikes++;
  a.missFlash = 0.35;
  game.bus.emit('sfx', 'beep');
  if (a.strikes > a.maxStrikes) {
    finish(game, station, false);
    return { hit: false, done: true, reason };
  }
  // Neues Fenster, gleiche Taste - man bekommt noch eine Chance.
  a.keyLeft = a.keyTime;
  return { hit: false, done: false, reason };
}

/** Jede Nacht-Aktualisierung: Anlauf, Zeitfenster, Auflösung. */
export function updateAggression(game, dt) {
  const night = game.state.night;
  if (!night?.running) return;
  for (const station of Object.values(night.stations)) {
    updateStation(game, station, dt);
  }
  if (!aggressionPossible(game.state)) return;
  // Wer lange an der Kontrolle steht und schlecht drauf ist, kann von selbst
  // ausrasten - unabhängig von jeder Entscheidung.
  for (const station of stationsWithGuest(game, night)) {
    if (aggressionActive(station)) continue;
    station.aggroCooldown = (station.aggroCooldown ?? 1.5) - dt;
    if (station.aggroCooldown > 0) continue;
    station.aggroCooldown = 1;
    // Einer pro Nacht ist gesetzt: ist die ausgewürfelte Stelle erreicht und
    // bis dahin nichts passiert, geht dieser hier los.
    const guest = station.guest;
    if (forcedDue(night) && !guest.tutorial && !guest.isArtist) {
      startAggression(game, station, 'idle');
    } else {
      maybeAggression(game, station, 'idle');
    }
  }
}

/**
 * Steht der garantierte Übergriff dieser Nacht an?
 * Er entfällt, sobald ohnehin schon jemand ausgerastet ist.
 */
export function forcedDue(night) {
  if (!night || night.stats.attacks > 0) return false;
  return night.processed >= (night.forcedAttackAt ?? Infinity);
}

function stationsWithGuest(game, night) {
  const list = [night.stations.door];
  if (!isSolo(game.state)) list.push(night.stations.airlock);
  return list.filter((s) => s.guest);
}

function updateStation(game, station, dt) {
  const a = station.aggro;
  if (!a || a.phase === 'over') return;

  if (a.hitFlash > 0) a.hitFlash -= dt;
  if (a.missFlash > 0) a.missFlash -= dt;
  a.shake = Math.max(0, a.shake - dt * 1.6);

  if (a.phase === 'charge') {
    a.timer -= dt;
    a.approach = clamp(1 - a.timer / AGGRESSION.chargeTime, 0, 1);
    if (a.timer <= 0) {
      a.phase = 'defend';
      a.approach = 1;
      a.keyLeft = a.keyTime;
    }
    return;
  }

  if (a.phase === 'defend') {
    a.keyLeft -= dt;
    if (a.keyLeft <= 0) strike(game, station, 'timeout');
    return;
  }

  // win | fail: kurz stehen lassen, dann auflösen.
  a.timer -= dt;
  if (a.timer <= 0) resolve(game, station);
}

function finish(game, station, won) {
  const a = station.aggro;
  const guest = station.guest;
  const { state } = game;
  const night = state.night;

  a.phase = won ? 'win' : 'fail';
  a.timer = AGGRESSION.resultTime;
  a.approach = won ? 0.35 : 1;

  if (won) {
    night.stats.defended = (night.stats.defended ?? 0) + 1;
    night.stats.defensePay = (night.stats.defensePay ?? 0) + AGGRESSION.winBonus;
    changeReputation(state, AGGRESSION.winRep, 'Angriff abgewehrt');
    earn(state, AGGRESSION.winBonus, 'finding');
    state.xp += AGGRESSION.winXp;
    addToast(night, `ABGEWEHRT +${AGGRESSION.winBonus} EUR`, 'good', 3.5);
    game.bus.emit('sfx', 'ok');
    if (guest) { guest.said = 'SCHON GUT, SCHON GUT!'; guest.saidTimer = 2.4; }
  } else {
    night.stats.attacksLanded = (night.stats.attacksLanded ?? 0) + 1;
    night.stats.incidents++;
    state.lifetime.incidents++;
    const cost = fine(state, AGGRESSION.failCost, 'Übergriff an der Tür');
    changeReputation(state, AGGRESSION.failRep, 'Übergriff');
    addToast(night, `ÜBERGRIFF - SCHADEN ${cost.value} EUR`, 'bad', 4.5);
    pushLog(state, 'Übergriff an der Tür', 'bad');
    game.bus.emit('sfx', 'alarm');
    // Benommen ist man erst, wenn der Gast weg ist (siehe resolve).
    a.stun = true;
  }
  game.bus.emit('aggressionEnd', { station: station.id, won });
}

function stationBelongsTo(game, station, player) {
  if (isSolo(game.state)) return true;
  return station.id === (player.area === 'airlock' ? 'airlock' : 'door');
}

/** Der Gast fliegt raus - egal wie es ausgegangen ist. */
function resolve(game, station) {
  const guest = station.guest;
  const stun = !!station.aggro?.stun;
  station.aggro = null;
  station.aggroCooldown = 2;

  if (stun) {
    // Nach einem Treffer steht man erst mal neben sich.
    for (const player of game.players ?? []) {
      if (!stationBelongsTo(game, station, player)) continue;
      player.busy = AGGRESSION.failStun;
      player.busyTotal = AGGRESSION.failStun;
      player.busyLabel = 'BENOMMEN';
      player.pending = null;
      player.flash = 0.6;
    }
  }

  if (!guest) return;
  rejectGuest(game, guest, station);
}
