/**
 * Zentraler Spielzustand + abgeleitete Werte.
 * DOM-frei, damit die Spiellogik testbar bleibt (und auf dem Host im
 * Online-Modus autoritativ laufen kann).
 */

import { TUNING, UPGRADES, CLUB_TIERS, RANKS, rolesFor, AIRLOCK_CAPACITY } from '../data/config.js';
import { clamp } from '../core/rng.js';
import { emptyNotes } from './notes.js';

export function createInitialState(mode = 'solo') {
  const upgrades = {};
  for (const u of UPGRADES) upgrades[u.id] = 0;

  return {
    version: 2,
    mode,                    // solo | local | online
    phase: 'menu',           // menu | briefing | night | report | shop
    money: TUNING.moneyStart,
    reputation: TUNING.reputationStart,
    xp: 0,
    talentPoints: 1,
    talents: { street: 0, scanner: 0, charisma: 0, reputation: 0, management: 0 },
    upgrades,
    nightIndex: 0,
    clubsOwned: 1,
    expandUnlocked: false,
    bookedArtist: null,
    tutorialDone: false,
    /** Freischaltungen: das Tutorial gibt Mechaniken nacheinander frei. */
    unlocks: { id: true, talk: false, search: false, alcohol: false, calm: false },
    lifetime: { guests: 0, admitted: 0, rejected: 0, revenue: 0, incidents: 0, nights: 0 },
    night: null,
    log: []
  };
}

/**
 * Wie viele Gaeste muessen in dieser Nacht abgefertigt werden?
 * Die Schicht endet nicht nach der Uhr, sondern wenn die Liste leer ist.
 */
export function guestQuota(state) {
  const n = Math.max(0, state.nightIndex - 1);
  return Math.min(
    TUNING.guestsPerNightMax,
    TUNING.guestsPerNight + n * TUNING.guestsPerNightGrowth
  );
}

/** Zustand einer laufenden Nacht. */
export function createNightState(event, artist, seed, mode = 'solo', quota = TUNING.guestsPerNight) {
  return {
    /** Schichtplan statt Uhr: so viele Gaeste sind zu pruefen. */
    quota,
    processed: 0,

    seed,
    mode,
    event,
    artist,
    artistArrived: false,
    artistHandled: false,
    artistDelayed: false,
    clock: TUNING.nightStartMinute,
    running: true,
    tutorial: null,

    queue: [],          // Warteschlange draussen
    airlockQueue: [],   // durchgelassene Gaeste, warten in der Schleuse
    inside: [],
    leaving: [],

    stations: {
      door: newStation('door'),
      airlock: newStation('airlock')
    },

    /**
     * Ab welchem abgearbeiteten Gast spaetestens jemand ausrastet?
     * Genau ein garantierter Uebergriff pro Nacht - startNight wuerfelt aus,
     * wann er faellig wird (siehe systems/aggression.js).
     */
    forcedAttackAt: 0,

    spawnCooldown: 0.25,
    randomEventCooldown: 40,
    activeEffects: [],
    stats: {
      arrived: 0, admitted: 0, rejected: 0, left: 0, passed: 0,
      revenue: 0, entry: 0, bar: 0, incidents: 0, vips: 0,
      correct: 0, mistakes: 0, verified: 0, catches: 0, fines: 0, artistFee: 0,
      /** Selbst gefundene Unregelmaessigkeiten (Ausweis, Sachen, Alkohol). */
      findings: 0, falseAlarms: 0, overlooked: 0, findingPay: 0,
      /** Uebergriffe: versucht, abgewehrt, durchgekommen. */
      attacks: 0, defended: 0, attacksLanded: 0, defensePay: 0
    },
    repDelta: 0,
    toasts: []
  };
}

export function newStation(id) {
  return {
    id, guest: null, checks: emptyChecks(), patdown: null, notes: emptyNotes(),
    /** Laufender Uebergriff (siehe systems/aggression.js). */
    aggro: null,
    aggroCooldown: 2
  };
}

