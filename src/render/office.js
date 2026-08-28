/**
 * Das Büro des Clubleiters - der Tag zwischen zwei Nächten.
 *
 * Tageslicht durch die Jalousie, Kleiderschrank links, Schreibtisch mit
 * Laptop in der Mitte, Tür rechts. Alles prozedural gezeichnet, wie der Rest
 * des Spiels. Die anklickbaren Stellen liegen als Rechtecke in
 * `OFFICE_HOTSPOTS` (Anteile der Fläche) - die Oberfläche legt ihre Felder
 * genau darüber.
 */

import { PAL, withAlpha } from './palette.js';
import { roundRect } from './sprites.js';
import { drawFigure } from './figure.js';
import { characterLook, accentColor } from '../systems/character.js';

export const OFFICE_WORLD = { width: 1280, height: 720 };

export const OFFICE_HOTSPOTS = {
  wardrobe: { x: 0.066, y: 0.076, w: 0.176, h: 0.586, label: 'KLEIDERSCHRANK', note: 'Aussehen ändern' },
  laptop: { x: 0.474, y: 0.505, w: 0.164, h: 0.170, label: 'LAPTOP', note: 'Upgrades kaufen' },
  door: { x: 0.738, y: 0.118, w: 0.180, h: 0.500, label: 'TÜR', note: 'Nächste Nacht' }
};

/** Warme Tagesfarben - der Gegenpol zur Nachtszene. */
const DAY = {
  wallTop: '#4c5464',
  wallBottom: '#343b48',
  floor: '#4a3b2d',
  floorDark: '#2e251c',
  wood: '#4d3a2a',
  woodDark: '#33251a',
  metal: '#5b6472',
  sky: '#8fc3e8',
  sun: '#ffe9b0'
};

export function drawOffice(ctx, w, h, t, character) {
  const horizon = h * 0.61;

  drawWalls(ctx, w, h, horizon, t);
  drawWindow(ctx, w, h, t);
  drawShelfAndPoster(ctx, w, h);
  drawWardrobe(ctx, w, h, t);
  drawDoor(ctx, w, h, t);
  drawDesk(ctx, w, h, t);
  if (character) drawOwner(ctx, w, h, t, character);
  drawLightAndDust(ctx, w, h, t);
}

/* ---------- Raum ---------- */

function drawWalls(ctx, w, h, horizon) {
  const wall = ctx.createLinearGradient(0, 0, 0, horizon);
  wall.addColorStop(0, DAY.wallTop);
  wall.addColorStop(1, DAY.wallBottom);
  ctx.fillStyle = wall;
  ctx.fillRect(0, 0, w, horizon);

  // Fugen der Betonplatten
  ctx.strokeStyle = 'rgba(0,0,0,0.18)';
  ctx.lineWidth = 1;
  for (let y = 60.5; y < horizon; y += 74) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
  }
  for (let x = 92.5; x < w; x += 148) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, horizon); ctx.stroke();
  }

  // Boden mit Dielen in leichter Fluchtperspektive
  const floor = ctx.createLinearGradient(0, horizon, 0, h);
  floor.addColorStop(0, DAY.floorDark);
  floor.addColorStop(0.35, DAY.floor);
  floor.addColorStop(1, '#1d1712');
  ctx.fillStyle = floor;
  ctx.fillRect(0, horizon, w, h - horizon);

  ctx.strokeStyle = 'rgba(0,0,0,0.28)';
  ctx.lineWidth = 1.5;
  for (let i = -6; i <= 18; i++) {
    const xTop = w * 0.5 + i * w * 0.055;
    const xBottom = w * 0.5 + i * w * 0.11;
    ctx.beginPath();
    ctx.moveTo(xTop, horizon);
    ctx.lineTo(xBottom, h);
    ctx.stroke();
  }

  // Sockelleiste
  ctx.fillStyle = '#1b2029';
  ctx.fillRect(0, horizon - 12, w, 12);
  ctx.fillStyle = withAlpha('#ffffff', 0.05);
  ctx.fillRect(0, horizon - 12, w, 2);
}

