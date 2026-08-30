## Reputation System: Ruf 0-100 steuert Andrang, Preise und Acts.
##
## Portierung von src/systems/reputation.js.
class_name Reputation
extends RefCounted

static func change_reputation(state: Dictionary, delta: float, reason: String = "") -> Dictionary:
	var scaled := delta * GameState.reputation_gain_multiplier(state) if delta > 0.0 else delta
	var before := float(state["reputation"])
	state["reputation"] = clampf(before + scaled, 0.0, 100.0)
	var applied := float(state["reputation"]) - before
	var night: Variant = state["night"]
	if night != null:
		night["repDelta"] = float(night.get("repDelta", 0.0)) + applied
	return {"applied": applied, "reason": reason}

## Reputation beeinflusst, wie viele Gaeste ueberhaupt auftauchen.
static func crowd_pull(state: Dictionary) -> float:
	return 0.55 + (float(state["reputation"]) / 100.0) * 1.5

static func rep_band(rep: float) -> String:
	if rep >= 85.0:
		return "INTERNATIONAL"
	if rep >= 68.0:
		return "ETABLIERT"
	if rep >= 48.0:
		return "BEKANNT"
	if rep >= 28.0:
		return "LOKAL"
	return "UNBEKANNT"

## Sternewertung fuer den Night Report.
static func night_rating(stats: Dictionary) -> int:
	var decisions := int(stats["correct"]) + int(stats["mistakes"])
	var accuracy := float(stats["correct"]) / float(decisions) if decisions > 0 else 0.5
	var arrived := int(stats["arrived"])
	var flow := 1.0 - float(stats["left"]) / float(maxi(1, arrived)) if arrived > 0 else 1.0
	var incident_penalty := minf(0.4, int(stats["incidents"]) * 0.06)
	var score := accuracy * 0.6 + flow * 0.4 - incident_penalty
	return int(clampf(round(score * 5.0), 0.0, 5.0))
