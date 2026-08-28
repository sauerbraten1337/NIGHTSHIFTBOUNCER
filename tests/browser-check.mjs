/**
 * Browser-Check: startet den echten Server, lädt das Spiel in Chromium und
 * spielt es tatsächlich - Solo-Tutorial, Ausweisprüfung per Mausklick,
 * lokaler Koop-Splitscreen und ein Online-Raum mit zwei Browser-Fenstern.
 *
 * Start: node tests/browser-check.mjs [--shots]
 */

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';
import { chromium } from 'playwright';

const PORT = 8477;
const BASE = `http://localhost:${PORT}`;
const shots = process.argv.includes('--shots');
const errors = [];
const IGNORE = /Failed to load resource|favicon|fonts\.(googleapis|gstatic)/i;

/* ---------- Server starten ---------- */

const server = spawn(process.execPath, ['server/index.js', String(PORT)], {
  stdio: ['ignore', 'pipe', 'pipe']
});
server.stderr.on('data', (d) => errors.push(`server: ${d}`));
await waitForServer();

async function waitForServer() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`${BASE}/health`);
      if (res.ok) return;
    } catch { /* noch nicht bereit */ }
    await sleep(150);
  }
  throw new Error('Server ist nicht gestartet');
}

/* ---------- Browser ---------- */

const exe = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/opt/pw-browsers/chromium/chrome']
  .find((p) => existsSync(p));
const browser = await chromium.launch(exe ? { executablePath: exe } : {});

