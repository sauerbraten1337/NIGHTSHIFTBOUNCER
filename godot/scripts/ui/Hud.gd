## HUD: Schichtplan (Gaeste), Geld/Ruf/Schlange, Aktionsleisten, die grossen
## Entscheidungs-Knoepfe unten in der Mitte, Tutorial, Toasts.
##
## Bewusst NICHT im HUD: der Tages-Timer (die Schicht endet, wenn die
## Gaesteliste abgearbeitet ist), Belegung des Clubs, Ausbaustufe und die alte
## Uebersichtskarte - das steht jetzt alles auf dem Notizzettel bzw. gar nicht.
##
## Portierung von src/ui/hud.js zusammen mit dem HUD-Teil von index.html: die
## Vorlage findet ihre Elemente per getElementById, hier baut der Knoten sie
## selbst auf.
class_name Hud
extends CanvasLayer

const DECISION_CODES := ["admit", "reject", "pass"]

var game: Node = null

var _root: Control = null
var _clock: Label = null
var _shift_label: Label = null
var _phase: Label = null
var _club: Label = null
var _status: Label = null
var _night_bar: UiTheme.Meter = null
var _money: Label = null
var _rep: Label = null
var _rep_bar: UiTheme.Meter = null
var _queue: Label = null
## Der Weg in den Club - waehrend der Schicht die Pause, und der einzige Weg
## zum Feierabend.
var _club_button: Button = null
var _effects: VBoxContainer = null
var _toasts: VBoxContainer = null
var _bar1: HBoxContainer = null
var _bar2: HBoxContainer = null
var _decisions: HBoxContainer = null
var _net: Label = null
var _notepad: Notepad = null

# Tutorial-Kasten
var _tutorial: PanelContainer = null
var _tut_step: Label = null
var _tut_title: Label = null
var _tut_body: Label = null
var _tut_hint: Label = null

var _built_for := ""
var _last_toast_key := ""
var _last_tutorial := ""
## Die Aktionsknoepfe, um sie je Frame umfaerben zu koennen.
var _action_buttons: Array = []   # { button, icon, code, role }
var _decision_buttons: Array = [] # { button, code, role }

func _init(game_node: Node) -> void:
	game = game_node
	layer = 1
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top()
	_build_tutorial()
	_build_toasts()
	_build_bottom()

	# Der Block liegt unten rechts und waechst nach oben, so weit die Liste
	# reicht - in der Web-Fassung macht das `bottom: 116px` mit automatischer
	# Hoehe. Dafuer haengen alle vier Anker im selben Punkt und die
	# Wachstumsrichtung zeigt nach oben links.
	_notepad = Notepad.new(game)
	_notepad.anchor_left = 1.0
	_notepad.anchor_top = 1.0
	_notepad.anchor_right = 1.0
	_notepad.anchor_bottom = 1.0
	_notepad.offset_right = -30
	_notepad.offset_bottom = -116
	_notepad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notepad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notepad.custom_minimum_size = Vector2(296, 0)
	_root.add_child(_notepad)

	_net = UiTheme.label("", 11, UiTheme.CYAN, 2.0)
	_net.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_net.offset_top = 96
	_net.visible = false
	_root.add_child(_net)

	hide_hud()

