## Queue System: Warteschlange draussen und Schleuse innen.
##
## Koop-Fluss:   Schlange -> Tuer (Bouncer) -> Schleuse (Security) -> Club
## Solo-Fluss:   Schlange -> Tuer (alles in einer Hand)            -> Club
##
## Portierung von src/systems/queue.js. `game` ist wie in der Web-Fassung ein
## Dictionary mit state, rng und bus.
class_name QueueSys
extends RefCounted

## Wie viele Gaeste pro Spielminute eintreffen.
##
## Die Kurve haengt am Schichtfortschritt, nicht mehr an der Uhr: erst
## ruhig, dann voll, gegen Ende der Liste wieder ruhiger.
static func arrival_rate(state: Dictionary) -> float:
	var night: Dictionary = state["night"]
	var p := clampf(float(night["processed"]) / float(maxi(1, int(night["quota"]))), 0.0, 1.0)
	var curve: float
	if p < 0.1:
		curve = 0.45 + p / 0.1 * 0.45
	elif p < 0.6:
		curve = 0.9 + (p - 0.1) / 0.5 * 0.5
	elif p < 0.85:
		curve = 1.4 - (p - 0.6) / 0.25 * 0.35
	else:
		curve = clampf(1.05 - (p - 0.85) / 0.15 * 0.6, 0.4, 1.05)

	var rush := 2.4 if _has_effect(night, "rush") else 0.0
	var viral := 0.6 if _has_effect(night, "influencerPost") else 0.0
	var tutorial := 0.3 if night["tutorial"] != null else 1.0
	# Solo muss allein durch alle Kontrollen - entsprechend weniger Andrang.
	var mode_scale := 0.55 if GameState.is_solo(state) else 1.0
	var spawn := 1.0
	if night["event"] != null:
		spawn = float((night["event"] as Dictionary).get("spawn", 1.0))
	return ((curve * spawn * Reputation.crowd_pull(state) * 0.55) + rush + viral) \
		* tutorial * mode_scale

static func _has_effect(night: Dictionary, id: String) -> bool:
	for e: Dictionary in (night["activeEffects"] as Array):
		if e["id"] == id:
			return true
	return false

## Wie viele Gaeste des Schichtplans stecken gerade im System?
## Abgearbeitete zaehlen mit, weggelaufene nicht - fuer die kommt Ersatz.
static func guests_in_shift(night: Dictionary) -> int:
	var stations: Dictionary = night["stations"]
	return int(night["processed"]) \
		+ (night["queue"] as Array).size() \
		+ (night["airlockQueue"] as Array).size() \
		+ (1 if stations["door"]["guest"] != null else 0) \
		+ (1 if stations["airlock"]["guest"] != null else 0)

## Wie viele Gaeste stehen noch auf der Liste?
static func guests_left(night: Variant) -> int:
	if night == null:
		return 0
	return maxi(0, int(night.get("quota", 0)) - int(night.get("processed", 0)))

static func update_queue(game: Dictionary, dt: float, minutes: float) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var cap := GameState.queue_capacity(state)

	var block_spawns := false
	if night["tutorial"] != null:
		block_spawns = bool((night["tutorial"] as Dictionary).get("blockSpawns", false))

	if not block_spawns:
		night["spawnCooldown"] = float(night["spawnCooldown"]) - minutes * arrival_rate(state) * 0.45
		while float(night["spawnCooldown"]) <= 0.0:
			night["spawnCooldown"] = float(night["spawnCooldown"]) + 1.0
			# Nur so viele Leute schicken, wie fuer den Schichtplan noch fehlen.
			if guests_in_shift(night) >= int(night["quota"]):
				break
			if (night["queue"] as Array).size() < cap:
				_spawn_guest(game)
			else:
				var stats: Dictionary = night["stats"]
				stats["left"] = int(stats["left"]) + 1
				stats["arrived"] = int(stats["arrived"]) + 1

	_update_patience(game, dt)
	_advance_stations(game)
	_update_leaving(night, dt)
	_move_guests(night, dt)

