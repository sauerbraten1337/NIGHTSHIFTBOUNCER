/**
 * Night Report: die Bilanz nach jeder Nacht.
 *
 * Links die Zahlen der Schicht, rechts der eigene Türsteher, der auf das
 * Ergebnis reagiert: bei einer guten Nacht jubelt er im Konfettiregen, bei
 * einer schlechten steht er im Nieselregen und lässt die Schultern hängen.
 * Sterne, Balken und Zahlen laufen beim Öffnen des Bildschirms an.
 */

import { escapeHtml } from './hud.js';
import { clubTier, rank } from '../systems/state.js';
import { rankProgress } from '../systems/progression.js';
import { REPORT_QUOTES } from '../data/dialogue.js';
import { characterLook, accentColor, normalizeCharacter } from '../systems/character.js';
import { drawFigure } from '../render/figure.js';
import { PAL, withAlpha } from '../render/palette.js';

/** Wie die Nacht gelaufen ist - Ton des ganzen Bildschirms. */
const GRADES = [
  { min: 5, id: 'legend', label: 'LEGENDÄRE NACHT', color: PAL.green, mood: 'happy', pose: 'cheer',
    line: 'Das war die beste Nacht seit Langem. Keiner ist durchgerutscht.' },
  { min: 4, id: 'strong', label: 'STARKE NACHT', color: PAL.cyan, mood: 'proud', pose: 'cheer',
    line: 'Sauber gearbeitet. Der Chef wird morgen nichts zu meckern haben.' },
  { min: 3, id: 'ok', label: 'SOLIDE NACHT', color: PAL.amber, mood: 'polite', pose: 'idle',
    line: 'Ging klar. Ein paar Sachen hätte ich früher sehen müssen.' },
  { min: 2, id: 'weak', label: 'ZÄHE NACHT', color: PAL.amber, mood: 'tired', pose: 'idle',
    line: 'Lange Schicht. Da war zu viel Durcheinander an der Tür.' },
  { min: 0, id: 'bad', label: 'MIESE NACHT', color: PAL.red, mood: 'sad', pose: 'slump',
    line: 'Das war nichts. Morgen muss ich das wieder geradebiegen.' }
];

function gradeFor(rating) {
  return GRADES.find((g) => rating >= g.min) ?? GRADES[GRADES.length - 1];
}

