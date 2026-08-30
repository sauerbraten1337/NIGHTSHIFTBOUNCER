/**
 * Einstellungen: Bild, Ton und Spiel - dauerhaft im localStorage.
 *
 * Alles hier ist reine Datenhaltung plus ein kleiner Verteiler: wer etwas
 * ändert, ruft `setSetting`, und jeder Teil des Spiels, der davon betroffen
 * ist (Renderer, Audio), hört über `onSettingsChange` zu.
 */

const KEY = 'nullwerk.settings.v1';

/**
 * Auflösung des Zeichenpuffers. "AUTO" folgt dem Bildschirm, alles andere
 * rechnet auf eine feste Höhe - niedriger heisst schneller, höher heisst
 * schärfer.
 */
export const RESOLUTIONS = [
  { id: 'auto', label: 'AUTO', note: 'Folgt dem Bildschirm (bis 2×)' },
  { id: 'native', label: 'NATIV', note: 'Ein Bildpunkt pro CSS-Pixel' },
  { id: '540', label: '960 × 540', note: 'Sehr schnell, weich', height: 540 },
  { id: '720', label: '1280 × 720', note: 'Schnell', height: 720 },
  { id: '900', label: '1600 × 900', note: 'Ausgewogen', height: 900 },
  { id: '1080', label: '1920 × 1080', note: 'Scharf', height: 1080 },
  { id: '1440', label: '2560 × 1440', note: 'Sehr scharf', height: 1440 },
  { id: '2160', label: '3840 × 2160', note: 'Nur für starke Rechner', height: 2160 }
];

/** Grösse der Bedienoberfläche - manche Bildschirme sind sehr gross. */
export const UI_SCALES = [
  { id: 'small', label: 'KLEIN', value: 0.9 },
  { id: 'normal', label: 'NORMAL', value: 1 },
  { id: 'large', label: 'GROSS', value: 1.12 },
  { id: 'huge', label: 'SEHR GROSS', value: 1.25 }
];

export const DEFAULTS = {
  resolution: 'auto',
  uiScale: 'normal',
  effects: true,        // Scanlines, Vignette, Nebel
  showFps: false,
  tutorial: true,
  master: 0.9,
  music: 0.5,
  sfx: 0.55,
  muted: false
};

let current = { ...DEFAULTS, ...read() };
const listeners = new Set();

function read() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return {};
    const data = JSON.parse(raw);
    return data && typeof data === 'object' ? data : {};
  } catch {
    return {};
  }
}

function write() {
  try {
    localStorage.setItem(KEY, JSON.stringify(current));
  } catch { /* Privatmodus: dann eben nur für diese Sitzung. */ }
}

export function settings() { return current; }

export function setSetting(key, value) {
  if (!(key in DEFAULTS)) return current;
  current = { ...current, [key]: value };
  write();
  for (const fn of listeners) fn(current, key);
  return current;
}

export function resetSettings() {
  current = { ...DEFAULTS };
  write();
  for (const fn of listeners) fn(current, null);
  return current;
}

export function onSettingsChange(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/** Faktor der gewählten UI-Grösse. */
export function uiScaleValue(id = current.uiScale) {
  return UI_SCALES.find((s) => s.id === id)?.value ?? 1;
}

/**
 * Grösse des Zeichenpuffers für eine Anzeigefläche in CSS-Pixeln.
 * Das Seitenverhältnis bleibt immer das der Fläche - gerechnet wird nur
 * über die Höhe.
 */
export function bufferSize(cssWidth, cssHeight, dpr = deviceRatio()) {
  const w = Math.max(1, cssWidth);
  const h = Math.max(1, cssHeight);
  const mode = RESOLUTIONS.find((r) => r.id === current.resolution) ?? RESOLUTIONS[0];
  if (mode.id === 'auto') return { width: Math.round(w * dpr), height: Math.round(h * dpr) };
  if (mode.id === 'native') return { width: Math.round(w), height: Math.round(h) };
  const scale = mode.height / h;
  return { width: Math.round(w * scale), height: mode.height };
}

function deviceRatio() {
  return Math.min(2, (typeof window !== 'undefined' && window.devicePixelRatio) || 1);
}

/** Beschreibung der tatsächlich benutzten Auflösung - für die Anzeige. */
export function resolutionNote(cssWidth, cssHeight) {
  const { width, height } = bufferSize(cssWidth, cssHeight);
  return `${width} × ${height} PIXEL`;
}

/* ---------- Vollbild ---------- */

export function fullscreenActive() {
  return typeof document !== 'undefined' && !!document.fullscreenElement;
}

export async function toggleFullscreen(target) {
  if (typeof document === 'undefined') return false;
  try {
    if (document.fullscreenElement) {
      await document.exitFullscreen();
      return false;
    }
    const node = target ?? document.documentElement;
    await node.requestFullscreen?.();
    return true;
  } catch {
    return fullscreenActive();
  }
}
