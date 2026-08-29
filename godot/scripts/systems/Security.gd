## Security System: koerperliche Kontrolle.
##
## Ablauf, bewusst abstrakt und ohne Gewaltdarstellung:
##   1. Abtasten starten - die Zonen werden markiert (Jacke, Hosentaschen, Tasche)
##   2. Eine Zone waehlen -> der Gast leert sie aus (bei der Tasche holt er sie
##      erst hervor), die Sachen kommen gross auf den Tisch
##   3. Der Spieler markiert selbst, was nicht in den Club darf, und schliesst
##      die Zone ab. Das Spiel sagt nicht, ob er richtig lag - zwischen
##      Kaugummi und Klinge liegt sein Auge.
##
## Portierung von src/systems/security.js.
class_name Security
extends RefCounted

static func zone_ids() -> Array[String]:
	var out: Array[String] = []
	for z: Dictionary in Config.ZONES:
		out.append(z["id"])
	return out

static func zones_for(guest: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var guest_zones: Array = (guest["truth"] as Dictionary)["zoneIds"]
	for z: Dictionary in Config.ZONES:
		if guest_zones.has(z["id"]):
			out.append(z)
	return out

static func start_patdown(state: Dictionary, guest: Dictionary) -> Dictionary:
	var zones := {}
	for zone: Dictionary in zones_for(guest):
		zones[zone["id"]] = {
			"id": zone["id"],
			"label": zone["label"],
			"state": "closed",  # closed | open | done
			"openTimer": 0.0,
			"items": null,      # erst beim Oeffnen sichtbar
			"flagged": [],      # vom Spieler beanstandete Gegenstaende (Item-Ids)
			"picked": null,     # erster beanstandeter Gegenstand, fuer die Anzeige
		}

	return {
		"guestId": guest["id"],
		"zones": zones,
		"order": zones.keys(),
		"active": null,   # aktuell geoeffnete Zone
		"complete": false,
		"bagOut": false,  # die Tasche ist hervorgeholt
	}

## Zone oeffnen: der Gast holt heraus, was drin ist.
static func open_zone(patdown: Variant, guest: Dictionary, zone_id: String) -> Variant:
	if patdown == null:
		return null
	var zone: Variant = (patdown["zones"] as Dictionary).get(zone_id, null)
	if zone == null or zone["state"] == "done":
		return null
	var carried: Array = (guest["truth"] as Dictionary)["carried"].get(zone_id, [])
	zone["items"] = carried.duplicate()
	zone["state"] = "open"
	patdown["active"] = zone_id
	if zone_id == "bag":
		patdown["bagOut"] = true
	return zone

## Der Spieler markiert einen Gegenstand als nicht regelkonform - oder nimmt
## die Markierung wieder zurueck. Es gibt keine Rueckmeldung, ob er richtig lag.
## item_id = "" schliesst die Zone ab (siehe close_zone).
static func pick_item(patdown: Variant, guest: Dictionary, zone_id: String, item_id: String) -> Variant:
	if patdown == null:
		return null
	var zone: Variant = (patdown["zones"] as Dictionary).get(zone_id, null)
	if zone == null or zone["state"] != "open":
		return null
	if item_id.is_empty():
		return close_zone(patdown, zone_id)

	var items: Array = zone["items"] if zone["items"] != null else []
	var item: Variant = null
	for i: Dictionary in items:
		if i["id"] == item_id:
			item = i
			break
	if item == null:
		return null

	var flagged: Array = zone["flagged"]
	var at := flagged.find(item["id"])
	if at >= 0:
		flagged.remove_at(at)
	else:
		flagged.append(item["id"])

	zone["picked"] = null
	if not flagged.is_empty():
		for i: Dictionary in items:
			if i["id"] == flagged[0]:
				zone["picked"] = i
				break

	return {"zone": zone_id, "item": item, "flagged": at < 0, "flaggedIds": flagged.duplicate()}

## Zone abschliessen - mit oder ohne Beanstandung.
static func close_zone(patdown: Variant, zone_id: String) -> Variant:
	if patdown == null:
		return null
	var zones: Dictionary = patdown["zones"]
	var zone: Variant = zones.get(zone_id, null)
	if zone == null or zone["state"] != "open":
		return null
	zone["state"] = "done"
	patdown["active"] = null
	var all_done := true
	for key: String in zones:
		if zones[key]["state"] != "done":
			all_done = false
			break
	patdown["complete"] = all_done
	return {"zone": zone_id, "closed": true, "flaggedIds": (zone["flagged"] as Array).duplicate()}

## Alle vom Spieler beanstandeten Gegenstaende.
static func flagged_items(patdown: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if patdown == null:
		return out
	var zones: Dictionary = patdown["zones"]
	for key: String in zones:
		var zone: Dictionary = zones[key]
		var items: Array = zone["items"] if zone["items"] != null else []
		for id: Variant in (zone["flagged"] as Array):
			for i: Dictionary in items:
				if i["id"] == id:
					out.append({"zone": zone["id"], "item": i})
					break
	return out

## Auswertung NACH der Entscheidung: Treffer, Fehlgriffe, Uebersehenes.
static func score_patdown(patdown: Variant, guest: Dictionary) -> Dictionary:
	var flagged := flagged_items(patdown)
	var hits: Array[Dictionary] = []
	var wrong: Array[Dictionary] = []
	var seen_ids := {}
	for f: Dictionary in flagged:
		seen_ids[(f["item"] as Dictionary)["id"]] = true
		if bool((f["item"] as Dictionary)["forbidden"]):
			hits.append(f)
		else:
			wrong.append(f)

	var missed: Array[Dictionary] = []
	if patdown != null:
		var zones: Dictionary = patdown["zones"]
		for key: String in zones:
			var zone: Dictionary = zones[key]
			if zone["state"] != "done":
				continue
			var items: Array = zone["items"] if zone["items"] != null else []
			for item: Dictionary in items:
				if bool(item["forbidden"]) and not seen_ids.has(item["id"]):
					missed.append({"zone": zone["id"], "item": item})
	return {"hits": hits, "wrong": wrong, "missed": missed}

## Zusammenfassung fuer den Notizzettel (nur die Angaben des Spielers).
static func patdown_result(patdown: Variant) -> Variant:
	if patdown == null:
		return null
	var zones: Dictionary = patdown["zones"]
	var done := 0
	for key: String in zones:
		if zones[key]["state"] == "done":
			done += 1
	var flagged := flagged_items(patdown)
	var complete := bool(patdown["complete"])

	var text: String
	if not flagged.is_empty():
		var labels: PackedStringArray = []
		for f: Dictionary in flagged:
			labels.append(String((f["item"] as Dictionary)["label"]).to_upper())
		text = "BEANSTANDET: %s" % ", ".join(labels)
	elif complete:
		text = "NICHTS BEANSTANDET"
	else:
		text = "%d/%d ZONEN" % [done, zones.size()]

	return {
		"done": complete,
		"partial": done > 0 and not complete,
		"zonesChecked": done,
		"zonesTotal": zones.size(),
		"flagged": flagged,
		"text": text,
	}

## Offene Zonen fuer die Anzeige.
static func pending_zones(patdown: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if patdown == null:
		return out
	var zones: Dictionary = patdown["zones"]
	for key: String in zones:
		if zones[key]["state"] != "done":
			out.append(zones[key])
	return out

## Entscheidet, ob ein zugelassener Gast im Club einen Zwischenfall ausloest.
static func incident_chance(state: Dictionary, guest: Dictionary) -> float:
	var t: Dictionary = guest["truth"]
	var p := float(t["risk"]) * 0.35
	if float(t["drunk"]) > 0.6:
		p += 0.15
	if t["contraband"] != null:
		p += int((t["contraband"] as Dictionary)["severity"]) * 0.12
	if float(t.get("impaired", 0.0)) > 0.6:
		p += 0.18
	if bool(t["blacklisted"]):
		p += 0.25
	p -= GameState.upgrade_level(state, "team") * 0.07
	p -= GameState.upgrade_level(state, "cameras") * 0.05
	return maxf(0.0, minf(0.95, p))
