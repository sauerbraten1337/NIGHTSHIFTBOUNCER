## Screens: Menue, Katalog, Online-Lobby, Briefing, Report, Shop, Buero,
## Charaktereditor, Pause.
##
## Portierung von src/ui/screens.js. Die Vorlage schiebt fertiges HTML in
## einen Container und stellt ihn ueber drei Klassen ein (bare / full / wide);
## hier ist es ein CanvasLayer mit einem Inhaltsbereich, dessen Rahmen und
## Breite dieselben drei Zustaende kennt.
class_name Screens
extends CanvasLayer

var game: Node = null

var _root: Control = null
var _shade: ColorRect = null
var _frame: PanelContainer = null
var _scroll: ScrollContainer = null
var _inner: VBoxContainer = null

## Merkt sich, welcher Modus zuletzt gewaehlt wurde (fuer FORTSETZEN).
var _last_mode := "solo"

# Lobby-Rueckmeldungen, von Game.gd ueber die Bus-Ereignisse gefuettert.
var _lobby_room: VBoxContainer = null
var _lobby_status: Label = null
var _lobby_start: Button = null

func _init(game_node: Node) -> void:
	game = game_node
	layer = 2

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_shade = ColorRect.new()
	_shade.color = Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.82)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shade)

	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_frame)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_scroll)

	_inner = VBoxContainer.new()
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.add_theme_constant_override("separation", 10)
	_scroll.add_child(_inner)

	hide_screen()

# ---------------- Rahmen ----------------

## opts: { bare, full, wide } - dieselben drei Zustaende wie in ui.css.
func show_screen(content: Control, opts: Dictionary = {}) -> void:
	for child in _inner.get_children():
		_inner.remove_child(child)
		child.queue_free()
	_inner.add_child(content)

	var bare := bool(opts.get("bare", false))
	var full := bool(opts.get("full", false))
	var wide := bool(opts.get("wide", false))

	# "bare": kein Kasten, keine Abdunklung - der Titelbildschirm zeigt die Szene.
	_shade.visible = not bare and not full
	var box := UiTheme.panel_box(
		Color(0, 0, 0, 0) if bare or full else Color(8.0 / 255.0, 10.0 / 255.0, 14.0 / 255.0, 0.9),
		Color(0, 0, 0, 0) if bare or full else UiTheme.LINE
	)
	# "full": randlos ueber den ganzen Bildschirm - das Buero ist ein Raum,
	# kein Formular in einem Kasten.
	var margin := 0 if full or bare else 40
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	_frame.add_theme_stylebox_override("panel", box)

	# "wide": breiter Kasten fuer Nachtabschluss und Charaktereditor.
	if bare:
		_frame.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_frame.offset_left = -MenuScreen.COLUMN_WIDTH
	elif full:
		_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_frame.offset_left = -560.0 if wide else -420.0
		_frame.offset_right = 560.0 if wide else 420.0
		_frame.offset_top = -330.0
		_frame.offset_bottom = 330.0

	_scroll.scroll_vertical = 0
	_root.visible = true

func hide_screen() -> void:
	_root.visible = false

# ---------------- Hauptmenue ----------------

## Der Titelbildschirm laesst die Szene frei: das Menue steht als Spalte
## rechts - oben der Clubname als Leuchtschrift, darunter die Auswahl, ganz
## unten die Fusszeile. Aufgebaut wird sie in MenuScreen.
func menu() -> void:
	show_screen(MenuScreen.build({
		"on_mode": func(mode: String) -> void:
			_last_mode = mode
			_start_career(mode),
		"on_continue": func() -> void: _continue_career(_last_mode),
		"on_catalog": func() -> void: catalog(func() -> void: menu()),
		"on_settings": func() -> void: settings(),
	}), {"bare": true})

## Einstellungen: eigener Bildschirm statt Klappfach im Menue.
func settings() -> void:
	show_screen(SettingsScreen.build(func() -> void: menu()), {"wide": true})

