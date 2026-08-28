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
import { ITEMS, DIFFICULTY_STEPS } from '../src/data/config.js';
import { difficultyProfile } from '../src/systems/difficulty.js';

/* ---------- Spiel aufsetzen ---------- */

function makeGame(mode, seed = 1234) {
  const state = createInitialState(mode);
  // Für die Simulation ist alles freigeschaltet (das Tutorial testet Schritt 5).
  state.unlocks = { id: true, talk: true, search: true, alcohol: true, calm: true };
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
    if (can('search')) {
      const pat = station.patdown;
      if (!pat) { tryAction(game, player, 'search'); return; }
      if (!pat.complete) {
        const open = pat.active ? pat.zones[pat.active] : null;
        if (open) {
          // Alles ansehen und das Verbotene herausgreifen - wie ein wacher Spieler.
          const bad = open.items.find((i) => i.forbidden);
          tryAction(game, player, 'pick', { zone: open.id, itemId: bad ? bad.id : null });
          return;
        }
        const next = Object.values(pat.zones).find((z) => z.state === 'closed');
        if (next) { tryAction(game, player, 'zone', { zone: next.id }); return; }
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
  if (c.search && c.search.found) return true;
  // Das Gerät zeigt nur den Wert - der Grenzwert steht auf dem Gehäuse.
  if (c.alcohol && c.alcohol.promille >= c.alcohol.limit) return true;
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
assert.ok(tryAction(coop, bouncer, 'search'), 'Bouncer darf nicht abtasten');
assert.ok(tryAction(coop, security, 'id'), 'Security darf keinen Ausweis verlangen');
assert.ok(tryAction(coop, bouncer, 'admit'), 'Bouncer darf nicht in den Club einlassen');

/* ---------- Test 3: Tutorial läuft durch und schaltet frei ---------- */

const tut = makeGame('solo', 777);
tut.state.unlocks = { id: true, talk: false, search: false, alcohol: false, calm: false };
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
assert.equal('scan' in tut.state.unlocks, false, 'Der Scan ist als Feature entfernt');
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

/* ---------- Test 5: Gegenstände, Zonen, Progression ---------- */

const rngItems = createRng(2024);
let withBag = 0;
let bagZoneOnlyWithBag = true;
let contrabandInRightZone = true;
let decoysSeen = 0;
let impairedSeen = 0;

for (let i = 0; i < 600; i++) {
  const night = 1 + (i % 12);
  const g = createGuest(rngItems, { reputation: 50, nightIndex: night });
  const zones = Object.keys(g.truth.carried);

  if (g.truth.hasBag) withBag++;
  else if (zones.includes('bag')) bagZoneOnlyWithBag = false;

  // In jeder Zone liegt etwas, und alles Getragene ist ein echtes Item.
  for (const [zone, items] of Object.entries(g.truth.carried)) {
    assert.ok(items.length > 0, `Zone ${zone} ist nicht leer`);
    for (const item of items) {
      assert.ok(ITEMS.some((it) => it.id === item.id), 'Nur bekannte Gegenstände');
      assert.ok(item.zones.includes(zone), `${item.label} passt in ${zone}`);
    }
    if (items.filter((i) => !i.forbidden).length >= 2) decoysSeen++;
  }

  // Höchstens ein verbotener Gegenstand, und der liegt in der gemeldeten Zone.
  const forbidden = Object.values(g.truth.carried).flat().filter((i) => i.forbidden);
  assert.ok(forbidden.length <= 1, 'Höchstens ein verbotener Gegenstand pro Gast');
  if (g.truth.contraband) {
    assert.equal(forbidden.length, 1, 'Verbotener Gegenstand liegt wirklich dabei');
    if (!g.truth.carried[g.truth.contrabandZone]?.some((i) => i.id === g.truth.contraband.id)) {
      contrabandInRightZone = false;
    }
  } else {
    assert.equal(forbidden.length, 0, 'Ohne Contraband liegt nichts Verbotenes dabei');
  }

  if (g.truth.impaired > 0) {
    impairedSeen++;
    assert.ok(night >= 4, 'Substanzeinfluss erst ab der vierten Nacht');
  }
  if (g.truth.impaired >= 0.6) {
    assert.ok(violationsOf(g).some((v) => v.id === 'impaired'), 'Deutlicher Einfluss ist ein Verstoß');
  }
}

assert.ok(withBag > 100, `Manche Gäste haben eine Tasche dabei (${withBag}/600)`);
assert.ok(bagZoneOnlyWithBag, 'Ohne Tasche gibt es auch keine Taschen-Zone');
assert.ok(contrabandInRightZone, 'Verbotenes liegt in der Zone, die die Wahrheit nennt');
assert.ok(decoysSeen > 200, 'Harmlose Gegenstände lenken ab');
assert.ok(impairedSeen > 5, `Substanzeinfluss kommt vor (${impairedSeen})`);

// Progression: jede Stufe schaltet zur angekündigten Nacht frei.
for (const step of DIFFICULTY_STEPS) {
  const before = difficultyProfile(step.night - 1);
  const after = difficultyProfile(step.night);
  if (step.id in after) {
    assert.equal(after[step.id], true, `${step.label} gilt ab Nacht ${step.night}`);
    if (step.night > 1) assert.equal(before[step.id], false, `${step.label} gilt vorher nicht`);
  }
}
assert.ok(difficultyProfile(12).decoyBonus > difficultyProfile(2).decoyBonus,
  'Später liegen mehr harmlose Sachen zur Ablenkung dabei');

/* ---------- Test 6: Regelwerk ---------- */

const rng2 = createRng(7);
for (let i = 0; i < 500; i++) {
  const g = createGuest(rng2, { reputation: 50, nightIndex: 3 });
  const v = violationsOf(g);
  if (g.truth.underage) assert.ok(v.some((x) => x.id === 'underage'), 'Minderjährig = Verstoß');
  if (g.truth.contraband) assert.ok(v.some((x) => x.id === 'item'), 'Verbotener Gegenstand = Verstoß');
}

/* ---------- Test 7: Upgrades, Talente, Save/Load ---------- */

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
console.log(`  TUT    ${seenSteps.size} Schritte durchlaufen · Freischaltungen ${Object.values(tut.state.unlocks).filter(Boolean).length}/5`);
console.log(line('SOLO', { ...sn.stats, rating: `${sn.rating}/5` }));
console.log(line('KOOP', { ...cn.stats, rating: `${cn.rating}/5` }));
console.log('\nAlle Smoketests bestanden.');
