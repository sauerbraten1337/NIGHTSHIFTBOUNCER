/** Screens: Menü, Modus-Auswahl, Online-Lobby, Briefing, Report, Shop, Pause. */

import { escapeHtml } from './hud.js';
import { renderReport } from './report.js';
import { renderShop } from './shop.js';
import { CLUB_NAME, MODES, rolesFor, DEFENSE_KEYS } from '../data/config.js';
import { clubTier, capacity, rank } from '../systems/state.js';
import { hasSave, clearSave } from '../systems/save.js';
import { repBand } from '../systems/reputation.js';
import { difficultyBriefing } from '../systems/difficulty.js';

export function createScreens(game) {
  const root = document.getElementById('screen');
  const inner = document.getElementById('screen-inner');

  function show(node, opts = {}) {
    inner.innerHTML = '';
    inner.appendChild(node);
    // "bare": kein Kasten, keine Abdunklung - der Titelbildschirm zeigt die Szene.
    root.classList.toggle('bare', !!opts.bare);
    inner.classList.toggle('bare', !!opts.bare);
    root.classList.remove('hidden');
    inner.scrollTop = 0;
  }

  function hide() { root.classList.add('hidden'); }

  /* ---------- Hauptmenü ---------- */

  /**
   * Der Titelbildschirm laesst die Szene auf dem Canvas frei: das Menue steht
   * als schmale Spalte rechts, oben der Clubname, darunter die Auswahl.
   */
  function menu({ onStart, onContinue }) {
    const el = document.createElement('div');
    el.className = 'menu';
    el.innerHTML = `
      <div class="menu-head">
        <div class="menu-kicker">NULLWERK PRÄSENTIERT</div>
        <h1 class="menu-title">${escapeHtml(CLUB_NAME)}</h1>
        <div class="menu-sub">NIGHTSHIFT — BOUNCER CO-OP</div>
        <div class="menu-tag">Tür auf, Tür zu. Du entscheidest, wer reinkommt.</div>
      </div>
      <nav class="menu-nav" id="menu-nav"></nav>
      <div class="menu-panel hidden" id="menu-panel"></div>
      <div class="menu-foot">TON STARTET MIT DEM ERSTEN KLICK · ESC PAUSE · M TON</div>
    `;

    const nav = el.querySelector('#menu-nav');
    const panel = el.querySelector('#menu-panel');
    let tutorial = true;

    const items = [
      { id: 'solo', label: MODES.solo.label, note: 'Allein an der Tür. Alles liegt bei dir.', kind: 'mode' },
      { id: 'local', label: MODES.local.label, note: 'Zwei an einer Tastatur, geteilter Bildschirm.', kind: 'mode' },
      { id: 'online', label: MODES.online.label, note: 'Raum erstellen oder mit Code beitreten.', kind: 'mode' },
      { id: 'settings', label: 'EINSTELLUNGEN', note: 'Tutorial, Spielstand.', kind: 'panel' },
      { id: 'howto', label: 'ANLEITUNG', note: 'Wie eine Schicht abläuft.', kind: 'panel' },
      { id: 'credits', label: 'ÜBER DAS SPIEL', note: 'Was das hier ist.', kind: 'panel' }
    ];
    if (hasSave()) {
      items.splice(3, 0, {
        id: 'continue', label: 'KARRIERE FORTSETZEN',
        note: 'Weiter mit dem gespeicherten Club.', kind: 'continue'
      });
    }

    for (const item of items) {
      const btn = document.createElement('button');
      btn.className = `menu-item${item.kind === 'mode' || item.kind === 'continue' ? ' play' : ''}`;
      btn.dataset.id = item.id;
      btn.innerHTML = `
        <span class="mi-mark">▸</span>
        <span class="mi-text"><b>${escapeHtml(item.label)}</b><i>${escapeHtml(item.note)}</i></span>`;
      btn.addEventListener('click', () => choose(item));
      nav.appendChild(btn);
    }

    /** Merkt sich, welcher Modus zuletzt gewaehlt wurde (fuer FORTSETZEN). */
    let lastMode = 'solo';

    function choose(item) {
      if (item.kind === 'mode') {
        lastMode = item.id;
        onStart(item.id, tutorial);
        return;
      }
      if (item.kind === 'continue') { onContinue(lastMode, tutorial); return; }
      togglePanel(item.id);
    }

    let openPanel = null;
    function togglePanel(id) {
      if (openPanel === id) {
        openPanel = null;
        panel.classList.add('hidden');
        markOpen();
        return;
      }
      openPanel = id;
      panel.classList.remove('hidden');
      panel.innerHTML = panelHtml(id);
      markOpen();
      if (id === 'settings') wireSettings();
    }

    function markOpen() {
      nav.querySelectorAll('.menu-item').forEach((b) => {
        b.classList.toggle('open', b.dataset.id === openPanel);
      });
    }

    function panelHtml(id) {
      if (id === 'settings') {
        return `
          <label class="menu-toggle">
            <input type="checkbox" id="menu-tutorial" ${tutorial ? 'checked' : ''} />
            <span>TUTORIAL SPIELEN</span>
          </label>
          <p class="menu-note">Die Einarbeitung erklärt Ausweis, Abtasten und Entscheidung Schritt für Schritt.</p>
          ${hasSave()
            ? '<button class="btn ghost" id="menu-clear">SPIELSTAND LÖSCHEN</button>'
            : '<p class="menu-note">Kein Spielstand vorhanden.</p>'}`;
      }
      if (id === 'howto') {
        return `
          <ol class="menu-steps">
            <li><b>AUSWEIS</b> verlangen und selbst prüfen: Foto, Name, Geburtsdatum, Gültigkeit, Hologramm.</li>
            <li><b>ANSPRECHEN</b> — was sagt der Gast, passt es zum Ausweis?</li>
            <li><b>ABTASTEN</b> — Jacke, Hosentaschen, Tasche. Ringe anklicken oder <kbd>J</kbd><kbd>K</kbd><kbd>L</kbd>.</li>
            <li><b>ALKOTEST</b> bei Verdacht. Den Grenzwert liest du selbst ab.</li>
            <li><b>ENTSCHEIDEN</b> — einlassen oder abweisen. Niemand sagt dir, ob es richtig war.</li>
          </ol>`;
      }
      return `
        <p class="menu-note">Ein Club, eine Tür, eine Nacht. Im Koop steht einer draussen an der Tür
        und einer drinnen in der Sicherheitsschleuse — was der eine übersieht, kann der andere
        noch fangen.</p>
        <p class="menu-note">Alles hier ist von Hand gezeichneter Code: keine Bilder, keine Assets.</p>`;
    }

    function wireSettings() {
      panel.querySelector('#menu-tutorial')?.addEventListener('change', (e) => {
        tutorial = e.target.checked;
      });
      panel.querySelector('#menu-clear')?.addEventListener('click', (e) => {
        clearSave();
        e.target.disabled = true;
        e.target.textContent = 'GELÖSCHT';
      });
    }

    show(el, { bare: true });
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

      ${difficultyBlock(state.nightIndex + 1)}

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

  /**
   * Pause. Hier - und nur hier - steht die komplette Tastenbelegung, damit
   * das laufende Spiel frei von Steuerungstexten bleibt.
   */
  function pause(onResume, onQuit) {
    const roles = rolesFor(game.state.mode);
    const el = document.createElement('div');
    el.className = 'pause';
    el.innerHTML = `
      <div class="pause-main">
        <h1 class="title">PAUSE</h1>
        <div class="subtitle">DIE SCHLANGE WARTET</div>
        <div class="btn-row" style="flex-direction:column;align-items:stretch;max-width:280px">
          <button class="btn primary" id="pause-resume">WEITER</button>
          <button class="btn ghost" id="pause-quit">SCHICHT ABBRECHEN</button>
        </div>
      </div>
      <aside class="pause-controls">
        <h2 class="sec" style="margin-top:0">STEUERUNG</h2>
        ${roles.map((role) => `
          <div class="ctl-group">
            <div class="ctl-head">${escapeHtml(role.label)} — ${role.area === 'airlock' ? 'SCHLEUSE' : 'TÜR'}</div>
            ${role.actions.map((a) => `
              <div class="ctl-row"><kbd>${escapeHtml(keyName(a.key))}</kbd>
                <span>${escapeHtml(a.label)}</span></div>`).join('')}
          </div>`).join('')}
        <div class="ctl-group">
          <div class="ctl-head">ABTASTEN</div>
          <div class="ctl-row"><kbd>J</kbd><span>Jacke</span></div>
          <div class="ctl-row"><kbd>K</kbd><span>Hosentaschen</span></div>
          <div class="ctl-row"><kbd>L</kbd><span>Tasche</span></div>
          <div class="ctl-row"><kbd>Maus</kbd><span>Ring am Gast anklicken</span></div>
          <div class="ctl-row"><kbd>1</kbd><kbd>…</kbd><span>Gegenstand beanstanden</span></div>
          <div class="ctl-row"><kbd>0</kbd><span>Zone freigeben</span></div>
        </div>
        <div class="ctl-group">
          <div class="ctl-head">ABWEHR</div>
          <div class="ctl-row">
            <kbd>${DEFENSE_KEYS.map((k) => escapeHtml(k.label)).join('</kbd><kbd>')}</kbd>
            <span>Geht jemand auf dich los, erscheinen diese Tasten der Reihe nach — schnell drücken</span>
          </div>
          <div class="ctl-row"><kbd>Maus</kbd><span>Taste im Bild anklicken</span></div>
        </div>
        <div class="ctl-group">
          <div class="ctl-head">SYSTEM</div>
          <div class="ctl-row"><kbd>ESC</kbd><span>Pause</span></div>
          <div class="ctl-row"><kbd>M</kbd><span>Ton an/aus</span></div>
        </div>
        <p class="ctl-note">Alle Kontrollen lassen sich auch anklicken:
          die Icons unten, der Ausweis, der Block und die Ringe am Gast.</p>
      </aside>`;
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

/** Was ab heute zusätzlich auffällig sein kann. */
function difficultyBlock(nightNumber) {
  const { active, fresh } = difficultyBriefing(nightNumber);
  return `
    ${fresh ? `<div class="tier-banner">NEU AB HEUTE — ${escapeHtml(fresh.label)}: ${escapeHtml(fresh.desc)}</div>` : ''}
    <h2 class="sec">WORAUF DU ACHTEST</h2>
    <ul class="watchlist">
      ${active.map((step) => `<li class="${fresh && step.id === fresh.id ? 'fresh' : ''}">
        <b>${escapeHtml(step.label)}</b> ${escapeHtml(step.desc)}</li>`).join('')}
    </ul>`;
}

function keyName(code) {
  if (code.startsWith('Digit')) return code.slice(5);
  if (code.startsWith('Key')) return code.slice(3);
  return { Enter: 'ENTER', Backspace: 'BACK' }[code] ?? code;
}
