## Koop-System: wer darf was, wo.
##
## Jeder Spieler steht an seiner eigenen Station:
##   BOUNCER  - draussen an der Tuer (Ausweis, Gespraech, Schlange)
##   SECURITY - drinnen in der Schleuse (Scan, Abtasten, Alkoholtest)
## Im Solo-Modus gibt es nur die Tuer, und der Bouncer macht alles.
##
## Alle Aktionen laufen ueber try_action(), damit lokale Eingaben und
## Netzwerk-Kommandos denselben Weg nehmen.
##
## Portierung von src/systems/coop.js.
class_name Coop
extends RefCounted

static func create_players(mode: String = "solo") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index := 0
	for role: Dictionary in Config.roles_for(mode):
		out.append({
			"index": index,
			"id": role["id"],
			"role": role,
			"area": role["area"],
			"busy": 0.0,
			"busyTotal": 0.0,
			"busyLabel": "",
			"pending": null,
			"flash": 0.0,
			"idlePhase": index * 1.7,
			"lastResult": null,
			"lastResultTime": 0.0,
			"remote": false,
		})
		index += 1
	return out

## Die Station, an der dieser Spieler arbeitet.
static func station_of(game: Dictionary, player: Dictionary) -> Variant:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]
	if night == null:
		return null
	var stations: Dictionary = night["stations"]
	if GameState.is_solo(state):
		return stations["door"]
	return stations["airlock"] if player["area"] == "airlock" else stations["door"]

static func player_by_role(game: Dictionary, role_id: String) -> Dictionary:
	var players: Array = game["players"]
	for p: Dictionary in players:
		if p["id"] == role_id:
			return p
	return players[0]

static func update_players(game: Dictionary, dt: float, input: Variant) -> void:
	var state: Dictionary = game["state"]
	if state["night"] == null:
		return

	for player: Dictionary in (game["players"] as Array):
		player["idlePhase"] = float(player["idlePhase"]) + dt
		if float(player["flash"]) > 0.0:
			player["flash"] = float(player["flash"]) - dt

		# Angriff: alles andere ruht, es zaehlt nur noch die richtige Taste.
		var attacked: Variant = station_of(game, player)
		if Aggression.aggression_active(attacked):
			# Der Angriff unterbricht die laufende Kontrolle - man hat die
			# Haende voll.
			if float(player["busy"]) > 0.0:
				player["busy"] = 0.0
				player["busyLabel"] = ""
				player["pending"] = null
			if input != null and not bool(player["remote"]):
				for entry: Dictionary in Config.DEFENSE_KEYS:
					if (input as GameInput).just_pressed(entry["key"]):
						try_action(game, player, "defend", {"key": entry["key"]})
			continue

		if float(player["busy"]) > 0.0:
			player["busy"] = float(player["busy"]) - dt
			if float(player["busy"]) <= 0.0:
				player["busy"] = 0.0
				var pending: Variant = player["pending"]
				player["pending"] = null
				player["busyLabel"] = ""
				if pending != null:
					_complete_action(game, player, pending)
			continue

		if input == null or bool(player["remote"]):
			continue

		for action: Dictionary in ((player["role"] as Dictionary)["actions"] as Array):
			if (input as GameInput).just_pressed(action["key"]):
				try_action(game, player, action["code"])

		# Abtast-Zonen: nur Zonen, die dieser Gast ueberhaupt hat.
		var station: Variant = station_of(game, player)
		var pat: Variant = station["patdown"] if station != null else null
		if pat != null and not bool(pat["complete"]) and can_do(game, player, "search"):
			for zone_key: Dictionary in Config.PATDOWN_KEYS:
				if not (pat["zones"] as Dictionary).has(zone_key["zone"]):
					continue
				if (input as GameInput).just_pressed(zone_key["key"]):
					try_action(game, player, "zone", {
						"zone": zone_key["zone"], "label": zone_key["label"],
					})
			# Solo: Ziffern greifen direkt in die offene Zone (kein Konflikt,
			# weil gerade nichts anderes ansteht). Im Koop laeuft die Auswahl
			# per Maus.
			var open: Variant = null
			if pat["active"] != null:
				open = (pat["zones"] as Dictionary)[pat["active"]]
			if open != null and GameState.is_solo(state):
				if (input as GameInput).just_pressed("act_close_zone"):
					try_action(game, player, "pick", {"zone": open["id"], "itemId": null})
				var items: Array = open["items"] if open["items"] != null else []
				for i in mini(9, items.size()):
					if (input as GameInput).just_pressed("act_%d" % (i + 1)):
						try_action(game, player, "pick", {
							"zone": open["id"], "itemId": (items[i] as Dictionary)["id"],
						})

