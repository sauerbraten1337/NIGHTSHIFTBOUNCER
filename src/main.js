/**
 * NULLWERK — NIGHTSHIFT: BOUNCER CO-OP
 *
 * Einstiegspunkt: Spielfluss, Modi (Solo / lokaler Koop / Online-Koop),
 * Eingaben, Rendering, Audio.
 *
 * Online-Modell: Der Host simuliert, der Gast schickt Aktionen und rendert
 * Schnappschüsse. Alle Aktionen laufen durch dieselbe Funktion `act()`.
 */

import { createRng } from './core/rng.js';
import { createBus } from './core/bus.js';
import { createInput } from './core/input.js';
import { createLoop } from './core/loop.js';
import { createAudio } from './core/audio.js';

import { createInitialState, rank, pushLog, isSolo } from './systems/state.js';
import { createPlayers, updatePlayers, tryAction, stationOf } from './systems/coop.js';
import { startNight, updateNight, pickNightEvent, currentPhase, shiftProgress, endNight } from './systems/nightcycle.js';
import { saveGame, loadGame } from './systems/save.js';
import { checkRankUp } from './systems/progression.js';
import { rolesFor } from './data/config.js';

import { createRenderer } from './render/renderer.js';
import { createHud } from './ui/hud.js';
import { createScreens } from './ui/screens.js';
import { createIdCard } from './ui/idcard.js';
import { createItemTray } from './ui/itemtray.js';
import { createRulebook } from './ui/rulebook.js';
import { createNet, serializeState, applySnapshot } from './net/net.js';

const canvas = document.getElementById('scene');

/* ---------------- Spielobjekt ---------------- */

const game = {
  state: createInitialState('solo'),
  rng: createRng(),
  bus: createBus(),
  players: createPlayers('solo'),
  paused: false,
  localRole: 'bouncer',
  net: null,
  netRole: null,          // null | 'host' | 'guest'
  tutorialWanted: true,

  get isGuest() { return this.netRole === 'guest'; },
  get isHost() { return this.netRole === 'host'; },

  /** Steuert dieser Client die Rolle? */
  controls(roleId) {
    if (this.state.mode !== 'online') return true;
    return this.netRole === 'guest' ? roleId === 'security' : roleId === 'bouncer';
  },

  /** Welche Station zeigt das Befund-Panel? Im Splitscreen die rechte (Schleuse). */
  get dossierRole() {
    if (this.state.mode === 'local') return 'security';
    if (this.state.mode === 'online') return this.localRole;
    return 'bouncer';
  },

  roleById(id) {
    return rolesFor(this.state.mode).find((r) => r.id === id) ?? rolesFor(this.state.mode)[0];
  },

  /** Station einer Rolle - funktioniert auch auf dem Schnappschuss des Gastes. */
  stationFor(roleId) {
    const night = this.state.night;
    if (!night) return null;
    if (isSolo(this.state)) return night.stations.door;
    return roleId === 'security' ? night.stations.airlock : night.stations.door;
  },

  /** Zentrale Aktionsschleuse: lokal ausführen oder zum Host schicken. */
  act(roleId, code, payload = {}) {
    if (!this.controls(roleId)) return;
    if (this.isGuest) {
      this.net.sendAction(roleId, code, payload);
      return;
    }
    const player = this.players.find((p) => p.id === roleId);
    if (player) tryAction(this, player, code, payload);
  },

  save() {
    return this.isGuest ? false : saveGame(this.state);
  }
};

const input = createInput(window);
const audio = createAudio();
const renderer = createRenderer(canvas);
const hud = createHud(game);
const screens = createScreens(game);
const idcard = createIdCard(game, { roleId: 'bouncer' });
const itemTray = createItemTray(game, { roleId: 'security' });
const rulebook = createRulebook(game);
game.net = createNet(game.bus);

let pendingEvent = null;
let lobbyUi = null;
let snapshotTimer = 0;

/* ---------------- Modus / Spielfluss ---------------- */

