/** Deterministischer PRNG (mulberry32) + Hilfsfunktionen. */

export function createRng(seed = Date.now() >>> 0) {
  let a = seed >>> 0;
  const rng = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  rng.seed = seed;
  return rng;
}

export function randRange(rng, min, max) {
  return min + rng() * (max - min);
}

export function randInt(rng, min, max) {
  return Math.floor(randRange(rng, min, max + 1));
}

export function pick(rng, arr) {
  if (!arr || arr.length === 0) return undefined;
  return arr[Math.min(arr.length - 1, Math.floor(rng() * arr.length))];
}

/** Gewichtete Auswahl. `weightOf` liest das Gewicht aus dem Element. */
export function weightedPick(rng, arr, weightOf = (x) => x.weight ?? 1) {
  let total = 0;
  for (const item of arr) total += Math.max(0, weightOf(item));
  if (total <= 0) return pick(rng, arr);
  let roll = rng() * total;
  for (const item of arr) {
    roll -= Math.max(0, weightOf(item));
    if (roll <= 0) return item;
  }
  return arr[arr.length - 1];
}

export function chance(rng, p) {
  return rng() < p;
}

export function clamp(value, min, max) {
  return value < min ? min : value > max ? max : value;
}

export function lerp(a, b, t) {
  return a + (b - a) * t;
}