func _start_career(mode: String) -> void:
	game.set("tutorial_wanted", Settings.get_bool("tutorial"))
	var g: Dictionary = game.get("game")
	var carried: Dictionary = g["state"]
	g["state"] = GameState.create_initial_state(mode)
	# Wie in der Vorlage: das Tutorial faengt in einer neuen Karriere neu an.
	(g["state"] as Dictionary)["tutorialDone"] = false
	game.call("apply_mode", mode)
	# Eine neue Karriere beginnt vor dem Spiegel: erst der eigene Tuersteher.
	character(func() -> void:
		if mode == "online":
			lobby()
		else:
			game.call("go_briefing")
	)

func _continue_career(mode: String) -> void:
	game.set("tutorial_wanted", Settings.get_bool("tutorial"))
	var g: Dictionary = game.get("game")
	g["state"] = GameState.create_initial_state(mode)
	SaveGame.load_game(g["state"])
	(g["state"] as Dictionary)["mode"] = mode
	(g["state"] as Dictionary)["character"] = CharacterSys.normalize_character(
		(g["state"] as Dictionary)["character"]
	)
	game.call("apply_mode", mode)
	# Wer weiterspielt, hat seinen Tuersteher schon - ausser der Spielstand
	# stammt noch aus der Zeit vor dem Editor.
	if not bool(((g["state"] as Dictionary)["character"] as Dictionary)["created"]):
		character(func() -> void:
			if mode == "online":
				lobby()
			else:
				game.call("go_briefing")
		)
		return
	if mode == "online":
		lobby()
	else:
		game.call("go_briefing")

# ---------------- Gegenstands-Katalog ----------------

## Alles, was in der Nacht auf dem Kontrolltisch landen kann - mit dem Icon,
## das im Spiel gezeichnet wird, und der Gruppe der Hausordnung.
##
## Bewusst nur hier im Titelbildschirm: waehrend der Schicht muss man
## weiterhin selbst wissen, was ein Schlagring ist.
func catalog(on_back: Callable) -> void:
	var items := Config.items()
	var forbidden := 0
	for i: Dictionary in items:
		if bool(i["forbidden"]):
			forbidden += 1

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiTheme.label("GEGENSTÄNDE", 26, UiTheme.TEXT, 4.0, true))
	box.add_child(UiTheme.label(
		"%d SACHEN · %d DAVON VERBOTEN" % [items.size(), forbidden], 11, UiTheme.CYAN, 3.0
	))
	box.add_child(UiTheme.body_label(
		"Was Gäste dabeihaben können. In der Schicht steht in der Hausordnung nur "
		+ "die Gruppe — welcher Gegenstand dazugehört, entscheidest du dort selbst.",
		12, UiTheme.DIM
	))

	var groups: Array[Dictionary] = [{
		"id": null, "label": "ZUGELASSEN",
		"rule": "Alltagsgegenstände. Nicht zu beanstanden.", "severity": 0,
	}]
	for c: Dictionary in Config.ITEM_CATEGORIES:
		groups.append({
			"id": c["id"], "label": String(c["label"]).to_upper(),
			"rule": c["rule"], "severity": c["severity"],
		})

	for g: Dictionary in groups:
		var title := String(g["label"])
		if int(g["severity"]) > 0:
			title += " · STUFE %s" % "I".repeat(int(g["severity"]))
		box.add_child(_gap(10))
		box.add_child(UiTheme.label(title, 13, UiTheme.AMBER, 3.0))
		box.add_child(UiTheme.body_label(g["rule"], 11, UiTheme.DIM))
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for i: Dictionary in items:
			if i["cat"] != g["id"]:
				continue
			grid.add_child(_catalog_card(i, g["id"] != null))
		box.add_child(grid)

	box.add_child(_gap(14))
	var back := UiTheme.button("ZURÜCK", UiTheme.LINE, 12, 3.0)
	back.pressed.connect(on_back)
	box.add_child(back)
	show_screen(box, {"wide": true})

