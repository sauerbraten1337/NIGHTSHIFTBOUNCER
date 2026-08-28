/**
 * Zentrale Tuning-Werte, Datentabellen und Balancing-Konstanten.
 * Reines Daten-Modul: keine DOM-Zugriffe, keine Seiteneffekte.
 */

export const CLUB_NAME = 'NULLWERK';

export const TUNING = {
  // Nacht laeuft von 00:00 bis 05:00 (300 Spielminuten).
  nightStartMinute: 0,
  nightEndMinute: 300,
  // Spielminuten pro Realsekunde.
  minutesPerSecond: 0.8,

  baseEntryFee: 12,
  baseCapacity: 120,
  baseQueueCapacity: 22,

  // Dauer der Aktionen in Sekunden (Basis, wird durch Talente/Upgrades gesenkt).
  actionTime: {
    id: 1.6,
    talk: 1.2,
    scan: 1.4,
    search: 0.9,   // eine Zone ausleeren
    bag: 1.5,      // Tasche erst hervorholen, dann ausleeren
    pick: 0.35,    // einen Gegenstand herausgreifen
    alcohol: 1.3,
    calm: 1.0,
    admit: 0.6,
    reject: 0.6
  },

  patienceBase: 78, // Sekunden bis ein Gast die Schlange genervt verlaesst
  drunkRejectThreshold: 0.72,
  minAge: 18,

  reputationStart: 42,
  moneyStart: 400,

  // Wirtschaft
  barSpendPerGuestPerMinute: 0.16,
  incidentBaseCost: 90,
  fineUnderage: 320
};

/**
 * Spielmodi. Im Solo-Modus uebernimmt der Bouncer alle Aufgaben und es gibt
 * keinen getrennten Security-Bereich.
 */
export const MODES = {
  solo: { id: 'solo', label: 'SOLO', desc: 'Du machst Tuer und Kontrolle allein. Kein Security-Bereich.' },
  local: { id: 'local', label: 'LOKALER KOOP', desc: 'Zwei Spieler an einer Tastatur, Splitscreen.' },
  online: { id: 'online', label: 'ONLINE-KOOP', desc: 'Raum erstellen oder beitreten, jeder an seinem Rechner.' }
};

/** Bereiche: der Bouncer arbeitet draussen, die Security in der Schleuse. */
export const AREAS = {
  outside: { id: 'outside', label: 'EINGANG', sub: 'DRAUSSEN' },
  airlock: { id: 'airlock', label: 'SICHERHEITSSCHLEUSE', sub: 'INNEN, VOR DEM CLUB' }
};

