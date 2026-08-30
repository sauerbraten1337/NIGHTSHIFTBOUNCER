## Uebergriffe an der Tuer.
##
## Selten - aber es passiert: ein Gast laesst sich das Abweisen nicht gefallen,
## kommt auf den Tuersteher zu und man hat wenige Sekunden Zeit. Auf dem
## Bildschirm erscheinen nacheinander Tasten; wer sie schnell genug trifft,
## wehrt den Gast ab. Wer zu langsam ist oder danebengreift, kassiert.
##
## Bewusst ohne Gewaltdarstellung: es geht um Reaktion und Abstand halten,
## nicht um Schlagabtausch. Das Modul zeichnet nichts - Anzeige macht der
## Renderer, Eingaben kommen ueber defend() (lokal wie ueber das Netz).
##
## Portierung von src/systems/aggression.js.
class_name Aggression
extends RefCounted

## Laeuft an dieser Station gerade ein Angriff?
static func aggression_active(station: Variant) -> bool:
	if station == null:
		return false
	var a: Variant = station["aggro"]
	return a != null and a["phase"] != "over"

## Kann in dieser Nacht ueberhaupt jemand ausrasten?
static func aggression_possible(state: Dictionary) -> bool:
	if not bool(Config.FEATURES["aggression"]):
		return false
	# Admin-Testhilfe: niemand rastet mehr von selbst aus.
	if Admin.unlocked and Admin.no_aggro:
		return false
	var night: Variant = state["night"]
	if night == null or night["tutorial"] != null:
		return false
	return int(state["nightIndex"]) >= int(Config.AGGRESSION["minNight"]) \
		and bool(Difficulty.difficulty_profile(int(state["nightIndex"]))["aggression"])

## Wie explosiv ist dieser Gast? 0..1 - fliesst in beide Ausloeser ein.
## Betrunken, unter Einfluss, gereizt und riskant: das summiert sich.
static func aggression_risk(guest: Variant) -> float:
	if guest == null:
		return 0.0
	var t: Dictionary = guest["truth"]
	var risk := float(t["risk"]) * 0.5
	match guest["personality"]:
		"aggressive": risk += 0.45
		"annoyed": risk += 0.15
		"arrogant": risk += 0.1
	if float(t["drunk"]) > 0.6:
		risk += 0.25
	if float(t.get("impaired", 0.0)) > 0.5:
		risk += 0.2
	if bool(t["underage"]):
		risk += 0.05
	risk *= 1.0 - clampf(float(guest.get("mood", 0.6)), 0.0, 1.0) * 0.3
	return clampf(risk, 0.0, 1.0)

## Startet einen Angriff, falls der Zufall es will.
## `cause`: 'reject' (Abweisung) oder 'idle' (rastet waehrend der Kontrolle aus).
## Gibt true zurueck, wenn der Angriff laeuft - der Aufrufer muss dann warten.
static func maybe_aggression(game: Dictionary, station: Variant, cause: String) -> bool:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	if station == null:
		return false
	var guest: Variant = station["guest"]
	if guest == null or aggression_active(station):
		return false
	if not aggression_possible(state):
		return false
	if bool(guest.get("tutorial", false)) or bool(guest.get("isArtist", false)):
		return false

	var risk := aggression_risk(guest)
	var p := float(Config.AGGRESSION["rejectChance"]) * (0.4 + risk * 1.8) if cause == "reject" \
		else float(Config.AGGRESSION["idleChancePerSecond"]) * risk
	if not rng.chance(clampf(p, 0.0, 0.6)):
		return false

	start_aggression(game, station, cause)
	return true

## Baut den Angriff auf: Anlauf, dann die Tastenfolge.
static func start_aggression(game: Dictionary, station: Variant, cause: String = "reject") -> Variant:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	if station == null:
		return null
	var guest: Variant = station["guest"]
	var night: Variant = state["night"]
	if guest == null or night == null:
		return null

	var count := rng.range_int(
		int(Config.AGGRESSION["keys"][0]), int(Config.AGGRESSION["keys"][1])
	)
	var keys: Array[Dictionary] = []
	for i in count:
		# Nie zweimal dieselbe Taste hintereinander - das liest sich sonst falsch.
		var last_key: String = keys[keys.size() - 1]["key"] if not keys.is_empty() else ""
		var pool: Array[Dictionary] = []
		for k: Dictionary in Config.DEFENSE_KEYS:
			if k["key"] != last_key:
				pool.append(k)
		keys.append(rng.pick(pool))

	station["aggro"] = {
		"guestId": guest["id"],
		"cause": cause,
		"phase": "charge",  # charge | defend | win | fail | over
		"approach": 0.0,
		"timer": float(Config.AGGRESSION["chargeTime"]),
		"keys": keys,
		"index": 0,
		"keyTime": float(Config.AGGRESSION["keyTime"]),
		"keyLeft": float(Config.AGGRESSION["keyTime"]),
		"strikes": 0,
		"maxStrikes": int(Config.AGGRESSION["strikes"]),
		"hitFlash": 0.0,
		"missFlash": 0.0,
		"shake": 0.0,
		"stun": false,
	}

	# Der Gast ist damit objektiv nicht mehr tragbar - das Abweisen ist richtig.
	(guest["truth"] as Dictionary)["aggressive"] = true
	guest["said"] = "WAS SOLL DAS?!" if cause == "reject" else "FASS MICH NICHT AN!"
	guest["saidTimer"] = 2.2

	var stats: Dictionary = night["stats"]
	stats["attacks"] = int(stats.get("attacks", 0)) + 1
	GameState.add_toast(
		night,
		"ER RASTET AUS - ABWEHREN!" if cause == "reject" else "ANGRIFF - ABWEHREN!",
		"bad", 3.0
	)
	(game["bus"] as Bus).emit("sfx", "alarm")
	(game["bus"] as Bus).emit("aggression", {"station": station["id"], "cause": cause})
	return station["aggro"]

