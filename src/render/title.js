/**
 * Titelbildschirm: die Schauszene hinter dem Hauptmenü.
 *
 * Man sieht auf einen Blick, worum es geht - eine Clubfassade bei Nacht,
 * Neonschrift über der Tür, eine Schlange hinter der Kordel und davor der
 * Türsteher, der von hinten ins Bild ragt. Alles prozedural, kein Asset.
 *
 * Die Menüspalte liegt rechts, deshalb ist die Bühne nach links gewichtet
 * und die rechte Bildhälfte wird bewusst abgedunkelt.
 */

import { PAL, SKIN, OUTFIT, HAIR, withAlpha } from './palette.js';
import { drawFigure } from './figure.js';
import { glow, beam } from './effects.js';
import { CLUB_NAME } from '../data/config.js';

/** Feste Zufallswerte: die Szene soll bei jedem Start gleich aussehen. */
function seeded(i, salt = 0) {
  const v = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return v - Math.floor(v);
}

/** Die Wartenden vor dem Club - Aussehen einmalig festgelegt. */
const CROWD = Array.from({ length: 11 }, (_, i) => ({
  look: {
    skin: Math.floor(seeded(i, 1) * SKIN.length),
    outfit: Math.floor(seeded(i, 2) * OUTFIT.length),
    hair: Math.floor(seeded(i, 3) * HAIR.length),
    bulk: 0.9 + seeded(i, 4) * 0.3
  },
  personality: ['polite', 'annoyed', 'drunk', 'arrogant', 'nervous'][Math.floor(seeded(i, 5) * 5)],
  drunk: seeded(i, 6) > 0.7 ? 0.5 + seeded(i, 7) * 0.4 : 0,
  phase: seeded(i, 8) * 6.28
}));

const SKYLINE = Array.from({ length: 26 }, (_, i) => ({
  w: 40 + seeded(i, 11) * 74,
  h: 60 + seeded(i, 12) * 150
}));

export function drawTitleScene(ctx, w, h, t, pulse = 0) {
  const horizon = h * 0.62;

  drawSky(ctx, w, h, horizon, t);
  drawSkyline(ctx, w, horizon);
  drawStreet(ctx, w, h, horizon);
  drawFacade(ctx, w, h, horizon, t, pulse);
  drawQueue(ctx, w, h, horizon, t);
  drawRope(ctx, w, horizon, h);
  drawBouncerBack(ctx, w, h, t, pulse);
  drawAtmosphere(ctx, w, h, horizon, t);
  drawScrim(ctx, w, h);
}

/* ---------------- Kulisse ---------------- */

function drawSky(ctx, w, h, horizon, t) {
  const sky = ctx.createLinearGradient(0, 0, 0, horizon);
  sky.addColorStop(0, '#05070c');
  sky.addColorStop(0.55, '#0c1018');
  sky.addColorStop(1, '#1a1320');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, horizon);

  // Lichtschein der Stadt über dem Horizont
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const haze = ctx.createLinearGradient(0, horizon - 220, 0, horizon);
  haze.addColorStop(0, 'rgba(0,0,0,0)');
  haze.addColorStop(1, withAlpha(PAL.red, 0.1));
  ctx.fillStyle = haze;
  ctx.fillRect(0, horizon - 220, w, 220);
  ctx.restore();

  // Zwei Suchscheinwerfer wandern langsam über den Himmel
  for (const [i, color] of [[0, PAL.cyan], [1, PAL.red]]) {
    const base = w * (i ? 0.62 : 0.16);
    const angle = Math.sin(t * 0.22 + i * 2.1) * 0.55 + (i ? 0.3 : -0.3);
    beam(ctx, base, horizon, Math.PI + angle, horizon * 1.15, 26, color, 0.05);
  }
}

function drawSkyline(ctx, w, horizon) {
  let x = -30;
  SKYLINE.forEach((b, i) => {
    if (x > w + 40) return;
    ctx.fillStyle = i % 3 === 0 ? '#0a0e15' : '#0d1119';
    ctx.fillRect(x, horizon - b.h, b.w, b.h);
    // beleuchtete Fenster
    for (let wy = horizon - b.h + 10; wy < horizon - 10; wy += 15) {
      for (let wx = x + 7; wx < x + b.w - 8; wx += 13) {
        const s = seeded(Math.round(wx), Math.round(wy));
        if (s > 0.78) {
          ctx.fillStyle = withAlpha(s > 0.95 ? '#9fd8ff' : '#ffd9a0', 0.1 + s * 0.12);
          ctx.fillRect(wx, wy, 5, 7);
        }
      }
    }
    x += b.w + 8;
  });
}

