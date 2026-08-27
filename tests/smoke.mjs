/**
 * Headless-Smoketest: simuliert komplette Nächte ohne Browser.
 * Prüft Solo-Fluss (nur Tür) und Koop-Fluss (Tür -> Schleuse -> Club),
 * die manuelle Ausweisprüfung, Wirtschaft, Upgrades und Save/Load.
 *
 * Start: node tests/smoke.mjs
 */

import assert from 'node:assert/strict';

import { createRng } from '../src/core/rng.js';
import { createBus } from '../src/core/bus.js';
import { createInitialState, capacity, clubTier, isSolo } from '../src/systems/state.js';
import { createPlayers, updatePlayers, tryAction, stationOf, playerByRole } from '../src/systems/coop.js';
import { startNight, updateNight, pickNightEvent } from '../src/systems/nightcycle.js';
import { buyUpgrade, upgradeList } from '../src/systems/upgrades.js';
import { buyTalent } from '../src/systems/progression.js';
import { violationsOf, createGuest } from '../src/systems/guests.js';
import { faultyFields, ageFromBirth, requestId, markField } from '../src/systems/identity.js';
import { saveGame, loadGame } from '../src/systems/save.js';
import { PATDOWN_KEYS } from '../src/data/config.js';

/* ---------- Spiel aufsetzen ---------- */

function makeGame(mode, seed = 1234) {
  const state = createInitialState(mode);
  // Für die Simulation ist alles freigeschaltet (das Tutorial testet Schritt 5).
  state.unlocks = { id: true, talk: true, scan: true, search: true, alcohol: true, calm: true };
  return {
    state,
    rng: createRng(seed),
    bus: createBus(),
    players: createPlayers(mode),
    save: () => true
  };
}

/**
 * Türsteher-KI: verlangt den Ausweis, prüft die Felder von Hand
 * (nutzt die Wahrheit, wie es ein perfekter Spieler mit gutem Auge täte),
 * scannt, tastet ab und entscheidet.
 */
function driveStation(game, player, input) {
  const station = stationOf(game, player);
  const guest = station?.guest;
  if (!guest || player.busy > 0) return;
  const checks = station.checks;
  const solo = isSolo(game.state);
  const outside = player.area === 'outside';
  // Gesperrte Mechaniken (Tutorial) kann auch der Bot nicht benutzen.
  const can = (code) => game.state.unlocks[code] !== false;

  // --- Bouncer-Aufgaben (draussen bzw. solo) ---
  if (outside) {
    if (!checks.id && can('id')) { tryAction(game, player, 'id'); return; }
    if (!checks.talk && can('talk')) { tryAction(game, player, 'talk'); return; }
    // Ausweisfelder von Hand markieren
    const faults = faultyFields(guest);
    for (const field of faults) {
      if (!checks.id.marks[field]) { tryAction(game, player, 'mark', { field }); return; }
    }
  }

  // --- Security-Aufgaben (Schleuse bzw. solo) ---
  if (!outside || solo) {
    if (!checks.scan && can('scan')) { tryAction(game, player, 'scan'); return; }
    if (can('search')) {
      if (!station.patdown) { tryAction(game, player, 'search'); return; }
      if (!station.patdown.complete) {
        const zone = PATDOWN_KEYS.find((z) => station.patdown.zones[z.zone] === null);
        if (zone) tryAction(game, player, 'zone', { zone: zone.zone, label: zone.label });
        return;
      }
    }
    if (!checks.alcohol && can('alcohol')) { tryAction(game, player, 'alcohol'); return; }
  }

  // --- Entscheidung ---
  const suspicious = decide(station, outside && !solo);
  if (outside && !solo) {
    tryAction(game, player, suspicious ? 'reject' : 'pass');
  } else {
    tryAction(game, player, suspicious ? 'reject' : 'admit');
  }
}

function decide(station, doorOnly) {
  const c = station.checks;
  if (c.id && c.id.found.length > 0) return true;
  if (doorOnly) return false;
  if (c.scan && c.scan.ok === false) return true;
  if (c.search && c.search.found) return true;
  if (c.alcohol && c.alcohol.overLimit) return true;
  return false;
}

function runNight(game) {
  let ended = false;
  game.bus.on('nightEnd', () => { ended = true; });
  const event = pickNightEvent(game.rng, game.state);
  startNight(game, event, null);
  const dt = 1 / 60;
  let frames = 0;
  while (game.state.phase === 'night' && frames < 60 * 60 * 12) {
    for (const p of game.players) driveStation(game, p);
    updatePlayers(game, dt, null);
    updateNight(game, dt);
    frames++;
  }
  return { ended, night: game.state.night };
}

/* ---------- Test 1: Solo-Nacht ---------- */

