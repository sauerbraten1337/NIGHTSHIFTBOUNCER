/**
 * Renderer: baut das Bild aus einer oder zwei Stationsansichten auf.
 *
 *   solo / online  -> eine Ansicht (die eigene Station), Vollbild
 *   lokaler Koop   -> Splitscreen: links Tür (draussen), rechts Schleuse (innen)
 *
 * Dazu die Club-Übersicht als kleine Karte, Nebel, Vignette und Scanlines.
 */

import { WORLD } from './layout.js';
import { PAL } from './palette.js';
import { drawStationView } from './scene.js';
import {
  createEffects, updateEffects, drawFog, drawDust, drawSparks, scanlines, vignette
} from './effects.js';
import { currentPhase } from '../systems/nightcycle.js';
import { isSolo } from '../systems/state.js';
import { AREAS } from '../data/config.js';

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d');
  const fx = createEffects();
  let beatTime = 0;
  let time = 0;

  function resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const rect = canvas.getBoundingClientRect();
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));
  }

  window.addEventListener('resize', resize);
  resize();

  /** Rechtecke der aktuellen Ansichten (Weltkoordinaten) - fürs UI-Layout. */
  let viewRects = [];

  function render(game, dt) {
    const { state } = game;
    time += dt;
    updateEffects(fx, dt);

    const night = state.night;
    const phase = night ? currentPhase(night.clock) : { intensity: 0.35, label: 'CLOSED' };
    beatTime += dt * (128 / 60) * (0.8 + phase.intensity * 0.4);
    const beat = beatTime % 1;
    const pulse = Math.pow(1 - beat, 3);

    const scale = Math.min(canvas.width / WORLD.width, canvas.height / WORLD.height);
    const offsetX = (canvas.width - WORLD.width * scale) / 2;
    const offsetY = (canvas.height - WORLD.height * scale) / 2;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = PAL.night;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(scale, 0, 0, scale, offsetX, offsetY);

    if (!night) {
      ctx.restore?.();
      return;
    }

    const blackout = night.activeEffects.some((e) => e.id === 'blackout');
    const dark = blackout ? 0.7 : 0;
    const views = layoutViews(game);
    viewRects = views;

    for (const view of views) {
      drawStationView(ctx, game, {
        rect: view.rect,
        area: view.area,
        station: view.station,
        queue: view.queue,
        t: time,
        beat,
        pulse,
        dark,
        label: view.label,
        sub: view.sub,
        accent: view.accent
      });
    }

    // Trennlinie im Splitscreen
    if (views.length === 2) {
      ctx.fillStyle = '#05070b';
      ctx.fillRect(views[0].rect.w - 1, 0, 4, WORLD.height);
    }

    drawFog(ctx, fx, 0.45 + phase.intensity * 0.4);
    drawDust(ctx, fx);
    drawSparks(ctx, fx);
    vignette(ctx, WORLD.width, WORLD.height, blackout ? 0.9 : 0.5);
    scanlines(ctx, WORLD.width, WORLD.height, 0.03);
  }

  /** Welche Ansichten werden gezeigt? */
  function layoutViews(game) {
    const { state } = game;
    const night = state.night;
    const solo = isSolo(state);
    const localCoop = state.mode === 'local';

    const doorView = {
      id: 'outside',
      area: 'outside',
      station: night.stations.door,
      queue: night.queue,
      label: `${AREAS.outside.label} · ${AREAS.outside.sub}`,
      accent: PAL.red
    };
    const airlockView = {
      id: 'airlock',
      area: 'airlock',
      station: night.stations.airlock,
      queue: night.airlockQueue,
      label: `${AREAS.airlock.label} · ${AREAS.airlock.sub}`,
      accent: PAL.cyan
    };

    if (solo) {
      doorView.rect = { x: 0, y: 0, w: WORLD.width, h: WORLD.height };
      return [doorView];
    }
    if (localCoop) {
      const half = Math.floor(WORLD.width / 2);
      doorView.rect = { x: 0, y: 0, w: half, h: WORLD.height };
      airlockView.rect = { x: half + 3, y: 0, w: WORLD.width - half - 3, h: WORLD.height };
      return [doorView, airlockView];
    }
    // Online: jeder sieht nur seine eigene Station.
    const own = game.localRole === 'security' ? airlockView : doorView;
    own.rect = { x: 0, y: 0, w: WORLD.width, h: WORLD.height };
    return [own];
  }

  /** Rechnet Bildschirmkoordinaten in Weltkoordinaten um (für Mausklicks). */
  function toWorld(clientX, clientY) {
    const bounds = canvas.getBoundingClientRect();
    const scale = Math.min(canvas.width / WORLD.width, canvas.height / WORLD.height);
    const dpr = canvas.width / bounds.width;
    const offsetX = (canvas.width - WORLD.width * scale) / 2;
    const offsetY = (canvas.height - WORLD.height * scale) / 2;
    return {
      x: ((clientX - bounds.left) * dpr - offsetX) / scale,
      y: ((clientY - bounds.top) * dpr - offsetY) / scale
    };
  }

  return {
    render,
    resize,
    fx,
    toWorld,
    get views() { return viewRects; },
    get beat() { return beatTime % 1; }
  };
}
