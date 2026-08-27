/**
 * Browser-Check: startet einen lokalen Server, laedt das Spiel in Chromium,
 * spielt ein Stueck der ersten Nacht und prueft auf Konsolenfehler.
 *
 * Start: node tests/browser-check.mjs [--shots]
 */

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { existsSync } from 'node:fs';
import { chromium } from 'playwright';

const ROOT = new URL('..', import.meta.url).pathname;
const PORT = 8321;
const shots = process.argv.includes('--shots');

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml'
};

const server = createServer(async (req, res) => {
  try {
    const url = decodeURIComponent(req.url.split('?')[0]);
    const rel = normalize(url === '/' ? '/index.html' : url).replace(/^(\.\.[/\\])+/, '');
    const file = join(ROOT, rel);
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
});

await new Promise((r) => server.listen(PORT, r));

// In dieser Umgebung liegt Chromium unter PLAYWRIGHT_BROWSERS_PATH;
// falls die gepinnte Build-Nummer abweicht, den vorhandenen Binary nehmen.
const launchOptions = {};
const candidates = [
  '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  '/opt/pw-browsers/chromium/chrome'
];
for (const path of candidates) {
  if (existsSync(path)) { launchOptions.executablePath = path; break; }
}
const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1440, height: 810 } });

const errors = [];
// Externe Ressourcen (Google Fonts, favicon) sind in Sandboxes oft blockiert
// und sagen nichts ueber das Spiel aus.
const IGNORE = /Failed to load resource|favicon|fonts\.(googleapis|gstatic)/i;
page.on('console', (m) => {
  if (m.type() === 'error' && !IGNORE.test(m.text())) errors.push(m.text());
});
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));

await page.goto(`http://localhost:${PORT}/index.html`, { waitUntil: 'networkidle' });
await page.waitForSelector('#menu-new');
if (shots) await page.screenshot({ path: 'docs/shot-menu.png' });

await page.click('#menu-new');
await page.waitForSelector('#briefing-start');
await page.click('#briefing-start');
await page.waitForTimeout(1500);

// Ein paar Gaeste abarbeiten: ID, Scan, Abtasten, Entscheidung.
for (let i = 0; i < 12; i++) {
  await page.keyboard.press('Digit1');
  await page.keyboard.press('Digit7');
  await page.waitForTimeout(700);
  await page.keyboard.press('Digit8');
  await page.waitForTimeout(200);
  for (const k of ['j', 'k', 'l']) {
    await page.keyboard.press(k);
    await page.waitForTimeout(450);
  }
  await page.keyboard.press(i % 4 === 0 ? 'Digit4' : 'Digit3');
  await page.waitForTimeout(500);
}

const snapshot = await page.evaluate(() => {
  const g = window.NULLWERK;
  return {
    phase: g.state.phase,
    money: g.state.money,
    reputation: g.state.reputation,
    clock: g.state.night.clock,
    queue: g.state.night.queue.length,
    stats: g.state.night.stats,
    hudClock: document.getElementById('hud-clock').textContent,
    dossier: document.getElementById('dossier-body').textContent.slice(0, 60)
  };
});

if (shots) await page.screenshot({ path: 'docs/shot-night.png' });

// Nacht abkuerzen und Report pruefen.
await page.evaluate(() => { window.NULLWERK.state.night.clock = 298; });
const reportVisible = await page.waitForSelector('#report-next', { timeout: 8000 })
  .then(() => true).catch(() => false);
if (shots && reportVisible) await page.screenshot({ path: 'docs/shot-report.png' });
if (reportVisible) {
  await page.click('#report-next');
  await page.waitForSelector('#shop-next');
  if (shots) await page.screenshot({ path: 'docs/shot-shop.png' });
}

await browser.close();
server.close();

console.log('Browser-Check:');
console.log(`  Phase            ${snapshot.phase}`);
console.log(`  HUD-Uhr          ${snapshot.hudClock}`);
console.log(`  Warteschlange    ${snapshot.queue}`);
console.log(`  Eingelassen      ${snapshot.stats.admitted}`);
console.log(`  Abgewiesen       ${snapshot.stats.rejected}`);
console.log(`  Geld             ${Math.round(snapshot.money)}`);
console.log(`  Report sichtbar  ${reportVisible}`);
console.log(`  Konsolenfehler   ${errors.length}`);
if (errors.length) {
  for (const e of errors.slice(0, 10)) console.log(`    ! ${e}`);
  process.exit(1);
}
if (snapshot.stats.admitted + snapshot.stats.rejected < 4) {
  console.log('  FEHLER: zu wenige Entscheidungen verarbeitet');
  process.exit(1);
}
if (!reportVisible) {
  console.log('  FEHLER: Night Report wurde nicht angezeigt');
  process.exit(1);
}
console.log('\nBrowser-Check bestanden.');
