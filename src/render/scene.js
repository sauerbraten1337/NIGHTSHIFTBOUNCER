/**
 * Die Spielansicht aus Sicht des Personals.
 *
 *   BOUNCER  - steht an der Tür und sieht die Strasse, den Gast und die Schlange
 *   SECURITY - steht in der Schleuse und sieht den Gast, Scanner und Clubtür
 *
 * Beides sind 2D-Szenen (Frontansicht mit Tiefenstaffelung), kein 3D.
 */

import { PAL, withAlpha } from './palette.js';
import { roundRect, drawSpeech } from './sprites.js';
import { drawFigure, shade } from './figure.js';
import { glow, beam } from './effects.js';
import { upgradeLevel } from '../systems/state.js';

/**
 * @param {object} opts { rect:{x,y,w,h}, area:'outside'|'airlock', station,
 *                        queue:[], t, beat, pulse, dark, label }
 */
export function drawStationView(ctx, game, opts) {
  const { rect, area } = opts;
  ctx.save();
  ctx.beginPath();
  ctx.rect(rect.x, rect.y, rect.w, rect.h);
  ctx.clip();
  ctx.translate(rect.x, rect.y);

  if (area === 'outside') drawOutside(ctx, game, opts);
  else drawAirlock(ctx, game, opts);

  drawGuestAtStation(ctx, game, opts);
  drawViewFrame(ctx, game, opts);
  ctx.restore();
}

/* ---------------------------------------------------------------- */
/* DRAUSSEN: Eingang, Strasse, Schlange                              */
/* ---------------------------------------------------------------- */

function drawOutside(ctx, game, opts) {
  const { rect, t, pulse, dark = 0 } = opts;
  const w = rect.w;
  const h = rect.h;
  const horizon = h * 0.5;
  const light = 1 - dark;

  // Himmel / Nachtluft
  const sky = ctx.createLinearGradient(0, 0, 0, horizon);
  sky.addColorStop(0, '#080a10');
  sky.addColorStop(1, '#141a26');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, horizon);

  // Stadtsilhouette
  ctx.fillStyle = '#0d1119';
  let bx = -20;
  let i = 0;
  while (bx < w + 40) {
    const bw = 46 + ((i * 37) % 60);
    const bh = 40 + ((i * 53) % 90);
    ctx.fillRect(bx, horizon - bh, bw, bh);
    // Fenster
    ctx.fillStyle = withAlpha('#ffd9a0', 0.12 * light);
    for (let wy = horizon - bh + 8; wy < horizon - 8; wy += 14) {
      for (let wx = bx + 6; wx < bx + bw - 8; wx += 12) {
        if ((wx * wy + i) % 7 < 2) ctx.fillRect(wx, wy, 4, 6);
      }
    }
    ctx.fillStyle = '#0d1119';
    bx += bw + 10;
    i++;
  }

  // Boden (Asphalt) mit Fluchtlinien
  const ground = ctx.createLinearGradient(0, horizon, 0, h);
  ground.addColorStop(0, '#171c25');
  ground.addColorStop(1, '#0d1015');
  ctx.fillStyle = ground;
  ctx.fillRect(0, horizon, w, h - horizon);

  ctx.strokeStyle = withAlpha(PAL.line, 0.35 * light);
  ctx.lineWidth = 1;
  for (let k = -6; k <= 6; k++) {
    ctx.beginPath();
    ctx.moveTo(w / 2 + k * 22, horizon);
    ctx.lineTo(w / 2 + k * 190, h);
    ctx.stroke();
  }
  for (let d = 1; d <= 6; d++) {
    const y = horizon + Math.pow(d / 6, 2.1) * (h - horizon);
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  // Clubwand links und rechts (wir stehen im Eingang)
  drawSideWall(ctx, 0, w * 0.19, h, horizon, light, 1);
  drawSideWall(ctx, w - w * 0.19, w * 0.19, h, horizon, light, -1);

  // Türlicht von hinten über die Schulter des Spielers
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const spill = ctx.createRadialGradient(w / 2, h * 1.05, 10, w / 2, h * 1.05, h * 0.9);
  spill.addColorStop(0, withAlpha(PAL.red, (0.2 + pulse * 0.08) * light));
  spill.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = spill;
  ctx.fillRect(0, 0, w, h);
  ctx.restore();

  // Leuchtreklame auf der anderen Strassenseite (der Club liegt hinter uns)
  const flicker = Math.sin(t * 9) > 0.6 ? 0.45 : 1;
  ctx.save();
  ctx.font = `${Math.round(h * 0.028)}px "Archivo Black", "Arial Black", sans-serif`;
  ctx.textAlign = 'center';
  ctx.letterSpacing = '4px';
  ctx.shadowColor = PAL.cyan;
  ctx.shadowBlur = 18 * flicker * light;
  ctx.fillStyle = withAlpha('#bff0ff', 0.5 * flicker * light);
  ctx.fillText('SPÄTI 24H', w * 0.19, horizon - 54);
  ctx.restore();

  // Absperrgitter
  drawBarrier(ctx, w, horizon, h, light);

  // Warteschlange in der Tiefe
  drawQueueDepth(ctx, game, opts, horizon);

  // Strassenlaterne
  glow(ctx, w * 0.12, horizon - 30, 150, PAL.amber, 0.12 * light);
  glow(ctx, w * 0.88, horizon - 40, 120, PAL.cyan, 0.06 * light);

  drawCounter(ctx, w, h, light, 'TÜRPULT', PAL.red);
}

