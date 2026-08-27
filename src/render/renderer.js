/**
 * Renderer: zeichnet die komplette 2D-Szene (Top-Down mit leichter Aufsicht).
 * Der Club veraendert sich sichtbar mit jeder Ausbaustufe.
 */

import { LAYOUT, WORLD } from './layout.js';
import { PAL, withAlpha } from './palette.js';
import { drawCharacter, drawDancer, drawSpeech, roundRect } from './sprites.js';
import {
  createEffects, updateEffects, drawFog, drawDust, drawSparks,
  glow, beam, scanlines, vignette
} from './effects.js';
import { clubTier, upgradeLevel, capacity } from '../systems/state.js';
import { currentPhase } from '../systems/nightcycle.js';
import { CLUB_NAME } from '../data/config.js';
import { ZONES } from '../systems/security.js';

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d');
  const fx = createEffects();
  let beatTime = 0;

  function resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const rect = canvas.getBoundingClientRect();
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
  }

  window.addEventListener('resize', resize);
  resize();

  function render(game, dt) {
    const { state } = game;
    updateEffects(fx, dt);
    const phase = state.night ? currentPhase(state.night.clock) : { intensity: 0.35, label: 'CLOSED' };
    beatTime += dt * (128 / 60) * (0.8 + phase.intensity * 0.4);
    const beat = beatTime % 1;
    const pulse = Math.pow(1 - beat, 3);

    const dpr = canvas.width / WORLD.width;
    const scaleY = canvas.height / WORLD.height;
    const scale = Math.min(dpr, scaleY);
    const offsetX = (canvas.width - WORLD.width * scale) / 2;
    const offsetY = (canvas.height - WORLD.height * scale) / 2;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = PAL.night;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(scale, 0, 0, scale, offsetX, offsetY);

    const tier = clubTier(state).level;
    const blackout = state.night?.activeEffects.some((e) => e.id === 'blackout');
    const light = blackout ? 0.25 : 1;

    drawStreet(ctx, state, phase, light);
    drawClub(ctx, game, tier, beat, pulse, light);
    drawFacade(ctx, game, tier, pulse, light);
    drawQueueArea(ctx, state, light);

    if (state.night) {
      drawGuests(ctx, game, light);
      drawPlayers(ctx, game);
      drawDoorOverlay(ctx, game, pulse);
    }

    drawFog(ctx, fx, 0.7 + phase.intensity * 0.6);
    drawDust(ctx, fx);
    drawSparks(ctx, fx);
    vignette(ctx, WORLD.width, WORLD.height, blackout ? 0.9 : 0.5);
    scanlines(ctx, WORLD.width, WORLD.height, 0.035);
  }

  return { render, resize, fx, get beat() { return beatTime % 1; } };
}

/* ---------------- Straße ---------------- */

