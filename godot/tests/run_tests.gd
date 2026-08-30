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
	_test_night_solo()
	_test_night_coop()
	_test_area_limits()
	_test_upgrades_and_talents()
	_test_save_roundtrip()
	_test_settings()

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

# ---------- Nachtsimulation ----------
#
# Portierung des Bot-Treibers aus tests/smoke.mjs: ein Tuersteher, der die
# Wahrheit kennt und so handelt, wie es ein perfekter Spieler mit gutem Auge
# taete. Er prueft damit den ganzen Fluss - Schlange, Stationen, Kontrollen,
# Entscheidungen, Wirtschaft, Schichtende.

func _make_game(mode: String, game_seed: int = 1234) -> Dictionary:
	var state := GameState.create_initial_state(mode)
	# Fuer die Simulation ist alles freigeschaltet (das Tutorial hat eigene Tests).
	state["unlocks"] = {"id": true, "talk": true, "search": true, "alcohol": true, "calm": true}
	return {
		"state": state,
		"rng": Rng.new(game_seed),
		"bus": Bus.new(),
		"players": Coop.create_players(mode),
	}

func _drive_station(game: Dictionary, player: Dictionary) -> void:
	var station: Variant = Coop.station_of(game, player)
	if station == null:
		return
	# Uebergriff: der Bot wehrt sich, solange er die Tastenfolge sieht.
	if station["aggro"] != null:
		var a: Dictionary = station["aggro"]
		if a["phase"] == "defend":
			var keys: Array = a["keys"]
			var idx := int(a["index"])
			if idx < keys.size():
				Coop.try_action(game, player, "defend", {"key": (keys[idx] as Dictionary)["key"]})
		return

	var guest: Variant = station["guest"]
	if guest == null or float(player["busy"]) > 0.0:
		return
	var checks: Dictionary = station["checks"]
	var solo := GameState.is_solo(game["state"])
	var outside: bool = player["area"] == "outside"
	var unlocks: Dictionary = (game["state"] as Dictionary)["unlocks"]

	# --- Bouncer-Aufgaben (draussen bzw. solo) ---
	if outside:
		if checks["id"] == null and unlocks["id"] != false:
			Coop.try_action(game, player, "id")
			return
		if checks["talk"] == null and unlocks["talk"] != false:
			Coop.try_action(game, player, "talk")
			return
		# Ausweisfelder von Hand als "nicht korrekt" vermerken (ein Klick
		# genuegt, weil der Zyklus mit "nicht korrekt" beginnt).
		for field: String in Identity.faulty_fields(guest):
			if (checks["id"] as Dictionary)["marks"].get(field, null) != "suspect":
				Coop.try_action(game, player, "mark", {"field": field})
				return

	# --- Security-Aufgaben (Schleuse bzw. solo) ---
	if not outside or solo:
		if unlocks["search"] != false:
			var pat: Variant = station["patdown"]
			if pat == null:
				Coop.try_action(game, player, "search")
				return
			if not bool(pat["complete"]):
				var open: Variant = null
				if pat["active"] != null:
					open = (pat["zones"] as Dictionary)[pat["active"]]
				if open != null:
					# Alles ansehen, das Verbotene beanstanden, dann die Zone
					# abschliessen.
					var bad: Variant = null
					for i: Dictionary in (open["items"] as Array):
						if bool(i["forbidden"]) and not (open["flagged"] as Array).has(i["id"]):
							bad = i
							break
					if bad != null:
						Coop.try_action(game, player, "pick", {
							"zone": open["id"], "itemId": bad["id"],
						})
					else:
						Coop.try_action(game, player, "closezone", {"zone": open["id"]})
					return
				for key: String in (pat["zones"] as Dictionary):
					if (pat["zones"] as Dictionary)[key]["state"] == "closed":
						Coop.try_action(game, player, "zone", {"zone": key})
						return
		if checks["alcohol"] == null and unlocks["alcohol"] != false:
			Coop.try_action(game, player, "alcohol")
			return
		# Der Befund kommt auf den eigenen Notizzettel - das Spiel traegt
		# nichts ein.
		if checks["alcohol"] != null:
			var alc: Dictionary = checks["alcohol"]
			var noted: bool = (station["notes"] as Dictionary)["topics"].get("alcohol", null) == "bad"
			if float(alc["promille"]) >= float(alc["limit"]) and not noted:
				Coop.try_action(game, player, "note", {"topic": "alcohol"})
				return

	# --- Entscheidung ---
	var suspicious := _decide(station, outside and not solo)
	if outside and not solo:
		Coop.try_action(game, player, "reject" if suspicious else "pass")
	else:
		Coop.try_action(game, player, "reject" if suspicious else "admit")

