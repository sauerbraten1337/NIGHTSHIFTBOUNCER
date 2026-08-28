/**
 * Queue System: Warteschlange draussen und Schleuse innen.
 *
 * Koop-Fluss:   Schlange -> Tür (Bouncer) -> Schleuse (Security) -> Club
 * Solo-Fluss:   Schlange -> Tür (alles in einer Hand)          -> Club
 */

import {
  queueCapacity, addToast, patienceMultiplier, isSolo, airlockCapacity
} from './state.js';
import { changeReputation, crowdPull } from './reputation.js';
import { createGuest, guestLine } from './guests.js';
import { clamp } from '../core/rng.js';

/** Wie viele Gäste pro Spielminute eintreffen (Kurve über die Nacht). */
export function arrivalRate(state) {
  const night = state.night;
  const t = night.clock;
  let curve;
  if (t < 30) curve = 0.45 + t / 30 * 0.45;
  else if (t < 180) curve = 0.5 + (t - 30) / 150 * 0.9;
  else if (t < 240) curve = 1.4 - (t - 180) / 60 * 0.35;
  else curve = clamp(1.05 - (t - 240) / 60 * 0.95, 0.05, 1.05);

  const rush = night.activeEffects.some((e) => e.id === 'rush') ? 2.4 : 0;
  const viral = night.activeEffects.some((e) => e.id === 'influencerPost') ? 0.6 : 0;
  const tutorial = night.tutorial ? 0.3 : 1;
  // Solo muss allein durch alle Kontrollen - entsprechend weniger Andrang.
  const modeScale = isSolo(state) ? 0.55 : 1;
  return ((curve * (night.event?.spawn ?? 1) * crowdPull(state) * 0.55) + rush + viral)
    * tutorial * modeScale;
}

export function updateQueue(game, dt, minutes) {
  const { state } = game;
  const night = state.night;
  const cap = queueCapacity(state);

  if (!night.tutorial?.blockSpawns) {
    night.spawnCooldown -= minutes * arrivalRate(state) * 0.45;
    while (night.spawnCooldown <= 0) {
      night.spawnCooldown += 1;
      if (night.clock >= 285) break;
      if (night.queue.length < cap) spawnGuest(game);
      else { night.stats.left++; night.stats.arrived++; }
    }
  }

  updatePatience(game, dt);
  advanceStations(game);
  updateLeaving(night, dt);
  moveGuests(night, dt);
}

function updatePatience(game, dt) {
  const { state } = game;
  const night = state.night;
  for (let i = night.queue.length - 1; i >= 0; i--) {
    const g = night.queue[i];
    const drain = 1 + (g.mood < 0.4 ? 0.4 : 0) + (i > 6 ? 0.25 : 0);
    g.patience -= dt * drain;
    if (g.saidTimer > 0) g.saidTimer -= dt;
    else g.said = null;

    if (g.patience <= 0) {
      night.queue.splice(i, 1);
      night.stats.left++;
      g.state = 'left';
      g.exitTimer = 1.2;
      night.leaving.push(g);
      changeReputation(state, g.truth.vip ? -1.4 : -0.35, 'Gast ist gegangen');
      if (g.truth.vip) addToast(night, 'VIP HAT DIE SCHLANGE VERLASSEN', 'bad');
    }
  }
  // Gäste in der Schleuse und an den Stationen: Sprechblasen ausblenden.
  for (const g of [...night.airlockQueue, night.stations.door.guest, night.stations.airlock.guest]) {
    if (!g) continue;
    if (g.saidTimer > 0) g.saidTimer -= dt;
    else g.said = null;
  }
}

/** Rückt Gäste an die freien Stationen nach. */
function advanceStations(game) {
  const { state, rng, bus } = game;
  const night = state.night;
  const door = night.stations.door;
  const airlock = night.stations.airlock;

  if (!door.guest && night.queue.length > 0) {
    const next = night.queue.shift();
    next.state = 'door';
    next.said = guestLine(rng, next, 'greet');
    next.saidTimer = 3.4;
    door.guest = next;
    door.checks = emptyStationChecks();
    door.patdown = null;
    bus.emit('stationGuest', { station: 'door', guest: next });
  }

  if (!isSolo(state) && !airlock.guest && night.airlockQueue.length > 0) {
    const next = night.airlockQueue.shift();
    next.state = 'airlock';
    next.said = guestLine(rng, next, 'search');
    next.saidTimer = 3.2;
    airlock.guest = next;
    airlock.checks = emptyStationChecks();
    airlock.patdown = null;
    bus.emit('stationGuest', { station: 'airlock', guest: next });
  }
}

function emptyStationChecks() {
  return {
    id: null, talk: null, scan: null, search: null, alcohol: null,
    verified: false, conflict: false
  };
}

function updateLeaving(night, dt) {
  for (let i = night.leaving.length - 1; i >= 0; i--) {
    const g = night.leaving[i];
    g.exitTimer -= dt;
    if (g.exitTimer <= 0) night.leaving.splice(i, 1);
  }
}

function moveGuests(night, dt) {
  for (const g of night.queue) {
    g.walkPhase += dt * (g.moving ? 8 : 1.2);
    g.swayPhase += dt * (1.5 + g.truth.drunk * 3.5);
  }
  for (const g of night.airlockQueue) {
    g.walkPhase += dt * 1.2;
    g.swayPhase += dt * (1.5 + g.truth.drunk * 3.5);
  }
  for (const s of [night.stations.door, night.stations.airlock]) {
    if (s.guest) {
      s.guest.walkPhase += dt * 1.4;
      s.guest.swayPhase += dt * (1.5 + s.guest.truth.drunk * 4);
    }
  }
}

function spawnGuest(game) {
  const { state, rng } = game;
  const night = state.night;
  const guest = createGuest(rng, {
    event: night.event,
    reputation: state.reputation,
    patienceMul: patienceMultiplier(state),
    nightIndex: state.nightIndex
  });
  night.queue.push(guest);
  night.stats.arrived++;
  state.lifetime.guests++;
  return guest;
}

/** Fügt einen vorbereiteten Gast (Special-Event, Tutorial) ein. */
export function insertGuest(game, guest, atFront = false) {
  const night = game.state.night;
  if (atFront) night.queue.unshift(guest);
  else night.queue.push(guest);
  night.stats.arrived++;
  game.state.lifetime.guests++;
  return guest;
}

/** Gast wandert von der Tür in die Schleuse. */
export function moveToAirlock(game, guest) {
  const night = game.state.night;
  guest.state = 'airlockQueue';
  guest.passedAt = night.clock;
  night.airlockQueue.push(guest);
  return night.airlockQueue.length;
}

export function airlockFull(state) {
  const night = state.night;
  return night.airlockQueue.length + (night.stations.airlock.guest ? 1 : 0) >= airlockCapacity(state);
}

/** CALM: beruhigt die Warteschlange. */
export function calmQueue(state) {
  const night = state.night;
  const power = 8 + state.talents.charisma * 4 + (state.upgrades.team ?? 0) * 3;
  let affected = 0;
  for (const g of night.queue.slice(0, 8)) {
    g.patience = Math.min(g.patienceMax, g.patience + power);
    g.mood = clamp(g.mood + 0.15, 0, 1);
    affected++;
  }
  return affected;
}

/** Durchschnittliche Stimmung der Schlange (0-1) für HUD und Rendering. */
export function queueMood(night) {
  if (!night.queue.length) return 1;
  let sum = 0;
  for (const g of night.queue) sum += g.patience / g.patienceMax;
  return sum / night.queue.length;
}
