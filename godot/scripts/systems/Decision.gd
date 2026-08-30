## Entscheidungssystem: DURCHLASSEN / EINLASSEN / ABWEISEN.
##
## Koop: Der Bouncer draussen entscheidet nur, wer ueberhaupt in die Schleuse
## darf. Die Security innen entscheidet, wer in den Club kommt. Dadurch gibt es
## eine zweite Verteidigungslinie - und echte Team-Momente ("guter Fang").
##
## Portierung von src/systems/decision.js.
class_name Decision
extends RefCounted

## Koop-Verifikation: das Urteil der Tuer (Ausweispruefung) gegen den Befund
## der Schleuse (Abtasten und Alkoholtest). Zwei Augenpaare, ein Ergebnis.
static func coop_verification(guest: Dictionary, airlock_checks: Variant) -> Dictionary:
	var door_verdict: Variant = guest.get("doorVerdict", null)
	if door_verdict == null or not bool(door_verdict["checked"]):
		return {"state": "none"}
	# Die Schleuse hat erst dann ein belastbares Urteil, wenn sie fertig ist.
	if airlock_checks == null:
		return {"state": "none"}
	var search: Variant = (airlock_checks as Dictionary).get("search", null)
	var alcohol: Variant = (airlock_checks as Dictionary).get("alcohol", null)
	var searched: bool = search != null and bool((search as Dictionary).get("done", false))
	var tested := alcohol != null
	if not searched or not tested:
		return {"state": "none"}

	var flagged: Array = (search as Dictionary).get("flagged", [])
	var security_clean: bool = flagged.is_empty() \
		and float((alcohol as Dictionary)["promille"]) < float((alcohol as Dictionary)["limit"])
	if bool(door_verdict["clean"]) == security_clean:
		return {"state": "verified", "clean": security_clean}
	return {
		"state": "conflict",
		"doorClean": door_verdict["clean"],
		"securityClean": security_clean,
	}

## Solo: Es gibt kein zweites Augenpaar. Wer aber wirklich alles prueft -
## Ausweis, alle Zonen, Alkoholtest - arbeitet nachweislich gruendlich.
static func solo_verification(checks: Dictionary) -> Dictionary:
	var search: Variant = checks.get("search", null)
	var searched: bool = search != null and bool((search as Dictionary).get("done", false))
	if checks["id"] == null or not searched or checks["alcohol"] == null:
		return {"state": "none"}
	return {"state": "verified", "clean": Identity.inspection_verdict(checks["id"])["clean"]}

# ------------------------------------------------------------------