func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 24
	top.add_theme_constant_override("separation", 16)
	_root.add_child(top)

	# links: Schichtplan
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock = UiTheme.label("0/0", 30, UiTheme.TEXT, 2.0, true)
	_shift_label = UiTheme.sub_label("Gäste auf der Liste")
	_phase = UiTheme.sub_label("Opening")
	left.add_child(_clock)
	left.add_child(_shift_label)
	left.add_child(_phase)

	# Jederzeit rein in den eigenen Club: die Nacht steht dort still, und von
	# dort wird auch der Tag beendet. Online geht das nicht - der Host
	# simuliert weiter (siehe Game.club_break_allowed()).
	_club_button = UiTheme.button("IN DEN CLUB", UiTheme.AMBER, 9, 3.0)
	_club_button.custom_minimum_size = Vector2(150, 26)
	_club_button.pressed.connect(func() -> void:
		if bool(game.call("club_break_allowed")):
			game.call("go_club", true)
	)
	var club_row := HBoxContainer.new()
	club_row.add_child(_club_button)
	left.add_child(club_row)
	top.add_child(left)

	# Mitte: Clubname, Nacht, Fortschritt
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_club = UiTheme.label(Config.CLUB_NAME, 20, Color(1, 1, 1), 10.0, true)
	_club.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status = UiTheme.sub_label("Night 01")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_bar = UiTheme.meter(240.0, 3.0)
	_night_bar.fill_color = UiTheme.RED
	_night_bar.fill_to = UiTheme.AMBER
	center.add_child(_club)
	center.add_child(_status)
	center.add_child(_night_bar)
	top.add_child(center)

	# rechts: Geld, Ruf, Schlange
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	_money = _stat_row(right, "GELD")
	var rep_row := HBoxContainer.new()
	rep_row.alignment = BoxContainer.ALIGNMENT_END
	rep_row.add_theme_constant_override("separation", 10)
	rep_row.add_child(UiTheme.label("RUF", 9, UiTheme.DIM, 3.0))
	_rep = UiTheme.label("0", 17, UiTheme.TEXT)
	rep_row.add_child(_rep)
	right.add_child(rep_row)
	_rep_bar = UiTheme.meter(110.0, 3.0)
	var rep_wrap := HBoxContainer.new()
	rep_wrap.alignment = BoxContainer.ALIGNMENT_END
	rep_wrap.add_child(_rep_bar)
	right.add_child(rep_wrap)
	_queue = _stat_row(right, "SCHLANGE")

	_effects = VBoxContainer.new()
	_effects.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_effects)
	top.add_child(right)

func _stat_row(parent: Control, key: String) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	var value := UiTheme.label("0", 17, UiTheme.TEXT)
	row.add_child(value)
	parent.add_child(row)
	return value

func _build_tutorial() -> void:
	_tutorial = UiTheme.panel()
	# Mittig oben wie `.tutorial` in styles/ui.css - links unten liegt
	# der Ausweis, der reicht bei langen Aussagen weit nach oben.
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tutorial.offset_left = -210
	_tutorial.offset_right = 210
	_tutorial.offset_top = 108
	_tutorial.custom_minimum_size = Vector2(420, 0)
	_tutorial.visible = false
	_root.add_child(_tutorial)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_tut_step = UiTheme.label("", 9, UiTheme.CYAN, 3.0)
	_tut_title = UiTheme.label("", 16, UiTheme.TEXT, 2.0, true)
	_tut_body = UiTheme.body_label("", 12, UiTheme.TEXT)
	_tut_body.custom_minimum_size = Vector2(396, 0)
	_tut_hint = UiTheme.label("", 11, UiTheme.AMBER, 2.0)
	box.add_child(_tut_step)
	box.add_child(_tut_title)
	box.add_child(_tut_body)
	box.add_child(_tut_hint)
	_tutorial.add_child(box)

func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 120
	_toasts.offset_left = -220
	_toasts.offset_right = 220
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

func _build_bottom() -> void:
	_decisions = HBoxContainer.new()
	_decisions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_decisions.offset_top = -172
	_decisions.offset_bottom = -102
	_decisions.offset_left = -420
	_decisions.offset_right = 420
	_decisions.alignment = BoxContainer.ALIGNMENT_CENTER
	_decisions.add_theme_constant_override("separation", 18)
	_root.add_child(_decisions)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -96
	bottom.offset_bottom = -12
	_root.add_child(bottom)

	_bar1 = HBoxContainer.new()
	_bar1.add_theme_constant_override("separation", 8)
	_bar1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_bar1)

	_bar2 = HBoxContainer.new()
	_bar2.add_theme_constant_override("separation", 8)
	_bar2.alignment = BoxContainer.ALIGNMENT_END
	_bar2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_bar2)

# ---------------- Aufbau der Leisten ----------------

func rebuild() -> void:
	_built_for = ""

