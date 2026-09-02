## Der Ausweis - gross, lesbar und von Hand zu pruefen.
##
## Das Spiel sagt nicht, was falsch ist. Der Spieler vergleicht selbst:
## Foto gegen Gesicht, Name gegen Aussage, Geburtsdatum gegen heute,
## Ablaufdatum gegen heute, Hologramm auf Vollstaendigkeit.
## Ein Klick auf ein Feld schaltet den Status um, den der Spieler vergibt:
##   nichts -> NICHT KORREKT -> IN ORDNUNG -> nichts
## Das Spiel bewertet nichts davon, es notiert nur.
##
## Portierung von src/ui/idcard.js. Das Passfoto zeichnet in der Vorlage ein
## eigenes Canvas; hier uebernimmt das ein kleiner Zeichenknoten, der
## Figure.draw_portrait aufruft.
class_name IdCard
extends PanelContainer

var game: Node = null
var role_id := "bouncer"

var _rendered_for: Variant = null
var _rendered_marks := ""
var _body: VBoxContainer = null

func _init(game_node: Node, initial_role: String = "bouncer") -> void:
	game = game_node
	role_id = initial_role
	custom_minimum_size = Vector2(380, 0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(11.0 / 255.0, 13.0 / 255.0, 18.0 / 255.0, 0.94), UiTheme.LINE
	))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	visible = false

func update_card() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var station: Variant = game.call("station_for", role_id)
	var inspection: Variant = null
	var guest: Variant = null
	if station != null:
		inspection = (station["checks"] as Dictionary)["id"]
		guest = station["guest"]

	if state["night"] == null or inspection == null or guest == null:
		if _rendered_for != null:
			visible = false
			_clear()
			_rendered_for = null
		return

	var talk: Variant = (station["checks"] as Dictionary)["talk"]
	var said: Array = (talk as Dictionary).get("said", []) if talk != null else []
	var marks: Dictionary = inspection["marks"]
	var parts: PackedStringArray = []
	var keys: Array = marks.keys()
	keys.sort()
	for k: String in keys:
		parts.append(k + str(marks[k]))
	var mark_key := "|".join(parts) + "|said%d" % said.size()
	if _rendered_for == guest["id"] and _rendered_marks == mark_key:
		return
	_rendered_for = guest["id"]
	_rendered_marks = mark_key

	visible = true
	_clear()
	_build(guest, inspection, station)

func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _build(guest: Dictionary, inspection: Dictionary, station: Dictionary) -> void:
	var doc: Dictionary = guest["doc"]
	var age := Identity.age_from_birth(doc["birth"])

	# Kopfzeile
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiTheme.label("AUSWEISKONTROLLE", 10, UiTheme.TEXT, 2.5))
	head.add_child(UiTheme.spacer())
	head.add_child(UiTheme.label(
		"HEUTE %s · MINDESTALTER %d" % [Identity.today_string(), int(Config.TUNING["minAge"])],
		8, UiTheme.DIM, 1.0
	))
	_body.add_child(head)
	_body.add_child(UiTheme.separator())

	# Karte: Foto links, Felder rechts
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)

	var photo_button := Button.new()
	photo_button.flat = true
	# Etwas kleiner als frueher: die Karte bleibt schmal genug, dass
	# links der Reiter und rechts die Sprechblase frei bleiben.
	photo_button.custom_minimum_size = Vector2(118, 150)
	photo_button.tooltip_text = "Foto mit dem Gast vergleichen"
	photo_button.pressed.connect(func() -> void:
		game.call("act", role_id, "mark", {"field": "photo"})
	)
	var photo := PortraitRect.new(doc["photoLook"])
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_button.add_child(photo)
	var photo_box := VBoxContainer.new()
	photo_box.add_child(photo_button)
	photo_box.add_child(_field_tag("FOTO", inspection, "photo"))
	card.add_child(photo_box)

	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 4)

	fields.add_child(_static_row(
		"AUSWEIS", "%s · %s" % [doc["issuer"], doc["number"]]
	))
	fields.add_child(_field_row(
		inspection, "name", "NAME", doc["name"],
		"Mit der Aussage des Gastes vergleichen"
	))
	# Manipulierte Jahreszahl: anders eingefaerbt statt versetzt.
	var birth_parts := String(doc["birth"]).split("-")
	var birth_row := _field_row(
		inspection, "birth", "GEBOREN", doc["birth"],
		"Alter berechnen, auf Manipulation achten", "%d J." % age
	)
	if bool(doc["tampered"]):
		_tint_value(birth_row, UiTheme.AMBER)
	fields.add_child(birth_row)
	fields.add_child(_field_row(
		inspection, "expiry", "GÜLTIG BIS", doc["expiry"], "Gegen das heutige Datum prüfen"
	))
	fields.add_child(_holo_row(inspection, bool(doc["marksOk"])))
	card.add_child(fields)
	_body.add_child(card)

	# Aussagen-Protokoll
	var talk: Variant = (station["checks"] as Dictionary)["talk"]
	var said: Array = (talk as Dictionary).get("said", []) if talk != null else []
	if not said.is_empty():
		_body.add_child(UiTheme.separator())
		var more: bool = bool((talk as Dictionary)["moreToSay"])
		_body.add_child(UiTheme.label(
			"AUSSAGEN%s" % (" · REDET NOCH" if more else ""), 9, UiTheme.CYAN, 3.0
		))
		for s: Dictionary in said:
			_body.add_child(UiTheme.body_label("„%s“" % s["text"], 12, UiTheme.TEXT))

	# Fusszeile
	_body.add_child(UiTheme.separator())
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 2)
	var real_name: Variant = (talk as Dictionary)["realName"] if talk != null else null
	if real_name != null:
		foot.add_child(UiTheme.label("GAST SAGT: %s" % real_name, 11, UiTheme.TEXT, 1.0))
	else:
		foot.add_child(UiTheme.label("Namen erfragen: ANSPRECHEN", 10, UiTheme.DIM))
	var claimed := Identity.claimed_faults(inspection)
	if not claimed.is_empty():
		foot.add_child(UiTheme.label(
			"%d FELD(ER) ALS NICHT KORREKT NOTIERT" % claimed.size(), 10, UiTheme.RED, 2.0
		))
	else:
		foot.add_child(UiTheme.label(
			"Feld anklicken: nicht korrekt · in Ordnung · leer", 10, UiTheme.DIM
		))
	_body.add_child(foot)