func _decide(station: Dictionary, door_only: bool) -> bool:
	var c: Dictionary = station["checks"]
	if c["id"] != null and not Identity.claimed_faults(c["id"]).is_empty():
		return true
	if door_only:
		return false
	if c["search"] != null and not ((c["search"] as Dictionary)["flagged"] as Array).is_empty():
		return true
	# Das Geraet zeigt nur den Wert - der Grenzwert steht auf dem Gehaeuse.
	if c["alcohol"] != null:
		var alc: Dictionary = c["alcohol"]
		if float(alc["promille"]) >= float(alc["limit"]):
			return true
	return false

func _run_night(game: Dictionary) -> Dictionary:
	var ended := {"value": false}
	(game["bus"] as Bus).on("nightEnd", func(_p: Variant) -> void: ended["value"] = true)
	var event := NightCycle.pick_night_event(game["rng"], game["state"])
	NightCycle.start_night(game, event, null)
	var dt := 1.0 / 60.0
	var frames := 0
	while (game["state"] as Dictionary)["phase"] == "night" and frames < 60 * 60 * 12:
		for p: Dictionary in (game["players"] as Array):
			_drive_station(game, p)
		Coop.update_players(game, dt, null)
		NightCycle.update_night(game, dt)
		frames += 1
	return {"ended": ended["value"], "night": (game["state"] as Dictionary)["night"], "frames": frames}

func _test_night_solo() -> void:
	print("nacht solo")
	var game := _make_game("solo")
	var money_before := float((game["state"] as Dictionary)["money"])
	var run := _run_night(game)
	var night: Dictionary = run["night"]
	var stats: Dictionary = night["stats"]
	var state: Dictionary = game["state"]

	check(bool(run["ended"]), "Solo: Nacht regulär beendet")
	check_eq(state["phase"], "report", "Solo: Report erreicht")
	check_eq((game["players"] as Array).size(), 1, "Solo: nur ein Spieler")
	check(
		int(stats["arrived"]) >= int(night["quota"]),
		"Solo: genug Gäste erschienen (%d/%d)" % [stats["arrived"], night["quota"]]
	)
	check_eq(night["processed"], night["quota"], "Solo: Schicht endet bei der Quote")
	check(int(stats["admitted"]) > 0, "Solo: Gäste eingelassen")
	check(int(stats["rejected"]) > 0, "Solo: Gäste abgewiesen")
	check_eq(stats["passed"], 0, "Solo: keine Schleuse, also kein Durchlassen")
	check((night["airlockQueue"] as Array).is_empty(), "Solo: Schleuse bleibt leer")
	check(float(state["money"]) > money_before, "Solo: Geld gestiegen")
	check(
		int(stats["correct"]) > int(stats["mistakes"]),
		"Solo: mehr richtig als falsch (%d/%d)" % [stats["correct"], stats["mistakes"]]
	)