## Darf dieser Spieler diese Kontrolle ueberhaupt ausfuehren?
static func can_do(game: Dictionary, player: Dictionary, code: String) -> bool:
	if GameState.is_solo(game["state"]):
		return true
	var area: String = player["area"]
	if code == "id" or code == "talk" or code == "calm" or code == "pass":
		return area == "outside"
	if (Config.AREA_CHECKS["airlock"] as Array).has(code) or code == "admit":
		return area == "airlock"
	return true  # reject duerfen beide

static func _duration(state: Dictionary, key: String) -> float:
	var times: Dictionary = Config.TUNING["actionTime"]
	return float(times.get(key, 1.0)) * GameState.action_speed(state)

static func _begin(
	game: Dictionary, player: Dictionary, label: String, key: String, payload: Dictionary = {}
) -> void:
	var t := _duration(game["state"], key)
	player["busy"] = t
	player["busyTotal"] = t
	player["busyLabel"] = label
	var pending := payload.duplicate()
	pending["key"] = key
	player["pending"] = pending

static func _deny(game: Dictionary, player: Dictionary, reason: String) -> String:
	player["flash"] = 0.5
	_set_result(player, "deny", reason)
	GameState.add_toast((game["state"] as Dictionary)["night"], reason, "warn", 2.2)
	(game["bus"] as Bus).emit("sfx", "beep")
	return reason

static func _set_result(player: Dictionary, kind: String, text: String) -> void:
	player["lastResult"] = {"kind": kind, "text": text}
	player["lastResultTime"] = 0.0

