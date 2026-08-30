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
import { createInitialState, capacity, clubTier, isSolo, guestQuota } from '../src/systems/state.js';
import { createPlayers, updatePlayers, tryAction, stationOf, playerByRole } from '../src/systems/coop.js';
import { startNight, updateNight, pickNightEvent } from '../src/systems/nightcycle.js';
import { buyUpgrade, upgradeList } from '../src/systems/upgrades.js';
import { buyTalent } from '../src/systems/progression.js';
import { violationsOf, createGuest, visibleTells } from '../src/systems/guests.js';
import {
  faultyFields, ageFromBirth, requestId, toggleField, claimedFaults, scoreInspection
} from '../src/systems/identity.js';
import { startPatdown, openZone, pickItem, closeZone, scorePatdown } from '../src/systems/security.js';
import {
  emptyNotes, toggleCheck, toggleTopic, flipPage, reportedProblems, checklistFor, topicsFor
} from '../src/systems/notes.js';
import { saveGame, loadGame } from '../src/systems/save.js';
import {
  ITEMS, DIFFICULTY_STEPS, ITEM_CATEGORIES, IMPAIRMENT_SIGNS, AGGRESSION,
  DEFENSE_KEYS, itemsOfCategory, categoryById
} from '../src/data/config.js';
import { difficultyProfile } from '../src/systems/difficulty.js';
import {
  startAggression, aggressionActive, aggressionPossible, aggressionRisk, forcedDue
} from '../src/systems/aggression.js';
import { buildStatements } from '../src/systems/statements.js';
import { talkTo } from '../src/systems/alcohol.js';
import { collectFindings } from '../src/systems/decision.js';
import { updateNight as tickNight } from '../src/systems/nightcycle.js';

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
  // Übergriff: der Bot wehrt sich, solange er die Tastenfolge sieht.
  if (station?.aggro) {
    const a = station.aggro;
    if (a.phase === 'defend') tryAction(game, player, 'defend', { key: a.keys[a.index].key });
    return;
  }
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
    // Ausweisfelder von Hand als "nicht korrekt" vermerken (ein Klick genuegt,
    // weil der Zyklus mit "nicht korrekt" beginnt).
    const faults = faultyFields(guest);
    for (const field of faults) {
      if (checks.id.marks[field] !== 'suspect') { tryAction(game, player, 'mark', { field }); return; }
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
          // Alles ansehen, das Verbotene beanstanden, dann die Zone abschliessen.
          const bad = open.items.find((i) => i.forbidden && !open.flagged.includes(i.id));
          if (bad) tryAction(game, player, 'pick', { zone: open.id, itemId: bad.id });
          else tryAction(game, player, 'closezone', { zone: open.id });
          return;
        }
        const next = Object.values(pat.zones).find((z) => z.state === 'closed');
        if (next) { tryAction(game, player, 'zone', { zone: next.id }); return; }
      }
    }
    if (!checks.alcohol && can('alcohol')) { tryAction(game, player, 'alcohol'); return; }
    // Der Befund kommt auf den eigenen Notizzettel - das Spiel traegt nichts ein.
    if (checks.alcohol && checks.alcohol.promille >= checks.alcohol.limit
        && !(station.notes?.topics.alcohol === 'bad')) {
      tryAction(game, player, 'note', { topic: 'alcohol' });
      return;
    }
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
  if (c.id && claimedFaults(c.id).length > 0) return true;
  if (doorOnly) return false;
  if (c.search && c.search.flagged?.length) return true;
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
assert.ok(sn.stats.arrived >= sn.quota, `Solo: Gäste erschienen (${sn.stats.arrived})`);
assert.equal(sn.processed, sn.quota, `Solo: Schicht endet bei der Quote (${sn.processed}/${sn.quota})`);
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

/* ---------- Test 4: manuelle Ausweisprüfung, Selbstbewertung ---------- */

