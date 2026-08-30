## Identity System: Ausweiskontrolle von Hand.
##
## Das Spiel deckt Fehler NICHT automatisch auf. Der Gast reicht das Dokument
## herueber, der Spieler sieht es gross vor sich und vergleicht selbst:
##
##   FOTO        gegen das Gesicht des Gastes
##   NAME        gegen das, was der Gast beim Ansprechen sagt
##   GEBURTSTAG  gegen das heutige Datum (Mindestalter) und auf Manipulation
##   GUELTIG BIS gegen das heutige Datum
##   MERKMALE    Hologramm vorhanden und sauber?
##
## Ein Feld anklicken schaltet den Status um, den der Spieler dem Feld gibt:
##   unbewertet -> NICHT KORREKT -> IN ORDNUNG -> unbewertet
##
## Das Spiel sagt zu keinem Zeitpunkt, ob die Einschaetzung stimmt. Erst in der
## Auswertung nach der Entscheidung wird verglichen.
##
## Portierung von src/systems/identity.js.
class_name Identity
extends RefCounted

## Die pruefbaren Felder des Dokuments.
const ID_FIELDS := [
	{"id": "photo", "label": "FOTO", "hint": "Passt das Foto zum Gast?"},
	{"id": "name", "label": "NAME", "hint": "Stimmt der Name mit der Aussage?"},
	{"id": "birth", "label": "GEBURTSDATUM", "hint": "Alt genug? Datum unverändert?"},
	{"id": "expiry", "label": "GÜLTIG BIS", "hint": "Noch gültig?"},
	{"id": "marks", "label": "MERKMALE", "hint": "Hologramm und Prägung vorhanden?"},
]

static func today_string() -> String:
	return "%d-%s-%s" % [
		Config.GAME_DATE["year"], _pad(Config.GAME_DATE["month"]), _pad(Config.GAME_DATE["day"])
	]

static func _pad(n: int) -> String:
	return str(n).pad_zeros(2)

static func parse_date(text: String) -> Dictionary:
	var parts := text.split("-")
	return {
		"year": int(parts[0]) if parts.size() > 0 else 0,
		"month": int(parts[1]) if parts.size() > 1 else 0,
		"day": int(parts[2]) if parts.size() > 2 else 0,
	}

static func date_before(a: Dictionary, b: Dictionary) -> bool:
	if a["year"] != b["year"]:
		return a["year"] < b["year"]
	if a["month"] != b["month"]:
		return a["month"] < b["month"]
	return a["day"] < b["day"]

## Alter am heutigen Spieldatum, berechnet aus dem Geburtsdatum.
static func age_from_birth(birth_str: String) -> int:
	var b := parse_date(birth_str)
	var age: int = int(Config.GAME_DATE["year"]) - int(b["year"])
	var month: int = int(Config.GAME_DATE["month"])
	var day: int = int(Config.GAME_DATE["day"])
	if month < int(b["month"]) or (month == int(b["month"]) and day < int(b["day"])):
		age -= 1
	return age

## Welche Felder sind objektiv fehlerhaft?
## Das ist die Wahrheit - der Spieler muss sie selbst finden.
static func faulty_fields(guest: Dictionary) -> Array[String]:
	var issues: Array = (guest["truth"] as Dictionary).get("idIssues", [])
	var fields: Array[String] = []
	if issues.has("photo"):
		fields.append("photo")
	if issues.has("name"):
		fields.append("name")
	if issues.has("marks"):
		fields.append("marks")
	if issues.has("expired"):
		fields.append("expiry")
	if issues.has("age") and not fields.has("birth"):
		fields.append("birth")
	# Ein ehrliches Dokument, das ein zu junges Alter zeigt, ist ebenfalls ein Treffer.
	if age_from_birth((guest["doc"] as Dictionary)["birth"]) < int(Config.TUNING["minAge"]):
		if not fields.has("birth"):
			fields.append("birth")
	return fields

## Der Gast reicht den Ausweis herueber.
static func request_id(state: Dictionary, guest: Dictionary) -> Dictionary:
	var offline := tool_offline(state["night"])
	return {
		"requested": true,
		"doc": guest["doc"],
		"guestId": guest["id"],
		# Einschaetzung des Spielers je Feld: fehlt | 'suspect' | 'fine'
		"marks": {},
		"toolOffline": offline,
		"closed": false,
		# Wahrheit, erst nach der Entscheidung fuer die Auswertung genutzt.
		"faults": faulty_fields(guest),
	}

## Der Reihe nach: unbewertet -> nicht korrekt -> in Ordnung -> unbewertet.
const MARK_CYCLE := [null, "suspect", "fine"]

