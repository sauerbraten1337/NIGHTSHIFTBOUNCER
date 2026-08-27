/** Farbwelt: Beton, Nacht, rote Warnlichter, kaltes Neon. */

export const PAL = {
  night: '#090b10',
  asphalt: '#151922',
  asphaltLight: '#1d232e',
  concrete: '#272d38',
  concreteDark: '#1a1f28',
  concreteLight: '#39414f',
  line: '#39414f',
  red: '#ff2f3c',
  redDim: '#8c1620',
  cyan: '#39d7ff',
  amber: '#ffb638',
  green: '#4ce08a',
  white: '#e8ecf2',
  grey: '#8b93a1',
  purple: '#8b5cff'
};

export const SKIN = ['#f0c9a4', '#dfa87a', '#c3855c', '#9a6440', '#71462b', '#4e3020'];

export const OUTFIT = [
  '#1c1f26', '#24262e', '#2b1f2f', '#12232b', '#33202a', '#1a2a1f', '#2e2a1c', '#202433'
];

export const HAIR = ['#141519', '#2b2019', '#4a3524', '#6b6f78', '#8e2f3a', '#243a52', '#d8d3c8'];

export function withAlpha(hex, alpha) {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const r = parseInt(full.slice(0, 2), 16);
  const g = parseInt(full.slice(2, 4), 16);
  const b = parseInt(full.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}