/** Fenster mit Jalousie: der Tag steht im Raum. */
function drawWindow(ctx, w, h, t) {
  const x = w * 0.255;
  const y = h * 0.13;
  const ww = w * 0.245;
  const wh = h * 0.29;

  // Rahmen
  ctx.fillStyle = '#1c2129';
  roundRect(ctx, x - 12, y - 12, ww + 24, wh + 24, 4); ctx.fill();

  // Himmel und Stadt draussen
  const sky = ctx.createLinearGradient(0, y, 0, y + wh);
  sky.addColorStop(0, '#b9dcf5');
  sky.addColorStop(0.65, DAY.sky);
  sky.addColorStop(1, '#c9cfd6');
  ctx.fillStyle = sky;
  ctx.fillRect(x, y, ww, wh);

  ctx.fillStyle = withAlpha(DAY.sun, 0.9);
  ctx.beginPath();
  ctx.arc(x + ww * 0.74, y + wh * 0.26, wh * 0.11, 0, Math.PI * 2);
  ctx.fill();

  // Häuser gegenüber
  ctx.fillStyle = 'rgba(90,105,125,0.55)';
  for (let i = 0; i < 7; i++) {
    const bw = ww * (0.09 + (i % 3) * 0.035);
    const bh = wh * (0.22 + ((i * 37) % 100) / 100 * 0.32);
    ctx.fillRect(x + i * ww * 0.145, y + wh - bh, bw, bh);
  }

  // Wolke zieht langsam durch
  const cloudX = x + ((t * 9) % (ww + 160)) - 80;
  ctx.fillStyle = 'rgba(255,255,255,0.6)';
  ctx.beginPath();
  ctx.ellipse(cloudX, y + wh * 0.22, 34, 12, 0, 0, Math.PI * 2);
  ctx.ellipse(cloudX + 24, y + wh * 0.19, 22, 10, 0, 0, Math.PI * 2);
  ctx.fill();

  // Jalousie, halb heruntergelassen
  ctx.fillStyle = 'rgba(226,222,208,0.82)';
  for (let sy = y; sy < y + wh * 0.42; sy += 9) {
    ctx.fillRect(x, sy, ww, 6);
  }
  ctx.strokeStyle = 'rgba(0,0,0,0.25)';
  ctx.lineWidth = 1;
  ctx.strokeRect(x + 0.5, y + 0.5, ww - 1, wh - 1);

  // Sprossen
  ctx.fillStyle = '#1c2129';
  ctx.fillRect(x + ww / 2 - 3, y, 6, wh);

  // Lichtbahn in den Raum
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const shaft = ctx.createLinearGradient(x, y + wh, x + ww * 1.4, h);
  shaft.addColorStop(0, withAlpha(DAY.sun, 0.22));
  shaft.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = shaft;
  ctx.beginPath();
  ctx.moveTo(x, y + wh);
  ctx.lineTo(x + ww, y + wh);
  ctx.lineTo(x + ww * 1.9, h);
  ctx.lineTo(x - ww * 0.35, h);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** Regal, Pinnwand und Uhr - damit die Wand nicht leer wirkt. */
function drawShelfAndPoster(ctx, w, h) {
  // Pinnwand
  const px = w * 0.545;
  const py = h * 0.14;
  const pw = w * 0.13;
  const ph = h * 0.19;
  ctx.fillStyle = '#6b5334';
  roundRect(ctx, px, py, pw, ph, 3); ctx.fill();
  ctx.strokeStyle = '#2a2117';
  ctx.lineWidth = 3;
  ctx.strokeRect(px, py, pw, ph);
  for (let i = 0; i < 6; i++) {
    const nx = px + 10 + (i % 3) * (pw / 3);
    const ny = py + 12 + Math.floor(i / 3) * (ph / 2.2);
    ctx.save();
    ctx.translate(nx, ny);
    ctx.rotate((i % 2 ? 1 : -1) * 0.06);
    ctx.fillStyle = ['#f2ead6', '#e8d7a8', '#dfe8ef'][i % 3];
    ctx.fillRect(0, 0, pw / 4, ph / 3.2);
    ctx.fillStyle = 'rgba(60,60,60,0.35)';
    for (let l = 0; l < 3; l++) ctx.fillRect(3, 5 + l * 6, pw / 4 - 8, 2);
    ctx.restore();
  }

  // Wanduhr - zeigt Nachmittag
  const cx = w * 0.715;
  const cy = h * 0.17;
  const r = h * 0.052;
  ctx.fillStyle = '#e7e3d8';
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = '#1b2029';
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.strokeStyle = '#1b2029';
  ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + r * 0.5, cy - r * 0.25); ctx.stroke();
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx, cy - r * 0.7); ctx.stroke();

  // Regal mit Ordnern
  const sx = w * 0.545;
  const sy = h * 0.40;
  const sw = w * 0.20;
  ctx.fillStyle = DAY.woodDark;
  ctx.fillRect(sx, sy, sw, 10);
  const colors = ['#7d3b3b', '#3b5b7d', '#6b6b3b', '#4a3b6b', '#3b6b52'];
  for (let i = 0; i < 9; i++) {
    ctx.fillStyle = colors[i % colors.length];
    const bwid = sw / 11;
    ctx.fillRect(sx + 6 + i * (bwid + 2), sy - 44, bwid, 44);
    ctx.fillStyle = 'rgba(255,255,255,0.16)';
    ctx.fillRect(sx + 6 + i * (bwid + 2), sy - 34, bwid, 6);
  }
}

