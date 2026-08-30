## Einstellungen: Bild, Ton, Spiel und Daten - ein eigener Bildschirm.
##
## Gegenstueck zu `settingsScreen()` in src/ui/screens.js. Jede Aenderung
## greift sofort und liegt danach in Settings; der Bildschirm baut sich nach
## jedem Klick neu auf, damit Zustand und Anzeige nie auseinanderlaufen.
class_name SettingsScreen
extends RefCounted

## Baut den Bildschirm. `on_back` fuehrt zurueck ins Hauptmenue.
static func build(on_back: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_fill(box, on_back)
	return box

static func _rebuild(box: VBoxContainer, on_back: Callable) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_fill(box, on_back)

static func _fill(box: VBoxContainer, on_back: Callable) -> void:
	# ---------- Kopf ----------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(UiTheme.label("NULLWERK · SYSTEM", 9, UiTheme.RED, 5.0))
	titles.add_child(UiTheme.label("EINSTELLUNGEN", 26, UiTheme.TEXT, 4.0, true))
	titles.add_child(UiTheme.label("BILD · TON · SPIEL · DATEN", 11, UiTheme.CYAN, 3.0))
	head.add_child(titles)
	var back := UiTheme.button("ZURÜCK", UiTheme.LINE, 12, 3.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(on_back)
	head.add_child(back)
	box.add_child(head)
	box.add_child(UiTheme.separator())

	# ---------- 01 BILD ----------
	var bild := _block(box, "01", "BILD")

	var res_row := _row(bild, "AUFLÖSUNG",
		"Grösse des Fensters. Gilt im Fenstermodus; im Vollbild zählt der Bildschirm.")
	var res_col := VBoxContainer.new()
	res_col.add_theme_constant_override("separation", 6)
	var res_ids: PackedStringArray = []
	var res_labels: PackedStringArray = []
	for r: Dictionary in Settings.RESOLUTIONS:
		res_ids.append(String(r["id"]))
		res_labels.append(String(r["label"]))
	res_col.add_child(_segmented(
		res_ids, res_labels, Settings.get_string("resolution"),
		func(id: String) -> void:
			Settings.set_value("resolution", id)
			Settings.apply_window()
			_rebuild(box, on_back)
	))
	res_col.add_child(UiTheme.label(
		"%s · %s" % [Settings.current_note(), String(Settings.resolution_entry()["note"])],
		9, Color("6d7482"), 2.0
	))
	res_row.add_child(res_col)

	var disp_row := _row(bild, "ANZEIGE", "Fenster, randloses Vollbild oder ganz exklusiv.")
	var disp_ids: PackedStringArray = []
	var disp_labels: PackedStringArray = []
	for d: Dictionary in Settings.DISPLAY_MODES:
		disp_ids.append(String(d["id"]))
		disp_labels.append(String(d["label"]))
	disp_row.add_child(_segmented(
		disp_ids, disp_labels, Settings.get_string("display"),
		func(id: String) -> void:
			Settings.set_value("display", id)
			Settings.apply_window()
			_rebuild(box, on_back)
	))

	_row(bild, "BILDEFFEKTE", "Nebel, Scanlines, Funken. Aus spart Leistung.").add_child(
		_switch("effects", box, on_back)
	)
	_row(bild, "BILDSYNCHRONISATION", "Verhindert zerrissene Bilder, kostet etwas Tempo.").add_child(
		_switch("vsync", box, on_back)
	)

	# ---------- 02 TON ----------
	var ton := _block(box, "02", "TON")
	_row(ton, "STUMM", "Schaltet alles ab — wie die Taste M.").add_child(
		_switch("muted", box, on_back)
	)
	_row(ton, "GESAMT", "Lautstärke von allem.").add_child(_slider("master"))
	_row(ton, "MUSIK", "Der Sound aus dem Club.").add_child(_slider("music"))
	_row(ton, "EFFEKTE", "Türen, Piepser, Stempel.").add_child(_slider("sfx"))

	# ---------- 03 SPIEL ----------
	var spiel := _block(box, "03", "SPIEL")
	_row(spiel, "TUTORIAL SPIELEN",
		"Die Einarbeitung erklärt Ausweis, Abtasten und Entscheidung Schritt für Schritt."
	).add_child(_switch("tutorial", box, on_back))

	# ---------- 04 DATEN ----------
	var daten := _block(box, "04", "DATEN")
	var has_save := SaveGame.has_save()
	var save_row := _row(daten, "SPIELSTAND",
		"Gelöscht ist gelöscht — die Karriere beginnt danach von vorn." if has_save
		else "Kein Spielstand vorhanden.")
	var clear := UiTheme.button("SPIELSTAND LÖSCHEN", UiTheme.RED, 11, 3.0)
	clear.disabled = not has_save
	clear.pressed.connect(func() -> void:
		SaveGame.clear_save()
		clear.disabled = true
		clear.text = "GELÖSCHT"
	)
	save_row.add_child(clear)

	var reset_row := _row(daten, "ZURÜCKSETZEN", "Alle Einstellungen wieder auf Werk.")
	var reset := UiTheme.button("STANDARD", UiTheme.LINE, 11, 3.0)
	reset.pressed.connect(func() -> void:
		Settings.reset()
		Settings.apply_window()
		_rebuild(box, on_back)
	)
	reset_row.add_child(reset)

	box.add_child(_gap(10))
	var done := UiTheme.button("FERTIG", UiTheme.GREEN, 12, 3.0)
	done.pressed.connect(on_back)
	box.add_child(done)

# ---------- Bausteine ----------

## Ein Abschnitt: Nummer, Titel und ein Kasten fuer die Zeilen.
static func _block(parent: VBoxContainer, number: String, title: String) -> VBoxContainer:
	parent.add_child(_gap(10))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var num := PanelContainer.new()
	num.add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.08),
		Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.45)
	))
	num.add_child(UiTheme.label(number, 10, UiTheme.CYAN, 2.0, true))
	head.add_child(num)
	head.add_child(UiTheme.label(title, 13, UiTheme.TEXT, 5.0))
	parent.add_child(head)

	var panel := PanelContainer.new()
	var style := UiTheme.panel_box(Color(1, 1, 1, 0.022), UiTheme.LINE)
	style.border_width_left = 2
	style.border_color = UiTheme.LINE
	panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	panel.add_child(body)
	parent.add_child(panel)
	return body

