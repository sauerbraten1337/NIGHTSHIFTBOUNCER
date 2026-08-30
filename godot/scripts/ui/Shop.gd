## Der Laptop im Buero: NIGHT//OS.
##
## Statt einer langen Liste ist der Einkauf ein kleines Betriebssystem auf
## einem Laptop-Bildschirm - mit Wallpaper, Menueleiste, Dock und Fenstern.
## Vier Programme: AUSBAU (Upgrades), TALENTE, BOOKING (Acts) und AKTE
## (Status des Clubs). Die Upgrades sind nach Bereichen sortiert, lassen sich
## filtern, durchsuchen und nach Empfehlung, Preis, Fortschritt oder Name
## ordnen.
##
## Portierung von src/ui/shop.js.
class_name Shop
extends Control

## Der Startbildschirm laeuft nur einmal pro Sitzung - sonst nervt er.
static var _boot_shown := false

## Reihenfolge und Farbe der Upgrade-Bereiche. Die Gruppen stehen in
## data/Config.gd; hier bekommen sie Rang, Farbe und Symbol.
const GROUPS := [
	{"id": "Sicherheit", "color": "ff2f3c", "icon": "shield",
		"note": "Kontrolle, Team und Technik an der Tür."},
	{"id": "Eingang", "color": "ffb638", "icon": "door",
		"note": "Wie schnell und wie viele reinkommen."},
	{"id": "Technik", "color": "39d7ff", "icon": "wave",
		"note": "Licht und Sound - der Grund, warum sie kommen."},
	{"id": "Innenbereich", "color": "8b5cff", "icon": "floor",
		"note": "Fläche, Bar, VIP und Backstage."},
	{"id": "Komfort", "color": "4ce08a", "icon": "heart",
		"note": "Kleinkram, der den Ruf hebt."},
]

const SORTS := [
	{"id": "empfohlen", "label": "EMPFOHLEN"},
	{"id": "preis", "label": "PREIS"},
	{"id": "fortschritt", "label": "FORTSCHRITT"},
	{"id": "name", "label": "NAME"},
]

var game: Node = null
var on_next := Callable()

# Ansicht (entspricht `view` in der Vorlage)
var _app := "upgrades"
var _group := "alle"
var _sort := "empfohlen"
var _only_affordable := false
var _query := ""
var _flash := ""

var _wall: WallpaperNode = null
var _bar: HBoxContainer = null
var _dock: VBoxContainer = null
var _window_body: VBoxContainer = null
var _window_head: HBoxContainer = null
var _clock: Label = null
var _toast: Label = null
var _boot: PanelContainer = null
var _want_boot := false
var _dock_buttons: Array = []

static func build(game_node: Node, next: Callable) -> Control:
	var shop := Shop.new()
	shop.game = game_node
	shop.on_next = next
	shop._build_shell()
	shop._paint()
	return shop

func _init() -> void:
	custom_minimum_size = Vector2(1280, 720)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

static func _group_meta(id: String) -> Dictionary:
	for i in GROUPS.size():
		var g: Dictionary = GROUPS[i]
		if g["id"] == id:
			var out := g.duplicate()
			out["order"] = i
			return out
	return {"id": id, "color": "8b93a1", "icon": "box", "note": "", "order": 99}

# ---------------- Gehaeuse ----------------

