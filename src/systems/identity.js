/**
 * Identity System: Ausweiskontrolle von Hand.
 *
 * Das Spiel deckt Fehler NICHT mehr automatisch auf. Der Gast reicht das
 * Dokument herüber, der Spieler sieht es gross vor sich und vergleicht selbst:
 *
 *   FOTO        gegen das Gesicht des Gastes
 *   NAME        gegen das, was der Gast beim Ansprechen sagt
 *   GEBURTSTAG  gegen das heutige Datum (Mindestalter) und auf Manipulation
 *   GÜLTIG BIS  gegen das heutige Datum
 *   MERKMALE    Hologramm vorhanden und sauber?
 *
 * Ein Feld anklicken schaltet den Status um, den der Spieler dem Feld gibt:
 *   unbewertet -> NICHT KORREKT -> IN ORDNUNG -> unbewertet
 *
 * Das Spiel sagt zu keinem Zeitpunkt, ob die Einschaetzung stimmt. Erst in der
 * Auswertung nach der Entscheidung wird verglichen.
 */

import { GAME_DATE, TUNING, ID_ISSUES } from '../data/config.js';
import { upgradeLevel } from './state.js';

const ISSUE_LABEL = Object.fromEntries(ID_ISSUES.map((i) => [i.id, i.label]));

/** Die prüfbaren Felder des Dokuments. */
export const ID_FIELDS = [
  { id: 'photo', label: 'FOTO', hint: 'Passt das Foto zum Gast?' },
  { id: 'name', label: 'NAME', hint: 'Stimmt der Name mit der Aussage?' },
  { id: 'birth', label: 'GEBURTSDATUM', hint: 'Alt genug? Datum unverändert?' },
  { id: 'expiry', label: 'GÜLTIG BIS', hint: 'Noch gültig?' },
  { id: 'marks', label: 'MERKMALE', hint: 'Hologramm und Prägung vorhanden?' }
];

export const TODAY = GAME_DATE;

export function todayString() {
  return `${GAME_DATE.year}-${pad(GAME_DATE.month)}-${pad(GAME_DATE.day)}`;
}

function pad(n) {
  return String(n).padStart(2, '0');
}

export function parseDate(str) {
  const [y, m, d] = String(str).split('-').map(Number);
  return { year: y, month: m, day: d };
}

export function dateBefore(a, b) {
  if (a.year !== b.year) return a.year < b.year;
  if (a.month !== b.month) return a.month < b.month;
  return a.day < b.day;
}

/** Alter am heutigen Spieldatum, berechnet aus dem Geburtsdatum. */
export function ageFromBirth(birthStr) {
  const b = parseDate(birthStr);
  let age = GAME_DATE.year - b.year;
  if (GAME_DATE.month < b.month || (GAME_DATE.month === b.month && GAME_DATE.day < b.day)) age--;
  return age;
}

/**
 * Welche Felder sind objektiv fehlerhaft?
 * Das ist die Wahrheit - der Spieler muss sie selbst finden.
 */
export function faultyFields(guest) {
  const issues = guest.truth.idIssues ?? [];
  const fields = new Set();
  if (issues.includes('photo')) fields.add('photo');
  if (issues.includes('name')) fields.add('name');
  if (issues.includes('marks')) fields.add('marks');
  if (issues.includes('expired')) fields.add('expiry');
  if (issues.includes('age')) fields.add('birth');
  // Ein ehrliches Dokument, das ein zu junges Alter zeigt, ist ebenfalls ein Treffer.
  if (ageFromBirth(guest.doc.birth) < TUNING.minAge) fields.add('birth');
  return fields;
}

/** Der Gast reicht den Ausweis herüber. */
export function requestId(state, guest) {
  const offline = toolOffline(state.night);
  return {
    requested: true,
    doc: guest.doc,
    guestId: guest.id,
    /** Einschaetzung des Spielers je Feld: undefined | 'suspect' | 'fine' */
    marks: {},
    toolOffline: offline,
    closed: false,
    /** Wahrheit, erst nach der Entscheidung fuer die Auswertung genutzt. */
    faults: [...faultyFields(guest)]
  };
}

/** Der Reihe nach: unbewertet -> nicht korrekt -> in Ordnung -> unbewertet. */
export const MARK_CYCLE = [undefined, 'suspect', 'fine'];

