/**
 * Headless-Smoketest: simuliert eine komplette Nacht ohne Browser.
 * Prueft, dass Kern-Gameplay-Schleife, Wirtschaft, Reputation, Koop-Aktionen,
 * Upgrades und Save/Load tatsaechlich funktionieren (keine Platzhalter).
 *
 * Start: node tests/smoke.mjs
 */

import assert from 'node:assert/strict';

import { createRng } from '../src/core/rng.js';
import { createBus } from '../src/core/bus.js';
import { createInitialState, capacity, clubTier } from '../src/systems/state.js';
import { createPlayers, updatePlayers, tryAction } from '../src/systems/coop.js';
import { startNight, updateNight, pickNightEvent } from '../src/systems/nightcycle.js';
import { buyUpgrade, upgradeList } from '../src/systems/upgrades.js';
import { buyTalent } from '../src/systems/progression.js';
import { violationsOf, createGuest } from '../src/systems/guests.js';
import { saveGame, loadGame } from '../src/systems/save.js';
import { PATDOWN_KEYS } from '../src/data/config.js';

/* ---------- Fake-Input: spielt einen "guten Tuersteher" nach ---------- */

function createFakeInput() {
  const queued = new Set();
  return {
    press(code) { queued.add(code); },
    isDown: () => false,
    justPressed(code) {
      if (queued.has(code)) { queued.delete(code); return true; }
      return false;
    },
    anyDown: () => false,
    endFrame() { queued.clear(); }
  };
}

function makeGame(seed = 1234) {
  const game = {
    state: createInitialState(),
    rng: createRng(seed),
    bus: createBus(),
    players: createPlayers(),
    save: () => true
  };
  return game;
}

/** Einfache KI: prueft jeden Gast und entscheidet anhand der Ergebnisse. */
function driveDoor(game, input) {
  const night = game.state.night;
  const guest = night.door;
  if (!guest) return;
  const [p1, p2] = game.players;
  const checks = night.doorChecks;

  if (p1.busy <= 0) {
    if (!checks.id) tryAction(game, p1, 'id');
    else if (readyToDecide(night)) tryAction(game, p1, decide(night) ? 'admit' : 'reject');
  }

  if (p2.busy <= 0) {
    if (!checks.scan) tryAction(game, p2, 'scan');
    else if (!night.patdown) tryAction(game, p2, 'search');
    else if (!night.patdown.complete) {
      const zone = PATDOWN_KEYS.find((z) => night.patdown.zones[z.zone] === null);
      if (zone) input.press(zone.key);
    } else if (!checks.alcohol && checks.talk === null) tryAction(game, p2, 'alcohol');
  }
}

function readyToDecide(night) {
  return !!night.doorChecks.id && !!night.doorChecks.scan &&
    (!night.patdown || night.patdown.complete);
}

function decide(night) {
  const c = night.doorChecks;
  if (c.id && (c.id.detected.length > 0 || c.id.docTooYoung)) return false;
  if (c.scan && c.scan.ok === false) return false;
  if (c.search && c.search.found) return false;
  if (c.alcohol && c.alcohol.overLimit) return false;
  return true;
}

/* ---------- Test 1: eine komplette Nacht ---------- */

const game = makeGame();
const input = createFakeInput();
let nightEnded = false;
game.bus.on('nightEnd', () => { nightEnded = true; });

const event = pickNightEvent(game.rng, game.state);
assert.ok(event, 'Nacht-Event wurde gewaehlt');
startNight(game, event, null);
assert.equal(game.state.phase, 'night');

const startMoney = game.state.money;
const dt = 1 / 60;
let frames = 0;
while (game.state.phase === 'night' && frames < 60 * 60 * 12) {
  driveDoor(game, input);
  updatePlayers(game, dt, input);
  updateNight(game, dt);
  input.endFrame();
  frames++;
}