## Was hat der Spieler selbst gefunden?
##
## Erst hier - nach der Entscheidung - vergleicht das Spiel die Angaben des
## Spielers mit der Wahrheit. Waehrend der Kontrolle bekommt er dazu nichts
## zu sehen. Jede zutreffende Beanstandung bringt am Ende der Nacht Geld.
static func collect_findings(guest: Dictionary, station: Dictionary) -> Dictionary:
	var checks: Dictionary = station["checks"]
	var notes: Variant = station.get("notes", null)
	if notes == null:
		notes = Notes.empty_notes()
	var hits: Array[Dictionary] = []
	var wrong: Array[Dictionary] = []
	var missed: Array[Dictionary] = []

	# Ausweis: die vom Spieler als "nicht korrekt" markierten Felder.
	if checks["id"] != null:
		var s := Identity.score_inspection(checks["id"], guest)
		for f: String in (s["hits"] as Array):
			hits.append({"kind": "id", "label": f})
		for f: String in (s["wrong"] as Array):
			wrong.append({"kind": "id", "label": f})
		for f: String in (s["missed"] as Array):
			missed.append({"kind": "id", "label": f})

	# Abtasten: die vom Spieler beanstandeten Gegenstaende.
	if station["patdown"] != null:
		var sp := Security.score_patdown(station["patdown"], guest)
		for f: Dictionary in (sp["hits"] as Array):
			hits.append({"kind": "item", "label": (f["item"] as Dictionary)["label"]})
		for f: Dictionary in (sp["wrong"] as Array):
			wrong.append({"kind": "item", "label": (f["item"] as Dictionary)["label"]})
		for f: Dictionary in (sp["missed"] as Array):
			missed.append({"kind": "item", "label": (f["item"] as Dictionary)["label"]})

	# Notizzettel: der Spieler hat den Alkoholwert selbst als zu hoch notiert.
	var problems := Notes.reported_problems(notes)
	if checks["alcohol"] != null:
		var alc: Dictionary = checks["alcohol"]
		var over: bool = float(alc["promille"]) >= float(alc["limit"])
		var noted := problems.has("alcohol")
		if noted and over:
			hits.append({"kind": "alcohol", "label": "Alkoholwert"})
		elif noted and not over:
			wrong.append({"kind": "alcohol", "label": "Alkoholwert"})
		elif not noted and over:
			missed.append({"kind": "alcohol", "label": "Alkoholwert"})

	# Aussage: nur was der Gast wirklich gesagt hat, zaehlt. Wer nie
	# angesprochen hat, kann hier weder treffen noch etwas uebersehen.
	var said: Array = []
	if checks["talk"] != null:
		said = (checks["talk"] as Dictionary).get("said", [])
	var lies := Statements.revealed_lies(said)
	if problems.has("statement"):
		if not lies.is_empty():
			hits.append({"kind": "statement", "label": "Falsche Aussage"})
		else:
			wrong.append({"kind": "statement", "label": "Aussage"})
	elif not lies.is_empty():
		missed.append({"kind": "statement", "label": "Falsche Aussage"})

	# Zustand der Person: nur als Angabe wertbar, wenn der Gast wirklich
	# beeintraechtigt ist.
	if problems.has("person"):
		var t: Dictionary = guest["truth"]
		if float(t.get("impaired", 0.0)) > 0.5 or float(t["drunk"]) > 0.6:
			hits.append({"kind": "person", "label": "Zustand der Person"})
		else:
			wrong.append({"kind": "person", "label": "Zustand der Person"})

	return {"hits": hits, "wrong": wrong, "missed": missed}

