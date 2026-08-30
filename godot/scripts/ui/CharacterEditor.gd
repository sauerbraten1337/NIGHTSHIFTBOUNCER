## Charaktereditor: der eigene Tuersteher.
##
## Links die Figur in Lebensgroesse auf dem Podest, rechts die Regler.
## Jede Aenderung ist sofort an der Figur zu sehen - deshalb laeuft hier eine
## eigene kleine Zeichenschleife, die stoppt, sobald der Bildschirm weg ist.
##
## Portierung von src/ui/character.js.
class_name CharacterEditor
extends RefCounted

## opts: { title, subtitle, confirmLabel, onBack, backLabel }
static func build(game: Node, on_done: Callable, opts: Dictionary = {}) -> Control:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	# Der Entwurf wird direkt bearbeitet und erst beim Bestaetigen uebernommen.
	var draft := CharacterSys.normalize_character(state["character"])

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.add_child(UiTheme.label(
		opts.get("title", "DEIN TÜRSTEHER"), 26, UiTheme.TEXT, 4.0, true
	))
	head.add_child(UiTheme.label(
		opts.get("subtitle", "WER STEHT HEUTE NACHT AN DER TÜR?"), 11, UiTheme.CYAN, 3.0
	))
	wrap.add_child(head)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)

	# ---- Buehne ----
	var stage_col := VBoxContainer.new()
	var stage := StageNode.new(draft)
	stage_col.add_child(stage)
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", 0)
	var plate_name := UiTheme.label(draft["name"], 15, UiTheme.TEXT, 3.0, true)
	plate.add_child(plate_name)
	plate.add_child(UiTheme.label("TÜRSTEHER · NULLWERK", 9, UiTheme.DIM, 3.0))
	stage_col.add_child(plate)
	body.add_child(stage_col)
	stage.plate = plate_name

	# ---- Regler ----
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	body.add_child(controls)
	wrap.add_child(body)

	var rebuild := func() -> void: pass  # wird unten belegt
	var build_controls := func() -> void:
		for child in controls.get_children():
			controls.remove_child(child)
			child.queue_free()

		# Name
		var name_group := VBoxContainer.new()
		name_group.add_theme_constant_override("separation", 2)
		name_group.add_child(UiTheme.label("NAME", 9, UiTheme.DIM, 3.0))
		var name_input := LineEdit.new()
		name_input.max_length = 14
		name_input.text = draft["name"]
		name_input.add_theme_font_override("font", Fonts.mono())
		name_input.add_theme_font_size_override("font_size", 14)
		name_input.text_changed.connect(func(text: String) -> void:
			draft["name"] = text.to_upper()
			name_input.text = draft["name"]
			name_input.caret_column = name_input.text.length()
			plate_name.text = draft["name"] if not draft["name"].is_empty() else "—"
		)
		name_group.add_child(name_input)
		controls.add_child(name_group)

		# Farbfelder und Chips
		var skin_entries: Array[Dictionary] = []
		for i in Palette.SKIN.size():
			skin_entries.append({"value": i, "color": Palette.SKIN[i], "label": ""})
		controls.add_child(_swatch_group(
			game, "HAUTTON", "skin", skin_entries, draft, stage
		))

		var hair_entries: Array[Dictionary] = []
		for i in Palette.HAIR.size():
			hair_entries.append({"value": i, "color": Palette.HAIR[i], "label": ""})
		controls.add_child(_swatch_group(
			game, "HAARFARBE", "hair", hair_entries, draft, stage
		))

		var style_entries: Array[Dictionary] = []
		for s: Dictionary in CharacterSys.HAIR_STYLES:
			style_entries.append({"value": s["id"], "label": s["label"]})
		controls.add_child(_chip_group(
			game, "FRISUR", "hairStyle", style_entries, draft, stage
		))

		var outfit_entries: Array[Dictionary] = []
		for i in Palette.OUTFIT.size():
			outfit_entries.append({"value": i, "color": Palette.OUTFIT[i], "label": ""})
		controls.add_child(_swatch_group(
			game, "JACKE", "outfit", outfit_entries, draft, stage
		))

		var build_entries: Array[Dictionary] = []
		for b: Dictionary in CharacterSys.BUILDS:
			build_entries.append({"value": b["id"], "label": b["label"]})
		controls.add_child(_chip_group(
			game, "STATUR", "build", build_entries, draft, stage
		))

		controls.add_child(_chip_group(game, "BART", "beard", [
			{"value": "no", "label": "OHNE"}, {"value": "yes", "label": "MIT"},
		], draft, stage))

		var accent_entries: Array[Dictionary] = []
		for a: Dictionary in CharacterSys.ACCENTS:
			accent_entries.append({
				"value": a["id"], "label": a["label"],
				"color": Color(a["color"]) if not String(a["color"]).is_empty() else null,
			})
		controls.add_child(_swatch_group(
			game, "STREIFEN", "accent", accent_entries, draft, stage
		))
	build_controls.call()

	# ---- Knopfleiste ----
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var done := UiTheme.button(
		opts.get("confirmLabel", "SO SIEHT ER AUS"), UiTheme.GREEN, 12, 3.0
	)
	done.pressed.connect(func() -> void:
		var saved := draft.duplicate()
		saved["created"] = true
		saved = CharacterSys.normalize_character(saved)
		state["character"] = saved
		game.call("save")
		if on_done.is_valid():
			on_done.call()
	)
	row.add_child(done)

	var dice := UiTheme.button("WÜRFELN", UiTheme.LINE, 12, 3.0)
	dice.pressed.connect(func() -> void:
		var fresh := CharacterSys.create_character()
		for key: String in fresh:
			if key != "name" and key != "created":
				draft[key] = fresh[key]
		build_controls.call()
	)
	row.add_child(dice)

	if opts.has("onBack"):
		var back := UiTheme.button(opts.get("backLabel", "ZURÜCK"), UiTheme.LINE, 12, 3.0)
		back.pressed.connect(opts["onBack"])
		row.add_child(back)
	wrap.add_child(row)

	return wrap

