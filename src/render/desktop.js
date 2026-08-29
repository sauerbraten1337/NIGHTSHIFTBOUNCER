/**
 * Hintergrundbild des Laptops - das "Wallpaper" von NIGHT//OS.
 *
 * Kein Foto, sondern gezeichnet wie der Rest des Spiels: Nachthimmel über
 * der Stadt, ein Neon-Raster bis zum Horizont, die Silhouette des Clubs und
 * ein leises Flackern der Röhre. Die Farbe des Rasters richtet sich nach der
 * Club-Stufe, damit der Ausbau auch auf dem Desktop sichtbar wird.
 */

import { PAL, withAlpha } from './palette.js';

/** Rasterfarbe je Club-Stufe: von kaltem Blau zu heissem Magenta. */
const TIER_COLORS = [
  '#2f6f8f', '#2f6f8f', '#2f8f9c', '#39d7ff', '#7a6cff', '#b45cff', '#ff4fa3', '#ff2f3c'
];

export function tierColor(level) {
  return TIER_COLORS[Math.max(0, Math.min(TIER_COLORS.length - 1, level))];
}

/**
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} w @param {number} h  Pixelmasse des Canvas
 * @param {number} t                    Laufzeit in Sekunden
 * @param {number} tier                 Club-Stufe (faerbt das Raster)
 */
export function drawDesktop(ctx, w, h, t, tier = 1) {
  const accent = tierColor(tier);
  const horizon = h * 0.52;

  drawSky(ctx, w, h, horizon, accent, t);
  drawSkyline(ctx, w, horizon, accent, t);
  drawGrid(ctx, w, h, horizon, accent, t);
  drawMark(ctx, w, h, accent, t);
  drawScanlines(ctx, w, h, t);
}

/* ---------- Himmel ---------- */

function drawSky(ctx, w, h, horizon, accent, t) {
  const sky = ctx.createLinearGradient(0, 0, 0, horizon);
  sky.addColorStop(0, '#05060c');
  sky.addColorStop(0.55, '#0a0d1c');
  sky.addColorStop(1, withAlpha(accent, 0.28));
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, horizon);

  const ground = ctx.createLinearGradient(0, horizon, 0, h);
  ground.addColorStop(0, '#080a12');
  ground.addColorStop(1, '#04050a');
  ctx.fillStyle = ground;
  ctx.fillRect(0, horizon, w, h - horizon);

  // Sterne: fester Raster-Zufall, damit nichts springt.
  for (let i = 0; i < 90; i++) {
    const x = ((i * 977) % 1000) / 1000 * w;
    const y = ((i * 613) % 1000) / 1000 * horizon * 0.9;
    const twinkle = 0.25 + 0.25 * Math.sin(t * 1.4 + i);
    ctx.fillStyle = withAlpha(PAL.white, twinkle * 0.5);
    ctx.fillRect(x, y, 1.5, 1.5);
  }

  // Der Lichtschein über dem Horizont atmet.
  const glow = ctx.createRadialGradient(w * 0.5, horizon, 0, w * 0.5, horizon, w * 0.42);
  glow.addColorStop(0, withAlpha(accent, 0.34 + 0.06 * Math.sin(t * 0.8)));
  glow.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, w, horizon + 2);
}

/* ---------- Stadt ---------- */

function drawSkyline(ctx, w, horizon, accent, t) {
  const blocks = 26;
  for (let i = 0; i < blocks; i++) {
    const seed = (i * 7919) % 100 / 100;
    const bw = w / blocks;
    const x = i * bw;
    const bh = horizon * (0.12 + seed * 0.34);
    ctx.fillStyle = '#070910';
    ctx.fillRect(x, horizon - bh, bw - 2, bh);

    // Fenster: ein paar leuchten, ein paar flackern mit.
    for (let fy = horizon - bh + 6; fy < horizon - 6; fy += 9) {
      for (let fx = x + 4; fx < x + bw - 8; fx += 7) {
        const lit = ((fx * 13 + fy * 7) % 11) < 3;
        if (!lit) continue;
        const flick = 0.35 + 0.25 * Math.sin(t * 2 + fx * 0.4 + fy);
        ctx.fillStyle = withAlpha(accent, flick);
        ctx.fillRect(fx, fy, 3, 3);
      }
    }
  }
}

/* ---------- Neon-Raster ---------- */

function drawGrid(ctx, w, h, horizon, accent, t) {
  ctx.save();
  ctx.lineWidth = 1;

  // Fluchtlinien
  ctx.strokeStyle = withAlpha(accent, 0.3);
  for (let i = -14; i <= 14; i++) {
    ctx.beginPath();
    ctx.moveTo(w * 0.5 + i * (w * 0.035), horizon);
    ctx.lineTo(w * 0.5 + i * (w * 0.42), h);
    ctx.stroke();
  }

  // Querlinien laufen auf den Betrachter zu.
  const speed = (t * 0.25) % 1;
  for (let i = 0; i < 16; i++) {
    const p = ((i + speed) / 16) ** 2.4;
    const y = horizon + (h - horizon) * p;
    ctx.strokeStyle = withAlpha(accent, 0.08 + 0.3 * p);
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  // Horizontkante
  ctx.strokeStyle = withAlpha(accent, 0.85);
  ctx.beginPath();
  ctx.moveTo(0, horizon);
  ctx.lineTo(w, horizon);
  ctx.stroke();
  ctx.restore();
}

/* ---------- Logo-Wasserzeichen ---------- */

function drawMark(ctx, w, h, accent, t) {
  ctx.save();
  ctx.globalAlpha = 0.10 + 0.02 * Math.sin(t * 1.1);
  ctx.translate(w * 0.5, h * 0.5);

  ctx.strokeStyle = accent;
  ctx.lineWidth = Math.max(2, w * 0.004);
  const r = Math.min(w, h) * 0.22;
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.stroke();

  ctx.beginPath();
  ctx.arc(0, 0, r * 0.68, Math.PI * 0.15, Math.PI * 1.35);
  ctx.stroke();

  ctx.fillStyle = accent;
  ctx.fillRect(-r * 0.5, -r * 0.06, r, r * 0.12);
  ctx.restore();
}

/* ---------- Röhrenbild ---------- */

function drawScanlines(ctx, w, h, t) {
  ctx.save();
  ctx.fillStyle = 'rgba(0,0,0,0.16)';
  for (let y = 0; y < h; y += 3) ctx.fillRect(0, y, w, 1);

  // Ein heller Balken wandert langsam durchs Bild.
  const band = ((t * 0.08) % 1.3 - 0.15) * h;
  const sweep = ctx.createLinearGradient(0, band - h * 0.06, 0, band + h * 0.06);
  sweep.addColorStop(0, 'rgba(255,255,255,0)');
  sweep.addColorStop(0.5, 'rgba(255,255,255,0.035)');
  sweep.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = sweep;
  ctx.fillRect(0, band - h * 0.06, w, h * 0.12);
  ctx.restore();
}
