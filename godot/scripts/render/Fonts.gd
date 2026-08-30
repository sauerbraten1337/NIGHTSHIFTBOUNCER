## Schriften der Web-Fassung, in Godot verfuegbar gemacht.
##
## index.html laedt drei Schriften von Google Fonts:
##   Archivo Black    - Ueberschriften, Zahlen auf Geraeten
##   IBM Plex Mono    - alles Technische, HUD, Beschriftungen
##   Caveat           - Handschrift auf dem Notizzettel
##
## Godot braucht sie als Datei. Liegen sie unter res://fonts/, werden sie
## benutzt; fehlen sie, faellt alles auf die eingebaute Schrift zurueck -
## das Spiel laeuft dann, sieht aber anders aus als die Vorlage.
##
## Zusaetzlich bildet dieses Modul `letterSpacing` aus dem Canvas ab: Godot
## kennt das nur ueber FontVariation.spacing_glyph.
class_name Fonts
extends RefCounted

const MONO_PATH := "res://fonts/IBMPlexMono-Regular.ttf"
const MONO_BOLD_PATH := "res://fonts/IBMPlexMono-SemiBold.ttf"
const DISPLAY_PATH := "res://fonts/ArchivoBlack-Regular.ttf"
const HAND_PATH := "res://fonts/Caveat-SemiBold.ttf"

static var _cache: Dictionary = {}

static func _load(path: String) -> Font:
	if _cache.has(path):
		return _cache[path]
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path)
	if font == null:
		font = ThemeDB.fallback_font
	_cache[path] = font
	return font

## IBM Plex Mono - die Arbeitsschrift des Spiels.
static func mono() -> Font:
	return _load(MONO_PATH)

static func mono_bold() -> Font:
	return _load(MONO_BOLD_PATH)

## Archivo Black - fette Ueberschriften und Geraeteziffern.
static func display() -> Font:
	return _load(DISPLAY_PATH)

## Caveat - die Handschrift auf dem Notizzettel.
static func hand() -> Font:
	return _load(HAND_PATH)

## Entspricht ctx.letterSpacing. Das Ergebnis wird gecacht, damit nicht bei
## jedem Frame eine neue FontVariation entsteht.
static func spaced(base: Font, spacing: float) -> Font:
	if is_zero_approx(spacing):
		return base
	var key := "%s@%.2f" % [base.get_instance_id(), spacing]
	if _cache.has(key):
		return _cache[key]
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = int(round(spacing))
	_cache[key] = variation
	return variation

## Kurzform: Mono mit Sperrung, wie sie die Szenen durchgehend benutzen.
static func mono_spaced(spacing: float) -> Font:
	return spaced(mono(), spacing)

static func display_spaced(spacing: float) -> Font:
	return spaced(display(), spacing)

## Sind die echten Schriften vorhanden? Fuer eine Warnung beim Start.
static func available() -> bool:
	return ResourceLoader.exists(MONO_PATH) and ResourceLoader.exists(DISPLAY_PATH)
