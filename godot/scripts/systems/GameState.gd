## Zentraler Spielzustand + abgeleitete Werte.
##
## Portierung von src/systems/state.js. Der Zustand bleibt bewusst ein
## Dictionary statt einer typisierten Klasse: die Web-Fassung reicht dasselbe
## Objekt durch alle Systeme, serialisiert es fuer den Online-Koop und
## speichert Teile davon als JSON. Ein Dictionary bildet das 1:1 ab und haelt
## Serialisierung und Snapshot-Abgleich trivial.
class_name GameState
extends RefCounted

static func create_initial_state(mode: String = "solo") -> Dictionary:
	var upgrades := {}
	for u: Dictionary in Config.UPGRADES:
		upgrades[u["id"]] = 0

	return {
		"version": 2,
		"mode": mode,        # solo | local | online
		"phase": "menu",     # menu | office | club | briefing | night | report | shop
		"money": float(Config.TUNING["moneyStart"]),
		"reputation": float(Config.TUNING["reputationStart"]),
		"xp": 0,
		"talentPoints": 1,
		"talents": {"street": 0, "scanner": 0, "charisma": 0, "reputation": 0, "management": 0},
		"upgrades": upgrades,
		"nightIndex": 0,
		"clubsOwned": 1,
		"expandUnlocked": false,
		"bookedArtist": null,
		# Der eigene Tuersteher - im Editor erstellt, am Kleiderschrank aenderbar.
		"character": CharacterSys.create_character(),
		"tutorialDone": false,
		# Freischaltungen: das Tutorial gibt Mechaniken nacheinander frei.
		"unlocks": {"id": true, "talk": false, "search": false, "alcohol": false, "calm": false},
		"lifetime": {
			"guests": 0, "admitted": 0, "rejected": 0, "revenue": 0.0,
			"incidents": 0, "nights": 0,
		},
		"night": null,
		"log": [],
	}

## Wie viele Gaeste muessen in dieser Nacht abgefertigt werden?
## Die Schicht endet nicht nach der Uhr, sondern wenn die Liste leer ist.
static func guest_quota(state: Dictionary) -> int:
	var n: int = maxi(0, int(state["nightIndex"]) - 1)
	return mini(
		int(Config.TUNING["guestsPerNightMax"]),
		int(Config.TUNING["guestsPerNight"]) + n * int(Config.TUNING["guestsPerNightGrowth"])
	)

## Zustand einer laufenden Nacht.
static func create_night_state(
	event: Variant, artist: Variant, seed_value: int,
	mode: String = "solo", quota: int = -1
) -> Dictionary:
	if quota < 0:
		quota = int(Config.TUNING["guestsPerNight"])
	return {
		# Schichtplan statt Uhr: so viele Gaeste sind zu pruefen.
		"quota": quota,
		"processed": 0,

		"seed": seed_value,
		"mode": mode,
		"event": event,
		"artist": artist,
		"artistArrived": false,
		"artistHandled": false,
		"artistDelayed": false,
		"clock": float(Config.TUNING["nightStartMinute"]),
		"running": true,
		"tutorial": null,

		"queue": [],         # Warteschlange draussen
		"airlockQueue": [],  # durchgelassene Gaeste, warten in der Schleuse
		"inside": [],
		"leaving": [],

		"stations": {
			"door": new_station("door"),
			"airlock": new_station("airlock"),
		},

		# Ab welchem abgearbeiteten Gast spaetestens jemand ausrastet?
		# Genau ein garantierter Uebergriff pro Nacht - start_night wuerfelt
		# aus, wann er faellig wird (siehe systems/Aggression.gd).
		"forcedAttackAt": 0,

		"spawnCooldown": 0.25,
		"randomEventCooldown": 40.0,
		"activeEffects": [],
		"stats": {
			"arrived": 0, "admitted": 0, "rejected": 0, "left": 0, "passed": 0,
			"revenue": 0.0, "entry": 0.0, "bar": 0.0, "incidents": 0, "vips": 0,
			"correct": 0, "mistakes": 0, "verified": 0, "catches": 0,
			"fines": 0.0, "artistFee": 0.0,
			# Selbst gefundene Unregelmaessigkeiten (Ausweis, Sachen, Alkohol).
			"findings": 0, "falseAlarms": 0, "overlooked": 0, "findingPay": 0.0,
			# Uebergriffe: versucht, abgewehrt, durchgekommen.
			"attacks": 0, "defended": 0, "attacksLanded": 0, "defensePay": 0.0,
		},
		"repDelta": 0.0,
		"toasts": [],
	}

static func new_station(id: String) -> Dictionary:
	return {
		"id": id,
		"guest": null,
		"checks": empty_checks(),
		"patdown": null,
		"notes": Notes.empty_notes(),
		# Laufender Uebergriff (siehe systems/Aggression.gd).
		"aggro": null,
		"aggroCooldown": 2.0,
	}

static func empty_checks() -> Dictionary:
	return {
		"id": null,       # Inspection-Objekt (siehe Identity.gd)
		"talk": null,     # { line, realName, hint, moodHint }
		"search": null,   # { done, found, text }
		"alcohol": null,  # { value, promille, overLimit }
		"verified": false,
		"conflict": false,
	}

