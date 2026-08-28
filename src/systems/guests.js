/**
 * Guest System: erzeugt Gäste mit versteckten Eigenschaften.
 * Die Wahrheit (`truth`) ist für den Spieler unsichtbar und wird nur
 * über Kontrollen (ID, Scan, Abtasten, Gespräch, Alkoholtest) aufgedeckt.
 */

import {
  ARCHETYPES, ITEMS, ID_ISSUES, TUNING, FIRST_NAMES, LAST_NAMES, GAME_DATE,
  ZONES, IMPAIRMENT_SIGNS
} from '../data/config.js';
import { difficultyProfile } from './difficulty.js';
import { LINES, PERSONALITIES } from '../data/dialogue.js';
import { randRange, randInt, pick, weightedPick, chance, clamp } from '../core/rng.js';

let guestSerial = 0;

export function createGuest(rng, ctx = {}) {
  const {
    event = null, reputation = 40, patienceMul = 1, nightIndex = 1, forceArchetype = null
  } = ctx;

  const archetype = forceArchetype
    ? ARCHETYPES.find((a) => a.id === forceArchetype) ?? ARCHETYPES[0]
    : weightedPick(rng, ARCHETYPES, (a) => archetypeWeight(a, event, reputation));

  const personality = choosePersonality(rng, archetype);
  const drunk = clamp(randRange(rng, archetype.drunk[0], archetype.drunk[1]), 0, 1);
  const risk = clamp(
    randRange(rng, archetype.risk[0], archetype.risk[1]) + (event?.trouble ?? 1 - 1) * 0.1,
    0, 1
  );

  // Alter: die meisten sind erwachsen, manche zu jung.
  const underage = chance(rng, underageChance(archetype, event));
  const realAge = underage ? randInt(rng, 15, 17) : randInt(rng, 18, 46);

  // Ausweis-Problem
  const badId = chance(rng, archetype.badIdChance * (event?.trouble ?? 1));
  const idIssues = [];
  if (underage) {
    // Zu junge Gäste faelschen fast immer das Dokument.
    idIssues.push(chance(rng, 0.7) ? 'age' : 'photo');
  }
  if (badId) {
    const issue = pick(rng, ID_ISSUES).id;
    if (!idIssues.includes(issue)) idIssues.push(issue);
  }

  const profile = difficultyProfile(nightIndex);

  // --- Gepäck: nur wer eine Tasche dabei hat, hat auch eine Zone dafür ---
  const hasBag = chance(rng, archetype.id === 'crew' ? 0.8 : 0.42);
  const zoneIds = ZONES.filter((z) => !z.needsBag || hasBag).map((z) => z.id);

  // --- Verbotener Gegenstand (höchstens einer pro Gast) ---
  const contrabandChance = archetype.contrabandChance * (event?.trouble ?? 1) + risk * 0.15;
  let contraband = null;
  let contrabandZone = null;
  if (chance(rng, clamp(contrabandChance, 0, 0.85))) {
    const maxSeverity = risk > 0.6 ? 3 : 2;
    const pool = ITEMS.filter((i) => i.forbidden && i.severity <= maxSeverity
      && i.zones.some((z) => zoneIds.includes(z)));
    if (pool.length) {
      contraband = weightedPick(rng, pool, (i) => 4 - i.severity);
      contrabandZone = pick(rng, contraband.zones.filter((z) => zoneIds.includes(z)));
    }
  }

  // --- Was in jeder Zone steckt (harmloses Zeug als Ablenkung) ---
  const carried = {};
  const used = new Set();
  for (const zone of ZONES) {
    if (!zoneIds.includes(zone.id)) continue;
    // Niemand hat zwei Feuerzeuge dabei: pro Gast jedes Ding nur einmal.
    const harmless = ITEMS.filter(
      (i) => !i.forbidden && i.zones.includes(zone.id) && !used.has(i.id));
    const count = Math.min(
      harmless.length,
      randInt(rng, zone.capacity[0], zone.capacity[1]) + profile.decoyBonus);
    const picked = [];
    for (let i = 0; i < count; i++) {
      const pool = harmless.filter((it) => !picked.includes(it));
      if (!pool.length) break;
      const item = pick(rng, pool);
      used.add(item.id);
      picked.push(item);
    }
    if (contraband && contrabandZone === zone.id) {
      picked.splice(randInt(rng, 0, picked.length), 0, contraband);
    }
    carried[zone.id] = picked;
  }
  const items = Object.values(carried).flat();

  // --- Substanzeinfluss: ab der vierten Nacht ein eigenes Thema ---
  const impaired = chance(rng, profile.impairedChance * (1 + risk))
    ? clamp(randRange(rng, 0.45, 1) * (archetype.id === 'trouble' ? 1.1 : 1), 0, 1)
    : 0;
  const signs = IMPAIRMENT_SIGNS
    .filter((sign) => impaired >= sign.min && chance(rng, profile.signClarity))
    .map((sign) => sign.id);

  const vip = chance(rng, archetype.vip * (event?.vip ?? 1) * 0.6) || archetype.id === 'vip';
  const spendBase = randRange(rng, archetype.spend[0], archetype.spend[1]);
  const spend = spendBase * (1 + reputation / 220) * (event?.spend ?? 1);

  const blacklisted = chance(rng, risk > 0.7 ? 0.25 : 0.03);

  const name = `${pick(rng, FIRST_NAMES)} ${pick(rng, LAST_NAMES)}`;
  const docName = idIssues.includes('name') ? `${pick(rng, FIRST_NAMES)} ${pick(rng, LAST_NAMES)}` : name;

  // Geburtsdatum: bei Manipulation zeigt das Dokument ein Alter ueber 18,
  // die Ziffern sind dann aber sichtbar veraendert (doc.tampered).
  const tampered = idIssues.includes('age');
  const shownAge = tampered ? Math.max(TUNING.minAge, realAge + randInt(rng, 2, 6)) : realAge;
  const birth = birthString(rng, shownAge);

  // Ausweisfoto: bei Foto-Faelschung deutlich anderes Aussehen als der Gast.
  const look = {
    skin: randInt(rng, 0, 5),
    outfit: randInt(rng, 0, 7),
    hair: randInt(rng, 0, 6),
    height: randRange(rng, 0.92, 1.1),
    bulk: randRange(rng, 0.88, 1.14)
  };
  const photoLook = idIssues.includes('photo')
    ? { ...look, skin: (look.skin + 2 + randInt(rng, 0, 2)) % 6, hair: (look.hair + 3) % 7 }
    : { ...look };

  const guest = {
    id: `g${++guestSerial}`,
    name,
    archetype: archetype.id,
    archetypeLabel: archetype.label,
    personality,
    backstage: !!archetype.backstage,
    inspector: !!archetype.inspector,
    seed: Math.floor(rng() * 1e9),

    // Sichtbare Optik
    look,

    // Versteckte Wahrheit
    truth: {
      age: realAge,
      underage,
      idIssues,
      idValid: idIssues.length === 0,
      drunk,
      risk,
      blacklisted,
      vip,
      spend,
      items,
      carried,
      hasBag,
      zoneIds,
      contraband,
      contrabandZone,
      impaired,
      impairmentSigns: signs,
      repValue: archetype.rep
    },

    // Das vorgezeigte Dokument - genau das, was der Spieler zu sehen bekommt
    doc: {
      name: docName,
      birth,
      expiry: idIssues.includes('expired')
        ? `${randInt(rng, 2021, 2025)}-${pad(randInt(rng, 1, 12))}-${pad(randInt(rng, 1, 28))}`
        : `${randInt(rng, 2027, 2033)}-${pad(randInt(rng, 1, 12))}-${pad(randInt(rng, 1, 28))}`,
      marksOk: !idIssues.includes('marks'),
      tampered,
      photoLook,
      number: `${String.fromCharCode(65 + randInt(rng, 0, 25))}${randInt(rng, 10000000, 99999999)}`,
      issuer: pick(rng, ['BUNDESREPUBLIK', 'REPUBLIK', 'KANTON', 'STAAT']),
      /** Nur intern: das Alter, das das Dokument behauptet. */
      shownAge
    },

    // Zustand in der Warteschlange
    patience: TUNING.patienceBase * archetype.patience * patienceMul * (vip ? 0.7 : 1),
    patienceMax: TUNING.patienceBase * archetype.patience * patienceMul * (vip ? 0.7 : 1),
    mood: personality === 'aggressive' ? 0.25 : personality === 'annoyed' ? 0.45 : 0.75,
    x: 0, y: 0, targetX: 0, targetY: 0,
    walkPhase: rng() * Math.PI * 2,
    swayPhase: rng() * Math.PI * 2,
    state: 'queue', // queue | door | admitted | rejected | left
    said: null,
    saidTimer: 0
  };

  guest.difficulty = nightIndex;
  return guest;
}

