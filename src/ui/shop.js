/**
 * Der Laptop im Büro: NIGHT//OS.
 *
 * Statt einer langen Liste ist der Einkauf ein kleines Betriebssystem auf
 * einem Laptop-Bildschirm - mit Wallpaper, Menüleiste, Dock und Fenstern.
 * Vier Programme: AUSBAU (Upgrades), TALENTE, BOOKING (Acts) und AKTE
 * (Status des Clubs). Die Upgrades sind nach Bereichen sortiert, lassen sich
 * filtern, durchsuchen und nach Empfehlung, Preis, Fortschritt oder Name
 * ordnen.
 *
 * Der Rest des Spiels erwartet weiterhin `#shop-next` (zurück ins Büro).
 */

import { escapeHtml } from './hud.js';
import { upgradeList, buyUpgrade } from '../systems/upgrades.js';
import { talentList, buyTalent, rankProgress } from '../systems/progression.js';
import { availableArtists, bookArtist, cancelBooking } from '../systems/artists.js';
import {
  clubTier, capacity, queueCapacity, upgradeLevel, rank, totalUpgradeTiers
} from '../systems/state.js';
import { CLUB_TIERS, FEATURES } from '../data/config.js';
import { drawDesktop, tierColor } from '../render/desktop.js';

/** Der Startbildschirm läuft nur einmal pro Sitzung - sonst nervt er. */
let bootShown = false;

/* ---------- Bereiche ---------- */

/**
 * Reihenfolge und Farbe der Upgrade-Bereiche. Die Gruppen stehen in
 * `data/config.js`; hier bekommen sie Rang, Farbe und Symbol.
 */
const GROUPS = [
  { id: 'Sicherheit', color: 'var(--red)', icon: 'shield',
    note: 'Kontrolle, Team und Technik an der Tür.' },
  { id: 'Eingang', color: 'var(--amber)', icon: 'door',
    note: 'Wie schnell und wie viele reinkommen.' },
  { id: 'Technik', color: 'var(--cyan)', icon: 'wave',
    note: 'Licht und Sound - der Grund, warum sie kommen.' },
  { id: 'Innenbereich', color: 'var(--purple)', icon: 'floor',
    note: 'Fläche, Bar, VIP und Backstage.' },
  { id: 'Komfort', color: 'var(--green)', icon: 'heart',
    note: 'Kleinkram, der den Ruf hebt.' }
];

const GROUP_INDEX = new Map(GROUPS.map((g, i) => [g.id, { ...g, order: i }]));

function groupMeta(id) {
  return GROUP_INDEX.get(id) ?? { id, color: 'var(--dim)', icon: 'box', note: '', order: 99 };
}

const SORTS = [
  { id: 'empfohlen', label: 'EMPFOHLEN' },
  { id: 'preis', label: 'PREIS' },
  { id: 'fortschritt', label: 'FORTSCHRITT' },
  { id: 'name', label: 'NAME' }
];

/* ---------- Aufbau ---------- */

export function renderShop(game, onNext) {
  const view = {
    app: 'upgrades',
    group: 'alle',
    sort: 'empfohlen',
    onlyAffordable: false,
    query: '',
    flash: null            // zuletzt gekauftes Upgrade: kurzer Aufblitzer
  };

  const wrap = document.createElement('div');
  wrap.className = 'lap';
  wrap.innerHTML = shellHtml(game);

  const shell = wrap.querySelector('.lap-shell');
  const win = wrap.querySelector('#os-window');
  const bar = wrap.querySelector('#os-bar');
  const dock = wrap.querySelector('#os-dock');
  const clock = wrap.querySelector('#os-clock');

  /** Nur das Fenster und die Anzeigen neu bauen - das Wallpaper läuft weiter. */
  function paint() {
    const app = appById(view.app);
    win.innerHTML = `
      <header class="win-bar">
        <span class="win-dots"><i></i><i></i><i></i></span>
        <span class="win-title">${icon(app.icon)}<b>${escapeHtml(app.title)}</b>
          <em>${escapeHtml(app.subtitle)}</em></span>
        <span class="win-path">~/nightos/${app.id}</span>
      </header>
      <div class="win-body" id="win-body">${app.body(game, view)}</div>`;
    bar.innerHTML = statusHtml(game);
    // Die Akzentfarbe folgt der Club-Stufe: nach einem Ausbau kann sie wechseln.
    shell.style.setProperty('--os-accent', tierColor(clubTier(game.state).level));
    dock.querySelectorAll('[data-app]').forEach((b) => {
      b.classList.toggle('on', b.dataset.app === view.app);
    });
    bindBody(game, wrap, view, paint);
  }

  bindShell(game, wrap, view, paint, onNext);
  paint();
  startWallpaper(game, wrap);
  startClock(clock);
  if (!bootShown) {
    bootShown = true;
    playBoot(wrap);
  }
  return wrap;
}

