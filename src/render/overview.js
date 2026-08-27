/**
 * Club-Übersicht: kleine Top-Down-Karte in der Ecke.
 * Zeigt, wie sich der Club durch Upgrades sichtbar verändert, wie voll er ist
 * und wie lang die Schlange draussen steht.
 */

import { PAL, withAlpha } from './palette.js';
import { roundRect } from './sprites.js';
import { upgradeLevel, capacity, clubTier, isSolo } from '../systems/state.js';

export function drawOverview(ctx, game, rect, beat = 0, pulse = 0) {
  const { state } = game;
  const night = state.night;
  const { x, y, w, h } = rect;

  ctx.save();
  ctx.beginPath();
  roundRect(ctx, x, y, w, h, 3);
  ctx.clip();
  ctx.fillStyle = 'rgba(6,8,12,0.9)';
  ctx.fillRect(x, y, w, h);
  ctx.translate(x, y);

  const pad = 8;
  const clubH = h * 0.52;
  const clubW = w - pad * 2;
  const cx = pad;
  const cy = pad + 12;

  // Clubkörper
  ctx.fillStyle = '#232a35';
  ctx.fillRect(cx, cy, clubW, clubH);
  ctx.strokeStyle = withAlpha('#000', 0.6);
  ctx.strokeRect(cx + 0.5, cy + 0.5, clubW - 1, clubH - 1);

  // Tanzfläche (wächst mit dem Upgrade)
  const floorLv = upgradeLevel(state, 'floor');
  const dfW = clubW * (0.38 + floorLv * 0.07);
  const dfX = cx + clubW * 0.3;
  const dfg = ctx.createLinearGradient(0, cy, 0, cy + clubH);
  dfg.addColorStop(0, withAlpha(PAL.red, 0.28 + pulse * 0.2));
  dfg.addColorStop(1, 'rgba(0,0,0,0.1)');
  ctx.fillStyle = dfg;
  ctx.fillRect(dfX, cy + 6, dfW, clubH - 12);

  // Menschen auf dem Floor
  const inside = night ? night.inside.length : 0;
  const dots = Math.min(46, Math.ceil(inside / 2));
  ctx.fillStyle = withAlpha('#dbe3ef', 0.75);
  for (let i = 0; i < dots; i++) {
    const px = dfX + 4 + ((i * 97) % Math.max(1, dfW - 8));
    const py = cy + 10 + ((i * 53) % Math.max(1, clubH - 20));
    ctx.fillRect(px, py + Math.sin(beat * 6.28 + i) * 1.2, 2, 2);
  }

  // Bar / VIP / Floor 2 / Backstage
  if (upgradeLevel(state, 'bar') >= 1) box(ctx, cx + 4, cy + 4, clubW * 0.24, clubH * 0.3, PAL.amber, 'BAR');
  if (upgradeLevel(state, 'vip') >= 1) box(ctx, cx + 4, cy + clubH * 0.4, clubW * 0.24, clubH * 0.32, PAL.purple, 'VIP');
  if (floorLv >= 2) box(ctx, cx + clubW - clubW * 0.22 - 4, cy + 4, clubW * 0.22, clubH * 0.5, PAL.cyan, 'FLOOR2');
  if (upgradeLevel(state, 'backstage') >= 1) {
    box(ctx, cx + clubW - clubW * 0.22 - 4, cy + clubH * 0.58, clubW * 0.22, clubH * 0.36, PAL.grey, 'BACK');
  }

  // Schleuse (nur im Koop)
  const airY = cy + clubH + 6;
  const airH = h * 0.13;
  if (!isSolo(state)) {
    ctx.fillStyle = '#1a1f29';
    ctx.fillRect(cx + clubW * 0.34, airY, clubW * 0.32, airH);
    ctx.strokeStyle = withAlpha(PAL.cyan, 0.5);
    ctx.strokeRect(cx + clubW * 0.34 + 0.5, airY + 0.5, clubW * 0.32 - 1, airH - 1);
    label(ctx, cx + clubW * 0.5, airY + airH * 0.62, 'SCHLEUSE', PAL.cyan);
    const wait = night ? night.airlockQueue.length + (night.stations.airlock.guest ? 1 : 0) : 0;
    ctx.fillStyle = PAL.cyan;
    for (let i = 0; i < Math.min(6, wait); i++) {
      ctx.fillRect(cx + clubW * 0.36 + i * 6, airY + 4, 3, 3);
    }
  }

  // Tür + Schlange draussen
  const doorY = airY + airH + 6;
  ctx.fillStyle = PAL.red;
  ctx.fillRect(cx + clubW * 0.46, doorY, clubW * 0.08, 3);
  const queue = night ? night.queue.length : 0;
  ctx.fillStyle = withAlpha(PAL.white, 0.8);
  for (let i = 0; i < Math.min(22, queue); i++) {
    ctx.fillRect(cx + clubW * 0.5 + ((i % 11) - 5) * 7, doorY + 9 + Math.floor(i / 11) * 6, 3, 3);
  }

  // Kopfzeile
  ctx.font = '9px "IBM Plex Mono", monospace';
  ctx.letterSpacing = '2px';
  ctx.fillStyle = withAlpha(PAL.grey, 0.9);
  ctx.textAlign = 'left';
  ctx.fillText(`CLUB · ST. ${clubTier(state).level}`, pad, 12);
  ctx.textAlign = 'right';
  ctx.fillStyle = withAlpha(PAL.white, 0.8);
  ctx.fillText(`${inside}/${capacity(state)}`, w - pad, 12);

  ctx.restore();

  ctx.strokeStyle = withAlpha(PAL.line, 0.8);
  ctx.lineWidth = 1;
  roundRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 3);
  ctx.stroke();
}

function box(ctx, x, y, w, h, color, text) {
  ctx.fillStyle = withAlpha(color, 0.16);
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = withAlpha(color, 0.5);
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
  label(ctx, x + w / 2, y + h / 2 + 3, text, color);
}

function label(ctx, x, y, text, color) {
  ctx.save();
  ctx.font = '7px "IBM Plex Mono", monospace';
  ctx.fillStyle = withAlpha(color, 0.9);
  ctx.textAlign = 'center';
  ctx.letterSpacing = '1px';
  ctx.fillText(text, x, y);
  ctx.restore();
}
