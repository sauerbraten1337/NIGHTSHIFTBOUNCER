# NULLWERK — NIGHTSHIFT: BOUNCER CO-OP

Ein **2D-Simulationsspiel aus Sicht des Türstehers** eines fiktiven Underground-Techno-Clubs.
Du siehst die Strasse, die Schlange und den Gast direkt vor dir. Er reicht dir seinen Ausweis —
und du prüfst ihn **selbst**: Foto gegen Gesicht, Name gegen Aussage, Geburtsdatum gegen heute,
Ablaufdatum, Hologramm. Dann entscheidest du.

Spielbar **allein**, zu zweit **an einer Tastatur** (Splitscreen) oder **online über einen Raumcode**.

**Das Spiel ist 2D.** Frontansicht mit Tiefenstaffelung, alles prozedural auf Canvas gezeichnet —
kein 3D, keine Ego-Kamera, keine Assets.

![An der Tür](docs/shot-door.png)

Der Ausweis liegt in deiner Hand, die Checkliste hängt als Notizzettel daneben,
und was aus einer Tasche kommt, landet gross auf dem Kontrolltisch:

![Kontrolle](docs/shot-search.png)

---

## Starten

```bash
npm install     # nur für den Online-Modus nötig (ws)
npm start       # http://localhost:8080 — inkl. Online-Räume
```

Ohne Online-Koop genügt jeder statische Server (`npm run serve:static`).

## Tests

```bash
npm test            # Headless: Solo-Nacht, Koop-Nacht, Tutorial, Ausweisregeln, Save/Load
npm run test:browser  # Chromium: spielt alle drei Modi durch, inkl. echtem Online-Raum
npm run shots       # dasselbe mit Screenshots nach docs/
```

Der Browser-Check startet den echten Server, öffnet **zwei** Fenster, erstellt einen Raum,
tritt ihm bei und spielt Tür und Schleuse gegeneinander — Online-Koop wird also wirklich getestet,
nicht nur behauptet.

---

## Die drei Modi

| | Wer macht was | Ansicht |
|---|---|---|
| **SOLO** | Du machst Tür **und** Kontrolle. Es gibt keinen Security-Bereich. | Eine Ansicht: die Tür |
| **LOKALER KOOP** | Zwei Spieler, eine Tastatur. | Splitscreen: links Tür, rechts Schleuse |
| **ONLINE-KOOP** | Raum erstellen / mit Code beitreten. Host = Bouncer, Gast = Security. | Jeder sieht seinen Bereich |

## Die zwei Bereiche

```
Strasse → [ TÜR — draussen ]        → [ SCHLEUSE — innen ]        → Club
           Bouncer:                     Security:
           Ausweis, Gespräch,           Scanner, Abtasten,
           Schlange beruhigen           Alkoholtest
           DURCHLASSEN / ABWEISEN       EINLASSEN / ZURÜCKSCHICKEN
```

Der **Bouncer arbeitet draussen** und entscheidet nur, wer überhaupt hineindarf.
Die **Security sitzt drinnen in einer Sicherheitsschleuse** — innen, aber vom Club getrennt;
erst sie öffnet die Tür zum Floor. Im Solo-Modus entfällt die Schleuse komplett.

Daraus entsteht das eigentliche Koop-Gefühl: eine **zweite Verteidigungslinie**.
Was der Bouncer übersieht, kann die Security noch fangen — das gibt einen **guten Fang**
(Bonus fürs Team) statt einer Strafe. Stimmen Türurteil und Scan überein, gibt es
**SECURITY VERIFIED** (+15 % Eintritt, mehr Ruf); widersprechen sie sich: **CHECK AGAIN**.

## Steuerung

**Solo**
`1` Ausweis · `2` Ansprechen · `3` Scan · `4` Abtasten · `5` Alkotest · `6` Schlange ·
`E` Einlassen · `X` Abweisen · Zonen `J` `K` `L` · Gegenstand: anklicken oder `1`–`6`, `0` = Zone freigeben

**Koop — Spieler 1 (Bouncer, draussen)**
`1` Ausweis · `2` Ansprechen · `3` Schlange · `E` Durchlassen · `X` Abweisen

**Koop — Spieler 2 (Security, Schleuse)**
`7` Scan · `8` Abtasten (`J` Jacke / `K` Taschen / `L` Beutel) · `9` Alkotest ·
`ENTER` Einlassen · `BACKSPACE` Zurückschicken

System: `ESC` Pause · `M` Ton · `H` Hilfe