## Der Spieler schaltet den Status eines Feldes um.
## Es gibt keine Rueckmeldung, ob die Einschaetzung stimmt.
static func toggle_field(inspection: Variant, field: String) -> Variant:
	if inspection == null or not _has_field(field):
		return null
	var marks: Dictionary = inspection["marks"]
	var idx := MARK_CYCLE.find(marks.get(field, null))
	var next: Variant = MARK_CYCLE[(idx + 1) % MARK_CYCLE.size()]
	if next == null:
		marks.erase(field)
	else:
		marks[field] = next
	return {"field": field, "label": field_label(field), "state": next}

## Welche Felder hat der Spieler als "nicht korrekt" markiert?
static func claimed_faults(inspection: Variant) -> Array[String]:
	var out: Array[String] = []
	if inspection == null:
		return out
	var marks: Dictionary = inspection["marks"]
	for f: Dictionary in ID_FIELDS:
		if marks.get(f["id"], null) == "suspect":
			out.append(f["id"])
	return out

## Welche Felder hat der Spieler ueberhaupt bewertet?
static func rated_fields(inspection: Variant) -> Array[String]:
	var out: Array[String] = []
	if inspection == null:
		return out
	var marks: Dictionary = inspection["marks"]
	for f: Dictionary in ID_FIELDS:
		if marks.get(f["id"], null) != null:
			out.append(f["id"])
	return out

## Auswertung NACH der Entscheidung: was hat der Spieler richtig erkannt,
## was hat er zu Unrecht beanstandet, was hat er uebersehen?
static func score_inspection(inspection: Variant, guest: Dictionary) -> Dictionary:
	var faults := faulty_fields(guest)
	var claimed := claimed_faults(inspection)
	var hits: Array[String] = []
	var wrong: Array[String] = []
	var missed: Array[String] = []
	for f: String in claimed:
		if faults.has(f):
			hits.append(f)
		else:
			wrong.append(f)
	for f: String in faults:
		if not claimed.has(f):
			missed.append(f)
	return {"hits": hits, "wrong": wrong, "missed": missed}

static func field_label(field: String) -> String:
	for f: Dictionary in ID_FIELDS:
		if f["id"] == field:
			return f["label"]
	return field.to_upper()

## Klartext, warum ein Feld falsch ist (fuer Feedback nach dem Markieren).
static func reason_for(guest: Dictionary, field: String) -> Variant:
	var issues: Array = (guest["truth"] as Dictionary).get("idIssues", [])
	match field:
		"photo":
			return "Foto passt nicht zum Gast" if issues.has("photo") else null
		"name":
			return "Name weicht von der Aussage ab" if issues.has("name") else null
		"marks":
			return "Sicherheitsmerkmale fehlen" if issues.has("marks") else null
		"expiry":
			return "Dokument ist abgelaufen" if issues.has("expired") else null
		"birth":
			if issues.has("age"):
				return "Geburtsdatum wurde manipuliert"
			if age_from_birth((guest["doc"] as Dictionary)["birth"]) < int(Config.TUNING["minAge"]):
				return "Zu jung laut Dokument"
			return null
		_:
			return null

## Was hat der Spieler selbst angegeben? (Keine Wahrheit, nur seine Angabe.)
static func inspection_verdict(inspection: Variant) -> Dictionary:
	if inspection == null:
		return {"checked": false, "clean": null, "claimed": [], "rated": 0}
	var claimed := claimed_faults(inspection)
	return {
		"checked": true,
		"claimed": claimed,
		"rated": rated_fields(inspection).size(),
		# "sauber" heisst hier: der Spieler hat nichts beanstandet.
		"clean": claimed.is_empty(),
	}

static func id_summary(inspection: Variant) -> String:
	if inspection == null:
		return "NICHT GEPRÜFT"
	var claimed := claimed_faults(inspection)
	if claimed.is_empty():
		return "ALLES IN ORDNUNG (EIGENE ANGABE)" if not rated_fields(inspection).is_empty() \
			else "NOCH NICHTS BEWERTET"
	var labels: PackedStringArray = []
	for f: String in claimed:
		labels.append(field_label(f))
	return " / ".join(labels)

## Bezeichnung des Pruefgeraets (frueher der Scanner).
static func doc_tool_label(level: int) -> String:
	var names := ["SICHTPRÜFUNG", "UV-LAMPE", "SCHNELLPRÜFUNG", "FEINANALYSE"]
	return names[level] if level >= 0 and level < names.size() else "SICHTPRÜFUNG"

## Faellt das Geraet gerade aus?
static func tool_offline(night: Variant) -> bool:
	if night == null:
		return false
	for e: Dictionary in (night["activeEffects"] as Array):
		if e["id"] == "scannerFail" or e["id"] == "blackout":
			return true
	return false

static func issue_label(id: String) -> String:
	for i: Dictionary in Config.ID_ISSUES:
		if i["id"] == id:
			return i["label"]
	return id

static func _has_field(field: String) -> bool:
	for f: Dictionary in ID_FIELDS:
		if f["id"] == field:
			return true
	return false
