/**
 * Notizzettel des Spielers.
 *
 * Seite 1: Checkliste - was muss ich bei diesem Gast noch pruefen?
 *          Der Spieler hakt selbst ab, das Spiel hakt nichts fuer ihn ab.
 * Seite 2: Befund - der Spieler traegt selbst ein, welche Punkte der Norm
 *          entsprechen und welche nicht.
 *
 * Beides ist reine Spielernotiz: das Spiel bewertet sie erst nach der
 * Entscheidung ueber den Gast.
 */

import { CHECKLIST, NOTE_TOPICS } from '../data/config.js';

/** Welche Punkte gehoeren zu diesem Bereich? (Solo sieht alles.) */
export function checklistFor(area, solo = false) {
  return CHECKLIST.filter((c) => solo || c.area === area);
}

export function topicsFor(area, solo = false) {
  return NOTE_TOPICS.filter((t) => solo || t.area === area);
}

export function emptyNotes() {
  return {
    page: 0,          // 0 = Checkliste, 1 = Befund
    checked: {},      // Checklisten-Id -> true
    topics: {}        // Themen-Id -> 'ok' | 'bad'
  };
}

/** Haken setzen oder wieder entfernen. */
export function toggleCheck(notes, id) {
  if (!notes || !CHECKLIST.some((c) => c.id === id)) return null;
  if (notes.checked[id]) delete notes.checked[id];
  else notes.checked[id] = true;
  return { id, checked: !!notes.checked[id] };
}

/** Befund umschalten: leer -> entspricht der Norm -> entspricht nicht -> leer. */
export const TOPIC_CYCLE = [undefined, 'ok', 'bad'];

export function toggleTopic(notes, id) {
  if (!notes || !NOTE_TOPICS.some((t) => t.id === id)) return null;
  const idx = TOPIC_CYCLE.indexOf(notes.topics[id] ?? undefined);
  const next = TOPIC_CYCLE[(idx + 1) % TOPIC_CYCLE.length];
  if (next === undefined) delete notes.topics[id];
  else notes.topics[id] = next;
  return { id, state: next ?? null };
}

export function flipPage(notes, page) {
  if (!notes) return null;
  notes.page = page === undefined ? (notes.page === 0 ? 1 : 0) : (page ? 1 : 0);
  return notes.page;
}

/** Wie viele Punkte hat der Spieler als "entspricht nicht" eingetragen? */
export function reportedProblems(notes) {
  if (!notes) return [];
  return NOTE_TOPICS.filter((t) => notes.topics[t.id] === 'bad').map((t) => t.id);
}

export function topicLabel(id) {
  return NOTE_TOPICS.find((t) => t.id === id)?.label ?? id;
}

export function checkLabel(id) {
  return CHECKLIST.find((c) => c.id === id)?.label ?? id;
}
