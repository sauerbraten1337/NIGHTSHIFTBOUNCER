/**
 * Prozedurale 2D-Charaktere (leicht erhöhte Top-Down-Perspektive).
 * Alles wird zur Laufzeit gezeichnet - keine externen Assets.
 */

import { SKIN, OUTFIT, HAIR, PAL, withAlpha } from './palette.js';

/**
 * Zeichnet eine animierte Figur.
 * opts: { x, y, look, walkPhase, moving, sway, scale, accent, outline, tag }
 */
export function drawCharacter(ctx, opts) {
  const {
    x, y, look = {}, walkPhase = 0, moving = false, sway = 0,
    scale = 1, accent = null, outline = null, alpha = 1, hatColor = null
  } = opts;

  const s = scale * (look.height ?? 1);
  const bulk = look.bulk ?? 1;
  const skin = SKIN[(look.skin ?? 0) % SKIN.length];
  const outfit = OUTFIT[(look.outfit ?? 0) % OUTFIT.length];
  const hair = HAIR[(look.hair ?? 0) % HAIR.length];

  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.translate(x, y);
  // Betrunkene / nervöse Figuren schwanken sichtbar.
  if (sway) ctx.rotate(Math.sin(walkPhase * 0.6) * sway);
  ctx.scale(s, s);

  // Schatten
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.beginPath();
  ctx.ellipse(0, 2, 11 * bulk, 5, 0, 0, Math.PI * 2);
  ctx.fill();

  const step = moving ? Math.sin(walkPhase) : Math.sin(walkPhase * 0.35) * 0.2;
  const bob = moving ? Math.abs(Math.cos(walkPhase)) * 1.6 : Math.sin(walkPhase * 0.5) * 0.5;

  // Beine
  ctx.strokeStyle = '#0e1015';
  ctx.lineWidth = 4.4 * bulk;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-3, -8);
  ctx.lineTo(-3 + step * 3.4, 0);
  ctx.moveTo(3, -8);
  ctx.lineTo(3 - step * 3.4, 0);
  ctx.stroke();

  // Torso
  const torsoY = -22 - bob;
  ctx.fillStyle = outfit;
  roundRect(ctx, -7.5 * bulk, torsoY, 15 * bulk, 16, 4);
  ctx.fill();

  // Akzentstreifen (Rollen-Farbe / VIP)
  if (accent) {
    ctx.fillStyle = accent;
    roundRect(ctx, -7.5 * bulk, torsoY + 10, 15 * bulk, 3.4, 1.6);
    ctx.fill();
  }

  // Arme
  ctx.strokeStyle = outfit;
  ctx.lineWidth = 3.6 * bulk;
  ctx.beginPath();
  ctx.moveTo(-7 * bulk, torsoY + 3);
  ctx.lineTo(-9.5 * bulk, torsoY + 12 + step * 1.6);
  ctx.moveTo(7 * bulk, torsoY + 3);
  ctx.lineTo(9.5 * bulk, torsoY + 12 - step * 1.6);
  ctx.stroke();

  // Kopf
  const headY = torsoY - 7;
  ctx.fillStyle = skin;
  ctx.beginPath();
  ctx.arc(0, headY, 6.1, 0, Math.PI * 2);
  ctx.fill();

  // Haare / Muetze
  ctx.fillStyle = hatColor ?? hair;
  ctx.beginPath();
  ctx.arc(0, headY - 1.4, 6.1, Math.PI * 0.98, Math.PI * 2.02);
  ctx.fill();
  if (!hatColor && (look.hair ?? 0) % 3 === 0) {
    ctx.fillRect(-6.1, headY - 2.4, 12.2, 2.2);
  }

  if (outline) {
    ctx.strokeStyle = outline;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.ellipse(0, -16, 13 * bulk, 24, 0, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.restore();
}

/** Kleine Menge tanzender Silhouetten auf dem Floor. */
export function drawDancer(ctx, x, y, phase, beat, color) {
  const bounce = Math.sin(phase + beat * Math.PI * 2) * 2.4;
  ctx.save();
  ctx.translate(x, y - bounce);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(0, 0, 3.4, 6.4, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(0, -8, 2.6, 0, Math.PI * 2);
  ctx.fill();
  const armAngle = Math.sin(phase * 1.7 + beat * 6.28) * 0.7;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(-2.6, -3);
  ctx.lineTo(-5.5, -8 - armAngle * 3);
  ctx.moveTo(2.6, -3);
  ctx.lineTo(5.5, -8 + armAngle * 3);
  ctx.stroke();
  ctx.restore();
}

/** Sprechblase über einer Figur. */
export function drawSpeech(ctx, x, y, text, accent = PAL.white, maxWidth = 210) {
  if (!text) return;
  ctx.save();
  ctx.font = '12px "IBM Plex Mono", ui-monospace, monospace';
  const lines = wrapText(ctx, text, maxWidth - 18);
  const w = Math.min(maxWidth, Math.max(...lines.map((l) => ctx.measureText(l).width)) + 18);
  const h = lines.length * 15 + 12;
  const bx = x - w / 2;
  const by = y - h;

  ctx.fillStyle = 'rgba(8,10,14,0.88)';
  ctx.strokeStyle = withAlpha(accent, 0.55);
  ctx.lineWidth = 1;
  roundRect(ctx, bx, by, w, h, 3);
  ctx.fill();
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(x - 5, by + h);
  ctx.lineTo(x, by + h + 6);
  ctx.lineTo(x + 5, by + h);
  ctx.closePath();
  ctx.fillStyle = 'rgba(8,10,14,0.88)';
  ctx.fill();

  ctx.fillStyle = PAL.white;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  lines.forEach((line, i) => ctx.fillText(line, x, by + 12 + i * 15));
  ctx.restore();
}

export function wrapText(ctx, text, maxWidth) {
  const words = String(text).split(' ');
  const lines = [];
  let line = '';
  for (const word of words) {
    const test = line ? `${line} ${word}` : word;
    if (ctx.measureText(test).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = test;
    }
  }
  if (line) lines.push(line);
  return lines;
}

export function roundRect(ctx, x, y, w, h, r) {
  const radius = Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
  ctx.lineTo(x + w, y + h - radius);
  ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
  ctx.lineTo(x + radius, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}
