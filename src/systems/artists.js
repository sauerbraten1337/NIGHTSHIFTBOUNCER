/**
 * Artist System: fiktive Acts buchen, Gage zahlen - und der Running Gag:
 * auch der Headliner muss durch die Kontrolle.
 */

import { ARTISTS } from '../data/config.js';
import { upgradeLevel, addToast, addRadio } from './state.js';
import { changeReputation } from './reputation.js';
import { createGuest } from './guests.js';
import { insertGuest } from './queue.js';
import { ARTIST_LINES } from '../data/dialogue.js';
import { pick } from '../core/rng.js';

/** Welche Acts sind bei aktuellem Ruf/Backstage buchbar? */
export function availableArtists(state) {
  const backstage = upgradeLevel(state, 'backstage');
  if (backstage < 1) return [];
  const maxPop = backstage >= 2 ? 7 : 4;
  const repGate = state.reputation / 100 * 7 + 1.5;
  return ARTISTS.filter((a) => a.pop <= maxPop && a.pop <= repGate);
}

export function bookArtist(state, artistId) {
  const artist = ARTISTS.find((a) => a.id === artistId);
  if (!artist) return { ok: false, reason: 'Act unbekannt' };
  if (state.money < artist.fee) return { ok: false, reason: 'Nicht genug Geld' };
  state.bookedArtist = artist;
  return { ok: true, artist };
}

export function cancelBooking(state) {
  state.bookedArtist = null;
}

/** Der Act trifft am Hintereingang ein und wird als Sondergast eingereiht. */
export function arriveArtist(game) {
  const { state, rng } = game;
  const night = state.night;
  if (!night.artist || night.artistArrived) return null;

  const guest = createGuest(rng, {
    event: night.event, reputation: state.reputation, nightIndex: state.nightIndex,
    forceArchetype: 'crew'
  });
  guest.name = night.artist.name;
  guest.isArtist = true;
  guest.backstage = true;
  guest.archetypeLabel = 'Künstler';
  guest.personality = 'arrogant';
  guest.truth.vip = true;
  guest.truth.spend = 0;
  guest.truth.contraband = null;
  guest.truth.contrabandZone = null;
  guest.truth.underage = false;
  guest.truth.age = Math.max(24, guest.truth.age);
  guest.truth.idIssues = [];
  guest.truth.idValid = true;
  guest.truth.blacklisted = false;
  guest.truth.drunk = Math.min(guest.truth.drunk, 0.3);
  guest.doc.name = night.artist.name;
  guest.doc.age = guest.truth.age;
  guest.doc.photoMatch = true;
  guest.doc.marks = true;
  guest.patience = guest.patienceMax = 70;
  guest.artistBanter = pick(rng, ARTIST_LINES);

  insertGuest(game, guest, true);
  night.artistArrived = true;
  night.artistGuestId = guest.id;
  addToast(night, `${night.artist.name} IST DA`, 'good', 5);
  addRadio(night, 'BACKSTAGE', `${night.artist.name} steht am Hintereingang.`);
  game.bus.emit('sfx', 'radio');
  return guest;
}

/** Wird aufgerufen, wenn ein Künstler-Gast eine Entscheidung erhaelt. */
export function resolveArtistDecision(game, guest, admitted) {
  const { state } = game;
  const night = state.night;
  if (!guest.isArtist) return;
  night.artistHandled = true;
  if (admitted) {
    const rep = 3 + night.artist.pop * 1.2;
    changeReputation(state, rep, 'Act spielt');
    night.artistPlaying = true;
    addToast(night, `${night.artist.name} SPIELT HEUTE`, 'good', 5);
    addRadio(night, 'FLOOR', 'Der Floor dreht durch.');
  } else {
    changeReputation(state, -6, 'Act abgewiesen');
    addToast(night, 'DU HAST DEN HEADLINER ABGEWIESEN', 'bad', 6);
    addRadio(night, 'BOOKING', 'Das war der Act. Der Act. Ernsthaft?');
  }
}

/** Umsatz-Multiplikator, solange der Act spielt. */
export function artistSpendBonus(night) {
  if (!night?.artist) return 1;
  return night.artistPlaying ? night.artist.spend : 1;
}