static func _update_patience(game: Dictionary, dt: float) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var queue: Array = night["queue"]

	for i in range(queue.size() - 1, -1, -1):
		var g: Dictionary = queue[i]
		if float(g["saidTimer"]) > 0.0:
			g["saidTimer"] = float(g["saidTimer"]) - dt
		else:
			g["said"] = null

		# Ungeduld ist abgeschaltet: niemand verlaesst die Schlange, es geht
		# ausschliesslich um die Kontrolle an der Tuer.
		if not bool(Config.FEATURES["queueImpatience"]):
			continue

		var drain := 1.0 + (0.4 if float(g["mood"]) < 0.4 else 0.0) + (0.25 if i > 6 else 0.0)
		g["patience"] = float(g["patience"]) - dt * drain
		if float(g["patience"]) <= 0.0:
			queue.remove_at(i)
			var stats: Dictionary = night["stats"]
			stats["left"] = int(stats["left"]) + 1
			g["state"] = "left"
			g["exitTimer"] = 1.2
			(night["leaving"] as Array).append(g)
			var is_vip := bool((g["truth"] as Dictionary)["vip"])
			Reputation.change_reputation(state, -1.4 if is_vip else -0.35, "Gast ist gegangen")
			if is_vip:
				GameState.add_toast(night, "VIP HAT DIE SCHLANGE VERLASSEN", "bad")

	# Gaeste in der Schleuse und an den Stationen: Sprechblasen ausblenden.
	var others: Array = (night["airlockQueue"] as Array).duplicate()
	others.append((night["stations"] as Dictionary)["door"]["guest"])
	others.append((night["stations"] as Dictionary)["airlock"]["guest"])
	for g: Variant in others:
		if g == null:
			continue
		if float(g["saidTimer"]) > 0.0:
			g["saidTimer"] = float(g["saidTimer"]) - dt
		else:
			g["said"] = null

## Rueckt Gaeste an die freien Stationen nach.
static func _advance_stations(game: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]
	var door: Dictionary = (night["stations"] as Dictionary)["door"]
	var airlock: Dictionary = (night["stations"] as Dictionary)["airlock"]

	if door["guest"] == null and not (night["queue"] as Array).is_empty():
		var next: Dictionary = (night["queue"] as Array).pop_front()
		next["state"] = "door"
		next["said"] = Guests.guest_line(rng, next, "greet")
		next["saidTimer"] = 3.4
		door["guest"] = next
		door["checks"] = GameState.empty_checks()
		door["patdown"] = null
		door["notes"] = Notes.empty_notes()
		bus.emit("stationGuest", {"station": "door", "guest": next})

	if not GameState.is_solo(state) and airlock["guest"] == null \
			and not (night["airlockQueue"] as Array).is_empty():
		var next_a: Dictionary = (night["airlockQueue"] as Array).pop_front()
		next_a["state"] = "airlock"
		next_a["said"] = Guests.guest_line(rng, next_a, "search")
		next_a["saidTimer"] = 3.2
		airlock["guest"] = next_a
		airlock["checks"] = GameState.empty_checks()
		airlock["patdown"] = null
		airlock["notes"] = Notes.empty_notes()
		bus.emit("stationGuest", {"station": "airlock", "guest": next_a})

static func _update_leaving(night: Dictionary, dt: float) -> void:
	var leaving: Array = night["leaving"]
	for i in range(leaving.size() - 1, -1, -1):
		var g: Dictionary = leaving[i]
		g["exitTimer"] = float(g["exitTimer"]) - dt
		if float(g["exitTimer"]) <= 0.0:
			leaving.remove_at(i)

