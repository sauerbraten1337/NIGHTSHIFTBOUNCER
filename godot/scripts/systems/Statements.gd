## Aussagen: was der Gast von sich aus behauptet.
##
## ANSPRECHEN liefert nicht nur den Namen. Jeder Gast hat zwei bis drei
## Aussagen im Gepaeck - ueber sein Alter, sein Dokument, seine Taschen, seinen
## Zustand. Jede davon ist ueberpruefbar: gegen den Ausweis, gegen das, was man
## an ihm sieht, gegen den Alkoholwert oder gegen das, was beim Abtasten auf
## den Tisch kommt.
##
## Manche Aussagen sind gelogen. Das Spiel sagt nicht welche - es merkt sich
## nur, ob sie stimmten, und rechnet erst nach der Entscheidung ab. Wer nicht
## zuhoert, verschenkt eine ganze Pruefebene.
##
## Portierung von src/systems/statements.js. Die JS-Fassung haelt je Art eine
## `build`-Funktion im Tabelleneintrag; GDScript kennt keine Methoden in
## Konstanten, darum steht der Text in KIND_CHECKS und das Bauen in
## _build_kind().
class_name Statements
extends RefCounted

## Alle Aussage-Arten in ihrer Reihenfolge. 'age' ist immer die erste.
const KIND_IDS := ["age", "document", "bag", "items", "sober", "state", "visit"]

## Woran es zu merken war - wird dem Spieler erst im Nachhinein gezeigt.
const KIND_CHECKS := {
	"age": "Alter gegen das Geburtsdatum im Ausweis",
	"document": "Aussage gegen das Ablaufdatum auf der Karte",
	"bag": "Aussage gegen das, was der Gast sichtbar dabeihat",
	"items": "Aussage gegen das, was beim Abtasten auftaucht",
	"sober": "Aussage gegen Alkoholwert und Auftreten",
	"state": "Aussage gegen das, was man der Person ansieht",
	"visit": "Nicht überprüfbar - reine Behauptung",
}

## Liefert Text und Wahrheitsgehalt fuer genau diesen Gast.
static func _build_kind(id: String, rng: Rng, guest: Dictionary) -> Dictionary:
	var truth: Dictionary = guest["truth"]
	var doc: Dictionary = guest["doc"]
	var issues: Array = truth.get("idIssues", [])

	match id:
		"age":
			var doc_age := Identity.age_from_birth(doc["birth"])
			var real_age: int = truth["age"]
			# Wer ein manipuliertes Dokument hat, verplappert sich manchmal und
			# nennt sein echtes Alter - das passt dann nicht zur Karte.
			var slips: bool = bool(doc["tampered"]) and rng.chance(0.5)
			# Selten verschaetzt sich jemand auch ohne Faelschung um ein, zwei
			# Jahre - wer aufpasst, merkt trotzdem, dass es nicht zur Karte passt.
			var claimed := real_age if slips \
				else doc_age + (rng.range_int(1, 3) if rng.chance(0.05) else 0)
			return {
				"text": rng.pick([
					"Ich bin %d." % claimed,
					"Ich bin %d, seit letztem Jahr." % claimed,
					"%d bin ich." % claimed,
				]),
				"lie": claimed != doc_age,
				"idle": false,
			}

		"document":
			var expired: bool = issues.has("expired")
			var honest_doc: bool = not expired or rng.chance(0.35)
			return {
				"text": rng.pick([
					"Der Ausweis ist abgelaufen, ich weiss.", "Der ist alt, aber ich bins.",
				]) if honest_doc and expired else rng.pick([
					"Der Ausweis ist noch lange gültig.",
					"Den hab ich erst neu machen lassen.",
					"Alles frisch, der gilt noch Jahre.",
				]),
				"lie": expired and not honest_doc,
				"idle": false,
			}

		"bag":
			var has_bag := bool(truth.get("hasBag", false))
			var honest_bag: bool = not has_bag or rng.chance(0.78)
			var bag_text: String
			if has_bag and honest_bag:
				bag_text = rng.pick(["Nur die Tasche, sonst nichts.", "Die Tasche muss mit rein, sorry."])
			elif has_bag:
				bag_text = rng.pick(["Ich hab nichts dabei.", "Keine Tasche, nichts."])
			else:
				bag_text = rng.pick(["Ich hab nur Handy und Schlüssel.", "Hosentaschen, mehr nicht."])
			return {"text": bag_text, "lie": has_bag and not honest_bag, "idle": false}

		"items":
			var carries: bool = truth.get("contraband", null) != null
			var honest_items: bool = not carries or rng.chance(0.15)
			return {
				"text": rng.pick([
					"Ich hab da was dabei, das ihr vielleicht nicht mögt.",
					"Bevor ihr fragt: in der Jacke ist was.",
				]) if carries and honest_items else rng.pick([
					"Ich hab nichts dabei, ehrlich.",
					"Nichts Verbotenes, könnt ihr durchsuchen.",
					"Ausser Kleingeld ist da nichts.",
				]),
				"lie": carries and not honest_items,
				"idle": false,
			}

		"sober":
			var drunk := float(truth["drunk"])
			var over_limit: bool = drunk * 2.4 >= Config.ALCOHOL_LIMIT_PROMILLE
			var honest_sober: bool = not over_limit or rng.chance(0.25)
			return {
				"text": rng.pick([
					"Ich hab was getrunken, klar.", "Zwei, drei Bier waren es schon.",
				]) if over_limit and honest_sober else rng.pick([
					"Ich hab heute nichts getrunken.",
					"Ich bin komplett nüchtern.",
					"Ein Bier, mehr nicht.",
				]),
				"lie": over_limit and not honest_sober,
				"idle": false,
			}

		"state":
			var impaired: bool = float(truth.get("impaired", 0.0)) >= 0.5
			var honest_state: bool = not impaired or rng.chance(0.2)
			return {
				"text": rng.pick([
					"Mir gehts nicht ganz so gut, aber passt schon.",
					"Langer Tag, sieht man mir an.",
				]) if impaired and honest_state else rng.pick([
					"Mir gehts blendend, alles normal.",
					"Ich bin nur müde von der Arbeit.",
					"Alles gut bei mir, wirklich.",
				]),
				"lie": impaired and not honest_state,
				"idle": false,
			}

		_:  # "visit"
			return {
				"text": rng.pick([
					"Ich war letzte Woche schon hier.",
					"Ich kenn hier ein paar Leute.",
					"Ich bin mit Freunden verabredet, die sind schon drin.",
					"Erstes Mal hier, ehrlich gesagt.",
				]),
				# Geplauder ohne Pruefmoeglichkeit: nie eine wertbare Luege.
				"lie": false,
				"idle": true,
			}