## Fuehrt eine Aktion aus (oder lehnt sie mit Begruendung ab).
## payload: { zone } fuer 'zone', { field } fuer 'mark'.
static func try_action(
	game: Dictionary, player: Dictionary, code: String, payload: Dictionary = {}
) -> Variant:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]
	if night == null or not bool(night["running"]):
		return "KEINE SCHICHT"

	var station: Variant = station_of(game, player)
	var guest: Variant = station["guest"] if station != null else null

	# Solange jemand auf einen losgeht, geht nichts anderes.
	if Aggression.aggression_active(station):
		if code != "defend":
			return _deny(game, player, "ERST ABWEHREN")
		var res: Variant = Aggression.defend(game, station, payload.get("key", ""))
		if res != null:
			var hit := bool(res["hit"])
			player["flash"] = 0.2 if hit else 0.45
			_set_result(player, "ok" if hit else "deny", "GETROFFEN" if hit else "DANEBEN")
		return null
	if code == "defend":
		return null
	if float(player["busy"]) > 0.0:
		return "BESCHÄFTIGT"

	if code == "calm":
		if not can_do(game, player, "calm"):
			return _deny(game, player, "NUR DER BOUNCER KANN DIE SCHLANGE BERUHIGEN")
		if not bool((state["unlocks"] as Dictionary)["calm"]):
			return _deny(game, player, "NOCH NICHT FREIGESCHALTET")
		_begin(game, player, "SCHLANGE BERUHIGEN", "calm")
		return null

	if not can_do(game, player, code):
		return _deny(game, player, "NUR DIE SECURITY LÄSST IN DEN CLUB" if code == "admit" \
			else "NICHT DEIN BEREICH")
	if guest == null:
		return _deny(game, player, "NIEMAND VOR DIR")
	var unlocks: Dictionary = state["unlocks"]
	if unlocks.has(code) and unlocks[code] == false:
		return _deny(game, player, "NOCH NICHT FREIGESCHALTET")

	var checks: Dictionary = station["checks"]

	match code:
		"id":
			if checks["id"] != null:
				return _deny(game, player, "AUSWEIS LIEGT SCHON VOR")
			guest["said"] = Guests.guest_line(game["rng"], guest, "idAsk")
			guest["saidTimer"] = 3.2
			_begin(game, player, "AUSWEIS VERLANGEN", "id", {"guestId": guest["id"]})
			(game["bus"] as Bus).emit("sfx", "beep")
			return null

		# Der Spieler schaltet den Status eines Ausweisfeldes um. Das Spiel sagt
		# ihm NICHT, ob er richtig liegt - er traegt seine eigene Einschaetzung
		# ein.
		"mark":
			if checks["id"] == null:
				return _deny(game, player, "ERST DEN AUSWEIS VERLANGEN")
			if (checks["id"] as Dictionary)["guestId"] != guest["id"]:
				return _deny(game, player, "ANDERER GAST")
			var mark_res: Variant = Identity.toggle_field(checks["id"], payload.get("field", ""))
			if mark_res == null:
				return null
			var mark_state: Variant = mark_res["state"]
			var mark_text: String
			if mark_state == "suspect":
				mark_text = "%s: als nicht korrekt notiert" % mark_res["label"]
			elif mark_state == "fine":
				mark_text = "%s: als in Ordnung notiert" % mark_res["label"]
			else:
				mark_text = "%s: Eintrag gelöscht" % mark_res["label"]
			_set_result(player, "info", mark_text)
			(game["bus"] as Bus).emit("sfx", "beep")
			(game["bus"] as Bus).emit("idMark", {
				"field": payload.get("field", ""), "state": mark_state,
			})
			return null

		# Notizzettel Seite 1: Haken setzen/entfernen.
		"check":
			var check_res: Variant = Notes.toggle_check(station["notes"], payload.get("item", ""))
			if check_res == null:
				return null
			(game["bus"] as Bus).emit("sfx", "beep")
			(game["bus"] as Bus).emit("noteCheck", check_res)
			return null

		# Notizzettel Seite 2: Befund umschalten (entspricht der Norm / nicht).
		"note":
			var note_res: Variant = Notes.toggle_topic(station["notes"], payload.get("topic", ""))
			if note_res == null:
				return null
			var note_state: Variant = note_res["state"]
			var label := Notes.topic_label(note_res["id"])
			var note_text: String
			if note_state == "bad":
				note_text = "%s: entspricht nicht" % label
			elif note_state == "ok":
				note_text = "%s: entspricht der Norm" % label
			else:
				note_text = "%s: Eintrag gelöscht" % label
			_set_result(player, "info", note_text)
			(game["bus"] as Bus).emit("sfx", "beep")
			(game["bus"] as Bus).emit("noteTopic", note_res)
			return null

		"page":
			Notes.flip_page(station["notes"], payload.get("page", null))
			return null

		"talk":
			_begin(game, player, "ANSPRECHEN", "talk", {"guestId": guest["id"]})
			return null

		"alcohol":
			if checks["alcohol"] != null:
				return _deny(game, player, "TEST BEREITS GEMACHT")
			_begin(game, player, "ALKOHOLTEST", "alcohol", {"guestId": guest["id"]})
			(game["bus"] as Bus).emit("sfx", "beep")
			return null

		"search":
			if station["patdown"] != null and bool((station["patdown"] as Dictionary)["complete"]):
				return _deny(game, player, "KONTROLLE ABGESCHLOSSEN")
			if station["patdown"] == null:
				station["patdown"] = Security.start_patdown(state, guest)
				guest["said"] = Guests.guest_line(game["rng"], guest, "search")
				guest["saidTimer"] = 3.0
				(game["bus"] as Bus).emit("sfx", "radio")
				var letters := {"jacket": "J", "pockets": "K", "bag": "L"}
				var keys: PackedStringArray = []
				for z: String in ((station["patdown"] as Dictionary)["zones"] as Dictionary):
					keys.append(letters[z])
				GameState.add_toast(night, "ZONE WÄHLEN: %s" % " / ".join(keys), "info", 3.5)
			return null

		"zone":
			var zpat: Variant = station["patdown"]
			if zpat == null or bool(zpat["complete"]):
				return null
			var zone: Variant = (zpat["zones"] as Dictionary).get(payload.get("zone", ""), null)
			if zone == null or zone["state"] == "done":
				return null
			if zpat["active"] != null and zpat["active"] != payload.get("zone", ""):
				return _deny(game, player, "ERST DEN AKTUELLEN INHALT KLÄREN")
			if zone["state"] == "open":
				return null
			var is_bag: bool = payload.get("zone", "") == "bag"
			var zone_label := "TASCHE HERVORHOLEN" if is_bag else "ABTASTEN: %s" % zone["label"]
			_begin(game, player, zone_label, "bag" if is_bag else "search", {
				"zone": payload.get("zone", ""), "guestId": guest["id"],
			})
			(game["bus"] as Bus).emit("sfx", "radio")
			return null

		# Gegenstand beanstanden oder Beanstandung zuruecknehmen. Ob der
		# Gegenstand wirklich verboten ist, erfaehrt der Spieler hier nicht.
		"pick":
			var ppat: Variant = station["patdown"]
			if ppat == null:
				return null
			var pzone_id: Variant = payload.get("zone", null)
			if pzone_id == null:
				pzone_id = ppat["active"]
			var pzone: Variant = (ppat["zones"] as Dictionary).get(pzone_id, null)
			if pzone == null or pzone["state"] != "open":
				return null
			if payload.get("itemId", null) == null:
				return try_action(game, player, "closezone", {"zone": pzone["id"]})

			var pick_res: Variant = Security.pick_item(
				ppat, guest, pzone["id"], payload["itemId"]
			)
			if pick_res == null:
				return null
			var item_label: String = (pick_res["item"] as Dictionary)["label"]
			_set_result(player, "info", "%s: beanstandet" % item_label \
				if bool(pick_res["flagged"]) else "%s: Beanstandung zurückgenommen" % item_label)
			checks["search"] = Security.patdown_result(ppat)
			(game["bus"] as Bus).emit("sfx", "beep")
			(game["bus"] as Bus).emit("itemPicked", pick_res)
			return null

		# Zone abschliessen - mit oder ohne Beanstandung.
		"closezone":
			var cpat: Variant = station["patdown"]
			if cpat == null:
				return null
			var czone_id: Variant = payload.get("zone", null)
			if czone_id == null:
				czone_id = cpat["active"]
			var czone: Variant = (cpat["zones"] as Dictionary).get(czone_id, null)
			if czone == null or czone["state"] != "open":
				return null
			var close_res: Variant = Security.close_zone(cpat, czone["id"])
			if close_res == null:
				return null
			var flagged_count: int = (close_res["flaggedIds"] as Array).size()
			_set_result(player, "info", "%s: %d beanstandet" % [czone["label"], flagged_count] \
				if flagged_count > 0 else "%s: abgeschlossen" % czone["label"])
			checks["search"] = Security.patdown_result(cpat)
			if bool(cpat["complete"]):
				_update_verification(game, guest, station)
			(game["bus"] as Bus).emit("sfx", "ok")
			(game["bus"] as Bus).emit("zoneClosed", close_res)
			return null

		"pass":
			if GameState.is_solo(state):
				return _deny(game, player, "IM SOLO GIBT ES KEINE SCHLEUSE")
			if QueueSys.airlock_full(state):
				return _deny(game, player, "SCHLEUSE IST VOLL")
			_begin(game, player, "DURCHLASSEN", "admit", {"guestId": guest["id"], "pass": true})
			return null

		"admit":
			_begin(game, player, "EINLASSEN", "admit", {"guestId": guest["id"]})
			return null

		"reject":
			_begin(game, player, "ABWEISEN", "reject", {"guestId": guest["id"]})
			return null

	return _deny(game, player, "UNBEKANNTE AKTION")