function pad(n) {
  return String(n).padStart(2, '0');
}

/**
 * Erzeugt ein Geburtsdatum, das am Spieldatum exakt das gewünschte Alter ergibt.
 * (Wer dieses Jahr noch nicht Geburtstag hatte, ist ein Jahr früher geboren.)
 */
function birthString(rng, age) {
  const month = randInt(rng, 1, 12);
  const day = randInt(rng, 1, 28);
  const hadBirthday = month < GAME_DATE.month || (month === GAME_DATE.month && day <= GAME_DATE.day);
  const year = GAME_DATE.year - age - (hadBirthday ? 0 : 1);
  return `${year}-${pad(month)}-${pad(day)}`;
}

function underageChance(archetype, event) {
  const base = archetype.id === 'trouble' ? 0.2 : archetype.id === 'tourist' ? 0.12 : 0.07;
  return clamp(base * (event?.trouble ?? 1), 0, 0.4);
}

function archetypeWeight(a, event, reputation) {
  let w = a.weight;
  if (a.vip > 0) w *= (event?.vip ?? 1) * (0.6 + reputation / 90);
  if (a.id === 'trouble') w *= event?.trouble ?? 1;
  if (a.id === 'influencer' || a.id === 'scene') w *= 0.5 + reputation / 80;
  if (a.id === 'inspector' || a.id === 'insider') w *= event?.inspection ? 3 : 1;
  return Math.max(0.1, w);
}

