## Tutorial: eine ruhige erste Schicht, die alles nacheinander erklaert.
##
## Statt einer Textwand kommt jede Mechanik mit genau einem Gast, an dem man
## sie ausprobiert. Erst wenn der Schritt sitzt, geht es weiter - und erst dann
## wird die naechste Mechanik ueberhaupt freigeschaltet.
##
## Portierung von src/systems/tutorial.js. Die Vorlage haelt setup/wait/title
## als Funktionen im Tabelleneintrag; GDScript kennt keine Methoden in
## Konstanten, darum steht die Reihenfolge in STEP_IDS und das Verhalten in
## _setup_step() / _step_done() / _title_of() / _body_of() / _hint_of().
class_name Tutorial
extends RefCounted

const STEP_IDS := [
	"welcome", "spawn1", "inspect1", "admit1", "expired", "age",
	"talkUnlock", "photo", "marks", "security", "queue", "done",
]

const TUTORIAL_STEP_COUNT := 12

## Welche Mechanik schaltet ein Schritt frei?
const STEP_UNLOCKS := {
	"talkUnlock": ["talk"],
	"security": ["search", "alcohol"],
	"queue": ["calm"],
}

# ---------- Gast nach Drehbuch ----------

## Baut einen Gast mit genau den Eigenschaften, die der Schritt zeigen soll.
static func _scripted(game: Dictionary, spec: Dictionary = {}) -> Dictionary:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var has_bag := bool(spec.get("bag", false))

	var guest := Guests.create_guest(rng, {
		"reputation": float(state["reputation"]),
		"nightIndex": 0,
		"forceArchetype": spec.get("archetype", "regular"),
	})
	var t: Dictionary = guest["truth"]
	var doc: Dictionary = guest["doc"]

	# Standard: sauber und unauffaellig.
	t["idIssues"] = []
	t["idValid"] = true
	t["underage"] = false
	t["age"] = 24 + (int(guest["seed"]) % 12)
	t["drunk"] = 0.1
	t["risk"] = 0.05
	t["blacklisted"] = false
	t["contraband"] = null
	t["contrabandZone"] = null
	t["impaired"] = 0.0
	t["impairmentSigns"] = []
	# Saubere, ueberschaubare Taschen: nur harmlose Sachen.
	t["hasBag"] = has_bag
	var zone_ids: Array[String] = []
	for z: Dictionary in Config.ZONES:
		if not z["needsBag"] or has_bag:
			zone_ids.append(z["id"])
	t["zoneIds"] = zone_ids
	var carried := {
		"jacket": _items(["phone", "lighter"]),
		"pockets": _items(["keys", "gum"]),
	}
	if has_bag:
		carried["bag"] = _items(["bottle", "charger"])
	t["carried"] = carried

	doc["name"] = guest["name"]
	doc["tampered"] = false
	doc["marksOk"] = true
	doc["photoLook"] = (guest["look"] as Dictionary).duplicate()
	doc["birth"] = _birth_for(int(t["age"]))
	doc["expiry"] = "2031-06-30"
	guest["personality"] = spec.get("personality", "polite")
	guest["patience"] = 999.0
	guest["patienceMax"] = 999.0

	_build_spec(guest, String(spec.get("id", "")))
	# Die Aussagen muessen zur (jetzt ueberschriebenen) Wahrheit passen.
	t["statements"] = Statements.build_statements(rng, guest)
	guest["tutorial"] = spec.get("id", true)
	return guest

