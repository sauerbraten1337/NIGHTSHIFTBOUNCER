## Gespraech und Alkoholtest.
##
## Das Testgeraet zeigt nur eine Zahl. Ob die noch in Ordnung ist, liest der
## Spieler am aufgedruckten Grenzwert ab - und ein niedriger Promillewert
## heisst nicht, dass jemand niechtern ist: dafuer gibt es die sichtbaren
## Anzeichen.
##
## Portierung von src/systems/alcohol.js.
class_name Alcohol
extends RefCounted

## ANSPRECHEN. Beim ersten Mal nennt der Gast seinen Namen, danach ruecken
## seine Aussagen nach - eine pro Ansprache. `previous` ist das, was er in
## dieser Kontrolle schon gesagt hat.
static func talk_to(rng: Rng, state: Dictionary, guest: Dictionary, previous: Variant = null) -> Dictionary:
	# Der Gast nennt zuerst seinen Namen und redet dann weiter - der Name ist
	# das, was der Spieler mit dem Ausweis abgleichen muss.
	var real_name: String = guest["name"]
	var said: Array = []
	if previous != null:
		said = ((previous as Dictionary).get("said", []) as Array).duplicate()
	var statements: Array = (guest["truth"] as Dictionary).get("statements", [])
	var next: Variant = statements[said.size()] if said.size() < statements.size() else null
	if next != null:
		said.append(next)

	var follow: String = next["text"] if next != null else Guests.guest_line(rng, guest, "talk")
	var line: String
	if said.size() <= 1:
		line = "%s %s" % [Guests.guest_name_line(rng, guest), follow]
	else:
		line = follow

	var drunk := float((guest["truth"] as Dictionary)["drunk"])
	var impaired := float((guest["truth"] as Dictionary).get("impaired", 0.0))

	var hint := "spricht klar"
	if drunk > 0.8:
		hint = "spricht sehr undeutlich"
	elif drunk > 0.6:
		hint = "redet verwaschen"
	elif drunk > 0.35:
		hint = "wirkt angetrunken"

	# Substanzeinfluss klingt anders als Alkohol.
	var state_hint: Variant = null
	if impaired > 0.7:
		state_hint = "redet auffällig schnell und sprunghaft"
	elif impaired > 0.45:
		state_hint = "antwortet verzögert, wirkt abwesend"

	var mood_hint := "entspannt"
	match guest["personality"]:
		"aggressive": mood_hint = "sehr gereizt"
		"arrogant": mood_hint = "fordernd"
		"nervous": mood_hint = "nervös"

	return {
		"line": line,
		"realName": real_name,
		"hint": hint,
		"stateHint": state_hint,
		"moodHint": mood_hint,
		"drunkGuess": drunk,
		# Alles, was er in dieser Kontrolle bisher behauptet hat.
		"said": said,
		# Sind noch Aussagen offen? Dann lohnt sich nachfragen.
		"moreToSay": said.size() < statements.size(),
	}

## Alkoholtest: liefert die Anzeige des Geraets.
## Bewusst ohne Urteil - der Grenzwert steht auf dem Geraet.
static func alcohol_test(state: Dictionary, guest: Dictionary) -> Dictionary:
	var value := float((guest["truth"] as Dictionary)["drunk"])
	var promille := snappedf(value * 2.4, 0.1)

	return {
		"value": value,
		"promille": promille,
		"limit": Config.ALCOHOL_LIMIT_PROMILLE,
		"overLimit": value >= float(Config.TUNING["drunkRejectThreshold"]),
		"text": "%.1f ‰" % promille,
	}

## Welche Anzeichen sind an diesem Gast sichtbar?
static func visible_impairment(guest: Dictionary) -> Array[Dictionary]:
	var ids: Array = (guest["truth"] as Dictionary).get("impairmentSigns", [])
	var out: Array[Dictionary] = []
	for s: Dictionary in Config.IMPAIRMENT_SIGNS:
		if ids.has(s["id"]):
			out.append(s)
	return out

static func impairment_labels(guest: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in visible_impairment(guest):
		out.append(s["label"])
	return out
