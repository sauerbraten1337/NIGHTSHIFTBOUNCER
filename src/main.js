/**
 * NULLWERK — NIGHTSHIFT: BOUNCER CO-OP
 * Einstiegspunkt: verdrahtet Systeme, Rendering, UI, Audio und den Spielfluss.
 */

import { createRng } from './core/rng.js';
import { createBus } from './core/bus.js';
import { createInput } from './core/input.js';
import { createLoop } from './core/loop.js';
import { createAudio } from './core/audio.js';

import { createInitialState, rank, pushLog } from './systems/state.js';
import { createPlayers, updatePlayers } from './systems/coop.js';
import { startNight, updateNight, pickNightEvent, currentPhase } from './systems/nightcycle.js';
import { saveGame, loadGame } from './systems/save.js';
import { checkRankUp } from './systems/progression.js';

import { createRenderer } from './render/renderer.js';
import { burst } from './render/effects.js';
import { LAYOUT } from './render/layout.js';
import { createHud } from './ui/hud.js';
import { createScreens } from './ui/screens.js';

const canvas = document.getElementById('scene');
const hintEl = document.getElementById('hint');

const game = {
  state: createInitialState(),
  rng: createRng(),
  bus: createBus(),
  players: createPlayers(),
  paused: false,
  save() {
    return saveGame(this.state);
  }
};

const input = createInput(window);
const audio = createAudio();
const renderer = createRenderer(canvas);
const hud = createHud(game);
const screens = createScreens(game);

let pendingEvent = null;

/* ---------------- Spielfluss ---------------- */

function goMenu() {
  game.state.phase = 'menu';
  hud.hide();
  hintEl.classList.add('hidden');
  screens.menu({
    onNew: () => {
      game.state = createInitialState();
      game.players = createPlayers();
      goBriefing();
    },
    onContinue: () => {
      loadGame(game.state);
      goBriefing();
    }
  });
}

function goBriefing() {
  game.state.phase = 'briefing';
  hud.hide();
  hintEl.classList.add('hidden');
  pendingEvent = pickNightEvent(game.rng, game.state);
  screens.briefing(pendingEvent, beginNight);
}

function beginNight() {
  const artist = game.state.bookedArtist;
  game.state.bookedArtist = null;
  game.players = createPlayers();
  startNight(game, pendingEvent, artist);
  screens.hide();
  hud.show();
  hintEl.classList.remove('hidden');
  audio.start();
  audio.setIntensity(0.3);
}

function goReport() {
  hud.hide();
  hintEl.classList.add('hidden');
  screens.report(() => screens.shop(goBriefing));
}

game.bus.on('nightEnd', () => {
  const before = rank(game.state).level;
  const up = checkRankUp(game.state, before);
  if (up) pushLog(game.state, `Aufstieg: ${up.label}`, 'good');
  game.save();
  audio.setIntensity(0.2);
  goReport();
});

game.bus.on('sfx', (name) => audio.sfx(name));

game.bus.on('upgradeBought', (result) => {
  if (result.tierChanged) {
    pushLog(game.state, `Club-Stufe ${result.tier} erreicht`, 'good');
  }
});

game.bus.on('randomEvent', (event) => {
  if (event.id === 'blackout') burst(renderer.fx, LAYOUT.door.x, LAYOUT.door.y, '#ff2f3c', 26);
});

game.bus.on('doorGuest', () => {
  // kurzer Funk-Piepser, wenn der nächste Gast vorrückt
  audio.sfx('radio');
});

/* ---------------- Loop ---------------- */

const loop = createLoop({
  update(dt) {
    if (game.state.phase !== 'night' || game.paused) {
      input.endFrame();
      return;
    }
    updatePlayers(game, dt, input);
    updateNight(game, dt);
    const phase = currentPhase(game.state.night.clock);
    const load = Math.min(1, game.state.night.queue.length / 14);
    audio.setIntensity(phase.intensity * 0.75 + load * 0.25);
    input.endFrame();
  },
  render(dt) {
    renderer.render(game, dt);
    if (game.state.phase === 'night') hud.update();
  }
});

/* ---------------- Systemtasten ---------------- */

window.addEventListener('keydown', (e) => {
  if (e.code === 'KeyP' && game.state.phase === 'night') {
    togglePause();
  } else if (e.code === 'KeyM') {
    const muted = audio.toggleMute();
    hintEl.style.opacity = muted ? '0.4' : '1';
  } else if (e.code === 'KeyH') {
    hintEl.classList.toggle('hidden');
  }
});

function togglePause() {
  game.paused = !game.paused;
  if (game.paused) {
    screens.pause(togglePause, () => {
      game.paused = false;
      game.state.night.clock = 300;
      screens.hide();
    });
  } else {
    screens.hide();
  }
}

// Ton braucht eine Nutzergeste.
window.addEventListener('pointerdown', () => audio.start(), { once: true });

loop.start();
goMenu();

// Für Debug/Tests im Browser erreichbar.
window.NULLWERK = game;
