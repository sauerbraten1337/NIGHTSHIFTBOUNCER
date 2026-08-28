/**
 * Kleine Strich-Icons für die Aktions-Buttons.
 *
 * Bewusst als Inline-SVG mit `currentColor`: so erben sie die Farbe des
 * Buttons (Rot = Tür, Cyan = Schleuse, Grau = gesperrt) und bleiben in jeder
 * Grösse scharf. Kein Asset, kein Font.
 */

const svg = (body) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"
        stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;

export const ACTION_ICONS = {
  // Ausweis verlangen: Karte mit Foto und Zeilen
  id: svg(`<rect x="2.5" y="5" width="19" height="14" rx="2"/>
           <circle cx="8" cy="11" r="2.2"/>
           <path d="M5 16.4c.7-1.4 1.8-2.1 3-2.1s2.3.7 3 2.1"/>
           <path d="M14 10h5M14 13h5M14 16h3"/>`),

  // Ansprechen: Sprechblase mit Punkten
  talk: svg(`<path d="M4 5.5h16v10H9.5L5 19v-3.5H4z"/>
             <circle cx="9" cy="10.5" r=".9" fill="currentColor" stroke="none"/>
             <circle cx="12.5" cy="10.5" r=".9" fill="currentColor" stroke="none"/>
             <circle cx="16" cy="10.5" r=".9" fill="currentColor" stroke="none"/>`),

  // Abtasten: Hand an der Silhouette
  search: svg(`<circle cx="9" cy="4.8" r="2.3"/>
               <path d="M9 7.6c-2.4 0-3.8 1.5-3.8 3.8v4.2h1.4L7 21.5h4l.4-5.9h1.4v-4.2c0-2.3-1.4-3.8-3.8-3.8z"/>
               <path d="M16 13.5v-3a1 1 0 0 1 2 0v2.2l.9-.9a1 1 0 0 1 1.5 1.3l-1.9 2.4c-.5.8-1.4 1.3-2.4 1.3h-1"/>`),

  // Alkotest: Messgerät mit Mundstück
  alcohol: svg(`<rect x="3.5" y="8" width="14" height="9" rx="2"/>
                <rect x="6" y="10.6" width="6.5" height="3.8" rx="1"/>
                <path d="M17.5 12.5H20"/>
                <path d="M9.5 8V6.2M13.5 8V6.2"/>
                <circle cx="15" cy="12.5" r="1" fill="currentColor" stroke="none"/>`),

  // Schlange beruhigen: drei Wartende
  calm: svg(`<circle cx="5.5" cy="7" r="1.8"/><path d="M3 19v-4.5c0-1.6 1.1-2.6 2.5-2.6S8 12.9 8 14.5V19"/>
             <circle cx="12" cy="6" r="2"/><path d="M9.2 19v-5c0-1.7 1.2-2.9 2.8-2.9s2.8 1.2 2.8 2.9v5"/>
             <circle cx="18.5" cy="7" r="1.8"/><path d="M16 19v-4.5c0-1.6 1.1-2.6 2.5-2.6S21 12.9 21 14.5V19"/>`),

  // Einlassen: offene Tür mit Pfeil hinein
  admit: svg(`<path d="M14 3.5h5.5v17H14"/>
              <path d="M4 12h9"/><path d="M9.5 8.5 13 12l-3.5 3.5"/>`),

  // Durchlassen in die Schleuse: Pfeil durch zwei Pfosten
  pass: svg(`<path d="M6 4v16M18 4v16"/>
             <path d="M8.5 12h7"/><path d="M12.5 8.5 16 12l-3.5 3.5"/>`),

  // Abweisen: Tür mit Kreuz
  reject: svg(`<path d="M10 3.5H4.5v17H10"/>
               <path d="M13.5 9 20 15.5M20 9l-6.5 6.5"/>`)
};

/** Icon für einen Aktionscode; unbekannte Codes bekommen einen Punkt. */
export function actionIcon(code) {
  return ACTION_ICONS[code] ?? svg('<circle cx="12" cy="12" r="4"/>');
}
