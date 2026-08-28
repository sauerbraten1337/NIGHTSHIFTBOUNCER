/**
 * Security System: körperliche Kontrolle.
 *
 * Ablauf, bewusst abstrakt und ohne Gewaltdarstellung:
 *   1. Abtasten starten - die Zonen werden markiert (Jacke, Hosentaschen, Tasche)
 *   2. Eine Zone wählen -> der Gast leert sie aus (bei der Tasche holt er sie
 *      erst hervor), die Sachen kommen gross auf den Tisch
 *   3. Der Spieler sucht heraus, was nicht in den Club darf - oder erklärt die
 *      Zone für sauber. Zwischen Kaugummi und Klinge liegt sein Auge.
 */

import { ZONES } from '../data/config.js';
import { upgradeLevel } from './state.js';

export const ZONE_IDS = ZONES.map((z) => z.id);

export function zonesFor(guest) {
  return ZONES.filter((z) => guest.truth.zoneIds.includes(z.id));
}

export function startPatdown(state, guest) {
  const detector = upgradeLevel(state, 'detector');
  const zones = {};
  for (const zone of zonesFor(guest)) {
    zones[zone.id] = {
      id: zone.id,
      label: zone.label,
      state: 'closed',      // closed | opening | open | done
      openTimer: 0,
      items: null,          // erst beim Öffnen sichtbar
      picked: null,         // vom Spieler gewählter Gegenstand
      correct: null,
      missed: false
    };
  }

  const patdown = {
    guestId: guest.id,
    zones,
    order: Object.keys(zones),
    active: null,           // aktuell geöffnete Zone
    hint: detector >= 1 && guest.truth.contraband ? guest.truth.contrabandZone : null,
    found: null,
    complete: false,
    autoResolved: false,
    bagOut: false           // die Tasche ist hervorgeholt
  };

  // Stufe 2: der Detektor findet gefährliche Gegenstände von selbst.
  if (detector >= 2 && guest.truth.contraband && guest.truth.contraband.severity >= 2) {
    const zone = patdown.zones[guest.truth.contrabandZone];
    if (zone) {
      zone.state = 'done';
      zone.items = guest.truth.carried[zone.id] ?? [];
      zone.picked = guest.truth.contraband;
      zone.correct = true;
    }
    patdown.found = guest.truth.contraband;
    patdown.complete = true;
    patdown.autoResolved = true;
  }
  return patdown;
}

/** Zone öffnen: der Gast holt heraus, was drin ist. */
export function openZone(patdown, guest, zoneId) {
  const zone = patdown?.zones[zoneId];
  if (!zone || zone.state === 'done') return null;
  zone.items = [...(guest.truth.carried[zoneId] ?? [])];
  zone.state = 'open';
  patdown.active = zoneId;
  if (zoneId === 'bag') patdown.bagOut = true;
  return zone;
}

/**
 * Der Spieler zeigt auf einen Gegenstand (oder erklärt die Zone für sauber).
 * itemId = null bedeutet "hier ist nichts Verbotenes".
 */
export function pickItem(patdown, guest, zoneId, itemId) {
  const zone = patdown?.zones[zoneId];
  if (!zone || zone.state !== 'open') return null;

  const forbidden = (zone.items ?? []).find((i) => i.forbidden) ?? null;

  if (itemId === null) {
    zone.picked = null;
    zone.correct = !forbidden;
    zone.missed = !!forbidden;   // etwas übersehen
    zone.state = 'done';
  } else {
    const item = (zone.items ?? []).find((i) => i.id === itemId);
    if (!item) return null;
    zone.picked = item;
    zone.correct = !!item.forbidden;
    zone.state = 'done';
    if (item.forbidden) patdown.found = item;
  }

  patdown.active = null;
  patdown.complete = Object.values(patdown.zones).every((z) => z.state === 'done');
  return {
    zone: zoneId,
    item: zone.picked,
    correct: zone.correct,
    missed: zone.missed,
    forbidden
  };
}

/** Zusammenfassung für Notizzettel und Auswertung. */
export function patdownResult(patdown) {
  if (!patdown) return null;
  const zones = Object.values(patdown.zones);
  const done = zones.filter((z) => z.state === 'done');
  const missed = zones.filter((z) => z.missed);
  return {
    done: patdown.complete,
    partial: done.length > 0 && !patdown.complete,
    zonesChecked: done.length,
    zonesTotal: zones.length,
    found: patdown.found,
    missed: missed.length > 0,
    text: patdown.found
      ? `GEFUNDEN: ${patdown.found.label.toUpperCase()}`
      : patdown.complete
        ? (missed.length ? 'DURCHSUCHT, ABER ETWAS ÜBERSEHEN' : 'NICHTS GEFUNDEN')
        : `${done.length}/${zones.length} ZONEN`
  };
}

/** Offene Zonen für die Anzeige. */
export function pendingZones(patdown) {
  if (!patdown) return [];
  return Object.values(patdown.zones).filter((z) => z.state !== 'done');
}

/**
 * Entscheidet, ob ein zugelassener Gast im Club einen Zwischenfall auslöst.
 */
export function incidentChance(state, guest) {
  const t = guest.truth;
  let p = t.risk * 0.35 + (t.drunk > 0.6 ? 0.15 : 0) + (t.contraband ? t.contraband.severity * 0.12 : 0);
  if (t.impaired > 0.6) p += 0.18;
  if (t.blacklisted) p += 0.25;
  p -= upgradeLevel(state, 'team') * 0.07;
  p -= upgradeLevel(state, 'cameras') * 0.05;
  return Math.max(0, Math.min(0.95, p));
}

export { ZONES };
