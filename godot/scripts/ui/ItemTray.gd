## Der Kontrolltisch: alles, was aus einer Zone kommt, liegt gross vor dir.
## Kaugummi neben Klinge - du markierst selbst, was nicht reindarf (nochmal
## klicken nimmt die Markierung zurueck) und schliesst die Zone dann ab.
## Ob deine Auswahl stimmt, sagt dir hier niemand.
##
## Portierung von src/ui/itemtray.js. Die Gegenstandsbilder zeichnet in der
## Vorlage je ein Canvas; hier ist es ein kleiner Zeichenknoten je Karte, der
## Items.draw_item_icon aufruft.
class_name ItemTray
extends PanelContainer

var game: Node = null
var role_id := "security"

var _rendered_key := ""
var _body: VBoxContainer = null
var _grid: HFlowContainer = null

func _init(game_node: Node, initial_role: String = "security") -> void:
	game = game_node
	role_id = initial_role
	custom_minimum_size = Vector2(520, 0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(11.0 / 255.0, 13.0 / 255.0, 18.0 / 255.0, 0.94), UiTheme.CYAN
	))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	visible = false

func update_tray() -> void:
	var station: Variant = game.call("station_for", role_id)
	var pat: Variant = station["patdown"] if station != null else null
	var zone_id: Variant = (pat as Dictionary)["active"] if pat != null else null
	var zone: Variant = null
	if zone_id != null:
		zone = ((pat as Dictionary)["zones"] as Dictionary)[zone_id]

	# Bei einem Uebergriff hat niemand Zeit fuer den Kontrolltisch.
	var attacked: bool = station != null and station["aggro"] != null
	if zone == null or zone["state"] != "open" or attacked:
		if not _rendered_key.is_empty():
			visible = false
			_clear()
			_rendered_key = ""
		return

	var flagged: Array = zone["flagged"]
	var items: Array = zone["items"]
	var guest_id := ""
	if station["guest"] != null:
		guest_id = (station["guest"] as Dictionary)["id"]
	var key := "%s|%s|%d|%s" % [
		guest_id, zone_id, items.size(), ",".join(PackedStringArray(flagged)),
	]
	if key == _rendered_key:
		return
	_rendered_key = key

	visible = true
	_clear()
	_build(zone, items, flagged, zone_id)

func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _build(zone: Dictionary, items: Array, flagged: Array, zone_id: String) -> void:
	var solo := GameState.is_solo((game.get("game") as Dictionary)["state"])

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.add_child(UiTheme.label("%s — INHALT" % zone["label"], 11, UiTheme.CYAN, 3.0))
	head.add_child(UiTheme.label(
		"Markiere selbst, was nicht in den Club darf.", 10, UiTheme.DIM
	))
	_body.add_child(head)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	for i in items.size():
		var item: Dictionary = items[i]
		_grid.add_child(_card(item, i, solo, flagged.has(item["id"]), zone_id))
	_body.add_child(_grid)

	var close_label := "ZONE ABSCHLIESSEN — %s" % (
		"%d BEANSTANDET" % flagged.size() if not flagged.is_empty() else "NICHTS BEANSTANDET"
	)
	if solo:
		close_label = "[0] " + close_label
	var close := UiTheme.button(close_label, UiTheme.GREEN, 11, 2.0)
	close.pressed.connect(func() -> void:
		game.call("act", role_id, "closezone", {"zone": zone_id})
	)
	_body.add_child(close)

func _card(item: Dictionary, index: int, show_keys: bool, flagged: bool, zone_id: String) -> Control:
	var b := UiTheme.button("", UiTheme.AMBER if flagged else UiTheme.LINE, 9, 1.0)
	b.custom_minimum_size = Vector2(110, 132)
	b.tooltip_text = item["label"]
	b.pressed.connect(func() -> void:
		game.call("act", role_id, "pick", {"zone": zone_id, "itemId": item["id"]})
	)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 2)

	var icon := ItemIcon.new(item["id"], 84.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var label := UiTheme.label(item["label"], 9, UiTheme.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)

	if flagged:
		var flag := UiTheme.label("BEANSTANDET", 8, UiTheme.AMBER, 1.0)
		flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(flag)
	elif show_keys and index < 9:
		var key := UiTheme.label(str(index + 1), 8, UiTheme.DIM)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(key)

	b.add_child(box)
	return b

## Ein Gegenstandsbild als eigener Zeichenknoten.
class ItemIcon extends Control:
	var item_id := ""

	func _init(id: String, icon_size: float) -> void:
		item_id = id
		custom_minimum_size = Vector2(icon_size, icon_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Items.draw_item_icon(self, item_id, minf(size.x, size.y), Vector2.ZERO, Fonts.mono())