func _build_bars() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var key := "%s|%s" % [state["mode"], game.get("local_role")]
	if _built_for == key:
		return
	_built_for = key

	for node in [_bar1, _bar2, _decisions]:
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
	_action_buttons.clear()
	_decision_buttons.clear()

	var controlled := 0
	for player: Dictionary in (g["players"] as Array):
		if bool(game.call("controls", player["id"])):
			controlled += 1

	for player: Dictionary in (g["players"] as Array):
		if not bool(game.call("controls", player["id"])):
			continue
		var airlock: bool = player["area"] == "airlock"
		var container := _bar2 if airlock else _bar1
		var accent := UiTheme.CYAN if airlock else UiTheme.RED
		var role: Dictionary = player["role"]

		# Kontrollen als Icon-Knoepfe. Die Tastenbelegung steht nicht mehr im
		# Bild - die steht komplett im Pausenmenue.
		for action: Dictionary in (role["actions"] as Array):
			if DECISION_CODES.has(action["code"]):
				continue
			container.add_child(_action_button(player["id"], action, accent))

		# Entscheidungen wandern in die Mitte - gross und anklickbar.
		var group := VBoxContainer.new()
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_theme_constant_override("separation", 4)
		if controlled > 1:
			var role_label := UiTheme.label(role["label"], 9, accent, 3.0)
			role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			group.add_child(role_label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for action: Dictionary in (role["actions"] as Array):
			if not DECISION_CODES.has(action["code"]):
				continue
			row.add_child(_decision_button(player["id"], action))
		group.add_child(row)
		_decisions.add_child(group)

func _action_button(role_id: String, action: Dictionary, accent: Color) -> Control:
	var built := UiTheme.icon_button(action["code"], action["label"], accent, 76.0, 28.0)
	var b: Button = built["button"]
	b.pressed.connect(func() -> void: game.call("act", role_id, action["code"]))

	_action_buttons.append({
		"button": b, "icon": built["icon"], "name": built["label"],
		"code": action["code"], "role": role_id, "accent": accent,
	})
	return b

func _decision_button(role_id: String, action: Dictionary) -> Control:
	var yes: bool = action["code"] != "reject"
	var accent := UiTheme.GREEN if yes else UiTheme.RED
	# Kompakter Knopf mit eigener Zeichnung:
	# abgeschraegten Ecken, Lichtkante oben und Schein beim Ueberfahren.
	var b := DecisionButton.new(accent)
	# Flacher Zuschnitt: das Icon steht mittig ueber der Beschriftung.
	b.custom_minimum_size = Vector2(116, 62)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: game.call("act", role_id, action["code"]))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := Icons.icon_node(action["code"], 22.0, accent)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	# Lange Beschriftungen wie ZURÜCKSCHICKEN passen nur kleiner hinein.
	var label_text := String(action["label"])
	var text_size := 11 if label_text.length() <= 10 else 9
	var text := UiTheme.label(label_text, text_size, accent, 3.0 if text_size == 11 else 1.5)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.clip_text = true
	col.add_child(text)
	b.add_child(col)

	_decision_buttons.append({"button": b, "code": action["code"], "role": role_id})
	return b

