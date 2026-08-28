/**
 * Random Event System: macht jede Nacht anders.
 * Ereignisse setzen zeitlich begrenzte Effekte und/oder erzeugen Sondergaeste.
 */

import { RANDOM_EVENTS } from '../data/config.js';
import { addToast, addRadio } from './state.js';
import { changeReputation } from './reputation.js';
import { createGuest } from './guests.js';
import { insertGuest } from './queue.js';
import { weightedPick, chance, randRange } from '../core/rng.js';
import { arriveArtist } from './artists.js';

export function updateRandomEvents(game, dt, minutes) {
  const { state, rng } = game;
  const night = state.night;

  // Künstler kommt am Hintereingang an.
  if (night.artist && !night.artistArrived) {
    const arriveAt = night.artistDelayed ? 190 : 145;
    if (night.clock >= arriveAt) arriveArtist(game);
  }

  night.randomEventCooldown -= dt;
  if (night.randomEventCooldown > 0) return;

  const chaos = night.event?.chaos ? 0.6 : 1;
  night.randomEventCooldown = randRange(rng, 32, 70) * chaos;
  if (night.clock < 25 || night.clock > 270) return;
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
      addRadio(night, 'TECHNIK', 'Strom weg. Kein Licht, kein Prüfgerät.');
      bus.emit('sfx', 'alarm');
      break;
    case 'scannerFail':
      pushEffect(night, event, 25);
      addRadio(night, 'TECHNIK', 'Prüfgerät spinnt. Ohne Hinweise weitermachen.');
      bus.emit('sfx', 'beep');
      break;
    case 'rush':
      pushEffect(night, event, 12);
      addRadio(night, 'TÜR', 'Da kommt eine ganze Gruppe auf einmal.');
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
      addRadio(night, 'FUNK', 'Vorne steht jemand, den alle fotografieren.');
      break;
    }
    case 'complaint': {
      for (const g of night.queue.slice(0, 6)) g.mood = Math.max(0, g.mood - 0.35);
      addToast(night, 'DIE SCHLANGE WIRD UNRUHIG', 'warn');
      addRadio(night, 'SCHLANGE', 'Leute beschweren sich über die Wartezeit.');
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
        addRadio(night, 'BOOKING', `${night.artist.name} kommt später.`);
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