const KEYS_P1 = { up: 'KeyW', down: 'KeyS', left: 'KeyA', right: 'KeyD' };
const KEYS_P2 = { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' };

/**
 * Rollen je nach Modus.
 * `pass` schickt den Gast in die Schleuse (nur Koop),
 * `admit` laesst endgueltig in den Club.
 */
export function rolesFor(mode) {
  if (mode === 'solo') {
    return [{
      id: 'bouncer', label: 'BOUNCER', accent: '#ff3b3b', area: 'outside', solo: true,
      keys: KEYS_P1,
      actions: [
        { key: 'Digit1', code: 'id', label: 'AUSWEIS' },
        { key: 'Digit2', code: 'talk', label: 'ANSPRECHEN' },
        { key: 'Digit3', code: 'search', label: 'ABTASTEN' },
        { key: 'Digit4', code: 'alcohol', label: 'ALKOTEST' },
        { key: 'Digit5', code: 'calm', label: 'SCHLANGE' },
        { key: 'KeyE', code: 'admit', label: 'EINLASSEN' },
        { key: 'KeyX', code: 'reject', label: 'ABWEISEN' }
      ]
    }];
  }
  return [
    {
      id: 'bouncer', label: 'BOUNCER', accent: '#ff3b3b', area: 'outside', solo: false,
      keys: KEYS_P1,
      actions: [
        { key: 'Digit1', code: 'id', label: 'AUSWEIS' },
        { key: 'Digit2', code: 'talk', label: 'ANSPRECHEN' },
        { key: 'Digit3', code: 'calm', label: 'SCHLANGE' },
        { key: 'KeyE', code: 'pass', label: 'DURCHLASSEN' },
        { key: 'KeyX', code: 'reject', label: 'ABWEISEN' }
      ]
    },
    {
      id: 'security', label: 'SECURITY', accent: '#39d7ff', area: 'airlock', solo: false,
      keys: KEYS_P2,
      actions: [
        { key: 'Digit7', code: 'search', label: 'ABTASTEN' },
        { key: 'Digit8', code: 'alcohol', label: 'ALKOTEST' },
        { key: 'Enter', code: 'admit', label: 'EINLASSEN' },
        { key: 'Backspace', code: 'reject', label: 'ZURUECKSCHICKEN' }
      ]
    }
  ];
}

/** Welche Kontrollen gehoeren zu welchem Bereich? */
export const AREA_CHECKS = {
  outside: ['id', 'talk'],
  airlock: ['search', 'alcohol']
};

/** Das Spiel spielt an einem festen fiktiven Datum - Basis fuer Ablauf/Alter. */
export const GAME_DATE = { year: 2026, month: 3, day: 14 };

/** Wie viele Gaeste passen gleichzeitig in die Schleuse? */
export const AIRLOCK_CAPACITY = 4;

/** Tasten für die Abtast-Zonen (Spieler 2). */
export const PATDOWN_KEYS = [
  { key: 'KeyJ', zone: 'jacket', label: 'JACKE' },
  { key: 'KeyK', zone: 'pockets', label: 'HOSENTASCHEN' },
  { key: 'KeyL', zone: 'bag', label: 'TASCHE' }
];

/** Grenzwert, der auf dem Alkoholtestgerät aufgedruckt ist. */
export const ALCOHOL_LIMIT_PROMILLE = 1.7;

/** Gast-Archetypen. weight = relative Häufigkeit. */
export const ARCHETYPES = [
  {
    id: 'regular', label: 'Standardgast', weight: 30, spend: [18, 46], risk: [0, 0.35],
    drunk: [0, 0.55], vip: 0, badIdChance: 0.06, contrabandChance: 0.05, patience: 1.0, rep: 1
  },
  {
    id: 'tourist', label: 'Tourist', weight: 14, spend: [40, 95], risk: [0, 0.3],
    drunk: [0.1, 0.8], vip: 0, badIdChance: 0.14, contrabandChance: 0.04, patience: 1.15, rep: 0.6
  },
  {
    id: 'local', label: 'Stammgast', weight: 16, spend: [22, 55], risk: [0, 0.2],
    drunk: [0, 0.5], vip: 0, badIdChance: 0.03, contrabandChance: 0.03, patience: 0.85, rep: 1.4
  },
  {
    id: 'influencer', label: 'Influencer', weight: 6, spend: [15, 40], risk: [0, 0.3],
    drunk: [0, 0.45], vip: 0.2, badIdChance: 0.05, contrabandChance: 0.03, patience: 0.6, rep: 3
  },
  {
    id: 'vip', label: 'VIP', weight: 6, spend: [120, 340], risk: [0, 0.25],
    drunk: [0, 0.5], vip: 1, badIdChance: 0.02, contrabandChance: 0.02, patience: 0.45, rep: 2.5
  },
  {
    id: 'trouble', label: 'Problemgast', weight: 9, spend: [10, 30], risk: [0.55, 1],
    drunk: [0.3, 1], vip: 0, badIdChance: 0.25, contrabandChance: 0.42, patience: 0.7, rep: -1
  },
  {
    id: 'scene', label: 'Szene-Gast', weight: 8, spend: [25, 70], risk: [0, 0.35],
    drunk: [0, 0.5], vip: 0.1, badIdChance: 0.05, contrabandChance: 0.06, patience: 0.5, rep: 2
  },
  {
    id: 'crew', label: 'Crew-Mitglied', weight: 4, spend: [0, 10], risk: [0, 0.2],
    drunk: [0, 0.3], vip: 0.5, badIdChance: 0.08, contrabandChance: 0.05, patience: 0.7, rep: 1.5,
    backstage: true
  },
  {
    id: 'insider', label: 'Security-Insider', weight: 3, spend: [20, 50], risk: [0, 0.2],
    drunk: [0, 0.2], vip: 0, badIdChance: 0.35, contrabandChance: 0.3, patience: 1.2, rep: 2,
    inspector: true
  },
  {
    id: 'mystery', label: 'Mystery-Gast', weight: 4, spend: [0, 260], risk: [0, 1],
    drunk: [0, 0.9], vip: 0.35, badIdChance: 0.2, contrabandChance: 0.2, patience: 0.9, rep: 1.5
  }
];

/**
 * Gegenstände, die beim Abtasten zum Vorschein kommen.
 * Die meisten sind völlig harmlos - genau darum muss man hinsehen.
 * `zones` sagt, wo ein Gegenstand plausibel steckt.
 */
export const ITEMS = [
  // --- harmlos ---
  { id: 'gum', label: 'Kaugummi', forbidden: false, severity: 0, zones: ['pockets', 'bag'] },
  { id: 'phone', label: 'Handy', forbidden: false, severity: 0, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'keys', label: 'Schlüsselbund', forbidden: false, severity: 0, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'lighter', label: 'Feuerzeug', forbidden: false, severity: 0, zones: ['jacket', 'pockets'] },
  { id: 'smokes', label: 'Zigaretten', forbidden: false, severity: 0, zones: ['jacket', 'bag'] },
  { id: 'wallet', label: 'Portemonnaie', forbidden: false, severity: 0, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'earbuds', label: 'Kopfhörer', forbidden: false, severity: 0, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'coins', label: 'Kleingeld', forbidden: false, severity: 0, zones: ['pockets'] },
  { id: 'tissues', label: 'Taschentücher', forbidden: false, severity: 0, zones: ['jacket', 'bag'] },
  { id: 'balm', label: 'Lippenpflege', forbidden: false, severity: 0, zones: ['pockets', 'bag'] },
  { id: 'mints', label: 'Pfefferminz', forbidden: false, severity: 0, zones: ['pockets', 'bag'] },
  { id: 'charger', label: 'Ladekabel', forbidden: false, severity: 0, zones: ['bag'] },
  { id: 'bottle', label: 'Wasserflasche', forbidden: false, severity: 0, zones: ['bag'] },
  { id: 'book', label: 'Notizbuch', forbidden: false, severity: 0, zones: ['bag'] },

  // --- verboten ---
  { id: 'camera', label: 'Profikamera', forbidden: true, severity: 1, zones: ['bag'] },
  { id: 'glass', label: 'Glasflasche', forbidden: true, severity: 1, zones: ['bag', 'jacket'] },
  { id: 'laser', label: 'Laserpointer', forbidden: true, severity: 1, zones: ['jacket', 'pockets'] },
  { id: 'substance', label: 'Verdächtiges Päckchen', forbidden: true, severity: 2, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'spray', label: 'Reizgas', forbidden: true, severity: 2, zones: ['jacket', 'bag'] },
  { id: 'tool', label: 'Multitool', forbidden: true, severity: 2, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'baton', label: 'Teleskopstock', forbidden: true, severity: 3, zones: ['jacket', 'bag'] },
  { id: 'blade', label: 'Klinge', forbidden: true, severity: 3, zones: ['jacket', 'pockets'] }
];

export function itemById(id) {
  return ITEMS.find((i) => i.id === id) ?? null;
}

/** Abtast-Zonen. 'bag' gibt es nur, wenn der Gast wirklich eine Tasche dabei hat. */
export const ZONES = [
  { id: 'jacket', label: 'JACKE', key: 'KeyJ', needsBag: false, capacity: [1, 3] },
  { id: 'pockets', label: 'HOSENTASCHEN', key: 'KeyK', needsBag: false, capacity: [1, 3] },
  { id: 'bag', label: 'TASCHE', key: 'KeyL', needsBag: true, capacity: [2, 4] }
];

/**
 * Was der Spieler im Lauf der Karriere zusätzlich beachten muss.
 * Jede Stufe schaltet eine neue Auffälligkeit frei und wird im Briefing angekündigt.
 */
export const DIFFICULTY_STEPS = [
  {
    night: 1, id: 'basics', label: 'AUSWEIS',
    desc: 'Foto, Name, Geburtsdatum, Gültigkeit, Hologramm.'
  },
  {
    night: 2, id: 'items', label: 'GEGENSTÄNDE',
    desc: 'Beim Abtasten kommt alles auf den Tisch. Such heraus, was nicht reindarf.'
  },
  {
    night: 3, id: 'alcohol', label: 'ALKOHOL',
    desc: 'Das Testgerät zeigt den Wert - den Grenzwert musst du selbst lesen.'
  },
  {
    night: 4, id: 'impaired', label: 'ZUSTAND',
    desc: 'Nicht jeder Rausch riecht nach Alkohol: weite Pupillen, Schwitzen, Zittern, mahlender Kiefer.'
  },
  {
    night: 6, id: 'subtleId', label: 'FEINE FÄLSCHUNGEN',
    desc: 'Hologramme sind nur noch teilweise matt, Manipulationen kleiner.'
  },
  {
    night: 8, id: 'blacklist', label: 'HAUSVERBOTE',
    desc: 'Bekannte Gesichter mit Hausverbot versuchen es erneut. Der Scanner kennt sie.'
  },
  {
    night: 10, id: 'multi', label: 'MEHRFACHE MÄNGEL',
    desc: 'Ein sauberer Ausweis heisst gar nichts mehr - es kommt oft mehreres zusammen.'
  }
];

/** Sichtbare Anzeichen für Substanzeinfluss (abstrakt, ohne Konsumdetails). */
export const IMPAIRMENT_SIGNS = [
  { id: 'pupils', label: 'weite Pupillen', min: 0.35 },
  { id: 'sweat', label: 'schwitzt stark', min: 0.5 },
  { id: 'jaw', label: 'mahlender Kiefer', min: 0.6 },
  { id: 'shake', label: 'zitternde Hände', min: 0.7 },
  { id: 'absent', label: 'wirkt abwesend', min: 0.45 }
];

export const ID_ISSUES = [
  { id: 'expired', label: 'Ausweis abgelaufen' },
  { id: 'photo', label: 'Foto passt nicht' },
  { id: 'name', label: 'Name unstimmig' },
  { id: 'marks', label: 'Sicherheitsmerkmale fehlen' },
  { id: 'age', label: 'Geburtsdatum manipuliert' }
];

/** Nacht-Events. */
export const NIGHT_EVENTS = [
  {
    id: 'normal', label: 'NORMAL NIGHT', desc: 'Normale Gäste, ruhiger Betrieb.',
    spawn: 1.0, vip: 1.0, trouble: 1.0, spend: 1.0, minNight: 1
  },
  {
    id: 'rave', label: 'UNDERGROUND RAVE', desc: 'Massive Warteschlange, harter Andrang.',
    spawn: 1.75, vip: 0.9, trouble: 1.3, spend: 1.0, minNight: 2
  },
  {
    id: 'vipnight', label: 'VIP NIGHT', desc: 'Deutlich mehr VIPs, hohe Erwartungen.',
    spawn: 1.1, vip: 3.0, trouble: 0.9, spend: 1.35, minNight: 3
  },
  {
    id: 'artist', label: 'ARTIST NIGHT', desc: 'Grosser Act. Backstage-Kontrolle noetig.',
    spawn: 1.45, vip: 1.6, trouble: 1.1, spend: 1.25, minNight: 3
  },
  {
    id: 'soldout', label: 'SOLD OUT', desc: 'Extremer Andrang, Kapazität wird knapp.',
    spawn: 2.1, vip: 1.2, trouble: 1.2, spend: 1.1, minNight: 5
  },
  {
    id: 'inspection', label: 'INSPECTION NIGHT', desc: 'Behörden kontrollieren. Fehler kosten doppelt.',
    spawn: 1.0, vip: 0.8, trouble: 1.4, spend: 0.95, minNight: 4, inspection: true
  },
  {
    id: 'chaos', label: 'CHAOS NIGHT', desc: 'Zufällige Zwischenfälle, hohe Frequenz.',
    spawn: 1.5, vip: 1.2, trouble: 1.6, spend: 1.1, minNight: 6, chaos: true
  }
];

/** Fiktive In-Game-Acts. */
export const ARTISTS = [
  { id: 'philo', name: 'PHILO', genre: 'Deep Techno', fee: 300, pop: 1, vipPull: 1.1, spend: 1.1 },
  { id: 'tilo', name: 'TILO', genre: 'Hard Groove', fee: 650, pop: 2, vipPull: 1.2, spend: 1.15 },
  { id: 'baxboy', name: 'TJ BAXBOY', genre: 'Acid', fee: 1100, pop: 3, vipPull: 1.35, spend: 1.2 },
  { id: 'nerok', name: 'NERO K', genre: 'Industrial', fee: 1800, pop: 4, vipPull: 1.5, spend: 1.3 },
  { id: 'vexa', name: 'VEXA', genre: 'Hypnotic', fee: 2600, pop: 5, vipPull: 1.7, spend: 1.4 },
  { id: 'kayr', name: 'KAYR', genre: 'Trance Revival', fee: 3800, pop: 6, vipPull: 1.9, spend: 1.5 },
  { id: 'voidctrl', name: 'VOIDCTRL', genre: 'Warehouse', fee: 5200, pop: 7, vipPull: 2.2, spend: 1.7 }
];

/**
 * Upgrades. `tier` zaehlt in die sichtbare Club-Stufe ein.
 * cost(level) -> Preis für den nächsten Ausbau.
 */
export const UPGRADES = [
  {
    id: 'scanner', label: 'Dokumenten-Prüfgerät', max: 3, tier: 1,
    group: 'Sicherheit',
    desc: ['UV-Lampe: meldet, wenn am Dokument etwas nicht stimmt.',
      'Schnellprüfung: alle Kontrollen laufen zügiger.',
      'Feinanalyse: markiert das auffällige Feld auf dem Ausweis.'],
    cost: [450, 1200, 2800]
  },
  {
    id: 'detector', label: 'Metalldetektor', max: 2, tier: 1,
    group: 'Sicherheit',
    desc: ['Markiert die verdächtige Körperzone beim Abtasten.',
      'Erkennt gefaehrliche Gegenstaende automatisch.'],
    cost: [600, 1900]
  },
  {
    id: 'cameras', label: 'Sicherheitskameras', max: 2, tier: 1,
    group: 'Sicherheit',
    desc: ['Crowd-Monitoring: senkt Zwischenfall-Schaden.',
      'Risiko-Vorwarnung für die Warteschlange.'],
    cost: [520, 1500]
  },
  {
    id: 'team', label: 'Security-Team', max: 3, tier: 1,
    group: 'Sicherheit',
    desc: ['Ein zusätzlicher Mitarbeiter beruhigt die Schlange.',
      'Zweiter Mitarbeiter, weniger Eskalationen.',
      'Volles Team: Zwischenfälle werden meist abgefangen.'],
    cost: [700, 1600, 3400]
  },
  {
    id: 'door', label: 'Eingang & Tür', max: 3, tier: 1,
    group: 'Eingang',
    desc: ['Breitere Tür: schnellerer Einlass.',
      'Zweiter Eingang: längere Warteschlange möglich.',
      'VIP-Eingang: VIPs warten geduldiger.'],
    cost: [400, 1300, 3000]
  },
  {
    id: 'lights', label: 'Lichtanlage', max: 3, tier: 1,
    group: 'Technik',
    desc: ['Neue Neon-Beleuchtung am Eingang.',
      'Laser und bewegliche Scheinwerfer.',
      'LED-Waende und volle Lichtshow.'],
    cost: [380, 1400, 3600]
  },
  {
    id: 'sound', label: 'Soundanlage', max: 3, tier: 1,
    group: 'Technik',
    desc: ['Neue Stacks: Gäste bleiben länger.',
      'Subbass-Array: mehr Umsatz.',
      'Gigantisches Soundsystem: internationaler Standard.'],
    cost: [500, 1700, 4200]
  },
  {
    id: 'floor', label: 'Tanzfläche', max: 3, tier: 1,
    group: 'Innenbereich',
    desc: ['Größere Tanzfläche: +80 Kapazität.',
      'Zweiter Floor: +140 Kapazität.',
      'Dritter Floor: +220 Kapazität.'],
    cost: [800, 2200, 5000]
  },
  {
    id: 'bar', label: 'Bar', max: 3, tier: 1,
    group: 'Innenbereich',
    desc: ['Größere Bar: mehr Umsatz pro Gast.',
      'Zweite Bar: deutlich mehr Umsatz.',
      'Premium-Bar: maximaler Umsatz.'],
    cost: [450, 1500, 3800]
  },
  {
    id: 'vip', label: 'VIP-Bereich', max: 2, tier: 1,
    group: 'Innenbereich',
    desc: ['VIP-Lounge: VIPs geben deutlich mehr aus.',
      'Premium-Lounge mit eigenem Service.'],
    cost: [1500, 4000]
  },
  {
    id: 'comfort', label: 'Komfort', max: 2, tier: 0,
    group: 'Komfort',
    desc: ['Garderobe und bessere Toiletten: Ruf steigt schneller.',
      'Sitzbereiche und Belüftung: Gäste bleiben länger.'],
    cost: [600, 1800]
  },
  {
    id: 'backstage', label: 'Backstage', max: 2, tier: 1,
    group: 'Innenbereich',
    desc: ['Backstage-Bereich: Acts können gebucht werden.',
      'Künstler-Lounge: bessere Acts verfuegbar.'],
    cost: [1200, 3600]
  }
];

/** Sichtbare Club-Stufen. */
export const CLUB_TIERS = [
  { level: 1, label: 'KELLERCLUB', need: 0 },
  { level: 2, label: 'GROSSER EINGANG', need: 3 },
  { level: 3, label: 'NEUE RAEUME', need: 6 },
  { level: 4, label: 'ZWEITE TANZFLÄCHE', need: 10 },
  { level: 5, label: 'VIP-BEREICH', need: 14 },
  { level: 6, label: 'UNDERGROUND-KOMPLEX', need: 19 },
  { level: 7, label: 'TECHNO-TEMPEL', need: 24 }
];

export const RANKS = [
  { level: 1, label: 'ROOKIE', xp: 0 },
  { level: 2, label: 'DOOR STAFF', xp: 250 },
  { level: 3, label: 'SECURITY', xp: 700 },
  { level: 4, label: 'HEAD BOUNCER', xp: 1500 },
  { level: 5, label: 'SECURITY CHIEF', xp: 2800 },
  { level: 6, label: 'CLUB MANAGER', xp: 4800 }
];

export const TALENTS = [
  { id: 'street', label: 'Street Smarts', max: 3, desc: 'Verdächtige Gäste zeigen frueher Warnzeichen.' },
  { id: 'scanner', label: 'Routine', max: 3, desc: 'Alle Kontrollen laufen schneller ab.' },
  { id: 'charisma', label: 'Charisma', max: 3, desc: 'Gäste warten geduldiger, CALM wirkt staerker.' },
  { id: 'reputation', label: 'Reputation', max: 3, desc: 'Mehr Ruf pro richtiger Entscheidung.' },
  { id: 'management', label: 'Management', max: 3, desc: 'Upgrades kosten weniger, Bar bringt mehr.' }
];

export const RANDOM_EVENTS = [
  { id: 'blackout', label: 'STROMAUSFALL', desc: 'Licht und Scanner fallen kurz aus.', weight: 8 },
  { id: 'scannerFail', label: 'PRÜFGERÄT DEFEKT', desc: 'Das Dokumenten-Prüfgerät streikt.', weight: 10 },
  { id: 'rush', label: 'ANSTURM', desc: 'Eine grosse Gruppe trifft gleichzeitig ein.', weight: 14 },
  { id: 'celebrity', label: 'UNERWARTETER GAST', desc: 'Eine bekannte Person steht ploetzlich vorne.', weight: 8 },
  { id: 'complaint', label: 'BESCHWERDE', desc: 'Die Schlange wird unruhig.', weight: 12 },
  { id: 'influencerPost', label: 'INFLUENCER POSTET', desc: 'Der Club geht viral. Mehr Andrang, mehr Ruf.', weight: 7 },
  { id: 'artistLate', label: 'ACT VERSPAETET', desc: 'Der Künstler kommt später als geplant.', weight: 6 },
  { id: 'fakePass', label: 'FALSCHER BACKSTAGE-PASS', desc: 'Jemand behauptet, zur Crew zu gehoeren.', weight: 9 }
];

export const FIRST_NAMES = [
  'Mira', 'Jonas', 'Lena', 'Tarek', 'Nils', 'Sasha', 'Ada', 'Bruno', 'Kim', 'Elif',
  'Vito', 'Nora', 'Kaspar', 'Juno', 'Rico', 'Svea', 'Milan', 'Ida', 'Anton', 'Zoe',
  'Ferro', 'Malte', 'Nadja', 'Ole', 'Pia', 'Ravi', 'Toni', 'Ulla', 'Wanda', 'Yuri'
];

export const LAST_NAMES = [
  'Falk', 'Brandt', 'Vogel', 'Kern', 'Marek', 'Stein', 'Roth', 'Kilic', 'Sander', 'Novak',
  'Bauer', 'Lorenz', 'Haas', 'Petrov', 'Weiss', 'Dorn', 'Kaiser', 'Berg', 'Frost', 'Neumann'
];