function drawStreet(ctx, state, phase, light) {
  const s = LAYOUT.street;
  const g = ctx.createLinearGradient(0, s.y, 0, WORLD.height);
  g.addColorStop(0, PAL.asphaltLight);
  g.addColorStop(1, PAL.asphalt);
  ctx.fillStyle = g;
  ctx.fillRect(s.x, s.y, s.w, s.h);

  // Pflasterfugen
  ctx.strokeStyle = withAlpha(PAL.line, 0.5 * light);
  ctx.lineWidth = 1;
  for (let y = s.y + 40; y < WORLD.height; y += 46) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(WORLD.width, y);
    ctx.stroke();
  }
  for (let x = 40; x < WORLD.width; x += 92) {
    ctx.beginPath();
    ctx.moveTo(x, s.y);
    ctx.lineTo(x - 40, WORLD.height);
    ctx.stroke();
  }

  // Lichtinseln der Straßenlampen
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const lx of [LAYOUT.club.x + 40, LAYOUT.club.x + LAYOUT.club.w - 40]) {
    const lg = ctx.createRadialGradient(lx, s.y + 60, 6, lx, s.y + 60, 190);
    lg.addColorStop(0, withAlpha(PAL.amber, 0.16 * light));
    lg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.ellipse(lx, s.y + 60, 190, 90, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();

  // Pfützen mit Reflexion
  ctx.save();
  ctx.globalAlpha = 0.5 * light;
  for (const p of PUDDLES) {
    const grad = ctx.createLinearGradient(p.x, p.y - p.h, p.x, p.y + p.h);
    grad.addColorStop(0, withAlpha(PAL.red, 0.25));
    grad.addColorStop(1, withAlpha(PAL.cyan, 0.08));
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.ellipse(p.x, p.y, p.w, p.h, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

const PUDDLES = [
  { x: 300, y: 620, w: 70, h: 16 },
  { x: 880, y: 560, w: 90, h: 18 },
  { x: 620, y: 660, w: 120, h: 20 },
  { x: 1080, y: 640, w: 60, h: 14 }
];

/* ---------------- Club-Inneres ---------------- */

function drawClub(ctx, game, tier, beat, pulse, light) {
  const { state } = game;
  const c = LAYOUT.club;
  const int = LAYOUT.interior;

  // Gebaeudehuelle (Beton, brutalistisch)
  ctx.fillStyle = PAL.concreteDark;
  ctx.fillRect(c.x - 20, c.y - 20, c.w + 40, c.h + 40);
  const shell = ctx.createLinearGradient(0, c.y, 0, c.y + c.h);
  shell.addColorStop(0, PAL.concrete);
  shell.addColorStop(1, '#1d222b');
  ctx.fillStyle = shell;
  ctx.fillRect(c.x, c.y, c.w, c.h);

  // Betonstruktur: Schalungsfugen und Stuetzen
  ctx.strokeStyle = withAlpha('#000', 0.35);
  ctx.lineWidth = 2;
  for (let x = c.x; x < c.x + c.w; x += 80) {
    ctx.beginPath();
    ctx.moveTo(x, c.y);
    ctx.lineTo(x, c.y + c.h);
    ctx.stroke();
  }
  ctx.strokeStyle = withAlpha('#000', 0.22);
  ctx.lineWidth = 1;
  for (let y = c.y + 40; y < c.y + c.h; y += 56) {
    ctx.beginPath();
    ctx.moveTo(c.x, y);
    ctx.lineTo(c.x + c.w, y);
    ctx.stroke();
  }
  // Tragende Säulen
  for (const px of [c.x + 400, c.x + 720]) {
    for (const py of [c.y + 60, c.y + 220]) {
      ctx.fillStyle = PAL.concreteLight;
      ctx.fillRect(px - 7, py - 7, 14, 14);
      ctx.fillStyle = 'rgba(0,0,0,0.45)';
      ctx.fillRect(px - 7, py + 7, 16, 4);
    }
  }
  // Eingangskorridor von der Tür in den Club
  const corr = ctx.createLinearGradient(0, c.y + c.h, 0, c.y + c.h - 90);
  corr.addColorStop(0, withAlpha(PAL.red, 0.16 * light));
  corr.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = corr;
  ctx.fillRect(LAYOUT.door.x - 60, c.y + c.h - 90, 120, 90);

  // --- Tanzfläche ---
  const df = int.dancefloor;
  const floorLevel = upgradeLevel(state, 'floor');
  const dfW = df.w + floorLevel * 40;
  drawDanceFloor(ctx, df.x, df.y, dfW, df.h, beat, pulse, state, light);

  // --- Zweiter Floor ab Ausbaustufe ---
  if (floorLevel >= 2) {
    const f2 = int.floor2;
    drawDanceFloor(ctx, f2.x, f2.y, f2.w, f2.h, (beat + 0.5) % 1, pulse, state, light * 0.9);
    label(ctx, f2.x + f2.w / 2, f2.y - 8, 'FLOOR 2');
  }

  // --- Bar ---
  const barLevel = upgradeLevel(state, 'bar');
  if (barLevel >= 1 || tier >= 2) {
    const b = int.bar;
    room(ctx, b.x, b.y, b.w + barLevel * 20, b.h, '#20242c');
    ctx.fillStyle = withAlpha(PAL.amber, 0.5 * light);
    ctx.fillRect(b.x + 8, b.y + b.h - 14, b.w + barLevel * 20 - 16, 5);
    glow(ctx, b.x + b.w / 2, b.y + b.h - 12, 90, PAL.amber, 0.18 * light);
    label(ctx, b.x + 10, b.y + 14, 'BAR', 'left');
  }

  // --- VIP ---
  if (upgradeLevel(state, 'vip') >= 1) {
    const v = int.vip;
    room(ctx, v.x, v.y, v.w, v.h, '#241b2a');
    glow(ctx, v.x + v.w / 2, v.y + v.h / 2, 100, PAL.purple, 0.2 * light);
    label(ctx, v.x + 10, v.y + 14, 'VIP', 'left');
  } else if (upgradeLevel(state, 'backstage') >= 1) {
    const bs = int.backstage;
    room(ctx, bs.x, bs.y, bs.w, bs.h, '#1d2230');
    label(ctx, bs.x + 10, bs.y + 14, 'BACKSTAGE', 'left');
  }

  // --- DJ-Booth mit animierten Screens ---
  const booth = int.booth;
  ctx.fillStyle = '#0d1015';
  roundRect(ctx, booth.x, booth.y, booth.w, booth.h, 4);
  ctx.fill();
  const ledLevel = upgradeLevel(state, 'lights');
  for (let i = 0; i < 8; i++) {
    const h = 4 + Math.abs(Math.sin(beat * 6.28 + i)) * (10 + ledLevel * 5);
    ctx.fillStyle = withAlpha(i % 2 ? PAL.cyan : PAL.red, (0.5 + pulse * 0.4) * light);
    ctx.fillRect(booth.x + 10 + i * 15, booth.y + booth.h - 6 - h, 9, h);
  }
  if (state.night?.artistPlaying) {
    label(ctx, booth.x + booth.w / 2, booth.y - 6, state.night.artist.name);
  }

  // --- Licht / Laser ---
  if (ledLevel >= 2 && light > 0.5) {
    const t = performance.now() / 1000;
    for (let i = 0; i < 3; i++) {
      const a = Math.sin(t * (0.6 + i * 0.2) + i) * 0.5;
      beam(ctx, booth.x + booth.w / 2, booth.y + booth.h, a, 260, 40 + i * 20,
        i === 1 ? PAL.red : PAL.cyan, 0.13 + pulse * 0.08);
    }
  }
  if (ledLevel >= 3 && light > 0.5) {
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.fillStyle = withAlpha(PAL.purple, 0.05 + pulse * 0.06);
    ctx.fillRect(c.x, c.y, c.w, c.h);
    ctx.restore();
  }

  // --- Soundsystem: Stacks flankieren den Floor ---
  const soundLevel = upgradeLevel(state, 'sound');
  const stackH = 34 + soundLevel * 16;
  for (const sx of [df.x - 26, df.x + dfW + 8]) {
    ctx.fillStyle = '#0c0f14';
    ctx.fillRect(sx, df.y + 6, 18, stackH);
    ctx.strokeStyle = withAlpha(PAL.line, 0.8);
    ctx.strokeRect(sx + 0.5, df.y + 6.5, 17, stackH - 1);
    for (let i = 0; i < 2 + soundLevel; i++) {
      const cy = df.y + 18 + i * 15;
      if (cy > df.y + stackH) break;
      ctx.fillStyle = withAlpha('#000', 0.8);
      ctx.beginPath();
      ctx.arc(sx + 9, cy, 5 + pulse * soundLevel * 0.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = withAlpha(PAL.grey, 0.35);
      ctx.stroke();
    }
  }

  // --- Menschen im Club ---
  drawCrowd(ctx, game, df.x, df.y, dfW, df.h, beat, light);

  // Kante zur Straße
  ctx.fillStyle = PAL.concreteDark;
  ctx.fillRect(c.x - 20, c.y + c.h, c.w + 40, 8);
}

function drawDanceFloor(ctx, x, y, w, h, beat, pulse, state, light) {
  const g = ctx.createLinearGradient(x, y, x, y + h);
  g.addColorStop(0, '#222a36');
  g.addColorStop(1, '#151a22');
  ctx.fillStyle = g;
  ctx.fillRect(x, y, w, h);

  // Bodenraster (reflektierender Estrich)
  ctx.save();
  ctx.strokeStyle = withAlpha('#000', 0.25);
  ctx.lineWidth = 1;
  for (let gx = x + 40; gx < x + w; gx += 40) {
    ctx.beginPath(); ctx.moveTo(gx, y); ctx.lineTo(gx, y + h); ctx.stroke();
  }
  for (let gy = y + 35; gy < y + h; gy += 35) {
    ctx.beginPath(); ctx.moveTo(x, gy); ctx.lineTo(x + w, gy); ctx.stroke();
  }
  ctx.restore();

  // reflektierender Boden + wandernder Scheinwerfer
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, w, h);
  ctx.clip();
  ctx.globalCompositeOperation = 'lighter';
  const rg = ctx.createRadialGradient(x + w / 2, y + h * 0.4, 10, x + w / 2, y + h * 0.4, w * 0.7);
  rg.addColorStop(0, withAlpha(PAL.red, (0.3 + pulse * 0.2) * light));
  rg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = rg;
  ctx.fillRect(x, y, w, h);

  const t = performance.now() / 1000;
  const spotX = x + w / 2 + Math.sin(t * 0.55) * w * 0.36;
  const spotY = y + h * 0.55 + Math.cos(t * 0.4) * h * 0.22;
  const sg = ctx.createRadialGradient(spotX, spotY, 4, spotX, spotY, 90);
  sg.addColorStop(0, withAlpha(PAL.cyan, (0.22 + pulse * 0.16) * light));
  sg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = sg;
  ctx.fillRect(x, y, w, h);
  ctx.restore();

  ctx.strokeStyle = withAlpha(PAL.line, 0.7);
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

function drawCrowd(ctx, game, x, y, w, h, beat, light) {
  const night = game.state.night;
  const count = night ? Math.min(70, Math.ceil(night.inside.length)) : 12;
  const cap = capacity(game.state);
  const density = night ? Math.min(1, night.inside.length / Math.max(1, cap)) : 0.2;
  for (let i = 0; i < count; i++) {
    const seed = i * 2654435761 % 1000 / 1000;
    const seed2 = (i * 40503) % 997 / 997;
    const px = x + 16 + seed * (w - 32);
    const py = y + 20 + seed2 * (h - 34);
    const color = withAlpha(i % 7 === 0 ? PAL.cyan : '#dbe3ef', (0.55 + density * 0.3) * light);
    drawDancer(ctx, px, py, seed * 6.28 + i, beat, color);
  }
}

function room(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = withAlpha('#000', 0.5);
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

function label(ctx, x, y, text, align = 'center') {
  ctx.save();
  ctx.font = '10px "IBM Plex Mono", ui-monospace, monospace';
  ctx.fillStyle = withAlpha(PAL.grey, 0.85);
  ctx.textAlign = align;
  ctx.letterSpacing = '2px';
  ctx.fillText(text, x, y);
  ctx.restore();
}

/* ---------------- Fassade & Tür ---------------- */

function drawFacade(ctx, game, tier, pulse, light) {
  const { state } = game;
  const c = LAYOUT.club;
  const d = LAYOUT.door;
  const y = LAYOUT.club.y + LAYOUT.club.h + 8;

  // Fassadenband
  const band = ctx.createLinearGradient(0, y, 0, y + 22);
  band.addColorStop(0, PAL.concreteLight);
  band.addColorStop(1, '#232935');
  ctx.fillStyle = band;
  ctx.fillRect(c.x - 20, y, c.w + 40, 22);
  ctx.strokeStyle = withAlpha('#000', 0.5);
  ctx.strokeRect(c.x - 20.5, y + 0.5, c.w + 41, 22);

  // Rote Warnlichter auf der Fassade
  const blink = Math.sin(performance.now() / 420) > 0 ? 1 : 0.25;
  for (let lx = c.x + 60; lx < c.x + c.w; lx += 150) {
    ctx.fillStyle = withAlpha(PAL.red, 0.75 * blink * light);
    ctx.fillRect(lx - 5, y + 6, 10, 4);
    glow(ctx, lx, y + 8, 34, PAL.red, 0.25 * blink * light);
  }

  // Tür
  const doorW = d.w + upgradeLevel(state, 'door') * 22;
  ctx.fillStyle = '#04050a';
  ctx.fillRect(d.x - doorW / 2, y - 8, doorW, 34);
  ctx.strokeStyle = withAlpha(PAL.red, 0.9 * light);
  ctx.lineWidth = 2.5;
  ctx.strokeRect(d.x - doorW / 2, y - 8, doorW, 34);
  // Lichtaustritt aus der offenen Tür auf die Straße
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const spill = ctx.createLinearGradient(0, y + 20, 0, y + 150);
  spill.addColorStop(0, withAlpha(PAL.red, (0.3 + pulse * 0.12) * light));
  spill.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = spill;
  ctx.beginPath();
  ctx.moveTo(d.x - doorW / 2, y + 22);
  ctx.lineTo(d.x + doorW / 2, y + 22);
  ctx.lineTo(d.x + doorW * 1.5, y + 160);
  ctx.lineTo(d.x - doorW * 1.5, y + 160);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
  glow(ctx, d.x, y + 18, 150 + tier * 12, PAL.red, (0.26 + pulse * 0.14) * light);

  // Hintereingang (Backstage)
  if (upgradeLevel(state, 'backstage') >= 1) {
    const b = LAYOUT.backDoor;
    ctx.fillStyle = '#05060a';
    ctx.fillRect(b.x - b.w / 2, y - 4, b.w, 22);
    ctx.strokeStyle = withAlpha(PAL.cyan, 0.7 * light);
    ctx.strokeRect(b.x - b.w / 2, y - 4, b.w, 22);
    glow(ctx, b.x, y + 16, 70, PAL.cyan, 0.16 * light);
    label(ctx, b.x, y + 38, 'BACKSTAGE');
  }

  // Neon-Schriftzug an der Fassade (flackert auf niedriger Ausbaustufe)
  const flicker = tier <= 2 ? (Math.sin(performance.now() / 90) > 0.55 ? 0.35 : 1) : 1;
  const signW = 210;
  const signX = c.x + c.w - signW - 20;
  ctx.fillStyle = '#0a0d12';
  ctx.fillRect(signX, y + 1, signW, 20);
  ctx.strokeStyle = withAlpha(PAL.red, 0.4 * flicker * light);
  ctx.strokeRect(signX + 0.5, y + 1.5, signW - 1, 19);
  ctx.save();
  ctx.font = `${12 + tier}px "Archivo Black", "Arial Black", sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.letterSpacing = `${3 + tier}px`;
  ctx.shadowColor = PAL.red;
  ctx.shadowBlur = 18 * flicker * light;
  ctx.fillStyle = withAlpha('#ffe3e6', flicker * light);
  ctx.fillText(CLUB_NAME, signX + signW / 2, y + 11);
  ctx.restore();

  // VIP-Eingang ab Tür-Stufe 3
  if (upgradeLevel(state, 'door') >= 3) {
    ctx.fillStyle = '#05060a';
    ctx.fillRect(d.x + 150, y - 4, 60, 22);
    ctx.strokeStyle = withAlpha(PAL.purple, 0.8 * light);
    ctx.strokeRect(d.x + 150, y - 4, 60, 22);
    label(ctx, d.x + 180, y + 34, 'VIP');
  }

  // Lichtmasten
  for (const x of [c.x + 40, c.x + c.w - 40]) {
    ctx.fillStyle = PAL.concreteLight;
    ctx.fillRect(x - 3, y + 14, 6, 26);
    glow(ctx, x, y + 40, 70, PAL.amber, 0.14 * light);
  }
}

/* ---------------- Warteschlange / Absperrung ---------------- */

function drawQueueArea(ctx, state, light) {
  const q = LAYOUT.queue;
  ctx.save();
  ctx.strokeStyle = withAlpha(PAL.grey, 0.35 * light);
  ctx.lineWidth = 2;
  const rows = 3;
  for (let r = 0; r < rows; r++) {
    const y = q.y + r * q.rowGap + 26;
    ctx.setLineDash([10, 12]);
    ctx.beginPath();
    ctx.moveTo(q.x - 40, y);
    ctx.lineTo(q.x + q.perRow * q.spacing, y);
    ctx.stroke();
  }
  ctx.setLineDash([]);
  // Pfosten
  for (let r = 0; r <= rows; r++) {
    for (const x of [q.x - 40, q.x + q.perRow * q.spacing]) {
      const y = q.y + r * q.rowGap + 26;
      ctx.fillStyle = PAL.concreteLight;
      ctx.fillRect(x - 3, y - 16, 6, 18);
    }
  }
  ctx.restore();

  // Stationen der Spieler
  for (const key of ['door', 'search']) {
    const st = LAYOUT.stations[key];
    ctx.save();
    ctx.strokeStyle = withAlpha(key === 'door' ? PAL.red : PAL.cyan, 0.22);
    ctx.setLineDash([6, 8]);
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(st.x, st.y, st.r, st.r * 0.42, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    label(ctx, st.x, st.y + st.r * 0.42 + 14, st.label);
  }
}

/* ---------------- Figuren ---------------- */

function drawGuests(ctx, game, light) {
  const night = game.state.night;
  const all = [...night.queue, ...(night.leaving ?? []), ...(night.door ? [night.door] : [])];
  all.sort((a, b) => a.y - b.y);

  for (const g of all) {
    const isDoor = night.door === g;
    const accent = g.isArtist ? PAL.amber : g.truth.vip ? PAL.purple : null;
    drawCharacter(ctx, {
      x: g.x, y: g.y, look: g.look, walkPhase: g.walkPhase, moving: g.moving,
      sway: g.truth.drunk > 0.45 ? g.truth.drunk * 0.09 : 0,
      scale: 1.15, accent,
      outline: isDoor ? withAlpha(PAL.white, 0.5) : null,
      alpha: g.state === 'rejected' || g.state === 'left' ? 0.6 : 1
    });

    // Geduldsanzeige
    if (g.state === 'queue') {
      const ratio = Math.max(0, g.patience / g.patienceMax);
      const w = 22;
      ctx.fillStyle = 'rgba(0,0,0,0.6)';
      ctx.fillRect(g.x - w / 2, g.y - 52, w, 3);
      ctx.fillStyle = ratio > 0.5 ? PAL.green : ratio > 0.25 ? PAL.amber : PAL.red;
      ctx.fillRect(g.x - w / 2, g.y - 52, w * ratio, 3);
    }

    if (g.truth.vip || g.isArtist) {
      ctx.save();
      ctx.font = '9px "IBM Plex Mono", monospace';
      ctx.textAlign = 'center';
      ctx.fillStyle = g.isArtist ? PAL.amber : PAL.purple;
      ctx.fillText(g.isArtist ? 'ACT' : 'VIP', g.x, g.y - 58);
      ctx.restore();
    }

    if (g.said && g.saidTimer > 0) {
      drawSpeech(ctx, g.x, g.y - 62, g.said, isDoor ? PAL.white : PAL.grey, isDoor ? 240 : 170);
    }
  }
}

function drawPlayers(ctx, game) {
  for (const p of game.players) {
    const accent = p.role.accent;
    drawCharacter(ctx, {
      x: p.x, y: p.y, look: PLAYER_LOOK[p.role.id], walkPhase: p.walkPhase,
      moving: Math.abs(p.vx) + Math.abs(p.vy) > 1, scale: 1.28,
      accent, outline: withAlpha(accent, 0.55), hatColor: '#0c0e12'
    });

    ctx.save();
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.textAlign = 'center';
    ctx.fillStyle = accent;
    ctx.fillText(p.role.label, p.x, p.y + 16);
    ctx.restore();

    // Aktions-Fortschritt
    if (p.busy > 0) {
      ctx.save();
      const w = 74;
      const ratio = 1 - p.busy / p.busyTotal;
      ctx.fillStyle = 'rgba(4,6,10,0.85)';
      roundRect(ctx, p.x - w / 2, p.y - 74, w, 14, 2);
      ctx.fill();
      ctx.fillStyle = withAlpha(accent, 0.85);
      ctx.fillRect(p.x - w / 2 + 2, p.y - 72, (w - 4) * ratio, 10);
      ctx.fillStyle = PAL.white;
      ctx.font = '8px "IBM Plex Mono", monospace';
      ctx.textAlign = 'center';
      ctx.fillText(p.busyLabel, p.x, p.y - 64);
      ctx.restore();
    }

    if (p.flash > 0) {
      glow(ctx, p.x, p.y - 20, 60, PAL.red, p.flash * 0.4);
    }
  }
}

const PLAYER_LOOK = {
  bouncer: { skin: 2, outfit: 0, hair: 0, height: 1.06, bulk: 1.2 },
  security: { skin: 4, outfit: 1, hair: 5, height: 1.0, bulk: 1.12 }
};

/* ---------------- Tür-Overlay (Abtasten) ---------------- */

function drawDoorOverlay(ctx, game, pulse) {
  const night = game.state.night;
  const guest = night.door;
  if (!guest) return;

  if (night.patdown && !night.patdown.autoResolved) {
    const baseX = guest.x + 54;
    const baseY = guest.y - 76;
    ctx.save();
    ctx.fillStyle = 'rgba(6,8,12,0.9)';
    ctx.strokeStyle = withAlpha(PAL.cyan, 0.5);
    roundRect(ctx, baseX, baseY, 108, 74, 3);
    ctx.fill();
    ctx.stroke();
    ctx.font = '9px "IBM Plex Mono", monospace';
    ctx.fillStyle = PAL.grey;
    ctx.textAlign = 'left';
    ctx.fillText('ABTASTEN', baseX + 8, baseY + 14);
    const keys = ['J', 'K', 'L'];
    ZONES.forEach((zone, i) => {
      const y = baseY + 28 + i * 15;
      const status = night.patdown.zones[zone];
      const hint = night.patdown.hint === zone;
      ctx.fillStyle = status === 'hit' ? PAL.red
        : status === 'clear' ? PAL.green
          : hint ? withAlpha(PAL.amber, 0.6 + pulse * 0.4) : PAL.grey;
      ctx.fillText(`${keys[i]} ${zone.toUpperCase()}`, baseX + 8, y);
      ctx.fillText(status === 'hit' ? 'TREFFER' : status === 'clear' ? 'FREI' : hint ? 'SIGNAL' : '-',
        baseX + 66, y);
    });
    ctx.restore();
  }
}
