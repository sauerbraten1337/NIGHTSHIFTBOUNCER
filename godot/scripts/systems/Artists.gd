## Artist System: fiktive Acts buchen, Gage zahlen - und der Running Gag:
## auch der Headliner muss durch die Kontrolle.
##
## Portierung von src/systems/artists.js.
class_name Artists
extends RefCounted

## Welche Acts sind bei aktuellem Ruf/Backstage buchbar?
static func available_artists(state: Dictionary) -> Array[Dictionary]:
	var backstage := GameState.upgrade_level(state, "backstage")
	var out: Array[Dictionary] = []
	if backstage < 1:
		return out
	var max_pop := 7 if backstage >= 2 else 4
	var rep_gate := float(state["reputation"]) / 100.0 * 7.0 + 1.5
	for a: Dictionary in Config.ARTISTS:
		if int(a["pop"]) <= max_pop and float(a["pop"]) <= rep_gate:
			out.append(a)
	return out

static func book_artist(state: Dictionary, artist_id: String) -> Dictionary:
	var artist: Variant = null
	for a: Dictionary in Config.ARTISTS:
		if a["id"] == artist_id:
			artist = a
			break
	if artist == null:
		return {"ok": false, "reason": "Act unbekannt"}
	if float(state["money"]) < float(artist["fee"]):
		return {"ok": false, "reason": "Nicht genug Geld"}
	state["bookedArtist"] = artist
	return {"ok": true, "artist": artist}

static func cancel_booking(state: Dictionary) -> void:
	state["bookedArtist"] = null

## Der Act trifft am Hintereingang ein und wird als Sondergast eingereiht.
static func arrive_artist(game: Dictionary) -> Variant:
	var state: Dictionary = game["state"]
	var rng: Rng = game["rng"]
	var night: Dictionary = state["night"]
	if night["artist"] == null or bool(night["artistArrived"]):
		return null
	var artist: Dictionary = night["artist"]

	var guest := Guests.create_guest(rng, {
		"event": night["event"],
		"reputation": float(state["reputation"]),
		"nightIndex": int(state["nightIndex"]),
		"forceArchetype": "crew",
	})
	var t: Dictionary = guest["truth"]
	var doc: Dictionary = guest["doc"]

	guest["name"] = artist["name"]
	guest["isArtist"] = true
	guest["backstage"] = true
	guest["archetypeLabel"] = "Künstler"
	guest["personality"] = "arrogant"
	t["vip"] = true
	t["spend"] = 0.0
	t["contraband"] = null
	t["contrabandZone"] = null
	t["impaired"] = 0.0
	t["impairmentSigns"] = []
	t["statements"] = []
	var carried: Dictionary = t["carried"]
	for zone: String in carried.keys():
		var kept: Array[Dictionary] = []
		for i: Dictionary in (carried[zone] as Array):
			if not bool(i["forbidden"]):
				kept.append(i)
		carried[zone] = kept
	t["underage"] = false
	t["age"] = maxi(24, int(t["age"]))
	t["idIssues"] = []
	t["idValid"] = true
	t["blacklisted"] = false
	t["drunk"] = minf(float(t["drunk"]), 0.3)
	doc["name"] = artist["name"]
	doc["age"] = t["age"]
	doc["photoMatch"] = true
	doc["marks"] = true
	guest["patience"] = 70.0
	guest["patienceMax"] = 70.0
	guest["artistBanter"] = rng.pick(Dialogue.ARTIST_LINES)

	QueueSys.insert_guest(game, guest, true)
	night["artistArrived"] = true
	night["artistGuestId"] = guest["id"]
	GameState.add_toast(night, "%s IST DA" % artist["name"], "good", 5.0)
	(game["bus"] as Bus).emit("sfx", "radio")
	return guest

## Wird aufgerufen, wenn ein Kuenstler-Gast eine Entscheidung erhaelt.
static func resolve_artist_decision(game: Dictionary, guest: Dictionary, admitted: bool) -> void:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	if not bool(guest.get("isArtist", false)):
		return
	night["artistHandled"] = true
	var artist: Dictionary = night["artist"]
	if admitted:
		var rep := 3.0 + float(artist["pop"]) * 1.2
		Reputation.change_reputation(state, rep, "Act spielt")
		night["artistPlaying"] = true
		GameState.add_toast(night, "%s SPIELT HEUTE" % artist["name"], "good", 5.0)
	else:
		Reputation.change_reputation(state, -6.0, "Act abgewiesen")
		GameState.add_toast(night, "DU HAST DEN HEADLINER ABGEWIESEN", "bad", 6.0)

## Umsatz-Multiplikator, solange der Act spielt.
static func artist_spend_bonus(night: Variant) -> float:
	if night == null or night["artist"] == null:
		return 1.0
	return float((night["artist"] as Dictionary)["spend"]) \
		if bool(night.get("artistPlaying", false)) else 1.0
