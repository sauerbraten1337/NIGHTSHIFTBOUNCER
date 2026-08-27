/**
 * Entscheidungssystem: DURCHLASSEN / EINLASSEN / ABWEISEN.
 *
 * Koop: Der Bouncer draussen entscheidet nur, wer überhaupt in die Schleuse
 * darf. Die Security innen entscheidet, wer in den Club kommt. Dadurch gibt es
 * eine zweite Verteidigungslinie - und echte Team-Momente ("guter Fang").
 */

import { violationsOf } from './guests.js';
import { admitRevenue, plannedBarSpend, earn, fine, incidentCost } from './economy.js';
import { changeReputation } from './reputation.js';
import { incidentChance } from './security.js';
import { addToast, addRadio, pushLog, isSolo } from './state.js';
import { moveToAirlock } from './queue.js';
import { inspectionVerdict } from './identity.js';
import { TUNING } from '../data/config.js';
import { chance } from '../core/rng.js';

/**
 * Koop-Verifikation: das Urteil des Bouncers (Ausweisprüfung) gegen den Befund
 * der Security (Scan/Abtasten).
 */
export function coopVerification(guest, airlockChecks) {
  const doorVerdict = guest?.doorVerdict;
  if (!doorVerdict || !airlockChecks?.scan) return { state: 'none' };
  if (airlockChecks.scan.offline || airlockChecks.scan.ok === null) return { state: 'none' };
  const securityClean = airlockChecks.scan.ok !== false && !airlockChecks.search?.found;
  if (doorVerdict.clean === securityClean) return { state: 'verified', clean: securityClean };
  return { state: 'conflict', doorClean: doorVerdict.clean, securityClean };
}

/** Solo-Variante: ID-Prüfung und Scan an derselben Station. */
export function soloVerification(checks) {
  if (!checks.id || !checks.scan) return { state: 'none' };
  if (checks.scan.offline || checks.scan.ok === null) return { state: 'none' };
  const idClean = inspectionVerdict(checks.id).clean;
  const scanClean = checks.scan.ok !== false;
  return idClean === scanClean ? { state: 'verified', clean: idClean } : { state: 'conflict' };
}

/* ------------------------------------------------------------------ */

/** Bouncer schickt den Gast weiter in die Schleuse (nur Koop). */
export function passGuest(game, guest, station) {
  const { state, rng, bus } = game;
  const night = state.night;
  const verdict = inspectionVerdict(station.checks.id);

  guest.doorVerdict = {
    clean: verdict.checked ? verdict.clean : null,
    checked: verdict.checked,
    found: verdict.found ?? [],
    talked: !!station.checks.talk
  };

  night.stats.passed++;
  moveToAirlock(game, guest);
  clearStation(station);
  guest.said = null;
  addRadio(night, 'TÜR', verdict.checked
    ? (verdict.clean ? 'Ausweis geprüft, kommt zu euch.' : 'Der ist auffällig - schaut ihn euch an.')
    : 'Kommt ungeprüft durch, macht ihr weiter.');
  bus.emit('sfx', 'door');
  if (rng() < 0.001) pushLog(state, 'Tür läuft', 'info');
  return { verdict };
}

/** Gast endgültig in den Club lassen. */
export function admitGuest(game, guest, station) {
  const { state, rng, bus } = game;
  const night = state.night;
  const violations = violationsOf(guest);
  const verify = isSolo(state)
    ? soloVerification(station.checks)
    : coopVerification(guest, station.checks);

  night.stats.admitted++;
  state.lifetime.admitted++;
  if (guest.truth.vip) night.stats.vips++;

  let entry = admitRevenue(state, guest);
  if (verify.state === 'verified') {
    night.stats.verified++;
    entry = Math.round(entry * 1.15);
  }
  earn(state, entry, 'entry');

  const spendTotal = plannedBarSpend(state, guest);
  night.inside.push({
    id: guest.id, guest, spendTotal, spendLeft: spendTotal, phase: rng() * 6.28
  });

  if (violations.length === 0) {
    night.stats.correct++;
    let rep = 0.4 + guest.truth.repValue * 0.35;
    if (verify.state === 'verified') rep += 0.25;
    changeReputation(state, rep, 'korrekter Einlass');
    state.xp += 12;
    bus.emit('sfx', 'ok');
    addToast(night, `EINLASS +${entry} EUR`, 'good');
  } else {
    night.stats.mistakes++;
    state.xp += 3;
    const worst = violations.reduce((a, b) => (b.severity > a.severity ? b : a));
    resolveBadAdmission(game, guest, worst);
  }

  finishGuest(game, guest, station, 'admitted');
  bus.emit('sfx', 'door');
  return { entry, violations, verify };
}