## Die `build`-Rueckrufe der Vorlage, nach Schritt-Id aufgeschluesselt.
static func _build_spec(guest: Dictionary, id: String) -> void:
	var t: Dictionary = guest["truth"]
	var doc: Dictionary = guest["doc"]
	match id:
		"expired":
			t["idIssues"] = ["expired"]
			t["idValid"] = false
			doc["expiry"] = "2023-08-19"
		"underage":
			t["age"] = 16
			t["underage"] = true
			doc["birth"] = _birth_for(16)
		"name":
			t["idIssues"] = ["name"]
			t["idValid"] = false
			doc["name"] = "Kaspar Novak"
		"photo":
			t["idIssues"] = ["photo"]
			t["idValid"] = false
			var look: Dictionary = guest["look"]
			var photo := look.duplicate()
			photo["skin"] = (int(look["skin"]) + 3) % 6
			photo["hair"] = (int(look["hair"]) + 4) % 7
			doc["photoLook"] = photo
		"marks":
			t["idIssues"] = ["marks"]
			t["idValid"] = false
			doc["marksOk"] = false
		"contraband":
			var spray: Variant = Config.item_by_id("spray")
			t["contraband"] = spray
			t["contrabandZone"] = "bag"
			var bag: Array[Dictionary] = []
			var bottle: Variant = Config.item_by_id("bottle")
			var mints: Variant = Config.item_by_id("mints")
			if bottle != null:
				bag.append(bottle)
			if spray != null:
				bag.append(spray)
			if mints != null:
				bag.append(mints)
			(t["carried"] as Dictionary)["bag"] = bag
			var all_items: Array[Dictionary] = []
			for zone: String in (t["carried"] as Dictionary):
				all_items.append_array((t["carried"] as Dictionary)[zone])
			t["items"] = all_items
			t["risk"] = 0.6

