/**
 * Night Cycle: Uhr, Phasen, Start und Abschluss einer Nacht.
 */

import { TUNING, NIGHT_EVENTS, FEATURES } from '../data/config.js';
import { createNightState, capacity, addToast, pushLog, guestQuota } from './state.js';
import { tickInsideRevenue } from './economy.js';
import { updateQueue } from './queue.js';
import { updateRandomEvents } from './randomEvents.js';
import { nightRating, changeReputation } from './reputation.js';
import { weightedPick, clamp } from '../core/rng.js';
import { resetGuestSerial } from './guests.js';
import { startTutorial, updateTutorial } from './tutorial.js';

/**
 * Phasen der Nacht - jetzt am Schichtfortschritt festgemacht ("at" ist der
 * Anteil der abgearbeiteten Liste), nicht mehr an der Uhr.
 */
export const PHASES = [
  { at: 0, label: 'OPENING', intensity: 0.25 },
  { at: 0.1, label: 'ERSTE GÄSTE', intensity: 0.4 },
  { at: 0.2, label: 'WARM UP', intensity: 0.5 },
  { at: 0.35, label: 'FULL FLOOR', intensity: 0.65 },
  { at: 0.5, label: 'PRIME TIME', intensity: 0.8 },
  { at: 0.6, label: 'PEAK HOUR', intensity: 1.0 },
  { at: 0.8, label: 'AFTER PEAK', intensity: 0.7 },
  { at: 0.92, label: 'CLOSING', intensity: 0.4 }
];

/** Anteil der abgearbeiteten Schicht (0..1). */
export function shiftProgress(night) {
  if (!night?.quota) return 0;
  return Math.min(1, night.processed / night.quota);
}

export function pickNightEvent(rng, state) {
  if (!FEATURES.nightEvents) return NIGHT_EVENTS[0];
  const nightNumber = state.nightIndex + 1;
  const pool = NIGHT_EVENTS.filter((e) => nightNumber >= (e.minNight ?? 1));
  if (nightNumber === 1) return NIGHT_EVENTS[0];
  return weightedPick(rng, pool, (e) => (e.id === 'normal' ? 5 : 3));
}

export function startNight(game, event, artist, opts = {}) {
  const { state, rng } = game;
  resetGuestSerial();
  state.nightIndex++;
  state.night = createNightState(event, artist, rng.seed, state.mode, guestQuota(state));
  state.night.repDelta = 0;
  state.phase = 'night';
  if (artist) {
    state.night.stats.artistFee = artist.fee;
    state.money -= artist.fee;
  }
  if (opts.tutorial) startTutorial(game);
  pushLog(state, `NIGHT ${String(state.nightIndex).padStart(2, '0')} - ${event.label}`, 'info');
  addToast(state.night, `OFFEN - ${state.night.quota} LEUTE AUF DER LISTE`, 'info', 4);
  game.bus.emit('nightStart', state.night);
  return state.night;
}

export function currentPhase(progress) {
  let phase = PHASES[0];
  for (const p of PHASES) if (progress >= p.at) phase = p;
  return phase;
}

export function clockString(clock) {
  const total = Math.floor(clock);
  const h = Math.floor(total / 60) % 24;
  const m = total % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function updateNight(game, dt) {
  const { state } = game;
  const night = state.night;
  if (!night || !night.running) return;

  const minutes = dt * TUNING.minutesPerSecond;
  night.clock += minutes;

  updateTutorial(game, dt);
  updateQueue(game, dt, minutes);
  if (!night.tutorial && FEATURES.randomEvents) updateRandomEvents(game, dt, minutes);
  tickInsideRevenue(state, minutes);
  updateInside(game, dt, minutes);
  updateEffects(night, dt);
  updateToasts(night, dt);

  const phase = currentPhase(shiftProgress(night));
  if (night.lastPhase !== phase.label) {
    night.lastPhase = phase.label;
    if (night.clock > 1) addToast(night, phase.label, 'info');
    game.bus.emit('phase', phase);
  }

  // Die Schicht endet, wenn die Liste abgearbeitet ist - nicht nach der Uhr.
  if (!night.tutorial && night.processed >= night.quota) endNight(game);
}

function updateInside(game, dt, minutes) {
  const night = game.state.night;
  // Gäste verlassen den Club nach und nach wieder.
  for (let i = night.inside.length - 1; i >= 0; i--) {
    const g = night.inside[i];
    if (g.spendLeft <= 0 && night.clock > 200 && Math.random() < dt * 0.05) {
      night.inside.splice(i, 1);
    }
  }
}

function updateEffects(night, dt) {
  for (let i = night.activeEffects.length - 1; i >= 0; i--) {
    const e = night.activeEffects[i];
    e.remaining -= dt;
    if (e.remaining <= 0) night.activeEffects.splice(i, 1);
  }
}

function updateToasts(night, dt) {
  for (let i = night.toasts.length - 1; i >= 0; i--) {
    night.toasts[i].life -= dt;
    if (night.toasts[i].life <= 0) night.toasts.splice(i, 1);
  }
}

export function endNight(game) {
  const { state } = game;
  const night = state.night;
  night.running = false;
  state.phase = 'report';
  state.lifetime.nights++;

  const rating = nightRating(night.stats);
  night.rating = rating;

  // Abschluss-Reputation aus der Gesamtleistung.
  const bonus = (rating - 2.5) * 1.6;
  changeReputation(state, bonus, 'Nachtbewertung');

  // Künstler: nicht abgeholt = schlechte Presse.
  if (night.artist && !night.artistHandled) {
    changeReputation(state, -4, 'Act nicht eingelassen');
    night.artistMissed = true;
  }

  const xp = Math.round(night.stats.correct * 8 + night.stats.admitted * 2 + rating * 40);
  state.xp += xp;
  night.xpGained = xp;

  const capacityUsed = clamp(night.inside.length / capacity(state), 0, 1);
  night.capacityUsed = capacityUsed;

  if (state.reputation >= 88 && state.nightIndex >= 12) state.expandUnlocked = true;

  game.bus.emit('nightEnd', night);
  return night;
}
