/** Save System: Persistenz über localStorage (Metaprogression, keine laufende Nacht). */

const KEY = 'nullwerk.save.v1';

const PERSISTED = [
  'version', 'money', 'reputation', 'xp', 'talentPoints', 'talents', 'upgrades',
  'nightIndex', 'clubsOwned', 'expandUnlocked', 'lifetime'
];

export function saveGame(state, storage = safeStorage()) {
  if (!storage) return false;
  const data = {};
  for (const key of PERSISTED) data[key] = state[key];
  data.savedAt = Date.now();
  try {
    storage.setItem(KEY, JSON.stringify(data));
    return true;
  } catch {
    return false;
  }
}

export function loadGame(state, storage = safeStorage()) {
  if (!storage) return false;
  try {
    const raw = storage.getItem(KEY);
    if (!raw) return false;
    const data = JSON.parse(raw);
    if (!data || data.version !== state.version) {
      // Andere Version: nur übernehmen, was strukturell passt.
      if (!data) return false;
    }
    for (const key of PERSISTED) {
      if (key === 'version') continue;
      if (data[key] === undefined) continue;
      if (typeof state[key] === 'object' && state[key] !== null && !Array.isArray(state[key])) {
        Object.assign(state[key], data[key]);
      } else {
        state[key] = data[key];
      }
    }
    return true;
  } catch {
    return false;
  }
}

export function hasSave(storage = safeStorage()) {
  if (!storage) return false;
  try {
    return storage.getItem(KEY) !== null;
  } catch {
    return false;
  }
}

export function clearSave(storage = safeStorage()) {
  if (!storage) return false;
  try {
    storage.removeItem(KEY);
    return true;
  } catch {
    return false;
  }
}

function safeStorage() {
  try {
    return typeof localStorage !== 'undefined' ? localStorage : null;
  } catch {
    return null;
  }
}
