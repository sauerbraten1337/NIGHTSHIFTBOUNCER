/**
 * Gespräch und Alkoholtest.
 *
 * Das Testgerät zeigt nur eine Zahl. Ob die noch in Ordnung ist, liest der
 * Spieler am aufgedruckten Grenzwert ab - und ein niedriger Promillewert heisst
 * nicht, dass jemand nüchtern ist: dafür gibt es die sichtbaren Anzeichen.
 */

import { TUNING, ALCOHOL_LIMIT_PROMILLE, IMPAIRMENT_SIGNS } from '../data/config.js';
import { guestLine } from './guests.js';

export function talkTo(rng, state, guest) {
  const line = guestLine(rng, guest, 'talk');
  const realName = guest.name;
  const drunk = guest.truth.drunk;
  const impaired = guest.truth.impaired ?? 0;

  const hint = drunk > 0.8 ? 'spricht sehr undeutlich'
    : drunk > 0.6 ? 'redet verwaschen'
      : drunk > 0.35 ? 'wirkt angetrunken' : 'spricht klar';

  // Substanzeinfluss klingt anders als Alkohol.
  const stateHint = impaired > 0.7 ? 'redet auffällig schnell und sprunghaft'
    : impaired > 0.45 ? 'antwortet verzögert, wirkt abwesend'
      : null;

  const moodHint = guest.personality === 'aggressive' ? 'sehr gereizt'
    : guest.personality === 'arrogant' ? 'fordernd'
      : guest.personality === 'nervous' ? 'nervös' : 'entspannt';

  return { line, realName, hint, stateHint, moodHint, drunkGuess: drunk };
}

/**
 * Alkoholtest: liefert die Anzeige des Geräts.
 * Bewusst ohne Urteil - der Grenzwert steht auf dem Gerät.
 */
export function alcoholTest(state, guest) {
  const value = guest.truth.drunk;
  const promille = Number((value * 2.4).toFixed(1));
  const impaired = guest.truth.impaired ?? 0;

  return {
    value,
    promille,
    limit: ALCOHOL_LIMIT_PROMILLE,
    overLimit: value >= TUNING.drunkRejectThreshold,
    /** Das Gerät misst nur Alkohol - Auffälligkeiten muss man sehen. */
    deviceNote: impaired > 0.45 && promille < ALCOHOL_LIMIT_PROMILLE
      ? 'WERT NIEDRIG — VERHALTEN BEACHTEN'
      : null,
    text: `${promille.toFixed(1)} ‰`
  };
}

/** Welche Anzeichen sind an diesem Gast sichtbar? */
export function visibleImpairment(guest) {
  const ids = guest.truth.impairmentSigns ?? [];
  return IMPAIRMENT_SIGNS.filter((s) => ids.includes(s.id));
}

export function impairmentLabels(guest) {
  return visibleImpairment(guest).map((s) => s.label);
}