const solo = makeGame('solo');
const soloMoney = solo.state.money;
const soloRun = runNight(solo);
const sn = soloRun.night;

assert.ok(soloRun.ended, 'Solo: Nacht regulär beendet');
assert.equal(solo.state.phase, 'report', 'Solo: Report erreicht');
assert.equal(solo.players.length, 1, 'Solo: nur ein Spieler');
assert.ok(sn.stats.arrived > 20, `Solo: Gäste erschienen (${sn.stats.arrived})`);
assert.ok(sn.stats.admitted > 0, 'Solo: Gäste eingelassen');
assert.ok(sn.stats.rejected > 0, 'Solo: Gäste abgewiesen');
assert.equal(sn.stats.passed, 0, 'Solo: keine Schleuse, also kein Durchlassen');
assert.ok(sn.airlockQueue.length === 0, 'Solo: Schleuse bleibt leer');
assert.ok(solo.state.money > soloMoney, 'Solo: Geld gestiegen');
assert.ok(sn.stats.correct > sn.stats.mistakes,
  `Solo: mehr richtig als falsch (${sn.stats.correct}/${sn.stats.mistakes})`);

/* ---------- Test 2: Koop-Nacht mit getrennten Bereichen ---------- */

const coop = makeGame('local', 4321);
const coopRun = runNight(coop);
const cn = coopRun.night;

assert.ok(coopRun.ended, 'Koop: Nacht regulär beendet');
assert.equal(coop.players.length, 2, 'Koop: zwei Spieler');
assert.equal(playerByRole(coop, 'bouncer').area, 'outside', 'Bouncer arbeitet draussen');
assert.equal(playerByRole(coop, 'security').area, 'airlock', 'Security arbeitet in der Schleuse');
assert.ok(cn.stats.passed > 0, `Koop: Gäste in die Schleuse durchgelassen (${cn.stats.passed})`);
assert.ok(cn.stats.admitted > 0, 'Koop: Gäste in den Club eingelassen');
assert.ok(cn.stats.admitted <= cn.stats.passed, 'Koop: es kommt nur rein, wer durchgelassen wurde');
assert.ok(cn.stats.correct > cn.stats.mistakes,
  `Koop: mehr richtig als falsch (${cn.stats.correct}/${cn.stats.mistakes})`);

// Bereichsgrenzen: der Bouncer darf nicht scannen, die Security nicht am Ausweis arbeiten.
const bouncer = playerByRole(coop, 'bouncer');
const security = playerByRole(coop, 'security');
coop.state.night.running = true;
assert.ok(tryAction(coop, bouncer, 'scan'), 'Bouncer darf nicht scannen');
assert.ok(tryAction(coop, security, 'id'), 'Security darf keinen Ausweis verlangen');
assert.ok(tryAction(coop, bouncer, 'admit'), 'Bouncer darf nicht in den Club einlassen');

/* ---------- Test 3: Tutorial läuft durch und schaltet frei ---------- */

const tut = makeGame('solo', 777);
tut.state.unlocks = { id: true, talk: false, scan: false, search: false, alcohol: false, calm: false };
let tutEnded = false;
tut.bus.on('nightEnd', () => { tutEnded = true; });
startNight(tut, pickNightEvent(tut.rng, tut.state), null, { tutorial: true });

assert.ok(tut.state.night.tutorial, 'Tutorial gestartet');
assert.equal(tut.state.unlocks.talk, false, 'Ansprechen ist zu Beginn gesperrt');

const seenSteps = new Set();
let frames2 = 0;
while (tut.state.phase === 'night' && frames2 < 60 * 60 * 12) {
  const step = tut.state.night.tutorial?.step;
  if (step) seenSteps.add(step.id);
  for (const p of tut.players) driveStation(tut, p);
  updatePlayers(tut, 1 / 60, null);
  updateNight(tut, 1 / 60);
  frames2++;
}

assert.ok(seenSteps.has('spawn1'), 'Tutorial: erster Gast erklärt');
assert.ok(seenSteps.has('expired'), 'Tutorial: abgelaufener Ausweis erklärt');
assert.ok(seenSteps.has('photo'), 'Tutorial: Fotovergleich erklärt');
assert.ok(seenSteps.has('done'), `Tutorial vollständig durchlaufen (${seenSteps.size} Schritte)`);
assert.equal(tut.state.tutorialDone, true, 'Tutorial als abgeschlossen markiert');
assert.ok(Object.values(tut.state.unlocks).every(Boolean), 'Am Ende ist alles freigeschaltet');
assert.ok(tutEnded, 'Tutorial-Nacht regulär beendet');

/* ---------- Test 4: manuelle Ausweisprüfung ---------- */