/* ---------- Gehäuse ---------- */

function shellHtml(game) {
  const tier = clubTier(game.state);
  const apps = appsFor();
  return `
    <div class="lap-shell" style="--os-accent:${tierColor(tier.level)}">
      <div class="lap-cam"><i></i></div>
      <div class="lap-screen">
        <canvas class="os-wall" id="os-wall" width="1280" height="800"></canvas>
        <div class="os-glass"></div>

        <div class="os-top">
          <div class="os-brand">${icon('logo')}<b>NIGHT//OS</b><span>v3.1</span></div>
          <div class="os-chips" id="os-bar"></div>
          <div class="os-clock" id="os-clock">--:--</div>
        </div>

        <div class="os-desk">
          <nav class="os-dock" id="os-dock">
            ${apps.map((a, i) => `
              <button class="dock-app" data-app="${a.id}" title="${escapeHtml(a.title)}">
                ${icon(a.icon)}
                <b>${escapeHtml(a.dock)}</b>
                <em>${i + 1}</em>
              </button>`).join('')}
            <div class="dock-gap"></div>
            <button class="dock-app quit" id="shop-save">${icon('save')}<b>SICHERN</b></button>
            <button class="dock-app quit" id="shop-next">${icon('power')}<b>BÜRO</b></button>
          </nav>

          <section class="os-window" id="os-window"></section>
        </div>

        <div class="os-taskbar">
          <span class="tb-left">${icon('disk')} NULLWERK · CLUBVERWALTUNG</span>
          <span class="tb-mid" id="os-toast"></span>
          <span class="tb-right"><kbd>1</kbd><kbd>2</kbd><kbd>3</kbd><kbd>4</kbd> Programme ·
            <kbd>ESC</kbd> zurück ins Büro</span>
        </div>

        <div class="os-boot" id="os-boot" hidden></div>
      </div>
      <div class="lap-hinge"><span></span></div>
      <div class="lap-base"></div>
    </div>`;
}

/** Die Werte oben rechts: Geld, Ruf, Stufe, Punkte. */
function statusHtml(game) {
  const { state } = game;
  const tier = clubTier(state);
  return `
    <span class="chip money">${icon('coin')}<b>€${Math.round(state.money).toLocaleString('de-DE')}</b></span>
    <span class="chip">${icon('star')}<b>${Math.round(state.reputation)}</b><em>RUF</em></span>
    <span class="chip">${icon('floor')}<b>ST. ${tier.level}</b><em>${escapeHtml(tier.label)}</em></span>
    <span class="chip ${state.talentPoints > 0 ? 'hot' : ''}">${icon('spark')}<b>${state.talentPoints}</b><em>TALENT</em></span>`;
}

/* ---------- Programme ---------- */

