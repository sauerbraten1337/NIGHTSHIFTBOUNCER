## Der Club vor der Schicht - Zwei-Drittel-Blick von oben in den Raum.
##
## Aus dem Buero geht es hier hinein: man steht im eigenen Club, sieht
## Tanzflaeche, Buehne mit DJ-Pult, Bar, Booths und Toiletten - und drueckt
## auf den Eingang, um an die Tuer zu gehen. Das startet das Bouncer-Spiel.
##
## Die Klickfelder liegen als Anteilsrechtecke genau ueber dem, was
## render/Club.gd zeichnet: Club.hotspot_rect() rechnet sie aus derselben
## Projektion aus. Aufbau wie OfficeScreen.gd.
class_name ClubScreen
extends RefCounted

## opts: { onEntrance, onOffice, onMenu }
static func build(game: Node, opts: Dictionary) -> Control:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var tier := GameState.club_tier(state)
	var levels := levels_for(state)

	var wrap := Control.new()
	wrap.custom_minimum_size = Club.CLUB_WORLD
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scene := SceneNode.new(levels)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(scene)

	# Kopfzeile
	var head := VBoxContainer.new()
	head.position = Vector2(40, 26)
	head.add_theme_constant_override("separation", 2)
	head.add_child(UiTheme.label("NACHT %s · DEIN CLUB" % str(
		int(state["nightIndex"]) + 1
	).pad_zeros(2), 10, UiTheme.DIM, 3.0))
	head.add_child(UiTheme.label("GLEICH GEHT ES LOS", 26, UiTheme.TEXT, 4.0, true))
	head.add_child(UiTheme.label("STUFE %d · %s" % [
		int(tier["level"]), tier["label"],
	], 11, UiTheme.CYAN, 2.0))
	wrap.add_child(head)

	# Kennzahlen rechts - dieselben wie im Buero, damit der Blick sie findet.
	var stats := VBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats.offset_left = -320
	stats.offset_top = 26
	stats.offset_right = -40
	stats.alignment = BoxContainer.ALIGNMENT_END
	stats.add_theme_constant_override("separation", 2)
	stats.add_child(_stat("GELD", "€%s" % UiTheme.money_text(float(state["money"]))))
	stats.add_child(_stat("KAPAZITÄT", str(GameState.capacity(state))))
	var artist: Variant = state["bookedArtist"]
	stats.add_child(_stat(
		"ACT", String((artist as Dictionary)["name"]) if artist != null else "—"
	))
	wrap.add_child(stats)

	var hint := UiTheme.label(
		"Sieh dich um. Zum Anfangen: auf den Eingang drücken.", 11, UiTheme.DIM, 2.0
	)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 40
	hint.offset_top = -50
	wrap.add_child(hint)

	# Zurueck ins Buero und - wie ueberall - zurueck zum Titel. Beide stehen
	# oben rechts unter den Kennzahlen: unten im Bild liegen die Toiletten.
	var back := UiTheme.button("ZURÜCK INS BÜRO", UiTheme.DIM, 10, 3.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -320
	back.offset_top = 116
	back.offset_right = -170
	back.offset_bottom = 148
	back.pressed.connect(func() -> void:
		(g["bus"] as Bus).emit("sfx", "ok")
		if (opts.get("onOffice", Callable()) as Callable).is_valid():
			(opts["onOffice"] as Callable).call()
	)
	wrap.add_child(back)

	if (opts.get("onMenu", Callable()) as Callable).is_valid():
		var to_menu := UiTheme.button("HAUPTMENÜ", UiTheme.DIM, 10, 3.0)
		to_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		to_menu.offset_left = -160
		to_menu.offset_top = 116
		to_menu.offset_right = -40
		to_menu.offset_bottom = 148
		to_menu.pressed.connect(func() -> void: (opts["onMenu"] as Callable).call())
		wrap.add_child(to_menu)

	# Anklickbare Flaechen. Nur der Eingang startet die Schicht - die
	# uebrigen erklaeren sich beim Darueberfahren.
	for id: String in Club.DRAW_ORDER:
		var area: Dictionary = Club.AREAS[id]
		var rect := Club.hotspot_rect(id)
		var entrance := id == "entrance"

		var b := Button.new()
		b.flat = true
		b.anchor_left = rect.position.x
		b.anchor_top = rect.position.y
		b.anchor_right = rect.position.x + rect.size.x
		b.anchor_bottom = rect.position.y + rect.size.y
		b.offset_left = 0
		b.offset_top = 0
		b.offset_right = 0
		b.offset_bottom = 0
		var accent: Color = UiTheme.RED if entrance else UiTheme.CYAN
		b.add_theme_stylebox_override("hover", UiTheme.panel_box(
			Color(1, 1, 1, 0.07 if entrance else 0.05),
			Palette.with_alpha(accent, 0.65)
		))
		if entrance:
			# Der Eingang ist auch ohne Maus zu sehen: ein staendiger Rahmen.
			b.add_theme_stylebox_override("normal", UiTheme.panel_box(
				Color(1, 1, 1, 0.03), Palette.with_alpha(accent, 0.4)
			))
		b.mouse_entered.connect(func() -> void: hint.text = String(area["hint"]))
		b.focus_entered.connect(func() -> void: hint.text = String(area["hint"]))
		b.pressed.connect(func() -> void:
			if entrance:
				(g["bus"] as Bus).emit("sfx", "door")
				if (opts.get("onEntrance", Callable()) as Callable).is_valid():
					(opts["onEntrance"] as Callable).call()
			else:
				# Kein Weiterklicken: die Flaeche erzaehlt nur von sich.
				(g["bus"] as Bus).emit("sfx", "ok")
				hint.text = String(area["hint"])
		)

		# Die Beschriftung sitzt mittig in der Flaeche - am unteren Rand
		# haengen die vorderen Felder sonst aus dem Bild.
		var tag := VBoxContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.alignment = BoxContainer.ALIGNMENT_CENTER
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tag.add_child(UiTheme.label(
			String(area["label"]), 12, UiTheme.TEXT if entrance else UiTheme.DIM, 2.0, true
		))
		tag.add_child(UiTheme.label(
			String(area["note"]), 9, accent if entrance else UiTheme.DIM
		))
		b.add_child(tag)
		wrap.add_child(b)

	return wrap

## Ausbaustufen und Act - daraus baut der Zeichner den Raum.
static func levels_for(state: Dictionary) -> Dictionary:
	var artist: Variant = state["bookedArtist"]
	return {
		"floor": GameState.upgrade_level(state, "floor"),
		"bar": GameState.upgrade_level(state, "bar"),
		"vip": GameState.upgrade_level(state, "vip"),
		"lights": GameState.upgrade_level(state, "lights"),
		"sound": GameState.upgrade_level(state, "sound"),
		"tier": int(GameState.club_tier(state)["level"]),
		"character": CharacterSys.normalize_character(state["character"]),
		"artist": String((artist as Dictionary)["name"]).to_upper() if artist != null \
			else "NULLWERK",
	}

static func _stat(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	row.add_child(UiTheme.label(value, 12, UiTheme.TEXT))
	return row

## Der gezeichnete Raum. Laeuft weiter, solange der Bildschirm offen ist.
class SceneNode extends Control:
	var levels: Dictionary = {}
	var _t := 0.0
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(l: Dictionary) -> void:
		levels = l
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
		Club.draw_club(self, _fx, size.x, size.y, _t, levels)