## Baut die Aussagen eines Gastes. Immer dabei: eine zum Alter.
## Danach kommen ein bis zwei weitere - bevorzugt zu Dingen, bei denen dieser
## Gast tatsaechlich etwas zu verbergen hat, damit sich Zuhoeren lohnt.
static func build_statements(rng: Rng, guest: Dictionary) -> Array[Dictionary]:
	var pool: Array[String] = []
	for id: String in KIND_IDS:
		if id != "age":
			pool.append(id)

	var extras: Array[String] = []
	var count := mini(pool.size(), rng.range_int(1, 2))
	for i in count:
		var remaining: Array[String] = []
		for id: String in pool:
			if not extras.has(id):
				remaining.append(id)
		if remaining.is_empty():
			break
		extras.append(rng.weighted_pick_fn(
			remaining, func(id: Variant) -> float: return _weight_of(id, guest)
		))

	var chosen: Array[String] = ["age"]
	chosen.append_array(extras)

	var out: Array[Dictionary] = []
	for id: String in chosen:
		var built := _build_kind(id, rng, guest)
		out.append({
			"id": id,
			"text": built["text"],
			"lie": bool(built["lie"]),
			"check": KIND_CHECKS[id],
		})
	return out

## Wie interessant ist diese Aussage bei diesem Gast?
static func _weight_of(id: String, guest: Dictionary) -> float:
	var t: Dictionary = guest["truth"]
	match id:
		"document":
			return 4.0 if (t.get("idIssues", []) as Array).has("expired") else 1.0
		"bag":
			return 3.0 if t.get("hasBag", false) else 1.0
		"items":
			return 4.0 if t.get("contraband", null) != null else 1.0
		"sober":
			return 4.0 if float(t["drunk"]) * 2.4 >= Config.ALCOHOL_LIMIT_PROMILLE else 1.0
		"state":
			return 4.0 if float(t.get("impaired", 0.0)) >= 0.5 else 1.0
		_:
			return 1.5

## Hat der Gast in dem, was er gesagt hat, gelogen?
static func revealed_lies(said: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in said:
		if s["lie"]:
			out.append(s)
	return out

## Alle Luegen, die er (auch ungefragt) im Gepaeck hat.
static func all_lies(guest: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if guest == null:
		return out
	var statements: Array = (guest["truth"] as Dictionary).get("statements", [])
	for s: Dictionary in statements:
		if s["lie"]:
			out.append(s)
	return out

## Nur zur Anzeige: Kurzform fuer den Notizzettel.
static func statement_summary(said: Array) -> String:
	if said.is_empty():
		return "NICHTS GESAGT"
	var texts: PackedStringArray = []
	for s: Dictionary in said:
		texts.append(s["text"])
	return " ".join(texts)
