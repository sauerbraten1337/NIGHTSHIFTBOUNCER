/** Night Report: die Bilanz nach jeder Nacht. */

import { escapeHtml } from './hud.js';
import { clubTier, rank } from '../systems/state.js';
import { rankProgress } from '../systems/progression.js';
import { REPORT_QUOTES } from '../data/dialogue.js';

export function renderReport(game, onContinue) {
  const { state } = game;
  const night = state.night;
  const s = night.stats;
  const stars = '★'.repeat(night.rating) + '☆'.repeat(5 - night.rating);
  const rep = Math.round((night.repDelta ?? 0) * 10) / 10;
  const netto = s.revenue - s.artistFee;
  const prog = rankProgress(state);

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <h1 class="title">NIGHT COMPLETE</h1>
    <div class="subtitle">NIGHT ${String(state.nightIndex).padStart(2, '0')} · ${escapeHtml(night.event.label)} · ${escapeHtml(clubTier(state).label)}</div>

    <div class="stats-grid">
      ${cell('GÄSTE', s.arrived)}
      ${cell('EINLASS', s.admitted, 'good')}
      ${cell('ABGEWIESEN', s.rejected)}
      ${cell('ABGESPRUNGEN', s.left, s.left > s.admitted * 0.3 ? 'bad' : '')}
      ${cell('UMSATZ', `€${Math.round(s.revenue).toLocaleString('de-DE')}`, 'good')}
      ${cell('VORFÄLLE', s.incidents, s.incidents > 0 ? 'bad' : 'good')}
      ${cell('VIPS', s.vips)}
      ${cell('VERIFIED', s.verified, 'good')}
    </div>

    <h2 class="sec">BILANZ</h2>
    ${kv('Eintritt', `€${Math.round(s.entry).toLocaleString('de-DE')}`, 'good')}
    ${kv('Bar & VIP', `€${Math.round(s.bar).toLocaleString('de-DE')}`, 'good')}
    ${s.fines ? kv('Bußgelder & Schäden', `−€${Math.round(s.fines).toLocaleString('de-DE')}`, 'bad') : ''}
    ${s.artistFee ? kv('Gage', `−€${Math.round(s.artistFee).toLocaleString('de-DE')}`, 'bad') : ''}
    ${kv('Netto', `€${Math.round(netto).toLocaleString('de-DE')}`, netto >= 0 ? 'good' : 'bad')}

    <h2 class="sec">BEWERTUNG</h2>
    <div class="stars">${stars}</div>
    ${kv('Richtige Entscheidungen', `${s.correct} / ${s.correct + s.mistakes}`)}
    ${kv('Reputation', `${rep >= 0 ? '+' : ''}${rep}`, rep >= 0 ? 'good' : 'bad')}
    ${kv('Erfahrung', `+${night.xpGained} XP`)}
    ${kv('Rang', `${rank(state).label}${prog.next ? ` → ${prog.next.label} (${Math.round(prog.ratio * 100)}%)` : ' (max)'}`)}
    ${night.artist ? kv(`Act: ${night.artist.name}`,
      night.artistPlaying ? 'hat gespielt' : night.artistMissed ? 'nie eingelassen' : 'abgewiesen',
      night.artistPlaying ? 'good' : 'bad') : ''}

    <p style="margin-top:20px;color:var(--dim);font-size:12px">"${escapeHtml(quote(state))}"</p>

    <div class="btn-row">
      <button class="btn primary" id="report-next">UPGRADES ANSEHEN</button>
    </div>
  `;
  wrap.querySelector('#report-next').addEventListener('click', onContinue);
  return wrap;
}

function cell(k, v, cls = '') {
  return `<div class="stat-cell"><span class="k">${k}</span><span class="v ${cls}">${v}</span></div>`;
}

function kv(k, v, cls = '') {
  return `<div class="kv"><span>${escapeHtml(k)}</span><span class="v ${cls}">${escapeHtml(String(v))}</span></div>`;
}

function quote(state) {
  const idx = (state.nightIndex * 7) % REPORT_QUOTES.length;
  return REPORT_QUOTES[idx];
}