/** Das Pult, an dem der Spieler steht - unterer Bildrand. */
function drawCounter(ctx, w, h, light, label, accent) {
  const top = h * 0.9;
  const g = ctx.createLinearGradient(0, top, 0, h);
  g.addColorStop(0, '#1a1f28');
  g.addColorStop(1, '#0a0d12');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.moveTo(-20, h);
  ctx.lineTo(w * 0.06, top);
  ctx.lineTo(w * 0.94, top);
  ctx.lineTo(w + 20, h);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = withAlpha(accent, 0.4 * light);
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(w * 0.06, top + 0.5);
  ctx.lineTo(w * 0.94, top + 0.5);
  ctx.stroke();

  // Klemmbrett mit Gästeliste
  ctx.fillStyle = '#252b36';
  roundRect(ctx, w * 0.1, top + 14, w * 0.14, h * 0.075, 3);
  ctx.fill();
  ctx.fillStyle = withAlpha('#c9d2df', 0.5 * light);
  for (let i = 0; i < 4; i++) {
    ctx.fillRect(w * 0.11, top + 24 + i * 10, w * 0.115 - (i % 2) * 12, 2);
  }

  ctx.save();
  ctx.font = '9px "IBM Plex Mono", monospace';
  ctx.letterSpacing = '3px';
  ctx.fillStyle = withAlpha(PAL.grey, 0.55 * light);
  ctx.textAlign = 'right';
  ctx.fillText(label, w * 0.93, top + 22);
  ctx.restore();
}

function drawSideWall(ctx, x, ww, h, horizon, light, dir) {
  const g = ctx.createLinearGradient(x, 0, x + ww * dir, 0);
  g.addColorStop(0, '#232935');
  g.addColorStop(1, '#141922');
  ctx.fillStyle = g;
  ctx.beginPath();
  if (dir === 1) {
    ctx.moveTo(0, 0);
    ctx.lineTo(ww, horizon * 0.55);
    ctx.lineTo(ww, h - horizon * 0.2);
    ctx.lineTo(0, h);
  } else {
    ctx.moveTo(x + ww, 0);
    ctx.lineTo(x, horizon * 0.55);
    ctx.lineTo(x, h - horizon * 0.2);
    ctx.lineTo(x + ww, h);
  }
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = withAlpha('#000', 0.5);
  ctx.stroke();
}

function drawBarrier(ctx, w, horizon, h, light) {
  const y = horizon + (h - horizon) * 0.42;
  ctx.strokeStyle = withAlpha('#6d7684', 0.5 * light);
  ctx.lineWidth = 3;
  for (const side of [-1, 1]) {
    const x = w / 2 + side * w * 0.34;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x, y - 46);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(x, y - 50, 4, 0, Math.PI * 2);
    ctx.fillStyle = '#8a929e';
    ctx.fill();
  }
  // Kordel
  ctx.strokeStyle = withAlpha(PAL.red, 0.55 * light);
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(w / 2 - w * 0.34, y - 46);
  ctx.quadraticCurveTo(w / 2, y - 26, w / 2 + w * 0.34, y - 46);
  ctx.stroke();
}

