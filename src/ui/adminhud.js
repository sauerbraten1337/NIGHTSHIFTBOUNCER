/**
 * Röntgenblick (nur mit Admin-Code): blendet die versteckte Wahrheit des
 * Gastes ein, der gerade an der Kontrolle steht.
 *
 * Nur zum Testen - im normalen Spiel ist genau das die Aufgabe, die man
 * sich selbst erarbeiten muss.
 */

import { cheats } from '../systems/admin.js';
import { escapeHtml } from './hud.js';
import { ID_ISSUES } from '../data/config.js';
import { aggressionRisk } from '../systems/aggression.js';

export function createAdminHud(game) {
  const el = document.createElement('div');
  el.className = 'adminhud hidden';
  document.getElementById('hud').appendChild(el);

  function update() {
    const on = cheats.unlocked && cheats.reveal && game.state.phase === 'night' && !!game.state.night;
    el.classList.toggle('hidden', !on);
    if (!on) return;

    const night = game.state.night;
    const stations = Object.values(night.stations).filter((s) => s.guest);
    el.innerHTML = `
      <div class="adminhud-head">RÖNTGENBLICK · NACHT ${String(game.state.nightIndex).padStart(2, '0')} · ${night.processed}/${night.quota}</div>
      ${stations.length
        ? stations.map((s) => stationHtml(s)).join('')
        : '<div class="adminhud-empty">Niemand an der Kontrolle.</div>'}`;
  }

  function stationHtml(station) {
    const g = station.guest;
    const t = g.truth;
    const rows = [
      ['NAME', g.name],
      ['ALTER', `${t.age}${t.underage ? ' — MINDERJÄHRIG' : ''}`],
      ['AUSWEIS', t.idValid ? 'in Ordnung' : t.idIssues.map(issueLabel).join(', ')],
      ['PROMILLE', `${(t.drunk * 2.4).toFixed(1)} ‰`],
      ['SUBSTANZ', t.impaired > 0 ? `${Math.round(t.impaired * 100)} %` : '—'],
      ['VERBOTENES', t.contraband ? `${t.contraband.label} (${zoneName(t.contrabandZone)})` : '—'],
      ['LISTE', t.blacklisted ? 'GESPERRT' : '—'],
      ['VIP', t.vip ? 'ja' : '—'],
      ['AUSRASTRISIKO', `${Math.round(aggressionRisk(g) * 100)} %`]
    ];
    return `
      <div class="adminhud-station">
        <div class="adminhud-title">${station.id === 'airlock' ? 'SCHLEUSE' : 'TÜR'}</div>
        ${rows.map(([k, v]) => `
          <div class="adminhud-row"><span>${escapeHtml(k)}</span><b>${escapeHtml(String(v))}</b></div>`).join('')}
      </div>`;
  }

  return { update };
}

function issueLabel(id) {
  return ID_ISSUES.find((i) => i.id === id)?.label ?? id;
}

function zoneName(id) {
  return { jacket: 'Jacke', pockets: 'Hosentaschen', bag: 'Tasche' }[id] ?? id ?? '—';
}
