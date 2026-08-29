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
  await page.waitForSelector('.menu-item[data-id="solo"]');
  return page;
}

/** Tutorial-Haken sitzt im Menue unter EINSTELLUNGEN. */
async function setTutorial(page, on) {
  if (on) return;
  await page.click('.menu-item[data-id="settings"]');
  await page.waitForSelector('#menu-tutorial');
  await page.uncheck('#menu-tutorial');
  await page.click('.menu-item[data-id="settings"]');
}

/** Neue Karriere: erst der Charaktereditor, dann geht es weiter. */
async function passCharacterEditor(page) {
  const done = await page.waitForSelector('#chared-done', { timeout: 5000 }).catch(() => null);
  if (!done) return false;
  await done.click();
  return true;
}

async function startMode(page, mode, tutorial) {
  await setTutorial(page, tutorial);
  await page.click(`.menu-item[data-id="${mode}"]`);
  await passCharacterEditor(page);
  await page.waitForSelector('#briefing-start', { timeout: 5000 });
  await page.click('#briefing-start');
  await page.waitForTimeout(800);
}

const results = {};

/* ---------- 1. Solo mit Tutorial + Ausweisprüfung per Klick ---------- */

const solo = await newPage();
if (shots) await solo.screenshot({ path: 'docs/shot-menu.png' });

// Gegenstands-Katalog im Titelbildschirm - inklusive Rueckweg ins Menue.
await solo.click('.menu-item[data-id="catalog"]');
await solo.waitForSelector('#catalog-back', { timeout: 5000 });
results.catalog = await solo.evaluate(() => ({
  items: document.querySelectorAll('.cat-item').length,
  groups: document.querySelectorAll('.cat-grid').length,
  painted: [...document.querySelectorAll('.cat-item canvas')].every((c) => c.width > 0),
  // Kein Name darf aus seiner Karte laufen.
  overflow: [...document.querySelectorAll('.cat-label')].filter((e) => e.scrollWidth > e.clientWidth + 1).length
}));
if (shots) await solo.screenshot({ path: 'docs/shot-catalog.png' });
await solo.click('#catalog-back');
await solo.waitForSelector('.menu-item[data-id="solo"]', { timeout: 5000 });
results.catalog.back = true;

// Charaktereditor beim Start: Figur, Regler und Vorschau.
await solo.click('.menu-item[data-id="solo"]');
await solo.waitForSelector('#chared-done', { timeout: 5000 });
results.editor = await solo.evaluate(() => ({
  canvas: !!document.querySelector('#chared-canvas'),
  swatches: document.querySelectorAll('.ce-swatch').length,
  chips: document.querySelectorAll('.ce-chip').length,
  name: !!document.querySelector('#ce-name')
}));
// Eine Auswahl ändern und den Namen setzen - beides muss im Zustand landen.
await solo.fill('#ce-name', 'TESTER');
await solo.click('.ce-group:nth-of-type(2) .ce-swatch:last-child').catch(() => {});
await solo.click('.ce-chip').catch(() => {});
if (shots) await solo.screenshot({ path: 'docs/shot-character.png' });
await solo.click('#chared-done');
results.editor.saved = await solo.evaluate(() => window.NULLWERK.state.character);

// Vor der ersten Schicht fuehrt ein Zurueck-Button ins Menue zurueck.
await solo.waitForSelector('#briefing-start', { timeout: 5000 });
results.briefingBack = await solo.evaluate(() => !!document.getElementById('briefing-back'));
if (results.briefingBack) {
  await solo.click('#briefing-back');
  await solo.waitForSelector('.menu-item[data-id="solo"]', { timeout: 5000 });
  results.briefingBackWorks = true;
}

await startMode(solo, 'solo', true);

// Tutorial führt durch: warten, bis der erste Gast an der Tür steht.
await solo.waitForFunction(() => window.NULLWERK.state.night?.stations.door.guest, null, { timeout: 15000 });
await solo.keyboard.press('Digit1');                       // Ausweis verlangen
await solo.waitForSelector('#idcard .idc-card', { timeout: 5000 });
if (shots) await solo.screenshot({ path: 'docs/shot-door.png' });

