## Titelbildschirm: die Menuespalte rechts ueber der Szene.
##
## Godot bringt fuer so etwas keine Entsprechung zu CSS mit - Verlauf,
## Leuchtroehre am Rand, wandernder Lichtbalken und der Lichtwisch ueber einem
## Eintrag sind darum kleine Zeichenknoten. Der Rest ist gewoehnliches
## Container-Layout.
##
## Gegenstueck zum `.menu`-Block in styles/ui.css.
class_name MenuScreen
extends RefCounted

const COLUMN_WIDTH := 500.0

## opts: { on_mode(String), on_continue(), on_catalog(), on_settings() }
static func build(opts: Dictionary) -> Control:
	# Die Spalte ist selbst der Rahmen: mindestens bildschirmhoch, und wenn der
	# Inhalt mehr braucht, waechst sie mit (der Bildschirm scrollt dann).
	var column := Column.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, Layout.WORLD.y)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	column.add_child(box)

	var save: Variant = SaveGame.peek_save()

	# ---------- Kopf ----------

	box.add_child(_kicker("NULLWERK PRÄSENTIERT"))
	box.add_child(NeonTitle.new(Config.CLUB_NAME))
	box.add_child(_gap(6))
	box.add_child(_rule_row("NIGHTSHIFT — BOUNCER CO-OP", UiTheme.CYAN))
	var tag := UiTheme.body_label(
		"Tür auf, Tür zu. Du entscheidest, wer reinkommt.", 12, Color("9aa3b1")
	)
	box.add_child(tag)
	if save != null:
		box.add_child(_gap(6))
		box.add_child(_save_strip(save as Dictionary))
	box.add_child(_gap(10))

	# ---------- Auswahl ----------

	var items: Array[Dictionary] = [
		{"group": "SCHICHT ANTRETEN"},
		{"id": "solo", "label": Config.MODES["solo"]["label"],
			"note": "Allein an der Tür. Alles liegt bei dir.", "kind": "mode"},
		{"id": "local", "label": Config.MODES["local"]["label"],
			"note": "Zwei an einer Tastatur, geteilter Bildschirm.", "kind": "mode"},
		{"id": "online", "label": Config.MODES["online"]["label"],
			"note": "Raum erstellen oder mit Code beitreten.", "kind": "mode"},
		{"group": "CLUB"},
		{"id": "catalog", "label": "GEGENSTÄNDE",
			"note": "Alles, was Gäste dabeihaben können.", "kind": "screen"},
		{"id": "settings", "label": "EINSTELLUNGEN",
			"note": "Auflösung, Ton, Tutorial, Spielstand.", "kind": "screen"},
		{"id": "howto", "label": "ANLEITUNG",
			"note": "Wie eine Schicht abläuft.", "kind": "panel"},
		{"id": "credits", "label": "ÜBER DAS SPIEL",
			"note": "Was das hier ist.", "kind": "panel"},
	]
	if save != null:
		var s := save as Dictionary
		items.insert(1, {
			"id": "continue", "label": "KARRIERE FORTSETZEN",
			"note": "Nacht %s · €%s · Ruf %d" % [
				str(int(s["nightIndex"]) + 1).pad_zeros(2),
				UiTheme.money_text(float(s["money"])),
				int(round(float(s["reputation"]))),
			],
			"kind": "continue",
		})

	var panel := PanelContainer.new()
	panel.visible = false
	var panel_box := UiTheme.panel_box(Color(8.0 / 255.0, 10.0 / 255.0, 15.0 / 255.0, 0.86))
	panel_box.border_width_left = 2
	panel_box.border_color = UiTheme.CYAN
	panel.add_theme_stylebox_override("panel", panel_box)
	var panel_body := VBoxContainer.new()
	panel_body.add_theme_constant_override("separation", 6)
	panel.add_child(panel_body)

	var open_panel := {"id": ""}
	var buttons: Array[Item] = []
	var number := 0
	for item: Dictionary in items:
		if item.has("group"):
			box.add_child(_group_head(String(item["group"])))
			continue
		number += 1
		var kind := String(item["kind"])
		var entry := Item.new(
			str(number).pad_zeros(2), String(item["label"]), String(item["note"]),
			UiTheme.GREEN if kind == "continue" else UiTheme.RED,
			kind == "mode" or kind == "continue"
		)
		entry.pressed.connect(func() -> void:
			_choose(item, opts, open_panel, panel, panel_body, buttons)
		)
		box.add_child(entry)
		buttons.append(entry)

	box.add_child(panel)
	box.add_child(UiTheme.spacer())

	# ---------- Fusszeile ----------

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var keys := UiTheme.label(
		"↑ ↓ WÄHLEN · ENTER LOS · ESC PAUSE · M TON", 9, Color("5b626e"), 2.0
	)
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(keys)
	var fs := UiTheme.button(_fullscreen_label(), UiTheme.CYAN, 9, 3.0)
	fs.pressed.connect(func() -> void:
		# Der Knopf schaltet nur um; gespeichert wird ueber die Einstellungen,
		# damit beides denselben Weg nimmt.
		Settings.set_value(
			"display", "window" if Settings.get_string("display") != "window" else "fullscreen"
		)
		fs.text = _fullscreen_label()
	)
	foot.add_child(fs)
	box.add_child(foot)

	# Die Auswahl soll ohne Maus bedienbar sein: der erste Eintrag bekommt den
	# Fokus, Godot regelt Hoch/Runter dann selbst.
	if not buttons.is_empty():
		buttons[0].call_deferred("grab_focus")
	return column

