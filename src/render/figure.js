/**
 * Grosse 2D-Figuren in Frontansicht - das, was der Türsteher tatsächlich sieht.
 * Alles prozedural gezeichnet, kein Asset. Gesichtszüge, Haltung und Schwanken
 * transportieren Stimmung und Betrunkenheit.
 */

import { SKIN, OUTFIT, HAIR, PAL, withAlpha } from './palette.js';
import { roundRect } from './sprites.js';

const MOOD_FACE = {
  polite: { brow: 0, mouth: 0.35, eye: 1 },
  annoyed: { brow: -0.5, mouth: -0.4, eye: 0.9 },
  drunk: { brow: -0.1, mouth: 0.15, eye: 0.5 },
  arrogant: { brow: -0.3, mouth: -0.15, eye: 0.8 },
  aggressive: { brow: -0.9, mouth: -0.7, eye: 1.1 },
  nervous: { brow: 0.5, mouth: -0.2, eye: 1.15 }
};

/**
 * Zeichnet eine Person frontal.
 * opts: { x, y (Fusspunkt), h (Gesamthöhe in px), look, personality,
 *         t (Zeit), drunk, holdingId, accent, dim }
 */
export function drawFigure(ctx, opts) {
  const {
    x, y, h = 300, look = {}, personality = 'polite', t = 0,
    drunk = 0, holdingId = false, accent = null, dim = 0, vip = false
  } = opts;

  const skin = SKIN[(look.skin ?? 0) % SKIN.length];
  const outfit = OUTFIT[(look.outfit ?? 0) % OUTFIT.length];
  const hair = HAIR[(look.hair ?? 0) % HAIR.length];
  const bulk = look.bulk ?? 1;

  const sway = Math.sin(t * (0.9 + drunk * 2.2)) * (1.5 + drunk * 9);
  const breath = Math.sin(t * 1.6) * 0.006 * h;

  const headR = h * 0.095 * bulk;
  const headY = y - h + headR;
  const shoulderY = headY + headR * 1.5;
  const hipY = y - h * 0.40;
  const shoulderW = h * 0.125 * bulk;

  ctx.save();
  ctx.translate(x, 0);
  ctx.translate(sway * 0.4, 0);

  // Schatten
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.beginPath();
  ctx.ellipse(0, y, shoulderW * 1.5, h * 0.022, 0, 0, Math.PI * 2);
  ctx.fill();

  // Beine
  ctx.strokeStyle = shade(outfit, -0.35);
  ctx.lineWidth = h * 0.044 * bulk;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-shoulderW * 0.38, hipY);
  ctx.lineTo(-shoulderW * 0.58, y - h * 0.012);
  ctx.moveTo(shoulderW * 0.38, hipY);
  ctx.lineTo(shoulderW * 0.6, y - h * 0.012);
  ctx.stroke();

  // Schuhe
  ctx.fillStyle = '#0a0c10';
  roundRect(ctx, -shoulderW * 0.72, y - h * 0.022, shoulderW * 0.5, h * 0.022, 2); ctx.fill();
  roundRect(ctx, shoulderW * 0.24, y - h * 0.022, shoulderW * 0.5, h * 0.022, 2); ctx.fill();

  // Torso / Jacke
  const torsoTop = shoulderY - breath;
  ctx.fillStyle = outfit;
  ctx.beginPath();
  ctx.moveTo(-shoulderW, torsoTop + h * 0.02);
  ctx.quadraticCurveTo(-shoulderW * 1.06, torsoTop, -shoulderW * 0.55, torsoTop - h * 0.008);
  ctx.lineTo(shoulderW * 0.55, torsoTop - h * 0.008);
  ctx.quadraticCurveTo(shoulderW * 1.06, torsoTop, shoulderW, torsoTop + h * 0.02);
  ctx.lineTo(shoulderW * 0.78, hipY + h * 0.03);
  ctx.lineTo(-shoulderW * 0.78, hipY + h * 0.03);
  ctx.closePath();
  ctx.fill();

  // Jackenöffnung + Shirt
  ctx.fillStyle = shade(outfit, 0.22);
  ctx.beginPath();
  ctx.moveTo(-shoulderW * 0.3, torsoTop - h * 0.006);
  ctx.lineTo(shoulderW * 0.3, torsoTop - h * 0.006);
  ctx.lineTo(shoulderW * 0.12, hipY);
  ctx.lineTo(-shoulderW * 0.12, hipY);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = shade(outfit, -0.45);
  ctx.lineWidth = Math.max(1, h * 0.004);
  ctx.stroke();

  ctx.fillStyle = shade(outfit, -0.55);
  ctx.fillRect(-shoulderW * 0.8, hipY + h * 0.012, shoulderW * 1.6, h * 0.014);

  if (accent) {
    ctx.fillStyle = accent;
    roundRect(ctx, -shoulderW * 0.85, hipY - h * 0.03, shoulderW * 1.7, h * 0.012, 2);
    ctx.fill();
  }
  if (vip) {
    ctx.strokeStyle = withAlpha(PAL.amber, 0.85);
    ctx.lineWidth = Math.max(1, h * 0.005);
    ctx.beginPath();
    ctx.arc(0, torsoTop + h * 0.045, h * 0.03, Math.PI * 0.15, Math.PI * 0.85);
    ctx.stroke();
  }

  // Arme
  const armSwing = Math.sin(t * 1.1) * h * 0.006;
  ctx.strokeStyle = outfit;
  ctx.lineWidth = h * 0.042 * bulk;
  ctx.beginPath();
  ctx.moveTo(-shoulderW * 0.9, torsoTop + h * 0.03);
  if (holdingId) {
    ctx.lineTo(-shoulderW * 1.1, torsoTop + h * 0.13 + armSwing);
  } else {
    ctx.lineTo(-shoulderW * 1.02, hipY + armSwing);
  }
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(shoulderW * 0.9, torsoTop + h * 0.03);
  if (holdingId) {
    // Ausweis wird nach vorn gehalten
    ctx.lineTo(shoulderW * 0.55, torsoTop + h * 0.14);
  } else {
    ctx.lineTo(shoulderW * 1.02, hipY - armSwing);
  }
  ctx.stroke();

  // Hände
  ctx.fillStyle = skin;
  ctx.beginPath();
  ctx.arc(holdingId ? -shoulderW * 1.1 : -shoulderW * 1.02,
    holdingId ? torsoTop + h * 0.13 + armSwing : hipY + armSwing, h * 0.021, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(holdingId ? shoulderW * 0.55 : shoulderW * 1.02,
    holdingId ? torsoTop + h * 0.14 : hipY - armSwing, h * 0.021, 0, Math.PI * 2);
  ctx.fill();

  if (holdingId) drawHeldCard(ctx, shoulderW * 0.55, torsoTop + h * 0.145, h);

  // Hals
  ctx.fillStyle = shade(skin, -0.2);
  ctx.fillRect(-headR * 0.35, headY + headR * 0.6, headR * 0.7, headR * 0.9);

  // Kopf
  drawHead(ctx, 0, headY - breath, headR, skin, hair, look, personality, drunk, t);

  if (dim > 0) {
    ctx.fillStyle = `rgba(4,6,10,${dim})`;
    ctx.fillRect(-shoulderW * 2, y - h * 1.1, shoulderW * 4, h * 1.15);
  }
  ctx.restore();
}

