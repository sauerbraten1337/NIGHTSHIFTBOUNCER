/**
 * NULLWERK-Server: liefert das Spiel aus und vermittelt Online-Räume.
 *
 * Der Server ist bewusst dumm: er kennt keine Spielregeln, sondern verbindet
 * genau zwei Clients zu einem Raum und leitet Nachrichten weiter. Die Nacht
 * simuliert der Host (der den Raum erstellt hat) - dadurch kann es keine
 * auseinanderlaufenden Spielstände geben.
 *
 * Start: node server/index.js [port]
 */

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const PORT = Number(process.argv[2] ?? process.env.PORT ?? 8080);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

/* ---------------- Statische Dateien ---------------- */

const httpServer = createServer(async (req, res) => {
  const url = decodeURIComponent((req.url ?? '/').split('?')[0]);
  if (url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    return;
  }
  const rel = normalize(url === '/' ? '/index.html' : url).replace(/^(\.\.[/\\])+/, '');
  try {
    const body = await readFile(join(ROOT, rel));
    res.writeHead(200, {
      'Content-Type': MIME[extname(rel)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store'
    });
    res.end(body);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404');
  }
});

/* ---------------- Räume ---------------- */

/** code -> { host, guest, createdAt } */
const rooms = new Map();
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // ohne I/O/0/1

function newCode() {
  let code;
  do {
    code = Array.from({ length: 5 }, () =>
      ALPHABET[Math.floor(Math.random() * ALPHABET.length)]).join('');
  } while (rooms.has(code));
  return code;
}

const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

wss.on('connection', (socket) => {
  socket.isAlive = true;
  socket.on('pong', () => { socket.isAlive = true; });

  socket.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    handle(socket, msg);
  });

  socket.on('close', () => leave(socket));
  socket.on('error', () => leave(socket));
});

function handle(socket, msg) {
  switch (msg.type) {
    case 'create': {
      leave(socket);
      const code = newCode();
      rooms.set(code, { host: socket, guest: null, createdAt: Date.now() });
      socket.roomCode = code;
      socket.role = 'host';
      send(socket, { type: 'room', code, role: 'host' });
      break;
    }
    case 'join': {
      const code = String(msg.code ?? '').toUpperCase().trim();
      const room = rooms.get(code);
      if (!room) return send(socket, { type: 'error', reason: 'Raum nicht gefunden' });
      if (room.guest) return send(socket, { type: 'error', reason: 'Raum ist voll' });
      leave(socket);
      room.guest = socket;
      socket.roomCode = code;
      socket.role = 'guest';
      send(socket, { type: 'room', code, role: 'guest' });
      send(room.host, { type: 'peerJoined' });
      send(socket, { type: 'peerJoined' });
      break;
    }
    case 'leave':
      leave(socket);
      break;
    default: {
      // Alles andere geht unverändert an den Partner.
      const room = rooms.get(socket.roomCode);
      if (!room) return;
      const peer = socket === room.host ? room.guest : room.host;
      if (peer) send(peer, msg);
      break;
    }
  }
}

function leave(socket) {
  const code = socket.roomCode;
  if (!code) return;
  const room = rooms.get(code);
  socket.roomCode = null;
  if (!room) return;

  if (room.host === socket) {
    if (room.guest) send(room.guest, { type: 'peerLeft', fatal: true });
    rooms.delete(code);
  } else if (room.guest === socket) {
    room.guest = null;
    if (room.host) send(room.host, { type: 'peerLeft' });
  }
}

function send(socket, msg) {
  if (socket && socket.readyState === socket.OPEN) socket.send(JSON.stringify(msg));
}

// Tote Verbindungen aufräumen.
setInterval(() => {
  for (const socket of wss.clients) {
    if (!socket.isAlive) { socket.terminate(); continue; }
    socket.isAlive = false;
    socket.ping();
  }
  // Verwaiste Räume nach 4 Stunden entfernen.
  const cutoff = Date.now() - 4 * 3600 * 1000;
  for (const [code, room] of rooms) if (room.createdAt < cutoff) rooms.delete(code);
}, 30000);

httpServer.listen(PORT, () => {
  console.log(`NULLWERK läuft auf http://localhost:${PORT}  (Online-Räume aktiv)`);
});