func _build_shell() -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var accent := Desktop.tier_color(int(GameState.club_tier(state)["level"]))

	_wall = WallpaperNode.new(game)
	_wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_wall)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 14
	top.add_theme_constant_override("separation", 14)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 6)
	brand.add_child(Icons.os_icon("logo", 18.0, accent))
	brand.add_child(UiTheme.label("NIGHT//OS", 13, UiTheme.TEXT, 3.0, true))
	brand.add_child(UiTheme.label("v3.1", 9, UiTheme.DIM, 1.0))
	top.add_child(brand)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 14)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_bar)

	_clock = UiTheme.label("--:--", 13, UiTheme.TEXT, 2.0)
	top.add_child(_clock)
	add_child(top)

	var desk := HBoxContainer.new()
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.offset_left = 20
	desk.offset_right = -20
	desk.offset_top = 56
	desk.offset_bottom = -46
	desk.add_theme_constant_override("separation", 12)
	add_child(desk)

	_dock = VBoxContainer.new()
	_dock.custom_minimum_size = Vector2(112, 0)
	_dock.add_theme_constant_override("separation", 6)
	desk.add_child(_dock)
	_build_dock(accent)

	var window := PanelContainer.new()
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.9),
		Color(accent.r, accent.g, accent.b, 0.45)
	))
	var window_box := VBoxContainer.new()
	window_box.add_theme_constant_override("separation", 8)
	_window_head = HBoxContainer.new()
	_window_head.add_theme_constant_override("separation", 8)
	window_box.add_child(_window_head)
	window_box.add_child(UiTheme.separator())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window_body = VBoxContainer.new()
	_window_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_window_body)
	window_box.add_child(scroll)
	window.add_child(window_box)
	desk.add_child(window)

	# Statusleiste
	var task := HBoxContainer.new()
	task.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	task.offset_left = 20
	task.offset_right = -20
	task.offset_top = -34
	task.offset_bottom = -12
	task.add_theme_constant_override("separation", 12)
	task.add_child(Icons.os_icon("disk", 14.0, UiTheme.DIM))
	task.add_child(UiTheme.label("NULLWERK · CLUBVERWALTUNG", 9, UiTheme.DIM, 2.0))
	_toast = UiTheme.label("", 10, UiTheme.CYAN, 2.0)
	_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task.add_child(_toast)
	task.add_child(UiTheme.label(
		"[1][2][3][4] Programme · [ESC] zurück ins Büro", 9, UiTheme.DIM, 1.0
	))
	add_child(task)

	# Kurzer Startbildschirm - schnell genug, dass niemand wartet. Er braucht
	# Zeitgeber, also erst wenn der Knoten im Baum haengt (siehe _ready).
	if not _boot_shown:
		_boot_shown = true
		_want_boot = true

	_update_clock()
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(_update_clock)
	add_child(timer)

func _ready() -> void:
	if _want_boot:
		_want_boot = false
		_play_boot()

func _build_dock(accent: Color) -> void:
	_dock_buttons.clear()
	for child in _dock.get_children():
		_dock.remove_child(child)
		child.queue_free()

	var apps := _apps()
	for i in apps.size():
		var a: Dictionary = apps[i]
		var b := UiTheme.button("", accent, 9, 1.0)
		b.custom_minimum_size = Vector2(0, 62)
		b.pressed.connect(func() -> void:
			_app = a["id"]
			_flash = ""
			((game.get("game") as Dictionary)["bus"] as Bus).emit("sfx", "ok")
			_paint()
		)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon := Icons.os_icon(a["icon"], 20.0, accent)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(icon)
		var name := UiTheme.label(a["dock"], 9, UiTheme.TEXT, 1.0)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name)
		var num := UiTheme.label(str(i + 1), 8, UiTheme.DIM)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(num)
		b.add_child(col)
		_dock.add_child(b)
		_dock_buttons.append({"button": b, "id": a["id"]})

	_dock.add_child(UiTheme.spacer())

	var save := UiTheme.button("SICHERN", UiTheme.GREEN, 9, 1.0)
	save.pressed.connect(func() -> void:
		game.call("save")
		_show_toast("SPIELSTAND GESICHERT")
	)
	_dock.add_child(save)

	var quit := UiTheme.button("BÜRO", UiTheme.RED, 9, 1.0)
	quit.pressed.connect(func() -> void:
		if on_next.is_valid():
			on_next.call()
	)
	_dock.add_child(quit)

## Tastatur: 1-4 wechselt das Programm, ESC geht zurueck ins Buero.
func _gui_input(event: InputEvent) -> void:
	_handle_key(event)

func _unhandled_key_input(event: InputEvent) -> void:
	_handle_key(event)

func _handle_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		if on_next.is_valid():
			on_next.call()
		accept_event()
		return
	var apps := _apps()
	var n := key.keycode - KEY_0
	if n >= 1 and n <= apps.size():
		_app = apps[n - 1]["id"]
		_paint()
		accept_event()

func _update_clock() -> void:
	var now := Time.get_time_dict_from_system()
	_clock.text = "%s:%s" % [str(now["hour"]).pad_zeros(2), str(now["minute"]).pad_zeros(2)]

var _toast_timer: SceneTreeTimer = null

## Kurze Meldung in der Statusleiste unten.
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_timer = get_tree().create_timer(2.6)
	var expected := text
	_toast_timer.timeout.connect(func() -> void:
		if _toast != null and _toast.text == expected:
			_toast.text = ""
	)

const BOOT_LINES := [
	"NIGHT//OS 3.1 — NULLWERK SYSTEMS",
	"speicher geprüft ......... ok",
	"türsteher-profil geladen . ok",
	"clubakte entschlüsselt ... ok",
	"verbindung zur bank ...... ok",
	"willkommen zurück.",
]

