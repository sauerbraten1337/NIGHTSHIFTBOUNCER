## Der Notizzettel: zwei handschriftliche Seiten, beide vom Spieler gefuehrt.
##
##   SEITE 1 - CHECKLISTE
##     Was ist bei diesem Gast noch zu pruefen? Der Spieler hakt selbst ab.
##     Das Spiel setzt keinen einzigen Haken fuer ihn.
##
##   SEITE 2 - BEFUND
##     Der Spieler traegt selbst ein, welche Punkte der Norm entsprechen und
##     welche nicht. Auch hier bewertet das Spiel nichts - erst nach der
##     Entscheidung wird abgerechnet.
##
## Umgeblaettert wird ueber die beiden Reiter am Kopf des Zettels.
##
## Portierung von src/ui/notepad.js. Statt innerHTML bei jeder Aenderung neu
## zu setzen, baut dieser Knoten seine Zeilen als Control-Knoten - der
## Schluesselvergleich aus der Vorlage bleibt, damit nicht jeden Frame neu
## aufgebaut wird.
class_name Notepad
extends PanelContainer

var game: Node = null
var _last_key := ""
var _body: VBoxContainer = null

func _init(game_node: Node) -> void:
	game = game_node
	custom_minimum_size = Vector2(300, 0)
	var box := UiTheme.panel_box(
		Color(232.0 / 255.0, 226.0 / 255.0, 204.0 / 255.0, 0.94), Color("b9ae8c")
	)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	add_child(_body)

## Die Rolle, deren Zettel gezeigt wird.
func _role_id() -> String:
	var role: String = game.get("dossier_role")
	if role.is_empty():
		var players: Array = (game.get("game") as Dictionary)["players"]
		role = players[0]["id"] if not players.is_empty() else "bouncer"
	return role

func update_notepad() -> void:
	var role_id := _role_id()
	var g: Dictionary = game.get("game")
	var players: Array = g["players"]
	var player: Variant = null
	for p: Dictionary in players:
		if p["id"] == role_id:
			player = p
			break
	if player == null and not players.is_empty():
		player = players[0]

	var station: Variant = game.call("station_for", role_id)
	var guest: Variant = station["guest"] if station != null else null
	var notes: Dictionary = station["notes"] if station != null else Notes.empty_notes()
	var state: Dictionary = g["state"]

	if state["night"] == null or guest == null:
		if _last_key != "empty":
			_last_key = "empty"
			_clear()
			_body.add_child(_head("SCHICHTNOTIZEN"))
			var text := "Schleuse frei." if player != null and player["area"] == "airlock" \
				else "Niemand an der Tür."
			var empty := UiTheme.label(text, 15, Color("6f6754"))
			empty.add_theme_font_override("font", Fonts.hand())
			_body.add_child(empty)
		return

	var solo := GameState.is_solo(state)
	var area := "airlock" if player != null and player["area"] == "airlock" else "outside"

	# Schluessel wie in der Vorlage: nur bei echter Aenderung neu aufbauen.
	var checked_keys: Array = (notes["checked"] as Dictionary).keys()
	checked_keys.sort()
	var topic_keys: Array = (notes["topics"] as Dictionary).keys()
	topic_keys.sort()
	var topic_parts: PackedStringArray = []
	for k: String in topic_keys:
		topic_parts.append(k + str((notes["topics"] as Dictionary)[k]))
	var last_result := ""
	if player != null and player["lastResult"] != null:
		last_result = (player["lastResult"] as Dictionary)["text"]
	var key := "|".join(PackedStringArray([
		String(guest["id"]), str(notes["page"]),
		",".join(PackedStringArray(checked_keys)),
		",".join(topic_parts), last_result,
	]))
	if key == _last_key:
		return
	_last_key = key

	_clear()
	_body.add_child(_tabs(int(notes["page"]), role_id))
	_body.add_child(_guest_line(station, guest))
	if int(notes["page"]) == 0:
		_checklist_page(notes, area, solo, role_id)
	else:
		_finding_page(notes, area, solo, role_id)
	_footer(station, player)

func _clear() -> void:
	for child in _body.get_children():
		child.queue_free()
		_body.remove_child(child)

func _head(text: String) -> Control:
	var l := UiTheme.label(text, 10, Color("8a8067"), 3.0)
	return l