static func _move_guests(night: Dictionary, dt: float) -> void:
	for g: Dictionary in (night["queue"] as Array):
		g["walkPhase"] = float(g["walkPhase"]) + dt * (8.0 if g.get("moving", false) else 1.2)
		g["swayPhase"] = float(g["swayPhase"]) + dt * (1.5 + float((g["truth"] as Dictionary)["drunk"]) * 3.5)
	for g: Dictionary in (night["airlockQueue"] as Array):
		g["walkPhase"] = float(g["walkPhase"]) + dt * 1.2
		g["swayPhase"] = float(g["swayPhase"]) + dt * (1.5 + float((g["truth"] as Dictionary)["drunk"]) * 3.5)
	var stations: Dictionary = night["stations"]
	for key: String in ["door", "airlock"]:
		var guest: Variant = stations[key]["guest"]
		if guest != null:
			guest["walkPhase"] = float(guest["walkPhase"]) + dt * 1.4
			guest["swayPhase"] = float(guest["swayPhase"]) \
				+ dt * (1.5 + float((guest["truth"] as Dictionary)["drunk"]) * 4.0)

static func _spawn_guest(game: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var night: Dictionary = state["night"]
	var guest := Guests.create_guest(rng, {
		"event": night["event"],
		"reputation": float(state["reputation"]),
		"patienceMul": GameState.patience_multiplier(state),
		"nightIndex": int(state["nightIndex"]),
	})
	(night["queue"] as Array).append(guest)
	var stats: Dictionary = night["stats"]
	stats["arrived"] = int(stats["arrived"]) + 1
	var lifetime: Dictionary = state["lifetime"]
	lifetime["guests"] = int(lifetime["guests"]) + 1
	return guest

## Fuegt einen vorbereiteten Gast (Special-Event, Tutorial) ein.
static func insert_guest(game: Dictionary, guest: Dictionary, at_front: bool = false) -> Dictionary:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	if at_front:
		(night["queue"] as Array).push_front(guest)
	else:
		(night["queue"] as Array).append(guest)
	var stats: Dictionary = night["stats"]
	stats["arrived"] = int(stats["arrived"]) + 1
	var lifetime: Dictionary = state["lifetime"]
	lifetime["guests"] = int(lifetime["guests"]) + 1
	return guest

## Gast wandert von der Tuer in die Schleuse.
static func move_to_airlock(game: Dictionary, guest: Dictionary) -> int:
	var night: Dictionary = (game["state"] as Dictionary)["night"]
	guest["state"] = "airlockQueue"
	guest["passedAt"] = night["clock"]
	(night["airlockQueue"] as Array).append(guest)
	return (night["airlockQueue"] as Array).size()

static func airlock_full(state: Dictionary) -> bool:
	var night: Dictionary = state["night"]
	var occupied := (night["airlockQueue"] as Array).size() \
		+ (1 if (night["stations"] as Dictionary)["airlock"]["guest"] != null else 0)
	return occupied >= GameState.airlock_capacity(state)

## CALM: beruhigt die Warteschlange.
static func calm_queue(state: Dictionary) -> int:
	var night: Dictionary = state["night"]
	var power := 8.0 + int((state["talents"] as Dictionary)["charisma"]) * 4.0 \
		+ GameState.upgrade_level(state, "team") * 3.0
	var affected := 0
	var queue: Array = night["queue"]
	for i in mini(8, queue.size()):
		var g: Dictionary = queue[i]
		g["patience"] = minf(float(g["patienceMax"]), float(g["patience"]) + power)
		g["mood"] = clampf(float(g["mood"]) + 0.15, 0.0, 1.0)
		affected += 1
	return affected

## Durchschnittliche Stimmung der Schlange (0-1) fuer HUD und Rendering.
static func queue_mood(night: Dictionary) -> float:
	var queue: Array = night["queue"]
	if queue.is_empty():
		return 1.0
	var sum := 0.0
	for g: Dictionary in queue:
		sum += float(g["patience"]) / float(g["patienceMax"])
	return sum / queue.size()
