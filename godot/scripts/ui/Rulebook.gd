## Die Hausordnung am linken Bildrand.
##
## Ein Reiter klebt an der Kante; faehrt man mit der Maus darueber, klappt sie
## aus - aufgemacht wie ein amtliches Dokument: Briefkopf, Aktenzeichen,
## Paragraphen, Stempel.
##
## Wichtig: Hier stehen nur die GRUPPEN ("Waffen", "Pyrotechnik", ...), nie die
## einzelnen Gegenstaende. Ob ein Schlagring eine Waffe ist und ob das
## Flaeschchen ohne Etikett unter "unklare Substanzen" faellt, entscheidet der
## Spieler selbst - abgelesen werden kann das nicht.
##
## Portierung von src/ui/rulebook.js. Das Ausklappen loest in der Vorlage CSS
## per :hover; hier uebernehmen das mouse_entered/mouse_exited am Reiter, und
## ein Klick heftet das Blatt fest (fuer Touch und ruhiges Lesen).
class_name Rulebook
extends Control

const SEVERITY := {
	1: "Zutritt verweigern",
	2: "Zutritt verweigern, Eintrag ins Buch",
	3: "Zutritt verweigern, Leitung informieren",
}

var _sheet: PanelContainer = null
var _tab: Button = null
var _pinned := false

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	custom_minimum_size = Vector2(40, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_sheet = _build_sheet()
	_sheet.position = Vector2(-460, 60)
	_sheet.visible = false
	add_child(_sheet)

	_tab = UiTheme.button("HAUS\nORDNUNG", UiTheme.AMBER, 9, 2.0)
	_tab.custom_minimum_size = Vector2(34, 96)
	_tab.position = Vector2(0, 200)
	_tab.pressed.connect(func() -> void:
		_pinned = not _pinned
		_set_open(_pinned or not _sheet.visible)
	)
	add_child(_tab)

	mouse_entered.connect(func() -> void: _set_open(true))
	mouse_exited.connect(func() -> void:
		if not _pinned:
			_set_open(false)
	)

func _set_open(open: bool) -> void:
	_sheet.visible = open
	# Ausgeklappt liegt das Blatt im Bild, eingeklappt nur der Reiter.
	_sheet.position.x = 40.0 if open else -460.0

func _build_sheet() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var box := UiTheme.panel_box(
		Color(233.0 / 255.0, 231.0 / 255.0, 222.0 / 255.0, 0.97), Color("9a917c")
	)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)

	var ink := Color("22201a")
	var soft := Color("6b6555")
	var doc := VBoxContainer.new()
	doc.add_theme_constant_override("separation", 8)

	# Briefkopf
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var crest := UiTheme.label("§", 30, ink, 0.0, true)
	head.add_child(crest)
	var titles := VBoxContainer.new()
	titles.add_child(UiTheme.label(
		"%s · EINLASSKONTROLLE" % Config.CLUB_NAME, 12, ink, 2.0
	))
	titles.add_child(UiTheme.label(
		"Hausordnung, Anlage 2 — Nicht zugelassene Sachen (Gruppen)", 10, soft
	))
	head.add_child(titles)
	doc.add_child(head)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 12)
	meta.add_child(UiTheme.label(
		"AKTENZEICHEN NW-%d/02" % int(Config.GAME_DATE["year"]), 9, soft, 2.0
	))
	meta.add_child(UiTheme.spacer())
	meta.add_child(UiTheme.label("STAND %d.%d.%d" % [
		int(Config.GAME_DATE["day"]), int(Config.GAME_DATE["month"]),
		int(Config.GAME_DATE["year"]),
	], 9, soft, 2.0))
	doc.add_child(meta)
	doc.add_child(UiTheme.separator(Color("9a917c")))

	var zone_names: PackedStringArray = []
	for z: Dictionary in Config.ZONES:
		zone_names.append(z["label"])
	doc.add_child(_para(
		"§1  Der Einlass ist zu verweigern, wenn eine Sache aus einer der "
		+ "nachstehenden Gruppen mitgeführt wird. Die Aufzählung ist nicht "
		+ "abschliessend: die Einordnung im Einzelfall obliegt dem Kontrollpersonal. "
		+ "Geprüft wird an den Zonen %s." % ", ".join(zone_names),
		ink
	))

	# Tabelle der Gruppen, nach Stufe sortiert wie in der Vorlage.
	var groups: Array[Dictionary] = []
	for c: Dictionary in Config.ITEM_CATEGORIES:
		groups.append(c)
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["severity"]) != int(b["severity"]):
			return int(a["severity"]) > int(b["severity"])
		return String(a["label"]) < String(b["label"])
	)

	for n in groups.size():
		var c: Dictionary = groups[n]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(UiTheme.label(str(n + 1).pad_zeros(2), 10, soft, 1.0))
		var name := UiTheme.label(c["label"], 12, ink, 1.0)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var sev := int(c["severity"])
		top.add_child(UiTheme.label(
			"I".repeat(sev), 12,
			Color("8c1620") if sev >= 3 else (Color("9a6a1a") if sev == 2 else soft), 2.0
		))
		row.add_child(top)
		var note := UiTheme.body_label(c["rule"], 10, soft)
		note.custom_minimum_size = Vector2(400, 0)
		row.add_child(note)
		row.add_child(UiTheme.label(SEVERITY.get(sev, ""), 9, soft, 1.0))
		doc.add_child(row)

	doc.add_child(UiTheme.separator(Color("9a917c")))
	doc.add_child(_para(
		"§2  Ebenfalls abzuweisen ist, wer das Mindestalter von %d Jahren nicht "
		% int(Config.TUNING["minAge"])
		+ "nachweist, ein ungültiges oder fremdes Dokument vorlegt oder einen "
		+ "Atemalkoholwert von %.1f ‰ oder mehr aufweist."
		% Config.ALCOHOL_LIMIT_PROMILLE,
		ink
	))
	doc.add_child(_para(
		"§3  Alltagsgegenstände (Handy, Schlüssel, Feuerzeug, Zigaretten, "
		+ "Portemonnaie, Kopfhörer, Kaugummi und Vergleichbares) sind zugelassen "
		+ "und nicht zu beanstanden.",
		ink
	))
	doc.add_child(_para(
		"§4  Wer das Personal tätlich angreift, ist unabhängig von allen übrigen "
		+ "Feststellungen abzuweisen; der Vorfall ist zu melden.",
		ink
	))

	var stamp := UiTheme.label("GEPRÜFT · BETRIEBSLEITUNG", 10, Color("8c1620"), 3.0)
	doc.add_child(stamp)

	panel.add_child(doc)
	return panel

func _para(text: String, color: Color) -> Control:
	var l := UiTheme.body_label(text, 11, color)
	l.custom_minimum_size = Vector2(400, 0)
	return l