export function renderReport(game, onContinue, onMenu = null) {
  const { state } = game;
  const night = state.night;
  const s = night.stats;
  const rating = night.rating ?? 0;
  const grade = gradeFor(rating);
  const rep = Math.round((night.repDelta ?? 0) * 10) / 10;
  const netto = s.revenue - s.artistFee;
  const prog = rankProgress(state);
  const decisions = s.correct + s.mistakes;
  const accuracy = decisions > 0 ? s.correct / decisions : 0;
  const flow = s.arrived > 0 ? 1 - s.left / s.arrived : 1;
  const character = normalizeCharacter(state.character);

  const wrap = document.createElement('div');
  wrap.className = `report grade-${grade.id}`;
  wrap.style.setProperty('--grade', grade.color);
  wrap.innerHTML = `
    <div class="rep-top">
      <div class="rep-kicker">NIGHT ${String(state.nightIndex).padStart(2, '0')} ·
        ${escapeHtml(night.event.label)} · ${escapeHtml(clubTier(state).label)}</div>
      <h1 class="rep-title">NIGHT COMPLETE</h1>
      <div class="rep-stars" aria-label="${rating} von 5 Sternen">
        ${Array.from({ length: 5 }, (_, i) => `
          <span class="rep-star ${i < rating ? 'on' : ''}" style="--d:${i * 130}ms">★</span>`).join('')}
      </div>
      <div class="rep-grade">${escapeHtml(grade.label)}</div>
    </div>

    <div class="rep-body">
      <section class="rep-left">
        <div class="rep-hero">
          ${hero('NETTO', `€${fmt(netto)}`, netto >= 0 ? 'good' : 'bad')}
          ${hero('RUF', `${rep >= 0 ? '+' : ''}${rep}`, rep >= 0 ? 'good' : 'bad')}
          ${hero('ERFAHRUNG', `+${night.xpGained} XP`, 'cyan')}
        </div>

        <div class="rep-bars">
          ${bar('TREFFERQUOTE', accuracy, `${s.correct}/${decisions || 0}`)}
          ${bar('ANDRANG GEHALTEN', flow, `${s.left} abgesprungen`)}
          ${bar('RANG · ' + rank(state).label, prog.next ? prog.ratio : 1,
            prog.next ? `→ ${prog.next.label}` : 'MAX')}
        </div>

        <h2 class="sec">DIE NACHT IN ZAHLEN</h2>
        <div class="rep-tiles">
          ${tile('GÄSTE', s.arrived)}
          ${tile('EINLASS', s.admitted, 'good')}
          ${tile('ABGEWIESEN', s.rejected)}
          ${tile('ABGESPRUNGEN', s.left, s.left > s.admitted * 0.3 ? 'bad' : '')}
          ${tile('UMSATZ', s.revenue, 'good', '€')}
          ${tile('VORFÄLLE', s.incidents, s.incidents > 0 ? 'bad' : 'good')}
          ${tile('VIPS', s.vips)}
          ${tile('GEFUNDEN', s.findings ?? 0, (s.findings ?? 0) > 0 ? 'good' : '')}
        </div>

        <h2 class="sec">EIGENE BEFUNDE</h2>
        ${kv('Gefundene Unregelmäßigkeiten', s.findings ?? 0, (s.findings ?? 0) > 0 ? 'good' : '')}
        ${kv('Zu Unrecht beanstandet', s.falseAlarms ?? 0, (s.falseAlarms ?? 0) > 0 ? 'bad' : '')}
        ${kv('Übersehen', s.overlooked ?? 0, (s.overlooked ?? 0) > 0 ? 'bad' : '')}

        ${s.attacks ? `
        <h2 class="sec">ÜBERGRIFFE</h2>
        ${kv('Auf dich losgegangen', s.attacks)}
        ${kv('Abgewehrt', s.defended ?? 0, (s.defended ?? 0) > 0 ? 'good' : '')}
        ${kv('Erwischt worden', s.attacksLanded ?? 0, (s.attacksLanded ?? 0) > 0 ? 'bad' : '')}` : ''}

        <h2 class="sec">BILANZ</h2>
        ${kv('Eintritt', `€${fmt(s.entry)}`, 'good')}
        ${kv('Bar & VIP', `€${fmt(s.bar)}`, 'good')}
        ${kv('Prämie für Befunde', `€${fmt(s.findingPay ?? 0)}`, (s.findingPay ?? 0) > 0 ? 'good' : '')}
        ${s.defensePay ? kv('Prämie für Abwehr', `€${fmt(s.defensePay)}`, 'good') : ''}
        ${s.fines ? kv('Bußgelder & Schäden', `−€${fmt(s.fines)}`, 'bad') : ''}
        ${s.artistFee ? kv('Gage', `−€${fmt(s.artistFee)}`, 'bad') : ''}
        ${kv('Netto', `€${fmt(netto)}`, netto >= 0 ? 'good' : 'bad')}
        ${night.artist ? kv(`Act: ${night.artist.name}`,
          night.artistPlaying ? 'hat gespielt' : night.artistMissed ? 'nie eingelassen' : 'abgewiesen',
          night.artistPlaying ? 'good' : 'bad') : ''}

        <p class="rep-quote">"${escapeHtml(quote(state))}"</p>
      </section>

      <aside class="rep-right">
        <div class="rep-stagewrap">
          <canvas id="rep-canvas" width="520" height="520"></canvas>
          <div class="rep-bubble">${escapeHtml(grade.line)}</div>
        </div>
        <div class="rep-who">
          <b>${escapeHtml(character.name)}</b>
          <i>${escapeHtml(rank(state).label)} · SCHICHT ${String(state.nightIndex).padStart(2, '0')}</i>
        </div>
      </aside>
    </div>

    <div class="btn-row">
      <button class="btn primary" id="report-next">FEIERABEND — INS BÜRO</button>
      ${onMenu ? '<button class="btn ghost" id="report-menu">ZURÜCK ZUM HAUPTMENÜ</button>' : ''}
    </div>
  `;

  wrap.querySelector('#report-next').addEventListener('click', onContinue);
  // Nach der Nacht ist Schluss erlaubt: der Stand ist gespeichert.
  wrap.querySelector('#report-menu')?.addEventListener('click', () => onMenu());

  countUp(wrap);
  requestAnimationFrame(() => wrap.classList.add('run'));
  startStage(wrap.querySelector('#rep-canvas'), { grade, rating, character });

  return wrap;
}

/* ---------- Bausteine ---------- */

function hero(k, v, cls = '') {
  return `<div class="rep-hero-cell ${cls}"><span class="k">${escapeHtml(k)}</span>
    <span class="v">${escapeHtml(String(v))}</span></div>`;
}

function bar(label, ratio, note) {
  const pct = Math.round(Math.max(0, Math.min(1, ratio)) * 100);
  return `
    <div class="rep-bar">
      <div class="rep-bar-head"><span>${escapeHtml(label)}</span><b>${pct}%</b></div>
      <div class="rep-bar-track"><span style="--w:${pct}%"></span></div>
      <div class="rep-bar-note">${escapeHtml(String(note))}</div>
    </div>`;
}

function tile(k, v, cls = '', prefix = '') {
  return `<div class="rep-tile"><span class="k">${escapeHtml(k)}</span>
    <span class="v ${cls}" data-count="${Math.round(Number(v) || 0)}" data-prefix="${prefix}">${prefix}0</span></div>`;
}

function kv(k, v, cls = '') {
  return `<div class="kv"><span>${escapeHtml(k)}</span><span class="v ${cls}">${escapeHtml(String(v))}</span></div>`;
}

function fmt(value) {
  return Math.round(value).toLocaleString('de-DE');
}

function quote(state) {
  const idx = (state.nightIndex * 7) % REPORT_QUOTES.length;
  return REPORT_QUOTES[idx];
}