## Solo: alles laeuft an der Tuer. Koop: Tuer draussen, Schleuse innen.
static func is_solo(state: Dictionary) -> bool:
	return state["mode"] == "solo"

static func station_for(state: Dictionary, area_or_role: String) -> Variant:
	var night: Variant = state["night"]
	if night == null:
		return null
	if is_solo(state):
		return night["stations"]["door"]
	return night["stations"]["airlock"] \
		if area_or_role == "airlock" or area_or_role == "security" \
		else night["stations"]["door"]

static func airlock_capacity(state: Dictionary) -> int:
	return Config.AIRLOCK_CAPACITY + (2 if upgrade_level(state, "door") >= 2 else 0)

# ---------- Abgeleitete Werte ----------

static func upgrade_level(state: Dictionary, id: String) -> int:
	return int((state["upgrades"] as Dictionary).get(id, 0))

static func total_upgrade_tiers(state: Dictionary) -> int:
	var sum := 0
	for u: Dictionary in Config.UPGRADES:
		sum += upgrade_level(state, u["id"]) * int(u.get("tier", 1))
	return sum

static func club_tier(state: Dictionary) -> Dictionary:
	var total := total_upgrade_tiers(state)
	var tier: Dictionary = Config.CLUB_TIERS[0]
	for t: Dictionary in Config.CLUB_TIERS:
		if total >= int(t["need"]):
			tier = t
	return tier

static func capacity(state: Dictionary) -> int:
	var floor_level := upgrade_level(state, "floor")
	var table := [0, 80, 220, 440]
	var add: int = table[floor_level] if floor_level < table.size() else 0
	return int(Config.TUNING["baseCapacity"]) + add

static func queue_capacity(state: Dictionary) -> int:
	return int(Config.TUNING["baseQueueCapacity"]) + upgrade_level(state, "door") * 5

static func rank(state: Dictionary) -> Dictionary:
	var r: Dictionary = Config.RANKS[0]
	for entry: Dictionary in Config.RANKS:
		if int(state["xp"]) >= int(entry["xp"]):
			r = entry
	return r

static func next_rank(state: Dictionary) -> Variant:
	var current := rank(state)
	for r: Dictionary in Config.RANKS:
		if int(r["level"]) == int(current["level"]) + 1:
			return r
	return null

## Multiplikator fuer Aktionsdauer (kleiner = schneller).
static func action_speed(state: Dictionary) -> float:
	# Admin-Testhilfe: Kontrollen laufen praktisch ohne Wartezeit durch.
	if Admin.unlocked and Admin.fast_actions:
		return 0.05
	var talent := int((state["talents"] as Dictionary)["scanner"]) * 0.12
	var scanner := 0.18 if upgrade_level(state, "scanner") >= 2 else 0.0
	var door := 0.08 if upgrade_level(state, "door") >= 1 else 0.0
	return clampf(1.0 - talent - scanner - door, 0.4, 1.0)

static func spend_multiplier(state: Dictionary) -> float:
	var bar := upgrade_level(state, "bar") * 0.18
	var sound := upgrade_level(state, "sound") * 0.1
	var vip := upgrade_level(state, "vip") * 0.12
	var mgmt := int((state["talents"] as Dictionary)["management"]) * 0.05
	var artist := 1.0
	var night: Variant = state["night"]
	if night != null and night["artist"] != null:
		artist = float((night["artist"] as Dictionary).get("spend", 1.0))
	return (1.0 + bar + sound + vip + mgmt) * artist

static func patience_multiplier(state: Dictionary) -> float:
	var lights := upgrade_level(state, "lights") * 0.08
	var comfort := upgrade_level(state, "comfort") * 0.1
	var team := upgrade_level(state, "team") * 0.07
	var charisma := int((state["talents"] as Dictionary)["charisma"]) * 0.09
	return 1.0 + lights + comfort + team + charisma

static func reputation_gain_multiplier(state: Dictionary) -> float:
	return 1.0 + int((state["talents"] as Dictionary)["reputation"]) * 0.2 \
		+ upgrade_level(state, "comfort") * 0.08

static func upgrade_cost_multiplier(state: Dictionary) -> float:
	return clampf(1.0 - int((state["talents"] as Dictionary)["management"]) * 0.07, 0.7, 1.0)

static func entry_fee(state: Dictionary) -> int:
	var rep := float(state["reputation"])
	var tier := int(club_tier(state)["level"])
	return int(round(float(Config.TUNING["baseEntryFee"]) + rep * 0.12 + tier * 2.5))

static func roles_of(state: Dictionary) -> Array[Dictionary]:
	return Config.roles_for(state["mode"])

static func push_log(state: Dictionary, text: String, kind: String = "info") -> void:
	var log_list: Array = state["log"]
	log_list.push_front({"text": text, "kind": kind, "t": Time.get_ticks_msec()})
	if log_list.size() > 60:
		log_list.resize(60)

static func add_toast(night: Variant, text: String, kind: String = "info", ttl: float = 3.4) -> void:
	if night == null:
		return
	var toasts: Array = night["toasts"]
	toasts.append({"text": text, "kind": kind, "ttl": ttl, "life": ttl})
	if toasts.size() > 6:
		toasts.pop_front()
