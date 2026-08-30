## Guest System: erzeugt Gaeste mit versteckten Eigenschaften.
## Die Wahrheit (`truth`) ist fuer den Spieler unsichtbar und wird nur
## ueber Kontrollen (ID, Scan, Abtasten, Gespraech, Alkoholtest) aufgedeckt.
##
## Portierung von src/systems/guests.js. Die Reihenfolge der Zufallszuege ist
## unveraendert - sonst erzeugt derselbe Seed eine andere Nacht als die
## Web-Fassung.
class_name Guests
extends RefCounted

static var _guest_serial := 0

static func create_guest(rng: Rng, ctx: Dictionary = {}) -> Dictionary:
	var event: Variant = ctx.get("event", null)
	var reputation := float(ctx.get("reputation", 40.0))
	var patience_mul := float(ctx.get("patienceMul", 1.0))
	var night_index := int(ctx.get("nightIndex", 1))
	var force_archetype: Variant = ctx.get("forceArchetype", null)

	var archetype: Dictionary
	if force_archetype != null:
		archetype = Config.ARCHETYPES[0]
		for a: Dictionary in Config.ARCHETYPES:
			if a["id"] == force_archetype:
				archetype = a
				break
	else:
		archetype = rng.weighted_pick_fn(
			Config.ARCHETYPES,
			func(a: Variant) -> float: return _archetype_weight(a, event, reputation)
		)

	var personality := _choose_personality(rng, archetype)
	var drunk := clampf(
		rng.range_float(archetype["drunk"][0], archetype["drunk"][1]), 0.0, 1.0
	)
	# Die JS-Fassung schreibt hier `(event?.trouble ?? 1 - 1) * 0.1`. Weil `??`
	# schwaecher bindet als `-`, ist der Ersatzwert 0 und nicht 1 - ohne
	# Nacht-Event faellt der Zuschlag also ganz weg. Bewusst uebernommen,
	# damit die Balance identisch bleibt.
	var trouble_term := float(event["trouble"]) if event != null else 0.0
	var risk := clampf(
		rng.range_float(archetype["risk"][0], archetype["risk"][1]) + trouble_term * 0.1,
		0.0, 1.0
	)

	# Alter: die meisten sind erwachsen, manche zu jung.
	var underage := rng.chance(_underage_chance(archetype, event))
	var real_age := rng.range_int(15, 17) if underage else rng.range_int(18, 46)

	# Ausweis-Problem
	var bad_id := rng.chance(float(archetype["badIdChance"]) * _event_factor(event, "trouble"))
	var id_issues: Array[String] = []
	if underage:
		# Zu junge Gaeste faelschen fast immer das Dokument.
		id_issues.append("age" if rng.chance(0.7) else "photo")
	if bad_id:
		var issue: String = (rng.pick(Config.ID_ISSUES) as Dictionary)["id"]
		if not id_issues.has(issue):
			id_issues.append(issue)

	var profile := Difficulty.difficulty_profile(night_index)

	# --- Gepaeck: nur wer eine Tasche dabei hat, hat auch eine Zone dafuer ---
	var has_bag := rng.chance(0.8 if archetype["id"] == "crew" else 0.42)
	var zone_ids: Array[String] = []
	for z: Dictionary in Config.ZONES:
		if not z["needsBag"] or has_bag:
			zone_ids.append(z["id"])

	# --- Verbotener Gegenstand (hoechstens einer pro Gast) ---
	var contraband_chance := float(archetype["contrabandChance"]) * _event_factor(event, "trouble") \
		+ risk * 0.15
	var contraband: Variant = null
	var contraband_zone: Variant = null
	if rng.chance(clampf(contraband_chance, 0.0, 0.85)):
		var max_severity := 3 if risk > 0.6 else 2
		var pool: Array[Dictionary] = []
		for i: Dictionary in Config.items():
			if not i["forbidden"] or int(i["severity"]) > max_severity:
				continue
			if _any_zone_matches(i["zones"], zone_ids):
				pool.append(i)
		if not pool.is_empty():
			contraband = rng.weighted_pick_fn(
				pool, func(i: Variant) -> float: return 4.0 - float(i["severity"])
			)
			var zones_left: Array = []
			for z: String in (contraband["zones"] as Array):
				if zone_ids.has(z):
					zones_left.append(z)
			contraband_zone = rng.pick(zones_left)

	# --- Was in jeder Zone steckt (harmloses Zeug als Ablenkung) ---
	var carried := {}
	var used := {}
	for zone: Dictionary in Config.ZONES:
		if not zone_ids.has(zone["id"]):
			continue
		# Niemand hat zwei Feuerzeuge dabei: pro Gast jedes Ding nur einmal.
		var harmless: Array[Dictionary] = []
		for i: Dictionary in Config.items():
			if not i["forbidden"] and (i["zones"] as Array).has(zone["id"]) and not used.has(i["id"]):
				harmless.append(i)
		var count := mini(
			harmless.size(),
			rng.range_int(zone["capacity"][0], zone["capacity"][1]) + int(profile["decoyBonus"])
		)
		var picked: Array[Dictionary] = []
		for i in count:
			var sub_pool: Array[Dictionary] = []
			for it: Dictionary in harmless:
				if not picked.has(it):
					sub_pool.append(it)
			if sub_pool.is_empty():
				break
			var item: Dictionary = rng.pick(sub_pool)
			used[item["id"]] = true
			picked.append(item)
		if contraband != null and contraband_zone == zone["id"]:
			picked.insert(rng.range_int(0, picked.size()), contraband)
		carried[zone["id"]] = picked

	var items: Array[Dictionary] = []
	for zone_id: String in carried:
		items.append_array(carried[zone_id])

	# --- Substanzeinfluss: ab der vierten Nacht ein eigenes Thema ---
	var impaired := 0.0
	if rng.chance(float(profile["impairedChance"]) * (1.0 + risk)):
		impaired = clampf(
			rng.range_float(0.45, 1.0) * (1.1 if archetype["id"] == "trouble" else 1.0),
			0.0, 1.0
		)
	var signs: Array[String] = []
	for sign_entry: Dictionary in Config.IMPAIRMENT_SIGNS:
		if impaired >= float(sign_entry["min"]) and rng.chance(float(profile["signClarity"])):
			signs.append(sign_entry["id"])

	var vip: bool = rng.chance(float(archetype["vip"]) * _event_factor(event, "vip") * 0.6) \
		or archetype["id"] == "vip"
	var spend_base := rng.range_float(archetype["spend"][0], archetype["spend"][1])
	var spend := spend_base * (1.0 + reputation / 220.0) * _event_factor(event, "spend")

	var blacklisted := rng.chance(0.25 if risk > 0.7 else 0.03)

	var guest_name := "%s %s" % [rng.pick(Config.FIRST_NAMES), rng.pick(Config.LAST_NAMES)]
	var doc_name := guest_name
	if id_issues.has("name"):
		doc_name = "%s %s" % [rng.pick(Config.FIRST_NAMES), rng.pick(Config.LAST_NAMES)]

	# Geburtsdatum: bei Manipulation zeigt das Dokument ein Alter ueber 18,
	# die Ziffern sind dann aber sichtbar veraendert (doc.tampered).
	var tampered := id_issues.has("age")
	var shown_age := real_age
	if tampered:
		shown_age = maxi(int(Config.TUNING["minAge"]), real_age + rng.range_int(2, 6))
	var birth := _birth_string(rng, shown_age)

	# Ausweisfoto: bei Foto-Faelschung deutlich anderes Aussehen als der Gast.
	var look := {
		"skin": rng.range_int(0, 5),
		"outfit": rng.range_int(0, 7),
		"hair": rng.range_int(0, 6),
		"height": rng.range_float(0.92, 1.1),
		"bulk": rng.range_float(0.88, 1.14),
	}
	var photo_look := look.duplicate()
	if id_issues.has("photo"):
		photo_look["skin"] = (int(look["skin"]) + 2 + rng.range_int(0, 2)) % 6
		photo_look["hair"] = (int(look["hair"]) + 3) % 7

	var expiry: String
	if id_issues.has("expired"):
		expiry = "%d-%s-%s" % [
			rng.range_int(2021, 2025), _pad(rng.range_int(1, 12)), _pad(rng.range_int(1, 28)),
		]
	else:
		expiry = "%d-%s-%s" % [
			rng.range_int(2027, 2033), _pad(rng.range_int(1, 12)), _pad(rng.range_int(1, 28)),
		]

	var patience := float(Config.TUNING["patienceBase"]) * float(archetype["patience"]) \
		* patience_mul * (0.7 if vip else 1.0)

	_guest_serial += 1
	var guest := {
		"id": "g%d" % _guest_serial,
		"name": guest_name,
		"archetype": archetype["id"],
		"archetypeLabel": archetype["label"],
		"personality": personality,
		"backstage": bool(archetype.get("backstage", false)),
		"inspector": bool(archetype.get("inspector", false)),
		"seed": int(floor(rng.next() * 1e9)),

		# Sichtbare Optik
		"look": look,

		# Versteckte Wahrheit
		"truth": {
			"age": real_age,
			"underage": underage,
			"idIssues": id_issues,
			"idValid": id_issues.is_empty(),
			"drunk": drunk,
			"risk": risk,
			"blacklisted": blacklisted,
			"vip": vip,
			"spend": spend,
			"items": items,
			"carried": carried,
			"hasBag": has_bag,
			"zoneIds": zone_ids,
			"contraband": contraband,
			"contrabandZone": contraband_zone,
			"impaired": impaired,
			"impairmentSigns": signs,
			# Wird erst wahr, wenn der Gast tatsaechlich handgreiflich wird.
			"aggressive": false,
			# Was er behauptet, wenn man ihn anspricht (siehe Statements.gd).
			"statements": [],
			"repValue": float(archetype["rep"]),
		},

		# Das vorgezeigte Dokument - genau das, was der Spieler zu sehen bekommt
		"doc": {
			"name": doc_name,
			"birth": birth,
			"expiry": expiry,
			"marksOk": not id_issues.has("marks"),
			"tampered": tampered,
			"photoLook": photo_look,
			"number": "%s%d" % [
				char(65 + rng.range_int(0, 25)), rng.range_int(10000000, 99999999),
			],
			"issuer": rng.pick(["BUNDESREPUBLIK", "REPUBLIK", "KANTON", "STAAT"]),
			# Nur intern: das Alter, das das Dokument behauptet.
			"shownAge": shown_age,
		},

		# Zustand in der Warteschlange
		"patience": patience,
		"patienceMax": patience,
		"mood": 0.25 if personality == "aggressive" else (0.45 if personality == "annoyed" else 0.75),
		"x": 0.0, "y": 0.0, "targetX": 0.0, "targetY": 0.0,
		"walkPhase": rng.next() * TAU,
		"swayPhase": rng.next() * TAU,
		"state": "queue",  # queue | door | admitted | rejected | left
		"said": null,
		"saidTimer": 0.0,
		"difficulty": night_index,
	}

	# Was der Gast behauptet, haengt an seiner Wahrheit - also erst jetzt bauen.
	(guest["truth"] as Dictionary)["statements"] = Statements.build_statements(rng, guest)
	return guest

