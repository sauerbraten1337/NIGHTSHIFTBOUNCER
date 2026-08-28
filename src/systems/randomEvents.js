/**
 * Random Event System: macht jede Nacht anders.
 * Ereignisse setzen zeitlich begrenzte Effekte und/oder erzeugen Sondergaeste.
 */

import { RANDOM_EVENTS } from '../data/config.js';
import { addToast } from './state.js';
import { changeReputation } from './reputation.js';
import { createGuest } from './guests.js';
import { insertGuest } from './queue.js';
import { weightedPick, chance, randRange } from '../core/rng.js';
import { arriveArtist } from './artists.js';

/** Anteil der abgearbeiteten Schicht (lokal, um Zirkelimporte zu vermeiden). */
function shiftProgress(night) {
  if (!night?.quota) return 0;
  return Math.min(1, night.processed / night.quota);
}

export function updateRandomEvents(game, dt, minutes) {
  const { state, rng } = game;
  const night = state.night;

  const progress = shiftProgress(night);

  // Künstler kommt am Hintereingang an - abhaengig vom Schichtfortschritt.
  if (night.artist && !night.artistArrived) {
    const arriveAt = night.artistDelayed ? 0.62 : 0.45;
    if (progress >= arriveAt) arriveArtist(game);
  }

  night.randomEventCooldown -= dt;
  if (night.randomEventCooldown > 0) return;

  const chaos = night.event?.chaos ? 0.6 : 1;
  night.randomEventCooldown = randRange(rng, 32, 70) * chaos;
  if (progress < 0.08 || progress > 0.9) return;
  if (!chance(rng, 0.72)) return;

  const event = weightedPick(rng, RANDOM_EVENTS);
  triggerRandomEvent(game, event);
}

export function triggerRandomEvent(game, event) {
  const { state, rng, bus } = game;
  const night = state.night;

  switch (event.id) {
    case 'blackout':
      pushEffect(night, event, 16);
      addToast(night, 'STROM WEG - KEIN LICHT, KEIN PRÜFGERÄT', 'bad', 5);
      bus.emit('sfx', 'alarm');
      break;
    case 'scannerFail':
      pushEffect(night, event, 25);
      addToast(night, 'PRÜFGERÄT SPINNT - OHNE HINWEISE WEITER', 'warn', 5);
      bus.emit('sfx', 'beep');
      break;
    case 'rush':
      pushEffect(night, event, 12);
      addToast(night, 'EINE GANZE GRUPPE AUF EINMAL', 'warn', 4);
      break;
    case 'celebrity': {
      const guest = createGuest(rng, {
        event: night.event, reputation: state.reputation,
        nightIndex: state.nightIndex, forceArchetype: 'vip'
      });
      guest.celebrity = true;
      guest.name = `${guest.name}`;
      insertGuest(game, guest, true);
      addToast(night, 'UNERWARTETER GAST VORNE', 'warn');
      break;
    }
    case 'complaint': {
      for (const g of night.queue.slice(0, 6)) g.mood = Math.max(0, g.mood - 0.35);
      addToast(night, 'DIE SCHLANGE WIRD UNRUHIG', 'warn');
      break;
    }
    case 'influencerPost':
      pushEffect(night, event, 45);
      changeReputation(state, 2.5, 'viral');
      addToast(night, 'DER CLUB GEHT VIRAL', 'good');
      break;
    case 'artistLate':
      if (night.artist && !night.artistArrived) {
        night.artistDelayed = true;
        addToast(night, `${night.artist.name.toUpperCase()} KOMMT SPÄTER`, 'warn', 4);
      }
      break;
    case 'fakePass': {
      const guest = createGuest(rng, {
        event: night.event, reputation: state.reputation,
        nightIndex: state.nightIndex, forceArchetype: 'crew'
      });
      guest.truth.idIssues = ['name'];
      guest.truth.idValid = false;
      guest.doc.name = 'CREW / UNBEKANNT';
      guest.fakeCrew = true;
      insertGuest(game, guest, true);
      addToast(night, 'ANGEBLICHES CREW-MITGLIED', 'warn');
      break;
    }
    default:
      break;
  }

  night.lastEvent = { label: event.label, desc: event.desc, life: 5 };
  bus.emit('randomEvent', event);
}

function pushEffect(night, event, duration) {
  if (night.activeEffects.some((e) => e.id === event.id)) return;
  night.activeEffects.push({ id: event.id, label: event.label, remaining: duration, total: duration });
  addToast(night, event.label, 'warn', 4);
}