function applyMode(mode) {
  game.state.mode = mode;
  game.players = createPlayers(mode);
  game.localRole = game.netRole === 'guest' ? 'security' : 'bouncer';
  for (const p of game.players) p.remote = !game.controls(p.id);
  idcard.roleId = game.localRole;
  // Der Kontrolltisch gehört zu der Station, an der abgetastet wird.
  itemTray.roleId = isSolo(game.state) ? 'bouncer' : 'security';
  hud.rebuild();
}

function goMenu() {
  game.state.phase = 'menu';
  game.netRole = null;
  hud.hide();
  screens.menu({
    onStart: (mode, tutorial) => {
      game.tutorialWanted = tutorial;
      const carry = game.state;
      game.state = createInitialState(mode);
      game.state.tutorialDone = carry.tutorialDone && false;
      applyMode(mode);
      if (mode === 'online') goLobby();
      else goBriefing();
    },
    onContinue: (mode, tutorial) => {
      game.tutorialWanted = tutorial;
      game.state = createInitialState(mode);
      loadGame(game.state);
      game.state.mode = mode;
      applyMode(mode);
      if (mode === 'online') goLobby();
      else goBriefing();
    }
  });
}

function goLobby() {
  hud.hide();
  lobbyUi = screens.lobby({
    onHost: async () => {
      try {
        game.netRole = 'host';
        await game.net.createRoom();
        lobbyUi.setStatus('Raum wird erstellt …');
      } catch {
        lobbyUi.setStatus('Server nicht erreichbar. Läuft "npm start"?', 'bad');
      }
    },
    onJoin: async (code) => {
      if (!code || code.length < 4) return lobbyUi.setStatus('Bitte den 5-stelligen Code eingeben.', 'bad');
      try {
        game.netRole = 'guest';
        await game.net.joinRoom(code);
        lobbyUi.setStatus('Verbinde …');
      } catch {
        lobbyUi.setStatus('Server nicht erreichbar.', 'bad');
      }
    },
    onCancel: () => { game.net.leave(); goMenu(); },
    onStart: () => {
      game.net.send({ type: 'phase', phase: 'briefing' });
      goBriefing();
    }
  });
}

function goBriefing() {
  game.state.phase = 'briefing';
  hud.hide();
  if (game.isGuest) {
    screens.waiting('Der Host bereitet die Schicht vor …');
    return;
  }
  applyMode(game.state.mode);
  pendingEvent = pickNightEvent(game.rng, game.state);
  const tutorial = game.tutorialWanted && !game.state.tutorialDone;
  screens.briefing(pendingEvent, () => beginNight(tutorial), { tutorial });
}

function beginNight(tutorial) {
  const artist = game.state.bookedArtist;
  game.state.bookedArtist = null;
  applyMode(game.state.mode);
  startNight(game, pendingEvent, artist, { tutorial });
  if (!tutorial) {
    game.state.unlocks = { id: true, talk: true, search: true, alcohol: true, calm: true };
  }
  screens.hide();
  hud.show();
  audio.start();
  audio.setIntensity(0.3);
  if (game.isHost) sendSnapshot();
}

function goReport() {
  hud.hide();
  if (game.isGuest) {
    screens.waiting('Der Host sieht sich den Night Report an …');
    return;
  }
  screens.report(() => screens.shop(goBriefing));
}

/* ---------------- Bus-Ereignisse ---------------- */

game.bus.on('nightEnd', () => {
  if (game.isGuest) return;
  const before = rank(game.state).level;
  const up = checkRankUp(game.state, before);
  if (up) pushLog(game.state, `Aufstieg: ${up.label}`, 'good');
  game.save();
  audio.setIntensity(0.2);
  goReport();
});

game.bus.on('sfx', (name) => audio.sfx(name));

game.bus.on('upgradeBought', (result) => {
  if (result.tierChanged) pushLog(game.state, `Club-Stufe ${result.tier} erreicht`, 'good');
});

/* ---------------- Netzwerk ---------------- */

game.bus.on('net:room', ({ code, role }) => {
  game.netRole = role;
  applyMode('online');
  lobbyUi?.setRoom(code, role);
  lobbyUi?.setStatus(role === 'host'
    ? 'Warte auf den Partner …'
    : 'Verbunden. Warte auf den Host …');
});