const rng = createRng(99);
let checked = 0;
let seenPhoto = false; let seenExpiry = false; let seenBirth = false;
for (let i = 0; i < 900; i++) {
  const g = createGuest(rng, { reputation: 50, nightIndex: 3 });
  const faults = faultyFields(g);
  const inspection = requestId(makeGame('solo').state, g);

  // Ein sauberes Dokument darf keine Treffer liefern.
  if (faults.size === 0) {
    for (const field of ['photo', 'name', 'birth', 'expiry', 'marks']) {
      const res = markField(inspection, g, field);
      assert.equal(res.correct, false, 'Sauberes Dokument: kein Feld ist auffällig');
    }
  } else {
    for (const field of faults) {
      const res = markField(inspection, g, field);
      assert.equal(res.correct, true, `Fehlerhaftes Feld ${field} wird als Treffer erkannt`);
      assert.ok(res.reason, 'Treffer hat eine Begründung');
      if (field === 'photo') seenPhoto = true;
      if (field === 'expiry') seenExpiry = true;
      if (field === 'birth') seenBirth = true;
    }
    checked++;
  }

  // Wahrheit und Dokument müssen zusammenpassen.
  if (g.truth.underage) {
    assert.ok(faults.has('birth') || faults.has('photo') || faults.size > 0,
      'Minderjährige haben immer eine erkennbare Auffälligkeit');
  }
  if (!g.doc.tampered && !g.truth.underage) {
    assert.ok(ageFromBirth(g.doc.birth) >= 18, 'Ehrliches Dokument zeigt volljähriges Alter');
  }
}
assert.ok(checked > 100, `Genug fehlerhafte Dokumente im Test (${checked})`);
assert.ok(seenPhoto && seenExpiry && seenBirth, 'Alle Fehlerarten kamen vor');

/* ---------- Test 5: Regelwerk ---------- */

const rng2 = createRng(7);
for (let i = 0; i < 500; i++) {
  const g = createGuest(rng2, { reputation: 50, nightIndex: 3 });
  const v = violationsOf(g);
  if (g.truth.underage) assert.ok(v.some((x) => x.id === 'underage'), 'Minderjährig = Verstoß');
  if (g.truth.contraband) assert.ok(v.some((x) => x.id === 'item'), 'Verbotener Gegenstand = Verstoß');
}

/* ---------- Test 6: Upgrades, Talente, Save/Load ---------- */

solo.state.money = 50000;
const capBefore = capacity(solo.state);
const tierBefore = clubTier(solo.state).level;
for (const id of ['floor', 'scanner', 'bar', 'lights', 'door', 'team', 'detector']) {
  assert.ok(buyUpgrade(solo.state, id).ok, `Upgrade ${id} gekauft`);
}
assert.ok(capacity(solo.state) > capBefore, 'Kapazität gestiegen');
assert.ok(clubTier(solo.state).level >= tierBefore, 'Club-Stufe neu berechnet');
assert.ok(upgradeList(solo.state).every((u) => u.level <= u.max), 'Upgrade-Level im Rahmen');

solo.state.talentPoints = 2;
assert.ok(buyTalent(solo.state, 'scanner').ok, 'Talent gelernt');
assert.equal(buyTalent(solo.state, 'unbekannt').ok, false, 'Unbekanntes Talent abgelehnt');

const store = new Map();
const fakeStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, v),
  removeItem: (k) => store.delete(k)
};
solo.state.money = 4242;
solo.state.reputation = 71;
assert.ok(saveGame(solo.state, fakeStorage), 'Speichern erfolgreich');
const fresh = createInitialState('solo');
assert.ok(loadGame(fresh, fakeStorage), 'Laden erfolgreich');
assert.equal(fresh.money, 4242, 'Geld wiederhergestellt');
assert.equal(fresh.upgrades.floor, solo.state.upgrades.floor, 'Upgrades wiederhergestellt');

/* ---------- Ergebnis ---------- */

const line = (label, s) =>
  `  ${label.padEnd(6)} Gäste ${String(s.arrived).padStart(3)} · durchgelassen ${String(s.passed).padStart(3)}` +
  ` · Einlass ${String(s.admitted).padStart(3)} · abgewiesen ${String(s.rejected).padStart(3)}` +
  ` · Umsatz ${String(Math.round(s.revenue)).padStart(5)} EUR · richtig ${s.correct}/${s.correct + s.mistakes}` +
  ` · Fänge ${s.catches} · Bewertung ${s.rating ?? ''}`;

console.log('SIMULATION');
console.log(`  TUT    ${seenSteps.size} Schritte durchlaufen · Freischaltungen ${Object.values(tut.state.unlocks).filter(Boolean).length}/6`);
console.log(line('SOLO', { ...sn.stats, rating: `${sn.rating}/5` }));
console.log(line('KOOP', { ...cn.stats, rating: `${cn.rating}/5` }));
console.log('\nAlle Smoketests bestanden.');
