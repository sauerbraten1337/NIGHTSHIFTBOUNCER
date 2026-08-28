/**
 * Fortschreitende Schwierigkeit: Mit jeder Nacht kommt eine neue Sorte
 * Unregelmäßigkeit dazu, auf die man achten muss. Die Freischaltung wird im
 * Briefing angekündigt, damit niemand von einer neuen Regel überrascht wird,
 * ohne sie zu kennen.
 */

import { DIFFICULTY_STEPS } from '../data/config.js';

/** Alle Stufen, die in dieser Nacht bereits gelten. */
export function activeSteps(nightNumber) {
  return DIFFICULTY_STEPS.filter((s) => nightNumber >= s.night);
}

/** Die Stufe, die genau in dieser Nacht neu dazukommt (oder null). */
export function newStep(nightNumber) {
  return DIFFICULTY_STEPS.find((s) => s.night === nightNumber) ?? null;
}

export function hasFeature(nightNumber, id) {
  const step = DIFFICULTY_STEPS.find((s) => s.id === id);
  return !!step && nightNumber >= step.night;
}

/**
 * Wie stark greifen die Mechaniken in dieser Nacht?
 * Alles skaliert sanft, damit Nacht 12 nicht schlagartig unspielbar wird.
 */
export function difficultyProfile(nightNumber) {
  const n = Math.max(1, nightNumber);
  return {
    night: n,
    items: hasFeature(n, 'items'),
    alcohol: hasFeature(n, 'alcohol'),
    impaired: hasFeature(n, 'impaired'),
    aggression: hasFeature(n, 'aggression'),
    subtleId: hasFeature(n, 'subtleId'),
    blacklist: hasFeature(n, 'blacklist'),
    multi: hasFeature(n, 'multi'),

    /** Wahrscheinlichkeit, dass ein Gast unter Substanzeinfluss steht. */
    impairedChance: hasFeature(n, 'impaired') ? Math.min(0.3, 0.08 + (n - 4) * 0.025) : 0,
    /** Wie deutlich sind die Anzeichen? Später werden sie subtiler. */
    signClarity: Math.max(0.45, 1 - Math.max(0, n - 4) * 0.05),
    /** Wahrscheinlichkeit für mehrere Mängel gleichzeitig. */
    multiIssueChance: hasFeature(n, 'multi') ? Math.min(0.35, 0.12 + (n - 10) * 0.02) : 0,
    /** Wie viele harmlose Gegenstände liegen zur Ablenkung dabei? */
    decoyBonus: Math.min(2, Math.floor((n - 1) / 4))
  };
}

/** Kurzliste für das Briefing. */
export function difficultyBriefing(nightNumber) {
  return {
    active: activeSteps(nightNumber),
    fresh: newStep(nightNumber)
  };
}