function choosePersonality(rng, archetype) {
  const weights = {
    polite: 3, annoyed: 2, drunk: 1, arrogant: 1, aggressive: 0.6, nervous: 1
  };
  if (archetype.id === 'trouble') { weights.aggressive = 5; weights.drunk = 3; weights.polite = 0.4; }
  if (archetype.id === 'vip') { weights.arrogant = 6; weights.polite = 2; weights.aggressive = 0.5; }
  if (archetype.id === 'influencer') { weights.arrogant = 4; weights.polite = 2; }
  if (archetype.id === 'local') { weights.polite = 5; weights.annoyed = 2; }
  if (archetype.id === 'mystery') { weights.nervous = 5; }
  const entries = PERSONALITIES.map((p) => ({ p, w: weights[p] ?? 1 }));
  return weightedPick(rng, entries, (e) => e.w).p;
}

/** Zufällige Zeile passend zur Situation. */
export function guestLine(rng, guest, situation) {
  const set = LINES[guest.personality] ?? LINES.polite;
  const pool = set[situation] ?? set.talk;
  return pick(rng, pool);
}

/**
 * Regelwerk: darf dieser Gast rein?
 * Gibt die Liste der objektiven Verstöße zurück (leer = Einlass korrekt).
 */
export function violationsOf(guest) {
  const v = [];
  const t = guest.truth;
  if (t.underage || t.age < TUNING.minAge) v.push({ id: 'underage', label: 'Minderjährig', severity: 3 });
  if (!t.idValid) v.push({ id: 'id', label: 'Ausweis ungültig', severity: 2 });
  if (t.drunk >= TUNING.drunkRejectThreshold) v.push({ id: 'drunk', label: 'Zu betrunken', severity: 1 });
  if (t.contraband) {
    v.push({
      id: 'item', label: `Verbotener Gegenstand: ${t.contraband.label}`,
      severity: t.contraband.severity
    });
  }
  if ((t.impaired ?? 0) >= 0.6) {
    v.push({ id: 'impaired', label: 'Steht sichtbar unter Einfluss', severity: 2 });
  }
  if (t.blacklisted) v.push({ id: 'blacklist', label: 'Hausverbot', severity: 2 });
  return v;
}

export function shouldReject(guest) {
  return violationsOf(guest).length > 0;
}

/** Zeigt der Gast sichtbare Warnzeichen (für Street-Smarts / Rendering)? */
export function visibleTells(guest, talentStreet = 0) {
  const tells = [];
  const t = guest.truth;
  if (t.drunk > 0.55) tells.push('schwankt');
  for (const sign of t.impairmentSigns ?? []) {
    tells.push({ pupils: 'weite Pupillen', sweat: 'schwitzt', jaw: 'mahlender Kiefer',
      shake: 'zittert', absent: 'wirkt abwesend' }[sign] ?? sign);
  }
  if (t.risk > 0.65 && talentStreet >= 1) tells.push('unruhig');
  if (t.contraband && talentStreet >= 2 && t.contraband.severity >= 2) tells.push('greift staendig zur Jacke');
  if (t.underage && talentStreet >= 3) tells.push('wirkt sehr jung');
  if (t.vip) tells.push('teure Kleidung');
  return tells;
}

export function resetGuestSerial() {
  guestSerial = 0;
}
