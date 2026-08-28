/**
 * Tutorial: eine ruhige erste Schicht, die alles nacheinander erklärt.
 *
 * Statt einer Textwand kommt jede Mechanik mit genau einem Gast, an dem man
 * sie ausprobiert. Erst wenn der Schritt sitzt, geht es weiter - und erst dann
 * wird die nächste Mechanik überhaupt freigeschaltet.
 */

import { createGuest } from './guests.js';
import { insertGuest } from './queue.js';
import { addToast, addRadio, isSolo } from './state.js';
import { ITEMS, ZONES, itemById } from '../data/config.js';

/** Baut einen Gast mit genau den Eigenschaften, die der Schritt zeigen soll. */
function scripted(game, spec = {}) {
  const guest = createGuest(game.rng, {
    reputation: game.state.reputation,
    nightIndex: 0,
    forceArchetype: spec.archetype ?? 'regular'
  });

  // Standard: sauber und unauffällig.
  guest.truth.idIssues = [];
  guest.truth.idValid = true;
  guest.truth.underage = false;
  guest.truth.age = 24 + (guest.seed % 12);
  guest.truth.drunk = 0.1;
  guest.truth.risk = 0.05;
  guest.truth.blacklisted = false;
  guest.truth.contraband = null;
  guest.truth.contrabandZone = null;
  guest.truth.impaired = 0;
  guest.truth.impairmentSigns = [];
  // Saubere, überschaubare Taschen: nur harmlose Sachen.
  guest.truth.hasBag = !!spec.bag;
  guest.truth.zoneIds = ZONES.filter((z) => !z.needsBag || spec.bag).map((z) => z.id);
  guest.truth.carried = {
    jacket: [itemById('phone'), itemById('lighter')].filter(Boolean),
    pockets: [itemById('keys'), itemById('gum')].filter(Boolean),
    ...(spec.bag ? { bag: [itemById('bottle'), itemById('charger')].filter(Boolean) } : {})
  };
  guest.doc.name = guest.name;
  guest.doc.tampered = false;
  guest.doc.marksOk = true;
  guest.doc.photoLook = { ...guest.look };
  guest.doc.birth = birthFor(guest.truth.age);
  guest.doc.expiry = '2031-06-30';
  guest.personality = spec.personality ?? 'polite';
  guest.patience = guest.patienceMax = 999;

  spec.build?.(guest);
  guest.tutorial = spec.id ?? true;
  return guest;
}

function birthFor(age) {
  // Immer vor dem 14. März, damit das Alter exakt aufgeht.
  return `${2026 - age}-01-12`;
}