function drawStreet(ctx, w, h, horizon) {
  const ground = ctx.createLinearGradient(0, horizon, 0, h);
  ground.addColorStop(0, '#171c25');
  ground.addColorStop(0.5, '#11151d');
  ground.addColorStop(1, '#080a0e');
  ctx.fillStyle = ground;
  ctx.fillRect(0, horizon, w, h - horizon);

  // Nasser Asphalt: die Lichter spiegeln sich in Streifen
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 26; i++) {
    const rx = seeded(i, 21) * w;
    const ry = horizon + seeded(i, 22) * (h - horizon);
    ctx.fillStyle = withAlpha(i % 4 ? PAL.red : PAL.cyan, 0.02 + seeded(i, 23) * 0.03);
    ctx.fillRect(rx, ry, 20 + seeded(i, 24) * 120, 2);
  }
  ctx.restore();

  // Bordstein
  ctx.strokeStyle = withAlpha(PAL.line, 0.4);
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, horizon + 8.5);
  ctx.lineTo(w, horizon + 8.5);
  ctx.stroke();
}

/** Die Clubfassade mit Tür, Neonschrift und Bass-Licht. */
function drawFacade(ctx, w, h, horizon, t, pulse) {
  const fx = w * 0.06;
  const fw = w * 0.62;
  const fy = h * 0.04;
  const fh = horizon - fy + 10;

  // Mauerwerk
  const wall = ctx.createLinearGradient(fx, fy, fx, fy + fh);
  wall.addColorStop(0, '#1b2029');
  wall.addColorStop(0.6, '#151a22');
  wall.addColorStop(1, '#0f1319');
  ctx.fillStyle = wall;
  ctx.fillRect(fx, fy, fw, fh);

  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = 1;
  for (let y = fy + 26; y < fy + fh; y += 26) {
    ctx.beginPath(); ctx.moveTo(fx, y); ctx.lineTo(fx + fw, y); ctx.stroke();
  }
  for (let x = fx + 44; x < fx + fw; x += 44) {
    ctx.beginPath(); ctx.moveTo(x, fy); ctx.lineTo(x, fy + fh); ctx.stroke();
  }

  // Plakate an der Wand
  for (let i = 0; i < 4; i++) {
    const px = fx + 26 + i * 62;
    const py = fy + fh * 0.42 + seeded(i, 31) * 30;
    ctx.save();
    ctx.translate(px, py);
    ctx.rotate((seeded(i, 32) - 0.5) * 0.12);
    ctx.fillStyle = withAlpha(['#d8d2c4', '#c4b6a2', '#b9c3d0'][i % 3], 0.14);
    ctx.fillRect(0, 0, 44, 60);
    ctx.fillStyle = withAlpha(i % 2 ? PAL.red : PAL.cyan, 0.18);
    ctx.fillRect(4, 6, 36, 18);
    ctx.restore();
  }

  // Türnische
  const dw = fw * 0.3;
  const dx = fx + fw * 0.52;
  const dh = fh * 0.5;
  const dy = fy + fh - dh;
  ctx.fillStyle = '#0b0e14';
  ctx.fillRect(dx - 16, dy - 18, dw + 32, dh + 18);
  ctx.strokeStyle = withAlpha(PAL.concreteLight, 0.5);
  ctx.lineWidth = 2;
  ctx.strokeRect(dx - 16.5, dy - 18.5, dw + 33, dh + 19);

  // Offene Tür: rotes Licht drückt auf die Strasse
  const door = ctx.createLinearGradient(dx, dy, dx, dy + dh);
  door.addColorStop(0, withAlpha(PAL.red, 0.5 + pulse * 0.3));
  door.addColorStop(1, withAlpha('#2b0509', 0.95));
  ctx.fillStyle = door;
  ctx.fillRect(dx, dy, dw, dh);

  // Silhouetten im Türrahmen
  ctx.fillStyle = 'rgba(5,3,5,0.82)';
  for (let i = 0; i < 3; i++) {
    const sx = dx + dw * (0.3 + i * 0.24) + Math.sin(t * 1.4 + i) * 4;
    const sh = dh * (0.34 + seeded(i, 41) * 0.08);
    ctx.beginPath();
    ctx.ellipse(sx, dy + dh - sh * 0.5, dw * 0.065, sh * 0.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(sx, dy + dh - sh, dw * 0.04, 0, Math.PI * 2);
    ctx.fill();
  }

  // Lichtteppich vor der Tür
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const spill = ctx.createLinearGradient(0, dy + dh, 0, h);
  spill.addColorStop(0, withAlpha(PAL.red, 0.22 + pulse * 0.1));
  spill.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = spill;
  ctx.beginPath();
  ctx.moveTo(dx, dy + dh);
  ctx.lineTo(dx + dw, dy + dh);
  ctx.lineTo(dx + dw * 2.1, h);
  ctx.lineTo(dx - dw * 1.1, h);
  ctx.closePath();
  ctx.fill();
  ctx.restore();

  glow(ctx, dx + dw / 2, dy + dh * 0.9, 260 + pulse * 90, PAL.red, 0.16 + pulse * 0.1);

  // Vordach mit zwei Lampen
  ctx.fillStyle = '#0d1117';
  ctx.beginPath();
  ctx.moveTo(dx - 44, dy - 18);
  ctx.lineTo(dx + dw + 44, dy - 18);
  ctx.lineTo(dx + dw + 22, dy - 44);
  ctx.lineTo(dx - 22, dy - 44);
  ctx.closePath();
  ctx.fill();
  for (const side of [0.18, 0.82]) {
    const lx = dx + dw * side;
    ctx.fillStyle = withAlpha(PAL.amber, 0.9);
    ctx.beginPath();
    ctx.arc(lx, dy - 22, 5, 0, Math.PI * 2);
    ctx.fill();
    glow(ctx, lx, dy - 22, 90, PAL.amber, 0.1);
  }

  // Hausnummer neben der Tür
  ctx.save();
  ctx.font = '13px "IBM Plex Mono", monospace';
  ctx.letterSpacing = '4px';
  ctx.fillStyle = withAlpha(PAL.grey, 0.5);
  ctx.fillText('NR. 01 · NACHTS', dx - 12, dy + dh - 8);
  ctx.restore();

  drawNeon(ctx, dx + dw / 2, dy - 78, w, t);
}

/** Neonschriftzug des Clubs über der Tür - flackert wie eine echte Röhre. */
function drawNeon(ctx, cx, cy, w, t) {
  const flick = Math.sin(t * 11) > 0.82 ? 0.45 : Math.sin(t * 2.3) > 0.98 ? 0.7 : 1;
  ctx.save();
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `${Math.round(w * 0.042)}px "Archivo Black", "Arial Black", sans-serif`;
  ctx.letterSpacing = '10px';

  // Halterung
  ctx.strokeStyle = 'rgba(0,0,0,0.6)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(cx - w * 0.14, cy + 26);
  ctx.lineTo(cx + w * 0.14, cy + 26);
  ctx.stroke();

  ctx.globalCompositeOperation = 'lighter';
  ctx.shadowColor = PAL.red;
  ctx.shadowBlur = 34 * flick;
  ctx.fillStyle = withAlpha('#ff6a72', 0.85 * flick);
  ctx.fillText(CLUB_NAME, cx, cy);
  ctx.shadowBlur = 12 * flick;
  ctx.fillStyle = withAlpha('#ffe9ea', 0.9 * flick);
  ctx.fillText(CLUB_NAME, cx, cy);

  ctx.shadowBlur = 0;
  ctx.font = '12px "IBM Plex Mono", monospace';
  ctx.letterSpacing = '8px';
  ctx.fillStyle = withAlpha(PAL.cyan, 0.55 * flick);
  ctx.fillText('NACHTS OFFEN', cx, cy + 34);
  ctx.restore();
}

/* ---------------- Menschen ---------------- */

/** Die Schlange: von der Tür weg nach links hinten, in die Tiefe kleiner. */
function drawQueue(ctx, w, h, horizon, t) {
  // Hinten zuerst: die vorderen Gäste sollen die hinteren überdecken.
  for (let i = CROWD.length - 1; i >= 0; i--) {
    const p = CROWD[i];
    const depth = i / (CROWD.length - 1);
    const scale = 1 - depth * 0.42;
    const x = w * (0.47 - depth * 0.3) + Math.sin(depth * 9) * 10;
    const y = horizon + (h - horizon) * (0.62 - depth * 0.34);
    drawFigure(ctx, {
      x,
      y,
      h: h * 0.34 * scale,
      look: p.look,
      personality: p.personality,
      t: t + p.phase,
      drunk: p.drunk,
      bag: i % 4 === 0,
      dim: 0.12 + depth * 0.38
    });
  }
}

/** Absperrkordel zwischen zwei Pfosten. */
function drawRope(ctx, w, horizon, h) {
  const y = horizon + (h - horizon) * 0.4;
  const posts = [w * 0.28, w * 0.52];
  ctx.strokeStyle = withAlpha('#77808e', 0.7);
  ctx.lineWidth = 4;
  for (const px of posts) {
    ctx.beginPath();
    ctx.moveTo(px, y);
    ctx.lineTo(px, y - 62);
    ctx.stroke();
    ctx.fillStyle = '#98a1ad';
    ctx.beginPath();
    ctx.arc(px, y - 68, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    ctx.beginPath();
    ctx.ellipse(px, y + 2, 14, 4, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = withAlpha(PAL.red, 0.75);
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(posts[0], y - 62);
  ctx.quadraticCurveTo((posts[0] + posts[1]) / 2, y - 28, posts[1], y - 62);
  ctx.stroke();
}

/**
 * Der Türsteher im Vordergrund - von hinten, angeschnitten, sehr gross.
 * Er ist fast eine Silhouette; nur die Kanten fangen das Türlicht.
 */
function drawBouncerBack(ctx, w, h, t, pulse) {
  const cx = w * 0.155;
  const base = h * 1.14;
  const bh = h * 0.86;
  const sway = Math.sin(t * 0.6) * 3;
  const shoulderW = bh * 0.27;
  const headR = bh * 0.085;
  const shoulderY = base - bh + headR * 2.6;

  ctx.save();
  ctx.translate(cx + sway, 0);

  // Körper
  const body = ctx.createLinearGradient(0, shoulderY, 0, base);
  body.addColorStop(0, '#0d1119');
  body.addColorStop(1, '#04060a');
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.moveTo(-shoulderW, shoulderY + bh * 0.05);
  ctx.quadraticCurveTo(-shoulderW * 1.05, shoulderY - bh * 0.02, -shoulderW * 0.5, shoulderY - bh * 0.03);
  ctx.quadraticCurveTo(0, shoulderY - bh * 0.055, shoulderW * 0.5, shoulderY - bh * 0.03);
  ctx.quadraticCurveTo(shoulderW * 1.05, shoulderY - bh * 0.02, shoulderW, shoulderY + bh * 0.05);
  ctx.lineTo(shoulderW * 1.04, base);
  ctx.lineTo(-shoulderW * 1.04, base);
  ctx.closePath();
  ctx.fill();

  // Arme, vor der Brust verschränkt (von hinten: Ellbogen stehen ab)
  ctx.strokeStyle = '#0b0e15';
  ctx.lineWidth = bh * 0.075;
  ctx.lineCap = 'round';
  for (const side of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(side * shoulderW * 0.85, shoulderY + bh * 0.07);
    ctx.lineTo(side * shoulderW * 1.16, shoulderY + bh * 0.2);
    ctx.stroke();
  }

  // Nacken und kahler Kopf
  ctx.fillStyle = '#0d1117';
  ctx.fillRect(-headR * 0.55, shoulderY - headR * 1.1, headR * 1.1, headR * 1.4);
  ctx.beginPath();
  ctx.ellipse(0, shoulderY - headR * 1.5, headR * 0.94, headR, 0, 0, Math.PI * 2);
  ctx.fill();
  // Ohren
  ctx.beginPath();
  ctx.ellipse(-headR * 0.92, shoulderY - headR * 1.45, headR * 0.16, headR * 0.26, 0, 0, Math.PI * 2);
  ctx.ellipse(headR * 0.92, shoulderY - headR * 1.45, headR * 0.16, headR * 0.26, 0, 0, Math.PI * 2);
  ctx.fill();

  // Kantenlicht vom Türlicht rechts hinten
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.strokeStyle = withAlpha(PAL.red, 0.4 + pulse * 0.25);
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(shoulderW * 1.02, base);
  ctx.lineTo(shoulderW * 0.99, shoulderY + bh * 0.05);
  ctx.quadraticCurveTo(shoulderW * 1.04, shoulderY - bh * 0.02, shoulderW * 0.5, shoulderY - bh * 0.03);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(0, shoulderY - headR * 1.5, headR * 0.94, -Math.PI * 0.42, Math.PI * 0.28);
  ctx.stroke();
  ctx.strokeStyle = withAlpha(PAL.cyan, 0.12);
  ctx.beginPath();
  ctx.moveTo(-shoulderW * 1.02, base);
  ctx.lineTo(-shoulderW * 0.99, shoulderY + bh * 0.05);
  ctx.quadraticCurveTo(-shoulderW * 1.04, shoulderY - bh * 0.02, -shoulderW * 0.5, shoulderY - bh * 0.03);
  ctx.stroke();
  ctx.restore();

  // Headset-Bügel und Ohrhörer
  ctx.strokeStyle = '#1b212b';
  ctx.lineWidth = Math.max(2, headR * 0.14);
  ctx.beginPath();
  ctx.arc(0, shoulderY - headR * 1.55, headR * 1.02, Math.PI * 1.12, Math.PI * 1.88);
  ctx.stroke();
  ctx.fillStyle = '#262d38';
  ctx.beginPath();
  ctx.arc(-headR * 0.96, shoulderY - headR * 1.42, headR * 0.24, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = Math.sin(t * 3) > 0 ? withAlpha(PAL.green, 0.9) : withAlpha(PAL.green, 0.25);
  ctx.beginPath();
  ctx.arc(-headR * 0.96, shoulderY - headR * 1.42, headR * 0.08, 0, Math.PI * 2);
  ctx.fill();

  // CREW-Aufdruck auf dem Rücken
  ctx.save();
  ctx.font = `${Math.round(bh * 0.05)}px "Archivo Black", "Arial Black", sans-serif`;
  ctx.textAlign = 'center';
  ctx.letterSpacing = '8px';
  ctx.fillStyle = withAlpha('#7a8493', 0.32);
  ctx.fillText('SECURITY', 0, shoulderY + bh * 0.3);
  ctx.restore();

  ctx.restore();
}

/* ---------------- Stimmung ---------------- */

function drawAtmosphere(ctx, w, h, horizon, t) {
  // Bodennebel
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 9; i++) {
    const fx = ((i * 173 + t * 12) % (w + 400)) - 200;
    const fy = horizon + 40 + seeded(i, 51) * (h - horizon) * 0.7;
    const r = 130 + seeded(i, 52) * 140;
    const g = ctx.createRadialGradient(fx, fy, 0, fx, fy, r);
    g.addColorStop(0, withAlpha(i % 3 ? '#4b5b78' : PAL.red, 0.05));
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(fx, fy, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();

  // Nieselregen - dünne, schräge Striche
  ctx.save();
  ctx.strokeStyle = 'rgba(180,205,235,0.16)';
  ctx.lineWidth = 1;
  for (let i = 0; i < 90; i++) {
    const speed = 380 + seeded(i, 61) * 260;
    const x = (seeded(i, 62) * w + t * 40) % w;
    const y = (seeded(i, 63) * h + t * speed) % h;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - 4, y + 16);
    ctx.stroke();
  }
  ctx.restore();
}

/** Rechte Bildhälfte abdunkeln, damit das Menü sauber darauf liegt. */
function drawScrim(ctx, w, h) {
  const g = ctx.createLinearGradient(w * 0.42, 0, w, 0);
  g.addColorStop(0, 'rgba(4,5,9,0)');
  g.addColorStop(0.45, 'rgba(4,5,9,0.62)');
  g.addColorStop(1, 'rgba(4,5,9,0.9)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  const bottom = ctx.createLinearGradient(0, h * 0.82, 0, h);
  bottom.addColorStop(0, 'rgba(4,5,9,0)');
  bottom.addColorStop(1, 'rgba(4,5,9,0.75)');
  ctx.fillStyle = bottom;
  ctx.fillRect(0, h * 0.82, w, h * 0.18);
}