/** Die Schlange verschwindet perspektivisch nach hinten. */
function drawQueueDepth(ctx, game, opts, horizon) {
  const { rect, t } = opts;
  const queue = opts.queue ?? [];
  const h = rect.h;
  const w = rect.w;
  const shown = Math.min(queue.length, 9);

  for (let i = shown - 1; i >= 0; i--) {
    const guest = queue[i];
    const depth = (i + 1) / 10;
    const scale = 1 - Math.pow(depth, 0.55) * 0.72;
    const y = horizon + (h - horizon) * (0.5 - depth * 0.42);
    const offset = ((i % 2) * 2 - 1) * (26 + i * 5) * (1 - depth * 0.5);
    drawFigure(ctx, {
      x: w / 2 + offset,
      y,
      h: h * 0.42 * scale,
      look: guest.look,
      personality: guest.personality,
      t: t + guest.swayPhase,
      drunk: guest.truth.drunk,
      vip: guest.truth.vip,
      dim: 0.25 + depth * 0.45
    });
  }

  if (queue.length > shown) {
    ctx.save();
    ctx.font = '11px "IBM Plex Mono", monospace';
    ctx.fillStyle = withAlpha(PAL.grey, 0.7);
    ctx.textAlign = 'center';
    ctx.fillText(`+${queue.length - shown} WEITERE`, w / 2, horizon - 6);
    ctx.restore();
  }
}

/* ---------------------------------------------------------------- */
/* INNEN: Sicherheitsschleuse                                        */
/* ---------------------------------------------------------------- */

function drawAirlock(ctx, game, opts) {
  const { rect, t, pulse, dark = 0 } = opts;
  const w = rect.w;
  const h = rect.h;
  const horizon = h * 0.46;
  const light = 1 - dark;
  const state = game.state;

  // Rückwand
  const wall = ctx.createLinearGradient(0, 0, 0, horizon);
  wall.addColorStop(0, '#2a3140');
  wall.addColorStop(1, '#1b212b');
  ctx.fillStyle = wall;
  ctx.fillRect(0, 0, w, horizon);

  // Betonfugen
  ctx.strokeStyle = withAlpha('#000', 0.3);
  for (let y = 20; y < horizon; y += 34) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
  }
  for (let x = 30; x < w; x += 90) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, horizon); ctx.stroke();
  }

  // Boden mit Fluchtlinien
  const floor = ctx.createLinearGradient(0, horizon, 0, h);
  floor.addColorStop(0, '#20262f');
  floor.addColorStop(1, '#12161c');
  ctx.fillStyle = floor;
  ctx.fillRect(0, horizon, w, h - horizon);
  ctx.strokeStyle = withAlpha(PAL.line, 0.4 * light);
  for (let k = -5; k <= 5; k++) {
    ctx.beginPath();
    ctx.moveTo(w / 2 + k * 26, horizon);
    ctx.lineTo(w / 2 + k * 200, h);
    ctx.stroke();
  }
  for (let d = 1; d <= 5; d++) {
    const y = horizon + Math.pow(d / 5, 2) * (h - horizon);
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
  }

  // Warnstreifen auf dem Boden
  ctx.save();
  ctx.globalAlpha = 0.5 * light;
  for (let s = 0; s < 14; s++) {
    ctx.fillStyle = s % 2 ? '#1b1f27' : PAL.amber;
    ctx.fillRect(s * (w / 14), h * 0.86, w / 14, 8);
  }
  ctx.restore();

  // Tür nach draussen (links) und in den Club (rechts)
  drawDoorway(ctx, w * 0.05, horizon * 0.42, w * 0.11, horizon * 0.58, '#0a0d12', PAL.cyan, 'RAUS', light);
  drawDoorway(ctx, w * 0.84, horizon * 0.38, w * 0.11, horizon * 0.62, '#12060a', PAL.red, 'CLUB', light);

  // Bass-Licht aus der Clubtür
  glow(ctx, w * 0.895, horizon * 0.7, 110 + pulse * 50, PAL.red, (0.16 + pulse * 0.16) * light);

  // Scanner-Bogen hinter dem Gast
  drawScannerArch(ctx, w, horizon, h, t, light, upgradeLevel(state, 'scanner'));

  // Kamera
  drawCamera(ctx, w * 0.5, 22, t, light, upgradeLevel(state, 'cameras'));

  // Deckenlicht auf den Gast
  beam(ctx, w / 2, 0, 0, h * 0.8, w * 0.19, '#cfe0ff', 0.06 * light);
  glow(ctx, w / 2, h * 0.72, 190, '#9fc0ff', 0.05 * light);

  drawCounter(ctx, w, h, light, 'KONTROLLTISCH', PAL.cyan);

  // Wartende in der Schleuse
  const waiting = opts.queue ?? [];
  for (let i = Math.min(waiting.length, 3) - 1; i >= 0; i--) {
    const g = waiting[i];
    drawFigure(ctx, {
      x: w * (0.18 + i * 0.07),
      y: horizon + (h - horizon) * 0.42,
      h: h * 0.34,
      look: g.look,
      personality: g.personality,
      t: t + g.swayPhase,
      drunk: g.truth.drunk,
      dim: 0.35 + i * 0.08
    });
  }
}