func _test_night_coop() -> void:
	print("nacht koop")
	var game := _make_game("local", 4321)
	var run := _run_night(game)
	var night: Dictionary = run["night"]
	var stats: Dictionary = night["stats"]

	check(bool(run["ended"]), "Koop: Nacht regulär beendet")
	check_eq((game["players"] as Array).size(), 2, "Koop: zwei Spieler")
	check_eq(
		Coop.player_by_role(game, "bouncer")["area"], "outside", "Bouncer arbeitet draussen"
	)
	check_eq(
		Coop.player_by_role(game, "security")["area"], "airlock",
		"Security arbeitet in der Schleuse"
	)
	check(int(stats["passed"]) > 0, "Koop: Gäste in die Schleuse durchgelassen")
	check(int(stats["admitted"]) > 0, "Koop: Gäste in den Club eingelassen")
	check(
		int(stats["admitted"]) <= int(stats["passed"]),
		"Koop: es kommt nur rein, wer durchgelassen wurde"
	)
	check(
		int(stats["correct"]) > int(stats["mistakes"]),
		"Koop: mehr richtig als falsch (%d/%d)" % [stats["correct"], stats["mistakes"]]
	)

func _test_area_limits() -> void:
	print("bereichsgrenzen")
	var game := _make_game("local", 99)
	NightCycle.start_night(game, NightCycle.pick_night_event(game["rng"], game["state"]), null)
	var night: Dictionary = (game["state"] as Dictionary)["night"]
	night["running"] = true

	var bouncer := Coop.player_by_role(game, "bouncer")
	var security := Coop.player_by_role(game, "security")

	# Der Bouncer darf nicht abtasten, die Security nicht am Ausweis arbeiten.
	check(Coop.try_action(game, bouncer, "search") != null, "Bouncer darf nicht abtasten")
	check(Coop.try_action(game, security, "id") != null, "Security darf keinen Ausweis verlangen")
	check(Coop.try_action(game, bouncer, "admit") != null, "Bouncer lässt nicht in den Club")
	check(not Coop.can_do(game, bouncer, "alcohol"), "Alkotest gehört in die Schleuse")
	check(Coop.can_do(game, bouncer, "reject"), "Abweisen dürfen beide")
	check(Coop.can_do(game, security, "reject"), "Abweisen dürfen beide (Security)")

func _test_upgrades_and_talents() -> void:
	print("ausbau und talente")
	var state := GameState.create_initial_state("solo")
	state["money"] = 100000.0

	check_eq(GameState.club_tier(state)["level"], 1, "Start auf Club-Stufe 1")
	var before := GameState.capacity(state)
	var res := Upgrades.buy_upgrade(state, "floor")
	check(bool(res["ok"]), "Tanzfläche gekauft")
	check_eq(state["upgrades"]["floor"], 1, "Stufe erhöht")
	check(GameState.capacity(state) > before, "Kapazität gestiegen")

	# Bis zum Maximum kaufen, dann muss es abgelehnt werden.
	Upgrades.buy_upgrade(state, "floor")
	Upgrades.buy_upgrade(state, "floor")
	check_eq(state["upgrades"]["floor"], 3, "Maximalstufe erreicht")
	check(not bool(Upgrades.buy_upgrade(state, "floor")["ok"]), "über Maximum wird abgelehnt")
	check(Upgrades.next_cost(state, "floor") == null, "kein Preis mehr über Maximum")

	# Ohne Geld geht nichts.
	var broke := GameState.create_initial_state("solo")
	broke["money"] = 0.0
	check(not bool(Upgrades.buy_upgrade(broke, "bar")["ok"]), "ohne Geld kein Ausbau")

	# Talente
	var t := GameState.create_initial_state("solo")
	check_eq(t["talentPoints"], 1, "ein Talentpunkt zum Start")
	check(bool(Progression.buy_talent(t, "scanner")["ok"]), "Talent gekauft")
	check_eq(t["talents"]["scanner"], 1, "Talentstufe erhöht")
	check(not bool(Progression.buy_talent(t, "scanner")["ok"]), "keine Punkte mehr")
	check(not bool(Progression.buy_talent(t, "gibtsnicht")["ok"]), "unbekanntes Talent")

	# Routine macht die Kontrollen schneller.
	var fast := GameState.create_initial_state("solo")
	var normal_speed := GameState.action_speed(fast)
	(fast["talents"] as Dictionary)["scanner"] = 3
	check(GameState.action_speed(fast) < normal_speed, "Routine beschleunigt Kontrollen")

