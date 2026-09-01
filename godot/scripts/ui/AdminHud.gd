## Roentgenblick (nur mit Admin-Code): blendet die versteckte Wahrheit des
## Gastes ein, der gerade an der Kontrolle steht.
##
## Nur zum Testen - im normalen Spiel ist genau das die Aufgabe, die man sich
## selbst erarbeiten muss. Damit man das Fenster nie mit dem Spiel verwechselt,
## traegt es durchgehend Violett: Kopfleiste, Rahmen und Eckwinkel.
##
## Jede Zeile faerbt sich nach dem, was sie meldet: was zum Abweisen fuehrt,
## steht in Rot, was in Ordnung ist, bleibt gedaempft. Lange Werte werden
## umgebrochen statt aus dem Kasten zu laufen.
##
## Portierung von src/ui/adminhud.js.
class_name AdminHud
extends PanelContainer

const WIDTH := 320.0
## Breite der Beschriftungsspalte - der Rest gehoert dem Wert.
const KEY_WIDTH := 104.0

var game: Node = null
var _body: VBoxContainer = null

func _init(game_node: Node) -> void:
	game = game_node
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := UiTheme.panel_box(
		Color(6.0 / 255.0, 4.0 / 255.0, 12.0 / 255.0, 0.94), UiTheme.PURPLE, 3
	)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	add_theme_stylebox_override("panel", box)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	add_child(_body)
	add_child(UiTheme.Brackets.new(UiTheme.PURPLE, 12.0))
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

	_body.add_child(_title_bar(
		"RÖNTGENBLICK",
		"NACHT %s · %d/%d" % [
			str(state["nightIndex"]).pad_zeros(2),
			int(night["processed"]), int(night["quota"]),
		]
	))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.add_child(inner)
	_body.add_child(pad)

	var stations: Dictionary = night["stations"]
	var any := false
	for key: String in stations:
		var s: Dictionary = stations[key]
		if s["guest"] == null:
			continue
		any = true
		inner.add_child(_station_card(s))
	if not any:
		inner.add_child(UiTheme.label("Niemand an der Kontrolle.", 10, UiTheme.DIM))

	# Fusszeile: welche Cheats gerade laufen - sonst sucht man den Fehler im Spiel.
	var flags: PackedStringArray = []
	if Admin.get_cheat("noAggro"):
		flags.append("KEINE ÜBERGRIFFE")
	if Admin.get_cheat("fastActions"):
		flags.append("SOFORT FERTIG")
	inner.add_child(UiTheme.separator(Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.25)))
	inner.add_child(UiTheme.label(
		" · ".join(flags) if flags.size() > 0 else "NUR ANZEIGE — KEINE EINGRIFFE",
		8, Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.8), 2.0
	))

## Kopfleiste in Violett - sie traegt den Namen des Werkzeugs und den Stand
## der Nacht.
func _title_bar(title: String, note: String) -> Control:
	var bar := PanelContainer.new()
	var style := UiTheme.panel_box(
		Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.22),
		Color(0, 0, 0, 0)
	)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.color = UiTheme.PURPLE
	dot.custom_minimum_size = Vector2(3, 11)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var t := UiTheme.label(title, 10, UiTheme.PURPLE, 3.0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UiTheme.label(note, 9, UiTheme.DIM, 1.0))
	bar.add_child(row)
	return bar

func _station_card(station: Dictionary) -> Control:
	var guest: Dictionary = station["guest"]
	var t: Dictionary = guest["truth"]
	var door: bool = station["id"] != "airlock"
	var accent := UiTheme.RED if door else UiTheme.CYAN

	var card := UiTheme.card(accent, Color(1, 1, 1, 0.03))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var where := UiTheme.label("TÜR" if door else "SCHLEUSE", 10, accent, 3.0)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(where)
	head.add_child(UiTheme.label(String(guest["name"]).to_upper(), 10, UiTheme.TEXT, 1.0))
	col.add_child(head)

	# Die Marken oben: alles, was diesen Gast sofort auffaellig macht.
	var flags := HFlowContainer.new()
	flags.add_theme_constant_override("h_separation", 4)
	flags.add_theme_constant_override("v_separation", 4)
	if bool(t["underage"]):
		flags.add_child(_flag("MINDERJÄHRIG", UiTheme.RED))
	if not bool(t["idValid"]):
		flags.add_child(_flag("AUSWEIS FALSCH", UiTheme.RED))
	if t["contraband"] != null:
		flags.add_child(_flag("VERBOTENES", UiTheme.RED))
	if bool(t["blacklisted"]):
		flags.add_child(_flag("GESPERRT", UiTheme.RED))
	if bool(t["vip"]):
		flags.add_child(_flag("VIP", UiTheme.AMBER))
	if flags.get_child_count() == 0:
		flags.add_child(_flag("SAUBER", UiTheme.GREEN))
	col.add_child(flags)

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

	var age := int(t["age"])
	col.add_child(_row("ALTER", str(age), UiTheme.RED if bool(t["underage"]) else UiTheme.TEXT))
	col.add_child(_row("AUSWEIS", id_state, UiTheme.RED if not bool(t["idValid"]) else UiTheme.DIM))
	col.add_child(_row(
		"VERBOTENES", contraband,
		UiTheme.RED if t["contraband"] != null else UiTheme.DIM
	))
	col.add_child(_meter_row("PROMILLE", "%.1f ‰" % (float(t["drunk"]) * 2.4), float(t["drunk"])))
	if float(t["impaired"]) > 0.0:
		col.add_child(_meter_row(
			"SUBSTANZ", "%d %%" % int(round(float(t["impaired"]) * 100.0)),
			float(t["impaired"])
		))
	var risk := Aggression.aggression_risk(guest)
	col.add_child(_meter_row("AUSRASTRISIKO", "%d %%" % int(round(risk * 100.0)), risk))

	card.add_child(col)
	return card

## Eine Zeile: Beschriftung links in fester Breite, Wert rechts mit Umbruch.
func _row(key: String, value: String, color: Color = UiTheme.TEXT) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := UiTheme.label(key, 8, UiTheme.DIM, 1.0)
	k.custom_minimum_size = Vector2(KEY_WIDTH, 0)
	row.add_child(k)
	var v := UiTheme.body_label(value, 10, color)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row

## Eine Zeile mit Balken: Werte von 0 bis 1 sieht man so schneller als Zahlen.
func _meter_row(key: String, value: String, ratio: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := UiTheme.label(key, 8, UiTheme.DIM, 1.0)
	k.custom_minimum_size = Vector2(KEY_WIDTH, 0)
	row.add_child(k)
	row.add_child(UiTheme.spacer())
	var level := clampf(ratio, 0.0, 1.0)
	var color := UiTheme.GREEN if level < 0.34 else (UiTheme.AMBER if level < 0.67 else UiTheme.RED)
	row.add_child(UiTheme.label(value, 10, color))
	col.add_child(row)
	var meter := UiTheme.meter(0.0, 3.0)
	meter.fill_color = color
	meter.set_value(level)
	col.add_child(meter)
	return col

## Kleine Marke fuer einen Befund.
func _flag(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var style := UiTheme.panel_box(
		Color(color.r, color.g, color.b, 0.16), Color(color.r, color.g, color.b, 0.6), 2
	)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", style)
	p.add_child(UiTheme.label(text, 8, color, 1.0))
	return p

static func _zone_name(id: Variant) -> String:
	match id:
		"jacket": return "Jacke"
		"pockets": return "Hosentaschen"
		"bag": return "Tasche"
	return String(id) if id != null else "—"