func _play_boot() -> void:
	_boot = PanelContainer.new()
	_boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot.add_theme_stylebox_override("panel", UiTheme.panel_box(
		Color(2.0 / 255.0, 3.0 / 255.0, 5.0 / 255.0, 1.0), Color(0, 0, 0, 0)
	))
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 4)
	_boot.add_child(lines)
	add_child(_boot)

	for i in BOOT_LINES.size():
		var delay := i * 0.13
		var text: String = BOOT_LINES[i]
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(lines):
				lines.add_child(UiTheme.label(text, 12, UiTheme.GREEN, 2.0))
		)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(_boot):
			_boot.queue_free()
			_boot = null
	)

# ---------------- Programme ----------------

func _apps() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"id": "upgrades", "dock": "AUSBAU", "icon": "wrench", "title": "AUSBAU.EXE",
			"subtitle": "Was gebaut wird, sieht man an der Tür"},
		{"id": "talents", "dock": "TALENTE", "icon": "spark", "title": "TALENTE.EXE",
			"subtitle": "Was du selbst besser kannst"},
	]
	if bool(Config.FEATURES["artists"]):
		list.append({"id": "acts", "dock": "BOOKING", "icon": "note", "title": "BOOKING.EXE",
			"subtitle": "Wer heute Nacht spielt"})
	list.append({"id": "akte", "dock": "AKTE", "icon": "folder", "title": "CLUBAKTE.DAT",
		"subtitle": "Der Stand der Dinge"})
	return list

func _app_by_id(id: String) -> Dictionary:
	var apps := _apps()
	for a: Dictionary in apps:
		if a["id"] == id:
			return a
	return apps[0]

## Nur das Fenster und die Anzeigen neu bauen - das Wallpaper laeuft weiter.
func _paint() -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var accent := Desktop.tier_color(int(GameState.club_tier(state)["level"]))
	var app := _app_by_id(_app)

	for child in _window_head.get_children():
		_window_head.remove_child(child)
		child.queue_free()
	_window_head.add_child(Icons.os_icon(app["icon"], 18.0, accent))
	_window_head.add_child(UiTheme.label(app["title"], 13, UiTheme.TEXT, 2.0, true))
	_window_head.add_child(UiTheme.label(app["subtitle"], 10, UiTheme.DIM))
	_window_head.add_child(UiTheme.spacer())
	_window_head.add_child(UiTheme.label("~/nightos/%s" % app["id"], 9, UiTheme.DIM))

	for child in _window_body.get_children():
		_window_body.remove_child(child)
		child.queue_free()
	match app["id"]:
		"upgrades": _upgrades_body()
		"talents": _talents_body()
		"acts": _acts_body()
		_: _akte_body()

	_paint_status(accent)
	for entry: Dictionary in _dock_buttons:
		(entry["button"] as Button).button_pressed = entry["id"] == _app

## Die Werte oben: Geld, Ruf, Stufe, Punkte.
func _paint_status(accent: Color) -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var tier := GameState.club_tier(state)
	for child in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	_bar.add_child(_chip(
		"coin", "€%s" % UiTheme.money_text(float(state["money"])), "", UiTheme.AMBER
	))
	_bar.add_child(_chip("star", str(int(round(float(state["reputation"])))), "RUF", accent))
	_bar.add_child(_chip("floor", "ST. %d" % int(tier["level"]), tier["label"], accent))
	_bar.add_child(_chip(
		"spark", str(int(state["talentPoints"])), "TALENT",
		UiTheme.GREEN if int(state["talentPoints"]) > 0 else UiTheme.DIM
	))