const night = game.state.night;
assert.ok(nightEnded, 'Nacht wurde regulaer beendet');
assert.equal(game.state.phase, 'report', 'Report-Phase erreicht');
assert.ok(night.stats.arrived > 20, `Gaeste sind erschienen (${night.stats.arrived})`);
assert.ok(night.stats.admitted > 0, `Gaeste wurden eingelassen (${night.stats.admitted})`);
assert.ok(night.stats.rejected > 0, `Gaeste wurden abgewiesen (${night.stats.rejected})`);
assert.ok(night.stats.revenue > 0, `Umsatz erwirtschaftet (${Math.round(night.stats.revenue)})`);
assert.ok(game.state.money > startMoney, 'Geld hat sich erhoeht');
assert.ok(night.stats.correct > night.stats.mistakes,
  `Kontrolle lohnt sich: ${night.stats.correct} richtig vs ${night.stats.mistakes} falsch`);
assert.ok(night.stats.verified > 0, `Koop-Verifikation ausgeloest (${night.stats.verified})`);
assert.ok(night.rating >= 0 && night.rating <= 5, 'Sternewertung im Bereich 0-5');
assert.ok(game.state.xp > 0, 'XP vergeben');

/* ---------- Test 2: Upgrades veraendern die Welt ---------- */

game.state.money = 50000;
const capBefore = capacity(game.state);
const tierBefore = clubTier(game.state).level;
for (const id of ['floor', 'scanner', 'bar', 'lights', 'door', 'team', 'detector']) {
  const res = buyUpgrade(game.state, id);
  assert.ok(res.ok, `Upgrade ${id} gekauft`);
}
assert.ok(capacity(game.state) > capBefore, 'Kapazitaet ist gestiegen');
assert.ok(clubTier(game.state).level >= tierBefore, 'Club-Stufe wurde neu berechnet');
assert.ok(upgradeList(game.state).every((u) => u.level <= u.max), 'Upgrade-Level respektieren Maximum');

game.state.talentPoints = 2;
assert.ok(buyTalent(game.state, 'scanner').ok, 'Talent gelernt');
assert.equal(buyTalent(game.state, 'unbekannt').ok, false, 'Unbekanntes Talent abgelehnt');

/* ---------- Test 3: Regelwerk der Entscheidungen ---------- */

const rng = createRng(99);
let underageFound = false;
let contrabandFound = false;
for (let i = 0; i < 800; i++) {
  const g = createGuest(rng, { reputation: 50, nightIndex: 3 });
  const v = violationsOf(g);
  if (g.truth.underage) {
    assert.ok(v.some((x) => x.id === 'underage'), 'Minderjaehrig wird als Verstoss erkannt');
    underageFound = true;
  }
  if (g.truth.contraband) {
    assert.ok(v.some((x) => x.id === 'item'), 'Verbotener Gegenstand wird erkannt');
    contrabandFound = true;
  }
  if (!g.truth.underage && g.truth.idValid && !g.truth.contraband &&
      !g.truth.blacklisted && g.truth.drunk < 0.72) {
    assert.equal(v.length, 0, 'Sauberer Gast hat keine Verstoesse');
  }
}
assert.ok(underageFound && contrabandFound, 'Testmenge enthielt beide Problemfaelle');

/* ---------- Test 4: Save/Load ---------- */

const store = new Map();
const fakeStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, v),
  removeItem: (k) => store.delete(k)
};
game.state.money = 4242;
game.state.reputation = 71;
assert.ok(saveGame(game.state, fakeStorage), 'Speichern erfolgreich');
const fresh = createInitialState();
assert.ok(loadGame(fresh, fakeStorage), 'Laden erfolgreich');
assert.equal(fresh.money, 4242, 'Geld wiederhergestellt');
assert.equal(fresh.reputation, 71, 'Reputation wiederhergestellt');
assert.equal(fresh.upgrades.floor, game.state.upgrades.floor, 'Upgrades wiederhergestellt');

/* ---------- Ergebnis ---------- */

console.log('NIGHT REPORT (Simulation)');
console.log(`  Event         ${night.event.label}`);
console.log(`  Gaeste        ${night.stats.arrived}`);
console.log(`  Einlass       ${night.stats.admitted}`);
console.log(`  Abgewiesen    ${night.stats.rejected}`);
console.log(`  Abgesprungen  ${night.stats.left}`);
console.log(`  Umsatz        ${Math.round(night.stats.revenue)} EUR`);
console.log(`  Vorfaelle     ${night.stats.incidents}`);
console.log(`  Verified      ${night.stats.verified}`);
console.log(`  Bewertung     ${night.rating}/5`);
console.log('\nAlle Smoketests bestanden.');
