/**
 * Queue System: Warteschlange vor dem Club.
 * Gäste laufen an, stellen sich an, verlieren Geduld und ruecken nach.
 */

import { queueCapacity, addToast, patienceMultiplier } from './state.js';
import { changeReputation, crowdPull } from './reputation.js';
import { createGuest, guestLine } from './guests.js';
import { LAYOUT } from '../render/layout.js';
import { clamp } from '../core/rng.js';

/** Wie viele Gäste pro Spielminute eintreffen (Kurve über die Nacht). */
export function arrivalRate(state) {
  const night = state.night;
  const t = night.clock;
  // Kurve: langsam ab 00:00, Peak gegen 03:00, danach Abfall.
  let curve;
  if (t < 30) curve = 0.45 + t / 30 * 0.45;
  else if (t < 180) curve = 0.5 + (t - 30) / 150 * 0.9;
  else if (t < 240) curve = 1.4 - (t - 180) / 60 * 0.35;
  else curve = clamp(1.05 - (t - 240) / 60 * 0.95, 0.05, 1.05);

  const rush = night.activeEffects.some((e) => e.id === 'rush') ? 2.4 : 0;
  const viral = night.activeEffects.some((e) => e.id === 'influencerPost') ? 0.6 : 0;
  return (curve * (night.event?.spawn ?? 1) * crowdPull(state) * 0.55) + rush + viral;
}

export function updateQueue(game, dt, minutes) {
  const { state, rng } = game;
  const night = state.night;
  const cap = queueCapacity(state);

  // --- Spawning ---
  night.spawnCooldown -= minutes * arrivalRate(state) * 0.45;
  while (night.spawnCooldown <= 0) {
    night.spawnCooldown += 1;
    if (night.queue.length < cap && night.clock < 285) {
      spawnGuest(game);
    } else if (night.queue.length >= cap && night.clock < 285) {
      // Wer keinen Platz findet, geht wieder - kostet Umsatz.
      night.stats.left++;
      night.stats.arrived++;
    }
  }

  // --- Geduld & Positionen ---
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
      night.leaving = night.leaving ?? [];
      night.leaving.push(g);
      changeReputation(state, g.truth.vip ? -1.4 : -0.35, 'Gast ist gegangen');
      if (g.truth.vip) addToast(night, 'VIP HAT DIE SCHLANGE VERLASSEN', 'bad');
      continue;
    }
    layoutQueueSlot(g, i);
  }

  // --- Nächsten Gast an die Tür holen ---
  if (!night.door && night.queue.length > 0) {
    const next = night.queue.shift();
    next.state = 'door';
    next.targetX = LAYOUT.door.x;
    next.targetY = LAYOUT.door.y + 46;
    next.said = guestLine(rng, next, 'greet');
    next.saidTimer = 3.2;
    night.door = next;
    game.bus.emit('doorGuest', next);
  }

  // --- Abgehende Gäste ---
  if (night.leaving) {
    for (let i = night.leaving.length - 1; i >= 0; i--) {
      const g = night.leaving[i];
      g.exitTimer -= dt;
      g.targetY = g.state === 'admitted' ? LAYOUT.door.y - 60 : LAYOUT.street.y + 90;
      g.targetX += (g.state === 'admitted' ? 0 : (g.seed % 2 ? -1 : 1)) * dt * 40;
      if (g.exitTimer <= 0) night.leaving.splice(i, 1);
    }
  }

  // Positionen weich interpolieren
  moveGuests(night, dt);
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
  guest.x = LAYOUT.spawn.x + (rng() - 0.5) * 40;
  guest.y = LAYOUT.spawn.y + (rng() - 0.5) * 20;
  layoutQueueSlot(guest, night.queue.length);
  night.queue.push(guest);
  night.stats.arrived++;
  state.lifetime.guests++;
  return guest;
}

/** Fuegt einen vorbereiteten Gast (Special-Event) vorne oder hinten ein. */
export function insertGuest(game, guest, atFront = false) {
  const night = game.state.night;
  guest.x = LAYOUT.spawn.x;
  guest.y = LAYOUT.spawn.y;
  if (atFront) night.queue.unshift(guest);
  else night.queue.push(guest);
  night.stats.arrived++;
  game.state.lifetime.guests++;
  night.queue.forEach(layoutQueueSlot);
  return guest;
}

/** Schlangenform: erst gerade zur Tür, dann in Reihen zurück. */
export function layoutQueueSlot(guest, index) {
  const q = LAYOUT.queue;
  const row = Math.floor(index / q.perRow);
  const col = index % q.perRow;
  const dir = row % 2 === 0 ? 1 : -1;
  const colPos = dir === 1 ? col : q.perRow - 1 - col;
  guest.queueIndex = index;
  guest.targetX = q.x + colPos * q.spacing;
  guest.targetY = q.y + row * q.rowGap;
}

function moveGuests(night, dt) {
  const all = [...night.queue, ...(night.door ? [night.door] : []), ...(night.leaving ?? [])];
  for (const g of all) {
    const dx = g.targetX - g.x;
    const dy = g.targetY - g.y;
    const dist = Math.hypot(dx, dy);
    const speed = Math.min(dist * 4.5, 120);
    if (dist > 0.5) {
      g.x += (dx / dist) * speed * dt;
      g.y += (dy / dist) * speed * dt;
      g.walkPhase += dt * 9;
      g.moving = true;
    } else {
      g.moving = false;
      g.walkPhase += dt * 1.2;
    }
    // Betrunkene schwanken sichtbar.
    g.swayPhase += dt * (1.5 + g.truth.drunk * 3.5);
  }
}

/** CALM: beruhigt die Warteschlange (Aktion von Spieler 2). */
export function calmQueue(state) {
  const night = state.night;
  const power = 8 + state.talents.charisma * 4 + upgradeTeamBonus(state);
  let affected = 0;
  for (const g of night.queue.slice(0, 8)) {
    g.patience = Math.min(g.patienceMax, g.patience + power);
    g.mood = clamp(g.mood + 0.15, 0, 1);
    affected++;
  }
  return affected;
}

function upgradeTeamBonus(state) {
  return (state.upgrades.team ?? 0) * 3;
}

/** Durchschnittliche Stimmung der Schlange (0-1) für HUD und Rendering. */
export function queueMood(night) {
  if (!night.queue.length) return 1;
  let sum = 0;
  for (const g of night.queue) sum += g.patience / g.patienceMax;
  return sum / night.queue.length;
}