func _chip(icon_name: String, value: String, note: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(Icons.os_icon(icon_name, 15.0, color))
	row.add_child(UiTheme.label(value, 13, UiTheme.TEXT, 1.0))
	if not note.is_empty():
		row.add_child(UiTheme.label(note, 8, UiTheme.DIM, 2.0))
	return row

# ---------------- AUSBAU ----------------

func _upgrades_body() -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var all := Upgrades.upgrade_list(state)
	var filtered := _sort_upgrades(_filter_upgrades(all))

	var open := 0
	var ready := 0
	var done := 0
	var total := 0
	for u: Dictionary in all:
		if not bool(u["maxed"]):
			open += 1
			if bool(u["affordable"]):
				ready += 1
		done += int(u["level"])
		total += int(u["max"])

	var tier := GameState.club_tier(state)
	var next: Variant = null
	for t: Dictionary in Config.CLUB_TIERS:
		if int(t["level"]) == int(tier["level"]) + 1:
			next = t
			break
	var points := GameState.total_upgrade_tiers(state)

	# Werkzeugleiste: Bereiche, Suche, Filter, Sortierung
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	tabs.add_child(_tab("alle", "ALLE", open, UiTheme.CYAN, ""))
	for g: Dictionary in GROUPS:
		var in_group := 0
		var open_in_group := 0
		for u: Dictionary in all:
			if u["group"] == g["id"]:
				in_group += 1
				if not bool(u["maxed"]):
					open_in_group += 1
		if in_group == 0:
			continue
		tabs.add_child(_tab(
			g["id"], String(g["id"]).to_upper(), open_in_group, Color(g["color"]), g["icon"]
		))
	_window_body.add_child(tabs)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	var search := LineEdit.new()
	search.placeholder_text = "SUCHEN"
	search.text = _query
	search.custom_minimum_size = Vector2(200, 0)
	search.add_theme_font_override("font", Fonts.mono())
	search.add_theme_font_size_override("font_size", 11)
	search.text_changed.connect(func(text: String) -> void:
		_query = text
		_paint()
		# Nach dem Neuaufbau weitertippen koennen.
		var again := _window_body.find_child("Search", true, false)
		if again is LineEdit:
			(again as LineEdit).grab_focus()
			(again as LineEdit).caret_column = (again as LineEdit).text.length()
	)
	search.name = "Search"
	tools.add_child(search)

	var afford := CheckBox.new()
	afford.text = "NUR BEZAHLBAR"
	afford.button_pressed = _only_affordable
	afford.add_theme_font_override("font", Fonts.mono())
	afford.add_theme_font_size_override("font_size", 10)
	afford.toggled.connect(func(on: bool) -> void:
		_only_affordable = on
		_paint()
	)
	tools.add_child(afford)
	tools.add_child(UiTheme.spacer())
	for s: Dictionary in SORTS:
		var b := UiTheme.button(
			s["label"], UiTheme.CYAN if _sort == s["id"] else UiTheme.LINE, 9, 1.0
		)
		b.pressed.connect(func() -> void:
			_sort = s["id"]
			_paint()
		)
		tools.add_child(b)
	_window_body.add_child(tools)

	# Kennzahlen
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 16)
	meters.add_child(_meter_box(
		"AUSBAU GESAMT", "%d / %d" % [done, total],
		float(done) / total if total > 0 else 0.0, UiTheme.CYAN, ""
	))
	meters.add_child(_meter_box(
		"NÄCHSTE CLUB-STUFE",
		(next as Dictionary)["label"] if next != null else "MAXIMUM ERREICHT",
		minf(1.0, float(points) / float((next as Dictionary)["need"])) if next != null else 1.0,
		UiTheme.AMBER,
		"%d / %d AUSBAUPUNKTE" % [points, int((next as Dictionary)["need"])] if next != null
			else "%d AUSBAUPUNKTE" % points
	))
	meters.add_child(_meter_box(
		"SOFORT MÖGLICH", "%d VON %d" % [ready, open], -1.0,
		UiTheme.GREEN if ready > 0 else UiTheme.TEXT,
		"Offene Ausbauten, die du dir gerade leisten kannst."
	))
	_window_body.add_child(meters)

	if filtered.is_empty():
		_window_body.add_child(UiTheme.label(
			"Nichts gefunden. Filter zurücksetzen?", 12, UiTheme.DIM
		))
		return

	# Bei "EMPFOHLEN" bleibt die Liste am Stueck, sonst wird nach Bereichen
	# gebuendelt - so sieht man auf einen Blick, wo noch etwas offen ist.
	var grouped: bool = _sort != "empfohlen" or _group != "alle"
	if grouped:
		for g: Dictionary in GROUPS:
			var in_group: Array[Dictionary] = []
			for u: Dictionary in filtered:
				if u["group"] == g["id"]:
					in_group.append(u)
			if in_group.is_empty():
				continue
			var head := HBoxContainer.new()
			head.add_theme_constant_override("separation", 8)
			head.add_child(Icons.os_icon(g["icon"], 16.0, Color(g["color"])))
			head.add_child(UiTheme.label(
				String(g["id"]).to_upper(), 12, Color(g["color"]), 3.0
			))
			head.add_child(UiTheme.label(g["note"], 10, UiTheme.DIM))
			head.add_child(UiTheme.spacer())
			head.add_child(UiTheme.label(str(in_group.size()), 10, UiTheme.DIM))
			_window_body.add_child(head)
			_window_body.add_child(_upgrade_grid(in_group))
	else:
		_window_body.add_child(_upgrade_grid(filtered))

func _tab(id: String, label: String, count: int, color: Color, icon_name: String) -> Control:
	var b := UiTheme.content_button(color if _group == id else UiTheme.LINE, 9, 1.0)
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void:
		_group = id
		_paint()
	)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	if not icon_name.is_empty():
		row.add_child(Icons.os_icon(icon_name, 14.0, color))
	row.add_child(UiTheme.label(label, 9, UiTheme.TEXT, 2.0))
	row.add_child(UiTheme.label(str(count), 9, UiTheme.DIM))
	b.add_child(row)
	return b