function appsFor() {
  const list = [
    { id: 'upgrades', dock: 'AUSBAU', icon: 'wrench', title: 'AUSBAU.EXE',
      subtitle: 'Was gebaut wird, sieht man an der Tür', body: upgradesBody },
    { id: 'talents', dock: 'TALENTE', icon: 'spark', title: 'TALENTE.EXE',
      subtitle: 'Was du selbst besser kannst', body: talentsBody }
  ];
  if (FEATURES.artists) {
    list.push({ id: 'acts', dock: 'BOOKING', icon: 'note', title: 'BOOKING.EXE',
      subtitle: 'Wer heute Nacht spielt', body: actsBody });
  }
  list.push({ id: 'akte', dock: 'AKTE', icon: 'folder', title: 'CLUBAKTE.DAT',
    subtitle: 'Der Stand der Dinge', body: akteBody });
  return list;
}

function appById(id) {
  const apps = appsFor();
  return apps.find((a) => a.id === id) ?? apps[0];
}

/* ---------- AUSBAU ---------- */

function upgradesBody(game, view) {
  const { state } = game;
  const all = upgradeList(state);
  const filtered = sortUpgrades(filterUpgrades(all, view), view.sort);

  const open = all.filter((u) => !u.maxed).length;
  const ready = all.filter((u) => !u.maxed && u.affordable).length;
  const done = all.reduce((sum, u) => sum + u.level, 0);
  const total = all.reduce((sum, u) => sum + u.max, 0);

  const tier = clubTier(state);
  const next = CLUB_TIERS.find((t) => t.level === tier.level + 1);
  const points = totalUpgradeTiers(state);

  // Bei "EMPFOHLEN" bleibt die Liste am Stück, sonst wird nach Bereichen
  // gebündelt - so sieht man auf einen Blick, wo noch etwas offen ist.
  const grouped = view.sort !== 'empfohlen' || view.group !== 'alle';
  const body = filtered.length === 0
    ? `<p class="os-empty">Nichts gefunden. Filter zurücksetzen?</p>`
    : grouped
      ? GROUPS.filter((g) => filtered.some((u) => u.group === g.id)).map((g) => `
          <div class="grp">
            <div class="grp-head" style="--c:${g.color}">
              ${icon(g.icon)}<b>${escapeHtml(g.id.toUpperCase())}</b>
              <i>${escapeHtml(g.note)}</i>
              <span>${filtered.filter((u) => u.group === g.id).length}</span>
            </div>
            <div class="up-grid">${filtered.filter((u) => u.group === g.id).map((u) => upgradeCard(u, view)).join('')}</div>
          </div>`).join('')
      : `<div class="up-grid">${filtered.map((u) => upgradeCard(u, view)).join('')}</div>`;

  return `
    <div class="os-toolbar">
      <div class="tabs">
        <button class="tab ${view.group === 'alle' ? 'on' : ''}" data-group="alle">
          ALLE <span>${all.filter((u) => !u.maxed).length}</span></button>
        ${GROUPS.map((g) => {
          const inGroup = all.filter((u) => u.group === g.id);
          if (inGroup.length === 0) return '';
          const openInGroup = inGroup.filter((u) => !u.maxed).length;
          return `<button class="tab ${view.group === g.id ? 'on' : ''}" data-group="${escapeHtml(g.id)}"
            style="--c:${g.color}">${icon(g.icon)} ${escapeHtml(g.id.toUpperCase())}
            <span>${openInGroup}</span></button>`;
        }).join('')}
      </div>
      <div class="tools">
        <label class="os-search">${icon('search')}
          <input id="up-search" type="text" placeholder="SUCHEN" value="${escapeHtml(view.query)}" />
        </label>
        <label class="os-toggle">
          <input type="checkbox" id="up-afford" ${view.onlyAffordable ? 'checked' : ''} />
          <span>NUR BEZAHLBAR</span>
        </label>
        <div class="os-sort">
          ${SORTS.map((s) => `<button class="sortb ${view.sort === s.id ? 'on' : ''}" data-sort="${s.id}">${s.label}</button>`).join('')}
        </div>
      </div>
    </div>

    <div class="os-meters">
      <div class="meterbox">
        <span class="k">AUSBAU GESAMT</span>
        <span class="v">${done} / ${total}</span>
        <div class="bar"><i style="width:${Math.round(done / total * 100)}%"></i></div>
      </div>
      <div class="meterbox">
        <span class="k">NÄCHSTE CLUB-STUFE</span>
        <span class="v">${next ? escapeHtml(next.label) : 'MAXIMUM ERREICHT'}</span>
        <div class="bar"><i class="amber" style="width:${next ? Math.round(Math.min(1, points / next.need) * 100) : 100}%"></i></div>
        <span class="n">${next ? `${points} / ${next.need} AUSBAUPUNKTE` : `${points} AUSBAUPUNKTE`}</span>
      </div>
      <div class="meterbox">
        <span class="k">SOFORT MÖGLICH</span>
        <span class="v ${ready > 0 ? 'good' : ''}">${ready} VON ${open}</span>
        <span class="n">Offene Ausbauten, die du dir gerade leisten kannst.</span>
      </div>
    </div>

    ${body}`;
}

