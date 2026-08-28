/**
 * Online-Koop: Raum erstellen / beitreten.
 *
 * Modell: Host-autoritativ. Der Host simuliert die Nacht und schickt ~12x pro
 * Sekunde einen Schnappschuss; der Gast rendert daraus seine Schleusen-Ansicht
 * und schickt nur seine Aktionen zurück. So kann nichts auseinanderlaufen.
 */

export function createNet(bus) {
  let socket = null;
  let role = null;      // 'host' | 'guest'
  let code = null;
  let peerReady = false;
  let status = 'offline';

  function url() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    return `${proto}://${location.host}/ws`;
  }

  function connect() {
    return new Promise((resolve, reject) => {
      if (socket && socket.readyState === WebSocket.OPEN) return resolve(socket);
      try {
        socket = new WebSocket(url());
      } catch (err) {
        return reject(err);
      }
      status = 'connecting';
      socket.addEventListener('open', () => { status = 'online'; resolve(socket); });
      socket.addEventListener('error', () => {
        status = 'error';
        reject(new Error('Verbindung fehlgeschlagen'));
      });
      socket.addEventListener('close', () => {
        status = 'offline';
        peerReady = false;
        bus.emit('net:closed');
      });
      socket.addEventListener('message', (event) => {
        let msg;
        try { msg = JSON.parse(event.data); } catch { return; }
        route(msg);
      });
    });
  }

  function route(msg) {
    switch (msg.type) {
      case 'room':
        code = msg.code;
        role = msg.role;
        bus.emit('net:room', { code, role });
        break;
      case 'peerJoined':
        peerReady = true;
        bus.emit('net:peer', { connected: true });
        break;
      case 'peerLeft':
        peerReady = false;
        bus.emit('net:peer', { connected: false, fatal: !!msg.fatal });
        break;
      case 'error':
        bus.emit('net:error', msg.reason);
        break;
      case 'snapshot':
        bus.emit('net:snapshot', msg.data);
        break;
      case 'action':
        bus.emit('net:action', msg);
        break;
      case 'phase':
        bus.emit('net:phase', msg);
        break;
      case 'chat':
        bus.emit('net:chat', msg);
        break;
      default:
        break;
    }
  }

  return {
    get role() { return role; },
    get code() { return code; },
    get connected() { return socket?.readyState === WebSocket.OPEN; },
    get peerReady() { return peerReady; },
    get status() { return status; },

    async createRoom() {
      await connect();
      socket.send(JSON.stringify({ type: 'create' }));
    },

    async joinRoom(roomCode) {
      await connect();
      socket.send(JSON.stringify({ type: 'join', code: String(roomCode).toUpperCase().trim() }));
    },

    send(msg) {
      if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(msg));
    },

    sendAction(roleId, actionCode, payload) {
      this.send({ type: 'action', role: roleId, code: actionCode, payload });
    },

    sendSnapshot(data) {
      this.send({ type: 'snapshot', data });
    },

    leave() {
      this.send({ type: 'leave' });
      socket?.close();
      socket = null;
      role = null;
      code = null;
      peerReady = false;
      status = 'offline';
    }
  };
}

/* ------------------------------------------------------------------ */
/* Schnappschuss: nur, was der Gast zum Spielen und Anzeigen braucht.  */
/* Die versteckte Wahrheit über Gäste bleibt beim Host.                */
/* ------------------------------------------------------------------ */

export function serializeState(game) {
  const { state } = game;
  const night = state.night;

  return {
    mode: state.mode,
    phase: state.phase,
    money: state.money,
    reputation: state.reputation,
    upgrades: state.upgrades,
    talents: state.talents,
    unlocks: state.unlocks,
    nightIndex: state.nightIndex,
    xp: state.xp,
    night: night ? {
      clock: night.clock,
      quota: night.quota,
      processed: night.processed,
      running: night.running,
      event: night.event,
      artist: night.artist,
      stats: night.stats,
      activeEffects: night.activeEffects,
      toasts: night.toasts,
      queueLength: night.queue.length,
      queue: night.queue.slice(0, 9).map(viewGuest),
      airlockQueue: night.airlockQueue.map(viewGuest),
      insideCount: night.inside.length,
      tutorialStep: night.tutorial?.step ?? null,
      stations: {
        door: viewStation(night.stations.door),
        airlock: viewStation(night.stations.airlock)
      }
    } : null,
    players: game.players.map((p) => ({
      id: p.id, busy: p.busy, busyTotal: p.busyTotal, busyLabel: p.busyLabel,
      lastResult: p.lastResult, flash: p.flash
    }))
  };
}

function viewGuest(guest) {
  if (!guest) return null;
  return {
    id: guest.id,
    name: guest.name,
    archetypeLabel: guest.archetypeLabel,
    personality: guest.personality,
    look: guest.look,
    doc: guest.doc,
    said: guest.said,
    saidTimer: guest.saidTimer,
    isArtist: !!guest.isArtist,
    swayPhase: guest.swayPhase,
    walkPhase: guest.walkPhase,
    patience: guest.patience,
    patienceMax: guest.patienceMax,
    doorVerdict: guest.doorVerdict ?? null,
    // Nur, was man sehen kann - keine versteckten Verstösse.
    truth: {
      drunk: guest.truth.drunk,
      vip: guest.truth.vip,
      hasBag: guest.truth.hasBag,
      // Sichtbare Anzeichen gehören zum Bild, nicht zur versteckten Wahrheit.
      impairmentSigns: guest.truth.impairmentSigns ?? []
    }
  };
}

function viewStation(station) {
  const checks = station.checks;
  return {
    id: station.id,
    guest: viewGuest(station.guest),
    // Die Wahrheit ueber das Dokument bleibt auf dem Host.
    checks: checks.id ? { ...checks, id: { ...checks.id, faults: undefined } } : checks,
    patdown: station.patdown,
    notes: station.notes,
    // Übergriff: der Gast am anderen Rechner muss dieselben Tasten sehen.
    aggro: station.aggro
  };
}

/**
 * Baut aus einem Schnappschuss ein Objekt, das sich für Renderer und HUD
 * wie ein echtes Spiel verhält (nur eben ohne Simulation).
 */
export function applySnapshot(shadow, data) {
  shadow.state.mode = data.mode;
  shadow.state.phase = data.phase;
  shadow.state.money = data.money;
  shadow.state.reputation = data.reputation;
  shadow.state.upgrades = data.upgrades;
  shadow.state.talents = data.talents;
  shadow.state.unlocks = data.unlocks;
  shadow.state.nightIndex = data.nightIndex;
  shadow.state.xp = data.xp;

  if (!data.night) {
    shadow.state.night = null;
    return shadow;
  }

  const n = data.night;
  shadow.state.night = {
    clock: n.clock,
    quota: n.quota,
    processed: n.processed,
    running: n.running,
    event: n.event,
    artist: n.artist,
    stats: n.stats,
    activeEffects: n.activeEffects,
    toasts: n.toasts,
    queue: n.queue,
    queueLength: n.queueLength,
    airlockQueue: n.airlockQueue,
    inside: new Array(n.insideCount).fill(0),
    leaving: [],
    stations: n.stations,
    tutorial: n.tutorialStep ? { step: n.tutorialStep } : null
  };
  shadow.players = data.players.map((p) => {
    const role = shadow.roleById(p.id);
    // Der Bereich muss mitkommen, sonst landen Rolle, Panel und Aktionsleiste
    // beim Gast im falschen Bereich.
    return { ...p, role, area: role.area };
  });
  return shadow;
}