/** Zahlen zählen sich beim Öffnen hoch - das Ergebnis soll ankommen. */
function countUp(wrap) {
  const cells = [...wrap.querySelectorAll('[data-count]')];
  const start = performance.now();
  const dur = 850;

  function step(now) {
    if (!wrap.isConnected) return;
    const p = Math.min(1, (now - start) / dur);
    const eased = 1 - Math.pow(1 - p, 3);
    for (const cell of cells) {
      const target = Number(cell.dataset.count) || 0;
      const value = Math.round(target * eased);
      cell.textContent = `${cell.dataset.prefix ?? ''}${value.toLocaleString('de-DE')}`;
    }
    if (p < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

/* ---------- Die Bühne rechts ---------- */

/**
 * Der eigene Charakter reagiert: Haltung, Gesicht, Licht und Partikel
 * hängen alle an der Sternewertung.
 */
function startStage(canvas, { grade, rating, character }) {
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const w = canvas.width;
  const h = canvas.height;
  const floorY = h * 0.9;
  const good = rating >= 4;
  const bad = rating <= 1;
  const look = characterLook(character);
  const accent = accentColor(character);

  // Konfetti bei guter Nacht, Regen bei schlechter.
  const bits = Array.from({ length: good ? 90 : bad ? 120 : 26 }, (_, i) => ({
    x: Math.random() * w,
    y: Math.random() * h,
    vy: bad ? 420 + Math.random() * 260 : 60 + Math.random() * 110,
    vx: bad ? -60 : (Math.random() - 0.5) * 60,
    size: bad ? 1 : 3 + Math.random() * 5,
    spin: Math.random() * 6.28,
    color: [PAL.amber, PAL.cyan, PAL.green, PAL.red, PAL.white][i % 5]
  }));

  let t = 0;
  let last = performance.now();

  function frame(now) {
    if (!canvas.isConnected) return;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    t += dt;
    draw(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  function draw(dt) {
    ctx.clearRect(0, 0, w, h);

    const bg = ctx.createLinearGradient(0, 0, 0, h);
    bg.addColorStop(0, '#0a0d14');
    bg.addColorStop(1, '#05070b');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    // Lichtkegel in der Farbe der Bewertung
    const pulse = 0.5 + Math.sin(t * 2.2) * 0.5;
    const cone = ctx.createRadialGradient(w / 2, h * 0.05, 8, w / 2, floorY, h * 0.95);
    cone.addColorStop(0, withAlpha(grade.color, 0.24 + pulse * 0.1));
    cone.addColorStop(0.6, withAlpha(grade.color, 0.06));
    cone.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = cone;
    ctx.fillRect(0, 0, w, h);

    // Ringe auf dem Boden
    for (let i = 0; i < 3; i++) {
      const p = ((t * (good ? 0.6 : 0.25) + i / 3) % 1);
      ctx.strokeStyle = withAlpha(grade.color, (1 - p) * 0.35);
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(w / 2, floorY, 40 + p * w * 0.42, 8 + p * h * 0.05, 0, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Sterne als Aura über dem Kopf, einer je erreichtem Stern
    for (let i = 0; i < rating; i++) {
      const a = (i / Math.max(1, rating)) * Math.PI * 2 + t * (good ? 1.1 : 0.3);
      const rx = w * 0.19;
      const ry = h * 0.045;
      star(ctx, w / 2 + Math.cos(a) * rx, h * 0.2 + Math.sin(a) * ry,
        9 + Math.sin(t * 3 + i) * 2, withAlpha(PAL.amber, 0.85));
    }

    drawFigure(ctx, {
      x: w / 2,
      y: floorY,
      h: h * 0.72,
      look,
      personality: grade.mood,
      pose: grade.pose,
      t,
      accent
    });

    // Partikel: Konfetti fällt, Regen stürzt.
    for (const b of bits) {
      b.y += b.vy * dt;
      b.x += b.vx * dt;
      if (b.y > h + 10) { b.y = -10; b.x = Math.random() * w; }
      if (b.x < -10) b.x = w + 10;
      if (bad) {
        ctx.strokeStyle = 'rgba(150,180,210,0.25)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(b.x, b.y);
        ctx.lineTo(b.x - 4, b.y + 14);
        ctx.stroke();
      } else {
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(b.spin + t * 3);
        ctx.fillStyle = withAlpha(b.color, 0.85);
        ctx.fillRect(-b.size / 2, -b.size / 4, b.size, b.size / 2);
        ctx.restore();
      }
    }

    // Boden und Vignette
    const floor = ctx.createLinearGradient(0, floorY - 10, 0, h);
    floor.addColorStop(0, 'rgba(0,0,0,0)');
    floor.addColorStop(1, 'rgba(0,0,0,0.75)');
    ctx.fillStyle = floor;
    ctx.fillRect(0, floorY - 10, w, h - floorY + 10);
  }
}

function star(ctx, x, y, r, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = color;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 === 0 ? r : r * 0.44;
    const a = (Math.PI / 5) * i - Math.PI / 2;
    ctx[i === 0 ? 'moveTo' : 'lineTo'](Math.cos(a) * rad, Math.sin(a) * rad);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}