func _test_save_roundtrip() -> void:
	print("spielstand")
	var path := "user://test_save.json"
	SaveGame.clear_save(path)
	check(not SaveGame.has_save(path), "vorher kein Spielstand")

	var state := GameState.create_initial_state("solo")
	state["money"] = 4711.0
	state["reputation"] = 77.0
	state["xp"] = 950
	(state["upgrades"] as Dictionary)["bar"] = 2
	(state["talents"] as Dictionary)["charisma"] = 3
	(state["character"] as Dictionary)["name"] = "TESTER"
	check(SaveGame.save_game(state, path), "gespeichert")
	check(SaveGame.has_save(path), "Spielstand liegt vor")

	var fresh := GameState.create_initial_state("solo")
	check(SaveGame.load_game(fresh, path), "geladen")
	check_eq(fresh["money"], 4711.0, "Geld übernommen")
	check_eq(fresh["reputation"], 77.0, "Ruf übernommen")
	check_eq(fresh["xp"], 950, "XP übernommen")
	check_eq(fresh["upgrades"]["bar"], 2, "Ausbau übernommen")
	check_eq(fresh["talents"]["charisma"], 3, "Talent übernommen")
	check_eq(fresh["character"]["name"], "TESTER", "Charakter übernommen")
	# Die laufende Nacht gehört NICHT in den Spielstand.
	check(fresh["night"] == null, "keine laufende Nacht im Spielstand")

	SaveGame.clear_save(path)
	check(not SaveGame.has_save(path), "gelöscht")

func _test_settings() -> void:
	print("einstellungen")
	var path := "user://test_settings.json"
	if FileAccess.file_exists(path):
		DirAccess.open("user://").remove(path.get_file())
	Settings.use_path(path)

	# Ohne Datei gelten die Vorgaben.
	check_eq(Settings.get_string("resolution"), "1280x720", "Vorgabe Auflösung")
	check(Settings.get_bool("effects"), "Bildeffekte sind an")
	check(Settings.get_bool("tutorial"), "Tutorial ist an")

	# Jede Aenderung meldet sich und liegt danach auf der Platte.
	var seen: Array[String] = []
	var off := Settings.on_changed(func(key: String) -> void: seen.append(key))
	Settings.set_value("resolution", "1920x1080")
	Settings.set_value("master", 0.4)
	Settings.set_value("muted", true)
	off.call()
	check_eq(seen, ["resolution", "master", "muted"] as Array[String], "Änderungen gemeldet")
	check(FileAccess.file_exists(path), "Einstellungen gespeichert")

	# Neu laden: dieselben Werte, und Unbekanntes aus einer fremden Datei
	# wird nicht uebernommen.
	Settings.use_path(path)
	check_eq(Settings.get_string("resolution"), "1920x1080", "Auflösung geladen")
	check_eq(Settings.get_float("master"), 0.4, "Lautstärke geladen")
	check(Settings.get_bool("muted"), "Stumm geladen")
	check_eq(
		int(Settings.resolution_entry()["size"].x), 1920, "Auflösung kennt ihre Fenstergröße"
	)
	check_eq(String(Settings.display_entry("fullscreen")["id"]), "fullscreen", "Anzeigemodus gefunden")
	# Unbekannte Schluessel werden weder gelesen noch gesetzt.
	Settings.set_value("gibtsnicht", 1)
	check(not Settings.values().has("gibtsnicht"), "unbekannter Schlüssel bleibt draussen")

	Settings.reset()
	check_eq(Settings.get_string("resolution"), "1280x720", "zurückgesetzt")

	DirAccess.open("user://").remove(path.get_file())
	# Fuer alles Weitere wieder der normale Ablageort.
	Settings.use_path(Settings.DEFAULT_PATH)