results.tutorialStep = await solo.evaluate(() => window.NULLWERK.state.night.tutorial?.step?.id ?? null);
results.idCardVisible = true;

// Ausweisfeld anklicken: der Status muss durch den Zyklus laufen,
// ohne dass das Spiel eine Bewertung dazu abgibt.
await solo.click('.idc-row[data-field="expiry"]');
await solo.waitForTimeout(250);
results.markFirst = await solo.evaluate(() =>
  window.NULLWERK.state.night.stations.door.checks.id.marks.expiry);
await solo.click('.idc-row[data-field="expiry"]');
await solo.waitForTimeout(250);
results.markSecond = await solo.evaluate(() =>
  window.NULLWERK.state.night.stations.door.checks.id.marks.expiry);
await solo.click('.idc-row[data-field="expiry"]');
await solo.waitForTimeout(250);
results.markThird = await solo.evaluate(() =>
  window.NULLWERK.state.night.stations.door.checks.id.marks.expiry ?? null);

// Kontrollen: Icon-Buttons ohne Tastenhinweise, per Maus bedienbar.
results.actionButtons = await solo.evaluate(() => {
  const btns = [...document.querySelectorAll('#bar-p1 .act, #bar-p2 .act')];
  return {
    count: btns.length,
    icons: btns.filter((b) => b.querySelector('.act-icon svg')).length,
    keyBadges: document.querySelectorAll('.act .key, .dec .dec-key').length,
    roleTags: document.querySelectorAll('.role-tag').length,
    hintLine: !!document.getElementById('hint')
  };
});

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
      // Die erste Zone wird mit der Maus auf den Ring geoeffnet, der Rest per Aktion.
      if (!results.zoneByMouse) {
        const ring = await solo.evaluate(() => {
          const g = window.NULLWERK;
          const pat = g.state.night.stations.door.patdown;
          if (!pat || pat.complete) return null;
          const hit = g.renderer.zoneHits.find((z2) => pat.zones[z2.zone]?.state === 'closed');
          if (!hit) return null;
          const p = g.renderer.toScreen(hit.x, hit.y);
          return { zone: hit.zone, x: p.x, y: p.y };
        });
        if (ring) {
          await solo.mouse.click(ring.x, ring.y);
          // Das Ausleeren der Zone dauert eine knappe Sekunde.
          await solo.waitForFunction((id) => {
            const pat = window.NULLWERK.state.night?.stations.door.patdown;
            return !pat || pat.zones[id]?.state !== 'closed';
          }, ring.zone, { timeout: 4000 }).catch(() => {});
          results.zoneByMouse = await solo.evaluate((id) => {
            const pat = window.NULLWERK.state.night?.stations.door.patdown;
            return !!pat && pat.zones[id]?.state !== 'closed';
          }, ring.zone);
        }
      }
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
        await solo.waitForTimeout(200);
      }
      // Zone muss ausdrücklich abgeschlossen werden.
      await solo.click('.tray-clear').catch(() => {});
      await solo.waitForTimeout(320);
    }

    // Entscheidung über die grossen Buttons unten in der Mitte
    const btn = faults.length ? '.dec.no' : '.dec.yes';
    await solo.click(btn).catch(() => {});
  }
  await solo.waitForTimeout(600);
}

// ANSPRECHEN per Klick - und der Gast nennt dabei seinen Namen.
// Der Gast muss dafuer wirklich vorne stehen: waehrend der Vorgaenger noch
// abgeht, laeuft ein Klick ins Leere. Darum bis zu drei Versuche.
for (let attempt = 0; attempt < 3; attempt++) {
  await solo.waitForFunction(
    () => !!window.NULLWERK.state.night?.stations.door.guest, null, { timeout: 15000 }
  ).catch(() => {});
  await solo.click('.act[data-code="talk"]').catch(() => {});
  const talked = await solo.waitForFunction(
    () => !!window.NULLWERK.state.night?.stations.door.checks.talk, null, { timeout: 6000 }
  ).then(() => true).catch(() => false);
  if (talked) break;
  await solo.waitForTimeout(600);
}
results.talk = await solo.evaluate(() => {
  const st = window.NULLWERK.state.night.stations.door;
  return {
    done: !!st.checks.talk,
    saysName: !!st.guest && typeof st.guest.said === 'string' && st.guest.said.includes(st.guest.name)
  };
});