// Der Klick-Zyklus: leer -> nicht korrekt -> in Ordnung -> leer.
{
  const g = createGuest(createRng(5), { reputation: 50, nightIndex: 3 });
  const insp = requestId(makeGame('solo').state, g);
  assert.equal(insp.marks.photo, undefined, 'Feld startet unbewertet');
  assert.equal(toggleField(insp, 'photo').state, 'suspect', '1. Klick: nicht korrekt');
  assert.equal(toggleField(insp, 'photo').state, 'fine', '2. Klick: in Ordnung');
  assert.equal(toggleField(insp, 'photo').state, null, '3. Klick: wieder leer');
  assert.equal(insp.hint, undefined, 'Die Prüfung gibt keinen Hinweis mehr');
  assert.equal(insp.found, undefined, 'Das Spiel führt keine Trefferliste mehr');
  assert.equal(toggleField(insp, 'quatsch'), null, 'Unbekanntes Feld wird abgelehnt');
}

const rng = createRng(99);
let checked = 0;
let seenPhoto = false; let seenExpiry = false; let seenBirth = false;
for (let i = 0; i < 900; i++) {
  const g = createGuest(rng, { reputation: 50, nightIndex: 3 });
  const faults = faultyFields(g);
  const inspection = requestId(makeGame('solo').state, g);

  // Der Spieler beanstandet ALLE Felder: die Auswertung muss genau die
  // wirklich fehlerhaften als Treffer zählen - und erst nachträglich.
  for (const field of ['photo', 'name', 'birth', 'expiry', 'marks']) toggleField(inspection, field);
  const score = scoreInspection(inspection, g);
  assert.equal(score.hits.length, faults.size, 'Treffer entsprechen den echten Fehlern');
  assert.equal(score.wrong.length, 5 - faults.size, 'Der Rest zählt als Fehlgriff');
  assert.equal(score.missed.length, 0, 'Wer alles beanstandet, übersieht nichts');

  if (faults.size > 0) {
    checked++;
    if (faults.has('photo')) seenPhoto = true;
    if (faults.has('expiry')) seenExpiry = true;
    if (faults.has('birth')) seenBirth = true;
  } else {
    // Sauberes Dokument: nichts zu beanstanden, wer nichts anklickt liegt richtig.
    const clean = requestId(makeGame('solo').state, g);
    assert.equal(scoreInspection(clean, g).hits.length, 0, 'Sauberes Dokument: keine Treffer');
    assert.equal(scoreInspection(clean, g).missed.length, 0, 'Sauberes Dokument: nichts übersehen');
  }

  // Wahrheit und Dokument müssen zusammenpassen.
  if (g.truth.underage) {
    assert.ok(faults.size > 0, 'Minderjährige haben immer eine erkennbare Auffälligkeit');
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

/* ---------- Test 6b: Schichtplan, Selbstangaben und Prämie ---------- */

// Die Nacht endet an der Gästezahl, nicht an der Uhr.
assert.ok(sn.quota >= 16, `Solo: Schichtplan gesetzt (${sn.quota})`);
assert.equal(sn.processed, sn.quota, 'Solo: genau die geplanten Gäste abgearbeitet');
assert.equal(cn.processed, cn.quota, 'Koop: genau die geplanten Gäste abgearbeitet');
assert.ok(sn.clock < 10000, 'Die Uhr ist kein Abbruchkriterium mehr');

// Die Quote wächst mit den Nächten - bis zum Deckel.
{
  const st = createInitialState('solo');
  st.nightIndex = 1;
  const q1 = guestQuota(st);
  st.nightIndex = 5;
  assert.ok(guestQuota(st) > q1, 'Spätere Nächte haben mehr Gäste');
  st.nightIndex = 999;
  assert.ok(guestQuota(st) <= 40, 'Die Quote ist gedeckelt');
}

// Gefundene Unregelmäßigkeiten bringen Geld.
assert.ok(sn.stats.findings > 0, `Solo: eigene Befunde gezählt (${sn.stats.findings})`);
assert.equal(sn.stats.findingPay, sn.stats.findings * 35, 'Solo: Prämie je Befund ausgezahlt');
assert.ok(cn.stats.findings > 0, `Koop: eigene Befunde gezählt (${cn.stats.findings})`);
assert.equal(sn.stats.falseAlarms, 0, 'Der perfekte Bot beanstandet nichts zu Unrecht');

// Das Abtasten bewertet erst nachträglich - nicht beim Klicken.
{
  const g = createGuest(createRng(31), { reputation: 50, nightIndex: 6 });
  const st = makeGame('solo').state;
  const pat = startPatdown(st, g);
  const zoneId = Object.keys(pat.zones)[0];
  openZone(pat, g, zoneId);
  const item = pat.zones[zoneId].items[0];
  const res = pickItem(pat, g, zoneId, item.id);
  assert.equal(res.flagged, true, 'Erster Klick beanstandet');
  assert.equal(pat.zones[zoneId].correct, undefined, 'Keine sofortige Bewertung');
  assert.equal(pickItem(pat, g, zoneId, item.id).flagged, false, 'Zweiter Klick nimmt zurück');
  closeZone(pat, zoneId);
  assert.equal(pat.zones[zoneId].state, 'done', 'Zone wird ausdrücklich abgeschlossen');
  const score = scorePatdown(pat, g);
  assert.equal(score.hits.length + score.wrong.length, 0, 'Ohne Beanstandung gibt es keine Treffer');
  assert.equal(score.missed.length, (pat.zones[zoneId].items ?? []).filter((i) => i.forbidden).length,
    'Übersehenes Verbotenes wird nachträglich gezählt');
}

// Notizzettel: Haken und Befunde gehören dem Spieler.
{
  const notes = emptyNotes();
  assert.equal(notes.page, 0, 'Der Block liegt auf Seite 1');
  assert.equal(toggleCheck(notes, 'id').checked, true, 'Haken gesetzt');
  assert.equal(toggleCheck(notes, 'id').checked, false, 'Haken wieder entfernt');
  assert.equal(toggleCheck(notes, 'gibtsnicht'), null, 'Unbekannter Punkt wird abgelehnt');
  assert.equal(toggleTopic(notes, 'alcohol').state, 'ok', 'Befund: entspricht der Norm');
  assert.equal(toggleTopic(notes, 'alcohol').state, 'bad', 'Befund: entspricht nicht');
  assert.deepEqual(reportedProblems(notes), ['alcohol'], 'Beanstandete Themen werden gelistet');
  assert.equal(toggleTopic(notes, 'alcohol').state, null, 'Befund wieder gelöscht');
  assert.equal(flipPage(notes), 1, 'Auf Seite 2 geblättert');
  assert.equal(checklistFor('outside').length > 0, true, 'Die Tür hat eigene Checklistenpunkte');
  assert.equal(topicsFor('airlock').length > 0, true, 'Die Schleuse hat eigene Befundthemen');
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

/* ---------- Test 8: Gruppen statt Einzelliste ---------- */

// Die Hausordnung nennt nur Gruppen - also muss jede verbotene Sache in genau
// eine Gruppe fallen, und jede Gruppe muss mehrere Sachen enthalten.
{
  const forbidden = ITEMS.filter((i) => i.forbidden);
  assert.ok(forbidden.length >= 20, `Genug verbotene Sachen (${forbidden.length})`);
  for (const item of forbidden) {
    assert.ok(categoryById(item.cat), `${item.label} gehört zu einer Gruppe`);
    assert.ok(item.severity >= 1, `${item.label} hat eine Stufe`);
  }
  for (const item of ITEMS.filter((i) => !i.forbidden)) {
    assert.equal(item.cat, null, `${item.label} ist harmlos und ohne Gruppe`);
    assert.equal(item.severity, 0, `${item.label} hat keine Stufe`);
  }
  // Genau darum geht es: "Waffen" steht in der Liste, die einzelne Waffe nicht.
  assert.ok(itemsOfCategory('weapon').length >= 5,
    `Mehrere verschiedene Waffen (${itemsOfCategory('weapon').length})`);
  for (const cat of ITEM_CATEGORIES) {
    assert.ok(itemsOfCategory(cat.id).length >= 2, `Gruppe ${cat.label} hat mehrere Vertreter`);
    assert.ok(cat.rule.length > 10, `Gruppe ${cat.label} ist erklärt`);
  }
  const ids = new Set(ITEMS.map((i) => i.id));
  assert.equal(ids.size, ITEMS.length, 'Keine doppelten Gegenstands-Ids');
}

// Über viele Gäste kommen auch wirklich verschiedene Waffen und Gruppen vor.
{
  const rngCat = createRng(4711);
  const seenCats = new Set();
  const seenWeapons = new Set();
  for (let i = 0; i < 1200; i++) {
    const g = createGuest(rngCat, { reputation: 50, nightIndex: 8 });
    const c = g.truth.contraband;
    if (!c) continue;
    seenCats.add(c.cat);
    if (c.cat === 'weapon') seenWeapons.add(c.id);
  }
  assert.ok(seenCats.size >= 4, `Verschiedene Gruppen tauchen auf (${[...seenCats].join(', ')})`);
  assert.ok(seenWeapons.size >= 3, `Verschiedene Waffen tauchen auf (${seenWeapons.size})`);
}

/* ---------- Test 9: sichtbare Anzeichen ---------- */

{
  // Jedes Anzeichen hat eine Schwelle und einen lesbaren Namen.
  for (const sign of IMPAIRMENT_SIGNS) {
    assert.ok(sign.min > 0 && sign.min <= 1, `${sign.id} hat eine Schwelle`);
    assert.ok(sign.label.length > 3, `${sign.id} ist benannt`);
  }
  assert.ok(IMPAIRMENT_SIGNS.some((s) => s.id === 'redEyes'),
    'Rote Augen sind ein eigenes Anzeichen');
  assert.ok(IMPAIRMENT_SIGNS.filter((s) => s.face).length >= 5,
    'Mehrere Anzeichen sieht man direkt im Gesicht');

  const rngSign = createRng(321);
  const seen = new Set();
  let withSigns = 0;
  for (let i = 0; i < 900; i++) {
    const g = createGuest(rngSign, { reputation: 50, nightIndex: 9 });
    const signs = g.truth.impairmentSigns ?? [];
    if (signs.length) withSigns++;
    for (const id of signs) {
      seen.add(id);
      const cfg = IMPAIRMENT_SIGNS.find((s) => s.id === id);
      assert.ok(cfg, `Anzeichen ${id} ist bekannt`);
      assert.ok(g.truth.impaired >= cfg.min, `${id} passt zur Stärke des Einflusses`);
    }
    // Ohne Einfluss ist auch nichts zu sehen.
    if (g.truth.impaired === 0) assert.equal(signs.length, 0, 'Kein Einfluss, keine Anzeichen');
  }
  assert.ok(withSigns > 20, `Anzeichen kommen regelmässig vor (${withSigns})`);
  assert.ok(seen.has('redEyes'), 'Gerötete Augen kommen vor');
  assert.ok(seen.size >= 5, `Verschiedene Anzeichen kommen vor (${seen.size})`);
  // Sichtbare Hinweise landen im Klartext beim Rendering.
  const tells = visibleTells({
    truth: { drunk: 0.2, risk: 0.1, impairmentSigns: ['redEyes'], vip: false }
  });
  assert.ok(tells.includes('gerötete Augen'), 'Rote Augen erscheinen als Hinweis');
}

/* ---------- Test 10: Übergriffe und Abwehr ---------- */

/** Baut eine laufende Nacht mit einem Gast an der Tür. */
function nightWithGuest(seed = 5150, nightIndex = 7) {
  const g = makeGame('solo', seed);
  g.state.nightIndex = nightIndex - 1;
  startNight(g, pickNightEvent(g.rng, g.state), null);
  const door = g.state.night.stations.door;
  for (let i = 0; i < 4000 && !door.guest; i++) {
    updatePlayers(g, 1 / 60, null);
    tickNight(g, 1 / 60);
  }
  assert.ok(door.guest, 'Ein Gast steht an der Tür');
  return { game: g, door, player: g.players[0] };
}

// Vor der freigeschalteten Nacht rastet niemand aus.
{
  const early = makeGame('solo', 11);
  early.state.nightIndex = AGGRESSION.minNight - 2;
  startNight(early, pickNightEvent(early.rng, early.state), null);
  assert.equal(aggressionPossible(early.state), false,
    `Übergriffe erst ab Nacht ${AGGRESSION.minNight}`);
  early.state.nightIndex = AGGRESSION.minNight;
  assert.equal(aggressionPossible(early.state), true, 'Später sind sie möglich');
  early.state.night.tutorial = { step: null };
  assert.equal(aggressionPossible(early.state), false, 'Im Tutorial nie');
}

// Wer alle Tasten trifft, wehrt den Angriff ab.
{
  const { game: g, door, player } = nightWithGuest(5150);
  const guest = door.guest;
  startAggression(g, door, 'reject');
  assert.ok(aggressionActive(door), 'Der Angriff läuft');
  assert.equal(guest.truth.aggressive, true, 'Der Gast gilt als handgreiflich');
  assert.ok(violationsOf(guest).some((v) => v.id === 'aggressive'),
    'Ein Übergriff ist ein Verstoß - Abweisen ist richtig');
  assert.equal(tryAction(g, player, 'id'), 'ERST ABWEHREN', 'Alles andere ist gesperrt');

  const moneyBefore = g.state.money;
  let frames = 0;
  let pressed = 0;
  while (aggressionActive(door) && frames < 3000) {
    const a = door.aggro;
    if (a?.phase === 'defend') {
      tryAction(g, player, 'defend', { key: a.keys[a.index].key });
      pressed++;
    }
    updatePlayers(g, 1 / 60, null);
    tickNight(g, 1 / 60);
    frames++;
  }
  const s = g.state.night.stats;
  assert.ok(pressed >= AGGRESSION.keys[0], `Es war eine Tastenfolge (${pressed})`);
  assert.equal(s.attacks, 1, 'Der Angriff ist gezählt');
  assert.equal(s.defended, 1, 'Abgewehrt');
  assert.equal(s.attacksLanded ?? 0, 0, 'Nichts durchgekommen');
  assert.ok(g.state.money > moneyBefore, 'Die Abwehr bringt Geld');
  assert.equal(door.guest, null, 'Der Gast ist raus');
  assert.equal(s.rejected, 1, 'Er zählt als abgewiesen');
  assert.equal(g.state.night.processed, 1, 'Und ist damit abgearbeitet');
}

// Wer nichts drückt, kassiert - und steht danach kurz neben sich.
{
  const { game: g, door, player } = nightWithGuest(6060);
  startAggression(g, door, 'idle');
  const moneyBefore = g.state.money;
  const repBefore = g.state.reputation;
  let frames = 0;
  while (aggressionActive(door) && frames < 3000) {
    updatePlayers(g, 1 / 60, null);
    tickNight(g, 1 / 60);
    frames++;
  }
  const s = g.state.night.stats;
  assert.equal(s.attacksLanded, 1, 'Der Übergriff ist durchgekommen');
  assert.equal(s.defended ?? 0, 0, 'Nichts abgewehrt');
  assert.equal(s.incidents, 1, 'Zählt als Zwischenfall');
  assert.ok(g.state.money < moneyBefore, 'Das kostet Geld');
  assert.ok(g.state.reputation < repBefore, 'Und Ruf');
  assert.ok(player.busy > 0 && player.busyLabel === 'BENOMMEN', 'Danach ist man benommen');
}

// Ein Fehlgriff verzeiht die Abwehr, zu viele nicht.
{
  const { game: g, door, player } = nightWithGuest(7070);
  startAggression(g, door, 'reject');
  // Anlauf abwarten
  while (door.aggro.phase === 'charge') { updatePlayers(g, 1 / 60, null); tickNight(g, 1 / 60); }
  const wrong = DEFENSE_KEYS.find((k) => k.key !== door.aggro.keys[0].key);
  tryAction(g, player, 'defend', { key: wrong.key });
  assert.equal(door.aggro.strikes, 1, 'Ein Fehlgriff ist vermerkt');
  assert.equal(door.aggro.index, 0, 'Die Taste bleibt dieselbe');
  assert.equal(door.aggro.phase, 'defend', 'Ein Fehlgriff beendet noch nichts');
  tryAction(g, player, 'defend', { key: door.aggro.keys[0].key });
  assert.equal(door.aggro.index, 1, 'Die richtige Taste bringt einen weiter');
  // Jetzt so lange danebengreifen, bis Schluss ist.
  for (let i = 0; i < AGGRESSION.strikes + 2 && door.aggro?.phase === 'defend'; i++) {
    const miss = DEFENSE_KEYS.find((k) => k.key !== door.aggro.keys[door.aggro.index].key);
    tryAction(g, player, 'defend', { key: miss.key });
  }
  assert.equal(door.aggro.phase, 'fail', 'Zu viele Fehlgriffe gehen schief');
}

// Die Einschätzung, wer ausrastet, folgt dem Zustand des Gastes.
{
  const calm = { personality: 'polite', mood: 0.9, truth: { risk: 0, drunk: 0, impaired: 0 } };
  const hot = { personality: 'aggressive', mood: 0.1, truth: { risk: 0.9, drunk: 0.9, impaired: 0.8 } };
  assert.ok(aggressionRisk(hot) > aggressionRisk(calm) + 0.4,
    'Betrunken, gereizt und riskant heisst deutlich explosiver');
  assert.ok(aggressionRisk(calm) < 0.2, 'Ein entspannter Gast rastet praktisch nie aus');
}

// Eine späte Nacht läuft trotz Übergriffen sauber durch.
{
  const late = makeGame('solo', 8899);
  late.state.nightIndex = 11;
  const lateRun = runNight(late);
  const ln = lateRun.night;
  assert.ok(lateRun.ended, 'Späte Nacht regulär beendet');
  assert.equal(ln.processed, ln.quota, 'Auch mit Übergriffen wird die Liste abgearbeitet');
  assert.ok((ln.stats.attacks ?? 0) >= 0, 'Übergriffe werden gezählt');
  assert.equal((ln.stats.attacks ?? 0), (ln.stats.defended ?? 0) + (ln.stats.attacksLanded ?? 0),
    'Jeder Übergriff geht genau einmal aus');
  for (const station of Object.values(ln.stations)) {
    assert.equal(station.aggro, null, 'Am Ende läuft kein Angriff mehr');
  }
}


/* ---------- Test 11: Aussagen - Zuhören muss sich lohnen ---------- */

{
  const rngSt = createRng(2468);
  let withLie = 0;
  const kinds = new Set();
  const lieKinds = new Set();
  const total = 800;

  for (let i = 0; i < total; i++) {
    const g = createGuest(rngSt, { reputation: 50, nightIndex: 8 });
    const st = g.truth.statements;
    assert.ok(st.length >= 2, 'Jeder Gast sagt mehr als einen Satz');
    assert.equal(st[0].id, 'age', 'Die erste Aussage ist immer die zum Alter');
    for (const s of st) {
      assert.ok(s.text.length > 3, 'Aussagen haben einen Text');
      kinds.add(s.id);
      if (s.lie) lieKinds.add(s.id);
    }
    // Reines Geplauder ist nie eine wertbare Lüge.
    assert.ok(!st.some((s) => s.id === 'visit' && s.lie), 'Small Talk ist keine Lüge');
    if (st.some((s) => s.lie)) withLie++;
  }

  const share = withLie / total;
  assert.ok(share > 0.12 && share < 0.4, `Gelogen wird regelmässig, aber nicht immer (${Math.round(share * 100)}%)`);
  assert.ok(kinds.size >= 5, `Verschiedene Themen kommen vor (${kinds.size})`);
  assert.ok(lieKinds.size >= 3, `Gelogen wird zu verschiedenen Themen (${[...lieKinds].join(', ')})`);
}

// Jede Ansprache lockt genau eine weitere Aussage heraus.
{
  const rngTalk = createRng(1357);
  const state = makeGame('solo').state;
  const guest = createGuest(rngTalk, { reputation: 50, nightIndex: 6 });
  const count = guest.truth.statements.length;

  let talk = null;
  for (let i = 1; i <= count; i++) {
    talk = talkTo(rngTalk, state, guest, talk);
    assert.equal(talk.said.length, i, `Nach ${i} Ansprachen liegen ${i} Aussagen vor`);
    assert.equal(talk.moreToSay, i < count, 'moreToSay stimmt mit dem Rest überein');
    assert.equal(talk.realName, guest.name, 'Der echte Name kommt weiterhin heraus');
  }
  // Danach wiederholt er sich nur noch - die Liste waechst nicht weiter.
  talk = talkTo(rngTalk, state, guest, talk);
  assert.equal(talk.said.length, count, 'Mehr als seine Aussagen hat er nicht');
}

// Bewertet wird nur, was der Gast wirklich gesagt hat.
{
  const g = makeGame('solo');
  const station = { id: 'door', checks: { id: null, talk: null, alcohol: null }, notes: emptyNotes(), patdown: null };
  const guest = createGuest(createRng(24), { reputation: 50, nightIndex: 6 });
  guest.truth.statements = [
    { id: 'age', text: 'Ich bin 21.', lie: true },
    { id: 'bag', text: 'Keine Tasche.', lie: false }
  ];

  // Ohne Ansprechen ist die Aussage weder Treffer noch Versäumnis.
  toggleTopic(station.notes, 'statement');
  toggleTopic(station.notes, 'statement');       // -> 'bad'
  let score = collectFindings(guest, station);
  assert.equal(score.hits.filter((h) => h.kind === 'statement').length, 0,
    'Wer nie angesprochen hat, kann keine Lüge melden');
  assert.equal(score.wrong.filter((h) => h.kind === 'statement').length, 1,
    'Eine Meldung ohne Gespräch ist ein Fehlgriff');

  // Mit Ansprechen wird die Lüge zum Treffer.
  station.checks.talk = talkTo(createRng(9), g.state, guest, null);
  score = collectFindings(guest, station);
  assert.equal(score.hits.filter((h) => h.kind === 'statement').length, 1, 'Gehörte Lüge zählt als Treffer');

  // Wer sie hört, aber nicht meldet, hat sie übersehen.
  station.notes = emptyNotes();
  score = collectFindings(guest, station);
  assert.equal(score.missed.filter((h) => h.kind === 'statement').length, 1, 'Nicht gemeldete Lüge gilt als übersehen');
}

// Gescriptete Gäste (Tutorial) bekommen Aussagen, die zu ihrer Wahrheit passen.
{
  const guest = createGuest(createRng(5), { reputation: 50, nightIndex: 6 });
  guest.truth.hasBag = false;
  guest.truth.contraband = null;
  guest.truth.drunk = 0;
  guest.truth.impaired = 0;
  guest.truth.idIssues = [];
  guest.doc.tampered = false;
  guest.truth.statements = buildStatements(createRng(5), guest);
  assert.equal(guest.truth.statements.some((s) => s.lie), false,
    'Ein sauberer Gast hat nichts zu lügen');
}

/* ---------- Test 12: ein Übergriff pro Nacht ist gesetzt ---------- */

{
  const g = makeGame('solo', 13579);
  g.state.nightIndex = 10;
  startNight(g, pickNightEvent(g.rng, g.state), null);
  const night = g.state.night;
  assert.ok(night.forcedAttackAt >= 1 && night.forcedAttackAt <= night.quota - 2,
    `Der garantierte Übergriff ist eingeplant (bei Gast ${night.forcedAttackAt}/${night.quota})`);
  assert.equal(forcedDue(night), night.processed >= night.forcedAttackAt,
    'Fällig wird er erst an der ausgewürfelten Stelle');

  night.processed = night.forcedAttackAt;
  assert.equal(forcedDue(night), true, 'An der Stelle ist er fällig');
  night.stats.attacks = 1;
  assert.equal(forcedDue(night), false, 'Ist ohnehin schon jemand ausgerastet, entfällt er');
}

// In einer kompletten späten Nacht passiert er auch wirklich.
{
  for (const seed of [4242, 909, 31337]) {
    const late = makeGame('solo', seed);
    late.state.nightIndex = 9;
    const run = runNight(late);
    assert.ok(run.ended, 'Nacht beendet');
    assert.ok(run.night.stats.attacks >= 1,
      `Seed ${seed}: mindestens ein Übergriff pro Nacht (${run.night.stats.attacks})`);
  }
}

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
