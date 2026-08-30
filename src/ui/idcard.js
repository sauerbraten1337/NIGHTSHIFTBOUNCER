/**
 * Der Ausweis - gross, lesbar und von Hand zu prüfen.
 *
 * Das Spiel sagt nicht, was falsch ist. Der Spieler vergleicht selbst:
 * Foto gegen Gesicht, Name gegen Aussage, Geburtsdatum gegen heute,
 * Ablaufdatum gegen heute, Hologramm auf Vollständigkeit.
 * Ein Klick auf ein Feld schaltet den Status um, den der Spieler vergibt:
 *   nichts -> NICHT KORREKT -> IN ORDNUNG -> nichts
 * Das Spiel bewertet nichts davon, es notiert nur.
 */

import { escapeHtml } from './hud.js';
import { drawPortrait } from '../render/figure.js';
import { ID_FIELDS, todayString, ageFromBirth, claimedFaults } from '../systems/identity.js';
import { TUNING } from '../data/config.js';

export function createIdCard(game, { root, roleId = 'bouncer' } = {}) {
  const el = root ?? document.getElementById('idcard');
  const wrap = document.getElementById('idhand') ?? el;
  let renderedFor = null;
  let renderedMarks = '';
  const api = { el, roleId };

  el.addEventListener('click', (event) => {
    const field = event.target.closest('[data-field]')?.dataset.field;
    if (!field) return;
    game.act(api.roleId, 'mark', { field });
  });

  function update() {
    const night = game.state.night;
    const station = game.stationFor(api.roleId);
    const inspection = station?.checks?.id;
    const guest = station?.guest;

    if (!night || !inspection || !guest) {
      if (renderedFor !== null) {
        wrap.classList.add('hidden');
        el.innerHTML = '';
        renderedFor = null;
      }
      return;
    }

    const said = station.checks.talk?.said ?? [];
    const markKey = Object.entries(inspection.marks).map(([k, v]) => k + v).join('|')
      + `|said${said.length}`;
    if (renderedFor === guest.id && renderedMarks === markKey) return;
    renderedFor = guest.id;
    renderedMarks = markKey;

    wrap.classList.remove('hidden');
    el.innerHTML = template(game, guest, inspection, station);
    paintPhoto(el, guest);
  }

  api.update = update;
  return api;
}

function template(game, guest, inspection, station) {
  const doc = guest.doc;
  const age = ageFromBirth(doc.birth);
  const said = station.checks.talk?.realName;
  const claimed = claimedFaults(inspection);

  return `
    <div class="idc-head">
      <span class="idc-title">AUSWEISKONTROLLE</span>
      <span class="idc-today">HEUTE ${todayString()} · MINDESTALTER ${TUNING.minAge}</span>
    </div>

    <div class="idc-card ${doc.tampered ? '' : ''}">
      <div class="idc-photo ${mark(inspection, 'photo')}" data-field="photo" title="Foto mit dem Gast vergleichen">
        <canvas width="150" height="190"></canvas>
        <span class="idc-fieldtag">FOTO</span>
        ${badge(inspection, 'photo')}
      </div>

      <div class="idc-fields">
        <div class="idc-row static">
          <span class="k">AUSWEIS</span><span class="v">${escapeHtml(doc.issuer)} · ${escapeHtml(doc.number)}</span>
        </div>
        <div class="idc-row ${mark(inspection, 'name')}" data-field="name" title="Mit der Aussage des Gastes vergleichen">
          <span class="k">NAME</span>
          <span class="v">${escapeHtml(doc.name)}</span>${badge(inspection, 'name')}
        </div>
        <div class="idc-row ${mark(inspection, 'birth')}" data-field="birth" title="Alter berechnen, auf Manipulation achten">
          <span class="k">GEBOREN</span>
          <span class="v ${doc.tampered ? 'tampered' : ''}">${birthMarkup(doc)}</span>
          <span class="age">${age} J.</span>${badge(inspection, 'birth')}
        </div>
        <div class="idc-row ${mark(inspection, 'expiry')}" data-field="expiry" title="Gegen das heutige Datum prüfen">
          <span class="k">GÜLTIG BIS</span>
          <span class="v">${escapeHtml(doc.expiry)}</span>${badge(inspection, 'expiry')}
        </div>
        <div class="idc-row ${mark(inspection, 'marks')}" data-field="marks" title="Hologramm und Prägung prüfen">
          <span class="k">MERKMALE</span>
          <span class="v holo">${doc.marksOk ? '<i class="holo-ok"></i><i class="holo-ok"></i><i class="holo-ok"></i>'
                                              : '<i class="holo-off"></i><i class="holo-off"></i><i class="holo-off"></i>'}</span>
          ${badge(inspection, 'marks')}
        </div>
      </div>
    </div>

    ${statementBlock(station)}

    <div class="idc-foot">
      ${said ? `<span class="idc-said">GAST SAGT: <b>${escapeHtml(said)}</b></span>`
             : '<span class="idc-said dim">Namen erfragen: ANSPRECHEN</span>'}
      ${claimed.length
        ? `<span class="idc-found">${claimed.length} FELD(ER) ALS NICHT KORREKT NOTIERT</span>`
        : '<span class="idc-said dim">Feld anklicken: nicht korrekt · in Ordnung · leer</span>'}
    </div>
  `;
}

/**
 * Das Protokoll des Gesprächs. Es steht hier, damit man die Aussagen mit der
 * Karte daneben vergleichen kann - ob eine davon gelogen ist, sagt niemand.
 */
function statementBlock(station) {
  const talk = station.checks.talk;
  const said = talk?.said ?? [];
  if (!said.length) return '';
  return `
    <div class="idc-statements">
      <div class="idc-stmt-head">AUSSAGEN${talk.moreToSay ? ' · REDET NOCH' : ''}</div>
      <ul>
        ${said.map((s) => `<li>„${escapeHtml(s.text)}“</li>`).join('')}
      </ul>
    </div>`;
}

function birthMarkup(doc) {
  const [y, m, d] = doc.birth.split('-');
  if (!doc.tampered) return `${y}-${m}-${d}`;
  // Manipulierte Jahreszahl: leicht versetzt und anders eingefärbt.
  return `<span class="digit-off">${y}</span>-${m}-${d}`;
}

/**
 * Die Farbe zeigt die Einschätzung des SPIELERS:
 * rot = er hält das Feld für nicht korrekt, grün = er hält es für in Ordnung.
 */
function mark(inspection, field) {
  const m = inspection.marks[field];
  return m === 'suspect' ? 'suspect' : m === 'fine' ? 'fine' : '';
}

function badge(inspection, field) {
  const m = inspection.marks[field];
  if (m === 'suspect') return '<span class="idc-badge suspect">NICHT KORREKT</span>';
  if (m === 'fine') return '<span class="idc-badge fine">IN ORDNUNG</span>';
  return '';
}

function paintPhoto(el, guest) {
  const canvas = el.querySelector('.idc-photo canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  drawPortrait(ctx, guest.doc.photoLook, canvas.width, canvas.height, guest.seed % 100);
  // Rasterung wie bei einem gedruckten Passfoto
  ctx.fillStyle = 'rgba(0,0,0,0.16)';
  for (let y = 0; y < canvas.height; y += 3) ctx.fillRect(0, y, canvas.width, 1);
}

export { ID_FIELDS };