function filterUpgrades(list, view) {
  const q = view.query.trim().toLowerCase();
  return list.filter((u) => {
    if (view.group !== 'alle' && u.group !== view.group) return false;
    if (view.onlyAffordable && (!u.affordable || u.maxed)) return false;
    if (!q) return true;
    return `${u.label} ${u.group} ${u.nextDesc}`.toLowerCase().includes(q);
  });
}

function sortUpgrades(list, sort) {
  const copy = [...list];
  const byGroup = (a, b) => groupMeta(a.group).order - groupMeta(b.group).order;

  if (sort === 'preis') {
    copy.sort((a, b) => Number(a.maxed) - Number(b.maxed) || (a.cost ?? 0) - (b.cost ?? 0));
  } else if (sort === 'fortschritt') {
    copy.sort((a, b) => (b.level / b.max) - (a.level / a.max) || byGroup(a, b));
  } else if (sort === 'name') {
    copy.sort((a, b) => a.label.localeCompare(b.label, 'de'));
  } else {
    // Empfohlen: was jetzt geht zuerst, darin das Günstigste; MAX ans Ende.
    copy.sort((a, b) =>
      Number(a.maxed) - Number(b.maxed)
      || Number(b.affordable) - Number(a.affordable)
      || (a.cost ?? 0) - (b.cost ?? 0)
      || byGroup(a, b));
  }
  return copy;
}

function upgradeCard(u, view) {
  const g = groupMeta(u.group);
  const state = u.maxed ? 'maxed' : u.affordable ? 'ready' : 'locked';
  const badge = u.maxed ? 'AUSGEBAUT' : u.affordable ? 'BEREIT' : 'ZU TEUER';
  const segs = Array.from({ length: u.max }, (_, i) =>
    `<i class="${i < u.level ? 'on' : ''}"></i>`).join('');

  return `
    <article class="up ${state} ${view.flash === u.id ? 'flash' : ''}" style="--c:${g.color}">
      <div class="up-top">
        <span class="up-ico">${icon(g.icon)}</span>
        <div class="up-name">
          <b>${escapeHtml(u.label)}</b>
          <em title="Ausbaupunkte pro Stufe - sie bringen die nächste Club-Stufe">${escapeHtml(u.group.toUpperCase())} ·
            ${u.tierWeight > 0 ? `+${u.tierWeight} PKT` : 'OHNE PKT'}</em>
        </div>
        <span class="up-badge">${badge}</span>
      </div>

      <div class="up-level">
        <span class="lv">STUFE ${u.level}/${u.max}</span>
        <span class="segs">${segs}</span>
      </div>

      ${u.currentDesc ? `<p class="up-now">${icon('check')} ${escapeHtml(u.currentDesc)}</p>` : ''}
      <p class="up-next">${u.maxed ? 'Mehr geht hier nicht.' : escapeHtml(u.nextDesc)}</p>

      <div class="up-foot">
        <span class="up-price">${u.maxed ? 'MAX' : `€${u.cost.toLocaleString('de-DE')}`}</span>
        <button class="btn buy" data-buy="${u.id}" ${u.maxed || !u.affordable ? 'disabled' : ''}>
          ${u.maxed ? 'FERTIG' : 'KAUFEN'}
        </button>
      </div>
    </article>`;
}