function drawDoorway(ctx, x, y, w, h, fill, accent, label, light) {
  ctx.fillStyle = fill;
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = withAlpha(accent, 0.75 * light);
  ctx.lineWidth = 2;
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
  ctx.save();
  ctx.font = '10px "IBM Plex Mono", monospace';
  ctx.fillStyle = withAlpha(accent, 0.85 * light);
  ctx.textAlign = 'center';
  ctx.letterSpacing = '3px';
  ctx.fillText(label, x + w / 2, y - 8);
  ctx.restore();
}

function drawScannerArch(ctx, w, horizon, h, t, light, level) {
  const cx = w / 2;
  const archW = w * 0.42;
  const top = horizon * 0.46;
  const bottom = horizon + (h - horizon) * 0.5;

  ctx.strokeStyle = withAlpha('#7c8593', 0.8 * light);
  ctx.lineWidth = 10;
  ctx.beginPath();
  ctx.moveTo(cx - archW / 2, bottom);
  ctx.lineTo(cx - archW / 2, top + 20);
  ctx.quadraticCurveTo(cx, top - 10, cx + archW / 2, top + 20);
  ctx.lineTo(cx + archW / 2, bottom);
  ctx.stroke();

  // Statuslampen am Bogen
  const on = Math.sin(t * 3) > 0;
  for (let i = 0; i < 6; i++) {
    const yy = top + 34 + i * ((bottom - top - 40) / 6);
    for (const side of [-1, 1]) {
      ctx.fillStyle = withAlpha(level >= 1 ? (on ? PAL.green : '#2c3a33') : '#3a3a3a', light);
      ctx.fillRect(cx + side * (archW / 2) - 3, yy, 6, 4);
    }
  }
  ctx.save();
  ctx.font = '9px "IBM Plex Mono", monospace';
  ctx.fillStyle = withAlpha(PAL.grey, 0.7 * light);
  ctx.textAlign = 'center';
  ctx.letterSpacing = '2px';
  ctx.fillText(level >= 1 ? `SCANNER LV.${level}` : 'SCANNER: KEINER', cx, top + 4);
  ctx.restore();
}

function drawCamera(ctx, x, y, t, light, level) {
  ctx.fillStyle = '#1a1f28';
  roundRect(ctx, x - 14, y, 28, 12, 3);
  ctx.fill();
  ctx.fillStyle = '#0b0e13';
  ctx.beginPath();
  ctx.arc(x + 10, y + 6, 5, 0, Math.PI * 2);
  ctx.fill();
  if (level >= 1) {
    ctx.fillStyle = Math.sin(t * 2) > 0 ? PAL.red : '#3a1418';
    ctx.fillRect(x - 10, y + 4, 4, 4);
  }
}

/* ---------------------------------------------------------------- */
/* Der Gast direkt vor dem Spieler                                   */
/* ---------------------------------------------------------------- */