func _static_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var k := UiTheme.label(key, 9, UiTheme.DIM, 3.0)
	k.custom_minimum_size = Vector2(78, 0)
	row.add_child(k)
	row.add_child(UiTheme.label(value, 12, UiTheme.TEXT))
	return row

## Die Farbe zeigt die Einschaetzung des SPIELERS:
## rot = er haelt das Feld fuer nicht korrekt, gruen = er haelt es fuer in Ordnung.
func _field_row(
	inspection: Dictionary, field: String, key: String, value: String,
	tip: String, extra: String = ""
) -> Control:
	var mark: Variant = (inspection["marks"] as Dictionary).get(field, null)
	var accent := UiTheme.LINE
	var badge := ""
	if mark == "suspect":
		accent = UiTheme.RED
		badge = "NICHT KORREKT"
	elif mark == "fine":
		accent = UiTheme.GREEN
		badge = "IN ORDNUNG"

	var b := Button.new()
	b.flat = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void:
		game.call("act", role_id, "mark", {"field": field})
	)
	if mark != null:
		b.add_theme_stylebox_override("normal", UiTheme.panel_box(
			Color(accent.r, accent.g, accent.b, 0.1), accent
		))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k := UiTheme.label(key, 9, UiTheme.DIM, 3.0)
	k.custom_minimum_size = Vector2(78, 0)
	row.add_child(k)
	var v := UiTheme.label(value, 13, UiTheme.TEXT)
	v.name = "Value"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	if not extra.is_empty():
		row.add_child(UiTheme.label(extra, 11, UiTheme.DIM))
	if not badge.is_empty():
		row.add_child(UiTheme.label(badge, 8, accent, 2.0))
	b.add_child(row)
	return b

func _tint_value(row: Control, color: Color) -> void:
	var value := row.find_child("Value", true, false)
	if value is Label:
		(value as Label).add_theme_color_override("font_color", color)

func _holo_row(inspection: Dictionary, marks_ok: bool) -> Control:
	var mark: Variant = (inspection["marks"] as Dictionary).get("marks", null)
	var accent := UiTheme.LINE
	var badge := ""
	if mark == "suspect":
		accent = UiTheme.RED
		badge = "NICHT KORREKT"
	elif mark == "fine":
		accent = UiTheme.GREEN
		badge = "IN ORDNUNG"

	var b := Button.new()
	b.flat = true
	b.tooltip_text = "Hologramm und Prägung prüfen"
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void:
		game.call("act", role_id, "mark", {"field": "marks"})
	)
	if mark != null:
		b.add_theme_stylebox_override("normal", UiTheme.panel_box(
			Color(accent.r, accent.g, accent.b, 0.1), accent
		))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k := UiTheme.label("MERKMALE", 9, UiTheme.DIM, 3.0)
	k.custom_minimum_size = Vector2(78, 0)
	row.add_child(k)
	for i in 3:
		var holo := ColorRect.new()
		holo.custom_minimum_size = Vector2(22, 12)
		# Vorhanden: schimmerndes Cyan. Fehlend: matt und dunkel.
		holo.color = Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.75) if marks_ok \
			else Color(1, 1, 1, 0.06)
		row.add_child(holo)
	row.add_child(UiTheme.spacer())
	if not badge.is_empty():
		row.add_child(UiTheme.label(badge, 8, accent, 2.0))
	b.add_child(row)
	return b

func _field_tag(text: String, inspection: Dictionary, field: String) -> Control:
	var mark: Variant = (inspection["marks"] as Dictionary).get(field, null)
	var color := UiTheme.DIM
	if mark == "suspect":
		color = UiTheme.RED
	elif mark == "fine":
		color = UiTheme.GREEN
	var l := UiTheme.label(text, 9, color, 3.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Das Passfoto: Portrait plus Druckraster, wie in der Vorlage.
class PortraitRect extends Control:
	var look: Dictionary = {}

	func _init(photo_look: Dictionary) -> void:
		look = photo_look
		# In der Vorlage ist das Foto ein eigenes <canvas>; was ueber den Rand
		# hinausgeht (die Schultern), faellt dort einfach weg.
		clip_contents = true

	func _draw() -> void:
		Figure.draw_portrait(self, look, size.x, size.y)
		# Rasterung wie bei einem gedruckten Passfoto
		var line := Color(0, 0, 0, 0.16)
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, 1), line)
			y += 3.0
