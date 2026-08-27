/** Upgrade System: Club-Ausbau mit sichtbaren Stufen. */

import { UPGRADES } from '../data/config.js';
import { upgradeCostMultiplier, clubTier, upgradeLevel } from './state.js';

export function upgradeById(id) {
  return UPGRADES.find((u) => u.id === id) ?? null;
}

export function nextCost(state, id) {
  const def = upgradeById(id);
  if (!def) return null;
  const level = upgradeLevel(state, id);
  if (level >= def.max) return null;
  return Math.round(def.cost[level] * upgradeCostMultiplier(state));
}

export function canBuy(state, id) {
  const cost = nextCost(state, id);
  return cost !== null && state.money >= cost;
}

export function buyUpgrade(state, id) {
  const def = upgradeById(id);
  const cost = nextCost(state, id);
  if (!def || cost === null) return { ok: false, reason: 'Maximal ausgebaut' };
  if (state.money < cost) return { ok: false, reason: 'Nicht genug Geld' };

  const tierBefore = clubTier(state).level;
  state.money -= cost;
  state.upgrades[id] = upgradeLevel(state, id) + 1;
  const tierAfter = clubTier(state).level;

  return {
    ok: true,
    id,
    level: state.upgrades[id],
    cost,
    desc: def.desc[state.upgrades[id] - 1],
    tierChanged: tierAfter > tierBefore,
    tier: tierAfter
  };
}

/** Gruppierte Liste für den Shop. */
export function upgradeList(state) {
  return UPGRADES.map((def) => {
    const level = upgradeLevel(state, def.id);
    const cost = nextCost(state, def.id);
    return {
      id: def.id,
      label: def.label,
      group: def.group,
      level,
      max: def.max,
      cost,
      maxed: level >= def.max,
      nextDesc: level < def.max ? def.desc[level] : def.desc[def.max - 1],
      affordable: cost !== null && state.money >= cost
    };
  });
}
