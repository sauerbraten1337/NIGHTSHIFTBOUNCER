/**
 * Security System: körperliche Kontrolle.
 *
 * Ablauf, bewusst abstrakt und ohne Gewaltdarstellung:
 *   1. Abtasten starten - die Zonen werden markiert (Jacke, Hosentaschen, Tasche)
 *   2. Eine Zone wählen -> der Gast leert sie aus (bei der Tasche holt er sie
 *      erst hervor), die Sachen kommen gross auf den Tisch
 *   3. Der Spieler markiert selbst, was nicht in den Club darf, und schliesst
 *      die Zone ab. Das Spiel sagt nicht, ob er richtig lag - zwischen
 *      Kaugummi und Klinge liegt sein Auge.
 */

import { ZONES } from '../data/config.js';
import { upgradeLevel } from './state.js';

export const ZONE_IDS = ZONES.map((z) => z.id);

export function zonesFor(guest) {
  return ZONES.filter((z) => guest.truth.zoneIds.includes(z.id));
}

export function startPatdown(state, guest) {
  const zones = {};
  for (const zone of zonesFor(guest)) {
    zones[zone.id] = {
      id: zone.id,
      label: zone.label,
      state: 'closed',      // closed | open | done
      openTimer: 0,
      items: null,          // erst beim Öffnen sichtbar
      flagged: [],          // vom Spieler beanstandete Gegenstände (Item-Ids)
      picked: null          // erster beanstandeter Gegenstand, für die Anzeige
    };
  }

  return {
    guestId: guest.id,
    zones,
    order: Object.keys(zones),
    active: null,           // aktuell geöffnete Zone
    complete: false,
    bagOut: false           // die Tasche ist hervorgeholt
  };
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
 * Der Spieler markiert einen Gegenstand als nicht regelkonform - oder nimmt
 * die Markierung wieder zurueck. Es gibt keine Rueckmeldung, ob er richtig lag.
 * itemId = null schliesst die Zone ab (siehe closeZone).
 */
export function pickItem(patdown, guest, zoneId, itemId) {
  const zone = patdown?.zones[zoneId];
  if (!zone || zone.state !== 'open') return null;
  if (itemId === null) return closeZone(patdown, zoneId);

  const item = (zone.items ?? []).find((i) => i.id === itemId);
  if (!item) return null;

  const at = zone.flagged.indexOf(item.id);
  if (at >= 0) zone.flagged.splice(at, 1);
  else zone.flagged.push(item.id);
  zone.picked = zone.flagged.length ? (zone.items ?? []).find((i) => i.id === zone.flagged[0]) : null;

  return { zone: zoneId, item, flagged: at < 0, flaggedIds: [...zone.flagged] };
}

/** Zone abschliessen - mit oder ohne Beanstandung. */
export function closeZone(patdown, zoneId) {
  const zone = patdown?.zones[zoneId];
  if (!zone || zone.state !== 'open') return null;
  zone.state = 'done';
  patdown.active = null;
  patdown.complete = Object.values(patdown.zones).every((z) => z.state === 'done');
  return { zone: zoneId, closed: true, flaggedIds: [...zone.flagged] };
}

/** Alle vom Spieler beanstandeten Gegenstände. */
export function flaggedItems(patdown) {
  if (!patdown) return [];
  const out = [];
  for (const zone of Object.values(patdown.zones)) {
    for (const id of zone.flagged) {
      const item = (zone.items ?? []).find((i) => i.id === id);
      if (item) out.push({ zone: zone.id, item });
    }
  }
  return out;
}

/**
 * Auswertung NACH der Entscheidung: Treffer, Fehlgriffe, Übersehenes.
 */
export function scorePatdown(patdown, guest) {
  const flagged = flaggedItems(patdown);
  const hits = flagged.filter((f) => f.item.forbidden);
  const wrong = flagged.filter((f) => !f.item.forbidden);
  const seenIds = new Set(flagged.map((f) => f.item.id));
  const missed = [];
  for (const zone of Object.values(patdown?.zones ?? {})) {
    if (zone.state !== 'done') continue;
    for (const item of zone.items ?? []) {
      if (item.forbidden && !seenIds.has(item.id)) missed.push({ zone: zone.id, item });
    }
  }
  return { hits, wrong, missed };
}

/** Zusammenfassung für Notizzettel (nur die Angaben des Spielers). */
export function patdownResult(patdown) {
  if (!patdown) return null;
  const zones = Object.values(patdown.zones);
  const done = zones.filter((z) => z.state === 'done');
  const flagged = flaggedItems(patdown);
  return {
    done: patdown.complete,
    partial: done.length > 0 && !patdown.complete,
    zonesChecked: done.length,
    zonesTotal: zones.length,
    flagged,
    text: flagged.length
      ? `BEANSTANDET: ${flagged.map((f) => f.item.label.toUpperCase()).join(', ')}`
      : patdown.complete
        ? 'NICHTS BEANSTANDET'
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
