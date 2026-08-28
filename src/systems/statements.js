/**
 * Aussagen: was der Gast von sich aus behauptet.
 *
 * ANSPRECHEN liefert nicht mehr nur den Namen. Jeder Gast hat zwei bis drei
 * Aussagen im Gepäck - über sein Alter, sein Dokument, seine Taschen, seinen
 * Zustand. Jede davon ist überprüfbar: gegen den Ausweis, gegen das, was man
 * an ihm sieht, gegen den Alkoholwert oder gegen das, was beim Abtasten auf
 * den Tisch kommt.
 *
 * Manche Aussagen sind gelogen. Das Spiel sagt nicht welche - es merkt sich
 * nur, ob sie stimmten, und rechnet erst nach der Entscheidung ab. Wer nicht
 * zuhört, verschenkt eine ganze Prüfebene.
 */

import { ALCOHOL_LIMIT_PROMILLE } from '../data/config.js';
import { ageFromBirth } from './identity.js';
import { pick, chance, randInt, weightedPick } from '../core/rng.js';

/**
 * Alle Aussage-Arten. `build` liefert Text und Wahrheitsgehalt für genau
 * diesen Gast; `check` sagt dem Spieler (im Nachhinein), woran es zu merken war.
 */
const KINDS = [
  {
    id: 'age',
    check: 'Alter gegen das Geburtsdatum im Ausweis',
    build(rng, guest) {
      const docAge = ageFromBirth(guest.doc.birth);
      const realAge = guest.truth.age;
      // Wer ein manipuliertes Dokument hat, verplappert sich manchmal und
      // nennt sein echtes Alter - das passt dann nicht zur Karte.
      const slips = guest.doc.tampered && chance(rng, 0.5);
      // Selten verschätzt sich jemand auch ohne Fälschung um ein, zwei Jahre -
      // wer aufpasst, merkt trotzdem, dass es nicht zur Karte passt.
      const claimed = slips ? realAge : docAge + (chance(rng, 0.05) ? randInt(rng, 1, 3) : 0);
      return {
        text: pick(rng, [
          `Ich bin ${claimed}.`,
          `Ich bin ${claimed}, seit letztem Jahr.`,
          `${claimed} bin ich.`
        ]),
        lie: claimed !== docAge
      };
    }
  },
  {
    id: 'document',
    check: 'Aussage gegen das Ablaufdatum auf der Karte',
    build(rng, guest) {
      const expired = (guest.truth.idIssues ?? []).includes('expired');
      const honest = !expired || chance(rng, 0.35);
      return {
        text: honest && expired
          ? pick(rng, ['Der Ausweis ist abgelaufen, ich weiss.', 'Der ist alt, aber ich bins.'])
          : pick(rng, [
            'Der Ausweis ist noch lange gültig.',
            'Den hab ich erst neu machen lassen.',
            'Alles frisch, der gilt noch Jahre.'
          ]),
        lie: expired && !honest
      };
    }
  },
  {
    id: 'bag',
    check: 'Aussage gegen das, was der Gast sichtbar dabeihat',
    build(rng, guest) {
      const hasBag = !!guest.truth.hasBag;
      const honest = !hasBag || chance(rng, 0.78);
      return {
        text: hasBag && honest
          ? pick(rng, ['Nur die Tasche, sonst nichts.', 'Die Tasche muss mit rein, sorry.'])
          : hasBag
            ? pick(rng, ['Ich hab nichts dabei.', 'Keine Tasche, nichts.'])
            : pick(rng, ['Ich hab nur Handy und Schlüssel.', 'Hosentaschen, mehr nicht.']),
        lie: hasBag && !honest
      };
    }
  },
  {
    id: 'items',
    check: 'Aussage gegen das, was beim Abtasten auftaucht',
    build(rng, guest) {
      const carries = !!guest.truth.contraband;
      const honest = !carries || chance(rng, 0.15);
      return {
        text: carries && honest
          ? pick(rng, ['Ich hab da was dabei, das ihr vielleicht nicht mögt.',
            'Bevor ihr fragt: in der Jacke ist was.'])
          : pick(rng, [
            'Ich hab nichts dabei, ehrlich.',
            'Nichts Verbotenes, könnt ihr durchsuchen.',
            'Ausser Kleingeld ist da nichts.'
          ]),
        lie: carries && !honest
      };
    }
  },
  {
    id: 'sober',
    check: 'Aussage gegen Alkoholwert und Auftreten',
    build(rng, guest) {
      const drunk = guest.truth.drunk;
      const overLimit = drunk * 2.4 >= ALCOHOL_LIMIT_PROMILLE;
      const honest = !overLimit || chance(rng, 0.25);
      return {
        text: overLimit && honest
          ? pick(rng, ['Ich hab was getrunken, klar.', 'Zwei, drei Bier waren es schon.'])
          : pick(rng, [
            'Ich hab heute nichts getrunken.',
            'Ich bin komplett nüchtern.',
            'Ein Bier, mehr nicht.'
          ]),
        lie: overLimit && !honest
      };
    }
  },
  {
    id: 'state',
    check: 'Aussage gegen das, was man der Person ansieht',
    build(rng, guest) {
      const impaired = (guest.truth.impaired ?? 0) >= 0.5;
      const honest = !impaired || chance(rng, 0.2);
      return {
        text: impaired && honest
          ? pick(rng, ['Mir gehts nicht ganz so gut, aber passt schon.',
            'Langer Tag, sieht man mir an.'])
          : pick(rng, [
            'Mir gehts blendend, alles normal.',
            'Ich bin nur müde von der Arbeit.',
            'Alles gut bei mir, wirklich.'
          ]),
        lie: impaired && !honest
      };
    }
  },
  {
    id: 'visit',
    check: 'Nicht überprüfbar - reine Behauptung',
    build(rng, guest) {
      return {
        text: pick(rng, [
          'Ich war letzte Woche schon hier.',
          'Ich kenn hier ein paar Leute.',
          'Ich bin mit Freunden verabredet, die sind schon drin.',
          'Erstes Mal hier, ehrlich gesagt.'
        ]),
        // Geplauder ohne Prüfmöglichkeit: nie eine wertbare Lüge.
        lie: false,
        idle: true
      };
    }
  }
];

