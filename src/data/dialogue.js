/**
 * Gast-Dialoge. Trockener, situativer Humor - keine Slapstick-Sprueche.
 * Struktur: personality -> { greet, idAsk, talk, admit, reject }
 */

export const PERSONALITIES = ['polite', 'annoyed', 'drunk', 'arrogant', 'aggressive', 'nervous'];

export const LINES = {
  polite: {
    greet: ['Guten Abend.', 'Schönen Abend zusammen.', 'Alles gut bei euch?'],
    idAsk: ['Klar, hier bitte.', 'Kein Problem, hab ihn dabei.', 'Moment, ich hol ihn raus.'],
    talk: ['Ich war schon lange nicht mehr hier.', 'Wer legt heute auf?', 'Ich warte gern, kein Stress.'],
    search: ['Machen Sie ruhig.', 'Alles dabei was erlaubt ist.', 'Klar, Arme hoch.'],
    admit: ['Danke, schönen Abend.', 'Sehr nett, danke.'],
    reject: ['Schade. Trotzdem danke.', 'Alles klar, kein Problem.']
  },
  annoyed: {
    greet: ['Wie lange noch?', 'Ich steh hier seit einer Ewigkeit.', 'Geht das irgendwann weiter?'],
    idAsk: ['Ernsthaft? Okay.', 'Ich war letztes Wochenende auch hier.', 'Jedes Mal das Gleiche.'],
    talk: ['Was soll das? Ich war letztes Wochenende auch hier.', 'Ihr macht das mit Absicht, oder?', 'Ich kenn hier Leute.'],
    search: ['Muss das sein?', 'Fasst mich nicht so an.', 'Beeilt euch mal.'],
    admit: ['Wurde auch Zeit.', 'Na endlich.'],
    reject: ['Das ist ein Witz.', 'Ich komm hier nie wieder her. Bis nächste Woche.']
  },
  drunk: {
    greet: ['Bruder. Bruuuder.', 'Ist das hier der Eingang?', 'Ey. Ey! Hi.'],
    idAsk: ['Ausweis? Hab ich. Irgendwo.', 'Bruder ich bin komplett nüchtern.', 'Warte, das ist die Bibliothekskarte.'],
    talk: ['Bruder, lass mich einfach rein.', 'Ich hab nur zwei getrunken. Oder acht.', 'Ich tanz auch nur ein bisschen.'],
    search: ['Ich hab nix. Ausser Feuerzeug. Und so.', 'Kitzelt.', 'Vorsichtig, ich schwank ein bisschen.'],
    admit: ['Ich liebe dich, Mann.', 'Beste Tür der Stadt.'],
    reject: ['Das war unfair.', 'Ich geh dann zum Spaeti.']
  },
  arrogant: {
    greet: ['Ich stehe nicht 30 Minuten an.', 'Ich bin auf der Liste.', 'Wer ist hier verantwortlich?'],
    idAsk: ['Wissen Sie überhaupt, wer ich bin?', 'Muss das wirklich sein?', 'Normalerweise werde ich durchgewunken.'],
    talk: ['Ich bin Stammgast.', 'Ja, aber ich bin Stammgast in meinem Herzen.', 'Ich kenne den Betreiber.'],
    search: ['Fassen Sie mich bitte nicht an.', 'Das ist unter meinem Niveau.', 'Machen Sie schnell.'],
    admit: ['War ja klar.', 'Endlich jemand mit Verstand.'],
    reject: ['Das wird Konsequenzen haben.', 'Ihr habt gerade Geld verloren.']
  },
  aggressive: {
    greet: ['Was guckst du?', 'Mach die Tür auf.', 'Ich hab keine Zeit.'],
    idAsk: ['Du weisst überhaupt nicht, wer ich bin.', 'Brauch ich nicht.', 'Nimm den und gib ihn zurück.'],
    talk: ['Willst du Stress?', 'Ich frag nicht nochmal.', 'Rede nicht so mit mir.'],
    search: ['Fass mich nicht an.', 'Das lass ich nicht mit mir machen.', 'Beeil dich.'],
    admit: ['War auch besser so.', 'Klug.'],
    reject: ['Wir sehen uns.', 'Das war ein Fehler.']
  },
  nervous: {
    greet: ['Hi. Hey. Hallo.', 'Ist noch offen?', 'Ich... ja, hi.'],
    idAsk: ['Ausweis, ja, klar, sofort.', 'Der ist ganz normal.', 'Hier. Alles korrekt.'],
    talk: ['Ich will nur kurz rein.', 'Ich bin mit Freunden verabredet.', 'Alles gut bei mir. Wirklich.'],
    search: ['Ich hab nichts dabei.', 'Muss das sein? Okay.', 'Da ist nur mein Handy.'],
    admit: ['Danke. Danke.', 'Okay. Gut. Danke.'],
    reject: ['Verstehe. Ja. Okay.', 'Kein Problem, ich geh.']
  }
};

/** Künstler am Hintereingang - der Running Gag. */
export const ARTIST_LINES = [
  ['Bro, ich spiele hier.', 'Ausweis.', 'Ich BIN der Act.', 'Ausweis.'],
  ['Ich bin der DJ.', 'Name?', 'DJ Phantom.', 'Das steht hier nicht.', 'Dann bin ich wohl heute kein DJ.'],
  ['Mein Name steht auf dem Plakat.', 'Das Plakat kommt hier nicht rein.', 'Fair.']
];

export const REPORT_QUOTES = [
  'Die Schlange war zu lang. Aber sie war da.',
  'Der Floor hat gehalten.',
  'Die Nacht war laut. Genau richtig.',
  'Ein paar Leute reden morgen über diesen Club.',
  'Niemand hat sich beschwert. Fast niemand.'
];
