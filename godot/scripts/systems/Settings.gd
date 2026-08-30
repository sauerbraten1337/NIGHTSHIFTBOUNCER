## Einstellungen: Bild, Ton und Spiel - dauerhaft in user://.
##
## Gegenstueck zu src/systems/settings.js. Die Web-Fassung rechnet an einem
## Zeichenpuffer herum, weil sie in einer Seite sitzt; hier gibt es ein echtes
## Fenster, also ist "Aufloesung" auch wirklich die Fenstergroesse und
## "Anzeige" der Fenstermodus.
##
## Alles hier ist reine Datenhaltung plus ein kleiner Verteiler: wer etwas
## aendert, ruft `set_value`, und jeder Teil des Spiels, der davon betroffen
## ist (Fenster, Renderer, Audio), haengt sich ueber `changed` an.
class_name Settings
extends RefCounted

const DEFAULT_PATH := "user://nullwerk.settings.v1.json"

## Fenstergroessen. "AUTO" nimmt die Groesse des Bildschirms, auf dem das
## Fenster steht - alles andere ist fest.
const RESOLUTIONS: Array[Dictionary] = [
	{"id": "auto", "label": "AUTO", "note": "Passt sich dem Bildschirm an", "size": Vector2i.ZERO},
	{"id": "1280x720", "label": "1280 × 720", "note": "Grundgröße des Spiels", "size": Vector2i(1280, 720)},
	{"id": "1600x900", "label": "1600 × 900", "note": "Ausgewogen", "size": Vector2i(1600, 900)},
	{"id": "1920x1080", "label": "1920 × 1080", "note": "Scharf", "size": Vector2i(1920, 1080)},
	{"id": "2560x1440", "label": "2560 × 1440", "note": "Sehr scharf", "size": Vector2i(2560, 1440)},
	{"id": "3840x2160", "label": "3840 × 2160", "note": "Nur für grosse Bildschirme", "size": Vector2i(3840, 2160)},
]

## Fenstermodus. Godots Vollbild ist rahmenlos ueber den ganzen Bildschirm,
## "exklusiv" uebernimmt den Bildschirm ganz.
const DISPLAY_MODES: Array[Dictionary] = [
	{"id": "window", "label": "FENSTER", "note": "Mit Rahmen, frei verschiebbar"},
	{"id": "fullscreen", "label": "VOLLBILD", "note": "Rahmenlos über den ganzen Bildschirm"},
	{"id": "exclusive", "label": "EXKLUSIV", "note": "Bildschirm ganz übernehmen"},
]

const DEFAULTS := {
	"resolution": "1280x720",
	"display": "window",
	"effects": true,      # Nebel, Scanlines, Vignette, Funken
	"vsync": true,
	"tutorial": true,
	"master": 0.9,
	"music": 0.5,
	"sfx": 0.55,
	"muted": false,
}

# ---------- Zustand ----------

static var _values: Dictionary = {}
static var _loaded := false
static var _listeners: Array[Callable] = []
static var _path := DEFAULT_PATH

## Alle Werte (Kopie der internen Ablage waere teurer als noetig - hier wird
## nur gelesen; geschrieben wird ausschliesslich ueber set_value()).
static func values() -> Dictionary:
	_ensure()
	return _values

static func get_value(key: String, fallback: Variant = null) -> Variant:
	_ensure()
	if _values.has(key):
		return _values[key]
	return fallback if fallback != null else DEFAULTS.get(key)

static func get_bool(key: String) -> bool:
	return bool(get_value(key))

static func get_float(key: String) -> float:
	return float(get_value(key))

static func get_string(key: String) -> String:
	return String(get_value(key))

static func set_value(key: String, value: Variant) -> void:
	_ensure()
	if not DEFAULTS.has(key):
		return
	_values[key] = value
	save()
	_notify(key)

static func reset() -> void:
	_ensure()
	_values = DEFAULTS.duplicate(true)
	save()
	_notify("")

## Meldet einen Zuhoerer an; er bekommt den geaenderten Schluessel (leer bei
## einem kompletten Zuruecksetzen). Rueckgabe meldet ihn wieder ab.
static func on_changed(fn: Callable) -> Callable:
	if not _listeners.has(fn):
		_listeners.append(fn)
	return func() -> void: _listeners.erase(fn)

static func _notify(key: String) -> void:
	for fn: Callable in _listeners.duplicate():
		if fn.is_valid():
			fn.call(key)

# ---------- Ablage ----------

## Nur fuer Tests: Ablageort umlegen und neu laden.
static func use_path(path: String) -> void:
	_path = path
	_loaded = false
	_values = {}

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(_path):
		return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(raw)
	if data == null or not (data is Dictionary):
		return
	for key: Variant in (data as Dictionary):
		# Nur bekannte Schluessel uebernehmen: eine aeltere Datei darf keine
		# Felder einschleusen, die es nicht mehr gibt.
		if DEFAULTS.has(key):
			_values[key] = (data as Dictionary)[key]

static func save() -> bool:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_values))
	file.close()
	return true

# ---------- Nachschlagen ----------

static func resolution_entry(id: String = "") -> Dictionary:
	var wanted := id if id != "" else get_string("resolution")
	for r: Dictionary in RESOLUTIONS:
		if r["id"] == wanted:
			return r
	return RESOLUTIONS[0]

static func display_entry(id: String = "") -> Dictionary:
	var wanted := id if id != "" else get_string("display")
	for d: Dictionary in DISPLAY_MODES:
		if d["id"] == wanted:
			return d
	return DISPLAY_MODES[0]

# ---------- Auf das Fenster anwenden ----------

## Setzt Fenstermodus, Groesse und VSync. Ohne Bildschirm (headless, Tests)
## passiert nichts - dort gibt es kein Fenster, das man einstellen koennte.
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := get_string("display")
	match mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_apply_window_size()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if get_bool("vsync") else DisplayServer.VSYNC_DISABLED
	)

static func _apply_window_size() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var entry := resolution_entry()
	var size: Vector2i = entry["size"]
	if size == Vector2i.ZERO:
		size = usable.size
	# Nie groesser als der Bildschirm: sonst landet die Titelleiste ausserhalb
	# und das Fenster laesst sich nicht mehr fassen.
	size = size.min(usable.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(
		usable.position + (usable.size - size) / 2
	)

## Was gerade wirklich angezeigt wird - fuer die Zeile unter der Auswahl.
static func current_note() -> String:
	if DisplayServer.get_name() == "headless":
		return "KEIN FENSTER (HEADLESS)"
	var size := DisplayServer.window_get_size()
	return "AKTUELL: %d × %d PIXEL · %s" % [
		size.x, size.y, String(display_entry()["label"]),
	]
