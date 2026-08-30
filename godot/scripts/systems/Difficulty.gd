## Fortschreitende Schwierigkeit: Mit jeder Nacht kommt eine neue Sorte
## Unregelmaessigkeit dazu, auf die man achten muss. Die Freischaltung wird im
## Briefing angekuendigt, damit niemand von einer neuen Regel ueberrascht wird,
## ohne sie zu kennen.
##
## Portierung von src/systems/difficulty.js.
class_name Difficulty
extends RefCounted

## Alle Stufen, die in dieser Nacht bereits gelten.
static func active_steps(night_number: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in Config.DIFFICULTY_STEPS:
		if night_number >= int(s["night"]):
			out.append(s)
	return out

## Die Stufe, die genau in dieser Nacht neu dazukommt (oder null).
static func new_step(night_number: int) -> Variant:
	for s: Dictionary in Config.DIFFICULTY_STEPS:
		if int(s["night"]) == night_number:
			return s
	return null

static func has_feature(night_number: int, id: String) -> bool:
	for s: Dictionary in Config.DIFFICULTY_STEPS:
		if s["id"] == id:
			return night_number >= int(s["night"])
	return false

## Wie stark greifen die Mechaniken in dieser Nacht?
## Alles skaliert sanft, damit Nacht 12 nicht schlagartig unspielbar wird.
static func difficulty_profile(night_number: int) -> Dictionary:
	var n := maxi(1, night_number)
	return {
		"night": n,
		"items": has_feature(n, "items"),
		"alcohol": has_feature(n, "alcohol"),
		"impaired": has_feature(n, "impaired"),
		"aggression": has_feature(n, "aggression"),
		"subtleId": has_feature(n, "subtleId"),
		"blacklist": has_feature(n, "blacklist"),
		"multi": has_feature(n, "multi"),

		# Wahrscheinlichkeit, dass ein Gast unter Substanzeinfluss steht.
		"impairedChance": minf(0.3, 0.08 + (n - 4) * 0.025) if has_feature(n, "impaired") else 0.0,
		# Wie deutlich sind die Anzeichen? Spaeter werden sie subtiler.
		"signClarity": maxf(0.45, 1.0 - maxi(0, n - 4) * 0.05),
		# Wahrscheinlichkeit fuer mehrere Maengel gleichzeitig.
		"multiIssueChance": minf(0.35, 0.12 + (n - 10) * 0.02) if has_feature(n, "multi") else 0.0,
		# Wie viele harmlose Gegenstaende liegen zur Ablenkung dabei?
		"decoyBonus": mini(2, int(floor(float(n - 1) / 4.0))),
	}

## Kurzliste fuer das Briefing.
static func difficulty_briefing(night_number: int) -> Dictionary:
	return {
		"active": active_steps(night_number),
		"fresh": new_step(night_number),
	}
