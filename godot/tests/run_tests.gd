## Headless-Testlauf ohne Fremdbibliothek.
##
##   godot --headless --path godot --script res://tests/run_tests.gd
##
## Bewusst kein GUT/GdUnit4: die Portierung soll ohne Addon-Installation
## pruefbar bleiben, und die Web-Fassung testet mit demselben Mittel
## (node:assert in tests/smoke.mjs).
extends SceneTree

var _checks := 0
var _failures: Array[String] = []

func _init() -> void:
	_run_all()
	print("")
	if _failures.is_empty():
		print("OK - %d Pruefungen bestanden" % _checks)
		quit(0)
	else:
		print("FEHLGESCHLAGEN - %d von %d Pruefungen:" % [_failures.size(), _checks])
		for f: String in _failures:
			print("  - " + f)
		quit(1)

func _run_all() -> void:
	_test_rng_determinism()
	_test_config_tables()
	_test_identity_dates()
	_test_guest_generation()
	_test_notes()

# ---------- Pruefhelfer ----------

func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.append("%s (erwartet %s, war %s)" % [label, str(expected), str(actual)])

# ---------- Tests ----------

func _test_rng_determinism() -> void:
	print("rng")
	var a := Rng.new(1234)
	var b := Rng.new(1234)
	for i in 50:
		check_eq(a.next(), b.next(), "gleicher Seed liefert gleiche Folge")

	var r := Rng.new(1)
	for i in 500:
		var v := r.next()
		check(v >= 0.0 and v < 1.0, "Werte liegen in [0, 1)")

	# Verschiedene Seeds duerfen nicht dieselbe Folge liefern.
	var c := Rng.new(1)
	var d := Rng.new(2)
	var same := true
	for i in 10:
		if c.next() != d.next():
			same = false
	check(not same, "verschiedene Seeds liefern verschiedene Folgen")

	# range_int haelt seine Grenzen ein.
	var e := Rng.new(99)
	for i in 300:
		var n := e.range_int(3, 7)
		check(n >= 3 and n <= 7, "range_int bleibt im Bereich")

func _test_config_tables() -> void:
	print("config")
	var items := Config.items()
	check(items.size() == Config.RAW_ITEMS.size(), "jede Rohzeile wird zu einem Gegenstand")
	for i: Dictionary in items:
		check(i.has("forbidden"), "Gegenstand kennt forbidden")
		check(i.has("severity"), "Gegenstand kennt severity")
		if i["cat"] == null:
			check(not i["forbidden"], "ohne Gruppe ist nichts verboten")
			check_eq(i["severity"], 0, "harmlos hat severity 0")
		else:
			check(i["forbidden"], "mit Gruppe ist der Gegenstand verboten")
			check(int(i["severity"]) > 0, "verboten hat severity > 0")
			check(i["catLabel"] != null, "verboten kennt seine Gruppenbezeichnung")

	# Jede Gruppe hat mindestens einen Vertreter.
	for c: Dictionary in Config.ITEM_CATEGORIES:
		check(
			not Config.items_of_category(c["id"]).is_empty(),
			"Gruppe %s hat Gegenstaende" % c["id"]
		)

	check(Config.item_by_id("blade") != null, "item_by_id findet ein bekanntes Ding")
	check(Config.item_by_id("gibtsnicht") == null, "item_by_id liefert null bei Unbekanntem")

	# Rollen: solo hat eine Station, Koop zwei.
	check_eq(Config.roles_for("solo").size(), 1, "Solo hat eine Rolle")
	check_eq(Config.roles_for("local").size(), 2, "Koop hat zwei Rollen")

func _test_identity_dates() -> void:
	print("identity")
	check_eq(Identity.today_string(), "2026-03-14", "Spieldatum")
	# Am 2026-03-14 ist jemand mit Geburtstag 2000-01-01 bereits 26.
	check_eq(Identity.age_from_birth("2000-01-01"), 26, "Geburtstag war schon")
	# Wer erst im Dezember Geburtstag hat, ist noch 25.
	check_eq(Identity.age_from_birth("2000-12-31"), 25, "Geburtstag kommt noch")
	check(
		Identity.date_before({"year": 2025, "month": 1, "day": 1}, Config.GAME_DATE),
		"Datumsvergleich"
	)
	check_eq(Identity.doc_tool_label(0), "SICHTPRÜFUNG", "Geraetename Stufe 0")
	check_eq(Identity.doc_tool_label(9), "SICHTPRÜFUNG", "Geraetename ausserhalb der Tabelle")

