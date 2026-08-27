/**
 * Identity System: Ausweiskontrolle.
 * Der Spieler sieht das Dokument; welche Fehler er tatsaechlich erkennt,
 * haengt vom Scanner-Upgrade und vom Talent "Street Smarts" ab.
 */

import { upgradeLevel } from './state.js';
import { TUNING, ID_ISSUES } from '../data/config.js';

const ISSUE_LABEL = Object.fromEntries(ID_ISSUES.map((i) => [i.id, i.label]));

/**
 * Fuehrt die manuelle Ausweispruefung aus.
 * Ergebnis enthaelt die sichtbaren Dokumentdaten und - je nach Ausruestung -
 * automatisch erkannte Auffälligkeiten.
 */
export function checkId(state, guest) {
  const scanner = upgradeLevel(state, 'scanner');
  const street = state.talents.street;
  const issues = guest.truth.idIssues;

  // Welche Probleme werden dem Spieler direkt angezeigt?
  const detected = [];
  for (const issue of issues) {
    if (issue === 'expired') detected.push(issue);              // Datum ist immer lesbar
    else if (issue === 'age') detected.push(issue);             // Geburtsdatum ist lesbar
    else if (issue === 'name' && (scanner >= 1 || street >= 1)) detected.push(issue);
    else if (issue === 'photo' && (scanner >= 1 || street >= 2)) detected.push(issue);
    else if (issue === 'marks' && (scanner >= 1 || street >= 3)) detected.push(issue);
  }

  const docTooYoung = guest.doc.age < TUNING.minAge;
  const expired = issues.includes('expired');

  return {
    ok: detected.length === 0 && !docTooYoung,
    doc: guest.doc,
    detected,
    detectedLabels: detected.map((d) => ISSUE_LABEL[d] ?? d),
    docTooYoung,
    expired,
    /** Wahrheit für die spätere Auswertung der Koop-Verifikation. */
    truthValid: guest.truth.idValid && !guest.truth.underage,
    hiddenIssues: issues.filter((i) => !detected.includes(i)).length
  };
}

/** Kurztext für HUD/Funk. */
export function idSummary(result) {
  if (result.docTooYoung) return 'ZU JUNG LAUT DOKUMENT';
  if (result.detected.length === 0) return 'AUSWEIS OK';
  return result.detectedLabels.join(' / ').toUpperCase();
}