const STEPS = [
  {
    id: 'welcome',
    title: 'SCHICHTBEGINN',
    body: 'Du stehst an der Tür des NULLWERK. Vor dir die Strasse, hinter dir der Club. ' +
      'Was du reinlässt, ist deine Verantwortung. Der erste Gast kommt gleich.',
    setup(game) {
      addRadio(game.state.night, 'CHEF', 'Erste Schicht. Nimm dir Zeit, heute ist wenig los.');
    },
    wait: (game, elapsed) => elapsed > 3.5
  },
  {
    id: 'spawn1',
    title: 'ERSTER GAST',
    body: 'Ein Gast steht vor dir. Sieh ihn dir an: Haltung, Gesicht, Zustand. ' +
      'Verlange als Erstes den Ausweis.',
    hint: ['1', 'AUSWEIS VERLANGEN'],
    setup(game) {
      insertGuest(game, scripted(game, { id: 'clean' }));
    },
    wait: (game) => !!doorChecks(game)?.id
  },
  {
    id: 'inspect1',
    title: 'SELBST PRÜFEN',
    body: 'Der Ausweis liegt links unten - gross und lesbar. Prüfe ihn selbst: ' +
      'Passt das Foto zum Gast? Ist er alt genug? Ist das Dokument noch gültig? ' +
      'Ein Klick auf ein Feld beanstandet es. Hier ist alles in Ordnung.',
    wait: (game, elapsed) => elapsed > 6
  },
  {
    id: 'admit1',
    title: 'ENTSCHEIDEN',
    body: (game) => isSolo(game.state)
      ? 'Sauberer Ausweis, nüchterner Gast: lass ihn rein.'
      : 'Sauberer Ausweis: schick ihn weiter in die Schleuse. Die Security macht dort den Rest.',
    hint: (game) => isSolo(game.state) ? ['E', 'EINLASSEN'] : ['E', 'DURCHLASSEN'],
    wait: (game) => decisions(game) >= 1
  },
  {
    id: 'expired',
    title: 'ABGELAUFEN',
    body: 'Nächster Gast. Sieh dir "GÜLTIG BIS" genau an und vergleiche es mit dem heutigen Datum ' +
      'oben auf der Karte. Wenn etwas nicht stimmt: Feld anklicken, dann abweisen.',
    hint: ['X', 'ABWEISEN'],
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'expired', personality: 'annoyed',
        build: (g) => { g.truth.idIssues = ['expired']; g.truth.idValid = false; g.doc.expiry = '2023-08-19'; }
      }));
    },
    wait: (game) => decisions(game) >= 2
  },
  {
    id: 'age',
    title: 'ZU JUNG',
    body: 'Rechne beim Geburtsdatum mit. Neben dem Datum steht das errechnete Alter - ' +
      'aber verlass dich nicht blind darauf, manche Dokumente sind manipuliert.',
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'underage', personality: 'nervous',
        build: (g) => {
          g.truth.age = 16;
          g.truth.underage = true;
          g.doc.birth = birthFor(16);
        }
      }));
    },
    wait: (game) => decisions(game) >= 3
  },
  {
    id: 'talkUnlock',
    title: 'ANSPRECHEN FREIGESCHALTET',
    body: 'Manche Ausweise gehören jemand anderem. Sprich den Gast an - er nennt seinen Namen. ' +
      'Stimmt der nicht mit dem Dokument überein, hast du ihn.',
    hint: ['2', 'ANSPRECHEN'],
    unlock: 'talk',
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'name', personality: 'arrogant',
        build: (g) => {
          g.truth.idIssues = ['name'];
          g.truth.idValid = false;
          g.doc.name = 'Kaspar Novak';
        }
      }));
      addToast(game.state.night, 'NEU: ANSPRECHEN (2)', 'good', 4);
    },
    wait: (game) => decisions(game) >= 4
  },
  {
    id: 'photo',
    title: 'FOTO VERGLEICHEN',
    body: 'Der wichtigste Handgriff: Foto auf der Karte gegen das Gesicht vor dir. ' +
      'Haare, Hautton, Gesichtsform. Wenn es nicht passt, ist es nicht sein Ausweis.',
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'photo',
        build: (g) => {
          g.truth.idIssues = ['photo'];
          g.truth.idValid = false;
          g.doc.photoLook = { ...g.look, skin: (g.look.skin + 3) % 6, hair: (g.look.hair + 4) % 7 };
        }
      }));
    },
    wait: (game) => decisions(game) >= 5
  },
  {
    id: 'marks',
    title: 'SICHERHEITSMERKMALE',
    body: 'Echte Dokumente haben drei Hologramm-Marken. Fehlen sie oder sind sie matt, ' +
      'ist die Karte gefälscht.',
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'marks',
        build: (g) => {
          g.truth.idIssues = ['marks'];
          g.truth.idValid = false;
          g.doc.marksOk = false;
        }
      }));
    },
    wait: (game) => decisions(game) >= 6
  },
  {
    id: 'security',
    title: (game) => isSolo(game.state) ? 'KONTROLLE' : 'DIE SCHLEUSE',
    body: (game) => isSolo(game.state)
      ? 'Ein sauberer Ausweis heisst nicht, dass alles sauber ist. Taste den Gast ab (3) und ' +
        'wähle eine Zone: J Jacke, K Hosentaschen, L Tasche - er holt sie hervor und leert sie aus. ' +
        'Klick auf das, was nicht reindarf. Der Alkotest (4) zeigt nur den Wert; ' +
        'den Grenzwert liest du am Gerät ab.'
      : 'Alles, was du durchlässt, landet in der Schleuse - innen, aber noch nicht im Club. ' +
        'Dort tastet die Security ab (7, Zonen J/K/L) und testet auf Alkohol (8). ' +
        'Was aus einer Zone kommt, liegt gross auf dem Tisch: anklicken, was nicht reindarf. ' +
        'Erst die Security entscheidet mit ENTER über den Einlass.',
    unlock: ['search', 'alcohol'],
    setup(game) {
      insertGuest(game, scripted(game, {
        id: 'contraband', personality: 'nervous', bag: true,
        build: (g) => {
          const spray = ITEMS.find((i) => i.id === 'spray');
          g.truth.contraband = spray;
          g.truth.contrabandZone = 'bag';
          g.truth.carried.bag = [itemById('bottle'), spray, itemById('mints')].filter(Boolean);
          g.truth.items = Object.values(g.truth.carried).flat();
          g.truth.risk = 0.6;
        }
      }));
      addToast(game.state.night, 'NEU: SCAN · ABTASTEN · ALKOTEST', 'good', 5);
    },
    wait: (game) => decisions(game) >= 7
  },
  {
    id: 'queue',
    title: 'DIE SCHLANGE WARTET',
    body: (game) => 'Jede Kontrolle kostet Zeit, und die Leute draussen werden ungeduldig. ' +
      'Wer zu lange steht, geht - das kostet Umsatz und Ruf. Mit der Taste ' +
      (isSolo(game.state) ? '6' : '3') + ' redest du mit der Schlange und verschaffst dir Luft.',
    hint: (game) => [isSolo(game.state) ? '6' : '3', 'SCHLANGE BERUHIGEN'],
    unlock: 'calm',
    setup(game) {
      const night = game.state.night;
      night.tutorial.blockSpawns = false;
      for (let i = 0; i < 4; i++) {
        insertGuest(game, createGuest(game.rng, { reputation: game.state.reputation, nightIndex: 1 }));
      }
      addToast(game.state.night, 'NEU: SCHLANGE BERUHIGEN', 'good', 4);
    },
    wait: (game, elapsed) => elapsed > 10 || decisions(game) >= 9
  },
  {
    id: 'done',
    title: 'SCHICHT LÄUFT',
    body: 'Das war alles Nötige. Ab jetzt läuft die Nacht normal weiter: mehr Gäste, ' +
      'VIPs, Zwischenfälle. Verdiene Geld, halte den Ruf hoch - und bau den Laden aus.',
    setup(game) {
      const state = game.state;
      state.unlocks = { id: true, talk: true, search: true, alcohol: true, calm: true };
      state.tutorialDone = true;
      state.night.tutorial.blockSpawns = false;
      addRadio(state.night, 'CHEF', 'Läuft. Ab jetzt bist du dran.');
    },
    wait: (game, elapsed) => elapsed > 6
  }
];

