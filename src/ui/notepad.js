/**
 * Der Notizzettel: handschriftliche Checkliste an der Tür.
 *
 * Ersetzt die alte Statusanzeige. Er zeigt nur, was DU an DEINER Station
 * schon geprüft hast und was noch offen ist - abgehakt, durchgestrichen,
 * mit hingekritzelten Bemerkungen.
 */

import { escapeHtml } from './hud.js';
import { isSolo } from '../systems/state.js';
import { idSummary } from '../systems/identity.js';
import { scannerLabel } from '../systems/scanner.js';
import { upgradeLevel } from '../systems/state.js';
import { visibleTells } from '../systems/guests.js';

export function createNotepad(game, { root } = {}) {
  const el = root ?? document.getElementById('notepad');
  let lastKey = '';

  function update() {
    const roleId = game.dossierRole ?? game.players[0]?.id ?? 'bouncer';
    const player = game.players.find((p) => p.id === roleId) ?? game.players[0];
    const station = game.stationFor(roleId);
    const guest = station?.guest;

    if (!game.state.night || !guest) {
      if (lastKey !== 'empty') {
        lastKey = 'empty';
        el.classList.remove('hidden');
        el.innerHTML = `
          <div class="np-head">SCHICHTNOTIZEN</div>
          <div class="np-empty">${player?.area === 'airlock' ? 'Schleuse frei.' : 'Niemand an der Tür.'}</div>`;
      }
      return;
    }

    const lines = buildLines(game, station, guest, player);
    const key = `${guest.id}|${lines.map((l) => l.state + l.note).join('|')}`;
    if (key === lastKey) return;
    lastKey = key;

    el.classList.remove('hidden');
    el.innerHTML = `
      <div class="np-head">SCHICHTNOTIZEN</div>
      <div class="np-guest">${escapeHtml(guestName(station, guest))}</div>
      <ul class="np-list">
        ${lines.map(row).join('')}
      </ul>
      ${footer(station, player)}
    `;
  }

  return { update, el };
}

function guestName(station, guest) {
  if (station.checks.id) return station.checks.id.doc.name;
  if (guest.doorVerdict) return guest.doc?.name ?? 'Gast';
  return 'unbekannt';
}

function row(line) {
  const mark = line.state === 'ok' ? '✓' : line.state === 'bad' ? '✗' : line.state === 'part' ? '~' : '○';
  return `<li class="np-row ${line.state}">
    <span class="np-mark">${mark}</span>
    <span class="np-task">${escapeHtml(line.label)}</span>
    <span class="np-note">${escapeHtml(line.note)}</span>
  </li>`;
}

function buildLines(game, station, guest, player) {
  const checks = station.checks;
  const solo = isSolo(game.state);
  const outside = player?.area !== 'airlock';
  const lines = [];

  if (outside) {
    // --- Türseite ---
    const seen = checks.id
      ? ['photo', 'name', 'birth', 'expiry', 'marks'].filter((f) => checks.id.marks[f]).length
      : 0;
    lines.push(check('Ausweis', checks.id
      ? (checks.id.found.length ? ['bad', idSummary(checks.id)]
        : seen === 5 ? ['ok', 'alles geprüft'] : ['part', 'liegt vor'])
      : ['todo', 'nicht verlangt']));

    if (checks.id) {
      lines.push(check('  Felder', seen === 5
        ? ['ok', 'alle 5 durch']
        : ['part', `${seen}/5 angesehen`]));
    }

    lines.push(check('Ansprechen', checks.talk
      ? ['ok', `"${checks.talk.realName}"`]
      : ['todo', 'Name unbekannt']));

    const tells = visibleTells(guest, game.state.talents.street);
    lines.push(check('Zustand', tells.length
      ? ['bad', tells.slice(0, 2).join(', ')]
      : ['ok', 'unauffällig']));
  } else {
    // --- Schleusenseite: was die Tür gemeldet hat ---
    const v = guest.doorVerdict;
    lines.push(check('Von der Tür', v
      ? (v.checked
        ? (v.clean ? ['ok', 'Ausweis geprüft'] : ['bad', `beanstandet: ${v.found.join(', ')}`])
        : ['part', 'ungeprüft durchgewinkt'])
      : ['todo', '—']));
  }

  if (!outside || solo) {
    // --- Kontrollseite ---
    const level = upgradeLevel(game.state, 'scanner');
    lines.push(check('Scan', checks.scan
      ? (checks.scan.offline ? ['part', 'Gerät offline']
        : checks.scan.ok === false ? ['bad', checks.scan.text] : ['ok', checks.scan.text])
      : ['todo', scannerLabel(level).toLowerCase()]));

    const pat = station.patdown;
    if (!pat) {
      lines.push(check('Abtasten', ['todo', 'nicht begonnen']));
    } else {
      for (const zone of Object.values(pat.zones)) {
        const label = `  ${zone.label.toLowerCase()}`;
        if (zone.state === 'done') {
          lines.push(check(label, zone.picked
            ? (zone.correct ? ['bad', zone.picked.label] : ['part', `${zone.picked.label}?`])
            : (zone.missed ? ['part', 'freigegeben'] : ['ok', 'sauber'])));
        } else if (zone.state === 'open') {
          lines.push(check(label, ['part', 'liegt auf dem Tisch']));
        } else {
          lines.push(check(label, ['todo', pat.hint === zone.id ? 'Detektor piept!' : 'offen']));
        }
      }
    }

    lines.push(check('Alkotest', checks.alcohol
      ? [checks.alcohol.promille >= checks.alcohol.limit ? 'bad' : 'ok',
        `${checks.alcohol.promille.toFixed(1)} ‰`]
      : ['todo', 'kein Wert']));
  }

  return lines;
}

function check(label, [state, note]) {
  return { label, state, note };
}

function footer(station, player) {
  const checks = station.checks;
  if (checks.verified) return '<div class="np-stamp ok">SECURITY VERIFIED</div>';
  if (checks.conflict) return '<div class="np-stamp warn">CHECK AGAIN</div>';
  if (player?.lastResult) {
    return `<div class="np-scribble ${player.lastResult.kind}">${escapeHtml(player.lastResult.text)}</div>`;
  }
  return '';
}
