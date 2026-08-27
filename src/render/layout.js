/**
 * Weltkoordinaten der 2D-Szene (logische Aufloesung 1280x720).
 * Wird von Rendering UND Gameplay genutzt, damit Figuren und Kulisse
 * garantiert zusammenpassen.
 */

export const WORLD = { width: 1280, height: 720 };

export const LAYOUT = {
  club: { x: 120, y: 20, w: 1040, h: 320 },
  door: { x: 640, y: 348, w: 96 },
  backDoor: { x: 196, y: 348, w: 64 },
  street: { x: 0, y: 360, w: 1280, h: 360 },
  spawn: { x: 1245, y: 640 },
  queue: { x: 356, y: 470, spacing: 54, rowGap: 66, perRow: 9 },
  stations: {
    door: { x: 592, y: 404, r: 96, label: 'TÜR' },
    search: { x: 726, y: 404, r: 96, label: 'KONTROLLE' }
  },
  // Innenbereiche des Clubs (skalieren mit der Club-Stufe)
  interior: {
    dancefloor: { x: 430, y: 60, w: 420, h: 210 },
    floor2: { x: 880, y: 70, w: 230, h: 190 },
    bar: { x: 150, y: 70, w: 220, h: 90 },
    vip: { x: 150, y: 190, w: 220, h: 110 },
    booth: { x: 570, y: 34, w: 140, h: 44 },
    backstage: { x: 150, y: 190, w: 130, h: 100 }
  }
};

export function stationFor(roleId) {
  return roleId === 'bouncer' ? LAYOUT.stations.door : LAYOUT.stations.search;
}

export function inStation(player) {
  const s = stationFor(player.role.id);
  return Math.hypot(player.x - s.x, player.y - s.y) <= s.r;
}

export function nearQueue(player) {
  const q = LAYOUT.queue;
  return player.y > q.y - 60 && player.x > q.x - 80;
}