static func _pad(n: int) -> String:
	return str(n).pad_zeros(2)

## Liefert den Faktor eines Nacht-Events oder 1, wenn keines laeuft.
static func _event_factor(event: Variant, key: String) -> float:
	if event == null:
		return 1.0
	return float((event as Dictionary).get(key, 1.0))

static func _any_zone_matches(zones: Array, zone_ids: Array) -> bool:
	for z: Variant in zones:
		if zone_ids.has(z):
			return true
	return false

## Erzeugt ein Geburtsdatum, das am Spieldatum exakt das gewuenschte Alter
## ergibt. (Wer dieses Jahr noch nicht Geburtstag hatte, ist ein Jahr frueher
## geboren.)
static func _birth_string(rng: Rng, age: int) -> String:
	var month := rng.range_int(1, 12)
	var day := rng.range_int(1, 28)
	var game_month := int(Config.GAME_DATE["month"])
	var game_day := int(Config.GAME_DATE["day"])
	var had_birthday := month < game_month or (month == game_month and day <= game_day)
	var year := int(Config.GAME_DATE["year"]) - age - (0 if had_birthday else 1)
	return "%d-%s-%s" % [year, _pad(month), _pad(day)]

static func _underage_chance(archetype: Dictionary, event: Variant) -> float:
	var base := 0.07
	if archetype["id"] == "trouble":
		base = 0.2
	elif archetype["id"] == "tourist":
		base = 0.12
	return clampf(base * _event_factor(event, "trouble"), 0.0, 0.4)

