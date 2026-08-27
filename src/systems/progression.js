/** Spieler-Fortschritt: Raenge und Talente. */

import { TALENTS, RANKS } from '../data/config.js';
import { rank, nextRank } from './state.js';

/** Prueft nach einer Nacht, ob ein Rang aufgestiegen wurde. */
export function checkRankUp(state, previousLevel) {
  const current = rank(state);
  if (current.level > previousLevel) {
    state.talentPoints += current.level - previousLevel;
    return current;
  }
  return null;
}

export function rankProgress(state) {
  const current = rank(state);
  const next = nextRank(state);
  if (!next) return { current, next: null, ratio: 1 };
  const span = next.xp - current.xp;
  const done = state.xp - current.xp;
  return { current, next, ratio: Math.max(0, Math.min(1, done / span)) };
}

export function talentList(state) {
  return TALENTS.map((t) => ({
    ...t,
    level: state.talents[t.id] ?? 0,
    canBuy: (state.talents[t.id] ?? 0) < t.max && state.talentPoints > 0
  }));
}

export function buyTalent(state, id) {
  const def = TALENTS.find((t) => t.id === id);
  if (!def) return { ok: false, reason: 'Unbekannt' };
  if (state.talentPoints <= 0) return { ok: false, reason: 'Keine Talentpunkte' };
  if ((state.talents[id] ?? 0) >= def.max) return { ok: false, reason: 'Maximal' };
  state.talents[id] = (state.talents[id] ?? 0) + 1;
  state.talentPoints--;
  return { ok: true, level: state.talents[id], label: def.label };
}

export { RANKS };
