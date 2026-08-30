## Spieler-Fortschritt: Raenge und Talente.
##
## Portierung von src/systems/progression.js.
class_name Progression
extends RefCounted

## Prueft nach einer Nacht, ob ein Rang aufgestiegen wurde.
static func check_rank_up(state: Dictionary, previous_level: int) -> Variant:
	var current := GameState.rank(state)
	if int(current["level"]) > previous_level:
		state["talentPoints"] = int(state["talentPoints"]) + int(current["level"]) - previous_level
		return current
	return null

static func rank_progress(state: Dictionary) -> Dictionary:
	var current := GameState.rank(state)
	var next: Variant = GameState.next_rank(state)
	if next == null:
		return {"current": current, "next": null, "ratio": 1.0}
	var span := float(next["xp"]) - float(current["xp"])
	var done := float(state["xp"]) - float(current["xp"])
	return {
		"current": current, "next": next,
		"ratio": maxf(0.0, minf(1.0, done / span)),
	}

static func talent_list(state: Dictionary) -> Array[Dictionary]:
	var talents: Dictionary = state["talents"]
	var out: Array[Dictionary] = []
	for t: Dictionary in Config.TALENTS:
		var entry := t.duplicate(true)
		var level := int(talents.get(t["id"], 0))
		entry["level"] = level
		entry["canBuy"] = level < int(t["max"]) and int(state["talentPoints"]) > 0
		out.append(entry)
	return out

static func buy_talent(state: Dictionary, id: String) -> Dictionary:
	var def: Variant = null
	for t: Dictionary in Config.TALENTS:
		if t["id"] == id:
			def = t
			break
	if def == null:
		return {"ok": false, "reason": "Unbekannt"}
	if int(state["talentPoints"]) <= 0:
		return {"ok": false, "reason": "Keine Talentpunkte"}
	var talents: Dictionary = state["talents"]
	if int(talents.get(id, 0)) >= int(def["max"]):
		return {"ok": false, "reason": "Maximal"}
	talents[id] = int(talents.get(id, 0)) + 1
	state["talentPoints"] = int(state["talentPoints"]) - 1
	return {"ok": true, "level": talents[id], "label": def["label"]}