## Eine Taste wurde gedrueckt. `key` ist ein InputMap-Aktionsname.
## Gibt zurueck, was passiert ist - fuer Ton und Anzeige.
static func defend(game: Dictionary, station: Variant, key: String) -> Variant:
	if station == null:
		return null
	var a: Variant = station["aggro"]
	if a == null or a["phase"] != "defend":
		return null

	var keys: Array = a["keys"]
	var index := int(a["index"])
	if index >= keys.size():
		return null
	var expected: Dictionary = keys[index]

	if key == expected["key"]:
		a["index"] = index + 1
		a["hitFlash"] = 0.25
		a["shake"] = minf(1.0, float(a["shake"]) + 0.35)
		(game["bus"] as Bus).emit("sfx", "ok")
		if int(a["index"]) >= keys.size():
			_finish(game, station, true)
			return {"hit": true, "done": true}
		a["keyTime"] = maxf(
			float(Config.AGGRESSION["keyTimeMin"]),
			float(a["keyTime"]) - float(Config.AGGRESSION["keyTimeStep"])
		)
		a["keyLeft"] = a["keyTime"]
		return {"hit": true, "done": false}

	return _strike(game, station, "wrong")

## Fehlgriff oder abgelaufenes Zeitfenster.
static func _strike(game: Dictionary, station: Dictionary, reason: String) -> Dictionary:
	var a: Dictionary = station["aggro"]
	a["strikes"] = int(a["strikes"]) + 1
	a["missFlash"] = 0.35
	(game["bus"] as Bus).emit("sfx", "beep")
	if int(a["strikes"]) > int(a["maxStrikes"]):
		_finish(game, station, false)
		return {"hit": false, "done": true, "reason": reason}
	# Neues Fenster, gleiche Taste - man bekommt noch eine Chance.
	a["keyLeft"] = a["keyTime"]
	return {"hit": false, "done": false, "reason": reason}

## Jede Nacht-Aktualisierung: Anlauf, Zeitfenster, Aufloesung.
static func update_aggression(game: Dictionary, dt: float) -> void:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]
	if night == null or not bool(night["running"]):
		return
	var stations: Dictionary = night["stations"]
	for key: String in stations:
		_update_station(game, stations[key], dt)
	if not aggression_possible(state):
		return
	# Wer lange an der Kontrolle steht und schlecht drauf ist, kann von selbst
	# ausrasten - unabhaengig von jeder Entscheidung.
	for station: Dictionary in _stations_with_guest(game, night):
		if aggression_active(station):
			continue
		station["aggroCooldown"] = float(station.get("aggroCooldown", 1.5)) - dt
		if float(station["aggroCooldown"]) > 0.0:
			continue
		station["aggroCooldown"] = 1.0
		# Einer pro Nacht ist gesetzt: ist die ausgewuerfelte Stelle erreicht
		# und bis dahin nichts passiert, geht dieser hier los.
		var guest: Dictionary = station["guest"]
		if forced_due(night) and not bool(guest.get("tutorial", false)) \
				and not bool(guest.get("isArtist", false)):
			start_aggression(game, station, "idle")
		else:
			maybe_aggression(game, station, "idle")

## Steht der garantierte Uebergriff dieser Nacht an?
## Er entfaellt, sobald ohnehin schon jemand ausgerastet ist.
static func forced_due(night: Variant) -> bool:
	if night == null or int((night["stats"] as Dictionary).get("attacks", 0)) > 0:
		return false
	var at: Variant = night.get("forcedAttackAt", null)
	if at == null:
		return false
	return int(night["processed"]) >= int(at)

static func _stations_with_guest(game: Dictionary, night: Dictionary) -> Array[Dictionary]:
	var stations: Dictionary = night["stations"]
	var list: Array[Dictionary] = [stations["door"]]
	if not GameState.is_solo(game["state"]):
		list.append(stations["airlock"])
	var out: Array[Dictionary] = []
	for s: Dictionary in list:
		if s["guest"] != null:
			out.append(s)
	return out

