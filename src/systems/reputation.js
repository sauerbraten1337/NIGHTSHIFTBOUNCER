/** Reputation System: Ruf 0-100 steuert Andrang, Preise und Acts. */

import { clamp } from '../core/rng.js';
import { reputationGainMultiplier } from './state.js';

export function changeReputation(state, delta, reason = '') {
  const scaled = delta > 0 ? delta * reputationGainMultiplier(state) : delta;
  const before = state.reputation;
  state.reputation = clamp(state.reputation + scaled, 0, 100);
  const applied = state.reputation - before;
  if (state.night) state.night.repDelta = (state.night.repDelta ?? 0) + applied;
  return { applied, reason };
}

/** Reputation beeinflusst, wie viele Gäste überhaupt auftauchen. */
export function crowdPull(state) {
  const rep = state.reputation;
  return 0.55 + (rep / 100) * 1.5;
}

export function repBand(rep) {
  if (rep >= 85) return 'INTERNATIONAL';
  if (rep >= 68) return 'ETABLIERT';
  if (rep >= 48) return 'BEKANNT';
  if (rep >= 28) return 'LOKAL';
  return 'UNBEKANNT';
}

/** Sternewertung für den Night Report. */
export function nightRating(stats) {
  const decisions = stats.correct + stats.mistakes;
  const accuracy = decisions > 0 ? stats.correct / decisions : 0.5;
  const flow = stats.arrived > 0 ? 1 - stats.left / Math.max(1, stats.arrived) : 1;
  const incidentPenalty = Math.min(0.4, stats.incidents * 0.06);
  const score = accuracy * 0.6 + flow * 0.4 - incidentPenalty;
  return clamp(Math.round(score * 5), 0, 5);
}
