/**
 * Der Notizzettel: zwei handschriftliche Seiten, beide vom Spieler gefuehrt.
 *
 *   SEITE 1 - CHECKLISTE
 *     Was ist bei diesem Gast noch zu pruefen? Der Spieler hakt selbst ab.
 *     Das Spiel setzt keinen einzigen Haken fuer ihn.
 *
 *   SEITE 2 - BEFUND
 *     Der Spieler traegt selbst ein, welche Punkte der Norm entsprechen und
 *     welche nicht. Auch hier bewertet das Spiel nichts - erst nach der
 *     Entscheidung wird abgerechnet.
 *
 * Umgeblaettert wird ueber die beiden Reiter am Kopf des Zettels.
 */

import { escapeHtml } from './hud.js';
import { isSolo } from '../systems/state.js';
import { checklistFor, topicsFor, emptyNotes } from '../systems/notes.js';

export function createNotepad(game, { root } = {}) {
  const el = root ?? document.getElementById('notepad');
  const hand = document.getElementById('notepad-hand');
  let lastKey = '';

  // Klicks: Reiter umblaettern, Haken setzen, Befund umschalten.
  el.addEventListener('click', (event) => {
    const roleId = game.dossierRole ?? game.players[0]?.id ?? 'bouncer';
    const tab = event.target.closest('[data-page]');
    if (tab) { game.act(roleId, 'page', { page: Number(tab.dataset.page) }); return; }
    const check = event.target.closest('[data-check]');
    if (check) { game.act(roleId, 'check', { item: check.dataset.check }); return; }
    const topic = event.target.closest('[data-topic]');
    if (topic) game.act(roleId, 'note', { topic: topic.dataset.topic });
  });

  function update() {
    const roleId = game.dossierRole ?? game.players[0]?.id ?? 'bouncer';
    const player = game.players.find((p) => p.id === roleId) ?? game.players[0];
    const station = game.stationFor(roleId);
    const guest = station?.guest;
    const notes = station?.notes ?? emptyNotes();

    if (!game.state.night || !guest) {
      if (lastKey !== 'empty') {
        lastKey = 'empty';
        el.classList.remove('hidden');
        hand?.classList.remove('hidden');
        el.innerHTML = `
          <div class="np-head">SCHICHTNOTIZEN</div>
          <div class="np-empty">${player?.area === 'airlock' ? 'Schleuse frei.' : 'Niemand an der Tür.'}</div>`;
      }
      return;
    }

    const solo = isSolo(game.state);
    const area = player?.area === 'airlock' ? 'airlock' : 'outside';
    const key = [
      guest.id, notes.page,
      Object.keys(notes.checked).sort().join(','),
      Object.entries(notes.topics).sort().map(([k, v]) => k + v).join(','),
      player?.lastResult?.text ?? ''
    ].join('|');
    if (key === lastKey) return;
    lastKey = key;

    el.classList.remove('hidden');
    hand?.classList.remove('hidden');
    el.innerHTML = `
      <div class="np-tabs">
        <button class="np-tab ${notes.page === 0 ? 'on' : ''}" data-page="0">CHECKLISTE</button>
        <button class="np-tab ${notes.page === 1 ? 'on' : ''}" data-page="1">BEFUND</button>
      </div>
      <div class="np-guest">${escapeHtml(guestName(station, guest))}</div>
      ${notes.page === 0 ? checklistPage(notes, area, solo) : findingPage(notes, area, solo)}
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

/** Seite 1: was ich noch pruefen muss - selbst abzuhaken. */
function checklistPage(notes, area, solo) {
  const items = checklistFor(area, solo);
  const open = items.filter((c) => !notes.checked[c.id]).length;
  return `
    <ul class="np-list np-checklist">
      ${items.map((c) => `
        <li class="np-row ${notes.checked[c.id] ? 'ok' : 'todo'}" data-check="${c.id}">
          <span class="np-box">${notes.checked[c.id] ? '✓' : ''}</span>
          <span class="np-task">${escapeHtml(c.label)}</span>
        </li>`).join('')}
    </ul>
    <div class="np-foot-note">${open === 0 ? 'alles abgehakt' : `noch ${open} offen`}</div>`;
}

/** Seite 2: mein Befund - entspricht der Norm oder eben nicht. */
function findingPage(notes, area, solo) {
  const topics = topicsFor(area, solo);
  return `
    <ul class="np-list np-findings">
      ${topics.map((t) => {
        const st = notes.topics[t.id];
        const cls = st === 'bad' ? 'bad' : st === 'ok' ? 'ok' : 'todo';
        const verdict = st === 'bad' ? 'entspricht nicht'
          : st === 'ok' ? 'entspricht der Norm' : '—';
        return `
        <li class="np-row ${cls}" data-topic="${t.id}">
          <span class="np-mark">${st === 'bad' ? '✗' : st === 'ok' ? '✓' : '○'}</span>
          <span class="np-task">${escapeHtml(t.label)}<i>${escapeHtml(t.hint)}</i></span>
          <span class="np-note">${escapeHtml(verdict)}</span>
        </li>`;
      }).join('')}
    </ul>
    <div class="np-foot-note">Zeile anklicken: Norm · nicht · leer</div>`;
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