/* ---------- TALENTE ---------- */

function talentsBody(game) {
  const { state } = game;
  const talents = talentList(state);
  const prog = rankProgress(state);
  const spent = talents.reduce((s, t) => s + t.level, 0);

  return `
    <div class="os-meters">
      <div class="meterbox">
        <span class="k">FREIE PUNKTE</span>
        <span class="v ${state.talentPoints > 0 ? 'good' : ''}">${state.talentPoints}</span>
        <span class="n">Punkte gibt es beim Aufstieg im Rang.</span>
      </div>
      <div class="meterbox">
        <span class="k">RANG</span>
        <span class="v">${escapeHtml(prog.current.label)}</span>
        <div class="bar"><i class="cyan" style="width:${Math.round(prog.ratio * 100)}%"></i></div>
        <span class="n">${prog.next ? `NÄCHSTER: ${escapeHtml(prog.next.label)} (${prog.next.xp} XP)` : 'HÖCHSTER RANG'}</span>
      </div>
      <div class="meterbox">
        <span class="k">GELERNT</span>
        <span class="v">${spent} STUFEN</span>
        <span class="n">Talente bleiben über alle Nächte erhalten.</span>
      </div>
    </div>

    <div class="up-grid talents">
      ${talents.map(talentCard).join('')}
    </div>`;
}

function talentCard(t) {
  const segs = Array.from({ length: t.max }, (_, i) =>
    `<i class="${i < t.level ? 'on' : ''}"></i>`).join('');
  const maxed = t.level >= t.max;
  return `
    <article class="up ${maxed ? 'maxed' : t.canBuy ? 'ready' : 'locked'}" style="--c:var(--cyan)">
      <div class="up-top">
        <span class="up-ico">${icon('spark')}</span>
        <div class="up-name"><b>${escapeHtml(t.label)}</b><em>PERSÖNLICH</em></div>
        <span class="up-badge">${maxed ? 'MEISTER' : t.canBuy ? 'LERNBAR' : 'KEIN PUNKT'}</span>
      </div>
      <div class="up-level">
        <span class="lv">STUFE ${t.level}/${t.max}</span>
        <span class="segs">${segs}</span>
      </div>
      <p class="up-next">${escapeHtml(t.desc)}</p>
      <div class="up-foot">
        <span class="up-price">${maxed ? 'MAX' : '1 PUNKT'}</span>
        <button class="btn buy" data-talent="${t.id}" ${t.canBuy ? '' : 'disabled'}>LERNEN</button>
      </div>
    </article>`;
}

/* ---------- BOOKING ---------- */

function actsBody(game) {
  const { state } = game;
  const artists = availableArtists(state);
  const hasBackstage = upgradeLevel(state, 'backstage') >= 1;

  if (!hasBackstage) {
    return `<p class="os-empty">Ohne Backstage-Bereich lässt sich kein Act buchen.
      Bau ihn im Programm AUSBAU unter INNENBEREICH.</p>`;
  }

  return `
    ${state.bookedArtist ? `
      <div class="os-booked">
        ${icon('note')}
        <div><b>${escapeHtml(state.bookedArtist.name)}</b>
          <em>gebucht für €${state.bookedArtist.fee.toLocaleString('de-DE')} — kommt im Lauf der Nacht.</em></div>
        <button class="btn ghost" data-cancel="1">STORNIEREN</button>
      </div>` : ''}

    ${artists.length === 0
      ? '<p class="os-empty">Bei diesem Ruf will noch niemand hier spielen.</p>'
      : `<div class="up-grid">${artists.map((a) => artistCard(a, state)).join('')}</div>`}`;
}