game.bus.on('net:peer', ({ connected, fatal }) => {
  if (connected) {
    lobbyUi?.setStatus('Partner ist da. Ihr könnt starten.', 'ok');
    lobbyUi?.showStart(game.isHost);
    hud.setNet('ONLINE · PARTNER VERBUNDEN');
  } else {
    hud.setNet(fatal ? 'HOST HAT DEN RAUM GESCHLOSSEN' : 'PARTNER GETRENNT', true);
    lobbyUi?.setStatus('Partner getrennt.', 'bad');
    lobbyUi?.showStart(false);
  }
});

game.bus.on('net:error', (reason) => lobbyUi?.setStatus(reason, 'bad'));

game.bus.on('net:closed', () => {
  if (game.state.mode === 'online') hud.setNet('VERBINDUNG GETRENNT', true);
});

// Host: Aktionen des Gastes anwenden.
game.bus.on('net:action', (msg) => {
  if (!game.isHost) return;
  const player = game.players.find((p) => p.id === msg.role);
  if (!player) return;
  if (msg.role !== 'security') return;   // der Gast steuert nur die Schleuse
  tryAction(game, player, msg.code, msg.payload ?? {});
});

// Gast: Schnappschuss übernehmen.
game.bus.on('net:snapshot', (data) => {
  if (!game.isGuest) return;
  const wasPhase = game.state.phase;
  applySnapshot(game, data);
  if (game.state.phase === 'night' && wasPhase !== 'night') {
    screens.hide();
    hud.show();
    audio.start();
  } else if (game.state.phase !== 'night' && wasPhase === 'night') {
    goReport();
  }
});

game.bus.on('net:phase', (msg) => {
  if (!game.isGuest) return;
  if (msg.phase === 'briefing') screens.waiting('Der Host startet gleich die Schicht …');
});

function sendSnapshot() {
  if (!game.isHost || !game.net.peerReady) return;
  game.net.sendSnapshot(serializeState(game));
}

/* ---------------- Loop ---------------- */

const loop = createLoop({
  update(dt) {
    if (game.state.phase !== 'night' || game.paused) {
      input.endFrame();
      return;
    }

    if (game.isGuest) {
      // Der Gast simuliert nicht - er schickt nur seine Eingaben.
      readGuestInput();
      input.endFrame();
      return;
    }

    updatePlayers(game, dt, input);
    updateNight(game, dt);

    const phase = currentPhase(shiftProgress(game.state.night));
    const load = Math.min(1, game.state.night.queue.length / 14);
    audio.setIntensity(phase.intensity * 0.75 + load * 0.25);

    if (game.isHost) {
      snapshotTimer -= dt;
      if (snapshotTimer <= 0) {
        snapshotTimer = 0.08;
        sendSnapshot();
      }
    }
    input.endFrame();
  },
  render(dt) {
    renderer.render(game, dt);
    if (game.state.phase === 'night') {
      hud.update();
      idcard.update();
      itemTray.update();
    }
  }
});

/** Eingaben des Gastes: direkt als Netzwerk-Aktion. */
function readGuestInput() {
  const role = game.roleById('security');
  for (const action of role.actions) {
    if (input.justPressed(action.key)) game.act('security', action.code);
  }
  const station = game.stationFor('security');
  if (station?.patdown && !station.patdown.complete) {
    for (const [key, zone] of [['KeyJ', 'jacket'], ['KeyK', 'pockets'], ['KeyL', 'bag']]) {
      if (input.justPressed(key)) game.act('security', 'zone', { zone });
    }
  }
}

/* ---------------- Systemtasten ---------------- */

window.addEventListener('keydown', (e) => {
  if (e.target instanceof HTMLInputElement) return;
  if (e.code === 'Escape' && game.state.phase === 'night' && !game.isGuest) togglePause();
  else if (e.code === 'KeyM') audio.toggleMute();
  else if (e.code === 'KeyH') document.getElementById('hint').classList.toggle('hidden');
});

function togglePause() {
  game.paused = !game.paused;
  if (game.paused) {
    screens.pause(togglePause, () => {
      game.paused = false;
      endNight(game);
      screens.hide();
    });
  } else {
    screens.hide();
  }
}

window.addEventListener('pointerdown', () => audio.start(), { once: true });

loop.start();
applyMode('solo');
goMenu();

window.NULLWERK = game;
