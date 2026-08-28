/**
 * Charaktereditor: der eigene Türsteher.
 *
 * Links die Figur in Lebensgrösse auf dem Podest, rechts die Regler.
 * Jede Änderung ist sofort an der Figur zu sehen - deshalb läuft hier eine
 * eigene kleine Zeichenschleife, die stoppt, sobald der Bildschirm weg ist.
 */

import { escapeHtml } from './hud.js';
import { drawFigure } from '../render/figure.js';
import { PAL, SKIN, HAIR, OUTFIT, withAlpha } from '../render/palette.js';
import {
  ACCENTS, HAIR_STYLES, BUILDS,
  createCharacter, normalizeCharacter, characterLook, accentColor
} from '../systems/character.js';

/**
 * opts: { title, subtitle, confirmLabel, onDone(character), onBack, backLabel }
 */
export function renderCharacterEditor(game, opts = {}) {
  const draft = normalizeCharacter(game.state.character);

  const wrap = document.createElement('div');
  wrap.className = 'chared';
  wrap.innerHTML = `
    <div class="chared-head">
      <h1 class="title">${escapeHtml(opts.title ?? 'DEIN TÜRSTEHER')}</h1>
      <div class="subtitle">${escapeHtml(opts.subtitle ?? 'WER STEHT HEUTE NACHT AN DER TÜR?')}</div>
    </div>

    <div class="chared-body">
      <div class="chared-stage">
        <canvas id="chared-canvas" width="440" height="560"></canvas>
        <div class="chared-plate"><span id="chared-plate-name"></span><i>TÜRSTEHER · NULLWERK</i></div>
      </div>

      <div class="chared-controls" id="chared-controls"></div>
    </div>

    <div class="btn-row chared-actions">
      <button class="btn primary" id="chared-done">${escapeHtml(opts.confirmLabel ?? 'SO SIEHT ER AUS')}</button>
      <button class="btn ghost" id="chared-random">WÜRFELN</button>
      ${opts.onBack ? `<button class="btn ghost" id="chared-back">${escapeHtml(opts.backLabel ?? 'ZURÜCK')}</button>` : ''}
    </div>
  `;

  const controls = wrap.querySelector('#chared-controls');
  const canvas = wrap.querySelector('#chared-canvas');
  const ctx = canvas.getContext('2d');
  const plate = wrap.querySelector('#chared-plate-name');

  buildControls();

  function buildControls() {
    controls.innerHTML = `
      <label class="ce-group">
        <span class="ce-label">NAME</span>
        <input class="ce-name" id="ce-name" maxlength="14" value="${escapeHtml(draft.name)}"
               autocomplete="off" spellcheck="false" />
      </label>

      ${swatchGroup('HAUTTON', 'skin', SKIN.map((c, i) => ({ value: i, color: c })), draft.skin)}
      ${swatchGroup('HAARFARBE', 'hair', HAIR.map((c, i) => ({ value: i, color: c })), draft.hair)}
      ${chipGroup('FRISUR', 'hairStyle', HAIR_STYLES.map((s) => ({ value: s.id, label: s.label })), draft.hairStyle)}
      ${swatchGroup('JACKE', 'outfit', OUTFIT.map((c, i) => ({ value: i, color: c })), draft.outfit)}
      ${chipGroup('STATUR', 'build', BUILDS.map((b) => ({ value: b.id, label: b.label })), draft.build)}
      ${chipGroup('BART', 'beard', [{ value: 'no', label: 'OHNE' }, { value: 'yes', label: 'MIT' }],
        draft.beard ? 'yes' : 'no')}
      ${swatchGroup('STREIFEN', 'accent',
        ACCENTS.map((a) => ({ value: a.id, color: a.color, label: a.label })), draft.accent)}
    `;
    wire();
  }

  function swatchGroup(label, key, entries, current) {
    return `
      <div class="ce-group">
        <span class="ce-label">${escapeHtml(label)}</span>
        <div class="ce-swatches">
          ${entries.map((e) => `
            <button class="ce-swatch ${String(e.value) === String(current) ? 'on' : ''}"
                    data-key="${key}" data-value="${escapeHtml(String(e.value))}"
                    title="${escapeHtml(e.label ?? '')}"
                    style="${e.color ? `background:${e.color}` : ''}">
              ${e.color ? '' : '<span class="ce-none">✕</span>'}
            </button>`).join('')}
        </div>
      </div>`;
  }

  function chipGroup(label, key, entries, current) {
    return `
      <div class="ce-group">
        <span class="ce-label">${escapeHtml(label)}</span>
        <div class="ce-chips">
          ${entries.map((e) => `
            <button class="ce-chip ${String(e.value) === String(current) ? 'on' : ''}"
                    data-key="${key}" data-value="${escapeHtml(String(e.value))}">
              ${escapeHtml(e.label)}
            </button>`).join('')}
        </div>
      </div>`;
  }

  function wire() {
    const name = controls.querySelector('#ce-name');
    name.addEventListener('keydown', (e) => e.stopPropagation());
    name.addEventListener('input', () => {
      draft.name = name.value.toUpperCase();
      name.value = draft.name;
    });

    for (const btn of controls.querySelectorAll('[data-key]')) {
      btn.addEventListener('click', () => {
        apply(btn.dataset.key, btn.dataset.value);
        // Nur die Gruppe umschalten, in der geklickt wurde - der Rest bleibt stehen.
        const group = btn.closest('.ce-group');
        group.querySelectorAll('[data-key]').forEach((b) => b.classList.remove('on'));
        btn.classList.add('on');
        game.bus?.emit('sfx', 'ok');
      });
    }
  }

  function apply(key, value) {
    if (key === 'beard') draft.beard = value === 'yes';
    else if (key === 'build' || key === 'accent') draft[key] = value;
    else draft[key] = Number(value);
  }

  wrap.querySelector('#chared-random').addEventListener('click', () => {
    Object.assign(draft, createCharacter(), { name: draft.name, created: draft.created });
    buildControls();
  });

  wrap.querySelector('#chared-done').addEventListener('click', () => {
    const saved = normalizeCharacter({ ...draft, created: true });
    game.state.character = saved;
    game.save?.();
    opts.onDone?.(saved);
  });

  wrap.querySelector('#chared-back')?.addEventListener('click', () => opts.onBack?.());

  /* ---------- Vorschau ---------- */

  let t = 0;
  let last = performance.now();

  function frame(now) {
    if (!canvas.isConnected) return;          // Bildschirm gewechselt: Schleife endet.
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    t += dt;
    draw();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  function draw() {
    const w = canvas.width;
    const h = canvas.height;
    plate.textContent = draft.name || '—';

    ctx.clearRect(0, 0, w, h);
    const bg = ctx.createLinearGradient(0, 0, 0, h);
    bg.addColorStop(0, '#0b0e15');
    bg.addColorStop(1, '#05070b');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    // Scheinwerfer von oben auf das Podest
    const cone = ctx.createRadialGradient(w / 2, h * 0.1, 10, w / 2, h * 0.92, h * 0.9);
    cone.addColorStop(0, withAlpha(PAL.cyan, 0.16));
    cone.addColorStop(0.55, withAlpha(PAL.red, 0.06));
    cone.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = cone;
    ctx.fillRect(0, 0, w, h);

    // Umkleide-Raster im Hintergrund
    ctx.strokeStyle = withAlpha(PAL.line, 0.35);
    ctx.lineWidth = 1;
    for (let gx = 20.5; gx < w; gx += 40) {
      ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h * 0.86); ctx.stroke();
    }
    for (let gy = 20.5; gy < h * 0.86; gy += 40) {
      ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke();
    }

    // Podest
    const floorY = h * 0.88;
    ctx.fillStyle = '#11151d';
    ctx.beginPath();
    ctx.ellipse(w / 2, floorY, w * 0.34, h * 0.035, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = withAlpha(PAL.cyan, 0.4);
    ctx.lineWidth = 2;
    ctx.stroke();

    drawFigure(ctx, {
      x: w / 2,
      y: floorY,
      h: h * 0.74,
      look: characterLook(draft),
      personality: 'polite',
      t,
      accent: accentColor(draft),
      pose: 'idle'
    });

    // Massband am Rand - Umkleidekabinen-Optik
    ctx.strokeStyle = withAlpha(PAL.grey, 0.35);
    ctx.fillStyle = withAlpha(PAL.grey, 0.5);
    ctx.font = '9px "IBM Plex Mono", monospace';
    for (let i = 0; i <= 8; i++) {
      const y = floorY - (i / 8) * h * 0.76;
      const long = i % 2 === 0;
      ctx.beginPath();
      ctx.moveTo(8, y);
      ctx.lineTo(long ? 26 : 18, y);
      ctx.stroke();
      if (long) ctx.fillText(`${(i * 25).toString().padStart(3, '0')}`, 30, y + 3);
    }
  }

  return wrap;
}
