/**
 * Entscheidungssystem: REINLASSEN / ABWEISEN mit echten Konsequenzen.
 * Jede Entscheidung kostet etwas - Umsatz, Ruf oder Risiko.
 */

import { violationsOf } from './guests.js';
import { admitRevenue, plannedBarSpend, earn, fine, incidentCost } from './economy.js';
import { changeReputation } from './reputation.js';
import { incidentChance } from './security.js';
import { addToast, addRadio, pushLog, emptyChecks } from './state.js';
import { TUNING } from '../data/config.js';
import { chance } from '../core/rng.js';

/**
 * Hat das Team den Gast doppelt geprüft (Bouncer: ID, Security: Scan)?
 * Übereinstimmende Ergebnisse geben SECURITY VERIFIED.
 */
export function coopVerification(checks) {
  if (!checks.id || !checks.scan) return { state: 'none' };
  if (checks.scan.offline) return { state: 'none' };
  const idClean = checks.id.ok;
  const scanClean = checks.scan.ok !== false;
  if (checks.scan.ok === null) return { state: 'none' };
  if (idClean === scanClean) {
    return { state: 'verified', clean: idClean };
  }
  return { state: 'conflict' };
}

/** Gast reinlassen. */
export function admitGuest(game, guest) {
  const { state, rng, bus } = game;
  const night = state.night;
  const violations = violationsOf(guest);
  const verify = coopVerification(night.doorChecks);

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
    id: guest.id,
    guest,
    spendTotal,
    spendLeft: spendTotal,
    x: 0, y: 0, vx: 0, vy: 0, phase: rng() * 6.28
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
    resolveBadAdmission(game, guest, worst, violations);
  }

  finishGuest(game, guest, 'admitted');
  bus.emit('sfx', 'door');
  return { entry, violations, verify };
}

function resolveBadAdmission(game, guest, worst, violations) {
  const { state, rng, bus } = game;
  const night = state.night;
  const inspection = night.event?.inspection ? 2 : 1;

  // Minderjährige und Waffen sind die teuersten Fehler.
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

/** Gast abweisen. */
export function rejectGuest(game, guest) {
  const { state, bus } = game;
  const night = state.night;
  const violations = violationsOf(guest);
  const verify = coopVerification(night.doorChecks);

  night.stats.rejected++;
  state.lifetime.rejected++;

  if (violations.length > 0) {
    night.stats.correct++;
    let rep = 0.5 + violations.length * 0.2;
    if (verify.state === 'verified') { rep += 0.25; night.stats.verified++; }
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
    // Verlorener Umsatz und schlechte Stimmung.
    const lost = Math.round(plannedBarSpend(state, guest) + admitRevenue(state, guest));
    const repHit = guest.truth.vip ? -3.2 : guest.archetype === 'influencer' ? -2.6 : -1.1;
    changeReputation(state, repHit, 'zu Unrecht abgewiesen');
    state.xp += 2;
    bus.emit('sfx', 'deny');
    addToast(night, `FALSCH ABGEWIESEN (-${lost} EUR Potenzial)`, 'bad');
    if (guest.truth.vip) addRadio(night, 'FUNK', 'Das war ein VIP. Der redet morgen über uns.');
    if (guest.inspector) {
      changeReputation(state, 1, 'Testkontrolle');
    }
  }

  finishGuest(game, guest, 'rejected');
  return { violations, verify };
}

function finishGuest(game, guest, outcome) {
  const night = game.state.night;
  guest.state = outcome;
  guest.exitTimer = 1.4;
  night.leaving = night.leaving ?? [];
  night.leaving.push(guest);
  night.door = null;
  night.patdown = null;
  night.doorChecks = emptyChecks();
}