func _tabs(page: int, role_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in 2:
		var name := "CHECKLISTE" if i == 0 else "BEFUND"
		var b := UiTheme.button(name, UiTheme.LINE, 10, 2.0)
		b.add_theme_color_override(
			"font_color", Color("2c2718") if page == i else Color("8a8067")
		)
		var box := UiTheme.panel_box(
			Color(0, 0, 0, 0.1) if page == i else Color(0, 0, 0, 0.03), Color("b9ae8c")
		)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		b.add_theme_stylebox_override("pressed", box)
		var target := i
		b.pressed.connect(func() -> void:
			game.call("act", role_id, "page", {"page": target})
		)
		row.add_child(b)
	return row

func _guest_line(station: Dictionary, guest: Dictionary) -> Control:
	var l := UiTheme.label(_guest_name(station, guest), 19, Color("2c2718"))
	l.add_theme_font_override("font", Fonts.hand())
	return l

static func _guest_name(station: Dictionary, guest: Dictionary) -> String:
	var checks: Dictionary = station["checks"]
	if checks["id"] != null:
		return (checks["id"] as Dictionary)["doc"]["name"]
	if guest.get("doorVerdict", null) != null:
		var doc: Variant = guest.get("doc", null)
		return doc["name"] if doc != null else "Gast"
	return "unbekannt"

## Seite 1: was ich noch pruefen muss - selbst abzuhaken.
func _checklist_page(notes: Dictionary, area: String, solo: bool, role_id: String) -> void:
	var items := Notes.checklist_for(area, solo)
	var checked: Dictionary = notes["checked"]
	var open := 0
	for c: Dictionary in items:
		if not checked.get(c["id"], false):
			open += 1
		_body.add_child(_row(
			"✓" if checked.get(c["id"], false) else "",
			c["label"], "", checked.get(c["id"], false),
			func() -> void: game.call("act", role_id, "check", {"item": c["id"]})
		))
	_body.add_child(_foot_note(
		"alles abgehakt" if open == 0 else "noch %d offen" % open
	))

## Seite 2: mein Befund - entspricht der Norm oder eben nicht.
func _finding_page(notes: Dictionary, area: String, solo: bool, role_id: String) -> void:
	var topics := Notes.topics_for(area, solo)
	var marks: Dictionary = notes["topics"]
	for t: Dictionary in topics:
		var st: Variant = marks.get(t["id"], null)
		var mark := "○"
		var verdict := "—"
		if st == "bad":
			mark = "✗"
			verdict = "entspricht nicht"
		elif st == "ok":
			mark = "✓"
			verdict = "entspricht der Norm"
		_body.add_child(_row(
			mark, "%s  %s" % [t["label"], t["hint"]], verdict, st == "ok",
			func() -> void: game.call("act", role_id, "note", {"topic": t["id"]}),
			st == "bad"
		))
	_body.add_child(_foot_note("Zeile anklicken: Norm · nicht · leer"))

func _row(
	mark: String, text: String, note: String, done: bool, on_click: Callable,
	bad: bool = false
) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(0, 24)
	b.pressed.connect(on_click)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ink := Color("2c2718")
	if bad:
		ink = Color("8c1620")
	elif done:
		ink = Color("3f6b3f")

	var box := UiTheme.label(mark, 16, ink)
	box.add_theme_font_override("font", Fonts.hand())
	box.custom_minimum_size = Vector2(18, 0)
	row.add_child(box)

	var task := UiTheme.label(text, 16, ink)
	task.add_theme_font_override("font", Fonts.hand())
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(task)

	if not note.is_empty():
		var n := UiTheme.label(note, 14, Color(ink.r, ink.g, ink.b, 0.7))
		n.add_theme_font_override("font", Fonts.hand())
		row.add_child(n)

	b.add_child(row)
	return b

func _foot_note(text: String) -> Control:
	var l := UiTheme.label(text, 13, Color("8a8067"))
	l.add_theme_font_override("font", Fonts.hand())
	return l

func _footer(station: Dictionary, player: Variant) -> void:
	var checks: Dictionary = station["checks"]
	if bool(checks["verified"]):
		_body.add_child(_stamp("SECURITY VERIFIED", UiTheme.GREEN))
		return
	if bool(checks["conflict"]):
		_body.add_child(_stamp("CHECK AGAIN", UiTheme.AMBER))
		return
	if player != null and player["lastResult"] != null:
		var result: Dictionary = player["lastResult"]
		var scribble := UiTheme.label(
			result["text"], 15, UiTheme.kind_color(result["kind"]).darkened(0.35)
		)
		scribble.add_theme_font_override("font", Fonts.hand())
		scribble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(scribble)

func _stamp(text: String, color: Color) -> Control:
	var l := UiTheme.label(text, 12, color.darkened(0.2), 3.0)
	return l