/**
 * Baut die Aussagen eines Gastes. Immer dabei: eine zum Alter.
 * Danach kommen ein bis zwei weitere - bevorzugt zu Dingen, bei denen dieser
 * Gast tatsächlich etwas zu verbergen hat, damit sich Zuhören lohnt.
 */
export function buildStatements(rng, guest) {
  const pool = KINDS.filter((k) => k.id !== 'age');
  const extras = [];
  const count = Math.min(pool.length, randInt(rng, 1, 2));
  for (let i = 0; i < count; i++) {
    const remaining = pool.filter((k) => !extras.includes(k));
    if (!remaining.length) break;
    extras.push(weightedPick(rng, remaining, (k) => weightOf(k.id, guest)));
  }
  return [KINDS[0], ...extras].map((kind) => {
    const built = kind.build(rng, guest);
    return { id: kind.id, text: built.text, lie: !!built.lie, check: kind.check };
  });
}

/** Wie interessant ist diese Aussage bei diesem Gast? */
function weightOf(id, guest) {
  const t = guest.truth;
  switch (id) {
    case 'document': return (t.idIssues ?? []).includes('expired') ? 4 : 1;
    case 'bag': return t.hasBag ? 3 : 1;
    case 'items': return t.contraband ? 4 : 1;
    case 'sober': return t.drunk * 2.4 >= ALCOHOL_LIMIT_PROMILLE ? 4 : 1;
    case 'state': return (t.impaired ?? 0) >= 0.5 ? 4 : 1;
    default: return 1.5;
  }
}

/** Hat der Gast in dem, was er gesagt hat, gelogen? */
export function revealedLies(said = []) {
  return said.filter((s) => s.lie);
}

/** Alle Lügen, die er (auch ungefragt) im Gepäck hat. */
export function allLies(guest) {
  return (guest?.truth?.statements ?? []).filter((s) => s.lie);
}

/** Nur zur Anzeige: Kurzform für den Notizzettel. */
export function statementSummary(said = []) {
  if (!said.length) return 'NICHTS GESAGT';
  return said.map((s) => s.text).join(' ');
}
