## Economy System: Eintritt, Bar-Umsatz, Strafen, Zwischenfallkosten.
##
## Portierung von src/systems/economy.js.
class_name Economy
extends RefCounted

static func admit_revenue(state: Dictionary, guest: Dictionary) -> int:
	var fee := GameState.entry_fee(state)
	return int(round(fee * 1.6)) if bool((guest["truth"] as Dictionary)["vip"]) else fee

## Wie viel gibt der Gast im Laufe der Nacht drinnen aus?
static func planned_bar_spend(state: Dictionary, guest: Dictionary) -> float:
	var truth: Dictionary = guest["truth"]
	var vip_bonus := 1.0
	if bool(truth["vip"]):
		vip_bonus = 1.0 + GameState.upgrade_level(state, "vip") * 0.35
	return float(truth["spend"]) * GameState.spend_multiplier(state) * vip_bonus

static func earn(state: Dictionary, amount: float, category: String = "bar") -> int:
	var value := int(round(amount))
	state["money"] = float(state["money"]) + value
	var night: Variant = state["night"]
	if night != null:
		var stats: Dictionary = night["stats"]
		stats["revenue"] = float(stats["revenue"]) + value
		if category == "entry":
			stats["entry"] = float(stats["entry"]) + value
		elif category == "finding":
			pass  # wird separat als findingPay gefuehrt
		else:
			stats["bar"] = float(stats["bar"]) + value
	var lifetime: Dictionary = state["lifetime"]
	lifetime["revenue"] = float(lifetime["revenue"]) + value
	return value

static func spend(state: Dictionary, amount: float) -> int:
	var value := int(round(amount))
	state["money"] = float(state["money"]) - value
	return value

static func fine(state: Dictionary, amount: float, reason: String) -> Dictionary:
	var value := int(round(amount))
	state["money"] = float(state["money"]) - value
	var night: Variant = state["night"]
	if night != null:
		var stats: Dictionary = night["stats"]
		stats["fines"] = float(stats["fines"]) + value
		stats["revenue"] = float(stats["revenue"]) - value
	return {"value": value, "reason": reason}

static func incident_cost(state: Dictionary, severity: float = 1.0) -> int:
	var mitigation := 1.0 - GameState.upgrade_level(state, "team") * 0.12 \
		- GameState.upgrade_level(state, "cameras") * 0.08
	return maxi(20, int(round(
		float(Config.TUNING["incidentBaseCost"]) * severity * maxf(0.3, mitigation)
	)))

## Laufender Bar-Umsatz der Gaeste im Club (pro Spielminute).
## Bruchteile werden gepuffert, damit kein Umsatz durch Rundung verloren geht.
static func tick_inside_revenue(state: Dictionary, minutes: float) -> float:
	var night: Variant = state["night"]
	if night == null:
		return 0.0
	var total := 0.0
	for g: Dictionary in (night["inside"] as Array):
		if float(g["spendLeft"]) <= 0.0:
			continue
		var rate := float(g["spendTotal"]) / 90.0  # ueber ca. 90 Spielminuten verteilt
		var amount := minf(float(g["spendLeft"]), rate * minutes)
		g["spendLeft"] = float(g["spendLeft"]) - amount
		total += amount
	night["barAccum"] = float(night.get("barAccum", 0.0)) + total
	if float(night["barAccum"]) >= 1.0:
		var payout := floorf(float(night["barAccum"]))
		night["barAccum"] = float(night["barAccum"]) - payout
		earn(state, payout, "bar")
	return total
