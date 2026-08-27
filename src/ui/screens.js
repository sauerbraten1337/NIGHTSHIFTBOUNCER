/** Screen-Verwaltung: Menue, Briefing, Report, Shop, Pause, Hilfe. */

import { escapeHtml } from './hud.js';
import { renderReport } from './report.js';
import { renderShop } from './shop.js';
import { CLUB_NAME } from '../data/config.js';
import { clubTier, capacity, rank } from '../systems/state.js';
import { hasSave, clearSave } from '../systems/save.js';
import { repBand } from '../systems/reputation.js';

export function createScreens(game) {
  const root = document.getElementById('screen');
  const inner = document.getElementById('screen-inner');

  function show(node) {
    inner.innerHTML = '';
    inner.appendChild(node);
    root.classList.remove('hidden');
    inner.scrollTop = 0;
  }

  function hide() {
    root.classList.add('hidden');
  }

  function menu({ onNew, onContinue }) {
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">${CLUB_NAME}</h1>
      <div class="subtitle">NIGHTSHIFT — BOUNCER CO-OP · 2D TOP-DOWN SIMULATION</div>
      <p style="font-size:13px;line-height:1.6;color:#aab2bf;max-width:720px">
        Ihr arbeitet zu zweit an der Tür eines heruntergekommenen Underground-Clubs.
        Gäste kommen, ihr kontrolliert sie, entscheidet und lebt mit den Folgen.
        Jede Nacht bringt Geld und Ruf — beides baut den Club sichtbar aus.
      </p>

      <h2 class="sec">STEUERUNG — ZWEI SPIELER AN EINER TASTATUR</h2>
      <div class="keys-help">
        <div><b>SPIELER 1 — BOUNCER</b><br>
          Bewegung <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd><br>
          <kbd>1</kbd> ID CHECK · <kbd>2</kbd> TALK<br>
          <kbd>3</kbd> ADMIT · <kbd>4</kbd> REJECT
        </div>
        <div><b>SPIELER 2 — SECURITY</b><br>
          Bewegung <kbd>←</kbd><kbd>↑</kbd><kbd>↓</kbd><kbd>→</kbd><br>
          <kbd>7</kbd> SCAN · <kbd>8</kbd> SEARCH<br>
          Abtasten <kbd>J</kbd><kbd>K</kbd><kbd>L</kbd> · <kbd>9</kbd> ALKO · <kbd>0</kbd> CALM
        </div>
        <div><b>TEAM</b><br>
          ID-Check und Scan auf denselben Gast ergeben<br>
          <span style="color:var(--green)">SECURITY VERIFIED</span> (Bonus).<br>
          Widersprüchliche Ergebnisse: <span style="color:var(--amber)">CHECK AGAIN</span>.
        </div>
        <div><b>SYSTEM</b><br>
          <kbd>P</kbd> Pause · <kbd>M</kbd> Ton · <kbd>H</kbd> Hilfe<br>
          Jede Aktion braucht Zeit — und die Schlange wartet nicht.
        </div>
      </div>

      <div class="btn-row">
        <button class="btn primary" id="menu-new">NEUE KARRIERE</button>
        ${hasSave() ? '<button class="btn" id="menu-continue">FORTSETZEN</button>' : ''}
        ${hasSave() ? '<button class="btn ghost" id="menu-clear">SPIELSTAND LÖSCHEN</button>' : ''}
      </div>
      <p style="margin-top:14px;font-size:10px;color:#5b626e;letter-spacing:2px">
        TON STARTET MIT DEM ERSTEN KLICK.
      </p>
    `;
    el.querySelector('#menu-new').addEventListener('click', onNew);
    el.querySelector('#menu-continue')?.addEventListener('click', onContinue);
    el.querySelector('#menu-clear')?.addEventListener('click', (e) => {
      clearSave();
      e.target.disabled = true;
      e.target.textContent = 'GELÖSCHT';
    });
    show(el);
  }

  function briefing(event, onStart) {
    const { state } = game;
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">NIGHT ${String(state.nightIndex + 1).padStart(2, '0')}</h1>
      <div class="subtitle">${escapeHtml(event.label)} · ${escapeHtml(clubTier(state).label)} · RUF ${Math.round(state.reputation)} (${repBand(state.reputation)})</div>
      <p style="font-size:13px;color:#aab2bf;max-width:680px">${escapeHtml(event.desc)}</p>

      <div class="stats-grid" style="margin-top:20px">
        <div class="stat-cell"><span class="k">GELD</span><span class="v">€${Math.round(state.money).toLocaleString('de-DE')}</span></div>
        <div class="stat-cell"><span class="k">KAPAZITÄT</span><span class="v">${capacity(state)}</span></div>
        <div class="stat-cell"><span class="k">RANG</span><span class="v" style="font-size:16px">${escapeHtml(rank(state).label)}</span></div>
        <div class="stat-cell"><span class="k">ACT</span><span class="v" style="font-size:16px">${state.bookedArtist ? escapeHtml(state.bookedArtist.name) : '—'}</span></div>
      </div>

      ${state.bookedArtist ? `<p style="margin-top:14px;font-size:12px;color:var(--amber)">
        ${escapeHtml(state.bookedArtist.name)} kommt im Lauf der Nacht zum Hintereingang.
        Auch der Act muss durch die Kontrolle.</p>` : ''}

      <h2 class="sec">SCHICHTPLAN</h2>
      <div class="keys-help">
        <div><b>P1 BOUNCER</b> Tür halten: <kbd>1</kbd> ID, <kbd>2</kbd> Talk, <kbd>3</kbd> Admit, <kbd>4</kbd> Reject</div>
        <div><b>P2 SECURITY</b> Kontrolle: <kbd>7</kbd> Scan, <kbd>8</kbd> Search, <kbd>9</kbd> Alko, <kbd>0</kbd> Calm</div>
        <div><b>ZIEL</b> Umsatz machen, ohne den Laden zu riskieren.</div>
      </div>

      <div class="btn-row">
        <button class="btn primary" id="briefing-start">SCHICHT BEGINNEN</button>
      </div>
    `;
    el.querySelector('#briefing-start').addEventListener('click', onStart);
    show(el);
  }

  function report(onContinue) {
    show(renderReport(game, onContinue));
  }

  function shop(onNext) {
    show(renderShop(game, onNext));
  }

  function pause(onResume, onQuit) {
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">PAUSE</h1>
      <div class="subtitle">DIE SCHLANGE WARTET</div>
      <div class="btn-row">
        <button class="btn primary" id="pause-resume">WEITER</button>
        <button class="btn ghost" id="pause-quit">SCHICHT ABBRECHEN</button>
      </div>`;
    el.querySelector('#pause-resume').addEventListener('click', onResume);
    el.querySelector('#pause-quit').addEventListener('click', onQuit);
    show(el);
  }

  return { show, hide, menu, briefing, report, shop, pause, root };
}