export function startTutorial(game) {
  const night = game.state.night;
  night.tutorial = {
    stepIndex: -1,
    elapsed: 0,
    blockSpawns: true,
    baselineDecisions: 0,
    finished: false,
    step: null
  };
  game.state.unlocks = { id: true, talk: false, search: false, alcohol: false, calm: false };
  advance(game);
}

export function updateTutorial(game, dt) {
  const night = game.state.night;
  const tut = night?.tutorial;
  if (!tut || tut.finished) return;
  tut.elapsed += dt;
  const step = STEPS[tut.stepIndex];
  if (!step) return;
  if (step.wait(game, tut.elapsed)) advance(game);
}

function advance(game) {
  const night = game.state.night;
  const tut = night.tutorial;
  tut.stepIndex++;
  tut.elapsed = 0;

  const step = STEPS[tut.stepIndex];
  if (!step) {
    tut.finished = true;
    tut.step = null;
    night.tutorial = null;      // ab hier normale Nacht
    return;
  }

  if (step.unlock) {
    for (const key of [].concat(step.unlock)) game.state.unlocks[key] = true;
  }
  step.setup?.(game);
  tut.step = {
    id: step.id,
    title: typeof step.title === 'function' ? step.title(game) : step.title,
    body: typeof step.body === 'function' ? step.body(game) : step.body,
    hint: typeof step.hint === 'function' ? step.hint(game) : step.hint,
    index: tut.stepIndex,
    total: STEPS.length
  };
  game.bus.emit('tutorialStep', tut.step);
}

/* ---------- Hilfen ---------- */

function doorChecks(game) {
  return game.state.night?.stations.door.checks;
}

function decisions(game) {
  const s = game.state.night.stats;
  // Im Koop zählt schon das Durchlassen als getroffene Entscheidung.
  return s.rejected + (isSolo(game.state) ? s.admitted : s.passed);
}

export function tutorialStep(game) {
  return game.state.night?.tutorial?.step ?? null;
}

export const TUTORIAL_STEP_COUNT = STEPS.length;