/* ---------- Möbel ---------- */

function drawWardrobe(ctx, w, h, t) {
  const r = rect(OFFICE_HOTSPOTS.wardrobe, w, h);

  // Korpus
  const body = ctx.createLinearGradient(r.x, 0, r.x + r.w, 0);
  body.addColorStop(0, DAY.woodDark);
  body.addColorStop(0.5, DAY.wood);
  body.addColorStop(1, '#2c2018');
  ctx.fillStyle = body;
  ctx.fillRect(r.x, r.y, r.w, r.h);

  ctx.strokeStyle = 'rgba(0,0,0,0.55)';
  ctx.lineWidth = 3;
  ctx.strokeRect(r.x, r.y, r.w, r.h);

  // Zwei Türen
  ctx.strokeStyle = 'rgba(0,0,0,0.4)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(r.x + r.w / 2, r.y + 8);
  ctx.lineTo(r.x + r.w / 2, r.y + r.h - 8);
  ctx.stroke();
  for (const side of [0.25, 0.75]) {
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 2;
    ctx.strokeRect(r.x + r.w * side - r.w * 0.18, r.y + 22, r.w * 0.36, r.h - 44);
  }

  // Griffe
  ctx.fillStyle = DAY.metal;
  roundRect(ctx, r.x + r.w / 2 - 12, r.y + r.h * 0.48, 7, 44, 3); ctx.fill();
  roundRect(ctx, r.x + r.w / 2 + 5, r.y + r.h * 0.48, 7, 44, 3); ctx.fill();

  // Spiegel auf der linken Tür - fängt das Fensterlicht
  ctx.fillStyle = withAlpha('#cfe4f2', 0.16);
  ctx.fillRect(r.x + r.w * 0.09, r.y + r.h * 0.08, r.w * 0.32, r.h * 0.5);
  ctx.strokeStyle = withAlpha('#ffffff', 0.2);
  ctx.lineWidth = 1;
  ctx.strokeRect(r.x + r.w * 0.09, r.y + r.h * 0.08, r.w * 0.32, r.h * 0.5);

  // Crew-Jacke hängt an der Seite
  const jx = r.x + r.w + 12;
  const jy = r.y + r.h * 0.16;
  ctx.strokeStyle = DAY.metal;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(jx - 6, jy - 14);
  ctx.lineTo(jx + 14, jy - 14);
  ctx.stroke();
  ctx.fillStyle = '#1b1f27';
  ctx.beginPath();
  ctx.moveTo(jx + 4, jy - 10);
  ctx.lineTo(jx + 26, jy + 16);
  ctx.lineTo(jx + 20, jy + 110 + Math.sin(t * 1.2) * 2);
  ctx.lineTo(jx - 12, jy + 110 + Math.sin(t * 1.2) * 2);
  ctx.lineTo(jx - 18, jy + 16);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = withAlpha(PAL.red, 0.7);
  ctx.fillRect(jx - 16, jy + 52, 40, 5);

  // Schatten auf dem Boden
  ctx.fillStyle = 'rgba(0,0,0,0.35)';
  ctx.beginPath();
  ctx.ellipse(r.x + r.w / 2, r.y + r.h + 6, r.w * 0.62, 12, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawDesk(ctx, w, h, t) {
  const dx = w * 0.40;
  const dy = h * 0.655;
  const dw = w * 0.30;
  const dh = h * 0.045;

  // Schatten
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(dx + dw / 2, dy + h * 0.20, dw * 0.6, 20, 0, 0, Math.PI * 2);
  ctx.fill();

  // Bürostuhl - steht hinter dem Tisch, die Lehne schaut über die Platte.
  const cx = dx + dw * 0.13;
  // Der Stuhl steht weiter hinten im Raum: sein Fuss sitzt fast auf der
  // Tischkante, damit die Platte davor liegt und nur die Lehne herausschaut.
  const cy = dy + dh + h * 0.012;
  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  ctx.beginPath();
  ctx.ellipse(cx, cy + 26, 44, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = DAY.metal;
  ctx.fillRect(cx - 4, cy - 10, 8, 34);
  ctx.fillStyle = '#20252e';
  roundRect(ctx, cx - 46, cy - 30, 92, 22, 6); ctx.fill();
  ctx.fillStyle = '#262c36';
  roundRect(ctx, cx - 40, cy - 128, 80, 96, 12); ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.06)';
  roundRect(ctx, cx - 32, cy - 118, 64, 34, 8); ctx.fill();

  // Beine
  ctx.fillStyle = DAY.metal;
  ctx.fillRect(dx + 16, dy + dh, 12, h * 0.17);
  ctx.fillRect(dx + dw - 28, dy + dh, 12, h * 0.17);

  // Platte
  const top = ctx.createLinearGradient(0, dy, 0, dy + dh);
  top.addColorStop(0, '#6a4f38');
  top.addColorStop(1, DAY.woodDark);
  ctx.fillStyle = top;
  roundRect(ctx, dx, dy, dw, dh, 4); ctx.fill();
  ctx.fillStyle = withAlpha('#ffd9a0', 0.12);
  ctx.fillRect(dx + 4, dy + 3, dw - 8, 3);

  // Papierstapel und Kaffeetasse
  ctx.save();
  ctx.translate(dx + dw * 0.12, dy - 12);
  ctx.rotate(-0.05);
  ctx.fillStyle = '#e9e4d4';
  ctx.fillRect(0, 0, 62, 12);
  ctx.fillStyle = '#d5cfbc';
  ctx.fillRect(2, -5, 62, 8);
  ctx.restore();

  ctx.fillStyle = '#d8dee6';
  roundRect(ctx, dx + dw * 0.82, dy - 26, 26, 26, 3); ctx.fill();
  ctx.strokeStyle = '#d8dee6';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(dx + dw * 0.82 + 30, dy - 13, 8, -Math.PI / 2, Math.PI / 2);
  ctx.stroke();
  // Dampf
  ctx.strokeStyle = withAlpha('#ffffff', 0.25);
  ctx.lineWidth = 2;
  for (let i = 0; i < 2; i++) {
    const sx = dx + dw * 0.82 + 8 + i * 10;
    ctx.beginPath();
    ctx.moveTo(sx, dy - 30);
    ctx.quadraticCurveTo(sx + Math.sin(t * 2 + i) * 6, dy - 44, sx, dy - 58);
    ctx.stroke();
  }

  drawLaptop(ctx, w, h, t);
}

/** Der Laptop: hier laufen die Bestellungen für den Ausbau. */
function drawLaptop(ctx, w, h, t) {
  const r = rect(OFFICE_HOTSPOTS.laptop, w, h);
  const baseY = r.y + r.h * 0.82;

  // Deckel
  ctx.save();
  ctx.translate(r.x + r.w * 0.5, baseY);
  ctx.transform(1, 0, -0.16, 1, 0, 0);
  ctx.fillStyle = '#20252e';
  roundRect(ctx, -r.w * 0.42, -r.h * 0.78, r.w * 0.84, r.h * 0.72, 5); ctx.fill();

  // Bildschirm mit Shop-Oberfläche
  const scr = ctx.createLinearGradient(0, -r.h * 0.78, 0, -r.h * 0.06);
  scr.addColorStop(0, '#0d3448');
  scr.addColorStop(1, '#07141d');
  ctx.fillStyle = scr;
  ctx.fillRect(-r.w * 0.37, -r.h * 0.72, r.w * 0.74, r.h * 0.6);

  ctx.fillStyle = withAlpha(PAL.cyan, 0.75);
  ctx.fillRect(-r.w * 0.32, -r.h * 0.66, r.w * 0.3, 4);
  ctx.fillStyle = withAlpha(PAL.amber, 0.6);
  for (let i = 0; i < 3; i++) {
    const bw = r.w * (0.18 + ((i * 13) % 7) / 20) * (0.7 + Math.sin(t * 1.4 + i) * 0.1);
    ctx.fillRect(-r.w * 0.32, -r.h * 0.54 + i * r.h * 0.14, bw, 7);
  }
  ctx.restore();

  // Tastaturteil
  ctx.fillStyle = '#2b313b';
  roundRect(ctx, r.x + r.w * 0.06, baseY, r.w * 0.88, r.h * 0.13, 4); ctx.fill();
  ctx.fillStyle = '#3a414d';
  ctx.fillRect(r.x + r.w * 0.18, baseY + 3, r.w * 0.64, 5);

  // Bildschirmschein auf der Tischplatte
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const glowGrad = ctx.createRadialGradient(r.x + r.w / 2, baseY, 4, r.x + r.w / 2, baseY, r.w);
  glowGrad.addColorStop(0, withAlpha(PAL.cyan, 0.16 + Math.sin(t * 2) * 0.03));
  glowGrad.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = glowGrad;
  ctx.fillRect(r.x - r.w, baseY - r.h, r.w * 3, r.h * 2.4);
  ctx.restore();
}

/** Die Tür: dahinter beginnt die nächste Nacht. */
function drawDoor(ctx, w, h, t) {
  const r = rect(OFFICE_HOTSPOTS.door, w, h);

  // Rahmen
  ctx.fillStyle = '#1b2029';
  ctx.fillRect(r.x - 14, r.y - 14, r.w + 28, r.h + 14);

  const panel = ctx.createLinearGradient(r.x, 0, r.x + r.w, 0);
  panel.addColorStop(0, '#4a3729');
  panel.addColorStop(0.55, '#5d4633');
  panel.addColorStop(1, '#38291d');
  ctx.fillStyle = panel;
  ctx.fillRect(r.x, r.y, r.w, r.h);

  ctx.strokeStyle = 'rgba(0,0,0,0.45)';
  ctx.lineWidth = 3;
  for (const [oy, oh] of [[0.07, 0.34], [0.5, 0.42]]) {
    ctx.strokeRect(r.x + r.w * 0.14, r.y + r.h * oy, r.w * 0.72, r.h * oh);
  }

  // Klinke
  ctx.fillStyle = '#c9a35c';
  roundRect(ctx, r.x + r.w * 0.06, r.y + r.h * 0.52, r.w * 0.2, 10, 5); ctx.fill();
  ctx.beginPath();
  ctx.arc(r.x + r.w * 0.14, r.y + r.h * 0.53, 9, 0, Math.PI * 2);
  ctx.fill();

  // Schild "ZUR TÜR" - der Weg nach draussen
  ctx.fillStyle = '#12161d';
  roundRect(ctx, r.x + r.w * 0.16, r.y + r.h * 0.14, r.w * 0.68, 34, 3); ctx.fill();
  ctx.save();
  ctx.font = '13px "IBM Plex Mono", monospace';
  ctx.textAlign = 'center';
  ctx.letterSpacing = '3px';
  ctx.fillStyle = withAlpha(PAL.red, 0.7 + Math.sin(t * 2.4) * 0.25);
  ctx.fillText('NACHTSCHICHT', r.x + r.w * 0.5, r.y + r.h * 0.14 + 22);
  ctx.restore();

  // Lichtspalt unter der Tür
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const spill = ctx.createLinearGradient(0, r.y + r.h - 6, 0, r.y + r.h + 40);
  spill.addColorStop(0, withAlpha(PAL.amber, 0.3));
  spill.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = spill;
  ctx.fillRect(r.x - 10, r.y + r.h - 6, r.w + 20, 46);
  ctx.restore();
}

/** Der eigene Türsteher steht im Raum und wartet auf den Abend. */
function drawOwner(ctx, w, h, t, character) {
  drawFigure(ctx, {
    x: w * 0.335,
    y: h * 0.93,
    h: h * 0.52,
    look: characterLook(character),
    personality: 'polite',
    accent: accentColor(character),
    t
  });
}

function drawLightAndDust(ctx, w, h, t) {
  // Staub im Sonnenlicht
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 40; i++) {
    const seed = Math.sin(i * 12.9898) * 43758.5453;
    const f = seed - Math.floor(seed);
    const x = w * 0.16 + ((f * w * 0.5) + Math.sin(t * 0.25 + i) * 26) % (w * 0.5);
    const y = (h * 0.2 + f * h * 0.7 + t * (6 + f * 10)) % (h * 0.85);
    ctx.fillStyle = withAlpha(DAY.sun, 0.12 + f * 0.12);
    ctx.beginPath();
    ctx.arc(x, y, 1 + f * 1.6, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();

  // Weiche Vignette, damit die Ränder nicht flach wirken
  const v = ctx.createRadialGradient(w * 0.5, h * 0.5, h * 0.3, w * 0.5, h * 0.5, h * 0.95);
  v.addColorStop(0, 'rgba(0,0,0,0)');
  v.addColorStop(1, 'rgba(0,0,0,0.42)');
  ctx.fillStyle = v;
  ctx.fillRect(0, 0, w, h);
}

function rect(spot, w, h) {
  return { x: spot.x * w, y: spot.y * h, w: spot.w * w, h: spot.h * h };
}
