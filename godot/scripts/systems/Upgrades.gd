## Upgrade System: Club-Ausbau mit sichtbaren Stufen.
##
## Portierung von src/systems/upgrades.js.
class_name Upgrades
extends RefCounted

static func upgrade_by_id(id: String) -> Variant:
	for u: Dictionary in Config.UPGRADES:
		if u["id"] == id:
			return u
	return null

## Preis fuer die naechste Stufe, oder null bei voll ausgebaut.
static func next_cost(state: Dictionary, id: String) -> Variant:
	var def: Variant = upgrade_by_id(id)
	if def == null:
		return null
	var level := GameState.upgrade_level(state, id)
	if level >= int(def["max"]):
		return null
	return int(round(float(def["cost"][level]) * GameState.upgrade_cost_multiplier(state)))

static func can_buy(state: Dictionary, id: String) -> bool:
	var cost: Variant = next_cost(state, id)
	return cost != null and float(state["money"]) >= float(cost)

static func buy_upgrade(state: Dictionary, id: String) -> Dictionary:
	var def: Variant = upgrade_by_id(id)
	var cost: Variant = next_cost(state, id)
	if def == null or cost == null:
		return {"ok": false, "reason": "Maximal ausgebaut"}
	if float(state["money"]) < float(cost):
		return {"ok": false, "reason": "Nicht genug Geld"}

	var tier_before := int(GameState.club_tier(state)["level"])
	state["money"] = float(state["money"]) - float(cost)
	var upgrades: Dictionary = state["upgrades"]
	upgrades[id] = GameState.upgrade_level(state, id) + 1
	var tier_after := int(GameState.club_tier(state)["level"])

	return {
		"ok": true,
		"id": id,
		"level": upgrades[id],
		"cost": cost,
		"desc": def["desc"][int(upgrades[id]) - 1],
		"tierChanged": tier_after > tier_before,
		"tier": tier_after,
	}

## Gruppierte Liste fuer den Shop.
static func upgrade_list(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in Config.UPGRADES:
		var level := GameState.upgrade_level(state, def["id"])
		var cost: Variant = next_cost(state, def["id"])
		var max_level := int(def["max"])
		out.append({
			"id": def["id"],
			"label": def["label"],
			"group": def["group"],
			"level": level,
			"max": max_level,
			"cost": cost,
			"maxed": level >= max_level,
			# Was die naechste Stufe bringt (bei MAX: die letzte Stufe).
			"nextDesc": def["desc"][level] if level < max_level else def["desc"][max_level - 1],
			# Was gerade schon gebaut ist - null, solange nichts gekauft wurde.
			"currentDesc": def["desc"][level - 1] if level > 0 else null,
			# Ausbaupunkte pro Stufe: zaehlt auf die sichtbare Club-Stufe ein.
			"tierWeight": int(def.get("tier", 1)),
			"affordable": cost != null and float(state["money"]) >= float(cost),
		})
	return out
