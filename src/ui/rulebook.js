/**
 * Die Hausordnung am linken Bildrand.
 *
 * Ein Pfeil klebt an der Kante; faehrt man mit der Maus darueber, klappt sie
 * aus - aufgemacht wie ein amtliches Dokument: Briefkopf, Aktenzeichen,
 * Paragraphen, Stempel.
 *
 * Wichtig: Hier stehen nur die GRUPPEN ("Waffen", "Pyrotechnik", ...), nie die
 * einzelnen Gegenstaende. Ob ein Schlagring eine Waffe ist und ob das
 * Fläschchen ohne Etikett unter "unklare Substanzen" faellt, entscheidet der
 * Spieler selbst - abgelesen werden kann das nicht.
 */

import {
  ITEM_CATEGORIES, ZONES, CLUB_NAME, ALCOHOL_LIMIT_PROMILLE, TUNING, GAME_DATE
} from '../data/config.js';
import { escapeHtml } from './hud.js';

const SEVERITY = {
  1: 'Zutritt verweigern',
  2: 'Zutritt verweigern, Eintrag ins Buch',
  3: 'Zutritt verweigern, Leitung informieren'
};

export function createRulebook(game, { root } = {}) {
  const el = root ?? document.getElementById('rulebook');
  if (!el) return { el: null, update() {} };

  el.innerHTML = `
    <button class="rb-tab" aria-expanded="false" aria-controls="rb-sheet">
      <span class="rb-arrow">▶</span>
      <span class="rb-tab-label">HAUS<br>ORDNUNG</span>
    </button>
    <div class="rb-sheet" id="rb-sheet">${sheet()}</div>`;

  const tab = el.querySelector('.rb-tab');
  // Hover klappt aus, Klick haelt sie offen (fuer Touch und ruhiges Lesen).
  el.addEventListener('mouseenter', () => setOpen(true));
  el.addEventListener('mouseleave', () => { if (!el.classList.contains('pinned')) setOpen(false); });
  tab.addEventListener('click', () => {
    el.classList.toggle('pinned');
    setOpen(el.classList.contains('pinned') || !el.classList.contains('open'));
  });

  function setOpen(open) {
    el.classList.toggle('open', open);
    tab.setAttribute('aria-expanded', String(open));
  }

  return { el, update() {} };
}

function sheet() {
  const groups = ITEM_CATEGORIES.slice()
    .sort((a, b) => b.severity - a.severity || a.label.localeCompare(b.label));

  return `
    <div class="rb-doc">
      <div class="rb-letterhead">
        <div class="rb-crest">§</div>
        <div>
          <div class="rb-org">${escapeHtml(CLUB_NAME)} · EINLASSKONTROLLE</div>
          <div class="rb-sub">Hausordnung, Anlage 2 — Nicht zugelassene Sachen (Gruppen)</div>
        </div>
      </div>
      <div class="rb-meta">
        <span>AKTENZEICHEN NW-${GAME_DATE.year}/02</span>
        <span>STAND ${GAME_DATE.day}.${GAME_DATE.month}.${GAME_DATE.year}</span>
      </div>

      <p class="rb-para">
        <b>§1</b> Der Einlass ist zu verweigern, wenn eine Sache aus einer der
        nachstehenden Gruppen mitgeführt wird. Die Aufzählung ist nicht
        abschliessend: die Einordnung im Einzelfall obliegt dem Kontrollpersonal.
        Geprüft wird an den Zonen ${ZONES.map((z) => z.label).join(', ')}.
      </p>

      <table class="rb-table">
        <thead><tr><th>Gruppe</th><th>Stufe</th><th>Massnahme</th></tr></thead>
        <tbody>
          ${groups.map((c, n) => `
            <tr>
              <td>
                <span class="rb-no">${String(n + 1).padStart(2, '0')}</span> ${escapeHtml(c.label)}
                <span class="rb-note">${escapeHtml(c.rule)}</span>
              </td>
              <td class="rb-sev s${c.severity}">${'I'.repeat(c.severity)}</td>
              <td>${escapeHtml(SEVERITY[c.severity] ?? '')}</td>
            </tr>`).join('')}
        </tbody>
      </table>

      <p class="rb-para">
        <b>§2</b> Ebenfalls abzuweisen ist, wer das Mindestalter von
        ${TUNING.minAge} Jahren nicht nachweist, ein ungültiges oder fremdes
        Dokument vorlegt oder einen Atemalkoholwert von
        ${ALCOHOL_LIMIT_PROMILLE.toFixed(1)} ‰ oder mehr aufweist.
      </p>
      <p class="rb-para">
        <b>§3</b> Alltagsgegenstände (Handy, Schlüssel, Feuerzeug, Zigaretten,
        Portemonnaie, Kopfhörer, Kaugummi und Vergleichbares) sind zugelassen
        und nicht zu beanstanden.
      </p>
      <p class="rb-para">
        <b>§4</b> Wer das Personal tätlich angreift, ist unabhängig von allen
        übrigen Feststellungen abzuweisen; der Vorfall ist zu melden.
      </p>

      <div class="rb-stamp">GEPRÜFT · BETRIEBSLEITUNG</div>
    </div>`;
}
