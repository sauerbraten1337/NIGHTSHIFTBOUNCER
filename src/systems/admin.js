/**
 * Admin-Zugang: Testhilfen hinter einem Code.
 *
 * Gedacht zum Prüfen des Spiels, nicht zum Spielen: mit dem richtigen Code
 * lassen sich im Pausenmenü die Nacht frei wählen und ein paar Schalter
 * umlegen (kein Übergriff, sofortige Aktionen, Wahrheit einblenden).
 *
 * Bewusst DOM-frei und ohne Spielfluss-Aufrufe - die Schalter stehen hier,
 * gedrückt werden sie in `ui/screens.js`, ausgeführt in `main.js`.
 */

import { clamp } from '../core/rng.js';

export const ADMIN_CODE = 'cig1337';

/** Bis zu welcher Nacht darf im Menü gesprungen werden? */
export const ADMIN_MAX_NIGHT = 40;

const STORE_KEY = 'nullwerk.admin';

/**
 * Der Schaltzustand. Ein Modul-Singleton: die Spiellogik liest ihn direkt,
 * ohne dass er durch den Spielstand oder über das Netz wandern muss.
 */
export const cheats = {
  unlocked: false,
  /** Niemand rastet mehr aus - die Abwehr-Sequenz bleibt aus. */
  noAggro: false,
  /** Kontrollen dauern praktisch keine Zeit mehr. */
  fastActions: false,
  /** Blendet die versteckte Wahrheit des Gastes ein. */
  reveal: false
};

/** Sitzung überdauern: einmal eingeben reicht für den ganzen Testlauf. */
function store() {
  try {
    return typeof sessionStorage === 'undefined' ? null : sessionStorage;
  } catch {
    return null;
  }
}

export function restoreAdmin() {
  if (store()?.getItem(STORE_KEY) === '1') cheats.unlocked = true;
  return cheats.unlocked;
}

export function unlockAdmin(code) {
  if (String(code ?? '').trim().toLowerCase() !== ADMIN_CODE) return false;
  cheats.unlocked = true;
  try { store()?.setItem(STORE_KEY, '1'); } catch { /* egal */ }
  return true;
}

/** Sperren heisst: alle Schalter zurück auf Aus. */
export function lockAdmin() {
  cheats.unlocked = false;
  cheats.noAggro = false;
  cheats.fastActions = false;
  cheats.reveal = false;
  try { store()?.removeItem(STORE_KEY); } catch { /* egal */ }
}

export function setCheat(id, on) {
  if (!cheats.unlocked || !(id in cheats) || id === 'unlocked') return false;
  cheats[id] = !!on;
  return cheats[id];
}

/* ---------- Eingriffe in den Spielstand ---------- */

export function adminAddMoney(state, amount = 5000) {
  state.money = Math.round(state.money + amount);
  return state.money;
}

export function adminSetReputation(state, value = 100) {
  state.reputation = clamp(value, 0, 100);
  return state.reputation;
}

/** Alle Kontrollen freigeben (sonst gibt das Tutorial sie nacheinander frei). */
export function adminUnlockAll(state) {
  state.unlocks = { id: true, talk: true, search: true, alcohol: true, calm: true };
  state.tutorialDone = true;
  return state.unlocks;
}

/**
 * Nachtnummer vorbereiten: die nächste gestartete Schicht ist Nacht `n`.
 * Die laufende Nacht wird dabei verworfen - der Aufrufer schickt danach ins
 * Briefing (siehe `main.js`).
 */
export function adminPrepareNight(state, n) {
  const night = clamp(Math.round(Number(n) || 1), 1, ADMIN_MAX_NIGHT);
  if (state.night) state.night.running = false;
  state.night = null;
  state.nightIndex = night - 1;
  adminUnlockAll(state);
  return night;
}

/** Die Gästeliste kürzen: nur noch so viele Leute bis Schichtende. */
export function adminShortenShift(state, remaining = 3) {
  const night = state.night;
  if (!night) return 0;
  night.quota = Math.max(night.processed + 1, night.processed + Math.round(remaining));
  return night.quota;
}
