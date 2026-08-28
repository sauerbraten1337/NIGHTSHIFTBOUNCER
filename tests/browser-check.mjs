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

    // Abtasten: Zone öffnen, Inhalt ansehen, das Verbotene anklicken
    // (im Tutorial erst freigeschaltet, wenn der Schritt erreicht ist)
    await solo.evaluate(() => {
      if (window.NULLWERK.state.unlocks.search) window.NULLWERK.act('bouncer', 'search');
    });
    await solo.waitForTimeout(250);
    for (let z = 0; z < 3; z++) {
      const zone = await solo.evaluate(() => {
        const pat = window.NULLWERK.state.night.stations.door.patdown;
        if (!pat || pat.complete) return null;
        const next = Object.values(pat.zones).find((s2) => s2.state === 'closed');
        if (!next) return null;
        window.NULLWERK.act('bouncer', 'zone', { zone: next.id });
        return next.id;
      });
      if (!zone) break;
      await solo.waitForSelector('#itemtray .tray-item', { timeout: 4000 }).catch(() => {});
      results.trayShown = true;
      const bad = await solo.evaluate(() => {
        const pat = window.NULLWERK.state.night.stations.door.patdown;
        const open = pat?.active ? pat.zones[pat.active] : null;
        return open?.items.find((i) => i.forbidden)?.id ?? null;
      });
      if (bad) {
        results.contrabandFound = true;
        await solo.click(`.tray-item[data-item="${bad}"]`).catch(() => {});
      } else {
        await solo.click('.tray-clear').catch(() => {});
      }
      await solo.waitForTimeout(320);
    }

    // Entscheidung über die grossen Buttons unten in der Mitte
    const btn = faults.length ? '.dec.no' : '.dec.yes';
    await solo.click(btn).catch(() => {});
  }
  await solo.waitForTimeout(600);
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
      const pat = air.patdown;
      const open = pat.active ? pat.zones[pat.active] : null;
      if (open) {
        const bad = open.items.find((i) => i.forbidden);
        g.act('security', 'pick', { zone: open.id, itemId: bad ? bad.id : null });
      } else {
        const next = Object.values(pat.zones).find((z) => z.state === 'closed');
        if (next) g.act('security', 'zone', { zone: next.id });
      }
    } else if (air.guest) g.act('security', 'admit');
  });
  await coop.waitForTimeout(400);

  // Sobald eine Zone offen ist: liegt der Inhalt sichtbar auf dem Tisch?
  const tray = await coop.evaluate(() => {
    const items = [...document.querySelectorAll('#itemtray .tray-item')];
    if (!items.length) return null;
    const bad = window.NULLWERK.state.night.stations.airlock.patdown;
    const open = bad?.active ? bad.zones[bad.active] : null;
    return {
      count: items.length,
      labels: items.map((el) => el.querySelector('.tray-label')?.textContent.trim()),
      forbidden: open?.items.find((i) => i.forbidden)?.id ?? null,
      painted: items.every((el) => el.querySelector('canvas')?.width > 0)
    };
  });
  if (tray) {
    results.trayShown = true;
    results.trayCount = Math.max(results.trayCount ?? 0, tray.count);
    results.trayPainted = tray.painted;
    // Auswahl per echtem Mausklick auf die Karte
    if (tray.forbidden) {
      await coop.click(`.tray-item[data-item="${tray.forbidden}"]`).catch(() => {});
      results.contrabandFound = true;
    } else {
      await coop.click('.tray-clear').catch(() => {});
      results.clearedByClick = true;
    }
    await coop.waitForTimeout(300);
  }
  await coop.waitForTimeout(250);
}

results.ui = await coop.evaluate(() => {
  const has = (sel) => !!document.querySelector(sel);
  const notepad = document.getElementById('notepad');
  return {
    notepad: !!notepad && !notepad.classList.contains('hidden'),
    notepadHand: notepad ? getComputedStyle(notepad).fontFamily.toLowerCase() : '',
    decisions: document.querySelectorAll('#decisions .dec').length,
    hand: has('#idhand .hand'),
    // Diese Anzeigen sollen aus dem Spiel-HUD verschwunden sein
    // (im Briefing/Shop bleibt die Kapazität als Management-Info stehen).
    hudText: document.getElementById('hud').textContent
  };
});

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
console.log(`  Kontrolltisch         ${results.trayShown === true} · max. ${results.trayCount ?? 0} Gegenstände` +
  ` · Icons gezeichnet ${results.trayPainted === true}`);
console.log(`  Auswahl per Klick     verboten ${results.contrabandFound === true} · freigegeben ${results.clearedByClick === true}`);
console.log(`  Notizzettel           ${results.ui.notepad} (${results.ui.notepadHand.split(',')[0]})`);
console.log(`  Entscheidungs-Buttons ${results.ui.decisions} · Hand am Ausweis ${results.ui.hand}`);
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
if (!results.trayShown) fail('Kontrolltisch mit Gegenständen wurde nie gezeigt');
if (!results.ui.notepad) fail('Notizzettel fehlt');
if (!results.ui.notepadHand.includes('caveat') && !results.ui.notepadHand.includes('cursive')) {
  fail('Notizzettel ist nicht in Handschrift gesetzt');
}
if (results.ui.decisions < 2) fail('Entscheidungs-Buttons fehlen');
if (!results.ui.hand) fail('Der Ausweis wird nicht von einer Hand gehalten');
if (/KAPAZITÄT/i.test(results.ui.hudText)) fail('Kapazitätsanzeige ist noch im HUD');
if (/KELLERCLUB|STUFE \d/i.test(results.ui.hudText)) fail('Club-Stufe ist noch im HUD');
if (results.online.passed < 1) fail('Online: Host konnte niemanden durchlassen');

if (failed) process.exit(1);
console.log('\nBrowser-Check bestanden.');