/**
 * Der Spieler schaltet den Status eines Feldes um.
 * Es gibt keine Rueckmeldung, ob die Einschaetzung stimmt.
 */
export function toggleField(inspection, field) {
  if (!inspection) return null;
  if (!ID_FIELDS.some((f) => f.id === field)) return null;
  const idx = MARK_CYCLE.indexOf(inspection.marks[field] ?? undefined);
  const next = MARK_CYCLE[(idx + 1) % MARK_CYCLE.length];
  if (next === undefined) delete inspection.marks[field];
  else inspection.marks[field] = next;
  return { field, label: fieldLabel(field), state: next ?? null };
}

/** Welche Felder hat der Spieler als "nicht korrekt" markiert? */
export function claimedFaults(inspection) {
  if (!inspection) return [];
  return ID_FIELDS.map((f) => f.id).filter((id) => inspection.marks[id] === 'suspect');
}

/** Welche Felder hat der Spieler ueberhaupt bewertet? */
export function ratedFields(inspection) {
  if (!inspection) return [];
  return ID_FIELDS.map((f) => f.id).filter((id) => inspection.marks[id]);
}

/**
 * Auswertung NACH der Entscheidung: was hat der Spieler richtig erkannt,
 * was hat er zu Unrecht beanstandet, was hat er uebersehen?
 */
export function scoreInspection(inspection, guest) {
  const faults = faultyFields(guest);
  const claimed = claimedFaults(inspection);
  const hits = claimed.filter((f) => faults.has(f));
  const wrong = claimed.filter((f) => !faults.has(f));
  const missed = [...faults].filter((f) => !claimed.includes(f));
  return { hits, wrong, missed };
}

export function fieldLabel(field) {
  return ID_FIELDS.find((f) => f.id === field)?.label ?? field.toUpperCase();
}

/** Klartext, warum ein Feld falsch ist (fuer Feedback nach dem Markieren). */
export function reasonFor(guest, field) {
  const issues = guest.truth.idIssues ?? [];
  switch (field) {
    case 'photo': return issues.includes('photo') ? 'Foto passt nicht zum Gast' : null;
    case 'name': return issues.includes('name') ? 'Name weicht von der Aussage ab' : null;
    case 'marks': return issues.includes('marks') ? 'Sicherheitsmerkmale fehlen' : null;
    case 'expiry': return issues.includes('expired') ? 'Dokument ist abgelaufen' : null;
    case 'birth':
      if (issues.includes('age')) return 'Geburtsdatum wurde manipuliert';
      if (ageFromBirth(guest.doc.birth) < TUNING.minAge) return 'Zu jung laut Dokument';
      return null;
    default: return null;
  }
}

/** Was hat der Spieler selbst angegeben? (Keine Wahrheit, nur seine Angabe.) */
export function inspectionVerdict(inspection) {
  if (!inspection) return { checked: false, clean: null, claimed: [], rated: 0 };
  const claimed = claimedFaults(inspection);
  return {
    checked: true,
    claimed,
    rated: ratedFields(inspection).length,
    /** "sauber" heisst hier: der Spieler hat nichts beanstandet. */
    clean: claimed.length === 0
  };
}

export function idSummary(inspection) {
  if (!inspection) return 'NICHT GEPRÜFT';
  const claimed = claimedFaults(inspection);
  if (claimed.length === 0) {
    return ratedFields(inspection).length ? 'ALLES IN ORDNUNG (EIGENE ANGABE)' : 'NOCH NICHTS BEWERTET';
  }
  return claimed.map(fieldLabel).join(' / ');
}

/** Bezeichnung des Prüfgeräts (früher der Scanner). */
export function docToolLabel(level) {
  return ['SICHTPRÜFUNG', 'UV-LAMPE', 'SCHNELLPRÜFUNG', 'FEINANALYSE'][level] ?? 'SICHTPRÜFUNG';
}

/** Fällt das Gerät gerade aus? */
export function toolOffline(night) {
  return !!night?.activeEffects?.some((e) => e.id === 'scannerFail' || e.id === 'blackout');
}

export function issueLabel(id) {
  return ISSUE_LABEL[id] ?? id;
}
