/**
 * Security System: körperliche Kontrolle (Abtasten).
 * Bewusst abstrakt und nicht grafisch: drei Zonen, pro Zone eine kurze
 * Animation, danach ein Signal. Metalldetektor-Upgrades reduzieren die
 * noetige Handarbeit.
 */

import { PATDOWN_KEYS } from '../data/config.js';
import { upgradeLevel } from './state.js';

export const ZONES = PATDOWN_KEYS.map((z) => z.zone);

export function startPatdown(state, guest) {
  const detector = upgradeLevel(state, 'detector');
  const hinted = detector >= 1 && guest.truth.contraband ? guest.truth.contrabandZone : null;

  const patdown = {
    guestId: guest.id,
    zones: { jacket: null, pockets: null, bag: null },
    hint: hinted,
    found: null,
    complete: false,
    autoResolved: false
  };

  // Stufe 2: der Detektor findet gefaehrliche Gegenstaende selbststaendig.
  if (detector >= 2 && guest.truth.contraband && guest.truth.contraband.severity >= 2) {
    patdown.zones[guest.truth.contrabandZone] = 'hit';
    patdown.found = guest.truth.contraband;
    patdown.complete = true;
    patdown.autoResolved = true;
  }
  return patdown;
}

/** Tastet eine Zone ab. Gibt das Ergebnis für diese Zone zurück. */
export function patZone(patdown, guest, zone) {
  if (!patdown || patdown.zones[zone] !== null) return null;
  const isHit = guest.truth.contraband && guest.truth.contrabandZone === zone;
  patdown.zones[zone] = isHit ? 'hit' : 'clear';
  if (isHit) {
    patdown.found = guest.truth.contraband;
    patdown.complete = true;
  } else if (ZONES.every((z) => patdown.zones[z] !== null)) {
    patdown.complete = true;
  }
  return patdown.zones[zone];
}

/** Zusammenfassung der abgeschlossenen Kontrolle. */
export function patdownResult(patdown) {
  if (!patdown) return null;
  const checkedZones = ZONES.filter((z) => patdown.zones[z] !== null);
  return {
    done: patdown.complete,
    partial: checkedZones.length > 0 && !patdown.complete,
    zonesChecked: checkedZones.length,
    found: patdown.found,
    /** Wurde vollstaendig kontrolliert? Nur dann ist "sauber" belastbar. */
    reliable: patdown.complete && !patdown.found ? true : !!patdown.found,
    text: patdown.found
      ? `GEFUNDEN: ${patdown.found.label.toUpperCase()}`
      : patdown.complete ? 'KEINE AUFFÄLLIGKEITEN' : `${checkedZones.length}/3 ZONEN`
  };
}

/**
 * Entscheidet, ob ein zugelassener Gast im Club einen Zwischenfall ausloest.
 * Security-Team und Kameras daempfen Häufigkeit und Schaden.
 */
export function incidentChance(state, guest) {
  const t = guest.truth;
  let p = t.risk * 0.35 + (t.drunk > 0.6 ? 0.15 : 0) + (t.contraband ? t.contraband.severity * 0.12 : 0);
  if (t.blacklisted) p += 0.25;
  p -= upgradeLevel(state, 'team') * 0.07;
  p -= upgradeLevel(state, 'cameras') * 0.05;
  return Math.max(0, Math.min(0.95, p));
}