// Nochmal ansprechen: der Gast rueckt die naechste Aussage heraus, und alles
// Gesagte steht unter dem Ausweis - nur so kann man es mit der Karte vergleichen.
// Der Ausweis muss dafuer vorliegen - genau daneben stehen die Aussagen.
await solo.evaluate(() => {
  const g = window.NULLWERK;
  if (!g.state.night.stations.door.checks.id) g.act('bouncer', 'id');
});
await solo.waitForTimeout(1800);
await solo.click('.act[data-code="talk"]').catch(() => {});
await solo.waitForTimeout(1800);
results.statements = await solo.evaluate(() => {
  const st = window.NULLWERK.state.night.stations.door;
  return {
    said: st.checks.talk?.said?.length ?? 0,
    shown: document.querySelectorAll('.idc-statements li').length,
    // Die Wahrheit ("war das gelogen?") darf im Text nirgends stehen.
    leaks: /gelogen|LÜGE|lie/i.test(document.querySelector('.idc-statements')?.textContent ?? '')
  };
});

// Pausenmenü: liegt über allem und trägt die komplette Steuerung.
await solo.keyboard.press('Escape');
await solo.waitForSelector('.pause-controls', { timeout: 4000 });
results.pause = await solo.evaluate(() => {
  const box = document.querySelector('.pause-controls').getBoundingClientRect();
  // Punkt über der Hausordnung am linken Rand - die lag früher VOR dem Menü.
  const over = document.elementFromPoint(8, window.innerHeight * 0.38);
  return {
    rows: document.querySelectorAll('.ctl-row').length,
    rightSide: box.left > window.innerWidth * 0.45,
    inFront: !!over && !!over.closest('#screen')
  };
});
await solo.keyboard.press('Escape');
await solo.waitForTimeout(300);

results.solo = await solo.evaluate(() => {
  const s = window.NULLWERK.state;
  return {
    mode: s.mode, phase: s.phase, money: Math.round(s.money),
    stats: s.night.stats, unlocks: s.unlocks,
    quota: s.night.quota, processed: s.night.processed,
    clock: Math.round(s.night.clock)
  };
});
if (shots) await solo.screenshot({ path: 'docs/shot-solo.png' });