## EINLASSEN / ABWEISEN: schraege Ecken, farbige Lichtkante, Schein beim
## Ueberfahren. Gegenstueck zu `.dec` in styles/ui.css.
class DecisionButton extends Button:
	var accent := UiTheme.GREEN

	func _init(color: Color) -> void:
		accent = color
		flat = true
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cut := 14.0
		var lit := is_hovered() and not disabled
		var alpha := 0.3 if disabled else 1.0

		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(w, 0), Vector2(w, h - cut),
			Vector2(w - cut, h), Vector2(0, h), Vector2(0, cut),
		])
		# Fuellung: oben die Farbe der Entscheidung, unten fast schwarz.
		var top := Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.94 * alpha)
		var bottom := Color(0.04, 0.05, 0.06, 0.94 * alpha)
		Draw2D.gradient_polygon(self, shape, PackedColorArray([
			top, top, bottom, bottom, bottom, top,
		]))

		var edge := Color(accent.r, accent.g, accent.b, (0.9 if lit else 0.5) * alpha)
		draw_polyline(PackedVector2Array([
			Vector2(cut, 0.5), Vector2(w - 0.5, 0.5), Vector2(w - 0.5, h - cut),
			Vector2(w - cut, h - 0.5), Vector2(0.5, h - 0.5), Vector2(0.5, cut),
			Vector2(cut, 0.5),
		]), edge, 1.0)
		# Lichtkante oben - sie macht den Knopf zur Taste.
		draw_rect(Rect2(cut, 0, w - cut, 2.0),
			Color(accent.r, accent.g, accent.b, (1.0 if lit else 0.55) * alpha))
		if lit:
			# Schein nach aussen, solange der Zeiger darauf liegt.
			for i in 4:
				var g := float(i + 1)
				draw_rect(Rect2(-g, -g, w + g * 2.0, h + g * 2.0),
					Color(accent.r, accent.g, accent.b, 0.06), false, 1.0)

# ---------------- Aktualisierung ----------------

func update_hud() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var night: Variant = state["night"]
	_build_bars()

	_money.text = "€%s" % UiTheme.money_text(float(state["money"]))
	var rep := float(state["reputation"])
	_rep.text = str(int(round(rep)))
	_rep_bar.fill_color = UiTheme.GREEN if rep > 66.0 else (
		UiTheme.CYAN if rep > 33.0 else UiTheme.RED
	)
	_rep_bar.set_value(rep / 100.0)

	if _club_button != null:
		_club_button.visible = bool(game.call("club_break_allowed"))

	if night == null:
		return

	# Kein Timer mehr: die Schicht misst sich in Gaesten, nicht in Minuten.
	var quota := int(night.get("quota", 0))
	var done := mini(int(night.get("processed", 0)), quota)
	_clock.text = "%d/%d" % [done, quota]
	var phase := NightCycle.current_phase(float(done) / quota if quota > 0 else 0.0)
	_phase.text = "%s · %s" % [phase["label"], Reputation.rep_band(rep)]
	var event_label := ""
	if night["event"] != null:
		event_label = (night["event"] as Dictionary)["label"]
	_status.text = "NIGHT %s · %s" % [str(state["nightIndex"]).pad_zeros(2), event_label]
	_night_bar.set_value(float(done) / quota if quota > 0 else 0.0)
	var queue_len: int = int(night["queueLength"]) if night.has("queueLength") \
		else (night["queue"] as Array).size()
	_queue.text = str(queue_len)

	_update_effects(night)
	_update_toasts(night)
	_update_tutorial(night)
	_notepad.update_notepad()
	_update_action_bars()
	_update_decisions()

func _update_effects(night: Dictionary) -> void:
	for child in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	for e: Dictionary in (night.get("activeEffects", []) as Array):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiTheme.label(e["label"], 9, UiTheme.AMBER, 2.0))
		row.add_child(UiTheme.label("%ds" % int(ceil(float(e["remaining"]))), 9, UiTheme.DIM))
		_effects.add_child(row)

