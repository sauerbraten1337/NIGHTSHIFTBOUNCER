/**
 * Der eigene Türsteher: Aussehen und Name.
 *
 * Wird einmal beim Start erstellt (Charaktereditor) und lässt sich später
 * am Kleiderschrank im Büro jederzeit ändern. Die Figur taucht im
 * Nachtabschluss und im Büro auf - gezeichnet mit derselben `drawFigure`
 * wie alle anderen Menschen im Spiel.
 */

import { SKIN, HAIR, OUTFIT } from '../render/palette.js';

/** Auswahl für den Streifen auf der Jacke - das persönliche Erkennungszeichen. */
export const ACCENTS = [
  { id: 'red', label: 'ROT', color: '#ff2f3c' },
  { id: 'cyan', label: 'CYAN', color: '#39d7ff' },
  { id: 'amber', label: 'AMBER', color: '#ffb638' },
  { id: 'green', label: 'GRÜN', color: '#4ce08a' },
  { id: 'purple', label: 'VIOLETT', color: '#8b5cff' },
  { id: 'none', label: 'OHNE', color: null }
];

export const HAIR_STYLES = [
  { id: 0, label: 'KURZ' },
  { id: 1, label: 'VOLL' },
  { id: 2, label: 'ZURÜCK' },
  { id: 3, label: 'LANG' }
];

export const BUILDS = [
  { id: 'schlank', label: 'SCHLANK', bulk: 0.92 },
  { id: 'normal', label: 'NORMAL', bulk: 1.05 },
  { id: 'kräftig', label: 'KRÄFTIG', bulk: 1.18 },
  { id: 'schrank', label: 'SCHRANK', bulk: 1.32 }
];

const FIRST_NAMES = [
  'ALEX', 'MIKA', 'JONAS', 'SAM', 'NURI', 'ROBIN', 'KAY', 'TONI',
  'LENA', 'DENIZ', 'MARLON', 'SASCHA', 'ELI', 'FINN', 'JUNO'
];

/** Ein zufälliger, aber immer plausibler Türsteher. */
export function createCharacter(random = Math.random) {
  const pick = (n) => Math.floor(random() * n);
  return {
    name: FIRST_NAMES[pick(FIRST_NAMES.length)],
    skin: pick(SKIN.length),
    hair: pick(HAIR.length),
    hairStyle: pick(HAIR_STYLES.length),
    outfit: pick(OUTFIT.length),
    build: BUILDS[1 + pick(BUILDS.length - 1)].id,
    beard: random() > 0.5,
    accent: ACCENTS[pick(ACCENTS.length - 1)].id,
    created: false
  };
}

/** Fehlende Felder auffüllen - alte Spielstände kennen den Charakter nicht. */
export function normalizeCharacter(character) {
  const base = createCharacter(() => 0.5);
  const merged = { ...base, ...(character ?? {}) };
  merged.name = String(merged.name ?? '').trim().slice(0, 14).toUpperCase() || base.name;
  merged.skin = clampIndex(merged.skin, SKIN.length);
  merged.hair = clampIndex(merged.hair, HAIR.length);
  merged.hairStyle = clampIndex(merged.hairStyle, HAIR_STYLES.length);
  merged.outfit = clampIndex(merged.outfit, OUTFIT.length);
  if (!BUILDS.some((b) => b.id === merged.build)) merged.build = BUILDS[1].id;
  if (!ACCENTS.some((a) => a.id === merged.accent)) merged.accent = ACCENTS[0].id;
  merged.beard = !!merged.beard;
  merged.created = !!merged.created;
  return merged;
}

function clampIndex(value, length) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return ((Math.round(n) % length) + length) % length;
}

/** Umrechnung in das `look`-Objekt, das `drawFigure` versteht. */
export function characterLook(character) {
  const c = normalizeCharacter(character);
  return {
    skin: c.skin,
    hair: c.hair,
    hairStyle: c.hairStyle,
    outfit: c.outfit,
    beard: c.beard,
    bulk: BUILDS.find((b) => b.id === c.build)?.bulk ?? 1.05
  };
}

export function accentColor(character) {
  return ACCENTS.find((a) => a.id === normalizeCharacter(character).accent)?.color ?? null;
}