## Eine Zeile: links Name und Erklaerung, rechts das Bedienelement.
## Rueckgabe ist die rechte Seite - dort haengt der Aufrufer sein Element ein.
static func _row(parent: VBoxContainer, title: String, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size = Vector2(0, 46)

	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(300, 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.add_child(UiTheme.label(title, 12, UiTheme.TEXT, 3.0))
	var n := UiTheme.body_label(note, 10, UiTheme.DIM)
	n.custom_minimum_size = Vector2(300, 0)
	text.add_child(n)
	row.add_child(text)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)

	parent.add_child(row)
	parent.add_child(UiTheme.separator(UiTheme.LINE_SOFT))
	return right

## Auswahl aus mehreren Moeglichkeiten - die gewaehlte leuchtet cyan.
static func _segmented(
	ids: PackedStringArray, labels: PackedStringArray, current: String, on_pick: Callable
) -> Control:
	var row := HFlowContainer.new()
	# Ohne Ausdehnen bekaeme der Fluss nur seine Mindestbreite und legte jede
	# Schaltflaeche in eine eigene Zeile.
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	for i in ids.size():
		var id := ids[i]
		var on := id == current
		var b := UiTheme.button(labels[i], UiTheme.CYAN, 10, 2.0)
		if on:
			# Die aktive Schaltflaeche ist gefuellt, nicht nur umrandet.
			var box := UiTheme.panel_box(UiTheme.CYAN, UiTheme.CYAN)
			b.add_theme_stylebox_override("normal", box)
			b.add_theme_stylebox_override("hover", box)
			b.add_theme_stylebox_override("focus", box)
			b.add_theme_color_override("font_color", Color("05070c"))
			b.add_theme_color_override("font_hover_color", Color("05070c"))
		b.pressed.connect(func() -> void: on_pick.call(id))
		row.add_child(b)
	return row

## Schalter mit zwei Zustaenden. Godots CheckBox bringt eigene Grafiken mit -
## hier ist es ein Knopf, der wie der Schalter in der Web-Fassung aussieht.
static func _switch(key: String, box: VBoxContainer, on_back: Callable) -> Control:
	var on := Settings.get_bool(key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 24)
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, empty)
	var track := SwitchTrack.new(on)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(track)
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not Settings.get_bool(key))
		_rebuild(box, on_back)
	)
	row.add_child(b)
	row.add_child(UiTheme.label("AN" if on else "AUS", 10, UiTheme.GREEN if on else UiTheme.DIM, 3.0))
	return row

## Regler mit Prozentanzeige.
static func _slider(key: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.get_float(key)
	slider.custom_minimum_size = Vector2(280, 20)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UiTheme.CYAN
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1a1f28")
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)

	var out := UiTheme.label("%d%%" % int(round(slider.value * 100.0)), 13, UiTheme.CYAN, 1.0, true)
	out.custom_minimum_size = Vector2(52, 0)
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		out.text = "%d%%" % int(round(v * 100.0))
	)
	row.add_child(slider)
	row.add_child(out)
	return row

static func _gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

## Der Schalter selbst: Rahmen, Fuellung, wandernder Knubbel.
class SwitchTrack extends Control:
	var on := false

	func _init(is_on: bool) -> void:
		on = is_on

	func _draw() -> void:
		var w := size.x - 2.0
		var h := size.y - 2.0
		var border := UiTheme.GREEN if on else UiTheme.LINE
		var fill := Color(UiTheme.GREEN.r, UiTheme.GREEN.g, UiTheme.GREEN.b, 0.12) \
			if on else Color("0a0d12")
		draw_rect(Rect2(1, 1, w, h), fill)
		draw_rect(Rect2(1, 1, w, h), border, false, 1.0)
		var knob_x := w - 18.0 if on else 3.0
		var knob := UiTheme.GREEN if on else Color("444c5a")
		if on:
			draw_rect(Rect2(knob_x - 2.0, 2.0, 20.0, h - 2.0),
				Color(UiTheme.GREEN.r, UiTheme.GREEN.g, UiTheme.GREEN.b, 0.25))
		draw_rect(Rect2(knob_x, 4.0, 16.0, h - 6.0), knob)