function drawGuestAtStation(ctx, game, opts) {
  const { rect, station, t, area } = opts;
  const guest = station?.guest;
  const w = rect.w;
  const h = rect.h;
  const baseY = h * (area === 'outside' ? 0.93 : 0.92);

  if (!guest) {
    ctx.save();
    ctx.font = '12px "IBM Plex Mono", monospace';
    ctx.fillStyle = withAlpha(PAL.grey, 0.55);
    ctx.textAlign = 'center';
    ctx.letterSpacing = '4px';
    ctx.fillText(area === 'outside' ? 'NIEMAND AN DER TÜR' : 'SCHLEUSE FREI', w / 2, h * 0.62);
    ctx.restore();
    return;
  }

  const holding = !!station.checks.id;
  const figureH = guestHeight(w, h);
  drawFigure(ctx, {
    x: w / 2,
    y: baseY,
    h: figureH,
    look: guest.look,
    personality: guest.personality,
    t: t + guest.swayPhase,
    drunk: guest.truth.drunk,
    holdingId: holding,
    vip: guest.truth.vip,
    accent: guest.isArtist ? PAL.amber : guest.truth.vip ? PAL.purple : null
  });

  // Abtast-Zonen einblenden
  if (station.patdown && !station.patdown.complete) {
    drawPatdownOverlay(ctx, station, w, h, baseY, t, figureH);
  }

  // Sprechblase
  if (guest.said && guest.saidTimer > 0) {
    drawSpeech(ctx, w / 2, baseY - figureH - 26, guest.said, PAL.white, Math.min(320, w * 0.62));
  }

  // Kennzeichnung
  if (guest.truth.vip || guest.isArtist) {
    ctx.save();
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.textAlign = 'center';
    ctx.letterSpacing = '3px';
    ctx.fillStyle = guest.isArtist ? PAL.amber : PAL.purple;
    ctx.fillText(guest.isArtist ? 'ACT' : 'VIP', w / 2, baseY - figureH - 34);
    ctx.restore();
  }
}

const ZONE_POS = {
  jacket: { dy: 0.42, label: 'JACKE', key: 'J' },
  pockets: { dy: 0.26, label: 'TASCHEN', key: 'K' },
  bag: { dy: 0.16, label: 'BEUTEL', key: 'L' }
};

/** Höhe der Figur: nie breiter als die (im Splitscreen halbe) Ansicht. */
function guestHeight(w, h) {
  return Math.min(h * 0.56, w * 0.62);
}

function drawPatdownOverlay(ctx, station, w, h, baseY, t, figureH) {
  for (const [zone, cfg] of Object.entries(ZONE_POS)) {
    const y = baseY - figureH * cfg.dy;
    const status = station.patdown.zones[zone];
    const hinted = station.patdown.hint === zone;
    const pulse = 0.5 + Math.sin(t * 6) * 0.5;
    const color = status === 'hit' ? PAL.red
      : status === 'clear' ? PAL.green
        : hinted ? PAL.amber : PAL.cyan;
    ctx.save();
    ctx.strokeStyle = withAlpha(color, status ? 0.9 : 0.35 + pulse * 0.35);
    ctx.lineWidth = 1.5;
    ctx.setLineDash(status ? [] : [4, 4]);
    ctx.beginPath();
    ctx.ellipse(w / 2, y, figureH * 0.14, figureH * 0.075, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.fillStyle = withAlpha(color, 0.95);
    ctx.textAlign = 'left';
    ctx.textAlign = 'right';
    ctx.fillText(`[${cfg.key}] ${cfg.label}${status === 'hit' ? ' — TREFFER' : status === 'clear' ? ' — FREI' : ''}`,
      w / 2 - figureH * 0.17, y + 4);
    ctx.restore();
  }
}

/* ---------------------------------------------------------------- */

function drawViewFrame(ctx, game, opts) {
  const { rect, label, accent = PAL.red, sub } = opts;
  const w = rect.w;

  // Kopfzeile der Ansicht (unter der HUD-Leiste)
  const top = 74;
  ctx.save();
  ctx.fillStyle = 'rgba(6,8,12,0.72)';
  ctx.fillRect(0, top, w, 24);
  ctx.font = '10px "IBM Plex Mono", monospace';
  ctx.letterSpacing = '3px';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = accent;
  ctx.textAlign = 'left';
  ctx.fillText(label ?? '', 12, top + 12);
  if (sub) {
    ctx.fillStyle = withAlpha(PAL.grey, 0.9);
    ctx.textAlign = 'right';
    ctx.fillText(sub, w - 12, top + 12);
  }
  ctx.strokeStyle = withAlpha(accent, 0.35);
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, top + 24.5);
  ctx.lineTo(w, top + 24.5);
  ctx.stroke();
  ctx.restore();
}

export { shade };
