# Godot-Projekt einrichten und mit dem Repo verbinden

Die Godot-Portierung liegt im Unterordner `godot/`. Die Web-Version in `src/`
bleibt unangetastet, solange die Portierung läuft.

Geprüft mit **Godot 4.7.1-stable** (ohne .NET/C#).

---

## 1. Godot herunterladen

<https://godotengine.org/download> → Godot 4.7 für dein Betriebssystem, die
Standard-Variante (nicht ".NET"). Godot braucht keine Installation, die
entpackte Datei wird direkt gestartet.

## 2. Repo holen

```bash
git clone https://github.com/sauerbraten1337/NIGHTSHIFTBOUNCER.git
cd NIGHTSHIFTBOUNCER
git checkout claude/godot-game-conversion-g8je3u
```

Ist das Repo schon lokal vorhanden:

```bash
git fetch origin claude/godot-game-conversion-g8je3u
git checkout claude/godot-game-conversion-g8je3u
git pull
```

## 3. Projekt importieren

Godot starten → **Import** → die Datei `godot/project.godot` auswählen →
**Import & Edit**. Godot legt dabei den Ordner `godot/.godot/` an; der ist
Cache und per `.gitignore` ausgeschlossen.

## 4. Starten

**F5** drücken. Es erscheint die Platzhalterkulisse: Straße, Clubblock,
Türen und die beiden Stationsringe — gezeichnet aus denselben Koordinaten
und Farben wie die Web-Version (`godot/scripts/Layout.gd` und `Palette.gd`
sind Portierungen von `src/render/layout.js` und `src/render/palette.js`).

Sieht man das Bild, steht die Verbindung Repo ↔ Godot.

---

## Täglicher Ablauf

Git synchronisiert **nicht** von selbst. Änderungen aus einer Claude-Session
liegen zuerst nur auf GitHub.

**Änderungen holen:**

1. Im Editor alles speichern (`Strg+S`) und geänderte Szenen **schließen**.
2. `git pull`
3. Godot lädt `.gd`-Dateien beim nächsten Fokus automatisch neu. Nach
   Änderungen an `project.godot`, Autoloads oder der Input-Map: Editor neu
   starten.

**Eigene Änderungen abgeben:**

```bash
git add -A && git commit -m "..." && git push
```

### Warum offene Szenen vor dem Pull geschlossen gehören

Ist eine `.tscn`-Datei im Editor geöffnet, arbeitet Godot mit ihrer Fassung
im Speicher weiter und überschreibt die frisch gepullte Datei beim nächsten
Speichern. So gehen Änderungen verloren.

### Arbeitsteilung

`.tscn`-Dateien lassen sich kaum mergen — Godot schreibt beim Speichern
Node-Reihenfolge und Ressourcen-IDs um. Deshalb fasst nie mehr als eine
Seite dieselbe Datei an:

| Claude | Mensch im Editor |
| --- | --- |
| `.gd` (Logik, Systeme, Tests) | `.tscn`, `.tres`, Theme |
| `res://data/` | Szenenbaum, Node-Anordnung |

### `.uid`-Dateien

Godot 4.4+ legt neben jedem Skript eine `.uid`-Datei an. Die gehört ins
Repo — fehlt sie, reißen Skriptreferenzen in Szenen. Die `.gitignore`
schließt sie bewusst nicht aus.

---

## Headless prüfen (optional, auch in CI)

Ohne Editor, nur zum Prüfen:

```bash
# Projekt importieren (einmalig oder nach neuen Assets)
godot --headless --path godot --import

# Einzelnes Skript auf Syntaxfehler prüfen
godot --headless --path godot --check-only --script res://scripts/Main.gd

# Hauptszene 90 Frames laufen lassen und beenden
godot --headless --path godot --quit-after 90
```

Exitcode 0 und keine Fehlerausgabe heißt: Projekt lädt und läuft.

---

## Portierungsstand

Die Portierung ist vollständig: Das Godot-Projekt spielt dasselbe Spiel wie
die Web-Fassung, aus derselben Datenlage und mit denselben Zahlen.

| Bereich | Web | Godot |
| --- | --- | --- |
| Zufall, Bus, Eingabe, Schleife | `src/core/*` | `scripts/core/*` (`Rng.gd`, `Bus.gd`, `GameInput.gd`) |
| Daten | `src/data/*` | `scripts/data/Config.gd`, `Dialogue.gd` |
| Spiellogik | `src/systems/*` | `scripts/systems/*` (22 Module) |
| Zeichnen | `src/render/*` | `scripts/render/*` inkl. `Draw2D.gd` (Canvas-2D-Ersatz) |
| Oberfläche | `src/ui/*`, `styles/ui.css` | `scripts/ui/*` (Control-Knoten + `UiTheme.gd`) |
| Audio | `src/core/audio.js` | `scripts/core/GameAudio.gd` (`AudioStreamGenerator`) |
| Online-Koop | `src/net/net.js`, `server/` | `scripts/net/Net.gd` (`WebSocketPeer`, gleiches Protokoll) |
| Spielstand | `localStorage` | `user://nullwerk.save.v1.json` |
| Einstellungen | `localStorage` | `user://nullwerk.settings.v1.json` (`scripts/systems/Settings.gd`) |
| Einstiegspunkt | `src/main.js` | `scripts/Game.gd` (`scenes/Main.tscn`) |

Der Server aus `server/` bedient beide Fassungen — das JSON-Protokoll ist
unverändert.

### Titelbildschirm und Einstellungen

Der Titelbildschirm (`scripts/ui/MenuScreen.gd`) baut die Menüspalte rechts
über der Szene auf: Leuchtröhre am Rand, wandernder Lichtbalken, Clubname als
Neonschrift, gruppierte und nummerierte Einträge, ein Streifen mit dem Stand
der gespeicherten Karriere und eine Fusszeile mit Tastenhilfe und
Vollbild-Knopf. Bedienbar ist die Auswahl mit Maus und mit den Pfeiltasten.

**EINSTELLUNGEN** (`scripts/ui/SettingsScreen.gd`) ist ein eigener Bildschirm
mit vier Bereichen:

* **BILD** — Auflösung des Fensters (AUTO oder fest von 1280 × 720 bis
  3840 × 2160), Anzeige (Fenster, randloses Vollbild, exklusiv), Bildeffekte
  (Nebel, Scanlines, Funken) und Bildsynchronisation. Anders als im Browser
  ist das hier die echte Fenstergrösse — jede Änderung greift sofort.
* **TON** — stumm sowie Regler für Gesamt-, Musik- und Effektlautstärke.
* **SPIEL** — Tutorial an oder aus.
* **DATEN** — Spielstand löschen, Einstellungen auf Werk zurücksetzen.

Alles liegt in `user://nullwerk.settings.v1.json` und wird beim Start
angewendet (`Game.apply_settings()` und `Settings.apply_window()`).

Aus einer laufenden Karriere führen drei Wege zurück zum Titel: im Pausenmenü
**ZURÜCK ZUM HAUPTMENÜ** (mit Rückfrage, verwirft die Nacht und verlässt einen
Online-Raum), im Night Report und im Büro. **SCHICHT BEENDEN** im Pausenmenü
schliesst die Nacht dagegen regulär ab und zeigt den Report.

### Prüfen

```bash
# Alle Skripte auf Syntaxfehler prüfen
for f in $(find godot/scripts -name "*.gd"); do
  godot --headless --path godot --check-only --script "res://${f#godot/}"
done

# Regressionstests (Systeme, ganze Nächte solo und im Koop, Spielstand)
godot --headless --path godot --script res://tests/run_tests.gd

# Bildschirmfotos des ganzen Spielflusses (braucht einen X-Server)
xvfb-run -a godot --path godot --script res://tools/screenshot.gd -- --out /tmp/shots

# Tastenbelegung neu schreiben (nach Änderungen an tools/write_input_map.gd)
godot --headless --path godot --script res://tools/write_input_map.gd
```
