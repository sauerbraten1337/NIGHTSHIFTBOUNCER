/** Tür-Dossier: zeigt genau das, was das Team tatsaechlich herausgefunden hat. */

import { escapeHtml } from './hud.js';
import { visibleTells } from '../systems/guests.js';
import { coopVerification } from '../systems/decision.js';
import { scannerLabel } from '../systems/scanner.js';
import { upgradeLevel } from '../systems/state.js';

export function renderDossier(el, game) {
  const night = game.state.night;
  const guest = night?.door;

  if (!guest) {
    el.className = 'dossier-empty';
    el.textContent = 'Kein Gast an der Tür.';
    el.dataset.guest = '';
    return;
  }

  const checks = night.doorChecks;
  const tells = visibleTells(guest, game.state.talents.street);
  const verify = coopVerification(checks);

  el.className = '';
  el.innerHTML = `
    <div class="dossier-head">
      <span class="dossier-name">${escapeHtml(guest.isArtist || checks.id ? guest.doc.name : 'UNBEKANNT')}</span>
      <span class="dossier-type">${escapeHtml(guest.archetypeLabel.toUpperCase())}</span>
    </div>
    ${row('SICHT', tells.length ? tells.join(', ') : 'unauffällig', tells.length ? 'warn' : 'pending')}
    ${idRow(checks)}
    ${scanRow(game, checks)}
    ${searchRow(night, checks)}
    ${talkRow(checks)}
    ${alcoholRow(checks)}
    ${checks.id ? idCard(guest, checks.id) : ''}
    ${verify.state === 'verified' ? '<div class="verify-badge">SECURITY VERIFIED</div>' : ''}
    ${verify.state === 'conflict' ? '<div class="verify-badge conflict">CHECK AGAIN</div>' : ''}
  `;
}

function row(label, value, cls = '') {
  return `<div class="check-row"><span class="label">${label}</span>` +
    `<span class="value ${cls}">${escapeHtml(value)}</span></div>`;
}

function idRow(checks) {
  if (!checks.id) return row('ID', 'nicht geprüft', 'pending');
  if (checks.id.docTooYoung) return row('ID', `ZU JUNG (${checks.id.doc.age})`, 'bad');
  if (checks.id.detected.length) return row('ID', checks.id.detectedLabels.join(', '), 'bad');
  return row('ID', 'keine Auffälligkeit', 'ok');
}

function scanRow(game, checks) {
  const level = upgradeLevel(game.state, 'scanner');
  if (!checks.scan) return row('SCAN', `bereit (${scannerLabel(level)})`, 'pending');
  if (checks.scan.offline) return row('SCAN', 'GERÄT OFFLINE', 'warn');
  return row('SCAN', checks.scan.text, checks.scan.ok === false ? 'bad' : checks.scan.ok ? 'ok' : 'warn');
}

function searchRow(night, checks) {
  if (!night.patdown) return row('SEARCH', 'nicht abgetastet', 'pending');
  const res = checks.search;
  if (!res) return row('SEARCH', 'läuft', 'warn');
  if (res.found) return row('SEARCH', res.text, 'bad');
  if (res.done) return row('SEARCH', 'keine Auffälligkeiten', 'ok');
  return row('SEARCH', res.text, 'warn');
}

function talkRow(checks) {
  if (!checks.talk) return row('TALK', 'kein Gespräch', 'pending');
  return row('TALK', `${checks.talk.hint}, ${checks.talk.moodHint}`, 'warn');
}

function alcoholRow(checks) {
  if (!checks.alcohol) return row('ALKO', 'kein Test', 'pending');
  return row('ALKO', `${checks.alcohol.promille} ‰ — ${checks.alcohol.text}`,
    checks.alcohol.overLimit ? 'bad' : 'ok');
}

function idCard(guest, id) {
  const doc = guest.doc;
  const bad = (flag) => (flag ? 'style="color:var(--red)"' : '');
  return `
    <div class="id-card">
      <div class="id-photo"></div>
      <div class="id-fields">
        <div><span>NAME</span><span ${bad(id.detected.includes('name'))}>${escapeHtml(doc.name)}</span></div>
        <div><span>GEB.</span><span ${bad(id.detected.includes('age'))}>${escapeHtml(doc.birth)}</span></div>
        <div><span>ALTER</span><span ${bad(doc.age < 18)}>${doc.age}</span></div>
        <div><span>GÜLTIG</span><span ${bad(id.expired)}>${escapeHtml(doc.expiry)}</span></div>
        <div><span>MERKMALE</span><span ${bad(id.detected.includes('marks'))}>${id.detected.includes('marks') ? 'FEHLEN' : 'OK'}</span></div>
        <div><span>FOTO</span><span ${bad(id.detected.includes('photo'))}>${id.detected.includes('photo') ? 'ABWEICHUNG' : 'PASST'}</span></div>
        <div><span>NR.</span><span>${escapeHtml(doc.number)}</span></div>
      </div>
    </div>`;
}
