## Charaktereditor: der eigene Tuersteher.
##
## Links die Figur in der Umkleide, rechts die Regler. Alles steht auf einer
## Seite - die Regler liegen in zwei Spalten nebeneinander, damit nichts mehr
## unter den Bildrand rutscht und niemand scrollen muss.
##
## Jede Aenderung ist sofort an der Figur zu sehen - deshalb laeuft hier eine
## eigene kleine Zeichenschleife, die stoppt, sobald der Bildschirm weg ist.
##
## Portierung von src/ui/character.js.
class_name CharacterEditor
extends RefCounted

## Masse des Bildschirms. Der Rahmen von Screens ist im breiten Zustand
## 1120 x 660 mit 40 Pixel Rand - alles hier muss in 1040 x 580 passen.
const STAGE_SIZE := Vector2(372, 402)
const SWATCH_SIZE := Vector2(30, 28)

## opts: { title, subtitle, confirmLabel, onBack, backLabel }
static func build(game: Node, on_done: Callable, opts: Dictionary = {}) -> Control:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	# Der Entwurf wird direkt bearbeitet und erst beim Bestaetigen uebernommen.
	var draft := CharacterSys.normalize_character(state["character"])

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 12)

	# ---- Kopfzeile ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var head_left := VBoxContainer.new()
	head_left.add_theme_constant_override("separation", 1)
	head_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_left.add_child(UiTheme.label(
		opts.get("title", "DEIN TÜRSTEHER"), 24, UiTheme.TEXT, 4.0, true
	))
	head_left.add_child(UiTheme.label(
		opts.get("subtitle", "WER STEHT HEUTE NACHT AN DER TÜR?"), 10, UiTheme.CYAN, 3.0
	))
	head.add_child(head_left)
	var stamp := VBoxContainer.new()
	stamp.alignment = BoxContainer.ALIGNMENT_END
	stamp.add_theme_constant_override("separation", 1)
	var stamp_top := UiTheme.label("PERSONALAKTE", 9, UiTheme.DIM, 4.0)
	stamp_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.add_child(stamp_top)
	var stamp_id := UiTheme.label(
		"NW-%s" % str(abs(int(state["nightIndex"])) * 17 + 4021).pad_zeros(4),
		12, UiTheme.RED, 3.0
	)
	stamp_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.add_child(stamp_id)
	head.add_child(stamp)
	wrap.add_child(head)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)

	# ---- Buehne ----
	var stage_col := VBoxContainer.new()
	stage_col.add_theme_constant_override("separation", 8)
	var stage := StageNode.new(draft)
	stage_col.add_child(stage)

	var plate := UiTheme.card(UiTheme.CYAN)
	var plate_row := HBoxContainer.new()
	plate_row.add_theme_constant_override("separation", 10)
	var plate_col := VBoxContainer.new()
	plate_col.add_theme_constant_override("separation", 0)
	plate_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plate_name := UiTheme.label(draft["name"], 15, UiTheme.TEXT, 3.0, true)
	plate_col.add_child(plate_name)
	plate_col.add_child(UiTheme.label("TÜRSTEHER · NULLWERK", 9, UiTheme.DIM, 3.0))
	plate_row.add_child(plate_col)
	var plate_build := UiTheme.label("", 9, UiTheme.CYAN, 2.0)
	plate_build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate_row.add_child(plate_build)
	plate.add_child(plate_row)
	stage_col.add_child(plate)
	body.add_child(stage_col)
	stage.plate = plate_name
	stage.plate_build = plate_build

	# ---- Regler ----
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	body.add_child(controls)
	wrap.add_child(body)

	# Name steht ueber den beiden Spalten - er ist das einzige Feld zum Tippen.
	var name_card := UiTheme.card(UiTheme.RED)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	var name_key := UiTheme.label("NAME", 9, UiTheme.DIM, 3.0)
	name_key.custom_minimum_size = Vector2(78, 0)
	name_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_key)
	var name_input := LineEdit.new()
	name_input.max_length = 14
	name_input.text = draft["name"]
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_override("font", Fonts.spaced(Fonts.mono(), 2.0))
	name_input.add_theme_font_size_override("font_size", 14)
	name_input.add_theme_stylebox_override("normal", UiTheme.panel_box(
		Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.10)
	))
	name_input.add_theme_stylebox_override("focus", UiTheme.panel_box(
		Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.08), UiTheme.CYAN
	))
	name_input.text_changed.connect(func(text: String) -> void:
		draft["name"] = text.to_upper()
		name_input.text = draft["name"]
		name_input.caret_column = name_input.text.length()
		plate_name.text = draft["name"] if not draft["name"].is_empty() else "—"
	)
	name_row.add_child(name_input)
	name_card.add_child(name_row)
	controls.add_child(name_card)

	# Zwei Spalten - so passen alle sieben Gruppen neben die Figur.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(grid)

	var rebuild_groups := func() -> void:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()

		var skin_entries: Array[Dictionary] = []
		for i in Palette.SKIN.size():
			skin_entries.append({"value": i, "color": Palette.SKIN[i], "label": ""})
		grid.add_child(_swatch_group(game, 1, "HAUTTON", "skin", skin_entries, draft, stage))

		var hair_entries: Array[Dictionary] = []
		for i in Palette.HAIR.size():
			hair_entries.append({"value": i, "color": Palette.HAIR[i], "label": ""})
		grid.add_child(_swatch_group(game, 2, "HAARFARBE", "hair", hair_entries, draft, stage))

		var style_entries: Array[Dictionary] = []
		for s: Dictionary in CharacterSys.HAIR_STYLES:
			style_entries.append({"value": s["id"], "label": s["label"]})
		grid.add_child(_chip_group(game, 3, "FRISUR", "hairStyle", style_entries, draft, stage))

		var outfit_entries: Array[Dictionary] = []
		for i in Palette.OUTFIT.size():
			outfit_entries.append({"value": i, "color": Palette.OUTFIT[i], "label": ""})
		grid.add_child(_swatch_group(game, 4, "JACKE", "outfit", outfit_entries, draft, stage))

		var build_entries: Array[Dictionary] = []
		for b: Dictionary in CharacterSys.BUILDS:
			build_entries.append({"value": b["id"], "label": b["label"]})
		grid.add_child(_chip_group(game, 5, "STATUR", "build", build_entries, draft, stage))

		grid.add_child(_chip_group(game, 6, "BART", "beard", [
			{"value": "no", "label": "OHNE"}, {"value": "yes", "label": "MIT"},
		], draft, stage))

		var accent_entries: Array[Dictionary] = []
		for a: Dictionary in CharacterSys.ACCENTS:
			accent_entries.append({
				"value": a["id"], "label": a["label"],
				"color": Color(a["color"]) if not String(a["color"]).is_empty() else null,
			})
		grid.add_child(_swatch_group(
			game, 7, "STREIFEN", "accent", accent_entries, draft, stage
		))

		# Der siebte Kasten laesst ein Feld frei - dort steht der Hinweis, dass
		# nichts davon endgueltig ist.
		var note := UiTheme.card(UiTheme.DIM)
		var note_col := VBoxContainer.new()
		note_col.add_theme_constant_override("separation", 2)
		note_col.add_child(UiTheme.label("HINWEIS", 9, UiTheme.DIM, 3.0))
		note_col.add_child(UiTheme.body_label(
			"Am Kleiderschrank im Büro lässt sich alles vor jeder Schicht wieder ändern.",
			10, UiTheme.DIM
		))
		note.add_child(note_col)
		grid.add_child(note)
	rebuild_groups.call()

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

	var dice := UiTheme.button("WÜRFELN", UiTheme.AMBER, 12, 3.0)
	dice.pressed.connect(func() -> void:
		var fresh := CharacterSys.create_character()
		for key: String in fresh:
			if key != "name" and key != "created":
				draft[key] = fresh[key]
		rebuild_groups.call()
		stage.set("draft", draft)
		((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
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

## Kopfzeile einer Gruppe: laufende Nummer, Name, rechts der gewaehlte Wert.
static func _group_head(index: int, label: String, value: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.add_child(UiTheme.label(str(index).pad_zeros(2), 9, Color(1, 1, 1, 0.20), 1.0))
	var name := UiTheme.label(label, 9, UiTheme.DIM, 3.0)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(value)
	return row

## Jede Gruppe steht in einer eigenen Karte mit cyanfarbener Kante - sonst
## laufen sieben Reihen Knoepfe zu einer Wand zusammen.
static func _group_card(index: int, label: String, value: Label, row: Control) -> Control:
	var card := UiTheme.card(UiTheme.CYAN)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.add_child(_group_head(index, label, value))
	col.add_child(row)
	card.add_child(col)
	return card

static func _swatch_group(
	game: Node, index: int, label: String, key: String, entries: Array[Dictionary],
	draft: Dictionary, stage: Control
) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	var value := UiTheme.label("", 9, UiTheme.CYAN, 2.0)

	var buttons: Array[Button] = []
	for e: Dictionary in entries:
		var b := Button.new()
		b.custom_minimum_size = SWATCH_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = e.get("label", "")
		var color: Variant = e.get("color", null)
		if color == null:
			b.text = "✕"
			b.add_theme_font_size_override("font_size", 11)
			b.add_theme_color_override("font_color", UiTheme.DIM)
		buttons.append(b)
		row.add_child(b)

	var paint := func(selected: int) -> void:
		for j in entries.size():
			var e: Dictionary = entries[j]
			var c: Variant = e.get("color", null)
			var fill: Color = c if c != null else Color(1, 1, 1, 0.04)
			var on := j == selected
			buttons[j].add_theme_stylebox_override("normal", UiTheme.panel_box(
				fill, Color(1, 1, 1, 0.95) if on else Color(1, 1, 1, 0.12), 3, 2 if on else 1
			))
			buttons[j].add_theme_stylebox_override("hover", UiTheme.panel_box(
				fill, Color(1, 1, 1, 0.95) if on else UiTheme.CYAN, 3, 2 if on else 1
			))
			buttons[j].add_theme_stylebox_override("pressed", UiTheme.panel_box(
				fill, Color(1, 1, 1, 0.95), 3, 2
			))
		if selected >= 0:
			var text := String(entries[selected].get("label", ""))
			value.text = text.to_upper() if not text.is_empty() \
				else "%02d/%02d" % [selected + 1, entries.size()]

	var current := -1
	for i in entries.size():
		if str(entries[i]["value"]) == str(draft[key]):
			current = i
	paint.call(current)

	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].pressed.connect(func() -> void:
			_apply(draft, key, e["value"])
			paint.call(i)
			stage.set("draft", draft)
			((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
		)

	return _group_card(index, label, value, row)

static func _chip_group(
	game: Node, index: int, label: String, key: String, entries: Array[Dictionary],
	draft: Dictionary, stage: Control
) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	var value := UiTheme.label("", 9, UiTheme.CYAN, 2.0)

	var current := str(draft[key])
	if key == "beard":
		current = "yes" if bool(draft["beard"]) else "no"

	var buttons: Array[Button] = []
	for e: Dictionary in entries:
		var b := UiTheme.button(e["label"], UiTheme.CYAN, 10, 1.0)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, SWATCH_SIZE.y)
		buttons.append(b)
		row.add_child(b)

	var paint := func(selected: int) -> void:
		for j in entries.size():
			var sel := j == selected
			var accent := UiTheme.CYAN if sel else UiTheme.LINE
			buttons[j].add_theme_stylebox_override("normal", UiTheme.panel_box(
				Color(accent.r, accent.g, accent.b, 0.18 if sel else 0.03),
				Color(accent.r, accent.g, accent.b, 1.0 if sel else 0.35), 3, 2 if sel else 1
			))
			buttons[j].add_theme_color_override(
				"font_color", UiTheme.CYAN if sel else UiTheme.TEXT
			)
		if selected >= 0:
			value.text = String(entries[selected]["label"]).to_upper()

	var start := -1
	for i in entries.size():
		if str(entries[i]["value"]) == current:
			start = i
	paint.call(start)

	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].pressed.connect(func() -> void:
			_apply(draft, key, e["value"])
			paint.call(i)
			stage.set("draft", draft)
			((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
		)

	return _group_card(index, label, value, row)

## Die Vorschau: Umkleide mit Raster, Podest, Scheinwerfer und Massband.
class StageNode extends Control:
	var draft: Dictionary = {}
	var plate: Label = null
	var plate_build: Label = null
	var _t := 0.0
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(d: Dictionary) -> void:
		draft = d
		custom_minimum_size = CharacterEditor.STAGE_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_fx_node = FxReplay.new()
		_fx_node.list = _fx
		add_child(_fx_node)
		# Eckwinkel darueber: macht aus der Flaeche eine Kabine.
		add_child(UiTheme.Brackets.new(UiTheme.CYAN, 20.0))

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
		if plate_build != null:
			for b: Dictionary in CharacterSys.BUILDS:
				if b["id"] == draft["build"]:
					plate_build.text = String(b["label"]).to_upper()

		Draw2D.vgradient_rect(self, Rect2(0, 0, w, h), Color("0b0e15"), Color("05070b"))

		# Scheinwerfer von oben auf das Podest
		Effects.glow(_fx, w * 0.5, h * 0.92, h * 0.9, Palette.CYAN, 0.16)

		# Umkleide-Raster im Hintergrund
		var grid := Palette.with_alpha(Palette.LINE, 0.35)
		var gx := 20.5
		while gx < w:
			draw_line(Vector2(gx, 0), Vector2(gx, h * 0.86), grid, 1.0, true)
			gx += 34.0
		var gy := 20.5
		while gy < h * 0.86:
			draw_line(Vector2(0, gy), Vector2(w, gy), grid, 1.0, true)
			gy += 34.0

		# Messstreifen, der langsam von unten nach oben wandert - der Blick des
		# Ausstatters, der die Figur von Kopf bis Fuss durchgeht.
		var scan := fmod(_t * 0.22, 1.0)
		var scan_y := h * 0.9 - scan * h * 0.82
		Draw2D.vgradient_rect(
			self, Rect2(0, scan_y - 26.0, w, 26.0),
			Palette.with_alpha(Palette.CYAN, 0.0), Palette.with_alpha(Palette.CYAN, 0.10)
		)
		draw_line(
			Vector2(0, scan_y), Vector2(w, scan_y),
			Palette.with_alpha(Palette.CYAN, 0.35), 1.0, true
		)

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
