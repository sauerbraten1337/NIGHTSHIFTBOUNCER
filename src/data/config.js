/**
 * Zentrale Tuning-Werte, Datentabellen und Balancing-Konstanten.
 * Reines Daten-Modul: keine DOM-Zugriffe, keine Seiteneffekte.
 */

export const CLUB_NAME = 'NULLWERK';

export const TUNING = {
  // Die Nacht endet NICHT nach Zeit, sondern wenn die Schicht abgearbeitet ist.
  // Die Uhr laeuft nur noch im Hintergrund fuer Stimmung, Musik und Ereignisse.
  nightStartMinute: 0,
  nightEndMinute: 300,
  minutesPerSecond: 0.8,

  /** So viele Gaeste muessen pro Nacht abgefertigt werden. */
  guestsPerNight: 16,
  guestsPerNightGrowth: 2,     // pro Nacht mehr
  guestsPerNightMax: 40,

  /** Praemie fuer jede selbst gefundene Unregelmaessigkeit. */
  findingBonus: 35,

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
 * Gruppen verbotener Sachen. NUR diese Gruppen stehen in der Hausordnung -
 * nicht die einzelnen Gegenstände. Der Spieler muss also selbst einordnen,
 * ob ein Schlagring eine Waffe ist und ob ein Fläschchen ohne Etikett unter
 * "unklare Substanzen" fällt. Abgelesen werden kann das nicht mehr.
 */
export const ITEM_CATEGORIES = [
  {
    id: 'weapon', label: 'Waffen und gefährliche Gegenstände', severity: 3,
    rule: 'Stich- und Schneidwerkzeuge, Schlag- und Elektrogeräte sowie Reizstoffsprays jeder Art.'
  },
  {
    id: 'pyro', label: 'Pyrotechnik und offenes Feuer', severity: 3,
    rule: 'Alles, was gezündet wird oder brennt, funkt oder qualmt. Feuerzeuge bleiben erlaubt.'
  },
  {
    id: 'drugs', label: 'Unklare Substanzen', severity: 2,
    rule: 'Päckchen, Döschen, Briefchen und Fläschchen ohne lesbare Beschriftung. '
      + 'Beschriftete Medikamente aus der Apotheke sind zugelassen.'
  },
  {
    id: 'tool', label: 'Werkzeug', severity: 2,
    rule: 'Handwerkszeug jeder Grösse, auch zusammengeklappt.'
  },
  {
    id: 'glass', label: 'Glas und mitgebrachte Getränke', severity: 1,
    rule: 'Behälter aus Glas und Metall mit Inhalt. Leere Plastikflaschen sind zugelassen.'
  },
  {
    id: 'media', label: 'Professionelle Aufnahmetechnik', severity: 1,
    rule: 'Kameras mit Wechselobjektiv, Actioncams, Objektive, Stative. Handys bleiben erlaubt.'
  },
  {
    id: 'light', label: 'Blendlicht', severity: 1,
    rule: 'Laser und starke Blendleuchten, die in die Menge gerichtet werden können.'
  }
];

export function categoryById(id) {
  return ITEM_CATEGORIES.find((c) => c.id === id) ?? null;
}

/**
 * Gegenstände, die beim Abtasten zum Vorschein kommen.
 * Die meisten sind völlig harmlos - genau darum muss man hinsehen.
 * `zones` sagt, wo ein Gegenstand plausibel steckt, `cat` die Gruppe der
 * Hausordnung (nur bei verbotenen Sachen gesetzt).
 */
const RAW_ITEMS = [
  // --- harmlos ---
  { id: 'gum', label: 'Kaugummi', zones: ['pockets', 'bag'] },
  { id: 'phone', label: 'Handy', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'keys', label: 'Schlüsselbund', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'lighter', label: 'Feuerzeug', zones: ['jacket', 'pockets'] },
  { id: 'smokes', label: 'Zigaretten', zones: ['jacket', 'bag'] },
  { id: 'wallet', label: 'Portemonnaie', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'earbuds', label: 'Kopfhörer', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'coins', label: 'Kleingeld', zones: ['pockets'] },
  { id: 'tissues', label: 'Taschentücher', zones: ['jacket', 'bag'] },
  { id: 'balm', label: 'Lippenpflege', zones: ['pockets', 'bag'] },
  { id: 'mints', label: 'Pfefferminz', zones: ['pockets', 'bag'] },
  { id: 'charger', label: 'Ladekabel', zones: ['bag'] },
  { id: 'bottle', label: 'Plastikflasche, leer', zones: ['bag'] },
  { id: 'book', label: 'Notizbuch', zones: ['bag'] },
  { id: 'powerbank', label: 'Powerbank', zones: ['jacket', 'bag'] },
  { id: 'shades', label: 'Sonnenbrille', zones: ['jacket', 'bag'] },
  { id: 'meds', label: 'Tabletten, beschriftet', zones: ['pockets', 'bag'] },
  { id: 'deo', label: 'Deoroller', zones: ['bag'] },
  { id: 'selfie', label: 'Selfiestick', zones: ['bag'] },
  { id: 'pen', label: 'Kugelschreiber', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'snack', label: 'Müsliriegel', zones: ['jacket', 'bag'] },
  { id: 'earplugs', label: 'Ohrstöpsel', zones: ['pockets', 'bag'] },
  { id: 'vape', label: 'E-Zigarette', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'ticket', label: 'Ticket', zones: ['jacket', 'pockets'] },

  // --- Waffen: es gibt viele, in der Hausordnung steht nur "Waffen" ---
  { id: 'blade', label: 'Klappmesser', cat: 'weapon', zones: ['jacket', 'pockets'] },
  { id: 'cutter', label: 'Cuttermesser', cat: 'weapon', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'butterfly', label: 'Butterflymesser', cat: 'weapon', zones: ['jacket', 'pockets'] },
  { id: 'knuckles', label: 'Schlagring', cat: 'weapon', zones: ['jacket', 'pockets'] },
  { id: 'baton', label: 'Teleskopschlagstock', cat: 'weapon', zones: ['jacket', 'bag'] },
  { id: 'stun', label: 'Elektroschocker', cat: 'weapon', zones: ['jacket', 'bag'] },
  { id: 'spray', label: 'Reizgasspray', cat: 'weapon', severity: 2, zones: ['jacket', 'pockets', 'bag'] },

  // --- Pyrotechnik ---
  { id: 'flare', label: 'Bengalfackel', cat: 'pyro', zones: ['bag'] },
  { id: 'banger', label: 'Böller', cat: 'pyro', severity: 2, zones: ['jacket', 'pockets', 'bag'] },
  { id: 'smokepot', label: 'Rauchtopf', cat: 'pyro', zones: ['bag'] },
  { id: 'sparkler', label: 'Wunderkerzen', cat: 'pyro', severity: 1, zones: ['jacket', 'bag'] },

  // --- unklare Substanzen ---
  { id: 'substance', label: 'Unbeschriftetes Päckchen', cat: 'drugs', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'pills', label: 'Döschen mit losen Pillen', cat: 'drugs', zones: ['pockets', 'bag'] },
  { id: 'powder', label: 'Briefchen mit Pulver', cat: 'drugs', zones: ['jacket', 'pockets'] },
  { id: 'vial', label: 'Fläschchen ohne Etikett', cat: 'drugs', zones: ['pockets', 'bag'] },

  // --- Werkzeug ---
  { id: 'tool', label: 'Multitool', cat: 'tool', zones: ['jacket', 'pockets', 'bag'] },
  { id: 'screwdriver', label: 'Schraubendreher', cat: 'tool', zones: ['jacket', 'bag'] },
  { id: 'pliers', label: 'Kombizange', cat: 'tool', zones: ['bag'] },

  // --- Glas und Getränke ---
  { id: 'glass', label: 'Glasflasche', cat: 'glass', zones: ['jacket', 'bag'] },
  { id: 'flask', label: 'Flachmann', cat: 'glass', zones: ['jacket', 'pockets'] },
  { id: 'wine', label: 'Weinflasche', cat: 'glass', zones: ['bag'] },

  // --- Aufnahmetechnik ---
  { id: 'camera', label: 'Profikamera', cat: 'media', zones: ['bag'] },
  { id: 'lens', label: 'Teleobjektiv', cat: 'media', zones: ['bag'] },
  { id: 'actioncam', label: 'Actioncam', cat: 'media', zones: ['jacket', 'pockets', 'bag'] },

  // --- Blendlicht ---
  { id: 'laser', label: 'Laserpointer', cat: 'light', zones: ['jacket', 'pockets'] },
  { id: 'blinder', label: 'Blendleuchte', cat: 'light', severity: 2, zones: ['jacket', 'bag'] }
];

/**
 * `forbidden` und `severity` ergeben sich aus der Gruppe - so kann keine
 * Tabellenzeile aus Versehen widersprüchlich werden.
 */
export const ITEMS = RAW_ITEMS.map((item) => {
  const category = item.cat ? categoryById(item.cat) : null;
  return {
    ...item,
    cat: item.cat ?? null,
    catLabel: category?.label ?? null,
    forbidden: !!category,
    severity: item.severity ?? category?.severity ?? 0
  };
});

export function itemById(id) {
  return ITEMS.find((i) => i.id === id) ?? null;
}

/** Alle verbotenen Sachen einer Gruppe (fürs Balancing und für Tests). */
export function itemsOfCategory(catId) {
  return ITEMS.filter((i) => i.cat === catId);
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
    night: 5, id: 'aggression', label: 'ÜBERGRIFFE',
    desc: 'Manche lassen sich das Abweisen nicht gefallen und gehen auf dich los. '
      + 'Dann zählt nur noch, wie schnell du die eingeblendeten Tasten triffst.'
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

/**
 * Die Punkte, die der Spieler auf seinem Notizzettel selbst beurteilt.
 * `truth` sagt dem Spiel, ob die Beurteilung am Ende zutraf.
 */
export const NOTE_TOPICS = [
  { id: 'document', label: 'Dokument', area: 'outside', hint: 'Foto, Name, Datum, Merkmale' },
  { id: 'person', label: 'Zustand der Person', area: 'outside', hint: 'Auftreten, Augen, Hände' },
  { id: 'statement', label: 'Aussage', area: 'outside', hint: 'Passt, was er sagt, zum Rest?' },
  { id: 'items', label: 'Mitgeführte Sachen', area: 'airlock', hint: 'Jacke, Taschen, Beutel' },
  { id: 'alcohol', label: 'Alkoholwert', area: 'airlock', hint: 'Messwert gegen Grenzwert' }
];

/** Punkte der Checkliste (Seite 1) - der Spieler hakt selbst ab. */
export const CHECKLIST = [
  { id: 'id', label: 'Ausweis verlangt', area: 'outside' },
  { id: 'fields', label: 'Alle Felder geprüft', area: 'outside' },
  { id: 'talk', label: 'Person angesprochen', area: 'outside' },
  { id: 'look', label: 'Person angesehen', area: 'outside' },
  { id: 'search', label: 'Abgetastet', area: 'airlock' },
  { id: 'alcohol', label: 'Alkoholtest gemacht', area: 'airlock' }
];

/**
 * Sichtbare Anzeichen für Substanzeinfluss (abstrakt, ohne Konsumdetails).
 *
 * Alles hier ist von aussen erkennbar, bevor man den Gast überhaupt
 * anspricht: rote Augen, fahle Haut, Augenringe, ein glasiger Blick. Wer
 * hinsieht, braucht dafür kein Gerät.
 */
export const IMPAIRMENT_SIGNS = [
  { id: 'redEyes', label: 'gerötete Augen', min: 0.3, face: true },
  { id: 'pupils', label: 'weite Pupillen', min: 0.35, face: true },
  { id: 'glassy', label: 'glasiger Blick', min: 0.4, face: true },
  { id: 'absent', label: 'wirkt abwesend', min: 0.45 },
  { id: 'rings', label: 'dunkle Augenringe', min: 0.5, face: true },
  { id: 'sweat', label: 'schwitzt stark', min: 0.5, face: true },
  { id: 'pale', label: 'fahle Haut', min: 0.55, face: true },
  { id: 'jaw', label: 'mahlender Kiefer', min: 0.6, face: true },
  { id: 'restless', label: 'steht keine Sekunde still', min: 0.65 },
  { id: 'shake', label: 'zitternde Hände', min: 0.7 }
];

export const ID_ISSUES = [
  { id: 'expired', label: 'Ausweis abgelaufen' },
  { id: 'photo', label: 'Foto passt nicht' },
  { id: 'name', label: 'Name unstimmig' },
  { id: 'marks', label: 'Sicherheitsmerkmale fehlen' },
  { id: 'age', label: 'Geburtsdatum manipuliert' }
];

/**
 * Was gerade aktiv ist. Der Fokus liegt vorerst allein auf der Kontrolle an
 * der Tür: Sondernächte, Zufallsereignisse, Acts und ungeduldige Gäste sind
 * abgeschaltet. Zum Wiedereinschalten reicht ein `true`.
 */
export const FEATURES = {
  nightEvents: false,      // Sondernächte (Rave, VIP Night, Inspection, Chaos)
  randomEvents: false,     // Stromausfall, Promi, Ansturm, Beschwerden
  artists: false,          // Act am Hintereingang
  queueImpatience: false,  // Gäste verlassen die Schlange
  aggression: true         // Gäste gehen auf den Türsteher los (Abwehr per Taste)
};

/**
 * Tasten, die bei einem Angriff auf dem Bildschirm erscheinen. Bewusst weit
 * auseinander und nicht mit den Aktionstasten belegt, damit man im Reflex
 * nicht aus Versehen jemanden einlässt.
 */
export const DEFENSE_KEYS = [
  { key: 'KeyQ', label: 'Q' },
  { key: 'KeyW', label: 'W' },
  { key: 'KeyE', label: 'E' },
  { key: 'KeyR', label: 'R' },
  { key: 'KeyA', label: 'A' },
  { key: 'KeyS', label: 'S' },
  { key: 'KeyD', label: 'D' },
  { key: 'KeyF', label: 'F' }
];

/**
 * Abwehr von Angriffen.
 *
 * Ein Gast rastet nur selten aus - und wenn, dann kommt er auf einen zu und
 * man hat wenige Sekunden, die eingeblendeten Tasten zu treffen.
 */
export const AGGRESSION = {
  /** Grundchance, dass ein Gast beim Abweisen ausrastet. */
  rejectChance: 0.07,
  /** Chance pro Sekunde, dass er schon während der Kontrolle ausrastet. */
  idleChancePerSecond: 0.004,
  /** Erst ab dieser Nacht kann es passieren (Tutorial bleibt aussen vor). */
  minNight: 5,

  /** Anlauf: so lange rennt er auf einen zu, bevor die erste Taste kommt. */
  chargeTime: 0.9,
  /** Wie viele Tasten muss man treffen? */
  keys: [3, 5],
  /** Zeitfenster für die erste Taste, danach wird es enger. */
  keyTime: 1.5,
  keyTimeStep: 0.12,
  keyTimeMin: 0.7,
  /** So viele Fehlgriffe oder verpasste Fenster verzeiht die Abwehr. */
  strikes: 2,
  /** Wie lange steht das Ergebnis im Bild, bevor der Gast rausfliegt? */
  resultTime: 1.4,

  /** Belohnung für eine saubere Abwehr. */
  winRep: 1.6,
  winBonus: 60,
  winXp: 20,
  /** Kosten, wenn man ihn nicht abwehrt. */
  failRep: -3.5,
  failCost: 220,
  /** Wie lange ist der Spieler danach benommen und kann nichts tun? */
  failStun: 2.2
};

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
    id: 'scanner', label: 'Prüfplatz', max: 3, tier: 1,
    group: 'Sicherheit',
    desc: ['Bessere Lampe am Pult: du arbeitest schneller.',
      'Ordentlicher Prüftisch: Kontrollen gehen deutlich zügiger.',
      'Voll ausgestatteter Prüfplatz: schnellstmögliche Abfertigung.'],
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
    desc: ['Crowd-Monitoring: senkt den Schaden bei Zwischenfällen.',
      'Lückenlose Aufzeichnung: noch weniger Schaden.'],
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
