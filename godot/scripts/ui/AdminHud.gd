## Roentgenblick (nur mit Admin-Code): blendet die versteckte Wahrheit des
## Gastes ein, der gerade an der Kontrolle steht.
##
## Nur zum Testen - im normalen Spiel ist genau das die Aufgabe, die man sich
## selbst erarbeiten muss.
##
## Portierung von src/ui/adminhud.js.
class_name AdminHud
extends PanelContainer

var game: Node = null
var _body: VBoxContainer = null

func _init(game_node: Node) -> void:
	game = game_node
	custom_minimum_size = Vector2(280, 0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.9), UiTheme.PURPLE
	))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	add_child(_body)
	visible = false

func update_admin() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var on: bool = Admin.unlocked and Admin.reveal \
		and state["phase"] == "night" and state["night"] != null
	visible = on
	if not on:
		return

	var night: Dictionary = state["night"]
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	_body.add_child(UiTheme.label("RÖNTGENBLICK · NACHT %s · %d/%d" % [
		str(state["nightIndex"]).pad_zeros(2), int(night["processed"]), int(night["quota"]),
	], 9, UiTheme.PURPLE, 2.0))

	var stations: Dictionary = night["stations"]
	var any := false
	for key: String in stations:
		var s: Dictionary = stations[key]
		if s["guest"] == null:
			continue
		any = true
		_add_station(s)
	if not any:
		_body.add_child(UiTheme.label("Niemand an der Kontrolle.", 10, UiTheme.DIM))

func _add_station(station: Dictionary) -> void:
	var guest: Dictionary = station["guest"]
	var t: Dictionary = guest["truth"]

	_body.add_child(UiTheme.label(
		"SCHLEUSE" if station["id"] == "airlock" else "TÜR", 10, UiTheme.CYAN, 3.0
	))

	var id_state := "in Ordnung"
	if not bool(t["idValid"]):
		var labels: PackedStringArray = []
		for issue: String in (t["idIssues"] as Array):
			labels.append(Identity.issue_label(issue))
		id_state = ", ".join(labels)

	var contraband := "—"
	if t["contraband"] != null:
		contraband = "%s (%s)" % [
			(t["contraband"] as Dictionary)["label"], _zone_name(t["contrabandZone"]),
		]

	var rows := [
		["NAME", guest["name"]],
		["ALTER", "%d%s" % [int(t["age"]), " — MINDERJÄHRIG" if bool(t["underage"]) else ""]],
		["AUSWEIS", id_state],
		["PROMILLE", "%.1f ‰" % (float(t["drunk"]) * 2.4)],
		["SUBSTANZ", "%d %%" % int(round(float(t["impaired"]) * 100.0)) \
			if float(t["impaired"]) > 0.0 else "—"],
		["VERBOTENES", contraband],
		["LISTE", "GESPERRT" if bool(t["blacklisted"]) else "—"],
		["VIP", "ja" if bool(t["vip"]) else "—"],
		["AUSRASTRISIKO", "%d %%" % int(round(Aggression.aggression_risk(guest) * 100.0))],
	]
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_child(UiTheme.label(row[0], 9, UiTheme.DIM, 1.0))
		line.add_child(UiTheme.spacer())
		line.add_child(UiTheme.label(String(row[1]), 10, UiTheme.TEXT))
		_body.add_child(line)

static func _zone_name(id: Variant) -> String:
	match id:
		"jacket": return "Jacke"
		"pockets": return "Hosentaschen"
		"bag": return "Tasche"
	return String(id) if id != null else "—"