function resolveBadAdmission(game, guest, worst) {
  const { state, rng, bus } = game;
  const night = state.night;
  const inspection = night.event?.inspection ? 2 : 1;

  if (worst.id === 'underage') {
    if (chance(rng, 0.55 * inspection)) {
      const f = fine(state, TUNING.fineUnderage * inspection, 'Minderjährige eingelassen');
      changeReputation(state, -6 * inspection, 'Kontrolle');
      night.stats.incidents++;
      state.lifetime.incidents++;
      addToast(night, `BUSSGELD -${f.value} EUR: MINDERJÄHRIG`, 'bad', 5);
      addRadio(night, 'FUNK', 'Da war jemand zu jung. Das gibt Ärger.');
      bus.emit('sfx', 'alarm');
    } else {
      changeReputation(state, -1.5, 'Risiko');
      addToast(night, 'ZU JUNG DURCHGEWUNKEN', 'warn');
    }
    return;
  }

  const p = incidentChance(state, guest) + (worst.severity >= 2 ? 0.2 : 0);
  if (chance(rng, Math.min(0.95, p))) {
    const cost = incidentCost(state, worst.severity || 1) * inspection;
    fine(state, cost, worst.label);
    changeReputation(state, -2.2 * worst.severity * inspection * 0.6, 'Zwischenfall');
    night.stats.incidents++;
    state.lifetime.incidents++;
    addToast(night, `ZWISCHENFALL: ${worst.label.toUpperCase()} (-${cost} EUR)`, 'bad', 5);
    addRadio(night, 'FLOOR', `Zwischenfall im Club. ${worst.label}.`);
    pushLog(state, `Zwischenfall: ${worst.label}`, 'bad');
    bus.emit('sfx', 'alarm');
  } else {
    changeReputation(state, -0.8, 'Risiko');
    addToast(night, `RISIKO REINGELASSEN: ${worst.label}`, 'warn');
  }
}

/** Gast abweisen - an der Tür oder in der Schleuse. */
export function rejectGuest(game, guest, station) {
  const { state, bus } = game;
  const night = state.night;
  const violations = violationsOf(guest);
  const atAirlock = station.id === 'airlock';

  night.stats.rejected++;
  state.lifetime.rejected++;

  if (violations.length > 0) {
    night.stats.correct++;
    let rep = 0.5 + violations.length * 0.2;

    // Die Security hat gefangen, was draussen durchgerutscht ist.
    if (atAirlock && guest.doorVerdict && guest.doorVerdict.clean === true) {
      night.stats.catches++;
      rep += 0.4;
      addToast(night, 'GUTER FANG - SECURITY HAT IHN GESTOPPT', 'good', 4);
      addRadio(night, 'SECURITY', 'Den hätten wir fast reingelassen.');
    } else if (isSolo(state) || !atAirlock) {
      const verify = isSolo(state) ? soloVerification(station.checks) : { state: 'none' };
      if (verify.state === 'verified') { rep += 0.25; night.stats.verified++; }
    }

    changeReputation(state, rep, 'korrekt abgewiesen');
    state.xp += 15;
    bus.emit('sfx', 'deny');
    addToast(night, `RICHTIG ABGEWIESEN: ${violations[0].label}`, 'good');
    if (guest.inspector) {
      changeReputation(state, 2, 'Testkontrolle bestanden');
      addRadio(night, 'FUNK', 'Das war eine Testperson. Sauber gemacht.');
    }
  } else {
    night.stats.mistakes++;
    const lost = Math.round(plannedBarSpend(state, guest) + admitRevenue(state, guest));
    const repHit = guest.truth.vip ? -3.2 : guest.archetype === 'influencer' ? -2.6 : -1.1;
    changeReputation(state, repHit, 'zu Unrecht abgewiesen');
    state.xp += 2;
    bus.emit('sfx', 'deny');
    addToast(night, `FALSCH ABGEWIESEN (-${lost} EUR Potenzial)`, 'bad');
    if (guest.truth.vip) addRadio(night, 'FUNK', 'Das war ein VIP. Der redet morgen über uns.');
    if (guest.inspector) changeReputation(state, 1, 'Testkontrolle');
  }

  finishGuest(game, guest, station, 'rejected');
  return { violations };
}

function finishGuest(game, guest, station, outcome) {
  const night = game.state.night;
  guest.state = outcome;
  guest.exitTimer = 1.6;
  night.leaving.push(guest);
  clearStation(station);
}

function clearStation(station) {
  station.guest = null;
  station.patdown = null;
  station.checks = {
    id: null, talk: null, scan: null, search: null, alcohol: null,
    verified: false, conflict: false
  };
}