// Nacht abkürzen: der Timer ist weg, also wird die Gästeliste als
// abgearbeitet gesetzt (das Tutorial haelt die Schicht sonst offen).
await solo.evaluate(() => {
  const n = window.NULLWERK.state.night;
  n.tutorial = null;
  n.processed = n.quota;
});
await solo.waitForTimeout(400);
results.soloEnd = await solo.evaluate(() => {
  const n = window.NULLWERK.state.night;
  return { phase: window.NULLWERK.state.phase, processed: n.processed, quota: n.quota };
});
results.report = await solo.waitForSelector('#report-next', { timeout: 10000 }).then(() => true).catch(() => false);
// Sterne, Balken und Sprechblase laufen gestaffelt ein - erst danach das Bild.
if (shots && results.report) {
  await solo.waitForTimeout(1800);
  await solo.screenshot({ path: 'docs/shot-report.png' });
}
if (results.report) {
  // Der Abschluss zeigt links die Zahlen, rechts den eigenen Charakter.
  results.reportScreen = await solo.evaluate(() => ({
    stars: document.querySelectorAll('.rep-star').length,
    litStars: document.querySelectorAll('.rep-star.on').length,
    canvas: !!document.querySelector('#rep-canvas'),
    grade: document.querySelector('.rep-grade')?.textContent.trim() ?? '',
    tiles: document.querySelectorAll('.rep-tile').length,
    // links die Stats, rechts die Figur
    statsLeft: (() => {
      const l = document.querySelector('.rep-left')?.getBoundingClientRect();
      const r = document.querySelector('.rep-right')?.getBoundingClientRect();
      return !!l && !!r && l.left < r.left;
    })()
  }));

  await solo.click('#report-next');
  // Danach steht man am Tag im Büro: Schrank, Laptop, Tür.
  await solo.waitForSelector('.office-hit[data-spot="laptop"]', { timeout: 5000 });
  results.office = await solo.evaluate(() => ({
    phase: window.NULLWERK.state.phase,
    spots: [...document.querySelectorAll('.office-hit')].map((b) => b.dataset.spot),
    canvas: !!document.querySelector('#office-canvas')
  }));
  if (shots) await solo.screenshot({ path: 'docs/shot-office.png' });

  // Kleiderschrank: Charakter bearbeiten und zurück ins Büro.
  await solo.click('.office-hit[data-spot="wardrobe"]');
  await solo.waitForSelector('#chared-done', { timeout: 5000 });
  results.office.wardrobe = true;
  await solo.click('#chared-done');
  await solo.waitForSelector('.office-hit[data-spot="laptop"]', { timeout: 5000 });

  // Laptop: die Upgrades.
  await solo.click('.office-hit[data-spot="laptop"]');
  await solo.waitForSelector('#shop-next', { timeout: 5000 });
  results.office.laptop = true;
  // Der Startbildschirm von NIGHT//OS laeuft kurz - erst danach lohnt das Bild.
  if (shots) {
    await sleep(1800);
    await solo.screenshot({ path: 'docs/shot-shop.png' });
  }
  await solo.click('#shop-next');
  await solo.waitForSelector('.office-hit[data-spot="door"]', { timeout: 5000 });

  // Tür: die nächste Nacht beginnt.
  await solo.click('.office-hit[data-spot="door"]');
  results.office.door = await solo.waitForSelector('#briefing-start', { timeout: 5000 })
    .then(() => true).catch(() => false);
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
    if (air.guest && !air.patdown) g.act('security', 'search');
    else if (air.guest && !air.patdown.complete) {
      const pat = air.patdown;
      const open = pat.active ? pat.zones[pat.active] : null;
      if (open) {
        const bad = open.items.find((i) => i.forbidden && !open.flagged.includes(i.id));
        if (bad) g.act('security', 'pick', { zone: open.id, itemId: bad.id });
        else g.act('security', 'closezone', { zone: open.id });
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
      flagged: open?.flagged ?? [],
      painted: items.every((el) => el.querySelector('canvas')?.width > 0)
    };
  });
  if (tray) {
    results.trayShown = true;
    results.trayCount = Math.max(results.trayCount ?? 0, tray.count);
    results.trayPainted = tray.painted;
    results.trayOverflow = (results.trayOverflow ?? 0) + await coop.evaluate(() =>
      [...document.querySelectorAll('.tray-item')].filter((item) => {
        const label = item.querySelector('.tray-label');
        if (!label) return false;
        const l = label.getBoundingClientRect();
        const c = item.getBoundingClientRect();
        return label.scrollWidth > label.clientWidth + 1 || l.left < c.left - 1 || l.right > c.right + 1;
      }).length);
    // Auswahl per echtem Mausklick auf die Karte
    if (tray.forbidden && !tray.flagged.includes(tray.forbidden)) {
      await coop.click(`.tray-item[data-item="${tray.forbidden}"]`).catch(() => {});
      results.contrabandFound = true;
      await coop.waitForTimeout(200);
    }
    await coop.click('.tray-clear').catch(() => {});
    results.clearedByClick = true;
    await coop.waitForTimeout(300);
  }
  await coop.waitForTimeout(250);
}

// Hausordnung: Pfeil am linken Rand, faehrt bei Hover aus.
await coop.hover('#rulebook .rb-tab').catch(() => {});
await coop.waitForTimeout(500);
if (shots) await coop.screenshot({ path: 'docs/shot-rulebook.png' });
results.rulebook = await coop.evaluate(() => {
  const rb = document.getElementById('rulebook');
  const sheet = rb?.querySelector('.rb-sheet');
  const box = rb?.getBoundingClientRect();
  return {
    exists: !!rb,
    atLeftEdge: !!box && box.left < window.innerWidth * 0.1,
    open: !!rb?.classList.contains('open'),
    width: sheet ? Math.round(sheet.getBoundingClientRect().width) : 0,
    hasArrow: !!rb?.querySelector('.rb-arrow'),
    // amtliche Optik: Briefkopf, Paragraphen, Stempel
    official: !!rb?.querySelector('.rb-letterhead') && !!rb?.querySelector('.rb-stamp')
      && /§/.test(rb.textContent),
    forbiddenRows: rb ? rb.querySelectorAll('.rb-table tbody tr').length : 0,
    // Die Liste nennt nur Gruppen ("Waffen"), nie einzelne Gegenstände -
    // sonst könnte man die Kontrolle einfach ablesen.
    listsGroups: /Waffen/i.test(rb?.textContent ?? ''),
    listsSingleItems: /Klappmesser|Schlagring|Teleskopschlagstock|Bengalfackel/i
      .test(rb?.textContent ?? '')
  };
});