static func _fullscreen_label() -> String:
	return "FENSTER" if Settings.get_string("display") != "window" else "VOLLBILD"

# ---------- Auswahl ----------

static func _choose(
	item: Dictionary, opts: Dictionary, open_panel: Dictionary,
	panel: PanelContainer, body: VBoxContainer, buttons: Array[Item]
) -> void:
	match String(item["kind"]):
		"mode":
			(opts["on_mode"] as Callable).call(String(item["id"]))
		"continue":
			(opts["on_continue"] as Callable).call()
		"screen":
			if item["id"] == "catalog":
				(opts["on_catalog"] as Callable).call()
			else:
				(opts["on_settings"] as Callable).call()
		_:
			# Eigenes Feld auf- oder zuklappen.
			var id := String(item["id"])
			if open_panel["id"] == id:
				open_panel["id"] = ""
				panel.visible = false
			else:
				open_panel["id"] = id
				panel.visible = true
				for child in body.get_children():
					body.remove_child(child)
					child.queue_free()
				_fill_panel(body, id)
			for b: Item in buttons:
				b.open = b.label_text == String(item["label"]) and panel.visible
				b.queue_redraw()

static func _fill_panel(body: VBoxContainer, id: String) -> void:
	if id == "howto":
		var steps := [
			"AUSWEIS verlangen und selbst prüfen: Foto, Name, Geburtsdatum, "
				+ "Gültigkeit, Hologramm.",
			"ANSPRECHEN — was sagt der Gast, passt es zum Ausweis?",
			"ABTASTEN — Jacke, Hosentaschen, Tasche. Ringe anklicken oder J K L.",
			"ALKOTEST bei Verdacht. Den Grenzwert liest du selbst ab.",
			"ENTSCHEIDEN — einlassen oder abweisen. Niemand sagt dir, ob es richtig war.",
		]
		for i in steps.size():
			body.add_child(UiTheme.body_label("%d. %s" % [i + 1, steps[i]], 11, Color("9aa3b1")))
		return
	body.add_child(UiTheme.body_label(
		"Ein Club, eine Tür, eine Nacht. Im Koop steht einer draussen an der Tür und "
		+ "einer drinnen in der Sicherheitsschleuse — was der eine übersieht, kann der "
		+ "andere noch fangen.", 11, Color("9aa3b1")
	))
	body.add_child(UiTheme.body_label(
		"Alles hier ist von Hand gezeichneter Code: keine Bilder, keine Assets.",
		11, Color("9aa3b1")
	))

# ---------- Bausteine ----------

static func _gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

## Kleine Zeile mit rotem Strich davor.
static func _kicker(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var dash := ColorRect.new()
	dash.color = UiTheme.RED
	dash.custom_minimum_size = Vector2(22, 1)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dash)
	row.add_child(UiTheme.label(text, 9, UiTheme.DIM, 5.0))
	return row

## Beschriftung mit auslaufender Linie dahinter (`.menu-sub`).
static func _rule_row(text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiTheme.label(text, 11, color, 4.0))
	var line := FadeLine.new(color)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row