## Findings verbuchen und die Praemie gutschreiben.
static func _book_findings(game: Dictionary, guest: Dictionary, station: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var score := collect_findings(guest, station)
	var stats: Dictionary = night["stats"]

	var hit_count: int = (score["hits"] as Array).size()
	stats["findings"] = int(stats["findings"]) + hit_count
	stats["falseAlarms"] = int(stats["falseAlarms"]) + (score["wrong"] as Array).size()
	stats["overlooked"] = int(stats["overlooked"]) + (score["missed"] as Array).size()

	var pay := hit_count * int(Config.TUNING["findingBonus"])
	if pay > 0:
		stats["findingPay"] = float(stats["findingPay"]) + pay
		Economy.earn(state, pay, "finding")
		GameState.add_toast(night, "%d UNREGELMÄSSIGKEIT%s +%d EUR" % [
			hit_count, "EN" if hit_count > 1 else "", pay
		], "good")
	return score

## Bouncer schickt den Gast weiter in die Schleuse (nur Koop).
static func pass_guest(game: Dictionary, guest: Dictionary, station: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var verdict := Identity.inspection_verdict((station["checks"] as Dictionary)["id"])

	guest["doorVerdict"] = {
		"clean": verdict["clean"] if bool(verdict["checked"]) else null,
		"checked": verdict["checked"],
		"claimed": verdict.get("claimed", []),
		"talked": (station["checks"] as Dictionary)["talk"] != null,
	}

	# Die Tuer bucht ihre eigenen Befunde sofort ab.
	guest["doorScore"] = _book_findings(game, guest, station)

	var stats: Dictionary = night["stats"]
	stats["passed"] = int(stats["passed"]) + 1
	QueueSys.move_to_airlock(game, guest)
	_clear_station(station)
	guest["said"] = null

	var text: String
	if bool(verdict["checked"]):
		text = "TÜR: AUSWEIS GEPRÜFT, KOMMT DURCH" if bool(verdict["clean"]) \
			else "TÜR: AUFFÄLLIG - GENAU ANSEHEN"
	else:
		text = "TÜR: UNGEPRÜFT DURCHGELASSEN"
	var kind := "warn" if verdict["clean"] == false else "info"
	GameState.add_toast(night, text, kind, 3.0)

	bus.emit("sfx", "door")
	if rng.next() < 0.001:
		GameState.push_log(state, "Tür läuft", "info")
	return {"verdict": verdict}

## Gast endgueltig in den Club lassen.
static func admit_guest(game: Dictionary, guest: Dictionary, station: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var violations := Guests.violations_of(guest)
	var verify := solo_verification(station["checks"]) if GameState.is_solo(state) \
		else coop_verification(guest, station["checks"])

	_book_findings(game, guest, station)

	var stats: Dictionary = night["stats"]
	stats["admitted"] = int(stats["admitted"]) + 1
	var lifetime: Dictionary = state["lifetime"]
	lifetime["admitted"] = int(lifetime["admitted"]) + 1
	if bool((guest["truth"] as Dictionary)["vip"]):
		stats["vips"] = int(stats["vips"]) + 1

	var entry := Economy.admit_revenue(state, guest)
	if verify["state"] == "verified":
		stats["verified"] = int(stats["verified"]) + 1
		entry = int(round(entry * 1.15))
	Economy.earn(state, entry, "entry")

	var spend_total := Economy.planned_bar_spend(state, guest)
	(night["inside"] as Array).append({
		"id": guest["id"], "guest": guest,
		"spendTotal": spend_total, "spendLeft": spend_total,
		"phase": rng.next() * 6.28,
	})

	if violations.is_empty():
		stats["correct"] = int(stats["correct"]) + 1
		var rep := 0.4 + float((guest["truth"] as Dictionary)["repValue"]) * 0.35
		if verify["state"] == "verified":
			rep += 0.25
		Reputation.change_reputation(state, rep, "korrekter Einlass")
		state["xp"] = int(state["xp"]) + 12
		bus.emit("sfx", "ok")
		GameState.add_toast(night, "EINLASS +%d EUR" % entry, "good")
	else:
		stats["mistakes"] = int(stats["mistakes"]) + 1
		state["xp"] = int(state["xp"]) + 3
		var worst: Dictionary = violations[0]
		for v: Dictionary in violations:
			if int(v["severity"]) > int(worst["severity"]):
				worst = v
		_resolve_bad_admission(game, guest, worst)

	_finish_guest(game, guest, station, "admitted")
	bus.emit("sfx", "door")
	return {"entry": entry, "violations": violations, "verify": verify}

static func _resolve_bad_admission(game: Dictionary, guest: Dictionary, worst: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var stats: Dictionary = night["stats"]
	var lifetime: Dictionary = state["lifetime"]
	var inspection := 1.0
	if night["event"] != null and bool((night["event"] as Dictionary).get("inspection", false)):
		inspection = 2.0

	if worst["id"] == "underage":
		if rng.chance(0.55 * inspection):
			var f := Economy.fine(
				state, float(Config.TUNING["fineUnderage"]) * inspection,
				"Minderjährige eingelassen"
			)
			Reputation.change_reputation(state, -6.0 * inspection, "Kontrolle")
			stats["incidents"] = int(stats["incidents"]) + 1
			lifetime["incidents"] = int(lifetime["incidents"]) + 1
			GameState.add_toast(
				night, "BUSSGELD -%d EUR: MINDERJÄHRIG" % int(f["value"]), "bad", 5.0
			)
			bus.emit("sfx", "alarm")
		else:
			Reputation.change_reputation(state, -1.5, "Risiko")
			GameState.add_toast(night, "ZU JUNG DURCHGEWUNKEN", "warn")
		return

	var severity := int(worst["severity"])
	var p := Security.incident_chance(state, guest) + (0.2 if severity >= 2 else 0.0)
	if rng.chance(minf(0.95, p)):
		var cost := int(Economy.incident_cost(state, float(maxi(1, severity))) * inspection)
		Economy.fine(state, cost, worst["label"])
		Reputation.change_reputation(state, -2.2 * severity * inspection * 0.6, "Zwischenfall")
		stats["incidents"] = int(stats["incidents"]) + 1
		lifetime["incidents"] = int(lifetime["incidents"]) + 1
		GameState.add_toast(night, "ZWISCHENFALL: %s (-%d EUR)" % [
			String(worst["label"]).to_upper(), cost
		], "bad", 5.0)
		GameState.push_log(state, "Zwischenfall: %s" % worst["label"], "bad")
		bus.emit("sfx", "alarm")
	else:
		Reputation.change_reputation(state, -0.8, "Risiko")
		GameState.add_toast(night, "RISIKO REINGELASSEN: %s" % worst["label"], "warn")

## Gast abweisen - an der Tuer oder in der Schleuse.
static func reject_guest(game: Dictionary, guest: Dictionary, station: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var violations := Guests.violations_of(guest)
	var at_airlock: bool = station["id"] == "airlock"

	_book_findings(game, guest, station)

	var stats: Dictionary = night["stats"]
	stats["rejected"] = int(stats["rejected"]) + 1
	var lifetime: Dictionary = state["lifetime"]
	lifetime["rejected"] = int(lifetime["rejected"]) + 1

	if not violations.is_empty():
		stats["correct"] = int(stats["correct"]) + 1
		var rep := 0.5 + violations.size() * 0.2

		# Die Security hat gefangen, was draussen durchgerutscht ist.
		var door_verdict: Variant = guest.get("doorVerdict", null)
		if at_airlock and door_verdict != null and door_verdict["clean"] == true:
			stats["catches"] = int(stats["catches"]) + 1
			rep += 0.4
			GameState.add_toast(night, "GUTER FANG - SECURITY HAT IHN GESTOPPT", "good", 4.0)
		elif GameState.is_solo(state) or not at_airlock:
			var verify := solo_verification(station["checks"]) if GameState.is_solo(state) \
				else {"state": "none"}
			if verify["state"] == "verified":
				rep += 0.25
				stats["verified"] = int(stats["verified"]) + 1

		Reputation.change_reputation(state, rep, "korrekt abgewiesen")
		state["xp"] = int(state["xp"]) + 15
		bus.emit("sfx", "deny")
		GameState.add_toast(
			night, "RICHTIG ABGEWIESEN: %s" % (violations[0] as Dictionary)["label"], "good"
		)
		if bool(guest["inspector"]):
			Reputation.change_reputation(state, 2.0, "Testkontrolle bestanden")
			GameState.add_toast(night, "TESTPERSON ERKANNT", "good", 3.0)
	else:
		stats["mistakes"] = int(stats["mistakes"]) + 1
		var lost := int(round(
			Economy.planned_bar_spend(state, guest) + Economy.admit_revenue(state, guest)
		))
		var rep_hit := -1.1
		if bool((guest["truth"] as Dictionary)["vip"]):
			rep_hit = -3.2
		elif guest["archetype"] == "influencer":
			rep_hit = -2.6
		Reputation.change_reputation(state, rep_hit, "zu Unrecht abgewiesen")
		state["xp"] = int(state["xp"]) + 2
		bus.emit("sfx", "deny")
		GameState.add_toast(night, "FALSCH ABGEWIESEN (-%d EUR Potenzial)" % lost, "bad")
		if bool((guest["truth"] as Dictionary)["vip"]):
			GameState.add_toast(night, "DAS WAR EIN VIP", "bad", 4.0)
		if bool(guest["inspector"]):
			Reputation.change_reputation(state, 1.0, "Testkontrolle")

	_finish_guest(game, guest, station, "rejected")
	return {"violations": violations}

static func _finish_guest(
	game: Dictionary, guest: Dictionary, station: Dictionary, outcome: String
) -> void:
	var night: Dictionary = (game["state"] as Dictionary)["night"]
	guest["state"] = outcome
	guest["exitTimer"] = 1.6
	(night["leaving"] as Array).append(guest)
	# Der Gast ist abgearbeitet - er zaehlt gegen den Schichtplan.
	night["processed"] = int(night["processed"]) + 1
	_clear_station(station)

static func _clear_station(station: Dictionary) -> void:
	station["guest"] = null
	station["patdown"] = null
	station["notes"] = Notes.empty_notes()
	station["checks"] = GameState.empty_checks()
