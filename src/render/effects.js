/** Licht, Nebel, Partikel, Scanlines - die Atmosphäre der Szene. */

import { PAL, withAlpha } from './palette.js';
import { WORLD } from './layout.js';

export function createEffects(rng = Math.random) {
  const fog = [];
  for (let i = 0; i < 16; i++) {
    fog.push({
      x: rng() * WORLD.width,
      y: 340 + rng() * 360,
      r: 90 + rng() * 160,
      vx: (rng() - 0.5) * 8,
      a: 0.03 + rng() * 0.05,
      p: rng() * 6.28
    });
  }
  const dust = [];
  for (let i = 0; i < 60; i++) {
    dust.push({
      x: rng() * WORLD.width,
      y: rng() * WORLD.height,
      vy: -4 - rng() * 10,
      vx: (rng() - 0.5) * 6,
      r: 0.6 + rng() * 1.4,
      a: 0.15 + rng() * 0.35
    });
  }
  const sparks = [];
  return { fog, dust, sparks, t: 0 };
}

export function updateEffects(fx, dt) {
  fx.t += dt;
  for (const f of fx.fog) {
    f.x += f.vx * dt;
    f.p += dt * 0.4;
    if (f.x < -f.r) f.x = WORLD.width + f.r;
    if (f.x > WORLD.width + f.r) f.x = -f.r;
  }
  for (const d of fx.dust) {
    d.x += d.vx * dt;
    d.y += d.vy * dt;
    if (d.y < -10) { d.y = WORLD.height + 10; d.x = Math.random() * WORLD.width; }
  }
  for (let i = fx.sparks.length - 1; i >= 0; i--) {
    const s = fx.sparks[i];
    s.life -= dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.vy += 220 * dt;
    if (s.life <= 0) fx.sparks.splice(i, 1);
  }
}

export function burst(fx, x, y, color = PAL.amber, count = 14) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 60 + Math.random() * 160;
    fx.sparks.push({
      x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60,
      life: 0.4 + Math.random() * 0.5, color
    });
  }
}

export function drawFog(ctx, fx, intensity = 1) {
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (const f of fx.fog) {
    const r = f.r * (1 + Math.sin(f.p) * 0.08);
    const g = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, r);
    g.addColorStop(0, withAlpha('#9fb4c8', f.a * intensity));
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(f.x, f.y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

export function drawDust(ctx, fx) {
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (const d of fx.dust) {
    ctx.fillStyle = withAlpha('#cfe3ff', d.a);
    ctx.fillRect(d.x, d.y, d.r, d.r);
  }
  ctx.restore();
}

export function drawSparks(ctx, fx) {
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const s of fx.sparks) {
    ctx.fillStyle = withAlpha(s.color, Math.max(0, s.life));
    ctx.fillRect(s.x, s.y, 2, 2);
  }
  ctx.restore();
}

/** Weicher Lichtkegel / Glow. */
export function glow(ctx, x, y, radius, color, alpha = 0.5) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
  g.addColorStop(0, withAlpha(color, alpha));
  g.addColorStop(0.55, withAlpha(color, alpha * 0.32));
  g.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

/** Beweglicher Scheinwerfer-Kegel (für Tanzfläche). */
export function beam(ctx, x, y, angle, length, spread, color, alpha = 0.22) {
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.translate(x, y);
  ctx.rotate(angle);
  const g = ctx.createLinearGradient(0, 0, 0, length);
  g.addColorStop(0, withAlpha(color, alpha));
  g.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(-spread, length);
  ctx.lineTo(spread, length);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

export function scanlines(ctx, width, height, alpha = 0.05) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = '#000';
  for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
  ctx.restore();
}

export function vignette(ctx, width, height, strength = 0.75) {
  const g = ctx.createRadialGradient(width / 2, height / 2, height * 0.28, width / 2, height / 2, height * 0.95);
  g.addColorStop(0, 'rgba(0,0,0,0)');
  g.addColorStop(1, `rgba(0,0,0,${strength})`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, width, height);
}