static func _group_head(text: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_gap(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label(text, 8, Color("4e5563"), 5.0))
	var line := FadeLine.new(Color(1, 1, 1, 0.12))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	wrap.add_child(row)
	return wrap

## Was im Spielstand steht - direkt unter dem Titel.
static func _save_strip(save: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := UiTheme.panel_box(
		Color(UiTheme.GREEN.r, UiTheme.GREEN.g, UiTheme.GREEN.b, 0.07),
		Color(UiTheme.GREEN.r, UiTheme.GREEN.g, UiTheme.GREEN.b, 0.35)
	)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := Dot.new(UiTheme.GREEN)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var name_text := String(save.get("name", "")) if save.get("name", null) != null else ""
	if name_text.is_empty():
		name_text = "DEIN TÜRSTEHER"
	row.add_child(UiTheme.label(name_text, 11, UiTheme.GREEN, 3.0))
	row.add_child(UiTheme.label(
		"NACHT %s · %s" % [
			str(int(save["nightIndex"]) + 1).pad_zeros(2), _save_date(save),
		], 9, UiTheme.DIM, 2.0
	))
	panel.add_child(row)
	return panel

static func _save_date(save: Dictionary) -> String:
	var stamp := int(save.get("savedAt", 0))
	if stamp <= 0:
		return "ZULETZT —"
	var d := Time.get_datetime_dict_from_unix_time(stamp / 1000)
	return "ZULETZT %02d.%02d.%02d" % [d["day"], d["month"], int(d["year"]) % 100]

# ---------- Zeichenknoten ----------

## Der Hintergrund der Spalte: Verlauf nach rechts, Leuchtroehre am linken
## Rand und ein Lichtbalken, der langsam nach unten wandert.
class Column extends MarginContainer:
	var _t := 0.0

	func _init() -> void:
		add_theme_constant_override("margin_left", 34)
		add_theme_constant_override("margin_right", 32)
		add_theme_constant_override("margin_top", 22)
		add_theme_constant_override("margin_bottom", 16)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Verlauf: links durchsichtig, rechts fast schwarz.
		Draw2D.hgradient_rect(
			self, Rect2(-40.0, 0, w * 0.5 + 40.0, h),
			Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.0),
			Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.97)
		)
		draw_rect(
			Rect2(w * 0.5, 0, w * 0.5 + 40.0, h),
			Color(3.0 / 255.0, 4.0 / 255.0, 7.0 / 255.0, 0.97)
		)

		# Leuchtroehre: pulst leise, mit weichem Schein daneben.
		var pulse: float = 0.72 + 0.28 * sin(_t * 1.1)
		for i in 5:
			var spread := float(i) * 3.0
			draw_rect(
				Rect2(-spread, h * 0.04, 2.0 + spread * 2.0, h * 0.92),
				Color(UiTheme.RED.r, UiTheme.RED.g, UiTheme.RED.b, 0.06 * pulse)
			)
		draw_rect(Rect2(0, h * 0.06, 2.0, h * 0.88),
			Color(UiTheme.RED.r, UiTheme.RED.g, UiTheme.RED.b, 0.85 * pulse))

		# Lichtbalken, der durch die Spalte laeuft.
		var band_h := 150.0
		var y := fmod(_t * 60.0, h + band_h * 2.0) - band_h
		Draw2D.vgradient_rect(
			self, Rect2(0, y, w, band_h * 0.5),
			Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.0),
			Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.045)
		)
		Draw2D.vgradient_rect(
			self, Rect2(0, y + band_h * 0.5, w, band_h * 0.5),
			Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.045),
			Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.0)
		)

## Der Clubname als Leuchtschrift: weisser Kern, roter Schein, und ab und zu
## ein Doppelbild in Rot und Cyan.
class NeonTitle extends Control:
	var text := ""
	var _t := 0.0
	var _last_glitch := false

	func _init(content: String) -> void:
		text = content
		custom_minimum_size = Vector2(0, 50)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		# Der Kern steht still; neu gezeichnet wird nur um das kurze Zucken
		# herum - alles andere waere Arbeit fuer ein gleiches Bild.
		var now := _glitching()
		if now or now != _last_glitch:
			queue_redraw()
		_last_glitch = now

	func _glitching() -> bool:
		return fmod(_t, 6.5) > 6.2

	func _draw() -> void:
		var font := Fonts.spaced(Fonts.display(), 6.0)
		var size_px := 42
		var base := Vector2(0, 44)
		# Schein: mehrere schwach rote Kopien um den Kern herum.
		for i in 6:
			var a := float(i) / 6.0 * TAU
			draw_string(font, base + Vector2(cos(a), sin(a)) * 5.0,
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
				Color(UiTheme.RED.r, UiTheme.RED.g, UiTheme.RED.b, 0.12))
		# Doppelbild: kurzes Zucken alle paar Sekunden.
		if _glitching():
			draw_string(font, base + Vector2(-3, 1), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size_px, Color(UiTheme.RED.r, UiTheme.RED.g, UiTheme.RED.b, 0.65))
			draw_string(font, base + Vector2(3, -1), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size_px, Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.5))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 1, 1))

