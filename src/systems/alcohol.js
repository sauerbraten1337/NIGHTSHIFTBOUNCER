/**
 * Alcohol Check System: schnelle Einschätzung statt kompliziertem Minispiel.
 * Der Gast antwortet, schwankt sichtbar - der Spieler entscheidet.
 */

import { TUNING } from '../data/config.js';
import { guestLine } from './guests.js';

export function talkTo(rng, state, guest) {
  const line = guestLine(rng, guest, 'talk');
  // Der Gast nennt seinen echten Namen - Grundlage fuer den Abgleich mit dem Ausweis.
  const realName = guest.name;
  const drunk = guest.truth.drunk;
  const hint = drunk > 0.8 ? 'spricht sehr undeutlich'
    : drunk > 0.6 ? 'redet verwaschen'
      : drunk > 0.35 ? 'wirkt angetrunken' : 'wirkt klar';
  const moodHint = guest.personality === 'aggressive' ? 'sehr gereizt'
    : guest.personality === 'arrogant' ? 'fordernd'
      : guest.personality === 'nervous' ? 'nervös' : 'entspannt';
  return { line, realName, hint, moodHint, drunkGuess: drunk };
}

/** Alkoholtest: liefert einen Zahlenwert, der die Entscheidung eindeutig macht. */
export function alcoholTest(state, guest) {
  const value = guest.truth.drunk;
  return {
    value,
    promille: (value * 2.4).toFixed(1),
    overLimit: value >= TUNING.drunkRejectThreshold,
    text: value >= TUNING.drunkRejectThreshold ? 'ÜBER GRENZWERT' : 'UNTER GRENZWERT'
  };
}