// Notizzettel: zwei Seiten, beide vom Spieler zu fuehren.
results.notes = await coop.evaluate(() => ({
  tabs: document.querySelectorAll('#notepad .np-tab').length,
  checklist: document.querySelectorAll('#notepad [data-check]').length
}));
if (results.notes.checklist > 0) {
  await coop.click('#notepad [data-check]').catch(() => {});
  await coop.waitForTimeout(250);
  results.notes.checkedSelf = await coop.evaluate(() =>
    Object.keys(window.NULLWERK.stationFor('security').notes.checked).length);
}
await coop.click('#notepad .np-tab[data-page="1"]').catch(() => {});
await coop.waitForTimeout(250);
results.notes.page2 = await coop.evaluate(() => ({
  page: window.NULLWERK.stationFor('security').notes.page,
  topics: document.querySelectorAll('#notepad [data-topic]').length
}));
if (results.notes.page2.topics > 0) {
  await coop.click('#notepad [data-topic]').catch(() => {});
  await coop.waitForTimeout(250);
  results.notes.topicSet = await coop.evaluate(() =>
    Object.values(window.NULLWERK.stationFor('security').notes.topics)[0] ?? null);
}

results.ui = await coop.evaluate(() => {
  const has = (sel) => !!document.querySelector(sel);
  const notepad = document.getElementById('notepad');
  const box = notepad.getBoundingClientRect();
  const hand = document.querySelector('#idhand .holding-hand');
  const handStyle = hand ? getComputedStyle(hand) : null;
  return {
    // Zettel gehört nach UNTEN rechts
    notepadBottomRight: box.top > window.innerHeight * 0.35 && box.left > window.innerWidth * 0.5,
    // Hand ist ein Kreis und liegt hinter dem, was sie hält
    handIsCircle: !!handStyle && handStyle.borderRadius.startsWith('50%'),
    handBehind: !!handStyle && Number(handStyle.zIndex || 0) <= 0,
    handIsSvg: has('#idhand svg'),
    scanAction: [...document.querySelectorAll('.act .act-name')].some((n) => /SCAN/i.test(n.textContent)),
    notepad: !!notepad && !notepad.classList.contains('hidden'),
    notepadHand: notepad ? getComputedStyle(notepad).fontFamily.toLowerCase() : '',
    decisions: document.querySelectorAll('#decisions .dec').length,
    // Kein Timer mehr, sondern der Schichtplan in Gästen
    shiftCounter: document.getElementById('hud-clock')?.textContent ?? '',
    hand: has('#idhand .holding-hand'),
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
await setTutorial(host, false);
await host.click('.menu-item[data-id="online"]');
await passCharacterEditor(host);
await host.waitForSelector('#lobby-host');
await host.click('#lobby-host');
await host.waitForSelector('.roomcode', { timeout: 5000 });
const code = (await host.textContent('.roomcode')).trim();

const guest = await newPage();
await setTutorial(guest, false);
await guest.click('.menu-item[data-id="online"]');
await passCharacterEditor(guest);
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
    if (air?.guest) g.act('security', 'admit');
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
console.log(`  Ausweis-Klickzyklus   ${results.markFirst} -> ${results.markSecond} -> ${results.markThird}`);
console.log(`  Schichtplan           ${results.ui.shiftCounter} Gäste · Solo endet bei` +
  ` ${results.soloEnd.processed}/${results.soloEnd.quota} -> ${results.soloEnd.phase}`);
console.log(`  Hausordnung links     Pfeil ${results.rulebook.hasArrow} · ausgefahren ${results.rulebook.open}` +
  ` (${results.rulebook.width}px) · amtliche Optik ${results.rulebook.official}` +
  ` · ${results.rulebook.forbiddenRows} verbotene Gruppen` +
  ` · nennt Einzelstücke ${results.rulebook.listsSingleItems}`);
console.log(`  Notizzettel 2 Seiten  Reiter ${results.notes.tabs} · Checkliste ${results.notes.checklist}` +
  ` · selbst abgehakt ${results.notes.checkedSelf ?? 0} · Seite ${results.notes.page2.page}` +
  ` · Befunde ${results.notes.page2.topics} (${results.notes.topicSet ?? '—'})`);
console.log(`  Solo   Einlass ${results.solo.stats.admitted} · abgewiesen ${results.solo.stats.rejected}` +
  ` · richtig ${results.solo.stats.correct}/${results.solo.stats.correct + results.solo.stats.mistakes}`);
console.log(`  Solo   Freischaltungen ${Object.entries(results.solo.unlocks).filter(([, v]) => v).map(([k]) => k).join(',')}`);
console.log(`  Report/Shop           ${results.report}`);
console.log(`  Charaktereditor       Vorschau ${results.editor.canvas} · ${results.editor.swatches} Farbfelder` +
  ` · ${results.editor.chips} Schalter · Name ${results.editor.saved?.name}`);
console.log(`  Nachtabschluss        ${results.reportScreen?.litStars ?? 0}/${results.reportScreen?.stars ?? 0} Sterne` +
  ` · ${results.reportScreen?.grade} · Figur rechts ${results.reportScreen?.statsLeft}` +
  ` · ${results.reportScreen?.tiles ?? 0} Kacheln`);
console.log(`  Büro                  Phase ${results.office?.phase} · ${(results.office?.spots ?? []).join(', ')}` +
  ` · Schrank ${results.office?.wardrobe === true} · Laptop ${results.office?.laptop === true}` +
  ` · Tür ${results.office?.door === true}`);
console.log(`  Abtast-Ring per Maus  ${results.zoneByMouse === true}`);
console.log(`  Aktions-Buttons       ${results.actionButtons.count} · mit Icon ${results.actionButtons.icons}` +
  ` · Tastenhinweise ${results.actionButtons.keyBadges} · Rollen-Tags ${results.actionButtons.roleTags}`);
console.log(`  Ansprechen per Klick  ${results.talk.done} · nennt den Namen ${results.talk.saysName}`);
console.log(`  Pausenmenü            ${results.pause.rows} Zeilen · rechts ${results.pause.rightSide}` +
  ` · im Vordergrund ${results.pause.inFront}`);
console.log(`  Kontrolltisch         ${results.trayShown === true} · max. ${results.trayCount ?? 0} Gegenstände` +
  ` · Icons gezeichnet ${results.trayPainted === true}`);
console.log(`  Auswahl per Klick     verboten ${results.contrabandFound === true} · freigegeben ${results.clearedByClick === true}`);
console.log(`  Notizzettel           ${results.ui.notepad} (${results.ui.notepadHand.split(',')[0]}) · unten rechts ${results.ui.notepadBottomRight}`);
console.log(`  Hand                  Kreis ${results.ui.handIsCircle} · hinter dem UI ${results.ui.handBehind} · kein SVG ${!results.ui.handIsSvg}`);
console.log(`  Scan entfernt         ${!results.ui.scanAction}`);
console.log(`  Entscheidungs-Buttons ${results.ui.decisions} · Hand am Ausweis ${results.ui.hand}`);
console.log(`  Koop   Posten ${results.coop.players.join(' | ')}`);
console.log(`  Koop   durchgelassen ${results.coop.stats.passed} · eingelassen ${results.coop.stats.admitted}` +
  ` · in der Schleuse ${results.coop.airlockQueue}`);
console.log(`  Online Rollen ${results.online.hostRole}/${results.online.guestRole}` +
  ` · Gast sieht Nacht ${results.online.guestSeesNight} (Uhr ${results.online.guestClock} vs Host ${results.online.hostClock})`);
console.log(`  Online durchgelassen ${results.online.passed} · eingelassen ${results.online.admitted}`);
console.log(`  Gegenstands-Katalog   ${results.catalog.items} Karten · ${results.catalog.groups} Gruppen` +
  ` · gezeichnet ${results.catalog.painted} · Text laeuft raus ${results.catalog.overflow}`);
console.log(`  Zurueck zum Titel     Katalog ${results.catalog.back === true} · Briefing ${results.briefingBackWorks === true}`);
console.log(`  Aussagen              ${results.statements.said} gesagt · ${results.statements.shown} am Ausweis` +
  ` · verraet die Wahrheit ${results.statements.leaks}`);
console.log(`  Namen im Tray         laufen raus: ${results.trayOverflow ?? 0}`);
console.log(`  Konsolenfehler        ${errors.length}`);

let failed = false;
const fail = (msg) => { console.log(`  FEHLER: ${msg}`); failed = true; };

if (errors.length) { errors.slice(0, 8).forEach((e) => console.log(`    ! ${e}`)); failed = true; }
if (results.markFirst !== 'suspect' || results.markSecond !== 'fine' || results.markThird !== null) {
  fail('Der Klick auf ein Ausweisfeld schaltet nicht zwischen nicht korrekt / in Ordnung / leer um');
}
if (!/^\d+\/\d+$/.test(results.ui.shiftCounter.trim())) fail('Im HUD steht kein Gäste-Schichtplan');
if (/\d\d:\d\d/.test(results.ui.shiftCounter)) fail('Der Tages-Timer ist noch im HUD');
if (results.soloEnd.phase !== 'report' || results.soloEnd.processed !== results.soloEnd.quota) {
  fail('Solo: die Nacht endet nicht, wenn die Gästeliste abgearbeitet ist');
}
if (!results.rulebook.exists || !results.rulebook.hasArrow) fail('Der Pfeil für die Hausordnung fehlt');
if (!results.rulebook.atLeftEdge) fail('Die Hausordnung klebt nicht am linken Rand');
if (!results.rulebook.open || results.rulebook.width < 100) fail('Die Hausordnung fährt bei Hover nicht aus');
if (!results.rulebook.official) fail('Die Hausordnung sieht nicht nach amtlichem Dokument aus');
if (results.rulebook.forbiddenRows < 5 || !results.rulebook.listsGroups) {
  fail('Die Hausordnung listet die verbotenen Gruppen nicht auf');
}
if (results.rulebook.listsSingleItems) {
  fail('Die Hausordnung verrät einzelne Gegenstände - dann muss man nicht mehr selbst prüfen');
}
if (results.notes.tabs !== 2) fail('Der Notizzettel hat keine zwei Seiten');
if (!results.notes.checklist) fail('Seite 1 hat keine abhakbare Checkliste');
if (!results.notes.checkedSelf) fail('Der Haken lässt sich nicht selbst setzen');
if (results.notes.page2.page !== 1) fail('Man kann nicht auf Seite 2 blättern');
if (!results.notes.page2.topics) fail('Seite 2 hat keine Befund-Zeilen');
if (results.notes.topicSet !== 'ok') fail('Auf Seite 2 lässt sich kein Befund eintragen');
if (results.solo.stats.admitted + results.solo.stats.rejected < 3) fail('Solo: zu wenige Entscheidungen');
if (!results.report) fail('Night Report wurde nicht angezeigt');
if (!results.editor.canvas || results.editor.swatches < 12 || !results.editor.name) {
  fail('Der Charaktereditor beim Spielstart ist unvollständig');
}
if (results.editor.saved?.name !== 'TESTER' || results.editor.saved?.created !== true) {
  fail('Der erstellte Charakter wird nicht übernommen');
}
if (!results.reportScreen?.canvas || !results.reportScreen?.statsLeft) {
  fail('Im Nachtabschluss fehlt die Figur rechts neben den Stats');
}
if ((results.reportScreen?.stars ?? 0) !== 5 || !results.reportScreen?.grade) {
  fail('Im Nachtabschluss fehlen Sterne oder Bewertung');
}
if (results.office?.phase !== 'office' || (results.office?.spots ?? []).length !== 3) {
  fail('Nach der Nacht steht man nicht im Büro mit Schrank, Laptop und Tür');
}
if (!results.office?.wardrobe) fail('Am Kleiderschrank öffnet sich kein Charaktereditor');
if (!results.office?.laptop) fail('Am Laptop öffnen sich keine Upgrades');
if (!results.office?.door) fail('Die Bürotür startet nicht die nächste Nacht');
if (results.coop.stats.passed < 1) fail('Koop: niemand wurde in die Schleuse durchgelassen');
if (results.coop.stats.admitted < 1) fail('Koop: Security hat niemanden eingelassen');
if (results.online.hostRole !== 'host' || results.online.guestRole !== 'guest') fail('Online: Rollen falsch');
if (!results.online.guestSeesNight) fail('Online: der Gast bekommt keine Schnappschüsse');
if (!results.trayShown) fail('Kontrolltisch mit Gegenständen wurde nie gezeigt');
if (!results.zoneByMouse) fail('Abtast-Ring liess sich nicht mit der Maus anklicken');
if (results.actionButtons.count < 4 || results.actionButtons.icons !== results.actionButtons.count) {
  fail('Die Aktions-Buttons haben keine Icons');
}
if (results.actionButtons.keyBadges > 0 || results.actionButtons.hintLine || results.actionButtons.roleTags > 0) {
  fail('Im laufenden Spiel stehen noch Steuerungshinweise oder Rollen-Tags im Bild');
}
if (results.catalog.items < 20 || results.catalog.groups < 2 || !results.catalog.painted) {
  fail('Der Gegenstands-Katalog im Titelbildschirm ist unvollständig');
}
if (results.catalog.overflow > 0) fail('Im Katalog laufen Namen aus ihrer Karte');
if (!results.catalog.back) fail('Aus dem Katalog kommt man nicht ins Menü zurück');
if (!results.briefingBack || !results.briefingBackWorks) {
  fail('Vom Briefing führt kein Zurück-Button in den Titelbildschirm');
}
if (results.statements.said < 2 || results.statements.shown < 2) {
  fail('Erneutes Ansprechen bringt keine weitere Aussage auf den Ausweis');
}
if (results.statements.leaks) fail('Das Spiel verrät, welche Aussage gelogen war');
if ((results.trayOverflow ?? 0) > 0) fail('Auf dem Kontrolltisch laufen die Namen aus ihrer Karte');
if (!results.talk.done) fail('ANSPRECHEN liess sich nicht anklicken');
if (!results.talk.saysName) fail('Der Gast nennt beim Ansprechen nicht seinen Namen');
if (results.pause.rows < 8 || !results.pause.rightSide) fail('Im Pausenmenü fehlt die Steuerung rechts');
if (!results.pause.inFront) fail('Das Pausenmenü liegt nicht im Vordergrund');
if (!results.ui.notepad) fail('Notizzettel fehlt');
if (!results.ui.notepadHand.includes('caveat') && !results.ui.notepadHand.includes('cursive')) {
  fail('Notizzettel ist nicht in Handschrift gesetzt');
}
if (results.ui.decisions < 2) fail('Entscheidungs-Buttons fehlen');
if (!results.ui.hand) fail('Der Ausweis wird nicht von einer Hand gehalten');
if (!results.ui.notepadBottomRight) fail('Notizzettel hängt nicht unten rechts');
if (!results.ui.handIsCircle) fail('Die haltende Hand ist kein Kreis');
if (!results.ui.handBehind) fail('Die Hand liegt über dem UI statt dahinter');
if (results.ui.scanAction) fail('SCAN ist noch als Aktion vorhanden');
if (/KAPAZITÄT/i.test(results.ui.hudText)) fail('Kapazitätsanzeige ist noch im HUD');
if (/KELLERCLUB|STUFE \d/i.test(results.ui.hudText)) fail('Club-Stufe ist noch im HUD');
if (results.online.passed < 1) fail('Online: Host konnte niemanden durchlassen');

if (failed) process.exit(1);
console.log('\nBrowser-Check bestanden.');