function artistCard(a, state) {
  const booked = state.bookedArtist?.id === a.id;
  const affordable = state.money >= a.fee;
  return `
    <article class="up ${booked ? 'ready' : affordable ? '' : 'locked'}" style="--c:var(--purple)">
      <div class="up-top">
        <span class="up-ico">${icon('note')}</span>
        <div class="up-name"><b>${escapeHtml(a.name)}</b><em>${escapeHtml(a.genre)}</em></div>
        <span class="up-badge">POP ${a.pop}</span>
      </div>
      <p class="up-next">Umsatz ×${a.spend} · zieht VIPs ×${a.vipPull}</p>
      <div class="up-foot">
        <span class="up-price">€${a.fee.toLocaleString('de-DE')}</span>
        <button class="btn buy" data-artist="${a.id}" ${!affordable || booked ? 'disabled' : ''}>
          ${booked ? 'GEBUCHT' : 'BUCHEN'}
        </button>
      </div>
    </article>`;
}

/* ---------- CLUBAKTE ---------- */

function akteBody(game) {
  const { state } = game;
  const tier = clubTier(state);
  const points = totalUpgradeTiers(state);
  const list = upgradeList(state);
  const life = state.lifetime ?? { guests: 0, admitted: 0, rejected: 0, revenue: 0, incidents: 0, nights: 0 };
  const log = (state.log ?? []).slice(0, 10);

  return `
    <div class="akte">
      <div class="akte-main">
        <h3 class="akte-h">AUSBAUSTUFEN</h3>
        <ol class="tierline">
          ${CLUB_TIERS.map((t) => `
            <li class="${t.level < tier.level ? 'done' : t.level === tier.level ? 'now' : ''}">
              <span class="dot"></span>
              <b>STUFE ${t.level} · ${escapeHtml(t.label)}</b>
              <em>${t.need} Ausbaupunkte</em>
            </li>`).join('')}
        </ol>

        <h3 class="akte-h">BILANZ ÜBER ALLE NÄCHTE</h3>
        <div class="os-meters">
          <div class="meterbox"><span class="k">NÄCHTE</span><span class="v">${life.nights}</span></div>
          <div class="meterbox"><span class="k">GEPRÜFT</span><span class="v">${life.guests}</span>
            <span class="n">${life.admitted} eingelassen · ${life.rejected} abgewiesen</span></div>
          <div class="meterbox"><span class="k">UMSATZ</span><span class="v">€${Math.round(life.revenue).toLocaleString('de-DE')}</span>
            <span class="n">${life.incidents} Zwischenfälle</span></div>
        </div>

        <h3 class="akte-h">PROTOKOLL</h3>
        ${log.length === 0
          ? '<p class="os-empty">Noch nichts passiert.</p>'
          : `<ul class="oslog">${log.map((entry) => `
              <li class="${escapeHtml(entry.kind ?? 'info')}">${escapeHtml(entry.text)}</li>`).join('')}</ul>`}
      </div>

      <div class="akte-side">
        <h3 class="akte-h">KENNZAHLEN</h3>
        <div class="kvrow"><span>NACHT</span><b>${String(state.nightIndex + 1).padStart(2, '0')}</b></div>
        <div class="kvrow"><span>POSTEN</span><b>${escapeHtml(rank(state).label)}</b></div>
        <div class="kvrow"><span>KAPAZITÄT</span><b>${capacity(state)}</b></div>
        <div class="kvrow"><span>SCHLANGE</span><b>${queueCapacity(state)}</b></div>
        <div class="kvrow"><span>AUSBAUPUNKTE</span><b>${points}</b></div>
        <div class="kvrow"><span>ERFAHRUNG</span><b>${Math.round(state.xp)} XP</b></div>

        <h3 class="akte-h">BEREICHE</h3>
        ${GROUPS.map((g) => {
          const inGroup = list.filter((u) => u.group === g.id);
          if (inGroup.length === 0) return '';
          const lv = inGroup.reduce((s, u) => s + u.level, 0);
          const mx = inGroup.reduce((s, u) => s + u.max, 0);
          return `
            <div class="grpbar" style="--c:${g.color}">
              <span>${escapeHtml(g.id)}</span>
              <div class="bar"><i style="width:${Math.round(lv / mx * 100)}%;background:${g.color}"></i></div>
              <b>${lv}/${mx}</b>
            </div>`;
        }).join('')}
      </div>
    </div>`;
}

