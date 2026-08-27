/**
 * Befund-Panel: was an DEINER Station bisher herausgefunden wurde.
 * Zeigt nur Ergebnisse eigener Kontrollen - keine versteckte Wahrheit.
 */

import { escapeHtml } from './hud.js';
import { scannerLabel } from '../systems/scanner.js';
import { upgradeLevel, isSolo } from '../systems/state.js';
import { idSummary } from '../systems/identity.js';
import { AREAS } from '../data/config.js';

export function renderDossier(el, titleEl, game) {
  const night = game.state.night;
  const roleId = game.dossierRole ?? game.localRole ?? game.players[0]?.id ?? 'bouncer';
  const player = game.players.find((p) => p.id === roleId) ?? game.players[0];
  const station = game.stationFor(roleId);
  const guest = station?.guest;

  if (titleEl) {
    const area = player?.area === 'airlock' ? AREAS.airlock : AREAS.outside;
    titleEl.textContent = `${area.label} — BEFUNDE`;
  }

  if (!night || !guest) {
    el.className = 'dossier-empty';
    el.textContent = player?.area === 'airlock' ? 'Schleuse frei.' : 'Niemand an der Tür.';
    return;
  }

  const checks = station.checks;
  const airlock = player?.area === 'airlock';
  const verdict = guest.doorVerdict;

  el.className = '';
  el.innerHTML = `
    <div class="check-row">
      <span class="label">GAST</span>
      <span class="value">${escapeHtml(checks.id ? checks.id.doc.name : 'unbekannt')}
        <span style="color:var(--dim)"> · ${escapeHtml(guest.archetypeLabel ?? '')}</span></span>
    </div>
    ${airlock && verdict ? row('TÜR', doorVerdictText(verdict), verdict.clean === false ? 'warn' : 'ok') : ''}
    ${!airlock ? row('AUSWEIS', checks.id ? idSummary(checks.id) : 'nicht verlangt',
      checks.id ? (checks.id.found.length ? 'bad' : 'ok') : 'pending') : ''}
    ${!airlock ? row('AUSSAGE', checks.talk ? `"${checks.talk.realName}" · ${checks.talk.hint}` : 'kein Gespräch',
      checks.talk ? 'warn' : 'pending') : ''}
    ${airlock || isSolo(game.state) ? scanRow(game, checks) : ''}
    ${airlock || isSolo(game.state) ? searchRow(station, checks) : ''}
    ${airlock || isSolo(game.state) ? alcoholRow(checks) : ''}
    ${checks.verified ? '<div class="verify-badge">SECURITY VERIFIED</div>' : ''}
    ${checks.conflict ? '<div class="verify-badge conflict">CHECK AGAIN</div>' : ''}
    ${player?.lastResult ? `<div class="check-row"><span class="label">ZULETZT</span>
      <span class="value ${resultClass(player.lastResult.kind)}">${escapeHtml(player.lastResult.text)}</span></div>` : ''}
  `;
}

function doorVerdictText(verdict) {
  if (!verdict.checked) return 'ungeprüft durchgelassen';
  if (verdict.clean) return 'Ausweis geprüft, sauber';
  return `beanstandet: ${verdict.found.join(', ')}`;
}

function row(label, value, cls = '') {
  return `<div class="check-row"><span class="label">${label}</span>` +
    `<span class="value ${cls}">${escapeHtml(value)}</span></div>`;
}

function scanRow(game, checks) {
  const level = upgradeLevel(game.state, 'scanner');
  if (!checks.scan) return row('SCAN', `bereit (${scannerLabel(level)})`, 'pending');
  if (checks.scan.offline) return row('SCAN', 'GERÄT OFFLINE', 'warn');
  return row('SCAN', checks.scan.text, checks.scan.ok === false ? 'bad' : checks.scan.ok ? 'ok' : 'warn');
}

function searchRow(station, checks) {
  if (!station.patdown) return row('ABTASTEN', 'nicht begonnen', 'pending');
  const res = checks.search;
  if (!res) return row('ABTASTEN', 'läuft', 'warn');
  if (res.found) return row('ABTASTEN', res.text, 'bad');
  if (res.done) return row('ABTASTEN', 'keine Auffälligkeiten', 'ok');
  return row('ABTASTEN', res.text, 'warn');
}

function alcoholRow(checks) {
  if (!checks.alcohol) return row('ALKOHOL', 'kein Test', 'pending');
  return row('ALKOHOL', `${checks.alcohol.promille} ‰ — ${checks.alcohol.text}`,
    checks.alcohol.overLimit ? 'bad' : 'ok');
}

function resultClass(kind) {
  return kind === 'ok' ? 'ok' : kind === 'bad' || kind === 'deny' ? 'bad' : 'warn';
}