function drawHead(ctx, x, y, r, skin, hair, look, personality, drunk, t) {
  const face = MOOD_FACE[personality] ?? MOOD_FACE.polite;

  // Kopfform
  ctx.fillStyle = skin;
  ctx.beginPath();
  ctx.ellipse(x, y, r * 0.86, r, 0, 0, Math.PI * 2);
  ctx.fill();
  // Ohren
  ctx.beginPath();
  ctx.ellipse(x - r * 0.86, y + r * 0.08, r * 0.14, r * 0.2, 0, 0, Math.PI * 2);
  ctx.ellipse(x + r * 0.86, y + r * 0.08, r * 0.14, r * 0.2, 0, 0, Math.PI * 2);
  ctx.fill();

  // Augen (blinzeln, bei Betrunkenen halb geschlossen)
  const blink = (Math.sin(t * 0.7) > 0.985 || Math.sin(t * 1.9 + 2) > 0.99) ? 0.12 : 1;
  const open = Math.max(0.12, face.eye * (1 - drunk * 0.55)) * blink;
  const eyeY = y - r * 0.05;
  const eyeDx = r * 0.34;
  for (const side of [-1, 1]) {
    ctx.fillStyle = '#f2f4f8';
    ctx.beginPath();
    ctx.ellipse(x + side * eyeDx, eyeY, r * 0.155, r * 0.105 * open, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#151a22';
    ctx.beginPath();
    ctx.arc(x + side * eyeDx + Math.sin(t * 0.5) * r * 0.025, eyeY, r * 0.062 * Math.max(0.4, open), 0, Math.PI * 2);
    ctx.fill();
  }

  // Augenbrauen
  ctx.strokeStyle = shade(hair, -0.1);
  ctx.lineWidth = Math.max(1, r * 0.09);
  ctx.lineCap = 'round';
  for (const side of [-1, 1]) {
    const inner = y - r * 0.26 + face.brow * r * 0.12 * side * -1;
    const outer = y - r * 0.3 - face.brow * r * 0.08;
    ctx.beginPath();
    ctx.moveTo(x + side * (eyeDx - r * 0.18), inner);
    ctx.lineTo(x + side * (eyeDx + r * 0.18), outer);
    ctx.stroke();
  }

  // Nase
  ctx.strokeStyle = shade(skin, -0.3);
  ctx.lineWidth = Math.max(1, r * 0.06);
  ctx.beginPath();
  ctx.moveTo(x, y + r * 0.05);
  ctx.lineTo(x - r * 0.08, y + r * 0.3);
  ctx.stroke();

  // Mund
  ctx.strokeStyle = shade(skin, -0.55);
  ctx.lineWidth = Math.max(1, r * 0.07);
  ctx.beginPath();
  const mouthY = y + r * 0.5;
  ctx.moveTo(x - r * 0.2, mouthY);
  ctx.quadraticCurveTo(x, mouthY + face.mouth * r * 0.18, x + r * 0.2, mouthY);
  ctx.stroke();

  // Haare
  ctx.fillStyle = hair;
  const style = (look.hair ?? 0) % 4;
  ctx.beginPath();
  if (style === 0) {
    ctx.ellipse(x, y - r * 0.28, r * 0.92, r * 0.75, 0, Math.PI, Math.PI * 2);
  } else if (style === 1) {
    ctx.ellipse(x, y - r * 0.1, r * 0.95, r * 0.95, 0, Math.PI * 1.02, Math.PI * 1.98);
  } else if (style === 2) {
    ctx.ellipse(x, y - r * 0.35, r * 0.7, r * 0.5, 0, Math.PI, Math.PI * 2);
  } else {
    ctx.ellipse(x, y - r * 0.2, r * 0.9, r * 0.85, 0, Math.PI * 0.95, Math.PI * 2.05);
  }
  ctx.fill();
  if (style === 3) {
    // Seitenpartien
    ctx.fillRect(x - r * 0.92, y - r * 0.35, r * 0.2, r * 0.7);
    ctx.fillRect(x + r * 0.72, y - r * 0.35, r * 0.2, r * 0.7);
  }

  // Bartschatten
  if ((look.outfit ?? 0) % 3 === 0) {
    ctx.fillStyle = withAlpha(shade(hair, -0.45), 0.2);
    ctx.beginPath();
    ctx.ellipse(x, y + r * 0.66, r * 0.5, r * 0.22, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  // Betrunken: gerötete Wangen
  if (drunk > 0.45) {
    ctx.fillStyle = withAlpha('#ff5a5a', (drunk - 0.45) * 0.5);
    ctx.beginPath();
    ctx.ellipse(x - r * 0.45, y + r * 0.25, r * 0.2, r * 0.13, 0, 0, Math.PI * 2);
    ctx.ellipse(x + r * 0.45, y + r * 0.25, r * 0.2, r * 0.13, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawHeldCard(ctx, x, y, h) {
  const w = h * 0.075;
  const ch = w * 0.64;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(-0.15);
  ctx.fillStyle = '#c9d2df';
  roundRect(ctx, -w / 2, -ch / 2, w, ch, 2);
  ctx.fill();
  ctx.fillStyle = '#8e99a8';
  ctx.fillRect(-w / 2 + 2, -ch / 2 + 2, w * 0.3, ch - 4);
  ctx.restore();
}

/** Kleines Portrait fürs Ausweisfoto. */
export function drawPortrait(ctx, look, w, h, seed = 0) {
  ctx.save();
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, '#9aa6b6');
  g.addColorStop(1, '#6d7887');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  const skin = SKIN[(look.skin ?? 0) % SKIN.length];
  const hair = HAIR[(look.hair ?? 0) % HAIR.length];
  const outfit = OUTFIT[(look.outfit ?? 0) % OUTFIT.length];
  const cx = w / 2;
  const r = w * 0.29;
  const cy = h * 0.44;

  // Schultern
  ctx.fillStyle = outfit;
  ctx.beginPath();
  ctx.ellipse(cx, h * 1.08, w * 0.52, h * 0.42, 0, 0, Math.PI * 2);
  ctx.fill();

  drawHead(ctx, cx, cy, r, skin, hair, look, 'polite', 0, seed);
  ctx.restore();
}

export function shade(hex, amount) {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const num = parseInt(full, 16);
  let r = (num >> 16) & 255;
  let g = (num >> 8) & 255;
  let b = num & 255;
  const f = (v) => Math.max(0, Math.min(255, Math.round(amount >= 0 ? v + (255 - v) * amount : v * (1 + amount))));
  r = f(r); g = f(g); b = f(b);
  return `rgb(${r},${g},${b})`;
}