func _meter_box(
	key: String, value: String, ratio: float, color: Color, note: String
) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	col.add_child(UiTheme.label(value, 15, color))
	if ratio >= 0.0:
		var m := UiTheme.meter(220.0, 4.0)
		m.fill_color = color
		m.set_value(ratio)
		col.add_child(m)
	if not note.is_empty():
		col.add_child(UiTheme.label(note, 9, UiTheme.DIM))
	return col

func _filter_upgrades(list: Array[Dictionary]) -> Array[Dictionary]:
	var q := _query.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for u: Dictionary in list:
		if _group != "alle" and u["group"] != _group:
			continue
		if _only_affordable and (not bool(u["affordable"]) or bool(u["maxed"])):
			continue
		if q.is_empty():
			out.append(u)
			continue
		var haystack := "%s %s %s" % [u["label"], u["group"], u["nextDesc"]]
		if haystack.to_lower().contains(q):
			out.append(u)
	return out

func _sort_upgrades(list: Array[Dictionary]) -> Array[Dictionary]:
	var copy := list.duplicate()
	match _sort:
		"preis":
			copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if bool(a["maxed"]) != bool(b["maxed"]):
					return not bool(a["maxed"])
				return _cost_of(a) < _cost_of(b)
			)
		"fortschritt":
			copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var pa := float(a["level"]) / float(a["max"])
				var pb := float(b["level"]) / float(b["max"])
				if not is_equal_approx(pa, pb):
					return pa > pb
				return int(_group_meta(a["group"])["order"]) < int(_group_meta(b["group"])["order"])
			)
		"name":
			copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0
			)
		_:
			# Empfohlen: was jetzt geht zuerst, darin das Guenstigste; MAX ans Ende.
			copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if bool(a["maxed"]) != bool(b["maxed"]):
					return not bool(a["maxed"])
				if bool(a["affordable"]) != bool(b["affordable"]):
					return bool(a["affordable"])
				if not is_equal_approx(_cost_of(a), _cost_of(b)):
					return _cost_of(a) < _cost_of(b)
				return int(_group_meta(a["group"])["order"]) < int(_group_meta(b["group"])["order"])
			)
	return copy

static func _cost_of(u: Dictionary) -> float:
	return float(u["cost"]) if u["cost"] != null else 0.0

func _upgrade_grid(list: Array[Dictionary]) -> Control:
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for u: Dictionary in list:
		grid.add_child(_upgrade_card(u))
	return grid

func _upgrade_card(u: Dictionary) -> Control:
	var g := _group_meta(u["group"])
	var color := Color(g["color"])
	var maxed := bool(u["maxed"])
	var affordable := bool(u["affordable"])
	var badge := "AUSGEBAUT" if maxed else ("BEREIT" if affordable else "ZU TEUER")

	var panel := UiTheme.panel(
		Color(color.r, color.g, color.b, 0.16) if _flash == u["id"] else Color(1, 1, 1, 0.02),
		Color(color.r, color.g, color.b, 0.9 if affordable and not maxed else 0.3)
	)
	panel.custom_minimum_size = Vector2(310, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(Icons.os_icon(g["icon"], 20.0, color))
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_child(UiTheme.label(u["label"], 13, UiTheme.TEXT, 1.0, true))
	var weight: int = int(u["tierWeight"])
	name_col.add_child(UiTheme.label("%s · %s" % [
		String(u["group"]).to_upper(), "+%d PKT" % weight if weight > 0 else "OHNE PKT",
	], 8, UiTheme.DIM, 1.0))
	top.add_child(name_col)
	top.add_child(UiTheme.label(badge, 8, color, 1.0))
	col.add_child(top)

	var level := HBoxContainer.new()
	level.add_theme_constant_override("separation", 8)
	level.add_child(UiTheme.label("STUFE %d/%d" % [int(u["level"]), int(u["max"])], 10, UiTheme.DIM, 1.0))
	var segs := HBoxContainer.new()
	segs.add_theme_constant_override("separation", 3)
	for i in int(u["max"]):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 4)
		seg.color = color if i < int(u["level"]) else Color(1, 1, 1, 0.1)
		segs.add_child(seg)
	level.add_child(segs)
	col.add_child(level)

	if u["currentDesc"] != null:
		var now_row := HBoxContainer.new()
		now_row.add_theme_constant_override("separation", 5)
		now_row.add_child(Icons.os_icon("check", 12.0, UiTheme.GREEN))
		var now_label := UiTheme.body_label(u["currentDesc"], 10, UiTheme.GREEN)
		now_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		now_row.add_child(now_label)
		col.add_child(now_row)

	var next_label := UiTheme.body_label(
		"Mehr geht hier nicht." if maxed else u["nextDesc"], 11, UiTheme.TEXT
	)
	next_label.custom_minimum_size = Vector2(280, 0)
	col.add_child(next_label)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	foot.add_child(UiTheme.label(
		"MAX" if maxed else "€%s" % UiTheme.money_text(_cost_of(u)), 13, UiTheme.TEXT, 1.0
	))
	foot.add_child(UiTheme.spacer())
	var buy := UiTheme.button("FERTIG" if maxed else "KAUFEN", color, 10, 2.0)
	buy.disabled = maxed or not affordable
	buy.pressed.connect(func() -> void: _buy_upgrade(u["id"]))
	foot.add_child(buy)
	col.add_child(foot)

	panel.add_child(col)
	return panel

