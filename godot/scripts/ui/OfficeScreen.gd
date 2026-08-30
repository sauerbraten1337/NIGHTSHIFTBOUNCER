## Buero des Clubleiters - der Tag zwischen zwei Naechten.
##
## Drei Stellen sind anklickbar: der Kleiderschrank (Aussehen aendern), der
## Laptop (Upgrades kaufen) und die Tuer (naechste Nacht). Die Felder liegen
## als Anteilsrechtecke genau ueber dem, was render/Office.gd zeichnet.
##
## Portierung von src/ui/office.js. Heisst OfficeScreen, weil Office bereits
## das Zeichenmodul ist.
class_name OfficeScreen
extends RefCounted

## opts: { onWardrobe, onLaptop, onDoor, onMenu }
static func build(game: Node, opts: Dictionary) -> Control:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var character := CharacterSys.normalize_character(state["character"])
	var tier := GameState.club_tier(state)

	var wrap := Control.new()
	wrap.custom_minimum_size = Office.OFFICE_WORLD
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scene := SceneNode.new(character)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(scene)

	# Kopfzeile
	var head := VBoxContainer.new()
	head.position = Vector2(40, 32)
	head.add_theme_constant_override("separation", 2)
	head.add_child(UiTheme.label("TAG %s · BÜRO DES CLUBLEITERS" % str(
		int(state["nightIndex"]) + 1
	).pad_zeros(2), 10, UiTheme.DIM, 3.0))
	head.add_child(UiTheme.label("FEIERABEND BIS ZUM ABEND", 26, UiTheme.TEXT, 4.0, true))
	head.add_child(UiTheme.label("%s · %s" % [
		character["name"], GameState.rank(state)["label"],
	], 11, UiTheme.CYAN, 2.0))
	wrap.add_child(head)

	# Kennzahlen
	var stats := VBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats.offset_left = -320
	stats.offset_top = 32
	stats.offset_right = -40
	stats.alignment = BoxContainer.ALIGNMENT_END
	stats.add_theme_constant_override("separation", 2)
	stats.add_child(_stat("GELD", "€%s" % UiTheme.money_text(float(state["money"]))))
	stats.add_child(_stat("RUF", "%d · %s" % [
		int(round(float(state["reputation"]))),
		Reputation.rep_band(float(state["reputation"])),
	]))
	stats.add_child(_stat("CLUB", "STUFE %d · %s" % [int(tier["level"]), tier["label"]]))
	stats.add_child(_stat("KAPAZITÄT", str(GameState.capacity(state))))
	wrap.add_child(stats)

	var hint := UiTheme.label("Sieh dich um: Schrank, Laptop, Tür.", 11, UiTheme.DIM, 2.0)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 40
	hint.offset_top = -50
	wrap.add_child(hint)

	# Der Stand ist gespeichert - von hier darf man jederzeit zurueck zum Titel.
	if (opts.get("onMenu", Callable()) as Callable).is_valid():
		var to_menu := UiTheme.button("HAUPTMENÜ", UiTheme.DIM, 10, 3.0)
		to_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		to_menu.offset_left = -180
		to_menu.offset_top = -56
		to_menu.offset_right = -30
		to_menu.offset_bottom = -22
		to_menu.pressed.connect(func() -> void: (opts["onMenu"] as Callable).call())
		wrap.add_child(to_menu)

	# Anklickbare Stellen
	var spots := [
		{
			"id": "wardrobe", "action": opts.get("onWardrobe", Callable()),
			"hint": "Kleiderschrank: Aussehen und Name ändern.",
		},
		{
			"id": "laptop", "action": opts.get("onLaptop", Callable()),
			"hint": "Laptop: Upgrades, Talente und Acts.",
		},
		{
			"id": "door", "action": opts.get("onDoor", Callable()),
			"hint": "Tür: raus in die nächste Nacht.",
		},
	]
	for entry: Dictionary in spots:
		var spot: Dictionary = Office.OFFICE_HOTSPOTS[entry["id"]]
		var b := Button.new()
		b.flat = true
		b.anchor_left = float(spot["x"])
		b.anchor_top = float(spot["y"])
		b.anchor_right = float(spot["x"]) + float(spot["w"])
		b.anchor_bottom = float(spot["y"]) + float(spot["h"])
		b.offset_left = 0
		b.offset_top = 0
		b.offset_right = 0
		b.offset_bottom = 0
		b.add_theme_stylebox_override("hover", UiTheme.panel_box(
			Color(1, 1, 1, 0.06), Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.6)
		))
		b.mouse_entered.connect(func() -> void: hint.text = entry["hint"])
		b.focus_entered.connect(func() -> void: hint.text = entry["hint"])
		b.pressed.connect(func() -> void:
			(g["bus"] as Bus).emit("sfx", "door" if entry["id"] == "door" else "ok")
			if (entry["action"] as Callable).is_valid():
				(entry["action"] as Callable).call()
		)

		var tag := VBoxContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.alignment = BoxContainer.ALIGNMENT_END
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tag.add_child(UiTheme.label(spot["label"], 12, UiTheme.TEXT, 2.0, true))
		tag.add_child(UiTheme.label(spot["note"], 9, UiTheme.DIM))
		b.add_child(tag)
		wrap.add_child(b)

	return wrap

static func _stat(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	row.add_child(UiTheme.label(value, 12, UiTheme.TEXT))
	return row

## Der gezeichnete Raum. Laeuft weiter, solange der Bildschirm offen ist.
class SceneNode extends Control:
	var character: Dictionary = {}
	var _t := 0.0
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(c: Dictionary) -> void:
		character = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_fx_node = FxReplay.new()
		_fx_node.list = _fx
		add_child(_fx_node)

	func _process(delta: float) -> void:
		_t += minf(0.05, delta)
		queue_redraw()
		if _fx_node != null:
			_fx_node.queue_redraw()

	func _draw() -> void:
		_fx.clear()
		Office.draw_office(self, _fx, size.x, size.y, _t, character)