static func _archetype_weight(a: Dictionary, event: Variant, reputation: float) -> float:
	var w := float(a["weight"])
	if float(a["vip"]) > 0.0:
		w *= _event_factor(event, "vip") * (0.6 + reputation / 90.0)
	if a["id"] == "trouble":
		w *= _event_factor(event, "trouble")
	if a["id"] == "influencer" or a["id"] == "scene":
		w *= 0.5 + reputation / 80.0
	if a["id"] == "inspector" or a["id"] == "insider":
		var inspection: bool = event != null and bool((event as Dictionary).get("inspection", false))
		w *= 3.0 if inspection else 1.0
	return maxf(0.1, w)

static func _choose_personality(rng: Rng, archetype: Dictionary) -> String:
	var weights := {
		"polite": 3.0, "annoyed": 2.0, "drunk": 1.0,
		"arrogant": 1.0, "aggressive": 0.6, "nervous": 1.0,
	}
	match archetype["id"]:
		"trouble":
			weights["aggressive"] = 5.0
			weights["drunk"] = 3.0
			weights["polite"] = 0.4
		"vip":
			weights["arrogant"] = 6.0
			weights["polite"] = 2.0
			weights["aggressive"] = 0.5
		"influencer":
			weights["arrogant"] = 4.0
			weights["polite"] = 2.0
		"local":
			weights["polite"] = 5.0
			weights["annoyed"] = 2.0
		"mystery":
			weights["nervous"] = 5.0
	var entries: Array[Dictionary] = []
	for p: String in Dialogue.PERSONALITIES:
		entries.append({"p": p, "w": float(weights.get(p, 1.0))})
	var chosen: Dictionary = rng.weighted_pick_fn(
		entries, func(e: Variant) -> float: return float(e["w"])
	)
	return chosen["p"]