static func _complete_action(game: Dictionary, player: Dictionary, pending: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var station: Variant = station_of(game, player)

	if pending["key"] == "calm":
		var n := QueueSys.calm_queue(state)
		_set_result(player, "ok", "%d GÄSTE BERUHIGT" % n)
		GameState.add_toast(night, "SCHLANGE BERUHIGT (%d)" % n, "good", 2.5)
		bus.emit("sfx", "radio")
		return

	var guest: Variant = station["guest"] if station != null else null
	if guest == null or guest["id"] != pending.get("guestId", null):
		_set_result(player, "deny", "GAST NICHT MEHR DA")
		return
	var checks: Dictionary = station["checks"]

	match pending["key"]:
		"id":
			checks["id"] = Identity.request_id(state, guest)
			_set_result(player, "info", "AUSWEIS LIEGT VOR - SELBST PRÜFEN")
			bus.emit("sfx", "beep")

		"talk":
			# Jede weitere Ansprache lockt die naechste Aussage heraus.
			var talk_res := Alcohol.talk_to(rng, state, guest, checks["talk"])
			checks["talk"] = talk_res
			guest["said"] = talk_res["line"]
			guest["saidTimer"] = 3.6
			var said: Array = talk_res["said"]
			if not said.is_empty():
				var last: Dictionary = said[said.size() - 1]
				_set_result(player, "info", "SAGT: \"%s\"%s" % [
					last["text"], " (redet noch)" if bool(talk_res["moreToSay"]) else "",
				])
			else:
				_set_result(player, "info", "SAGT: \"%s\" - %s" % [
					talk_res["realName"], talk_res["hint"],
				])

		"alcohol":
			var alc := Alcohol.alcohol_test(state, guest)
			checks["alcohol"] = alc
			_set_result(player, "info", "MESSUNG LÄUFT — %s" % alc["text"])
			bus.emit("sfx", "scan")
			_update_verification(game, guest, station)

		"bag", "search":
			if station["patdown"] == null:
				return
			var zone: Variant = Security.open_zone(
				station["patdown"], guest, pending.get("zone", "")
			)
			if zone == null:
				return
			checks["search"] = Security.patdown_result(station["patdown"])
			_set_result(player, "info", "%s: %d GEGENSTÄNDE" % [
				zone["label"], (zone["items"] as Array).size(),
			])
			var pat: Dictionary = station["patdown"]
			if not bool(pat.get("hintShown", false)):
				pat["hintShown"] = true
				GameState.add_toast(
					night, "WAS DAVON DARF NICHT REIN? SELBST ENTSCHEIDEN.", "info", 3.0
				)
			bus.emit("sfx", "beep")
			bus.emit("zoneOpened", {"zone": zone["id"], "items": zone["items"]})

		"admit":
			if bool(pending.get("pass", false)):
				Decision.pass_guest(game, guest, station)
				_set_result(player, "ok", "DURCHGELASSEN")
				guest["said"] = Guests.guest_line(rng, guest, "admit")
				guest["saidTimer"] = 2.0
			else:
				var is_artist := bool(guest.get("isArtist", false))
				Decision.admit_guest(game, guest, station)
				if is_artist:
					Artists.resolve_artist_decision(game, guest, true)
				_set_result(player, "ok", "EINGELASSEN")
			bus.emit("decision", {
				"outcome": "pass" if bool(pending.get("pass", false)) else "admit",
				"guest": guest,
			})

		"reject":
			# Manche nehmen ein "Nein" nicht hin - dann geht es erst richtig los.
			if Aggression.maybe_aggression(game, station, "reject"):
				_set_result(player, "deny", "ER RASTET AUS")
				return
			var reject_artist := bool(guest.get("isArtist", false))
			Decision.reject_guest(game, guest, station)
			if reject_artist:
				Artists.resolve_artist_decision(game, guest, false)
			_set_result(player, "bad", "ABGEWIESEN")
			bus.emit("decision", {"outcome": "reject", "guest": guest})

## SECURITY VERIFIED / CHECK AGAIN auswerten.
static func _update_verification(game: Dictionary, guest: Dictionary, station: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var checks: Dictionary = station["checks"]
	var verify := Decision.solo_verification(checks) if GameState.is_solo(state) \
		else Decision.coop_verification(guest, checks)

	if verify["state"] == "verified" and not bool(checks["verified"]):
		checks["verified"] = true
		GameState.add_toast(night, "SECURITY VERIFIED", "good", 3.0)
		(game["bus"] as Bus).emit("sfx", "ok")
	elif verify["state"] == "conflict" and not bool(checks["conflict"]):
		checks["conflict"] = true
		GameState.add_toast(night, "CHECK AGAIN — BEFUNDE WIDERSPRECHEN SICH", "warn", 4.0)
		(game["bus"] as Bus).emit("sfx", "alarm")
