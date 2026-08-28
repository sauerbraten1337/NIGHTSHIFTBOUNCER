/** Screens: Menü, Modus-Auswahl, Online-Lobby, Briefing, Report, Shop, Pause. */

import { escapeHtml } from './hud.js';
import { renderReport } from './report.js';
import { renderShop } from './shop.js';
import { CLUB_NAME, MODES, rolesFor } from '../data/config.js';
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

  function hide() { root.classList.add('hidden'); }

  /* ---------- Hauptmenü ---------- */

  function menu({ onStart, onContinue }) {
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">${CLUB_NAME}</h1>
      <div class="subtitle">NIGHTSHIFT — BOUNCER CO-OP</div>
      <p style="font-size:13px;line-height:1.6;color:#aab2bf;max-width:760px">
        Du stehst an der Tür eines Underground-Clubs und siehst, was ein Türsteher sieht:
        die Strasse, die Schlange und den Gast direkt vor dir. Er reicht dir seinen Ausweis —
        du prüfst ihn selbst. Foto, Alter, Ablaufdatum, Hologramm. Danach entscheidest du.
      </p>

      <h2 class="sec">WIE WILLST DU SPIELEN?</h2>
      <div class="grid cols2" id="mode-grid">
        ${modeCard('solo', 'Du machst Tür und Kontrolle allein. Es gibt keinen Security-Bereich — alles passiert an der Tür.',
      'WASD · 1 Ausweis · 2 Ansprechen · 3 Scan · 4 Abtasten · 5 Alkotest · 6 Schlange · E Einlassen · X Abweisen')}
        ${modeCard('local', 'Zwei Spieler an einer Tastatur, Splitscreen: links die Tür draussen, rechts die Schleuse innen.',
      'P1: 1 / 2 / 3 · E · X    ·    P2: 7 / 8 / 9 · J K L · ENTER · BACKSPACE')}
        ${modeCard('online', 'Raum erstellen oder mit Code beitreten. Jeder spielt an seinem Rechner seinen eigenen Bereich.',
      'Host = Bouncer draussen · Gast = Security in der Schleuse')}
      </div>

      <h2 class="sec">DIE BEIDEN BEREICHE</h2>
      <div class="keys-help">
        <div><b>DRAUSSEN — BOUNCER</b><br>
          Warteschlange, Ausweiskontrolle von Hand, Gespräch.
          Wer okay aussieht, wird in die Schleuse durchgelassen.</div>
        <div><b>INNEN — SICHERHEITSSCHLEUSE</b><br>
          Getrennt vom Club: Scanner, Abtasten, Alkoholtest.
          Erst die Security öffnet die Tür zum Floor.</div>
        <div><b>ZWEITE VERTEIDIGUNGSLINIE</b><br>
          Was der Bouncer übersieht, kann die Security noch fangen —
          das gibt dem Team einen Bonus statt einer Strafe.</div>
      </div>

      <div class="btn-row">
        <button class="btn primary" id="menu-start">SCHICHT BEGINNEN</button>
        ${hasSave() ? '<button class="btn" id="menu-continue">KARRIERE FORTSETZEN</button>' : ''}
        ${hasSave() ? '<button class="btn ghost" id="menu-clear">SPIELSTAND LÖSCHEN</button>' : ''}
        <label style="font-size:11px;color:var(--dim);display:flex;align-items:center;gap:6px;margin-left:8px">
          <input type="checkbox" id="menu-tutorial" checked /> TUTORIAL SPIELEN
        </label>
      </div>
      <p style="margin-top:12px;font-size:10px;color:#5b626e;letter-spacing:2px">TON STARTET MIT DEM ERSTEN KLICK.</p>
    `;

    let selected = 'solo';
    const cards = el.querySelectorAll('.mode-card');
    const select = (mode) => {
      selected = mode;
      cards.forEach((c) => c.classList.toggle('selected', c.dataset.mode === mode));
    };
    cards.forEach((card) => card.addEventListener('click', () => select(card.dataset.mode)));
    select('solo');

    el.querySelector('#menu-start').addEventListener('click', () => {
      onStart(selected, el.querySelector('#menu-tutorial').checked);
    });
    el.querySelector('#menu-continue')?.addEventListener('click', () => {
      onContinue(selected, el.querySelector('#menu-tutorial').checked);
    });
    el.querySelector('#menu-clear')?.addEventListener('click', (e) => {
      clearSave();
      e.target.disabled = true;
      e.target.textContent = 'GELÖSCHT';
    });
    show(el);
  }

  function modeCard(id, desc, keys) {
    const mode = MODES[id];
    return `
      <div class="mode-card" data-mode="${id}">
        <h3>${escapeHtml(mode.label)}</h3>
        <p>${escapeHtml(desc)}</p>
        <div class="keys">${escapeHtml(keys)}</div>
      </div>`;
  }

  /* ---------- Online-Lobby ---------- */

  function lobby({ onHost, onJoin, onCancel, onStart }) {
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">ONLINE-KOOP</h1>
      <div class="subtitle">EIN RAUM, ZWEI BEREICHE</div>
      <div class="grid cols2">
        <div class="card">
          <div class="head"><span class="nm">RAUM ERSTELLEN</span><span class="lv">HOST · BOUNCER</span></div>
          <div class="ds">Du übernimmst die Tür draussen und simulierst die Nacht.
            Dein Partner bekommt den Code und übernimmt die Schleuse.</div>
          <button class="btn primary" id="lobby-host">RAUM ERSTELLEN</button>
        </div>
        <div class="card">
          <div class="head"><span class="nm">RAUM BEITRETEN</span><span class="lv">GAST · SECURITY</span></div>
          <div class="ds">Code eingeben und die Sicherheitsschleuse übernehmen.</div>
          <input class="codeinput" id="lobby-code" maxlength="5" placeholder="CODE" />
          <button class="btn" id="lobby-join">BEITRETEN</button>
        </div>
      </div>
      <div id="lobby-room"></div>
      <div class="lobby-status" id="lobby-status">Nicht verbunden.</div>
      <div class="btn-row">
        <button class="btn primary hidden" id="lobby-start">SCHICHT BEGINNEN</button>
        <button class="btn ghost" id="lobby-cancel">ZURÜCK</button>
      </div>
    `;

    el.querySelector('#lobby-host').addEventListener('click', onHost);
    el.querySelector('#lobby-join').addEventListener('click', () => {
      onJoin(el.querySelector('#lobby-code').value);
    });
    el.querySelector('#lobby-code').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') onJoin(e.target.value);
      e.stopPropagation();
    });
    el.querySelector('#lobby-cancel').addEventListener('click', onCancel);
    el.querySelector('#lobby-start').addEventListener('click', onStart);
    show(el);

    return {
      setRoom(code, role) {
        el.querySelector('#lobby-room').innerHTML =
          `<div class="roomcode">${escapeHtml(code)}</div>
           <p style="text-align:center;font-size:11px;color:var(--dim);letter-spacing:2px">
             ${role === 'host' ? 'CODE AN DEN PARTNER GEBEN' : 'VERBUNDEN'}</p>`;
      },
      setStatus(text, kind = '') {
        const node = el.querySelector('#lobby-status');
        node.textContent = text;
        node.className = `lobby-status ${kind}`;
      },
      showStart(visible) {
        el.querySelector('#lobby-start').classList.toggle('hidden', !visible);
      }
    };
  }

  /* ---------- Briefing ---------- */

  function briefing(event, onStart, opts = {}) {
    const { state } = game;
    const roles = rolesFor(state.mode);
    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">${opts.tutorial ? 'EINARBEITUNG' : `NIGHT ${String(state.nightIndex + 1).padStart(2, '0')}`}</h1>
      <div class="subtitle">${escapeHtml(event.label)} · ${escapeHtml(clubTier(state).label)} ·
        RUF ${Math.round(state.reputation)} (${repBand(state.reputation)}) · ${escapeHtml(MODES[state.mode].label)}</div>
      <p style="font-size:13px;color:#aab2bf;max-width:700px">${escapeHtml(
        opts.tutorial ? 'Ruhige erste Schicht. Alles wird Schritt für Schritt erklärt.' : event.desc)}</p>

      <div class="stats-grid" style="margin-top:20px">
        <div class="stat-cell"><span class="k">GELD</span><span class="v">€${Math.round(state.money).toLocaleString('de-DE')}</span></div>
        <div class="stat-cell"><span class="k">KAPAZITÄT</span><span class="v">${capacity(state)}</span></div>
        <div class="stat-cell"><span class="k">RANG</span><span class="v" style="font-size:15px">${escapeHtml(rank(state).label)}</span></div>
        <div class="stat-cell"><span class="k">ACT</span><span class="v" style="font-size:15px">${state.bookedArtist ? escapeHtml(state.bookedArtist.name) : '—'}</span></div>
      </div>

      ${state.bookedArtist ? `<p style="margin-top:14px;font-size:12px;color:var(--amber)">
        ${escapeHtml(state.bookedArtist.name)} kommt im Lauf der Nacht. Auch der Act muss durch die Kontrolle.</p>` : ''}

      <h2 class="sec">EURE POSTEN</h2>
      <div class="keys-help">
        ${roles.map((role) => `
          <div><b>${escapeHtml(role.label)} — ${role.area === 'airlock' ? 'SCHLEUSE (INNEN)' : 'TÜR (DRAUSSEN)'}</b><br>
            ${role.actions.map((a) => `<kbd>${keyName(a.key)}</kbd> ${escapeHtml(a.label)}`).join(' · ')}
            ${role.area === 'airlock' ? '<br><kbd>J</kbd><kbd>K</kbd><kbd>L</kbd> Abtast-Zonen' : ''}
          </div>`).join('')}
        <div><b>AUSWEIS PRÜFEN</b><br>
          Der Ausweis erscheint links unten. Felder anklicken, die nicht stimmen:
          Foto, Name, Geburtsdatum, Gültigkeit, Hologramm.</div>
      </div>

      <div class="btn-row"><button class="btn primary" id="briefing-start">SCHICHT BEGINNEN</button></div>
    `;
    el.querySelector('#briefing-start').addEventListener('click', onStart);
    show(el);
  }

  function report(onContinue) { show(renderReport(game, onContinue)); }
  function shop(onNext) { show(renderShop(game, onNext)); }

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

  function waiting(text) {
    const el = document.createElement('div');
    el.innerHTML = `<h1 class="title">WARTEN</h1><div class="subtitle">${escapeHtml(text)}</div>`;
    show(el);
  }

  return { show, hide, menu, lobby, briefing, report, shop, pause, waiting, root };
}

function keyName(code) {
  if (code.startsWith('Digit')) return code.slice(5);
  if (code.startsWith('Key')) return code.slice(3);
  return { Enter: 'ENTER', Backspace: 'BACK' }[code] ?? code;
}