/* ---------- Bedienung ---------- */

function bindShell(game, wrap, view, paint, onNext) {
  wrap.querySelectorAll('[data-app]').forEach((btn) => {
    btn.addEventListener('click', () => {
      view.app = btn.dataset.app;
      view.flash = null;
      game.bus?.emit('sfx', 'ok');
      paint();
    });
  });

  wrap.querySelector('#shop-next')?.addEventListener('click', onNext);
  wrap.querySelector('#shop-save')?.addEventListener('click', () => {
    game.save();
    toast(wrap, 'SPIELSTAND GESICHERT');
  });

  // Tastatur: 1-4 wechselt das Programm, ESC geht zurück ins Büro.
  const onKey = (e) => {
    if (!wrap.isConnected) { window.removeEventListener('keydown', onKey); return; }
    if (e.target instanceof HTMLInputElement) {
      if (e.code === 'Escape') e.target.blur();
      return;
    }
    if (e.code === 'Escape') { onNext?.(); return; }
    const n = Number(e.key);
    const apps = appsFor();
    if (n >= 1 && n <= apps.length) {
      view.app = apps[n - 1].id;
      paint();
    }
  };
  window.addEventListener('keydown', onKey);
}

function bindBody(game, wrap, view, paint) {
  const body = wrap.querySelector('#win-body');
  if (!body) return;

  body.querySelectorAll('[data-group]').forEach((btn) => {
    btn.addEventListener('click', () => { view.group = btn.dataset.group; paint(); });
  });
  body.querySelectorAll('[data-sort]').forEach((btn) => {
    btn.addEventListener('click', () => { view.sort = btn.dataset.sort; paint(); });
  });

  const search = body.querySelector('#up-search');
  search?.addEventListener('input', () => {
    view.query = search.value;
    paint();
    // Nach dem Neuaufbau weitertippen können.
    const again = wrap.querySelector('#up-search');
    again?.focus();
    again?.setSelectionRange(again.value.length, again.value.length);
  });

  body.querySelector('#up-afford')?.addEventListener('change', (e) => {
    view.onlyAffordable = e.target.checked;
    paint();
  });

  body.querySelectorAll('[data-buy]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const result = buyUpgrade(game.state, btn.dataset.buy);
      if (result.ok) {
        game.bus.emit('sfx', 'upgrade');
        game.bus.emit('upgradeBought', result);
        game.save();
        view.flash = result.id;
        // Der Aufblitzer gehört zum Kauf, nicht zur Karte: nach kurzer Zeit
        // vergessen, damit er beim nächsten Filterwechsel nicht erneut läuft.
        setTimeout(() => { view.flash = null; }, 800);
        toast(wrap, result.tierChanged
          ? `CLUB-STUFE ${result.tier} ERREICHT`
          : `GEKAUFT: ${result.desc}`);
      } else {
        toast(wrap, result.reason.toUpperCase());
      }
      paint();
    });
  });

  body.querySelectorAll('[data-talent]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const res = buyTalent(game.state, btn.dataset.talent);
      if (res.ok) {
        game.bus.emit('sfx', 'ok');
        game.save();
        toast(wrap, `GELERNT: ${res.label.toUpperCase()} ${res.level}`);
      }
      paint();
    });
  });

  body.querySelectorAll('[data-artist]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const res = bookArtist(game.state, btn.dataset.artist);
      if (res.ok) game.bus.emit('sfx', 'cash');
      paint();
    });
  });

  body.querySelector('[data-cancel]')?.addEventListener('click', () => {
    cancelBooking(game.state);
    paint();
  });
}

/* ---------- Leben auf dem Bildschirm ---------- */