export function emptyChecks() {
  return {
    id: null,        // Inspection-Objekt (siehe identity.js)
    talk: null,      // { line, realName, hint, moodHint }
    search: null,    // { done, found, text }
    alcohol: null,   // { value, promille, overLimit }
    verified: false,
    conflict: false
  };
}

/** Solo: alles laeuft an der Tuer. Koop: Tuer draussen, Schleuse innen. */
export function isSolo(state) {
  return state.mode === 'solo';
}

export function stationFor(state, areaOrRole) {
  const night = state.night;
  if (!night) return null;
  if (isSolo(state)) return night.stations.door;
  return areaOrRole === 'airlock' || areaOrRole === 'security'
    ? night.stations.airlock
    : night.stations.door;
}

export function airlockCapacity(state) {
  return AIRLOCK_CAPACITY + (upgradeLevel(state, 'door') >= 2 ? 2 : 0);
}

/* ---------- Abgeleitete Werte ---------- */

export function upgradeLevel(state, id) {
  return state.upgrades[id] ?? 0;
}

export function totalUpgradeTiers(state) {
  let sum = 0;
  for (const u of UPGRADES) sum += (state.upgrades[u.id] ?? 0) * (u.tier ?? 1);
  return sum;
}

export function clubTier(state) {
  const total = totalUpgradeTiers(state);
  let tier = CLUB_TIERS[0];
  for (const t of CLUB_TIERS) if (total >= t.need) tier = t;
  return tier;
}

export function capacity(state) {
  const floor = upgradeLevel(state, 'floor');
  const add = [0, 80, 220, 440][floor] ?? 0;
  return TUNING.baseCapacity + add;
}

export function queueCapacity(state) {
  return TUNING.baseQueueCapacity + upgradeLevel(state, 'door') * 5;
}

export function rank(state) {
  let r = RANKS[0];
  for (const entry of RANKS) if (state.xp >= entry.xp) r = entry;
  return r;
}

export function nextRank(state) {
  const current = rank(state);
  return RANKS.find((r) => r.level === current.level + 1) ?? null;
}

/** Multiplikator für Aktionsdauer (kleiner = schneller). */
export function actionSpeed(state) {
  const talent = state.talents.scanner * 0.12;
  const scanner = upgradeLevel(state, 'scanner') >= 2 ? 0.18 : 0;
  const door = upgradeLevel(state, 'door') >= 1 ? 0.08 : 0;
  return clamp(1 - talent - scanner - door, 0.4, 1);
}

export function spendMultiplier(state) {
  const bar = upgradeLevel(state, 'bar') * 0.18;
  const sound = upgradeLevel(state, 'sound') * 0.1;
  const vip = upgradeLevel(state, 'vip') * 0.12;
  const mgmt = state.talents.management * 0.05;
  const artist = state.night?.artist?.spend ?? 1;
  return (1 + bar + sound + vip + mgmt) * artist;
}

export function patienceMultiplier(state) {
  const lights = upgradeLevel(state, 'lights') * 0.08;
  const comfort = upgradeLevel(state, 'comfort') * 0.1;
  const team = upgradeLevel(state, 'team') * 0.07;
  const charisma = state.talents.charisma * 0.09;
  return 1 + lights + comfort + team + charisma;
}

export function reputationGainMultiplier(state) {
  return 1 + state.talents.reputation * 0.2 + upgradeLevel(state, 'comfort') * 0.08;
}

export function upgradeCostMultiplier(state) {
  return clamp(1 - state.talents.management * 0.07, 0.7, 1);
}

export function entryFee(state) {
  const rep = state.reputation;
  const tier = clubTier(state).level;
  return Math.round(TUNING.baseEntryFee + rep * 0.12 + tier * 2.5);
}

export function rolesOf(state) {
  return rolesFor(state.mode);
}

export function pushLog(state, text, kind = 'info') {
  state.log.unshift({ text, kind, t: Date.now() });
  if (state.log.length > 60) state.log.length = 60;
}

export function addToast(night, text, kind = 'info', ttl = 3.4) {
  if (!night) return;
  night.toasts.push({ text, kind, ttl, life: ttl });
  if (night.toasts.length > 6) night.toasts.shift();
}
