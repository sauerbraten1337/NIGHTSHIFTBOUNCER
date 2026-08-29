## Der eigene Tuersteher: Aussehen und Name.
##
## Wird einmal beim Start erstellt (Charaktereditor) und laesst sich spaeter
## am Kleiderschrank im Buero jederzeit aendern. Die Figur taucht im
## Nachtabschluss und im Buero auf - gezeichnet mit demselben Figure.draw()
## wie alle anderen Menschen im Spiel.
##
## Portierung von src/systems/character.js. Heisst CharacterSys, weil
## "Character" in Godot bereits als Klassenpraefix belegt wirkt
## (CharacterBody2D/3D) und Verwechslungen im Editor stiftet.
class_name CharacterSys
extends RefCounted

## Auswahl fuer den Streifen auf der Jacke - das persoenliche Erkennungszeichen.
const ACCENTS := [
	{"id": "red", "label": "ROT", "color": "ff2f3c"},
	{"id": "cyan", "label": "CYAN", "color": "39d7ff"},
	{"id": "amber", "label": "AMBER", "color": "ffb638"},
	{"id": "green", "label": "GRÜN", "color": "4ce08a"},
	{"id": "purple", "label": "VIOLETT", "color": "8b5cff"},
	{"id": "none", "label": "OHNE", "color": ""},
]

const HAIR_STYLES := [
	{"id": 0, "label": "KURZ"},
	{"id": 1, "label": "VOLL"},
	{"id": 2, "label": "ZURÜCK"},
	{"id": 3, "label": "LANG"},
]

const BUILDS := [
	{"id": "schlank", "label": "SCHLANK", "bulk": 0.92},
	{"id": "normal", "label": "NORMAL", "bulk": 1.05},
	{"id": "kräftig", "label": "KRÄFTIG", "bulk": 1.18},
	{"id": "schrank", "label": "SCHRANK", "bulk": 1.32},
]

const FIRST_NAMES := [
	"ALEX", "MIKA", "JONAS", "SAM", "NURI", "ROBIN", "KAY", "TONI",
	"LENA", "DENIZ", "MARLON", "SASCHA", "ELI", "FINN", "JUNO",
]

## Ein zufaelliger, aber immer plausibler Tuersteher.
## `random` liefert Werte in [0, 1); ohne Angabe wird echt gewuerfelt.
static func create_character(random: Callable = Callable()) -> Dictionary:
	var roll := func() -> float:
		return randf() if not random.is_valid() else float(random.call())
	var pick := func(n: int) -> int:
		return int(floor(roll.call() * n))
	return {
		"name": FIRST_NAMES[pick.call(FIRST_NAMES.size())],
		"skin": pick.call(Palette.SKIN.size()),
		"hair": pick.call(Palette.HAIR.size()),
		"hairStyle": pick.call(HAIR_STYLES.size()),
		"outfit": pick.call(Palette.OUTFIT.size()),
		"build": BUILDS[1 + pick.call(BUILDS.size() - 1)]["id"],
		"beard": roll.call() > 0.5,
		"accent": ACCENTS[pick.call(ACCENTS.size() - 1)]["id"],
		"created": false,
	}

## Fehlende Felder auffuellen - alte Spielstaende kennen den Charakter nicht.
static func normalize_character(character: Variant) -> Dictionary:
	var base := create_character(func() -> float: return 0.5)
	var merged := base.duplicate(true)
	if character is Dictionary:
		for key: Variant in (character as Dictionary):
			merged[key] = (character as Dictionary)[key]

	var name_text := String(merged.get("name", "")).strip_edges().substr(0, 14).to_upper()
	merged["name"] = name_text if not name_text.is_empty() else base["name"]
	merged["skin"] = _clamp_index(merged.get("skin", 0), Palette.SKIN.size())
	merged["hair"] = _clamp_index(merged.get("hair", 0), Palette.HAIR.size())
	merged["hairStyle"] = _clamp_index(merged.get("hairStyle", 0), HAIR_STYLES.size())
	merged["outfit"] = _clamp_index(merged.get("outfit", 0), Palette.OUTFIT.size())
	if not _has_id(BUILDS, String(merged.get("build", ""))):
		merged["build"] = BUILDS[1]["id"]
	if not _has_id(ACCENTS, String(merged.get("accent", ""))):
		merged["accent"] = ACCENTS[0]["id"]
	merged["beard"] = bool(merged.get("beard", false))
	merged["created"] = bool(merged.get("created", false))
	return merged

static func _clamp_index(value: Variant, length: int) -> int:
	var n := 0.0
	if value is float or value is int:
		n = float(value)
	if not is_finite(n):
		return 0
	return ((int(round(n)) % length) + length) % length

static func _has_id(table: Array, id: String) -> bool:
	for entry: Dictionary in table:
		if entry["id"] == id:
			return true
	return false

## Umrechnung in das `look`-Objekt, das Figure.draw() versteht.
static func character_look(character: Variant) -> Dictionary:
	var c := normalize_character(character)
	var bulk := 1.05
	for b: Dictionary in BUILDS:
		if b["id"] == c["build"]:
			bulk = b["bulk"]
			break
	return {
		"skin": c["skin"],
		"hair": c["hair"],
		"hairStyle": c["hairStyle"],
		"outfit": c["outfit"],
		"beard": c["beard"],
		"bulk": bulk,
	}

## Liefert die Akzentfarbe oder null, wenn "OHNE" gewaehlt ist.
static func accent_color(character: Variant) -> Variant:
	var accent := String(normalize_character(character)["accent"])
	for a: Dictionary in ACCENTS:
		if a["id"] == accent:
			var hex := String(a["color"])
			return null if hex.is_empty() else Color(hex)
	return null