func _test_guest_generation() -> void:
	print("guests")
	Guests.reset_guest_serial()
	var rng := Rng.new(4242)
	var seen_underage := false
	var seen_contraband := false

	for i in 200:
		var guest := Guests.create_guest(rng, {"nightIndex": 12, "reputation": 60.0})
		var t: Dictionary = guest["truth"]

		check(not String(guest["name"]).is_empty(), "Gast hat einen Namen")
		check(t["age"] >= 15 and t["age"] <= 46, "Alter im erwarteten Bereich")
		check(float(t["drunk"]) >= 0.0 and float(t["drunk"]) <= 1.0, "drunk normiert")
		check(float(t["risk"]) >= 0.0 and float(t["risk"]) <= 1.0, "risk normiert")

		# Das Dokument muss zum behaupteten Alter passen.
		var doc: Dictionary = guest["doc"]
		check_eq(
			Identity.age_from_birth(doc["birth"]), int(doc["shownAge"]),
			"Geburtsdatum ergibt genau das gezeigte Alter"
		)

		# Ohne Tasche gibt es keine Taschen-Zone.
		if not bool(t["hasBag"]):
			check(not (t["zoneIds"] as Array).has("bag"), "keine Tasche, keine Taschen-Zone")

		# Verbotenes liegt in einer Zone, die es auch gibt.
		if t["contraband"] != null:
			seen_contraband = true
			check(
				(t["zoneIds"] as Array).has(t["contrabandZone"]),
				"verbotener Gegenstand liegt in einer vorhandenen Zone"
			)
			var zone_items: Array = (t["carried"] as Dictionary)[t["contrabandZone"]]
			check(zone_items.has(t["contraband"]), "verbotener Gegenstand liegt wirklich dort")

		# Aussagen: immer mindestens die zum Alter.
		var statements: Array = t["statements"]
		check(statements.size() >= 1, "Gast hat mindestens eine Aussage")
		check_eq(statements[0]["id"], "age", "erste Aussage ist die zum Alter")
		for s: Dictionary in statements:
			check(not String(s["text"]).is_empty(), "Aussage hat Text")
			check(s.has("lie"), "Aussage weiss, ob sie gelogen ist")

		if bool(t["underage"]):
			seen_underage = true
			check(
				not Guests.violations_of(guest).is_empty(),
				"Minderjaehrige sind immer ein Verstoss"
			)

	check(seen_underage, "in 200 Gaesten kommt mindestens ein zu junger vor")
	check(seen_contraband, "in 200 Gaesten kommt mindestens etwas Verbotenes vor")

	# Gleicher Seed, gleicher Gast.
	Guests.reset_guest_serial()
	var g1 := Guests.create_guest(Rng.new(7), {"nightIndex": 5})
	Guests.reset_guest_serial()
	var g2 := Guests.create_guest(Rng.new(7), {"nightIndex": 5})
	check_eq(g1["name"], g2["name"], "gleicher Seed erzeugt denselben Gast")
	check_eq(g1["doc"]["number"], g2["doc"]["number"], "auch dieselbe Ausweisnummer")

func _test_notes() -> void:
	print("notes")
	var notes := Notes.empty_notes()
	check_eq(notes["page"], 0, "Notizzettel startet auf der Checkliste")

	Notes.toggle_check(notes, "id")
	check(bool((notes["checked"] as Dictionary).get("id", false)), "Haken gesetzt")
	Notes.toggle_check(notes, "id")
	check(not (notes["checked"] as Dictionary).has("id"), "Haken wieder entfernt")
	check(Notes.toggle_check(notes, "gibtsnicht") == null, "unbekannter Punkt wird abgelehnt")

	# Befund: leer -> ok -> bad -> leer
	Notes.toggle_topic(notes, "document")
	check_eq((notes["topics"] as Dictionary)["document"], "ok", "erster Druck: in Ordnung")
	Notes.toggle_topic(notes, "document")
	check_eq((notes["topics"] as Dictionary)["document"], "bad", "zweiter Druck: nicht in Ordnung")
	check_eq(Notes.reported_problems(notes), ["document"] as Array[String], "Befund gemeldet")
	Notes.toggle_topic(notes, "document")
	check(not (notes["topics"] as Dictionary).has("document"), "dritter Druck: wieder leer")

	Notes.flip_page(notes)
	check_eq(notes["page"], 1, "umgeblaettert")
	Notes.flip_page(notes, 0)
	check_eq(notes["page"], 0, "gezielt zurueckgeblaettert")

	check_eq(Notes.checklist_for("outside").size(), 4, "vier Punkte draussen")
	check_eq(Notes.checklist_for("airlock").size(), 2, "zwei Punkte in der Schleuse")
	check_eq(
		Notes.checklist_for("outside", true).size(), Config.CHECKLIST.size(),
		"Solo sieht alle Punkte"
	)
