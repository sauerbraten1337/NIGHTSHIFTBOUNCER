## Random Event System: macht jede Nacht anders.
## Ereignisse setzen zeitlich begrenzte Effekte und/oder erzeugen Sondergaeste.
##
## Portierung von src/systems/randomEvents.js.
class_name RandomEvents
extends RefCounted

## Anteil der abgearbeiteten Schicht (lokal gehalten wie in der Vorlage).
static func _shift_progress(night: Variant) -> float:
	if night == null or int(night.get("quota", 0)) == 0:
		return 0.0
	return minf(1.0, float(night["processed"]) / float(night["quota"]))

static func update_random_events(game: Dictionary, dt: float, minutes: float) -> void:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var night: Dictionary = state["night"]

	var progress := _shift_progress(night)

	# Kuenstler kommt am Hintereingang an - abhaengig vom Schichtfortschritt.
	if night["artist"] != null and not bool(night["artistArrived"]):
		var arrive_at := 0.62 if bool(night["artistDelayed"]) else 0.45
		if progress >= arrive_at:
			Artists.arrive_artist(game)

	night["randomEventCooldown"] = float(night["randomEventCooldown"]) - dt
	if float(night["randomEventCooldown"]) > 0.0:
		return

	var chaos := 1.0
	if night["event"] != null and bool((night["event"] as Dictionary).get("chaos", false)):
		chaos = 0.6
	night["randomEventCooldown"] = rng.range_float(32.0, 70.0) * chaos
	if progress < 0.08 or progress > 0.9:
		return
	if not rng.chance(0.72):
		return

	var event: Dictionary = rng.weighted_pick(Config.RANDOM_EVENTS)
	trigger_random_event(game, event)

static func trigger_random_event(game: Dictionary, event: Dictionary) -> void:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var bus: Bus = game["bus"]
	var night: Dictionary = state["night"]

	match event["id"]:
		"blackout":
			_push_effect(night, event, 16.0)
			GameState.add_toast(night, "STROM WEG - KEIN LICHT, KEIN PRÜFGERÄT", "bad", 5.0)
			bus.emit("sfx", "alarm")

		"scannerFail":
			_push_effect(night, event, 25.0)
			GameState.add_toast(night, "PRÜFGERÄT SPINNT - OHNE HINWEISE WEITER", "warn", 5.0)
			bus.emit("sfx", "beep")

		"rush":
			_push_effect(night, event, 12.0)
			GameState.add_toast(night, "EINE GANZE GRUPPE AUF EINMAL", "warn", 4.0)

		"celebrity":
			var celeb := Guests.create_guest(rng, {
				"event": night["event"], "reputation": float(state["reputation"]),
				"nightIndex": int(state["nightIndex"]), "forceArchetype": "vip",
			})
			celeb["celebrity"] = true
			QueueSys.insert_guest(game, celeb, true)
			GameState.add_toast(night, "UNERWARTETER GAST VORNE", "warn")

		"complaint":
			var queue: Array = night["queue"]
			for i in mini(6, queue.size()):
				var g: Dictionary = queue[i]
				g["mood"] = maxf(0.0, float(g["mood"]) - 0.35)
			GameState.add_toast(night, "DIE SCHLANGE WIRD UNRUHIG", "warn")

		"influencerPost":
			_push_effect(night, event, 45.0)
			Reputation.change_reputation(state, 2.5, "viral")
			GameState.add_toast(night, "DER CLUB GEHT VIRAL", "good")

		"artistLate":
			if night["artist"] != null and not bool(night["artistArrived"]):
				night["artistDelayed"] = true
				GameState.add_toast(night, "%s KOMMT SPÄTER" % String(
					(night["artist"] as Dictionary)["name"]
				).to_upper(), "warn", 4.0)

		"fakePass":
			var fake := Guests.create_guest(rng, {
				"event": night["event"], "reputation": float(state["reputation"]),
				"nightIndex": int(state["nightIndex"]), "forceArchetype": "crew",
			})
			var t: Dictionary = fake["truth"]
			t["idIssues"] = ["name"]
			t["idValid"] = false
			(fake["doc"] as Dictionary)["name"] = "CREW / UNBEKANNT"
			fake["fakeCrew"] = true
			QueueSys.insert_guest(game, fake, true)
			GameState.add_toast(night, "ANGEBLICHES CREW-MITGLIED", "warn")

	night["lastEvent"] = {"label": event["label"], "desc": event["desc"], "life": 5.0}
	bus.emit("randomEvent", event)

static func _push_effect(night: Dictionary, event: Dictionary, duration: float) -> void:
	var effects: Array = night["activeEffects"]
	for e: Dictionary in effects:
		if e["id"] == event["id"]:
			return
	effects.append({
		"id": event["id"], "label": event["label"],
		"remaining": duration, "total": duration,
	})
	GameState.add_toast(night, event["label"], "warn", 4.0)
