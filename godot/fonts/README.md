# Schriften

Dieselben drei Schriften, die `index.html` in der Web-Fassung von Google Fonts
lädt — hier als Datei, weil Godot keine Web-Schriften nachlädt.

| Datei | Schrift | Verwendung | Lizenz |
| --- | --- | --- | --- |
| `IBMPlexMono-Regular.ttf` | IBM Plex Mono | HUD, Beschriftungen, alles Technische | SIL Open Font License 1.1 |
| `IBMPlexMono-SemiBold.ttf` | IBM Plex Mono SemiBold | Hervorhebungen | SIL Open Font License 1.1 |
| `ArchivoBlack-Regular.ttf` | Archivo Black | Überschriften, Geräteziffern | SIL Open Font License 1.1 |
| `Caveat-SemiBold.ttf` | Caveat SemiBold | Handschrift auf dem Notizzettel | SIL Open Font License 1.1 |

Alle vier stehen unter der SIL Open Font License 1.1 und dürfen mit dem Spiel
ausgeliefert werden. Bezogen von `fonts.gstatic.com`.

Geladen werden sie über `scripts/render/Fonts.gd`. Fehlt eine Datei, fällt das
Spiel auf Godots eingebaute Schrift zurück — es läuft dann, sieht aber anders
aus als die Vorlage.
