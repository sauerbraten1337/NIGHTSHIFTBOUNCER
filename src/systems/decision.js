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
import { incidentChance, scorePatdown } from './security.js';
import { addToast, pushLog, isSolo } from './state.js';
import { emptyNotes, reportedProblems } from './notes.js';
import { moveToAirlock } from './queue.js';
import { inspectionVerdict, scoreInspection } from './identity.js';
import { TUNING } from '../data/config.js';
import { chance } from '../core/rng.js';

/**
 * Koop-Verifikation: das Urteil der Tür (Ausweisprüfung) gegen den Befund der
 * Schleuse (Abtasten und Alkoholtest). Zwei Augenpaare, ein Ergebnis.
 */
export function coopVerification(guest, airlockChecks) {
  const doorVerdict = guest?.doorVerdict;
  if (!doorVerdict || !doorVerdict.checked) return { state: 'none' };
  // Die Schleuse hat erst dann ein belastbares Urteil, wenn sie fertig ist.
  const searched = airlockChecks?.search?.done;
  const tested = !!airlockChecks?.alcohol;
  if (!searched || !tested) return { state: 'none' };

  const securityClean = !(airlockChecks.search.flagged?.length)
    && airlockChecks.alcohol.promille < airlockChecks.alcohol.limit;
  if (doorVerdict.clean === securityClean) return { state: 'verified', clean: securityClean };
  return { state: 'conflict', doorClean: doorVerdict.clean, securityClean };
}

/**
 * Solo: Es gibt kein zweites Augenpaar. Wer aber wirklich alles prüft -
 * Ausweis, alle Zonen, Alkoholtest - arbeitet nachweislich gründlich.
 */
export function soloVerification(checks) {
  if (!checks.id || !checks.search?.done || !checks.alcohol) return { state: 'none' };
  return { state: 'verified', clean: inspectionVerdict(checks.id).clean };
}

/* ------------------------------------------------------------------ */

/**
 * Was hat der Spieler selbst gefunden?
 *
 * Erst hier - nach der Entscheidung - vergleicht das Spiel die Angaben des
 * Spielers mit der Wahrheit. Waehrend der Kontrolle bekommt er dazu nichts
 * zu sehen. Jede zutreffende Beanstandung bringt am Ende der Nacht Geld.
 */
export function collectFindings(guest, station) {
  const checks = station.checks;
  const notes = station.notes ?? emptyNotes();
  const hits = [];
  const wrong = [];
  const missed = [];

  // Ausweis: die vom Spieler als "nicht korrekt" markierten Felder.
  if (checks.id) {
    const s = scoreInspection(checks.id, guest);
    for (const f of s.hits) hits.push({ kind: 'id', label: f });
    for (const f of s.wrong) wrong.push({ kind: 'id', label: f });
    for (const f of s.missed) missed.push({ kind: 'id', label: f });
  }

  // Abtasten: die vom Spieler beanstandeten Gegenstände.
  if (station.patdown) {
    const s = scorePatdown(station.patdown, guest);
    for (const f of s.hits) hits.push({ kind: 'item', label: f.item.label });
    for (const f of s.wrong) wrong.push({ kind: 'item', label: f.item.label });
    for (const f of s.missed) missed.push({ kind: 'item', label: f.item.label });
  }

  // Notizzettel: der Spieler hat den Alkoholwert selbst als zu hoch notiert.
  const problems = reportedProblems(notes);
  if (checks.alcohol) {
    const over = checks.alcohol.promille >= checks.alcohol.limit;
    const noted = problems.includes('alcohol');
    if (noted && over) hits.push({ kind: 'alcohol', label: 'Alkoholwert' });
    else if (noted && !over) wrong.push({ kind: 'alcohol', label: 'Alkoholwert' });
    else if (!noted && over) missed.push({ kind: 'alcohol', label: 'Alkoholwert' });
  }

  // Zustand der Person: nur als Angabe wertbar, wenn der Gast wirklich
  // beeintraechtigt ist.
  if (problems.includes('person')) {
    if (guest.truth.impaired > 0.5 || guest.truth.drunk > 0.6) {
      hits.push({ kind: 'person', label: 'Zustand der Person' });
    } else {
      wrong.push({ kind: 'person', label: 'Zustand der Person' });
    }
  }

  return { hits, wrong, missed };
}

/** Findings verbuchen und die Praemie gutschreiben. */
function bookFindings(game, guest, station) {
  const { state } = game;
  const night = state.night;
  const score = collectFindings(guest, station);

  night.stats.findings += score.hits.length;
  night.stats.falseAlarms += score.wrong.length;
  night.stats.overlooked += score.missed.length;

  const pay = score.hits.length * TUNING.findingBonus;
  if (pay > 0) {
    night.stats.findingPay += pay;
    earn(state, pay, 'finding');
    addToast(night, `${score.hits.length} UNREGELMÄSSIGKEIT${score.hits.length > 1 ? 'EN' : ''} +${pay} EUR`, 'good');
  }
  return score;
}

/** Bouncer schickt den Gast weiter in die Schleuse (nur Koop). */
export function passGuest(game, guest, station) {
  const { state, rng, bus } = game;
  const night = state.night;
  const verdict = inspectionVerdict(station.checks.id);

  guest.doorVerdict = {
    clean: verdict.checked ? verdict.clean : null,
    checked: verdict.checked,
    claimed: verdict.claimed ?? [],
    talked: !!station.checks.talk
  };

  // Die Tuer bucht ihre eigenen Befunde sofort ab.
  guest.doorScore = bookFindings(game, guest, station);

  night.stats.passed++;
  moveToAirlock(game, guest);
  clearStation(station);
  guest.said = null;
  addToast(night, verdict.checked
    ? (verdict.clean ? 'TÜR: AUSWEIS GEPRÜFT, KOMMT DURCH' : 'TÜR: AUFFÄLLIG - GENAU ANSEHEN')
    : 'TÜR: UNGEPRÜFT DURCHGELASSEN', verdict.clean === false ? 'warn' : 'info', 3);
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

  bookFindings(game, guest, station);

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

  bookFindings(game, guest, station);

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
      addToast(night, 'TESTPERSON ERKANNT', 'good', 3);
    }
  } else {
    night.stats.mistakes++;
    const lost = Math.round(plannedBarSpend(state, guest) + admitRevenue(state, guest));
    const repHit = guest.truth.vip ? -3.2 : guest.archetype === 'influencer' ? -2.6 : -1.1;
    changeReputation(state, repHit, 'zu Unrecht abgewiesen');
    state.xp += 2;
    bus.emit('sfx', 'deny');
    addToast(night, `FALSCH ABGEWIESEN (-${lost} EUR Potenzial)`, 'bad');
    if (guest.truth.vip) addToast(night, 'DAS WAR EIN VIP', 'bad', 4);
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
  // Der Gast ist abgearbeitet - er zaehlt gegen den Schichtplan.
  night.processed++;
  clearStation(station);
}

function clearStation(station) {
  station.guest = null;
  station.patdown = null;
  station.notes = emptyNotes();
  station.checks = {
    id: null, talk: null, search: null, alcohol: null,
    verified: false, conflict: false
  };
}