func _update_toasts(night: Dictionary) -> void:
	var toasts: Array = night.get("toasts", [])
	var parts: PackedStringArray = []
	for t: Dictionary in toasts:
		parts.append(t["text"])
	var key := "|".join(parts)
	if key == _last_toast_key:
		return
	_last_toast_key = key

	for child in _toasts.get_children():
		_toasts.remove_child(child)
		child.queue_free()
	for t: Dictionary in toasts:
		var panel := UiTheme.panel(
			Color(4.0 / 255.0, 5.0 / 255.0, 8.0 / 255.0, 0.86),
			UiTheme.kind_color(t["kind"])
		)
		var l := UiTheme.label(t["text"], 11, UiTheme.kind_color(t["kind"]), 2.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(l)
		_toasts.add_child(panel)

func _update_tutorial(night: Dictionary) -> void:
	var tut: Variant = night.get("tutorial", null)
	var step: Variant = (tut as Dictionary)["step"] if tut != null else null
	if step == null:
		_tutorial.visible = false
		_last_tutorial = ""
		return
	var key := "%s|%s" % [step["id"], step["title"]]
	if _last_tutorial == key:
		return
	_last_tutorial = key
	_tutorial.visible = true
	_tut_step.text = "TUTORIAL · SCHRITT %d/%d" % [int(step["index"]) + 1, int(step["total"])]
	_tut_title.text = step["title"]
	_tut_body.text = step["body"]
	var hint: Variant = step["hint"]
	if hint != null:
		_tut_hint.visible = true
		_tut_hint.text = "TASTE %s — %s" % [(hint as Array)[0], (hint as Array)[1]]
	else:
		_tut_hint.visible = false

func _update_action_bars() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	if state["night"] == null:
		return

	for entry: Dictionary in _action_buttons:
		var code: String = entry["code"]
		var player: Variant = null
		for p: Dictionary in (g["players"] as Array):
			if p["id"] == entry["role"]:
				player = p
				break
		if player == null:
			continue
		var station: Variant = game.call("station_for", entry["role"])
		var checks: Variant = station["checks"] if station != null else null
		var has_guest: bool = station != null and station["guest"] != null

		var done := false
		if checks != null:
			var c := checks as Dictionary
			done = (code == "id" and c["id"] != null) \
				or (code == "alcohol" and c["alcohol"] != null) \
				or (code == "search" and station["patdown"] != null
					and bool((station["patdown"] as Dictionary)["complete"]))
		# Waehrend eines Uebergriffs ist alles gesperrt - es zaehlt nur die Abwehr.
		var attacked: bool = station != null and station["aggro"] != null
		var unlocks: Dictionary = state["unlocks"]
		var locked: bool = (unlocks.has(code) and unlocks[code] == false) or attacked
		var active: bool = float(player["busy"]) > 0.0 and _is_for(player, code)

		var b: Button = entry["button"]
		var icon: Icons.IconRect = entry["icon"]
		b.disabled = locked
		var accent: Color = entry["accent"]
		if locked:
			icon.set_color(Color(UiTheme.DIM.r, UiTheme.DIM.g, UiTheme.DIM.b, 0.4))
		elif done:
			icon.set_color(UiTheme.GREEN)
		elif active:
			icon.set_color(Color(1, 1, 1))
		elif has_guest:
			icon.set_color(accent)
		else:
			icon.set_color(Color(accent.r, accent.g, accent.b, 0.45))

func _update_decisions() -> void:
	for entry: Dictionary in _decision_buttons:
		var station: Variant = game.call("station_for", entry["role"])
		var guest: Variant = station["guest"] if station != null else null
		var open: bool = station != null and station["patdown"] != null \
			and (station["patdown"] as Dictionary)["active"] != null
		var attacked: bool = station != null and station["aggro"] != null
		var button := entry["button"] as Button
		var blocked: bool = guest == null or open or attacked
		if button.disabled != blocked:
			button.disabled = blocked
			button.queue_redraw()
		button.modulate = Color(1, 1, 1, 0.35 if blocked else 1.0)

static func _is_for(player: Dictionary, code: String) -> bool:
	var pending: Variant = player["pending"]
	if pending == null:
		return false
	var key: String = (pending as Dictionary)["key"]
	if code == "search":
		return key == "search" or key == "bag"
	return key == code

# ---------------- Sichtbarkeit ----------------

## Die Flaeche, auf der die Handstuecke liegen: Ausweis, Kontrolltisch,
## Hausordnung. In der Web-Fassung sind das Kinder von #hud - sie tauchen
## also mit der Leiste zusammen auf und verschwinden mit ihr.
func overlay_root() -> Control:
	return _root

func show_hud() -> void:
	_root.visible = true

func hide_hud() -> void:
	_root.visible = false

func set_net(text: String, bad: bool = false) -> void:
	if text.is_empty():
		_net.visible = false
		return
	_net.text = text
	_net.add_theme_color_override("font_color", UiTheme.RED if bad else UiTheme.CYAN)
	_net.visible = true