Einlassen und Abweisen liegen als grosse Buttons unten in der Bildmitte — Maus oder Taste.
Die Auswahl auf dem Kontrolltisch und die Ausweisfelder laufen über die Maus (im Solo
zusätzlich über die Zifferntasten).

## Die Kontrolle

Der Ausweis liegt gross und lesbar unten links. **Klick auf ein Feld = beanstanden.**
Das Spiel verrät nichts von selbst — du musst hinsehen:

| Feld | Wie du es prüfst |
|---|---|
| **Foto** | Gegen das Gesicht des Gastes im Bild. Hautton, Haare, Gesichtsform. |
| **Name** | Gegen das, was der Gast beim *Ansprechen* sagt. |
| **Geburtsdatum** | Alter am heutigen Spieldatum. Manipulierte Ziffern sitzen schief. |
| **Gültig bis** | Gegen das heutige Datum oben auf der Karte. |
| **Merkmale** | Drei Hologramm-Marken. Matt oder fehlend = gefälscht. |

Ein Fehlgriff kostet Zeit und wird als „nichts zu beanstanden" markiert — genaues Hinsehen
lohnt sich also. Scanner-Upgrades und das Talent *Street Smarts* geben Hinweise
(„Dokument prüfen", später auch welches Feld), nehmen dir die Prüfung aber nie ab.

### Abtasten und Gegenstände

Beim Abtasten wählst du eine Zone: **J** Jacke, **K** Hosentaschen, **L** Tasche.
Eine Tasche gibt es nur, wenn der Gast wirklich eine dabei hat — dann siehst du sie an
seiner Schulter, und er holt sie erst hervor, bevor der Prüfring erscheint.

Der Inhalt kommt gross auf den Kontrolltisch: Kaugummi, Schlüssel, Ladekabel — und
vielleicht eine Glasflasche, ein Reizgas oder eine Klinge. **Du** zeigst auf das, was
nicht in den Club darf, oder gibst die Zone frei. Danebengegriffen heisst: der Gegenstand
war harmlos. Freigegeben, obwohl etwas drin war, steht später im Bericht.

### Alkohol und Zustand

Der Alkoholtest legt ein Gerät auf den Tisch. Es zeigt **nur den Wert** — der Grenzwert
steht daneben aufs Gehäuse gedruckt. Die Bewertung machst du.

Und ein niedriger Promillewert heisst nicht, dass jemand nüchtern ist: ab der vierten
Nacht kommen Gäste, die anders auffallen — weite Pupillen, Schweiss auf der Stirn,
mahlender Kiefer, zittrige Hände, abwesender Blick. Das steht in keiner Anzeige.
Das siehst du der Person an oder eben nicht.

### Der Notizzettel

Rechts hängt kein HUD-Panel, sondern ein handgeschriebener Zettel: was du geprüft hast
(durchgestrichen und abgehakt), was noch offen ist, und hingekritzelte Bemerkungen.
Belegung des Clubs, Ausbaustufe und die alte Übersichtskarte gibt es im Spiel nicht mehr —
während der Schicht zählt nur, was auf dem Zettel steht.

## Was mit der Zeit dazukommt

Jede Karriere fängt einfach an und wird schrittweise gemeiner. Was neu dazukommt,
kündigt das Briefing vorher an:

| ab Nacht | Neu | Worauf du achtest |
|---|---|---|
| 1 | Ausweis | Foto, Name, Geburtsdatum, Gültigkeit, Hologramm |
| 2 | Gegenstände | Beim Abtasten kommt alles auf den Tisch |
| 3 | Alkohol | Das Gerät zeigt den Wert, den Grenzwert liest du ab |
| 4 | Zustand | Anzeichen für Substanzeinfluss |
| 6 | Feine Fälschungen | Subtilere Manipulationen |
| 8 | Hausverbote | Bekannte Gesichter versuchen es erneut |
| 10 | Mehrfache Mängel | Es kommt oft mehreres zusammen |

Zusätzlich liegen später mehr harmlose Gegenstände zur Ablenkung dabei.

## Tutorial

Eine ruhige erste Schicht in **12 Schritten**, die jede Mechanik mit genau einem passenden
Gast einführt — und sie erst dann freischaltet: erster Gast → Ausweis verlangen → selbst prüfen →
entscheiden → abgelaufenes Dokument → zu jung → *Ansprechen* freigeschaltet (Namensabgleich) →
Fotovergleich → Hologramm → Scanner/Abtasten/Alkotest (bzw. die Schleuse im Koop) →
Schlange beruhigen → freier Betrieb. Abwählbar im Menü.

---

## Was sonst drin ist

* **Gäste** mit versteckten Eigenschaften, 10 Archetypen, sechs Persönlichkeiten mit eigenen
  Sprüchen, sichtbarem Schwanken und Gesichtsausdruck.
* **Wirtschaft**: Eintritt (skaliert mit Ruf und Ausbaustufe), laufender Bar- und VIP-Umsatz,
  Bussgelder, Zwischenfallkosten, Gagen.
* **Reputation 0–100** steuert Andrang, Preise, VIP-Anteil und verfügbare Acts.
* **13 Upgrades** in 5 Bereichen und 7 Club-Stufen. Der Ausbau zeigt sich dort, wo du stehst:
  breitere Tür, hellere Neonschrift, Scannerbogen in der Schleuse, Kameras, VIP-Eingang.
* **Nacht-Events** (Rave, VIP Night, Artist Night, Sold Out, Inspection, Chaos) und
  **Zufallsereignisse** (Stromausfall, Scannerdefekt, Ansturm, viraler Post, falscher Backstage-Pass …).
* **Acts buchen** — fiktive Künstler; auch der Headliner braucht einen Ausweis.
* **Night Report**, 6 Ränge, 5 Talente, Save-System (`localStorage`).
* **Prozeduraler Techno** (WebAudio, kein Asset), dessen Intensität Nachtphase und
  Schlangenlänge folgt, plus Scanner-, Funk- und Türsounds.

---

## Architektur

Spiellogik ist DOM-frei und damit headless testbar — und läuft im Online-Modus
unverändert autoritativ beim Host.

```
index.html            Shell + HUD-Markup
styles/ui.css         UI: dunkel, industriell, minimal
src/main.js           Modi, Spielfluss, Eingaben, Host/Gast-Verdrahtung

src/core/             rng · bus · input · loop · audio
src/data/             config (Modi, Rollen, Balancing) · dialogue
src/systems/          state · guests · queue · identity · scanner · security · alcohol
                      decision · economy · reputation · upgrades · artists · randomEvents
                      nightcycle · progression · difficulty · tutorial · coop · save
src/render/           layout · palette · sprites · figure (grosse Frontfiguren)
                      items (gezeichnete Gegenstände) · scene (Tür-/Schleusenansicht,
                      Abtast-Ringe, Alkoholtestgerät) · effects · renderer
src/ui/               hud (inkl. Entscheidungs-Buttons) · notepad (Notizzettel)
                      idcard (Ausweis in der Hand) · itemtray (Kontrolltisch)
                      report · shop · screens
src/net/net.js        Räume, Schnappschüsse, Aktionen
server/index.js       Statischer Server + WebSocket-Raumvermittlung
tests/                smoke.mjs (headless) · browser-check.mjs (Chromium, alle drei Modi)
```

**Online-Modell:** Host-autoritativ. Der Host simuliert die Nacht und schickt ~12×/s einen
Schnappschuss; der Gast rendert daraus seine Schleusen-Ansicht und schickt nur Aktionen zurück.
Der Server kennt keine Spielregeln — er verbindet zwei Clients und leitet Nachrichten weiter.
Die versteckte Wahrheit über Gäste bleibt beim Host und wird nie mitgeschickt.

## Balancing anpassen

Fast alles Spürbare steht in `src/data/config.js`: `TUNING` (Nachtlänge, Aktionsdauern, Geduld,
Preise, Mindestalter), `rolesFor(mode)` (Tastenbelegung und Bereiche), `GAME_DATE` (das Datum,
gegen das geprüft wird), `ARCHETYPES`, `ITEMS`, `NIGHT_EVENTS`, `UPGRADES`, `ARTISTS`,
`RANKS`, `TALENTS`, `ITEMS` (was Gäste dabeihaben), `ZONES` (Abtast-Zonen),
`DIFFICULTY_STEPS` (wann welche Auffälligkeit dazukommt), `IMPAIRMENT_SIGNS` und
`ALCOHOL_LIMIT_PROMILLE`. Der Clubname ist eine Konstante (`CLUB_NAME`).

## Nächste Schritte

* Weitere Rollen: Floor Security, VIP Security, Backstage Security
* Gamepad-Support, Zuschauermodus für Online-Räume
* **EXPAND**: zweiter Club als zweite Spielphase (`expandUnlocked` ab Ruf 88 und Nacht 12)