static func _update_station(game: Dictionary, station: Dictionary, dt: float) -> void:
	var a: Variant = station["aggro"]
	if a == null or a["phase"] == "over":
		return

	if float(a["hitFlash"]) > 0.0:
		a["hitFlash"] = float(a["hitFlash"]) - dt
	if float(a["missFlash"]) > 0.0:
		a["missFlash"] = float(a["missFlash"]) - dt
	a["shake"] = maxf(0.0, float(a["shake"]) - dt * 1.6)

	if a["phase"] == "charge":
		a["timer"] = float(a["timer"]) - dt
		a["approach"] = clampf(
			1.0 - float(a["timer"]) / float(Config.AGGRESSION["chargeTime"]), 0.0, 1.0
		)
		if float(a["timer"]) <= 0.0:
			a["phase"] = "defend"
			a["approach"] = 1.0
			a["keyLeft"] = a["keyTime"]
		return

	if a["phase"] == "defend":
		a["keyLeft"] = float(a["keyLeft"]) - dt
		if float(a["keyLeft"]) <= 0.0:
			_strike(game, station, "timeout")
		return

	# win | fail: kurz stehen lassen, dann aufloesen.
	a["timer"] = float(a["timer"]) - dt
	if float(a["timer"]) <= 0.0:
		_resolve(game, station)

static func _finish(game: Dictionary, station: Dictionary, won: bool) -> void:
	var a: Dictionary = station["aggro"]
	var guest: Variant = station["guest"]
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var stats: Dictionary = night["stats"]

	a["phase"] = "win" if won else "fail"
	a["timer"] = float(Config.AGGRESSION["resultTime"])
	a["approach"] = 0.35 if won else 1.0

	if won:
		stats["defended"] = int(stats.get("defended", 0)) + 1
		stats["defensePay"] = float(stats.get("defensePay", 0.0)) \
			+ float(Config.AGGRESSION["winBonus"])
		Reputation.change_reputation(state, float(Config.AGGRESSION["winRep"]), "Angriff abgewehrt")
		Economy.earn(state, float(Config.AGGRESSION["winBonus"]), "finding")
		state["xp"] = int(state["xp"]) + int(Config.AGGRESSION["winXp"])
		GameState.add_toast(
			night, "ABGEWEHRT +%d EUR" % int(Config.AGGRESSION["winBonus"]), "good", 3.5
		)
		(game["bus"] as Bus).emit("sfx", "ok")
		if guest != null:
			guest["said"] = "SCHON GUT, SCHON GUT!"
			guest["saidTimer"] = 2.4
	else:
		stats["attacksLanded"] = int(stats.get("attacksLanded", 0)) + 1
		stats["incidents"] = int(stats["incidents"]) + 1
		var lifetime: Dictionary = state["lifetime"]
		lifetime["incidents"] = int(lifetime["incidents"]) + 1
		var cost := Economy.fine(
			state, float(Config.AGGRESSION["failCost"]), "Übergriff an der Tür"
		)
		Reputation.change_reputation(state, float(Config.AGGRESSION["failRep"]), "Übergriff")
		GameState.add_toast(
			night, "ÜBERGRIFF - SCHADEN %d EUR" % int(cost["value"]), "bad", 4.5
		)
		GameState.push_log(state, "Übergriff an der Tür", "bad")
		(game["bus"] as Bus).emit("sfx", "alarm")
		# Benommen ist man erst, wenn der Gast weg ist (siehe _resolve).
		a["stun"] = true
	(game["bus"] as Bus).emit("aggressionEnd", {"station": station["id"], "won": won})

static func _station_belongs_to(game: Dictionary, station: Dictionary, player: Dictionary) -> bool:
	if GameState.is_solo(game["state"]):
		return true
	return station["id"] == ("airlock" if player["area"] == "airlock" else "door")

## Der Gast fliegt raus - egal wie es ausgegangen ist.
static func _resolve(game: Dictionary, station: Dictionary) -> void:
	var guest: Variant = station["guest"]
	var stun := false
	if station["aggro"] != null:
		stun = bool((station["aggro"] as Dictionary).get("stun", false))
	station["aggro"] = null
	station["aggroCooldown"] = 2.0

	if stun:
		# Nach einem Treffer steht man erst mal neben sich.
		for player: Dictionary in (game.get("players", []) as Array):
			if not _station_belongs_to(game, station, player):
				continue
			player["busy"] = float(Config.AGGRESSION["failStun"])
			player["busyTotal"] = float(Config.AGGRESSION["failStun"])
			player["busyLabel"] = "BENOMMEN"
			player["pending"] = null
			player["flash"] = 0.6

	if guest == null:
		return
	Decision.reject_guest(game, guest, station)