## Der Gast nennt seinen echten Namen - die Antwort auf ANSPRECHEN.
static func guest_name_line(rng: Rng, guest: Dictionary) -> String:
	var set_lines: Array = Dialogue.NAME_LINES.get(guest["personality"], Dialogue.NAME_LINES["polite"])
	return Dialogue.with_name(rng.pick(set_lines), guest["name"])

## Zufaellige Zeile passend zur Situation.
static func guest_line(rng: Rng, guest: Dictionary, situation: String) -> String:
	var set_lines: Dictionary = Dialogue.LINES.get(guest["personality"], Dialogue.LINES["polite"])
	var pool: Array = set_lines.get(situation, set_lines["talk"])
	return rng.pick(pool)

## Regelwerk: darf dieser Gast rein?
## Gibt die Liste der objektiven Verstoesse zurueck (leer = Einlass korrekt).
static func violations_of(guest: Dictionary) -> Array[Dictionary]:
	var v: Array[Dictionary] = []
	var t: Dictionary = guest["truth"]
	if bool(t["underage"]) or int(t["age"]) < int(Config.TUNING["minAge"]):
		v.append({"id": "underage", "label": "Minderjährig", "severity": 3})
	if not bool(t["idValid"]):
		v.append({"id": "id", "label": "Ausweis ungültig", "severity": 2})
	if float(t["drunk"]) >= float(Config.TUNING["drunkRejectThreshold"]):
		v.append({"id": "drunk", "label": "Zu betrunken", "severity": 1})
	if t["contraband"] != null:
		var cb: Dictionary = t["contraband"]
		v.append({
			"id": "item",
			"label": "Verbotener Gegenstand: %s" % cb["label"],
			"severity": int(cb["severity"]),
		})
	if float(t.get("impaired", 0.0)) >= 0.6:
		v.append({"id": "impaired", "label": "Steht sichtbar unter Einfluss", "severity": 2})
	if bool(t["blacklisted"]):
		v.append({"id": "blacklist", "label": "Hausverbot", "severity": 2})
	# Wer handgreiflich wird, hat sich die Entscheidung selbst abgenommen.
	if bool(t["aggressive"]):
		v.append({"id": "aggressive", "label": "Übergriff an der Tür", "severity": 3})
	return v

static func should_reject(guest: Dictionary) -> bool:
	return not violations_of(guest).is_empty()

## Zeigt der Gast sichtbare Warnzeichen (fuer Street-Smarts / Rendering)?
static func visible_tells(guest: Dictionary, talent_street: int = 0) -> Array[String]:
	var tells: Array[String] = []
	var t: Dictionary = guest["truth"]
	if float(t["drunk"]) > 0.55:
		tells.append("schwankt")
	for sign_id: String in (t.get("impairmentSigns", []) as Array):
		var label := sign_id
		for s: Dictionary in Config.IMPAIRMENT_SIGNS:
			if s["id"] == sign_id:
				label = s["label"]
				break
		tells.append(label)
	if float(t["risk"]) > 0.65 and talent_street >= 1:
		tells.append("unruhig")
	if t["contraband"] != null and talent_street >= 2 \
			and int((t["contraband"] as Dictionary)["severity"]) >= 2:
		tells.append("greift staendig zur Jacke")
	if bool(t["underage"]) and talent_street >= 3:
		tells.append("wirkt sehr jung")
	if bool(t["vip"]):
		tells.append("teure Kleidung")
	return tells

static func reset_guest_serial() -> void:
	_guest_serial = 0
