/** Screens: Menü, Modus-Auswahl, Online-Lobby, Briefing, Report, Shop, Pause. */

import { escapeHtml } from './hud.js';
import { renderReport } from './report.js';
import { renderShop } from './shop.js';
import { renderOffice } from './office.js';
import { renderCharacterEditor } from './character.js';
import { CLUB_NAME, MODES, rolesFor, DEFENSE_KEYS, ITEMS, ITEM_CATEGORIES, ZONES } from '../data/config.js';
import { drawItemIcon } from '../render/items.js';
import { clubTier, capacity, rank } from '../systems/state.js';
import { hasSave, clearSave, peekSave } from '../systems/save.js';
import {
  settings, setSetting, resetSettings, RESOLUTIONS, UI_SCALES,
  resolutionNote, toggleFullscreen, fullscreenActive
} from '../systems/settings.js';
import { cheats, unlockAdmin, lockAdmin, setCheat, ADMIN_MAX_NIGHT } from '../systems/admin.js';
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
    // "full": randlos ueber den ganzen Bildschirm - das Buero ist ein Raum,
    // kein Formular in einem Kasten.
    root.classList.toggle('full', !!opts.full);
    inner.classList.toggle('full', !!opts.full);
    // "wide": breiter Kasten fuer Nachtabschluss und Charaktereditor.
    inner.classList.toggle('wide', !!opts.wide);
    root.classList.remove('hidden');
    inner.scrollTop = 0;
  }

  function hide() { root.classList.add('hidden'); }

  /* ---------- Hauptmenü ---------- */

  /** Merkt sich, welcher Modus zuletzt gewaehlt wurde (fuer FORTSETZEN). */
  let lastMode = 'solo';

  /**
   * Der Titelbildschirm laesst die Szene auf dem Canvas frei: das Menue steht
   * als Spalte rechts - oben der Clubname mit Leuchtschrift, darunter die
   * Auswahl, ganz unten die Fusszeile mit den Systemtasten.
   */
  function menu({ onStart, onContinue }) {
    const el = document.createElement('div');
    el.className = 'menu';
    const save = peekSave();

    el.innerHTML = `
      <div class="menu-scan" aria-hidden="true"></div>
      <div class="menu-head">
        <div class="menu-kicker"><i></i>NULLWERK PRÄSENTIERT</div>
        <h1 class="menu-title" data-text="${escapeHtml(CLUB_NAME)}">${escapeHtml(CLUB_NAME)}</h1>
        <div class="menu-sub">NIGHTSHIFT — BOUNCER CO-OP</div>
        <div class="menu-tag">Tür auf, Tür zu. Du entscheidest, wer reinkommt.</div>
        ${save ? saveStrip(save) : ''}
      </div>
      <nav class="menu-nav" id="menu-nav"></nav>
      <div class="menu-panel hidden" id="menu-panel"></div>
      <div class="menu-foot">
        <span class="mf-keys"><kbd>↑</kbd><kbd>↓</kbd> WÄHLEN · <kbd>ENTER</kbd> LOS · <kbd>ESC</kbd> PAUSE · <kbd>M</kbd> TON</span>
        <button class="mf-fs" id="menu-fullscreen" type="button">
          ${fullscreenActive() ? 'VOLLBILD BEENDEN' : 'VOLLBILD'}</button>
      </div>
    `;

    const nav = el.querySelector('#menu-nav');
    const panel = el.querySelector('#menu-panel');

    const items = [
      { group: 'SCHICHT ANTRETEN' },
      { id: 'solo', label: MODES.solo.label, note: 'Allein an der Tür. Alles liegt bei dir.', kind: 'mode' },
      { id: 'local', label: MODES.local.label, note: 'Zwei an einer Tastatur, geteilter Bildschirm.', kind: 'mode' },
      { id: 'online', label: MODES.online.label, note: 'Raum erstellen oder mit Code beitreten.', kind: 'mode' },
      { group: 'CLUB' },
      { id: 'catalog', label: 'GEGENSTÄNDE', note: 'Alles, was Gäste dabeihaben können.', kind: 'screen' },
      { id: 'settings', label: 'EINSTELLUNGEN', note: 'Auflösung, Ton, Tutorial, Spielstand.', kind: 'screen' },
      { id: 'howto', label: 'ANLEITUNG', note: 'Wie eine Schicht abläuft.', kind: 'panel' },
      { id: 'credits', label: 'ÜBER DAS SPIEL', note: 'Was das hier ist.', kind: 'panel' }
    ];
    if (save) {
      items.splice(1, 0, {
        id: 'continue', label: 'KARRIERE FORTSETZEN',
        note: `Nacht ${String(save.nightIndex + 1).padStart(2, '0')} · €${Math.round(save.money).toLocaleString('de-DE')} · Ruf ${Math.round(save.reputation)}`,
        kind: 'continue'
      });
    }

    let index = 0;
    for (const item of items) {
      if (item.group) {
        const head = document.createElement('div');
        head.className = 'menu-group';
        head.textContent = item.group;
        nav.appendChild(head);
        continue;
      }
      index++;
      const play = item.kind === 'mode' || item.kind === 'continue';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `menu-item${play ? ' play' : ''}${item.kind === 'continue' ? ' resume' : ''}`;
      btn.dataset.id = item.id;
      btn.innerHTML = `
        <span class="mi-num">${String(index).padStart(2, '0')}</span>
        <span class="mi-text"><b>${escapeHtml(item.label)}</b><i>${escapeHtml(item.note)}</i></span>
        <span class="mi-mark">▸</span>`;
      btn.addEventListener('click', () => choose(item));
      nav.appendChild(btn);
    }

    el.querySelector('#menu-fullscreen').addEventListener('click', async (e) => {
      const on = await toggleFullscreen(document.documentElement);
      e.target.textContent = on ? 'VOLLBILD BEENDEN' : 'VOLLBILD';
    });

    // Pfeiltasten durch die Auswahl - ein Menü soll ohne Maus bedienbar sein.
    el.addEventListener('keydown', (e) => {
      if (!['ArrowDown', 'ArrowUp'].includes(e.key)) return;
      const buttons = [...nav.querySelectorAll('.menu-item')];
      if (!buttons.length) return;
      e.preventDefault();
      const at = buttons.indexOf(document.activeElement);
      const step = e.key === 'ArrowDown' ? 1 : -1;
      const next = (at + step + buttons.length) % buttons.length;
      buttons[at < 0 ? 0 : next].focus();
    });

    function choose(item) {
      if (item.kind === 'mode') {
        lastMode = item.id;
        onStart(item.id, settings().tutorial);
        return;
      }
      if (item.kind === 'continue') { onContinue(lastMode, settings().tutorial); return; }
      if (item.kind === 'screen') {
        const back = () => menu({ onStart, onContinue });
        if (item.id === 'catalog') catalog(back);
        else settingsScreen(back);
        return;
      }
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
    }

    function markOpen() {
      nav.querySelectorAll('.menu-item').forEach((b) => {
        b.classList.toggle('open', b.dataset.id === openPanel);
      });
    }

    function panelHtml(id) {
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

    show(el, { bare: true });
    nav.querySelector('.menu-item')?.focus({ preventScroll: true });
  }

  /** Kopfzeile über dem Menü: wo die gespeicherte Karriere steht. */
  function saveStrip(save) {
    const when = save.savedAt
      ? new Date(save.savedAt).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: '2-digit' })
      : '—';
    return `
      <div class="menu-save">
        <span class="ms-dot"></span>
        <b>${escapeHtml(save.name || 'DEIN TÜRSTEHER')}</b>
        <i>NACHT ${String(save.nightIndex + 1).padStart(2, '0')} · ZULETZT ${escapeHtml(when)}</i>
      </div>`;
  }

  /* ---------- Einstellungen ---------- */

  /**
   * Eigener Bildschirm statt Klappfach: Bild, Ton, Spiel und Daten stehen
   * untereinander, jede Änderung greift sofort und wird gespeichert.
   */
  function settingsScreen(onBack) {
    const el = document.createElement('div');
    el.className = 'settings';

    function draw() {
      const s = settings();
      const view = viewportSize();
      el.innerHTML = `
        <div class="set-head">
          <div>
            <div class="set-kicker">NULLWERK · SYSTEM</div>
            <h1 class="title">EINSTELLUNGEN</h1>
            <div class="subtitle">BILD · TON · SPIEL · DATEN</div>
          </div>
          <button class="btn ghost" id="settings-back">ZURÜCK</button>
        </div>

        <section class="set-block">
          <h2 class="set-h"><span>01</span> BILD</h2>

          <div class="set-row">
            <div class="set-label">
              <b>AUFLÖSUNG</b>
              <i>Wie fein das Bild gerechnet wird. Niedriger läuft flüssiger.</i>
            </div>
            <div class="set-control">
              <div class="seg" id="set-res">
                ${RESOLUTIONS.map((r) => `
                  <button type="button" class="seg-b ${s.resolution === r.id ? 'on' : ''}"
                          data-set="resolution" data-value="${r.id}"
                          title="${escapeHtml(r.note)}">${escapeHtml(r.label)}</button>`).join('')}
              </div>
              <div class="set-hint" id="set-res-note">
                AKTUELL: ${escapeHtml(resolutionNote(view.w, view.h))} ·
                ${escapeHtml(RESOLUTIONS.find((r) => r.id === s.resolution)?.note ?? '')}
              </div>
            </div>
          </div>

          <div class="set-row">
            <div class="set-label"><b>OBERFLÄCHE</b><i>Grösse von Schrift und Bedienelementen.</i></div>
            <div class="set-control">
              <div class="seg">
                ${UI_SCALES.map((u) => `
                  <button type="button" class="seg-b ${s.uiScale === u.id ? 'on' : ''}"
                          data-set="uiScale" data-value="${u.id}">${escapeHtml(u.label)}</button>`).join('')}
              </div>
            </div>
          </div>

          <div class="set-row">
            <div class="set-label"><b>BILDEFFEKTE</b><i>Nebel, Scanlines, Funken. Aus spart Leistung.</i></div>
            <div class="set-control">${switchHtml('effects', s.effects)}</div>
          </div>

          <div class="set-row">
            <div class="set-label"><b>VOLLBILD</b><i>Der Club füllt den ganzen Bildschirm.</i></div>
            <div class="set-control">
              <button class="btn" id="set-fs" type="button">
                ${fullscreenActive() ? 'VOLLBILD BEENDEN' : 'VOLLBILD EIN'}</button>
            </div>
          </div>
        </section>

        <section class="set-block">
          <h2 class="set-h"><span>02</span> TON</h2>
          <div class="set-row">
            <div class="set-label"><b>STUMM</b><i>Schaltet alles ab — wie die Taste <kbd>M</kbd>.</i></div>
            <div class="set-control">${switchHtml('muted', s.muted)}</div>
          </div>
          ${sliderRow('master', 'GESAMT', 'Lautstärke von allem.', s.master)}
          ${sliderRow('music', 'MUSIK', 'Der Sound aus dem Club.', s.music)}
          ${sliderRow('sfx', 'EFFEKTE', 'Türen, Piepser, Stempel.', s.sfx)}
        </section>

        <section class="set-block">
          <h2 class="set-h"><span>03</span> SPIEL</h2>
          <div class="set-row">
            <div class="set-label">
              <b>TUTORIAL SPIELEN</b>
              <i>Die Einarbeitung erklärt Ausweis, Abtasten und Entscheidung Schritt für Schritt.</i>
            </div>
            <div class="set-control">
              <label class="switch">
                <input type="checkbox" id="menu-tutorial" data-toggle="tutorial" ${s.tutorial ? 'checked' : ''} />
                <span class="sw-track"><i></i></span>
                <span class="sw-text">${s.tutorial ? 'AN' : 'AUS'}</span>
              </label>
            </div>
          </div>
        </section>

        <section class="set-block">
          <h2 class="set-h"><span>04</span> DATEN</h2>
          <div class="set-row">
            <div class="set-label"><b>SPIELSTAND</b><i>${hasSave()
              ? 'Gelöscht ist gelöscht — die Karriere beginnt danach von vorn.'
              : 'Kein Spielstand vorhanden.'}</i></div>
            <div class="set-control">
              <button class="btn ghost" id="settings-clear" ${hasSave() ? '' : 'disabled'}>
                SPIELSTAND LÖSCHEN</button>
            </div>
          </div>
          <div class="set-row">
            <div class="set-label"><b>ZURÜCKSETZEN</b><i>Alle Einstellungen wieder auf Werk.</i></div>
            <div class="set-control"><button class="btn ghost" id="settings-reset">STANDARD</button></div>
          </div>
        </section>

        <div class="btn-row">
          <button class="btn primary" id="settings-done">FERTIG</button>
        </div>`;
      wire();
    }

    function switchHtml(key, on) {
      return `
        <label class="switch">
          <input type="checkbox" data-toggle="${key}" ${on ? 'checked' : ''} />
          <span class="sw-track"><i></i></span>
          <span class="sw-text">${on ? 'AN' : 'AUS'}</span>
        </label>`;
    }

    function sliderRow(key, label, note, value) {
      return `
        <div class="set-row">
          <div class="set-label"><b>${escapeHtml(label)}</b><i>${escapeHtml(note)}</i></div>
          <div class="set-control slider">
            <input type="range" min="0" max="100" step="1" value="${Math.round(value * 100)}"
                   data-range="${key}" />
            <span class="set-val" data-val="${key}">${Math.round(value * 100)}%</span>
          </div>
        </div>`;
    }

    function wire() {
      for (const btn of el.querySelectorAll('[data-set]')) {
        btn.addEventListener('click', () => {
          setSetting(btn.dataset.set, btn.dataset.value);
          draw();
        });
      }
      for (const input of el.querySelectorAll('[data-toggle]')) {
        input.addEventListener('change', (e) => {
          setSetting(input.dataset.toggle, e.target.checked);
          draw();
        });
      }
      for (const range of el.querySelectorAll('[data-range]')) {
        const key = range.dataset.range;
        range.addEventListener('input', (e) => {
          const value = Number(e.target.value) / 100;
          setSetting(key, value);
          const out = el.querySelector(`[data-val="${key}"]`);
          if (out) out.textContent = `${Math.round(value * 100)}%`;
        });
      }
      el.querySelector('#set-fs')?.addEventListener('click', async (e) => {
        const on = await toggleFullscreen(document.documentElement);
        e.target.textContent = on ? 'VOLLBILD BEENDEN' : 'VOLLBILD EIN';
      });
      el.querySelector('#settings-clear')?.addEventListener('click', (e) => {
        clearSave();
        e.target.disabled = true;
        e.target.textContent = 'GELÖSCHT';
      });
      el.querySelector('#settings-reset')?.addEventListener('click', () => { resetSettings(); draw(); });
      el.querySelector('#settings-back')?.addEventListener('click', onBack);
      el.querySelector('#settings-done')?.addEventListener('click', onBack);
    }

    draw();
    show(el, { wide: true });
  }

  function viewportSize() {
    return {
      w: window.innerWidth || 1280,
      h: window.innerHeight || 720
    };
  }

  /* ---------- Gegenstands-Katalog ---------- */

  /**
   * Alles, was in der Nacht auf dem Kontrolltisch landen kann - mit dem
   * Icon, das im Spiel gezeichnet wird, und der Gruppe der Hausordnung.
   *
   * Bewusst nur hier im Titelbildschirm: waehrend der Schicht muss man
   * weiterhin selbst wissen, was ein Schlagring ist.
   */
  function catalog(onBack) {
    const groups = [
      { id: null, label: 'ZUGELASSEN', rule: 'Alltagsgegenstände. Nicht zu beanstanden.' },
      ...ITEM_CATEGORIES.map((c) => ({ id: c.id, label: c.label.toUpperCase(), rule: c.rule, severity: c.severity }))
    ];

    const el = document.createElement('div');
    el.innerHTML = `
      <h1 class="title">GEGENSTÄNDE</h1>
      <div class="subtitle">${ITEMS.length} SACHEN · ${ITEMS.filter((i) => i.forbidden).length} DAVON VERBOTEN</div>
      <p style="font-size:13px;color:#aab2bf;max-width:760px">
        Was Gäste dabeihaben können. In der Schicht steht in der Hausordnung nur die Gruppe —
        welcher Gegenstand dazugehört, entscheidest du dort selbst.</p>
      ${groups.map((g) => `
        <h2 class="sec">${escapeHtml(g.label)}${g.severity ? ` · STUFE ${'I'.repeat(g.severity)}` : ''}</h2>
        <p class="cat-rule">${escapeHtml(g.rule)}</p>
        <div class="cat-grid">
          ${ITEMS.filter((i) => (i.cat ?? null) === g.id).map((i) => `
            <div class="cat-item ${g.id ? 'bad' : 'ok'}">
              <canvas width="96" height="96" data-item="${escapeHtml(i.id)}"></canvas>
              <span class="cat-label">${escapeHtml(i.label)}</span>
              <span class="cat-zones">${i.zones.map(zoneLabel).join(' · ')}</span>
            </div>`).join('')}
        </div>`).join('')}
      <div class="btn-row"><button class="btn ghost" id="catalog-back">ZURÜCK</button></div>
    `;
    el.querySelector('#catalog-back').addEventListener('click', onBack);
    show(el);
    // Dieselben Icons wie auf dem Kontrolltisch - kein zweiter Zeichensatz.
    for (const canvas of el.querySelectorAll('.cat-item canvas')) {
      const ctx = canvas.getContext('2d');
      drawItemIcon(ctx, canvas.dataset.item, canvas.width);
    }
  }

  function zoneLabel(id) {
    return ZONES.find((z) => z.id === id)?.label ?? id.toUpperCase();
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
    el.className = 'brief';
    el.innerHTML = `
      <div class="brief-head">
        <div class="brief-kicker">NULLWERK · SCHICHTPLAN</div>
        <h1 class="title">${opts.tutorial ? 'EINARBEITUNG' : `NIGHT ${String(state.nightIndex + 1).padStart(2, '0')}`}</h1>
        <div class="brief-chips">
          <span class="bchip event">${escapeHtml(event.label)}</span>
          <span class="bchip">${escapeHtml(clubTier(state).label)}</span>
          <span class="bchip">RUF ${Math.round(state.reputation)} · ${escapeHtml(repBand(state.reputation))}</span>
          <span class="bchip mode">${escapeHtml(MODES[state.mode].label)}</span>
        </div>
        <p class="brief-desc">${escapeHtml(
          opts.tutorial ? 'Ruhige erste Schicht. Alles wird Schritt für Schritt erklärt.' : event.desc)}</p>
      </div>

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

      <div class="btn-row">
        <button class="btn primary" id="briefing-start">SCHICHT BEGINNEN</button>
        ${opts.onBack ? '<button class="btn ghost" id="briefing-back">ZURÜCK ZUM TITEL</button>' : ''}
      </div>
    `;
    el.querySelector('#briefing-start').addEventListener('click', onStart);
    el.querySelector('#briefing-back')?.addEventListener('click', opts.onBack);
    show(el);
  }

  function report(onContinue, onMenu = null) {
    show(renderReport(game, onContinue, onMenu), { wide: true });
  }
  /** Der Laptop: randlos, damit der Desktop den ganzen Bildschirm füllt. */
  function shop(onNext) { show(renderShop(game, onNext), { full: true }); }

  /** Das Büro am Tag: Schrank, Laptop, Tür. */
  function office(handlers) { show(renderOffice(game, handlers), { full: true }); }

  /** Charaktereditor - beim ersten Start und am Kleiderschrank. */
  function character(opts) { show(renderCharacterEditor(game, opts), { wide: true }); }

  /**
   * Pause. Hier - und nur hier - steht die komplette Tastenbelegung, damit
   * das laufende Spiel frei von Steuerungstexten bleibt.
   */
  function pause(onResume, onQuit, admin = null, onMenu = null) {
    const roles = rolesFor(game.state.mode);
    const el = document.createElement('div');
    el.className = 'pause';
    el.innerHTML = `
      <div class="pause-main">
        <h1 class="title">PAUSE</h1>
        <div class="subtitle">DIE SCHLANGE WARTET</div>
        <div class="btn-row pause-btns">
          <button class="btn primary" id="pause-resume">WEITER</button>
          <button class="btn" id="pause-quit">SCHICHT BEENDEN</button>
          ${onMenu ? '<button class="btn ghost danger" id="pause-menu">ZURÜCK ZUM HAUPTMENÜ</button>' : ''}
          <p class="menu-note" id="pause-warn">Beenden schliesst die Nacht ab und zeigt den Night Report.
            Zurück zum Hauptmenü verwirft die laufende Schicht.</p>
        </div>
        <div class="admin" id="pause-admin"></div>
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
    // Zurueck ins Hauptmenue heisst: die Nacht ist weg. Einmal nachfragen.
    const menuBtn = el.querySelector('#pause-menu');
    if (menuBtn) {
      let armed = false;
      menuBtn.addEventListener('click', () => {
        if (!armed) {
          armed = true;
          menuBtn.textContent = 'WIRKLICH? NOCHMAL KLICKEN';
          menuBtn.classList.add('armed');
          return;
        }
        onMenu();
      });
    }
    if (admin) adminBox(el.querySelector('#pause-admin'), admin);
    show(el);
  }

  /* ---------- Admin: Testhilfen hinter einem Code ---------- */

  /**
   * Erst der Code, dann die Werkzeuge. Alles hier greift sofort - die
   * Nachtwahl verwirft die laufende Schicht und geht ins Briefing.
   */
  function adminBox(box, admin) {
    render();

    function render() {
      box.innerHTML = cheats.unlocked ? unlockedHtml() : lockedHtml();
      wire();
    }

    function lockedHtml() {
      return `
        <div class="admin-head">ADMIN</div>
        <p class="admin-note">Testzugang: Nacht frei wählen und Cheats schalten.</p>
        <div class="admin-login">
          <input type="password" class="admin-input" id="admin-code"
                 placeholder="ADMIN-CODE" autocomplete="off" />
          <button class="btn ghost" id="admin-unlock">FREISCHALTEN</button>
        </div>
        <div class="admin-msg" id="admin-msg"></div>`;
    }

    function unlockedHtml() {
      const night = game.state.nightIndex;
      return `
        <div class="admin-head open">ADMIN — FREIGESCHALTET</div>

        <div class="admin-group">
          <label class="admin-label" for="admin-night">NACHT WÄHLEN</label>
          <div class="admin-login">
            <input type="number" class="admin-input" id="admin-night" min="1"
                   max="${ADMIN_MAX_NIGHT}" value="${Math.max(1, night)}" />
            <button class="btn" id="admin-go">STARTEN</button>
          </div>
          <p class="admin-note">Bricht die laufende Schicht ab und geht ins Briefing
            der gewählten Nacht. Aktuell: NACHT ${String(night).padStart(2, '0')}.</p>
        </div>

        <div class="admin-group">
          <div class="admin-label">CHEATS</div>
          ${toggleHtml('noAggro', 'KEINE ÜBERGRIFFE')}
          ${toggleHtml('fastActions', 'KONTROLLEN SOFORT FERTIG')}
          ${toggleHtml('reveal', 'RÖNTGENBLICK (WAHRHEIT ANZEIGEN)')}
        </div>

        <div class="admin-group admin-actions">
          <button class="btn ghost" data-admin="money">+5000 €</button>
          <button class="btn ghost" data-admin="rep">RUF AUF 100</button>
          <button class="btn ghost" data-admin="unlockAll">ALLES FREISCHALTEN</button>
          <button class="btn ghost" data-admin="shorten">NOCH 3 GÄSTE</button>
          <button class="btn ghost" data-admin="attack">ÜBERGRIFF AUSLÖSEN</button>
          <button class="btn ghost" data-admin="endShift">SCHICHT BEENDEN</button>
        </div>

        <div class="admin-msg" id="admin-msg"></div>
        <button class="btn ghost admin-lock" id="admin-lock">ADMIN SPERREN</button>`;
    }

    function toggleHtml(id, label) {
      return `
        <label class="menu-toggle admin-toggle">
          <input type="checkbox" data-cheat="${id}" ${cheats[id] ? 'checked' : ''} />
          <span>${escapeHtml(label)}</span>
        </label>`;
    }

    function say(text, kind = '') {
      const node = box.querySelector('#admin-msg');
      if (!node) return;
      node.textContent = text;
      node.className = `admin-msg ${kind}`;
    }

    function wire() {
      const code = box.querySelector('#admin-code');
      code?.addEventListener('keydown', (e) => {
        e.stopPropagation();
        if (e.key === 'Enter') tryUnlock();
      });
      box.querySelector('#admin-unlock')?.addEventListener('click', tryUnlock);

      box.querySelector('#admin-lock')?.addEventListener('click', () => { lockAdmin(); render(); });

      box.querySelector('#admin-night')?.addEventListener('keydown', (e) => {
        e.stopPropagation();
        if (e.key === 'Enter') go();
      });
      box.querySelector('#admin-go')?.addEventListener('click', go);

      for (const input of box.querySelectorAll('[data-cheat]')) {
        input.addEventListener('change', (e) => {
          setCheat(e.target.dataset.cheat, e.target.checked);
        });
      }

      for (const btn of box.querySelectorAll('[data-admin]')) {
        btn.addEventListener('click', () => {
          const result = admin[btn.dataset.admin]?.();
          const text = typeof result === 'string' ? result : 'Erledigt.';
          // Nichts zu tun ist kein Erfolg - das soll man am Ton sehen.
          say(text, /^(Keine|Niemand)/.test(text) ? 'bad' : 'ok');
        });
      }
    }

    function tryUnlock() {
      const value = box.querySelector('#admin-code')?.value ?? '';
      if (unlockAdmin(value)) render();
      else say('Falscher Code.', 'bad');
    }

    function go() {
      const value = Number(box.querySelector('#admin-night')?.value ?? 1);
      admin.night(value);
    }
  }

  function waiting(text) {
    const el = document.createElement('div');
    el.innerHTML = `<h1 class="title">WARTEN</h1><div class="subtitle">${escapeHtml(text)}</div>`;
    show(el);
  }

  return {
    show, hide, menu, lobby, briefing, report, shop, office, character,
    pause, waiting, catalog, settings: settingsScreen, root
  };
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