func _catalog_card(item: Dictionary, bad: bool) -> Control:
	var panel := UiTheme.panel(
		Color(1, 1, 1, 0.02), UiTheme.RED if bad else UiTheme.LINE
	)
	panel.custom_minimum_size = Vector2(120, 150)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	var icon := ItemTray.ItemIcon.new(item["id"], 84.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var l := UiTheme.label(item["label"], 10, UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var zones: PackedStringArray = []
	for z: String in (item["zones"] as Array):
		zones.append(_zone_label(z))
	var zl := UiTheme.label(" · ".join(zones), 8, UiTheme.DIM, 1.0)
	zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(zl)
	panel.add_child(col)
	return panel

static func _zone_label(id: String) -> String:
	for z: Dictionary in Config.ZONES:
		if z["id"] == id:
			return z["label"]
	return id.to_upper()

# ---------------- Online-Lobby ----------------

func lobby() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UiTheme.label("ONLINE-KOOP", 26, UiTheme.TEXT, 4.0, true))
	box.add_child(UiTheme.label("EIN RAUM, ZWEI BEREICHE", 11, UiTheme.CYAN, 3.0))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)

	var host_card := UiTheme.panel()
	var host_col := VBoxContainer.new()
	host_col.add_theme_constant_override("separation", 6)
	host_col.add_child(UiTheme.label("RAUM ERSTELLEN", 13, UiTheme.TEXT, 2.0))
	host_col.add_child(UiTheme.label("HOST · BOUNCER", 9, UiTheme.RED, 3.0))
	host_col.add_child(UiTheme.body_label(
		"Du übernimmst die Tür draussen und simulierst die Nacht. Dein Partner "
		+ "bekommt den Code und übernimmt die Schleuse.", 11, UiTheme.DIM
	))
	var host_btn := UiTheme.button("RAUM ERSTELLEN", UiTheme.RED, 12, 3.0)
	host_btn.pressed.connect(func() -> void: game.call("net_host"))
	host_col.add_child(host_btn)
	host_card.add_child(host_col)
	host_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(host_card)

	var join_card := UiTheme.panel()
	var join_col := VBoxContainer.new()
	join_col.add_theme_constant_override("separation", 6)
	join_col.add_child(UiTheme.label("RAUM BEITRETEN", 13, UiTheme.TEXT, 2.0))
	join_col.add_child(UiTheme.label("GAST · SECURITY", 9, UiTheme.CYAN, 3.0))
	join_col.add_child(UiTheme.body_label(
		"Code eingeben und die Sicherheitsschleuse übernehmen.", 11, UiTheme.DIM
	))
	var code_input := LineEdit.new()
	code_input.max_length = 5
	code_input.placeholder_text = "CODE"
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.add_theme_font_override("font", Fonts.mono())
	code_input.add_theme_font_size_override("font_size", 18)
	join_col.add_child(code_input)
	var join_btn := UiTheme.button("BEITRETEN", UiTheme.CYAN, 12, 3.0)
	join_btn.pressed.connect(func() -> void: game.call("net_join", code_input.text))
	code_input.text_submitted.connect(func(text: String) -> void: game.call("net_join", text))
	join_col.add_child(join_btn)
	join_card.add_child(join_col)
	join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(join_card)
	box.add_child(cols)

	_lobby_room = VBoxContainer.new()
	_lobby_room.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_lobby_room)

	_lobby_status = UiTheme.label("Nicht verbunden.", 12, UiTheme.DIM)
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lobby_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_lobby_start = UiTheme.button("SCHICHT BEGINNEN", UiTheme.GREEN, 12, 3.0)
	_lobby_start.visible = false
	_lobby_start.pressed.connect(func() -> void: game.call("net_start"))
	row.add_child(_lobby_start)
	var cancel := UiTheme.button("ZURÜCK", UiTheme.LINE, 12, 3.0)
	cancel.pressed.connect(func() -> void: game.call("net_cancel"))
	row.add_child(cancel)
	box.add_child(row)

	show_screen(box)

