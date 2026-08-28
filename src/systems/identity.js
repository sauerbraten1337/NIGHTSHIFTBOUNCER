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
 * Ein Feld anklicken heisst: "hier stimmt etwas nicht".
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
  const scanner = upgradeLevel(state, 'scanner');
  const street = state.talents.street;
  const faults = faultyFields(guest);

  // Ausruestung und Talent geben Hinweise - nehmen die Prüfung aber nicht ab.
  let hint = null;
  let hintLevel = 0;
  if (faults.size > 0) {
    if (scanner >= 3 || street >= 3) { hint = [...faults][0]; hintLevel = 2; }
    else if (scanner >= 2 || street >= 2) { hint = [...faults][0]; hintLevel = 1; }
    else if (scanner >= 1 || street >= 1) { hint = 'any'; hintLevel = 1; }
  }

  return {
    requested: true,
    doc: guest.doc,
    guestId: guest.id,
    marks: {},          // vom Spieler markierte Felder -> 'hit' | 'miss'
    found: [],          // korrekt gefundene Verstoesse
    wrong: 0,           // Fehlgriffe
    hint,               // null | 'any' | Feld-Id
    hintLevel,
    closed: false,
    /** Wahrheit, erst nach der Entscheidung fuer die Auswertung genutzt. */
    faults: [...faults]
  };
}

/**
 * Der Spieler markiert ein Feld als auffaellig.
 * Gibt zurueck, ob der Verdacht stimmte.
 */
export function markField(inspection, guest, field) {
  if (!inspection || inspection.marks[field]) return { already: true };
  const faults = faultyFields(guest);
  const correct = faults.has(field);
  inspection.marks[field] = correct ? 'hit' : 'miss';
  if (correct) {
    if (!inspection.found.includes(field)) inspection.found.push(field);
  } else {
    inspection.wrong++;
  }
  return { already: false, correct, field, label: fieldLabel(field), reason: reasonFor(guest, field) };
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

/** Was weiss der Spieler nach seiner Prüfung? */
export function inspectionVerdict(inspection) {
  if (!inspection) return { checked: false, clean: null, found: [] };
  return {
    checked: true,
    found: inspection.found,
    /** "sauber" heisst hier: der Spieler hat nichts gefunden. */
    clean: inspection.found.length === 0,
    wrong: inspection.wrong
  };
}

export function idSummary(inspection) {
  if (!inspection) return 'NICHT GEPRÜFT';
  if (inspection.found.length === 0) return 'KEINE AUFFÄLLIGKEIT MARKIERT';
  return inspection.found.map(fieldLabel).join(' / ');
}

export function issueLabel(id) {
  return ISSUE_LABEL[id] ?? id;
}