func _buy_upgrade(id: String) -> void:
	var g: Dictionary = game.get("game")
	var result := Upgrades.buy_upgrade(g["state"], id)
	if bool(result["ok"]):
		var bus: Bus = g["bus"]
		bus.emit("sfx", "upgrade")
		bus.emit("upgradeBought", result)
		game.call("save")
		_flash = result["id"]
		# Der Aufblitzer gehoert zum Kauf, nicht zur Karte: nach kurzer Zeit
		# vergessen, damit er beim naechsten Filterwechsel nicht erneut laeuft.
		get_tree().create_timer(0.8).timeout.connect(func() -> void: _flash = "")
		_show_toast("CLUB-STUFE %d ERREICHT" % int(result["tier"]) if bool(result["tierChanged"])
			else "GEKAUFT: %s" % result["desc"])
	else:
		_show_toast(String(result["reason"]).to_upper())
	_paint()

# ---------------- TALENTE ----------------

func _talents_body() -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var talents := Progression.talent_list(state)
	var prog := Progression.rank_progress(state)
	var spent := 0
	for t: Dictionary in talents:
		spent += int(t["level"])

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 16)
	meters.add_child(_meter_box(
		"FREIE PUNKTE", str(int(state["talentPoints"])), -1.0,
		UiTheme.GREEN if int(state["talentPoints"]) > 0 else UiTheme.TEXT,
		"Punkte gibt es beim Aufstieg im Rang."
	))
	var next: Variant = prog["next"]
	meters.add_child(_meter_box(
		"RANG", (prog["current"] as Dictionary)["label"], float(prog["ratio"]), UiTheme.CYAN,
		"NÄCHSTER: %s (%d XP)" % [
			(next as Dictionary)["label"], int((next as Dictionary)["xp"]),
		] if next != null else "HÖCHSTER RANG"
	))
	meters.add_child(_meter_box(
		"GELERNT", "%d STUFEN" % spent, -1.0, UiTheme.TEXT,
		"Talente bleiben über alle Nächte erhalten."
	))
	_window_body.add_child(meters)

	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for t: Dictionary in talents:
		grid.add_child(_talent_card(t))
	_window_body.add_child(grid)

func _talent_card(t: Dictionary) -> Control:
	var maxed: bool = int(t["level"]) >= int(t["max"])
	var can_buy := bool(t["canBuy"])
	var panel := UiTheme.panel(
		Color(1, 1, 1, 0.02),
		Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.9 if can_buy else 0.3)
	)
	panel.custom_minimum_size = Vector2(310, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(Icons.os_icon("spark", 20.0, UiTheme.CYAN))
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_child(UiTheme.label(t["label"], 13, UiTheme.TEXT, 1.0, true))
	name_col.add_child(UiTheme.label("PERSÖNLICH", 8, UiTheme.DIM, 1.0))
	top.add_child(name_col)
	top.add_child(UiTheme.label(
		"MEISTER" if maxed else ("LERNBAR" if can_buy else "KEIN PUNKT"), 8, UiTheme.CYAN, 1.0
	))
	col.add_child(top)

	var level := HBoxContainer.new()
	level.add_theme_constant_override("separation", 8)
	level.add_child(UiTheme.label(
		"STUFE %d/%d" % [int(t["level"]), int(t["max"])], 10, UiTheme.DIM, 1.0
	))
	var segs := HBoxContainer.new()
	segs.add_theme_constant_override("separation", 3)
	for i in int(t["max"]):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 4)
		seg.color = UiTheme.CYAN if i < int(t["level"]) else Color(1, 1, 1, 0.1)
		segs.add_child(seg)
	level.add_child(segs)
	col.add_child(level)

	var desc := UiTheme.body_label(t["desc"], 11, UiTheme.TEXT)
	desc.custom_minimum_size = Vector2(280, 0)
	col.add_child(desc)

	var foot := HBoxContainer.new()
	foot.add_child(UiTheme.label("MAX" if maxed else "1 PUNKT", 12, UiTheme.TEXT, 1.0))
	foot.add_child(UiTheme.spacer())
	var learn := UiTheme.button("LERNEN", UiTheme.CYAN, 10, 2.0)
	learn.disabled = not can_buy
	learn.pressed.connect(func() -> void:
		var g: Dictionary = game.get("game")
		var res := Progression.buy_talent(g["state"], t["id"])
		if bool(res["ok"]):
			(g["bus"] as Bus).emit("sfx", "ok")
			game.call("save")
			_show_toast("GELERNT: %s %d" % [String(res["label"]).to_upper(), int(res["level"])])
		_paint()
	)
	foot.add_child(learn)
	col.add_child(foot)

	panel.add_child(col)
	return panel

