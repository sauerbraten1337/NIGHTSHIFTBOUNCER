/** Economy System: Eintritt, Bar-Umsatz, Strafen, Zwischenfallkosten. */

import { TUNING } from '../data/config.js';
import { entryFee, spendMultiplier, upgradeLevel } from './state.js';

export function admitRevenue(state, guest) {
  const fee = guest.truth.vip ? Math.round(entryFee(state) * 1.6) : entryFee(state);
  return fee;
}

/** Wie viel gibt der Gast im Laufe der Nacht drinnen aus? */
export function plannedBarSpend(state, guest) {
  const vipBonus = guest.truth.vip ? 1 + upgradeLevel(state, 'vip') * 0.35 : 1;
  return guest.truth.spend * spendMultiplier(state) * vipBonus;
}

export function earn(state, amount, category = 'bar') {
  const value = Math.round(amount);
  state.money += value;
  if (state.night) {
    state.night.stats.revenue += value;
    if (category === 'entry') state.night.stats.entry += value;
    else state.night.stats.bar += value;
  }
  state.lifetime.revenue += value;
  return value;
}

export function spend(state, amount) {
  const value = Math.round(amount);
  state.money -= value;
  return value;
}

export function fine(state, amount, reason) {
  const value = Math.round(amount);
  state.money -= value;
  if (state.night) {
    state.night.stats.fines += value;
    state.night.stats.revenue -= value;
  }
  return { value, reason };
}

export function incidentCost(state, severity = 1) {
  const mitigation = 1 - upgradeLevel(state, 'team') * 0.12 - upgradeLevel(state, 'cameras') * 0.08;
  return Math.max(20, Math.round(TUNING.incidentBaseCost * severity * Math.max(0.3, mitigation)));
}

/**
 * Laufender Bar-Umsatz der Gäste im Club (pro Spielminute).
 * Bruchteile werden gepuffert, damit kein Umsatz durch Rundung verloren geht.
 */
export function tickInsideRevenue(state, minutes) {
  const night = state.night;
  if (!night) return 0;
  let total = 0;
  for (const g of night.inside) {
    if (g.spendLeft <= 0) continue;
    const rate = g.spendTotal / 90; // über ca. 90 Spielminuten verteilt
    const amount = Math.min(g.spendLeft, rate * minutes);
    g.spendLeft -= amount;
    total += amount;
  }
  night.barAccum = (night.barAccum ?? 0) + total;
  if (night.barAccum >= 1) {
    const payout = Math.floor(night.barAccum);
    night.barAccum -= payout;
    earn(state, payout, 'bar');
  }
  return total;
}