func lobby_set_room(code: String, role: String) -> void:
	if _lobby_room == null:
		return
	for child in _lobby_room.get_children():
		_lobby_room.remove_child(child)
		child.queue_free()
	var l := UiTheme.label(code, 40, UiTheme.CYAN, 12.0, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_room.add_child(l)
	var note := UiTheme.label(
		"CODE AN DEN PARTNER GEBEN" if role == "host" else "VERBUNDEN", 10, UiTheme.DIM, 2.0
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_room.add_child(note)

func lobby_set_status(text: String, kind: String = "") -> void:
	if _lobby_status == null:
		return
	_lobby_status.text = text
	var color := UiTheme.DIM
	if kind == "ok":
		color = UiTheme.GREEN
	elif kind == "bad":
		color = UiTheme.RED
	_lobby_status.add_theme_color_override("font_color", color)

func lobby_show_start(visible_flag: bool) -> void:
	if _lobby_start != null:
		_lobby_start.visible = visible_flag

# ---------------- Briefing ----------------

## Der Schichtplan vor der Nacht: oben der Kopf mit Nacht, Eckdaten und
## Kennzahlen, darunter zwei Spalten - links worauf zu achten ist, rechts die
## Posten mit ihren Tasten. Alles auf einer Seite, ohne Fliesstextwand.
func briefing(event: Dictionary, tutorial: bool) -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var roles := Config.roles_for(state["mode"])

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	# ---- Kopf: Nacht links, Eckdaten rechts ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var head_left := VBoxContainer.new()
	head_left.add_theme_constant_override("separation", 1)
	head_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_left.add_child(UiTheme.label("NULLWERK · SCHICHTPLAN", 9, UiTheme.RED, 5.0))
	var title := "EINARBEITUNG" if tutorial \
		else "NIGHT %s" % str(int(state["nightIndex"]) + 1).pad_zeros(2)
	head_left.add_child(UiTheme.label(title, 30, UiTheme.TEXT, 4.0, true))
	head.add_child(head_left)

	# Die Eckdaten der Nacht als einzelne Schilder statt einer langen Zeile.
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_END
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.size_flags_vertical = Control.SIZE_SHRINK_END
	chips.custom_minimum_size = Vector2(580, 0)
	chips.add_child(_chip(String(event["label"]), UiTheme.AMBER))
	chips.add_child(_chip(String(GameState.club_tier(state)["label"]), UiTheme.DIM))
	chips.add_child(_chip("RUF %d · %s" % [
		int(round(float(state["reputation"]))),
		Reputation.rep_band(float(state["reputation"])),
	], UiTheme.DIM))
	chips.add_child(_chip(String(Config.MODES[state["mode"]]["label"]), UiTheme.CYAN))
	head.add_child(chips)
	box.add_child(head)

	# ---- Kennzahlen ----
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	var artist: Variant = state["bookedArtist"]
	stats.add_child(_stat_cell(
		"GELD", "€%s" % UiTheme.money_text(float(state["money"])), UiTheme.GREEN
	))
	stats.add_child(_stat_cell("KAPAZITÄT", str(GameState.capacity(state)), UiTheme.CYAN))
	stats.add_child(_stat_cell("RANG", GameState.rank(state)["label"], UiTheme.AMBER))
	stats.add_child(_stat_cell(
		"ACT", (artist as Dictionary)["name"] if artist != null else "—",
		UiTheme.PURPLE if artist != null else UiTheme.LINE
	))
	box.add_child(stats)

	box.add_child(UiTheme.body_label(
		"Ruhige erste Schicht. Alles wird Schritt für Schritt erklärt." if tutorial
		else event["desc"], 12, UiTheme.DIM
	))

	# Was ab heute zusaetzlich auffaellig sein kann.
	var brief := Difficulty.difficulty_briefing(int(state["nightIndex"]) + 1)
	var fresh: Variant = brief["fresh"]
	if fresh != null:
		box.add_child(_notice("NEU AB HEUTE", "%s — %s" % [
			(fresh as Dictionary)["label"], (fresh as Dictionary)["desc"],
		], UiTheme.AMBER))
	if artist != null:
		box.add_child(_notice("ACT", "%s kommt im Lauf der Nacht. Auch der Act muss durch die Kontrolle."
			% (artist as Dictionary)["name"], UiTheme.PURPLE))

	# ---- Zwei Spalten: Prüfschritte links, Posten rechts ----
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)

	var checks := VBoxContainer.new()
	checks.add_theme_constant_override("separation", 6)
	checks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checks.add_child(UiTheme.section("WORAUF DU ACHTEST", UiTheme.CYAN))
	var steps: Array = brief["active"]
	for i in steps.size():
		var step: Dictionary = steps[i]
		var is_fresh: bool = fresh != null and step["id"] == (fresh as Dictionary)["id"]
		checks.add_child(_check_row(i + 1, step, is_fresh))
	checks.add_child(_notice(
		"AUSWEIS PRÜFEN",
		"Der Ausweis erscheint links unten. Felder anklicken, die nicht stimmen: "
		+ "Foto, Name, Geburtsdatum, Gültigkeit, Hologramm.", UiTheme.DIM
	))
	cols.add_child(checks)

	var posts := VBoxContainer.new()
	posts.add_theme_constant_override("separation", 6)
	posts.custom_minimum_size = Vector2(400, 0)
	posts.add_child(UiTheme.section("EURE POSTEN", UiTheme.RED))
	for role: Dictionary in roles:
		posts.add_child(_post_card(role))
	cols.add_child(posts)
	box.add_child(cols)

	box.add_child(_gap(2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var start := UiTheme.button("SCHICHT BEGINNEN", UiTheme.GREEN, 12, 3.0)
	start.custom_minimum_size = Vector2(0, 40)
	start.pressed.connect(func() -> void: game.call("begin_night", tutorial))
	row.add_child(start)
	# Vor der ersten Schicht kommt man noch zurueck zum Titel; nach einer
	# gespielten Nacht waere das ein Rueckweg mitten aus der Karriere heraus.
	if int(state["nightIndex"]) == 0:
		var back := UiTheme.button("ZURÜCK ZUM TITEL", UiTheme.LINE, 12, 3.0)
		back.custom_minimum_size = Vector2(0, 40)
		back.pressed.connect(func() -> void: game.call("go_menu"))
		row.add_child(back)
	box.add_child(row)

	show_screen(box, {"wide": true})

## Ein Schild im Briefing-Kopf (`.bchip`): Rand in der Farbe der Angabe.
func _chip(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	var box := UiTheme.panel_box(
		Color(color.r, color.g, color.b, 0.08), Color(color.r, color.g, color.b, 0.45), 3
	)
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(UiTheme.label(text, 10, color, 3.0))
	return panel

## Eine Zelle des Kennzahlenrasters (`.stat-cell`): eigener Kasten mit
## farbigem Deckstrich, Wert in der Anzeigeschrift.
func _stat_cell(key: String, value: String, accent: Color = UiTheme.CYAN) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(150, 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiTheme.panel_box(
		Color(10.0 / 255.0, 12.0 / 255.0, 17.0 / 255.0, 1.0), UiTheme.LINE
	)
	style.border_width_top = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	cell.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	var v := UiTheme.label(value, 20, UiTheme.TEXT, 1.0, true)
	v.clip_text = true
	col.add_child(v)
	cell.add_child(col)
	return cell

## Hinweisstreifen mit Schlagwort links und Text rechts.
func _notice(tag: String, text: String, accent: Color) -> Control:
	var card := UiTheme.card(accent, Color(accent.r, accent.g, accent.b, 0.08), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var t := UiTheme.label(tag, 10, accent, 3.0)
	t.custom_minimum_size = Vector2(118, 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var body := UiTheme.body_label(text, 11, UiTheme.TEXT)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	card.add_child(row)
	return card

## Ein Pruefschritt: Nummer, Bezeichnung, Erklaerung. Was heute neu ist,
## steht in Bernstein.
func _check_row(index: int, step: Dictionary, fresh: bool) -> Control:
	var accent := UiTheme.AMBER if fresh else UiTheme.CYAN
	var card := UiTheme.card(accent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var num := UiTheme.label(str(index).pad_zeros(2), 14, Color(accent.r, accent.g, accent.b, 0.6), 1.0, true)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(num)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiTheme.label(String(step["label"]).to_upper(), 11, UiTheme.TEXT, 2.0))
	if fresh:
		head.add_child(UiTheme.label("NEU", 9, UiTheme.AMBER, 2.0))
	col.add_child(head)
	col.add_child(UiTheme.body_label(step["desc"], 10, UiTheme.DIM))
	row.add_child(col)
	card.add_child(row)
	return card

## Ein Posten: wer wo steht und welche Tasten dazugehoeren.
func _post_card(role: Dictionary) -> Control:
	var airlock: bool = role["area"] == "airlock"
	var accent := UiTheme.CYAN if airlock else UiTheme.RED
	var card := UiTheme.card(accent)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var who := UiTheme.label(String(role["label"]).to_upper(), 12, accent, 3.0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	head.add_child(UiTheme.label(
		"SCHLEUSE · INNEN" if airlock else "TÜR · DRAUSSEN", 9, UiTheme.DIM, 2.0
	))
	col.add_child(head)

	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 12)
	keys.add_theme_constant_override("v_separation", 4)
	for a: Dictionary in (role["actions"] as Array):
		keys.add_child(UiTheme.key_cap(UiTheme.key_label(a["key"]), a["label"], accent))
	if airlock:
		keys.add_child(UiTheme.key_cap("JKL", "Abtast-Zonen", accent))
	col.add_child(keys)
	card.add_child(col)
	return card

# ---------------- Weiterreichende Bildschirme ----------------

func report() -> void:
	show_screen(Report.build(
		game,
		func() -> void: game.call("go_office"),
		func() -> void: game.call("quit_to_menu")
	), {"wide": true})

## Der Laptop: randlos, damit der Desktop den ganzen Bildschirm fuellt.
func shop() -> void:
	show_screen(Shop.build(game, func() -> void: game.call("go_office")), {"full": true})

## Das Buero am Tag: Schrank, Laptop, Tuer.
func office() -> void:
	show_screen(OfficeScreen.build(game, {
		"onWardrobe": func() -> void:
			character(func() -> void: office(), {
				"title": "KLEIDERSCHRANK",
				"subtitle": "NEUES OUTFIT FÜR DIE NÄCHSTE SCHICHT",
				"confirmLabel": "ÜBERNEHMEN",
				"backLabel": "ABBRECHEN",
				"onBack": func() -> void: office(),
			}),
		"onLaptop": func() -> void: shop(),
		"onDoor": func() -> void: game.call("go_briefing"),
		"onMenu": func() -> void: game.call("quit_to_menu"),
	}), {"full": true})

## Charaktereditor - beim ersten Start und am Kleiderschrank.
func character(on_done: Callable, opts: Dictionary = {}) -> void:
	game.get("game")["state"]["phase"] = "character"
	show_screen(CharacterEditor.build(game, on_done, opts), {"wide": true})

func waiting(text: String) -> void:
	var box := VBoxContainer.new()
	box.add_child(UiTheme.label("WARTEN", 26, UiTheme.TEXT, 4.0, true))
	box.add_child(UiTheme.label(text, 12, UiTheme.DIM, 2.0))
	show_screen(box)

# ---------------- Pause ----------------

## Hier - und nur hier - steht die komplette Tastenbelegung, damit das
## laufende Spiel frei von Steuerungstexten bleibt.
func pause() -> void:
	var g: Dictionary = game.get("game")
	var roles := Config.roles_for(g["state"]["mode"])

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(UiTheme.label("PAUSE", 26, UiTheme.TEXT, 4.0, true))
	main.add_child(UiTheme.label("DIE SCHLANGE WARTET", 11, UiTheme.CYAN, 3.0))
	var resume := UiTheme.button("WEITER", UiTheme.GREEN, 12, 3.0)
	resume.pressed.connect(func() -> void: game.call("toggle_pause"))
	main.add_child(resume)
	var quit := UiTheme.button("SCHICHT BEENDEN", UiTheme.RED, 12, 3.0)
	quit.pressed.connect(func() -> void: game.call("end_shift_now"))
	main.add_child(quit)

	# Zurueck ins Hauptmenue heisst: die Nacht ist weg. Einmal nachfragen.
	var to_menu := UiTheme.button("ZURÜCK ZUM HAUPTMENÜ", UiTheme.DIM, 12, 3.0)
	var armed := [false]
	to_menu.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			to_menu.text = "WIRKLICH? NOCHMAL KLICKEN"
			return
		game.call("quit_to_menu")
	)
	main.add_child(to_menu)
	main.add_child(UiTheme.body_label(
		"Beenden schliesst die Nacht ab und zeigt den Night Report. Zurück zum "
		+ "Hauptmenü verwirft die laufende Schicht.", 10, UiTheme.DIM
	))
	main.add_child(_admin_box())
	cols.add_child(main)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size = Vector2(320, 0)
	side.add_child(UiTheme.label("STEUERUNG", 13, UiTheme.TEXT, 3.0))
	for role: Dictionary in roles:
		side.add_child(UiTheme.label("%s — %s" % [
			role["label"], "SCHLEUSE" if role["area"] == "airlock" else "TÜR",
		], 10, UiTheme.CYAN, 2.0))
		for a: Dictionary in (role["actions"] as Array):
			side.add_child(_ctl_row(UiTheme.key_label(a["key"]), a["label"]))
	side.add_child(UiTheme.label("ABTASTEN", 10, UiTheme.CYAN, 2.0))
	side.add_child(_ctl_row("J", "Jacke"))
	side.add_child(_ctl_row("K", "Hosentaschen"))
	side.add_child(_ctl_row("L", "Tasche"))
	side.add_child(_ctl_row("Maus", "Ring am Gast anklicken"))
	side.add_child(_ctl_row("1 …", "Gegenstand beanstanden"))
	side.add_child(_ctl_row("0", "Zone freigeben"))
	side.add_child(UiTheme.label("ABWEHR", 10, UiTheme.CYAN, 2.0))
	var defense: PackedStringArray = []
	for k: Dictionary in Config.DEFENSE_KEYS:
		defense.append(k["label"])
	side.add_child(_ctl_row(
		" ".join(defense),
		"Geht jemand auf dich los, erscheinen diese Tasten der Reihe nach — schnell drücken"
	))
	side.add_child(_ctl_row("Maus", "Taste im Bild anklicken"))
	side.add_child(UiTheme.label("SYSTEM", 10, UiTheme.CYAN, 2.0))
	side.add_child(_ctl_row("ESC", "Pause"))
	side.add_child(_ctl_row("M", "Ton an/aus"))
	side.add_child(UiTheme.body_label(
		"Alle Kontrollen lassen sich auch anklicken: die Icons unten, der Ausweis, "
		+ "der Block und die Ringe am Gast.", 10, UiTheme.DIM
	))
	cols.add_child(side)

	show_screen(cols, {"wide": true})

func _ctl_row(key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := UiTheme.label(key, 10, UiTheme.AMBER, 1.0)
	k.custom_minimum_size = Vector2(74, 0)
	row.add_child(k)
	var t := UiTheme.body_label(text, 10, UiTheme.DIM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row

# ---------------- Admin: Testhilfen hinter einem Code ----------------

## Erst der Code, dann die Werkzeuge. Alles hier greift sofort - die
## Nachtwahl verwirft die laufende Schicht und geht ins Briefing.
##
## Der Kasten traegt dasselbe Violett wie der Roentgenblick im Spiel: was hier
## geschaltet wird, gehoert nicht zur Schicht, sondern zum Testwerkzeug.
func _admin_box() -> Control:
	var frame := PanelContainer.new()
	var style := UiTheme.panel_box(
		Color(UiTheme.PURPLE.r * 0.16, UiTheme.PURPLE.g * 0.12, UiTheme.PURPLE.b * 0.24, 0.5),
		Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.55), 3
	)
	frame.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	frame.add_child(box)
	_fill_admin(box)
	return frame

func _fill_admin(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	var msg := UiTheme.label("", 10, UiTheme.DIM)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var say := func(text: String, kind: String) -> void:
		msg.text = text
		msg.add_theme_color_override("font_color", UiTheme.kind_color(kind))

	if not Admin.unlocked:
		box.add_child(UiTheme.section("ADMIN · GESPERRT", UiTheme.DIM))
		box.add_child(UiTheme.body_label(
			"Testzugang: Nacht frei wählen und Cheats schalten.", 10, UiTheme.DIM
		))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var code := LineEdit.new()
		code.secret = true
		code.placeholder_text = "ADMIN-CODE"
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code.add_theme_font_override("font", Fonts.mono())
		code.add_theme_font_size_override("font_size", 11)
		row.add_child(code)
		var unlock := UiTheme.button("FREISCHALTEN", UiTheme.PURPLE, 10, 2.0)
		var attempt := func() -> void:
			if Admin.unlock_admin(code.text):
				_fill_admin(box)
			else:
				say.call("Falscher Code.", "bad")
		unlock.pressed.connect(attempt)
		code.text_submitted.connect(func(_t: String) -> void: attempt.call())
		row.add_child(unlock)
		box.add_child(row)
		box.add_child(msg)
		return

	var night := int((game.get("game") as Dictionary)["state"]["nightIndex"])
	box.add_child(UiTheme.section("ADMIN · FREIGESCHALTET", UiTheme.PURPLE))

	# Nacht waehlen: Zahl und Startknopf in einer Zeile.
	var night_row := HBoxContainer.new()
	night_row.add_theme_constant_override("separation", 8)
	var night_key := UiTheme.label("NACHT", 9, UiTheme.DIM, 2.0)
	night_key.custom_minimum_size = Vector2(64, 0)
	night_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	night_row.add_child(night_key)
	var night_input := SpinBox.new()
	night_input.min_value = 1
	night_input.max_value = Admin.ADMIN_MAX_NIGHT
	night_input.value = maxi(1, night)
	night_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_row.add_child(night_input)
	var go := UiTheme.button("STARTEN", UiTheme.CYAN, 10, 2.0)
	go.pressed.connect(func() -> void: game.call("admin_night", int(night_input.value)))
	night_row.add_child(go)
	box.add_child(night_row)
	box.add_child(UiTheme.body_label(
		"Bricht die laufende Schicht ab und geht ins Briefing der gewählten Nacht. "
		+ "Aktuell: NACHT %s." % str(night).pad_zeros(2), 9, UiTheme.DIM
	))

	# Schalter als Knoepfe, die ihren Zustand zeigen - ein Haken sagt aus der
	# Entfernung nicht, ob der Cheat laeuft.
	var cheats := HFlowContainer.new()
	cheats.add_theme_constant_override("h_separation", 6)
	cheats.add_theme_constant_override("v_separation", 6)
	for entry: Array in [
		["noAggro", "KEINE ÜBERGRIFFE"],
		["fastActions", "SOFORT FERTIG"],
		["reveal", "RÖNTGENBLICK"],
	]:
		cheats.add_child(_cheat_toggle(entry[0], entry[1]))
	box.add_child(cheats)

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	for entry: Array in [
		["admin_money", "+5000 €"], ["admin_rep", "RUF AUF 100"],
		["admin_unlock_all", "ALLES FREISCHALTEN"], ["admin_shorten", "NOCH 3 GÄSTE"],
		["admin_attack", "ÜBERGRIFF AUSLÖSEN"], ["admin_end_shift", "SCHICHT BEENDEN"],
	]:
		var b := UiTheme.button(entry[1], UiTheme.LINE, 10)
		b.pressed.connect(func() -> void:
			var result: Variant = game.call(entry[0])
			var text := String(result) if result != null else "Erledigt."
			# Nichts zu tun ist kein Erfolg - das soll man am Ton sehen.
			var bad := text.begins_with("Keine") or text.begins_with("Niemand")
			say.call(text, "bad" if bad else "good")
		)
		actions.add_child(b)
	box.add_child(actions)
	box.add_child(msg)

	var lock := UiTheme.button("ADMIN SPERREN", UiTheme.RED, 10)
	lock.pressed.connect(func() -> void:
		Admin.lock_admin()
		_fill_admin(box)
	)
	box.add_child(lock)

## Ein Cheat-Schalter. An heisst violett gefuellt, aus bleibt dunkel.
func _cheat_toggle(id: String, label: String) -> Control:
	var b := UiTheme.button(label, UiTheme.PURPLE, 10, 1.0)
	b.toggle_mode = true
	b.button_pressed = Admin.get_cheat(id)
	var paint := func(on: bool) -> void:
		# Auch "pressed" mitfaerben: bei einem Schalter zeigt Godot diesen
		# Zustand, solange er eingerastet ist.
		for state: String in ["normal", "pressed"]:
			b.add_theme_stylebox_override(state, UiTheme.panel_box(
				Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.28 if on else 0.03),
				Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 1.0 if on else 0.35),
				3, 2 if on else 1
			))
		b.add_theme_color_override("font_color", UiTheme.TEXT if on else UiTheme.DIM)
	paint.call(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		Admin.set_cheat(id, on)
		paint.call(Admin.get_cheat(id))
	)
	return b

func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