# ---------------- BOOKING ----------------

func _acts_body() -> void:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var artists := Artists.available_artists(state)

	if GameState.upgrade_level(state, "backstage") < 1:
		_window_body.add_child(UiTheme.body_label(
			"Ohne Backstage-Bereich lässt sich kein Act buchen. Bau ihn im Programm "
			+ "AUSBAU unter INNENBEREICH.", 12, UiTheme.DIM
		))
		return

	var booked: Variant = state["bookedArtist"]
	if booked != null:
		var row := UiTheme.panel(
			Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.12), UiTheme.PURPLE
		)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(Icons.os_icon("note", 20.0, UiTheme.PURPLE))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiTheme.label((booked as Dictionary)["name"], 13, UiTheme.TEXT, 1.0, true))
		col.add_child(UiTheme.label("gebucht für €%s — kommt im Lauf der Nacht." % \
			UiTheme.money_text(float((booked as Dictionary)["fee"])), 10, UiTheme.DIM))
		line.add_child(col)
		var cancel := UiTheme.button("STORNIEREN", UiTheme.RED, 10, 2.0)
		cancel.pressed.connect(func() -> void:
			Artists.cancel_booking(state)
			_paint()
		)
		line.add_child(cancel)
		row.add_child(line)
		_window_body.add_child(row)

	if artists.is_empty():
		_window_body.add_child(UiTheme.body_label(
			"Bei diesem Ruf will noch niemand hier spielen.", 12, UiTheme.DIM
		))
		return

	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for a: Dictionary in artists:
		grid.add_child(_artist_card(a, state))
	_window_body.add_child(grid)

