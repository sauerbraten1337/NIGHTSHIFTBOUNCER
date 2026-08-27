/** Upgrade-Shop, Talente und Act-Booking zwischen den Nächten. */

import { escapeHtml } from './hud.js';
import { upgradeList, buyUpgrade } from '../systems/upgrades.js';
import { talentList, buyTalent } from '../systems/progression.js';
import { availableArtists, bookArtist, cancelBooking } from '../systems/artists.js';
import { clubTier, capacity, upgradeLevel, rank } from '../systems/state.js';
import { CLUB_TIERS } from '../data/config.js';

export function renderShop(game, onNext) {
  const wrap = document.createElement('div');
  const rerender = () => {
    wrap.innerHTML = shopHtml(game);
    bind(game, wrap, rerender, onNext);
  };
  rerender();
  return wrap;
}

function shopHtml(game) {
  const { state } = game;
  const tier = clubTier(state);
  const nextTier = CLUB_TIERS.find((t) => t.level === tier.level + 1);
  const list = upgradeList(state);
  const talents = talentList(state);
  const artists = availableArtists(state);

  return `
    <h1 class="title">CLUB AUSBAUEN</h1>
    <div class="subtitle">
      €${Math.round(state.money).toLocaleString('de-DE')} · RUF ${Math.round(state.reputation)} ·
      ${escapeHtml(rank(state).label)} · STUFE ${tier.level}: ${escapeHtml(tier.label)} ·
      KAPAZITÄT ${capacity(state)}
    </div>

    ${nextTier ? `<div class="tier-banner">NÄCHSTE SICHTBARE AUSBAUSTUFE: ${escapeHtml(nextTier.label)}</div>` : ''}

    <h2 class="sec">UPGRADES</h2>
    <div class="grid cols3">
      ${list.map(upgradeCard).join('')}
    </div>

    <h2 class="sec">TALENTE — ${state.talentPoints} PUNKT(E)</h2>
    <div class="grid cols4">
      ${talents.map(talentCard).join('')}
    </div>

    <h2 class="sec">ACT BUCHEN</h2>
    ${upgradeLevel(state, 'backstage') < 1
      ? '<p style="font-size:12px;color:var(--dim)">Ohne Backstage-Bereich lässt sich kein Act buchen.</p>'
      : artists.length === 0
        ? '<p style="font-size:12px;color:var(--dim)">Bei diesem Ruf will noch niemand hier spielen.</p>'
        : `<div class="grid cols4">${artists.map((a) => artistCard(a, state)).join('')}</div>`}
    ${state.bookedArtist
      ? `<p style="margin-top:10px;font-size:12px;color:var(--amber)">GEBUCHT: ${escapeHtml(state.bookedArtist.name)}
         (€${state.bookedArtist.fee}) <button class="btn ghost" data-cancel="1" style="margin-left:10px;padding:4px 10px">STORNIEREN</button></p>`
      : ''}

    <div class="btn-row">
      <button class="btn primary" id="shop-next">NÄCHSTE NACHT</button>
      <button class="btn ghost" id="shop-save">SPEICHERN</button>
    </div>
  `;
}

function upgradeCard(u) {
  const pips = Array.from({ length: u.max }, (_, i) =>
    `<span class="pip ${i < u.level ? 'on' : ''}"></span>`).join('');
  return `
    <div class="card ${u.maxed ? 'maxed' : ''}">
      <div class="head">
        <span class="nm">${escapeHtml(u.label)}</span>
        <span class="lv">${escapeHtml(u.group.toUpperCase())}</span>
      </div>
      <div class="pips">${pips}</div>
      <div class="ds">${escapeHtml(u.nextDesc)}</div>
      <div class="ft">
        <span class="price">${u.maxed ? 'MAX' : `€${u.cost.toLocaleString('de-DE')}`}</span>
        <button class="btn" data-buy="${u.id}" ${u.maxed || !u.affordable ? 'disabled' : ''}>KAUFEN</button>
      </div>
    </div>`;
}

function talentCard(t) {
  const pips = Array.from({ length: t.max }, (_, i) =>
    `<span class="pip ${i < t.level ? 'on' : ''}"></span>`).join('');
  return `
    <div class="card">
      <div class="head"><span class="nm">${escapeHtml(t.label)}</span></div>
      <div class="pips">${pips}</div>
      <div class="ds">${escapeHtml(t.desc)}</div>
      <div class="ft">
        <span class="price">1 PUNKT</span>
        <button class="btn" data-talent="${t.id}" ${t.canBuy ? '' : 'disabled'}>LERNEN</button>
      </div>
    </div>`;
}

function artistCard(a, state) {
  const booked = state.bookedArtist?.id === a.id;
  return `
    <div class="card ${booked ? 'selected' : ''}">
      <div class="head"><span class="nm">${escapeHtml(a.name)}</span><span class="lv">POP ${a.pop}</span></div>
      <div class="ds">${escapeHtml(a.genre)} · Umsatz ×${a.spend} · zieht VIPs ×${a.vipPull}</div>
      <div class="ft">
        <span class="price">€${a.fee.toLocaleString('de-DE')}</span>
        <button class="btn" data-artist="${a.id}" ${state.money < a.fee || booked ? 'disabled' : ''}>
          ${booked ? 'GEBUCHT' : 'BUCHEN'}
        </button>
      </div>
    </div>`;
}

function bind(game, wrap, rerender, onNext) {
  wrap.querySelectorAll('[data-buy]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const result = buyUpgrade(game.state, btn.dataset.buy);
      if (result.ok) {
        game.bus.emit('sfx', 'upgrade');
        game.bus.emit('upgradeBought', result);
        game.save();
      }
      rerender();
    });
  });
  wrap.querySelectorAll('[data-talent]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const res = buyTalent(game.state, btn.dataset.talent);
      if (res.ok) { game.bus.emit('sfx', 'ok'); game.save(); }
      rerender();
    });
  });
  wrap.querySelectorAll('[data-artist]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const res = bookArtist(game.state, btn.dataset.artist);
      if (res.ok) game.bus.emit('sfx', 'cash');
      rerender();
    });
  });
  wrap.querySelector('[data-cancel]')?.addEventListener('click', () => {
    cancelBooking(game.state);
    rerender();
  });
  wrap.querySelector('#shop-next')?.addEventListener('click', onNext);
  wrap.querySelector('#shop-save')?.addEventListener('click', (e) => {
    game.save();
    e.target.textContent = 'GESPEICHERT';
  });
}
