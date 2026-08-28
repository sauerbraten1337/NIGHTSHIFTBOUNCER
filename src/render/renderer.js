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
import { drawTitleScene } from './title.js';
import { currentPhase, shiftProgress } from '../systems/nightcycle.js';
import { isSolo } from '../systems/state.js';

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
  /** Anklickbare Abtast-Ringe (Weltkoordinaten) - fürs Zeigen mit der Maus. */
  let zoneHits = [];
  /** Anklickbare Abwehr-Tasten waehrend eines Uebergriffs. */
  let keyHits = [];

  function render(game, dt) {
    const { state } = game;
    time += dt;
    updateEffects(fx, dt);

    const night = state.night;
    const phase = night ? currentPhase(shiftProgress(night)) : { intensity: 0.35, label: 'CLOSED' };
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

    // Titelbildschirm: eigene Schauszene mit Club, Schlange und Türsteher.
    if (!night || state.phase !== 'night') {
      zoneHits = [];
      keyHits = [];
      viewRects = [];
      drawTitleScene(ctx, WORLD.width, WORLD.height, time, pulse);
      vignette(ctx, WORLD.width, WORLD.height, 0.55);
      scanlines(ctx, WORLD.width, WORLD.height, 0.03);
      return;
    }

    const blackout = night.activeEffects.some((e) => e.id === 'blackout');
    const dark = blackout ? 0.7 : 0;
    const views = layoutViews(game);
    viewRects = views;

    const hits = [];
    const keys = [];
    for (const view of views) {
      const drawn = drawStationView(ctx, game, {
        rect: view.rect,
        area: view.area,
        station: view.station,
        queue: view.queue,
        t: time,
        beat,
        pulse,
        dark
      });
      for (const z of drawn?.zones ?? []) {
        hits.push({ ...z, x: z.x + view.rect.x, y: z.y + view.rect.y, role: view.role });
      }
      for (const k of drawn?.keys ?? []) {
        keys.push({ ...k, x: k.x + view.rect.x, y: k.y + view.rect.y, role: view.role });
      }
    }
    zoneHits = hits;
    keyHits = keys;

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
      role: 'bouncer',
      station: night.stations.door,
      queue: night.queue
    };
    const airlockView = {
      id: 'airlock',
      area: 'airlock',
      role: 'security',
      station: night.stations.airlock,
      queue: night.airlockQueue
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

  /** Umkehrung von toWorld: Weltkoordinate -> Bildschirmkoordinate. */
  function toScreen(worldX, worldY) {
    const bounds = canvas.getBoundingClientRect();
    const scale = Math.min(canvas.width / WORLD.width, canvas.height / WORLD.height);
    const dpr = canvas.width / bounds.width;
    const offsetX = (canvas.width - WORLD.width * scale) / 2;
    const offsetY = (canvas.height - WORLD.height * scale) / 2;
    return {
      x: bounds.left + (worldX * scale + offsetX) / dpr,
      y: bounds.top + (worldY * scale + offsetY) / dpr
    };
  }

  return {
    render,
    resize,
    fx,
    toWorld,
    toScreen,
    get views() { return viewRects; },
    get zoneHits() { return zoneHits; },
    get keyHits() { return keyHits; },
    get beat() { return beatTime % 1; }
  };
}
