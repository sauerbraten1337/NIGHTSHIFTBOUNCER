## Save System: Persistenz (Metaprogression, keine laufende Nacht).
##
## Portierung von src/systems/save.js. Statt localStorage schreibt die
## Godot-Fassung eine JSON-Datei nach user:// - dieselbe Feldliste, dasselbe
## Zusammenfuehren beim Laden. Der Pfad ist ueberschreibbar, damit Tests
## nicht in den echten Spielstand schreiben.
class_name SaveGame
extends RefCounted

const DEFAULT_PATH := "user://nullwerk.save.v1.json"

const PERSISTED := [
	"version", "money", "reputation", "xp", "talentPoints", "talents", "upgrades",
	"nightIndex", "clubsOwned", "expandUnlocked", "lifetime", "character",
]

static func save_game(state: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var data := {}
	for key: String in PERSISTED:
		data[key] = state[key]
	data["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

static func load_game(state: Dictionary, path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var raw := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(raw)
	if data == null or not (data is Dictionary):
		return false

	for key: String in PERSISTED:
		if key == "version":
			continue
		if not (data as Dictionary).has(key):
			continue
		var incoming: Variant = (data as Dictionary)[key]
		var current: Variant = state[key]
		# Verschachtelte Objekte (talents, upgrades, lifetime, character)
		# werden zusammengefuehrt, damit neue Felder aus einer neueren
		# Spielversion erhalten bleiben.
		if current is Dictionary and incoming is Dictionary:
			for sub_key: Variant in (incoming as Dictionary):
				(current as Dictionary)[sub_key] = (incoming as Dictionary)[sub_key]
		else:
			state[key] = incoming
	return true

## Kurzer Blick in den Spielstand, ohne ihn zu laden - das Hauptmenue zeigt
## damit an, wo die Karriere steht. null, wenn es keinen gibt.
static func peek_save(path: String = DEFAULT_PATH) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(raw)
	if data == null or not (data is Dictionary):
		return null
	var d := data as Dictionary
	var character: Variant = d.get("character", null)
	return {
		"nightIndex": int(d.get("nightIndex", 0)),
		"money": float(d.get("money", 0.0)),
		"reputation": float(d.get("reputation", 0.0)),
		"name": (character as Dictionary).get("name", null) if character is Dictionary else null,
		"savedAt": int(d.get("savedAt", 0)),
	}

static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)

static func clear_save(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK \
		or DirAccess.open(path.get_base_dir()).remove(path.get_file()) == OK