## Linie, die nach rechts ausblendet.
class FadeLine extends Control:
	var color := UiTheme.CYAN

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(20, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Draw2D.hgradient_rect(
			self, Rect2(0, 0, size.x, 1),
			Color(color.r, color.g, color.b, 0.45), Color(color.r, color.g, color.b, 0.0)
		)

## Leuchtpunkt, der langsam pulst (Spielstand-Streifen).
class Dot extends Control:
	var color := UiTheme.GREEN
	var _t := 0.0

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(8, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a: float = 0.55 + 0.45 * sin(_t * 2.6)
		draw_circle(Vector2(4, 4), 7.0, Color(color.r, color.g, color.b, 0.18 * a))
		draw_circle(Vector2(4, 4), 3.5, Color(color.r, color.g, color.b, a))

## Ein Eintrag der Auswahl: Nummer, Name, Erklaerung, Pfeil.
##
## Der Knopf zeichnet seinen Hintergrund selbst - abgeschraegte Ecke, farbiger
## Balken links und ein Lichtwisch, der beim Ueberfahren einmal durchlaeuft.
class Item extends Button:
	var number := ""
	var label_text := ""
	var note := ""
	var accent := UiTheme.RED
	var play := false
	var open := false

	var _sweep := 1.5          # >1 = kein Wisch sichtbar
	var _num: Label = null
	var _name: Label = null
	var _note: Label = null

	func _init(
		num: String, name_text: String, note_text: String,
		accent_color: Color, is_play: bool
	) -> void:
		number = num
		label_text = name_text
		note = note_text
		accent = accent_color
		play = is_play
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(0, 46)
		# Die eingebauten Zustandskaesten wuerden ueber die eigene Zeichnung
		# laufen - alle vier auf durchsichtig.
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)

	func _ready() -> void:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 14
		row.offset_right = -12
		row.add_theme_constant_override("separation", 14)

		_num = UiTheme.label(number, 10, Color("454c5a"), 2.0)
		_num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_num)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 2)
		_name = UiTheme.label(label_text, 16, Color(1, 1, 1) if play else UiTheme.TEXT, 3.0, true)
		text.add_child(_name)
		_note = UiTheme.label(note, 10, UiTheme.DIM, 0.5)
		text.add_child(_note)
		row.add_child(text)

		var mark := UiTheme.label("▸", 12, accent)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.modulate = Color(1, 1, 1, 0)
		row.add_child(mark)
		add_child(row)

		mouse_entered.connect(func() -> void: _light_up(mark))
		focus_entered.connect(func() -> void: _light_up(mark))
		mouse_exited.connect(func() -> void: _dim(mark))
		focus_exited.connect(func() -> void: _dim(mark))
		set_process(true)

	func _light_up(mark: Control) -> void:
		mark.modulate = Color(1, 1, 1, 1)
		_num.add_theme_color_override("font_color", accent)
		_sweep = 0.0
		queue_redraw()

	func _dim(mark: Control) -> void:
		if is_hovered() or has_focus():
			return
		mark.modulate = Color(1, 1, 1, 0)
		_num.add_theme_color_override("font_color", Color("454c5a"))
		queue_redraw()

	func _process(delta: float) -> void:
		if _sweep <= 1.2:
			_sweep += delta * 2.4
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var lit := is_hovered() or has_focus() or open

		# Grundflaeche mit abgeschraegter unterer Ecke - der Verlauf sitzt als
		# Farbe je Eckpunkt direkt auf dem Vieleck, damit die Schraege bleibt.
		var cut := 9.0
		var shape := PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w, h - cut),
			Vector2(w - cut, h), Vector2(0, h),
		])
		var near := Color(accent.r, accent.g, accent.b, 0.16 if lit else 0.025)
		var far := Color(accent.r, accent.g, accent.b, 0.0)
		Draw2D.gradient_polygon(self, shape, PackedColorArray([
			near, far, far, far, near,
		]))

		# Balken links: die Farbe des Eintrags.
		var bar := Color(accent.r, accent.g, accent.b, 1.0) if lit \
			else Color(UiTheme.LINE.r, UiTheme.LINE.g, UiTheme.LINE.b, 1.0)
		draw_rect(Rect2(0, 0, 3.0 if lit else 2.0, h), bar)

		# Lichtwisch beim Ueberfahren.
		if _sweep <= 1.2:
			var x := lerpf(-0.3, 1.3, _sweep) * w
			Draw2D.hgradient_rect(self, Rect2(x - 60.0, 0, 60.0, h),
				Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.07))
			Draw2D.hgradient_rect(self, Rect2(x, 0, 60.0, h),
				Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0))

		if lit:
			# Feine Umrandung, damit der Eintrag vorne steht.
			var line := Color(accent.r, accent.g, accent.b, 0.35)
			draw_polyline(PackedVector2Array([
				Vector2(0, 0.5), Vector2(w - 0.5, 0.5), Vector2(w - 0.5, h - cut),
				Vector2(w - cut, h - 0.5), Vector2(0, h - 0.5),
			]), line, 1.0)
