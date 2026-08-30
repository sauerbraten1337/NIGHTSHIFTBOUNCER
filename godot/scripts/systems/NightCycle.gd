## Night Cycle: Uhr, Phasen, Start und Abschluss einer Nacht.
##
## Portierung von src/systems/nightcycle.js.
class_name NightCycle
extends RefCounted

## Phasen der Nacht - am Schichtfortschritt festgemacht ("at" ist der Anteil
## der abgearbeiteten Liste), nicht mehr an der Uhr.
const PHASES := [
	{"at": 0.0, "label": "OPENING", "intensity": 0.25},
	{"at": 0.1, "label": "ERSTE GÄSTE", "intensity": 0.4},
	{"at": 0.2, "label": "WARM UP", "intensity": 0.5},
	{"at": 0.35, "label": "FULL FLOOR", "intensity": 0.65},
	{"at": 0.5, "label": "PRIME TIME", "intensity": 0.8},
	{"at": 0.6, "label": "PEAK HOUR", "intensity": 1.0},
	{"at": 0.8, "label": "AFTER PEAK", "intensity": 0.7},
	{"at": 0.92, "label": "CLOSING", "intensity": 0.4},
]

## Anteil der abgearbeiteten Schicht (0..1).
static func shift_progress(night: Variant) -> float:
	if night == null or int(night.get("quota", 0)) == 0:
		return 0.0
	return minf(1.0, float(night["processed"]) / float(night["quota"]))

static func pick_night_event(rng: Rng, state: Dictionary) -> Dictionary:
	if not bool(Config.FEATURES["nightEvents"]):
		return Config.NIGHT_EVENTS[0]
	var night_number := int(state["nightIndex"]) + 1
	if night_number == 1:
		return Config.NIGHT_EVENTS[0]
	var pool: Array[Dictionary] = []
	for e: Dictionary in Config.NIGHT_EVENTS:
		if night_number >= int(e.get("minNight", 1)):
			pool.append(e)
	return rng.weighted_pick_fn(
		pool, func(e: Variant) -> float: return 5.0 if e["id"] == "normal" else 3.0
	)

static func start_night(
	game: Dictionary, event: Dictionary, artist: Variant, opts: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	Guests.reset_guest_serial()
	state["nightIndex"] = int(state["nightIndex"]) + 1
	state["night"] = GameState.create_night_state(
		event, artist, rng.seed, state["mode"], GameState.guest_quota(state)
	)
	var night: Dictionary = state["night"]
	night["repDelta"] = 0.0
	state["phase"] = "night"
	if artist != null:
		(night["stats"] as Dictionary)["artistFee"] = float((artist as Dictionary)["fee"])
		state["money"] = float(state["money"]) - float((artist as Dictionary)["fee"])
	# Ein Uebergriff pro Nacht ist gesetzt - offen ist nur, bei welchem Gast.
	night["forcedAttackAt"] = rng.range_int(1, maxi(1, int(night["quota"]) - 2))
	if bool(opts.get("tutorial", false)):
		Tutorial.start_tutorial(game)
	GameState.push_log(state, "NIGHT %s - %s" % [
		str(state["nightIndex"]).pad_zeros(2), event["label"]
	], "info")
	GameState.add_toast(night, "OFFEN - %d LEUTE AUF DER LISTE" % int(night["quota"]), "info", 4.0)
	(game["bus"] as Bus).emit("nightStart", night)
	return night

static func current_phase(progress: float) -> Dictionary:
	var phase: Dictionary = PHASES[0]
	for p: Dictionary in PHASES:
		if progress >= float(p["at"]):
			phase = p
	return phase

static func clock_string(clock: float) -> String:
	var total := int(floor(clock))
	@warning_ignore("integer_division")
	var h := (total / 60) % 24
	var m := total % 60
	return "%s:%s" % [str(h).pad_zeros(2), str(m).pad_zeros(2)]

static func update_night(game: Dictionary, dt: float) -> void:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]
	if night == null or not bool(night["running"]):
		return

	var minutes := dt * float(Config.TUNING["minutesPerSecond"])
	night["clock"] = float(night["clock"]) + minutes

	Tutorial.update_tutorial(game, dt)
	QueueSys.update_queue(game, dt, minutes)
	Aggression.update_aggression(game, dt)
	if night["tutorial"] == null and bool(Config.FEATURES["randomEvents"]):
		RandomEvents.update_random_events(game, dt, minutes)
	Economy.tick_inside_revenue(state, minutes)
	_update_inside(game, dt, minutes)
	_update_effects(night, dt)
	_update_toasts(night, dt)

	var phase := current_phase(shift_progress(night))
	if night.get("lastPhase", null) != phase["label"]:
		night["lastPhase"] = phase["label"]
		if float(night["clock"]) > 1.0:
			GameState.add_toast(night, phase["label"], "info")
		(game["bus"] as Bus).emit("phase", phase)

	# Die Schicht endet, wenn die Liste abgearbeitet ist - nicht nach der Uhr.
	if night["tutorial"] == null and int(night["processed"]) >= int(night["quota"]):
		end_night(game)

static func _update_inside(game: Dictionary, dt: float, minutes: float) -> void:
	var night: Dictionary = (game["state"] as Dictionary)["night"]
	var inside: Array = night["inside"]
	# Gaeste verlassen den Club nach und nach wieder.
	for i in range(inside.size() - 1, -1, -1):
		var g: Dictionary = inside[i]
		if float(g["spendLeft"]) <= 0.0 and float(night["clock"]) > 200.0 and randf() < dt * 0.05:
			inside.remove_at(i)

static func _update_effects(night: Dictionary, dt: float) -> void:
	var effects: Array = night["activeEffects"]
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e["remaining"] = float(e["remaining"]) - dt
		if float(e["remaining"]) <= 0.0:
			effects.remove_at(i)

static func _update_toasts(night: Dictionary, dt: float) -> void:
	var toasts: Array = night["toasts"]
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			toasts.remove_at(i)

static func end_night(game: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	night["running"] = false
	state["phase"] = "report"
	var lifetime: Dictionary = state["lifetime"]
	lifetime["nights"] = int(lifetime["nights"]) + 1

	var rating := Reputation.night_rating(night["stats"])
	night["rating"] = rating

	# Abschluss-Reputation aus der Gesamtleistung.
	var bonus := (rating - 2.5) * 1.6
	Reputation.change_reputation(state, bonus, "Nachtbewertung")

	# Kuenstler: nicht abgeholt = schlechte Presse.
	if night["artist"] != null and not bool(night["artistHandled"]):
		Reputation.change_reputation(state, -4.0, "Act nicht eingelassen")
		night["artistMissed"] = true

	var stats: Dictionary = night["stats"]
	var xp := int(round(
		int(stats["correct"]) * 8.0 + int(stats["admitted"]) * 2.0 + rating * 40.0
	))
	state["xp"] = int(state["xp"]) + xp
	night["xpGained"] = xp

	var capacity_used := clampf(
		float((night["inside"] as Array).size()) / float(GameState.capacity(state)), 0.0, 1.0
	)
	night["capacityUsed"] = capacity_used

	if float(state["reputation"]) >= 88.0 and int(state["nightIndex"]) >= 12:
		state["expandUnlocked"] = true

	(game["bus"] as Bus).emit("nightEnd", night)
	return night
