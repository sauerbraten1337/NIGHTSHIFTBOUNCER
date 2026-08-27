/**
 * Scanner System: digitaler Ausweis-Scan und Risikoanalyse.
 * Stufe 0 = kein Gerät (nur grobe Einschätzung),
 * Stufe 1 = digitaler Scanner, 2 = schneller Scanner, 3 = Risikoanalyse.
 */

import { upgradeLevel } from './state.js';

export function scannerLabel(level) {
  return ['MANUELL', 'DIGITAL', 'SCHNELL-SCAN', 'RISIKOANALYSE'][level] ?? 'MANUELL';
}

export function scanGuest(state, guest) {
  const level = upgradeLevel(state, 'scanner');
  const cameras = upgradeLevel(state, 'cameras');
  const offline = hasEffect(state.night, 'scannerFail') || hasEffect(state.night, 'blackout');

  if (offline) {
    return { offline: true, level, ok: null, text: 'SCANNER OFFLINE' };
  }

  const t = guest.truth;
  const result = {
    offline: false,
    level,
    idFlag: level >= 1 ? !t.idValid : null,
    underageFlag: level >= 1 ? t.underage : null,
    blacklisted: level >= 3 ? t.blacklisted : null,
    risk: level >= 3 || cameras >= 2 ? t.risk : null,
    riskBand: null,
    vipVerified: level >= 1 ? t.vip : null,
    itemHint: level >= 3 && t.contraband ? t.contrabandZone : null
  };

  if (level === 0) {
    // Ohne Gerät: Sichtprüfung. Erkennt nur offensichtliche Warnzeichen,
    // liefert aber ein Ergebnis - sonst wäre Koop-Verifikation unmöglich.
    const obvious = t.risk > 0.62 || t.drunk > 0.8 || (t.contraband?.severity ?? 0) >= 3;
    result.ok = !obvious;
    result.text = obvious ? 'SICHTPRÜFUNG: AUFFÄLLIG' : 'SICHTPRÜFUNG: UNAUFFÄLLIG';
    return result;
  }

  if (result.risk !== null) {
    result.riskBand = result.risk > 0.7 ? 'HOCH' : result.risk > 0.4 ? 'MITTEL' : 'NIEDRIG';
  }

  const flags = [];
  if (result.idFlag) flags.push('ID-FEHLER');
  if (result.underageFlag) flags.push('ALTER');
  if (result.blacklisted) flags.push('HAUSVERBOT');
  if (result.riskBand === 'HOCH') flags.push('RISIKO HOCH');
  if (result.itemHint) flags.push(`OBJEKT: ${result.itemHint.toUpperCase()}`);

  result.ok = flags.length === 0;
  result.text = flags.length === 0 ? 'SCAN SAUBER' : flags.join(' / ');
  return result;
}

export function hasEffect(night, id) {
  if (!night) return false;
  return night.activeEffects.some((e) => e.id === id);
}