func _artist_card(a: Dictionary, state: Dictionary) -> Control:
	var booked_artist: Variant = state["bookedArtist"]
	var booked: bool = booked_artist != null and (booked_artist as Dictionary)["id"] == a["id"]
	var affordable: bool = float(state["money"]) >= float(a["fee"])

	var panel := UiTheme.panel(
		Color(1, 1, 1, 0.02),
		Color(UiTheme.PURPLE.r, UiTheme.PURPLE.g, UiTheme.PURPLE.b, 0.9 if affordable else 0.3)
	)
	panel.custom_minimum_size = Vector2(310, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(Icons.os_icon("note", 20.0, UiTheme.PURPLE))
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_child(UiTheme.label(a["name"], 13, UiTheme.TEXT, 1.0, true))
	name_col.add_child(UiTheme.label(a["genre"], 8, UiTheme.DIM, 1.0))
	top.add_child(name_col)
	top.add_child(UiTheme.label("POP %d" % int(a["pop"]), 8, UiTheme.PURPLE, 1.0))
	col.add_child(top)

	col.add_child(UiTheme.body_label("Umsatz ×%s · zieht VIPs ×%s" % [
		str(a["spend"]), str(a["vipPull"]),
	], 11, UiTheme.TEXT))

	var foot := HBoxContainer.new()
	foot.add_child(UiTheme.label(
		"€%s" % UiTheme.money_text(float(a["fee"])), 13, UiTheme.TEXT, 1.0
	))
	foot.add_child(UiTheme.spacer())
	var book := UiTheme.button("GEBUCHT" if booked else "BUCHEN", UiTheme.PURPLE, 10, 2.0)
	book.disabled = not affordable or booked
	book.pressed.connect(func() -> void:
		var g: Dictionary = game.get("game")
		var res := Artists.book_artist(g["state"], a["id"])
		if bool(res["ok"]):
			(g["bus"] as Bus).emit("sfx", "cash")
		_paint()
	)
	foot.add_child(book)
	col.add_child(foot)

	panel.add_child(col)
	return panel

# ---------------- CLUBAKTE ----------------

func _akte_body() -> void:
	var state: Dictionary = (game.get("game") as Dictionary)["state"]
	var tier := GameState.club_tier(state)
	var points := GameState.total_upgrade_tiers(state)
	var list := Upgrades.upgrade_list(state)
	var life: Dictionary = state["lifetime"]
	var log_list: Array = state["log"]

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)

	main.add_child(UiTheme.label("AUSBAUSTUFEN", 12, UiTheme.TEXT, 3.0))
	for t: Dictionary in Config.CLUB_TIERS:
		var level := int(t["level"])
		var color := UiTheme.DIM
		if level < int(tier["level"]):
			color = UiTheme.GREEN
		elif level == int(tier["level"]):
			color = UiTheme.AMBER
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = color
		row.add_child(dot)
		row.add_child(UiTheme.label("STUFE %d · %s" % [level, t["label"]], 11, color, 1.0))
		row.add_child(UiTheme.spacer())
		row.add_child(UiTheme.label("%d Ausbaupunkte" % int(t["need"]), 9, UiTheme.DIM))
		main.add_child(row)

	main.add_child(UiTheme.label("BILANZ ÜBER ALLE NÄCHTE", 12, UiTheme.TEXT, 3.0))
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 16)
	meters.add_child(_meter_box("NÄCHTE", str(int(life["nights"])), -1.0, UiTheme.TEXT, ""))
	meters.add_child(_meter_box(
		"GEPRÜFT", str(int(life["guests"])), -1.0, UiTheme.TEXT,
		"%d eingelassen · %d abgewiesen" % [int(life["admitted"]), int(life["rejected"])]
	))
	meters.add_child(_meter_box(
		"UMSATZ", "€%s" % UiTheme.money_text(float(life["revenue"])), -1.0, UiTheme.TEXT,
		"%d Zwischenfälle" % int(life["incidents"])
	))
	main.add_child(meters)

	main.add_child(UiTheme.label("PROTOKOLL", 12, UiTheme.TEXT, 3.0))
	if log_list.is_empty():
		main.add_child(UiTheme.label("Noch nichts passiert.", 11, UiTheme.DIM))
	else:
		for i in mini(10, log_list.size()):
			var entry: Dictionary = log_list[i]
			main.add_child(UiTheme.label(
				entry["text"], 10, UiTheme.kind_color(entry.get("kind", "info"))
			))
	cols.add_child(main)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.add_theme_constant_override("separation", 4)
	side.add_child(UiTheme.label("KENNZAHLEN", 12, UiTheme.TEXT, 3.0))
	side.add_child(_kv_row("NACHT", str(int(state["nightIndex"]) + 1).pad_zeros(2)))
	side.add_child(_kv_row("POSTEN", GameState.rank(state)["label"]))
	side.add_child(_kv_row("KAPAZITÄT", str(GameState.capacity(state))))
	side.add_child(_kv_row("SCHLANGE", str(GameState.queue_capacity(state))))
	side.add_child(_kv_row("AUSBAUPUNKTE", str(points)))
	side.add_child(_kv_row("ERFAHRUNG", "%d XP" % int(state["xp"])))

	side.add_child(UiTheme.label("BEREICHE", 12, UiTheme.TEXT, 3.0))
	for g: Dictionary in GROUPS:
		var lv := 0
		var mx := 0
		for u: Dictionary in list:
			if u["group"] == g["id"]:
				lv += int(u["level"])
				mx += int(u["max"])
		if mx == 0:
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var head := HBoxContainer.new()
		head.add_child(UiTheme.label(g["id"], 10, Color(g["color"]), 1.0))
		head.add_child(UiTheme.spacer())
		head.add_child(UiTheme.label("%d/%d" % [lv, mx], 10, UiTheme.DIM))
		row.add_child(head)
		var m := UiTheme.meter(260.0, 4.0)
		m.fill_color = Color(g["color"])
		m.set_value(float(lv) / mx)
		row.add_child(m)
		side.add_child(row)
	cols.add_child(side)

	_window_body.add_child(cols)

func _kv_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiTheme.label(key, 9, UiTheme.DIM, 2.0))
	row.add_child(UiTheme.spacer())
	row.add_child(UiTheme.label(value, 11, UiTheme.TEXT))
	return row

# ---------------- Leben auf dem Bildschirm ----------------

## Das Wallpaper laeuft weiter, waehrend die Fenster neu gebaut werden.
class WallpaperNode extends Control:
	var game: Node = null
	var _t := 0.0
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(game_node: Node) -> void:
		game = game_node
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
		var state: Dictionary = (game.get("game") as Dictionary)["state"]
		Desktop.draw_desktop(
			self, _fx, size.x, size.y, _t, int(GameState.club_tier(state)["level"])
		)