function startWallpaper(game, wrap) {
  const canvas = wrap.querySelector('#os-wall');
  const ctx = canvas.getContext('2d');
  let t = 0;
  let last = performance.now();

  function frame(now) {
    if (!canvas.isConnected) return;
    t += Math.min(0.05, (now - last) / 1000);
    last = now;
    drawDesktop(ctx, canvas.width, canvas.height, t, clubTier(game.state).level);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function startClock(el) {
  // Beim ersten Aufruf haengt der Laptop noch nicht im Dokument - erst ab
  // dem zweiten Schlag darf `isConnected` die Uhr stoppen.
  let started = false;
  const tick = () => {
    if (started && !el.isConnected) return;
    started = true;
    const now = new Date();
    el.textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    setTimeout(tick, 10000);
  };
  tick();
}

const BOOT_LINES = [
  'NIGHT//OS 3.1 — NULLWERK SYSTEMS',
  'speicher geprüft ......... ok',
  'türsteher-profil geladen . ok',
  'clubakte entschlüsselt ... ok',
  'verbindung zur bank ...... ok',
  'willkommen zurück.'
];

/** Kurzer Startbildschirm - schnell genug, dass niemand wartet. */
function playBoot(wrap) {
  const boot = wrap.querySelector('#os-boot');
  if (!boot) return;
  boot.hidden = false;
  boot.innerHTML = `<div class="boot-lines"></div><div class="boot-bar"><i></i></div>`;
  const lines = boot.querySelector('.boot-lines');

  BOOT_LINES.forEach((line, i) => {
    setTimeout(() => {
      if (!boot.isConnected) return;
      const row = document.createElement('div');
      row.textContent = line;
      lines.appendChild(row);
    }, i * 130);
  });

  setTimeout(() => {
    if (!boot.isConnected) return;
    boot.classList.add('gone');
    setTimeout(() => boot.remove(), 400);
  }, 1000);
}

/** Kurze Meldung in der Statusleiste unten. */
let toastTimer = null;
function toast(wrap, text) {
  const el = wrap.querySelector('#os-toast');
  if (!el) return;
  el.textContent = text;
  el.classList.add('on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('on'), 2600);
}

/* ---------- Symbole ---------- */

const ICONS = {
  logo: '<circle cx="12" cy="12" r="8"/><path d="M7 12h10"/>',
  wrench: '<path d="M14.5 4.5a4 4 0 0 0-5 5L4 15v5h5l5.5-5.5a4 4 0 0 0 5-5l-3 3-2-2z"/>',
  spark: '<path d="M12 3l2.2 5.8L20 11l-5.8 2.2L12 19l-2.2-5.8L4 11l5.8-2.2z"/>',
  note: '<circle cx="8" cy="17" r="3"/><path d="M11 17V5l8-2v11"/><circle cx="16" cy="14" r="3"/>',
  folder: '<path d="M3 6h6l2 3h10v10H3z"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
  door: '<path d="M6 3h9v18H6z"/><circle cx="12.5" cy="12" r="1"/><path d="M15 21h4V3h-4"/>',
  wave: '<path d="M3 12h3l2-6 3 14 3-11 2 5h5"/>',
  floor: '<path d="M3 8h18v12H3z"/><path d="M3 14h18M9 8v12M15 8v12"/>',
  heart: '<path d="M12 20s-7-4.3-7-9a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 4.7-7 9-7 9z"/>',
  box: '<path d="M4 7l8-4 8 4v10l-8 4-8-4z"/>',
  coin: '<circle cx="12" cy="12" r="8"/><path d="M9 10h6M9 14h6M12 7v10"/>',
  star: '<path d="M12 3l2.6 6.2 6.4.5-4.9 4.1 1.5 6.2L12 16.8 6.4 20l1.5-6.2L3 9.7l6.4-.5z"/>',
  check: '<path d="M4 12l5 5L20 6"/>',
  search: '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
  save: '<path d="M4 4h12l4 4v12H4z"/><path d="M8 4v6h8V4M8 20v-6h8v6"/>',
  power: '<path d="M12 3v9"/><path d="M6.5 6.5a8 8 0 1 0 11 0"/>',
  disk: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/>'
};

function icon(name) {
  const path = ICONS[name] ?? ICONS.box;
  return `<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;
}