async function newPage() {
  const page = await browser.newPage({ viewport: { width: 1440, height: 810 } });
  page.on('console', (m) => {
    if (m.type() === 'error' && !IGNORE.test(m.text())) errors.push(`console: ${m.text()}`);
  });
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  await page.goto(`${BASE}/index.html`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#menu-start');
  return page;
}

async function startMode(page, mode, tutorial) {
  await page.click(`.mode-card[data-mode="${mode}"]`);
  if (!tutorial) await page.uncheck('#menu-tutorial');
  await page.click('#menu-start');
  await page.waitForSelector('#briefing-start', { timeout: 5000 });
  await page.click('#briefing-start');
  await page.waitForTimeout(800);
}

const results = {};

/* ---------- 1. Solo mit Tutorial + Ausweisprüfung per Klick ---------- */

const solo = await newPage();
if (shots) await solo.screenshot({ path: 'docs/shot-menu.png' });
await startMode(solo, 'solo', true);

// Tutorial führt durch: warten, bis der erste Gast an der Tür steht.
await solo.waitForFunction(() => window.NULLWERK.state.night?.stations.door.guest, null, { timeout: 15000 });
await solo.keyboard.press('Digit1');                       // Ausweis verlangen
await solo.waitForSelector('#idcard .idc-card', { timeout: 5000 });
if (shots) await solo.screenshot({ path: 'docs/shot-door.png' });

results.tutorialStep = await solo.evaluate(() => window.NULLWERK.state.night.tutorial?.step?.id ?? null);
results.idCardVisible = true;

// Ausweisfeld anklicken (bewusst ein sauberes Feld -> "nichts zu beanstanden")
await solo.click('.idc-row[data-field="expiry"]');
await solo.waitForTimeout(300);
results.markedMiss = await solo.evaluate(() =>
  window.NULLWERK.state.night.stations.door.checks.id.marks.expiry);

// Ein paar Gäste abarbeiten: prüfen, markieren wo nötig, entscheiden.
for (let i = 0; i < 30; i++) {
  const done = await solo.evaluate(async () => {
    const g = window.NULLWERK;
    const st = g.state.night.stations.door;
    if (!st.guest) return 'empty';
    if (!st.checks.id) { g.act('bouncer', 'id'); return 'id'; }
    return 'ready';
  });
  if (done === 'ready') {
    // fehlerhafte Felder finden und anklicken (wie ein aufmerksamer Spieler)
    const faults = await solo.evaluate(async () => {
      const g = window.NULLWERK;
      const mod = await import('/src/systems/identity.js');
      const guest = g.state.night.stations.door.guest;
      return [...mod.faultyFields(guest)];
    });
    for (const field of faults) {
      await solo.click(`[data-field="${field}"]`).catch(() => {});
      await solo.waitForTimeout(120);
    }
    await solo.keyboard.press(faults.length ? 'KeyX' : 'KeyE');
  }
  await solo.waitForTimeout(700);
}

results.solo = await solo.evaluate(() => {
  const s = window.NULLWERK.state;
  return {
    mode: s.mode, phase: s.phase, money: Math.round(s.money),
    stats: s.night.stats, unlocks: s.unlocks,
    clock: Math.round(s.night.clock)
  };
});
if (shots) await solo.screenshot({ path: 'docs/shot-solo.png' });

// Nacht abkürzen -> Report -> Shop
await solo.evaluate(() => { window.NULLWERK.state.night.clock = 298; });
results.report = await solo.waitForSelector('#report-next', { timeout: 10000 }).then(() => true).catch(() => false);
if (shots && results.report) await solo.screenshot({ path: 'docs/shot-report.png' });
if (results.report) {
  await solo.click('#report-next');
  await solo.waitForSelector('#shop-next', { timeout: 5000 });
  if (shots) await solo.screenshot({ path: 'docs/shot-shop.png' });
}
await solo.close();

/* ---------- 2. Lokaler Koop: Splitscreen + Schleuse ---------- */

const coop = await newPage();
await startMode(coop, 'local', false);
await coop.waitForFunction(() => window.NULLWERK.state.night?.stations.door.guest, null, { timeout: 15000 });

// Bouncer: Ausweis, durchlassen. Security: scannen, abtasten, einlassen.
for (let i = 0; i < 24; i++) {
  await coop.evaluate(() => {
    const g = window.NULLWERK;
    const door = g.state.night.stations.door;
    const air = g.state.night.stations.airlock;
    if (door.guest && !door.checks.id) g.act('bouncer', 'id');
    else if (door.guest) g.act('bouncer', 'pass');
    if (air.guest && !air.checks.scan) g.act('security', 'scan');
    else if (air.guest && !air.patdown) g.act('security', 'search');
    else if (air.guest && !air.patdown.complete) {
      const zone = ['jacket', 'pockets', 'bag'].find((z) => air.patdown.zones[z] === null);
      if (zone) g.act('security', 'zone', { zone });
    } else if (air.guest) g.act('security', 'admit');
  });
  await coop.waitForTimeout(650);
}

results.coop = await coop.evaluate(() => {
  const s = window.NULLWERK.state;
  return {
    players: window.NULLWERK.players.map((p) => `${p.id}:${p.area}`),
    stats: s.night.stats,
    airlockQueue: s.night.airlockQueue.length,
    views: window.NULLWERK.state.mode
  };
});
if (shots) await coop.screenshot({ path: 'docs/shot-coop.png' });
await coop.close();

/* ---------- 3. Online: Raum erstellen und beitreten ---------- */

const host = await newPage();
await host.click('.mode-card[data-mode="online"]');
await host.uncheck('#menu-tutorial');
await host.click('#menu-start');
await host.waitForSelector('#lobby-host');
await host.click('#lobby-host');
await host.waitForSelector('.roomcode', { timeout: 5000 });
const code = (await host.textContent('.roomcode')).trim();

const guest = await newPage();
await guest.click('.mode-card[data-mode="online"]');
await guest.uncheck('#menu-tutorial');
await guest.click('#menu-start');
await guest.waitForSelector('#lobby-code');
await guest.fill('#lobby-code', code);
await guest.click('#lobby-join');
await host.waitForSelector('#lobby-start:not(.hidden)', { timeout: 5000 });
if (shots) await host.screenshot({ path: 'docs/shot-lobby.png' });

await host.click('#lobby-start');
await host.waitForSelector('#briefing-start', { timeout: 5000 });
await host.click('#briefing-start');
await host.waitForTimeout(1200);

// Der Gast muss die Schleuse sehen und Aktionen schicken können.
await host.waitForFunction(() => window.NULLWERK.state.night?.stations.door.guest, null, { timeout: 15000 });
for (let i = 0; i < 12; i++) {
  await host.evaluate(() => {
    const g = window.NULLWERK;
    const door = g.state.night.stations.door;
    if (door.guest && !door.checks.id) g.act('bouncer', 'id');
    else if (door.guest) g.act('bouncer', 'pass');
  });
  await guest.evaluate(() => {
    const g = window.NULLWERK;
    const air = g.state.night?.stations.airlock;
    if (air?.guest && !air.checks.scan) g.act('security', 'scan');
    else if (air?.guest) g.act('security', 'admit');
  });
  await host.waitForTimeout(600);
}

results.online = {
  hostRole: await host.evaluate(() => window.NULLWERK.netRole),
  guestRole: await guest.evaluate(() => window.NULLWERK.netRole),
  guestSeesNight: await guest.evaluate(() => !!window.NULLWERK.state.night),
  guestClock: await guest.evaluate(() => Math.round(window.NULLWERK.state.night?.clock ?? -1)),
  hostClock: await host.evaluate(() => Math.round(window.NULLWERK.state.night.clock)),
  guestAirlockSeen: await guest.evaluate(() => window.NULLWERK.state.night?.airlockQueue?.length ?? -1),
  admitted: await host.evaluate(() => window.NULLWERK.state.night.stats.admitted),
  passed: await host.evaluate(() => window.NULLWERK.state.night.stats.passed)
};
if (shots) await guest.screenshot({ path: 'docs/shot-airlock.png' });

await guest.close();
await host.close();
await browser.close();
server.kill();

/* ---------- Ergebnis ---------- */

console.log('BROWSER-CHECK');
console.log(`  Tutorial-Schritt      ${results.tutorialStep}`);
console.log(`  Ausweis sichtbar      ${results.idCardVisible}`);
console.log(`  Feld markiert als     ${results.markedMiss} (erwartet: miss)`);
console.log(`  Solo   Einlass ${results.solo.stats.admitted} · abgewiesen ${results.solo.stats.rejected}` +
  ` · richtig ${results.solo.stats.correct}/${results.solo.stats.correct + results.solo.stats.mistakes}`);
console.log(`  Solo   Freischaltungen ${Object.entries(results.solo.unlocks).filter(([, v]) => v).map(([k]) => k).join(',')}`);
console.log(`  Report/Shop           ${results.report}`);
console.log(`  Koop   Posten ${results.coop.players.join(' | ')}`);
console.log(`  Koop   durchgelassen ${results.coop.stats.passed} · eingelassen ${results.coop.stats.admitted}` +
  ` · in der Schleuse ${results.coop.airlockQueue}`);
console.log(`  Online Rollen ${results.online.hostRole}/${results.online.guestRole}` +
  ` · Gast sieht Nacht ${results.online.guestSeesNight} (Uhr ${results.online.guestClock} vs Host ${results.online.hostClock})`);
console.log(`  Online durchgelassen ${results.online.passed} · eingelassen ${results.online.admitted}`);
console.log(`  Konsolenfehler        ${errors.length}`);

let failed = false;
const fail = (msg) => { console.log(`  FEHLER: ${msg}`); failed = true; };

if (errors.length) { errors.slice(0, 8).forEach((e) => console.log(`    ! ${e}`)); failed = true; }
if (results.markedMiss !== 'miss') fail('Markierung eines sauberen Feldes nicht als Fehlgriff gewertet');
if (results.solo.stats.admitted + results.solo.stats.rejected < 3) fail('Solo: zu wenige Entscheidungen');
if (!results.report) fail('Night Report wurde nicht angezeigt');
if (results.coop.stats.passed < 1) fail('Koop: niemand wurde in die Schleuse durchgelassen');
if (results.coop.stats.admitted < 1) fail('Koop: Security hat niemanden eingelassen');
if (results.online.hostRole !== 'host' || results.online.guestRole !== 'guest') fail('Online: Rollen falsch');
if (!results.online.guestSeesNight) fail('Online: der Gast bekommt keine Schnappschüsse');
if (results.online.passed < 1) fail('Online: Host konnte niemanden durchlassen');

if (failed) process.exit(1);
console.log('\nBrowser-Check bestanden.');