static func _apply(draft: Dictionary, key: String, value: Variant) -> void:
	if key == "beard":
		draft["beard"] = value == "yes"
	elif key == "build" or key == "accent":
		draft[key] = value
	else:
		draft[key] = int(value)

## Jede Gruppe steht in einem eigenen kleinen Kasten mit cyanfarbener Kante -
## sonst laufen sieben Reihen Knoepfe zu einer Wand zusammen.
static func _framed(group: Control) -> Control:
	var panel := PanelContainer.new()
	var box := UiTheme.panel_box(Color(1, 1, 1, 0.02), UiTheme.LINE_SOFT)
	box.border_width_left = 2
	box.border_color = Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.4)
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(group)
	return panel

static func _swatch_group(
	game: Node, label: String, key: String, entries: Array[Dictionary],
	draft: Dictionary, stage: Control
) -> Control:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	group.add_child(UiTheme.label(label, 9, UiTheme.DIM, 3.0))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)

	var buttons: Array[Button] = []
	for e: Dictionary in entries:
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 24)
		b.tooltip_text = e.get("label", "")
		var color: Variant = e.get("color", null)
		var fill: Color = color if color != null else Color(1, 1, 1, 0.04)
		var on: bool = str(e["value"]) == str(draft[key])
		b.add_theme_stylebox_override("normal", UiTheme.panel_box(
			fill, Color(1, 1, 1, 0.9) if on else Color(1, 1, 1, 0.12), 2, 2 if on else 1
		))
		b.add_theme_stylebox_override("hover", UiTheme.panel_box(fill, Color(1, 1, 1, 0.6), 2))
		if color == null:
			b.text = "✕"
			b.add_theme_font_size_override("font_size", 10)
		buttons.append(b)
		row.add_child(b)

	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].pressed.connect(func() -> void:
			_apply(draft, key, e["value"])
			# Nur die Gruppe umschalten, in der geklickt wurde.
			for j in entries.size():
				var other: Dictionary = entries[j]
				var c: Variant = other.get("color", null)
				var f: Color = c if c != null else Color(1, 1, 1, 0.04)
				var sel := j == i
				buttons[j].add_theme_stylebox_override("normal", UiTheme.panel_box(
					f, Color(1, 1, 1, 0.9) if sel else Color(1, 1, 1, 0.12), 2, 2 if sel else 1
				))
			stage.set("draft", draft)
			((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
		)

	group.add_child(row)
	return _framed(group)

static func _chip_group(
	game: Node, label: String, key: String, entries: Array[Dictionary],
	draft: Dictionary, stage: Control
) -> Control:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	group.add_child(UiTheme.label(label, 9, UiTheme.DIM, 3.0))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)

	var current := str(draft[key])
	if key == "beard":
		current = "yes" if bool(draft["beard"]) else "no"

	var buttons: Array[Button] = []
	for e: Dictionary in entries:
		var on: bool = str(e["value"]) == current
		var b := UiTheme.button(e["label"], UiTheme.CYAN if on else UiTheme.LINE, 10, 1.0)
		buttons.append(b)
		row.add_child(b)

	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].pressed.connect(func() -> void:
			_apply(draft, key, e["value"])
			for j in entries.size():
				var sel := j == i
				var accent := UiTheme.CYAN if sel else UiTheme.LINE
				buttons[j].add_theme_stylebox_override("normal", UiTheme.panel_box(
					Color(accent.r, accent.g, accent.b, 0.16 if sel else 0.03),
					Color(accent.r, accent.g, accent.b, 1.0 if sel else 0.35)
				))
			stage.set("draft", draft)
			((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
		)

	group.add_child(row)
	return _framed(group)

## Die Vorschau: Umkleide mit Raster, Podest, Scheinwerfer und Massband.
class StageNode extends Control:
	var draft: Dictionary = {}
	var plate: Label = null
	var _t := 0.0
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(d: Dictionary) -> void:
		draft = d
		custom_minimum_size = Vector2(440, 560)
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
		var w := size.x
		var h := size.y
		if plate != null:
			plate.text = draft["name"] if not String(draft["name"]).is_empty() else "—"

		Draw2D.vgradient_rect(self, Rect2(0, 0, w, h), Color("0b0e15"), Color("05070b"))

		# Scheinwerfer von oben auf das Podest
		Effects.glow(_fx, w * 0.5, h * 0.92, h * 0.9, Palette.CYAN, 0.16)

		# Umkleide-Raster im Hintergrund
		var grid := Palette.with_alpha(Palette.LINE, 0.35)
		var gx := 20.5
		while gx < w:
			draw_line(Vector2(gx, 0), Vector2(gx, h * 0.86), grid, 1.0, true)
			gx += 40.0
		var gy := 20.5
		while gy < h * 0.86:
			draw_line(Vector2(0, gy), Vector2(w, gy), grid, 1.0, true)
			gy += 40.0

		# Podest
		var floor_y := h * 0.88
		Draw2D.ellipse(
			self, Vector2(w * 0.5, floor_y), Vector2(w * 0.34, h * 0.035), Color("11151d")
		)
		Draw2D.ellipse_outline(
			self, Vector2(w * 0.5, floor_y), Vector2(w * 0.34, h * 0.035),
			Palette.with_alpha(Palette.CYAN, 0.4), 2.0
		)

		Figure.draw(self, {
			"x": w * 0.5, "y": floor_y, "h": h * 0.74,
			"look": CharacterSys.character_look(draft),
			"personality": "polite", "t": _t,
			"accent": CharacterSys.accent_color(draft), "pose": "idle",
		})

		# Massband am Rand - Umkleidekabinen-Optik
		var tick := Palette.with_alpha(Palette.GREY, 0.35)
		var text_color := Palette.with_alpha(Palette.GREY, 0.5)
		for i in 9:
			var y := floor_y - (float(i) / 8.0) * h * 0.76
			var long := i % 2 == 0
			draw_line(Vector2(8, y), Vector2(26.0 if long else 18.0, y), tick, 1.0, true)
			if long:
				Draw2D.text(
					self, Fonts.mono(), Vector2(30, y + 3), str(i * 25).pad_zeros(3),
					9, text_color
				)