static func _items(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ids:
		var item: Variant = Config.item_by_id(id)
		if item != null:
			out.append(item)
	return out

static func _birth_for(age: int) -> String:
	# Immer vor dem 14. Maerz, damit das Alter exakt aufgeht.
	return "%d-01-12" % (2026 - age)

# ---------- Schritt-Texte ----------

static func _title_of(game: Dictionary, id: String) -> String:
	match id:
		"welcome": return "SCHICHTBEGINN"
		"spawn1": return "ERSTER GAST"
		"inspect1": return "SELBST PRÜFEN"
		"admit1": return "ENTSCHEIDEN"
		"expired": return "ABGELAUFEN"
		"age": return "ZU JUNG"
		"talkUnlock": return "ANSPRECHEN FREIGESCHALTET"
		"photo": return "FOTO VERGLEICHEN"
		"marks": return "SICHERHEITSMERKMALE"
		"security": return "KONTROLLE" if GameState.is_solo(game["state"]) else "DIE SCHLEUSE"
		"queue": return "DIE SCHLANGE WARTET"
		"done": return "SCHICHT LÄUFT"
	return id

static func _body_of(game: Dictionary, id: String) -> String:
	var solo := GameState.is_solo(game["state"])
	match id:
		"welcome":
			return "Du stehst an der Tür des NULLWERK. Vor dir die Strasse, hinter dir der Club. " \
				+ "Was du reinlässt, ist deine Verantwortung. Unten rechts liegt dein Block: " \
				+ "Seite 1 die Checkliste zum selbst Abhaken, Seite 2 dein Befund. " \
				+ "Oben links steht, wie viele Gäste heute auf der Liste stehen - danach ist Schluss."
		"spawn1":
			return "Ein Gast steht vor dir. Sieh ihn dir an: Haltung, Gesicht, Zustand. " \
				+ "Verlange als Erstes den Ausweis."
		"inspect1":
			return "Der Ausweis liegt links unten - gross und lesbar. Prüfe ihn selbst: " \
				+ "Passt das Foto zum Gast? Ist er alt genug? Ist das Dokument noch gültig? " \
				+ "Ein Klick auf ein Feld schaltet deinen Vermerk um: nicht korrekt, in Ordnung, leer. " \
				+ "Das Spiel sagt dir nicht, ob du richtig liegst - du entscheidest. Hier ist alles sauber."
		"admit1":
			return "Sauberer Ausweis, nüchterner Gast: lass ihn rein." if solo \
				else "Sauberer Ausweis: schick ihn weiter in die Schleuse. Die Security macht dort den Rest."
		"expired":
			return "Nächster Gast. Sieh dir \"GÜLTIG BIS\" genau an und vergleiche es mit dem heutigen Datum " \
				+ "oben auf der Karte. Wenn etwas nicht stimmt: Feld als NICHT KORREKT vermerken, dann abweisen. " \
				+ "Jede zutreffende Beanstandung bringt am Ende der Nacht Prämie."
		"age":
			return "Rechne beim Geburtsdatum mit. Neben dem Datum steht das errechnete Alter - " \
				+ "aber verlass dich nicht blind darauf, manche Dokumente sind manipuliert. " \
				+ "Das Mindestalter und alles Verbotene stehen links in der Hausordnung: " \
				+ "Maus auf den Pfeil am linken Rand."
		"talkUnlock":
			return "Manche Ausweise gehören jemand anderem. Sprich den Gast an - er nennt seinen Namen. " \
				+ "Stimmt der nicht mit dem Dokument überein, hast du ihn. Frag ruhig mehrmals: " \
				+ "jede Ansprache lockt eine weitere Aussage heraus, und die stehen unter dem Ausweis. " \
				+ "Alter, Gültigkeit, Taschen, Zustand - was er sagt, muss zum Rest passen. Tut es das nicht, " \
				+ "trag \"Aussage\" auf Seite 2 als \"entspricht nicht\" ein."
		"photo":
			return "Der wichtigste Handgriff: Foto auf der Karte gegen das Gesicht vor dir. " \
				+ "Haare, Hautton, Gesichtsform. Wenn es nicht passt, ist es nicht sein Ausweis."
		"marks":
			return "Echte Dokumente haben drei Hologramm-Marken. Fehlen sie oder sind sie matt, " \
				+ "ist die Karte gefälscht."
		"security":
			if solo:
				return "Ein sauberer Ausweis heisst nicht, dass alles sauber ist. Taste den Gast ab (3) und " \
					+ "wähle eine Zone: J Jacke, K Hosentaschen, L Tasche - er holt sie hervor und leert sie aus. " \
					+ "Klick auf das, was nicht reindarf, und schliess die Zone dann ab. Der Alkotest (4) " \
					+ "zeigt nur den Wert; den Grenzwert liest du am Gerät ab. Deinen Befund trägst du " \
					+ "selbst auf Seite 2 des Zettels unten rechts ein."
			return "Alles, was du durchlässt, landet in der Schleuse - innen, aber noch nicht im Club. " \
				+ "Dort tastet die Security ab (7, Zonen J/K/L) und testet auf Alkohol (8). " \
				+ "Was aus einer Zone kommt, liegt gross auf dem Tisch: anklicken, was nicht reindarf, " \
				+ "dann die Zone abschliessen. " \
				+ "Erst die Security entscheidet mit ENTER über den Einlass."
		"queue":
			return "Jede Kontrolle kostet Zeit, und die Leute draussen werden ungeduldig. " \
				+ "Wer zu lange steht, geht - das kostet Umsatz und Ruf. Mit der Taste " \
				+ ("5" if solo else "3") + " redest du mit der Schlange und verschaffst dir Luft."
		"done":
			return "Das war alles Nötige. Ab jetzt läuft die Nacht normal weiter: mehr Gäste, " \
				+ "VIPs, Zwischenfälle. Verdiene Geld, halte den Ruf hoch - und bau den Laden aus."
	return ""

static func _hint_of(game: Dictionary, id: String) -> Variant:
	var solo := GameState.is_solo(game["state"])
	match id:
		"spawn1": return ["1", "AUSWEIS VERLANGEN"]
		"admit1": return ["E", "EINLASSEN"] if solo else ["E", "DURCHLASSEN"]
		"expired": return ["X", "ABWEISEN"]
		"talkUnlock": return ["2", "ANSPRECHEN"]
		"queue": return ["5" if solo else "3", "SCHLANGE BERUHIGEN"]
	return null

# ---------- Schritt-Aufbau und Abschlussbedingung ----------

static func _setup_step(game: Dictionary, id: String) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	match id:
		"welcome":
			GameState.add_toast(night, "CHEF: ERSTE SCHICHT - HEUTE IST WENIG LOS", "info", 5.0)
		"spawn1":
			QueueSys.insert_guest(game, _scripted(game, {"id": "clean"}))
		"expired":
			QueueSys.insert_guest(game, _scripted(game, {
				"id": "expired", "personality": "annoyed",
			}))
		"age":
			QueueSys.insert_guest(game, _scripted(game, {
				"id": "underage", "personality": "nervous",
			}))
		"talkUnlock":
			QueueSys.insert_guest(game, _scripted(game, {
				"id": "name", "personality": "arrogant",
			}))
			GameState.add_toast(night, "NEU: ANSPRECHEN (2)", "good", 4.0)
		"photo":
			QueueSys.insert_guest(game, _scripted(game, {"id": "photo"}))
		"marks":
			QueueSys.insert_guest(game, _scripted(game, {"id": "marks"}))
		"security":
			QueueSys.insert_guest(game, _scripted(game, {
				"id": "contraband", "personality": "nervous", "bag": true,
			}))
			GameState.add_toast(night, "NEU: ABTASTEN · ALKOTEST", "good", 5.0)
		"queue":
			(night["tutorial"] as Dictionary)["blockSpawns"] = false
			for i in 4:
				QueueSys.insert_guest(game, Guests.create_guest(game["rng"], {
					"reputation": float(state["reputation"]), "nightIndex": 1,
				}))
			GameState.add_toast(night, "NEU: SCHLANGE BERUHIGEN", "good", 4.0)
		"done":
			state["unlocks"] = {
				"id": true, "talk": true, "search": true, "alcohol": true, "calm": true,
			}
			state["tutorialDone"] = true
			(night["tutorial"] as Dictionary)["blockSpawns"] = false
			GameState.add_toast(night, "CHEF: LÄUFT. AB JETZT BIST DU DRAN.", "good", 5.0)

static func _step_done(game: Dictionary, id: String, elapsed: float) -> bool:
	match id:
		"welcome": return elapsed > 3.5
		"spawn1":
			var checks: Variant = _door_checks(game)
			return checks != null and (checks as Dictionary)["id"] != null
		"inspect1": return elapsed > 6.0
		"admit1": return _decisions(game) >= 1
		"expired": return _decisions(game) >= 2
		"age": return _decisions(game) >= 3
		"talkUnlock": return _decisions(game) >= 4
		"photo": return _decisions(game) >= 5
		"marks": return _decisions(game) >= 6
		"security": return _decisions(game) >= 7
		"queue": return elapsed > 10.0 or _decisions(game) >= 9
		"done": return elapsed > 6.0
	return true

# ---------- Ablauf ----------

static func start_tutorial(game: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	night["tutorial"] = {
		"stepIndex": -1,
		"elapsed": 0.0,
		"blockSpawns": true,
		"baselineDecisions": 0,
		"finished": false,
		"step": null,
	}
	state["unlocks"] = {
		"id": true, "talk": false, "search": false, "alcohol": false, "calm": false,
	}
	_advance(game)

static func update_tutorial(game: Dictionary, dt: float) -> void:
	var night: Variant = (game["state"] as Dictionary)["night"]
	if night == null:
		return
	var tut: Variant = night["tutorial"]
	if tut == null or bool(tut["finished"]):
		return
	tut["elapsed"] = float(tut["elapsed"]) + dt
	var index := int(tut["stepIndex"])
	if index < 0 or index >= STEP_IDS.size():
		return
	if _step_done(game, STEP_IDS[index], float(tut["elapsed"])):
		_advance(game)

static func _advance(game: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var tut: Dictionary = night["tutorial"]
	tut["stepIndex"] = int(tut["stepIndex"]) + 1
	tut["elapsed"] = 0.0

	var index := int(tut["stepIndex"])
	if index >= STEP_IDS.size():
		tut["finished"] = true
		tut["step"] = null
		night["tutorial"] = null  # ab hier normale Nacht
		return

	var id: String = STEP_IDS[index]
	if STEP_UNLOCKS.has(id):
		for key: String in STEP_UNLOCKS[id]:
			(state["unlocks"] as Dictionary)[key] = true
	_setup_step(game, id)
	tut["step"] = {
		"id": id,
		"title": _title_of(game, id),
		"body": _body_of(game, id),
		"hint": _hint_of(game, id),
		"index": index,
		"total": STEP_IDS.size(),
	}
	(game["bus"] as Bus).emit("tutorialStep", tut["step"])

# ---------- Hilfen ----------

static func _door_checks(game: Dictionary) -> Variant:
	var night: Variant = (game["state"] as Dictionary)["night"]
	if night == null:
		return null
	return (night["stations"] as Dictionary)["door"]["checks"]

static func _decisions(game: Dictionary) -> int:
	var state: Dictionary = game["state"]
	var s: Dictionary = (state["night"] as Dictionary)["stats"]
	# Im Koop zaehlt schon das Durchlassen als getroffene Entscheidung.
	return int(s["rejected"]) + (int(s["admitted"]) if GameState.is_solo(state) else int(s["passed"]))

static func tutorial_step(game: Dictionary) -> Variant:
	var night: Variant = (game["state"] as Dictionary)["night"]
	if night == null or night["tutorial"] == null:
		return null
	return (night["tutorial"] as Dictionary)["step"]
