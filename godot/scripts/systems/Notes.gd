## Notizzettel des Spielers.
##
## Seite 1: Checkliste - was muss ich bei diesem Gast noch pruefen?
##          Der Spieler hakt selbst ab, das Spiel hakt nichts fuer ihn ab.
## Seite 2: Befund - der Spieler traegt selbst ein, welche Punkte der Norm
##          entsprechen und welche nicht.
##
## Beides ist reine Spielernotiz: das Spiel bewertet sie erst nach der
## Entscheidung ueber den Gast.
##
## Portierung von src/systems/notes.js.
class_name Notes
extends RefCounted

## Welche Punkte gehoeren zu diesem Bereich? (Solo sieht alles.)
static func checklist_for(area: String, solo: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in Config.CHECKLIST:
		if solo or c["area"] == area:
			out.append(c)
	return out

static func topics_for(area: String, solo: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in Config.NOTE_TOPICS:
		if solo or t["area"] == area:
			out.append(t)
	return out

static func empty_notes() -> Dictionary:
	return {
		"page": 0,      # 0 = Checkliste, 1 = Befund
		"checked": {},  # Checklisten-Id -> true
		"topics": {},   # Themen-Id -> 'ok' | 'bad'
	}

## Haken setzen oder wieder entfernen.
static func toggle_check(notes: Variant, id: String) -> Variant:
	if notes == null or not _has_id(Config.CHECKLIST, id):
		return null
	var checked: Dictionary = notes["checked"]
	if checked.get(id, false):
		checked.erase(id)
	else:
		checked[id] = true
	return {"id": id, "checked": checked.get(id, false)}

## Befund umschalten: leer -> entspricht der Norm -> entspricht nicht -> leer.
const TOPIC_CYCLE := [null, "ok", "bad"]

static func toggle_topic(notes: Variant, id: String) -> Variant:
	if notes == null or not _has_id(Config.NOTE_TOPICS, id):
		return null
	var topics: Dictionary = notes["topics"]
	var current: Variant = topics.get(id, null)
	var idx := TOPIC_CYCLE.find(current)
	var next: Variant = TOPIC_CYCLE[(idx + 1) % TOPIC_CYCLE.size()]
	if next == null:
		topics.erase(id)
	else:
		topics[id] = next
	return {"id": id, "state": next}

## Ohne `page` wird umgeblaettert, mit `page` gezielt gesetzt.
static func flip_page(notes: Variant, page: Variant = null) -> Variant:
	if notes == null:
		return null
	if page == null:
		notes["page"] = 1 if notes["page"] == 0 else 0
	else:
		notes["page"] = 1 if bool(page) else 0
	return notes["page"]

## Wie viele Punkte hat der Spieler als "entspricht nicht" eingetragen?
static func reported_problems(notes: Variant) -> Array[String]:
	var out: Array[String] = []
	if notes == null:
		return out
	var topics: Dictionary = notes["topics"]
	for t: Dictionary in Config.NOTE_TOPICS:
		if topics.get(t["id"], null) == "bad":
			out.append(t["id"])
	return out

static func topic_label(id: String) -> String:
	for t: Dictionary in Config.NOTE_TOPICS:
		if t["id"] == id:
			return t["label"]
	return id

static func check_label(id: String) -> String:
	for c: Dictionary in Config.CHECKLIST:
		if c["id"] == id:
			return c["label"]
	return id

static func _has_id(table: Array, id: String) -> bool:
	for entry: Dictionary in table:
		if entry["id"] == id:
			return true
	return false
