## Gestaltungsvorgaben der Oberflaeche: dunkel, industriell, minimal.
##
## Portierung von styles/ui.css. Die CSS-Variablen aus :root stehen hier als
## Konstanten, und statt CSS-Klassen gibt es Bau-Funktionen fuer die immer
## gleichen Bausteine (Panel, Beschriftung, Knopf, Balken). Godots Theme-
## Ressource deckt nur einen Teil ab - Randfarben und Innenabstaende je
## Zustand kommen ueber StyleBoxFlat direkt am Knoten.
class_name UiTheme
extends RefCounted

# ---------- Farben (:root in ui.css) ----------

const BG := Color("05060a")
const PANEL := Color(10.0 / 255.0, 12.0 / 255.0, 17.0 / 255.0, 0.86)
const PANEL_SOLID := Color("0b0d12")
const LINE := Color("23282f")
const LINE_SOFT := Color(1, 1, 1, 0.06)
const TEXT := Color("e8ecf2")
const DIM := Color("8b93a1")
const RED := Color("ff2f3c")
const CYAN := Color("39d7ff")
const AMBER := Color("ffb638")
const GREEN := Color("4ce08a")
const PURPLE := Color("8b5cff")

## Farbe zu einer Meldungsart (toast/log: info | good | warn | bad).
static func kind_color(kind: String) -> Color:
	match kind:
		"good": return GREEN
		"warn": return AMBER
		"bad": return RED
		_: return CYAN

# ---------- Bausteine ----------

## Kasten mit Rand, wie `.panel` in ui.css.
static func panel_box(
	fill: Color = PANEL, border: Color = LINE, radius: int = 0, border_width: int = 1
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

static func panel(fill: Color = PANEL, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(fill, border))
	return p

## Beschriftung. `spacing` bildet CSS letter-spacing ab.
static func label(
	content: String, size: int = 12, color: Color = TEXT,
	spacing: float = 0.0, display: bool = false
) -> Label:
	var l := Label.new()
	l.text = content
	var font := Fonts.display() if display else Fonts.mono()
	l.add_theme_font_override("font", Fonts.spaced(font, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Kleine Grossbuchstaben-Zeile, wie `.sub` in ui.css.
static func sub_label(content: String) -> Label:
	return label(content.to_upper(), 10, DIM, 3.0)

## Fliesstext mit Umbruch.
static func body_label(content: String, size: int = 12, color: Color = TEXT) -> Label:
	var l := label(content, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Knopf im Stil von `.act` / `.dec`.
static func button(
	content: String, accent: Color = CYAN, size: int = 12, spacing: float = 2.0
) -> Button:
	return _style_button(Button.new(), content, accent, size, spacing)

## Knopf, dessen Groesse sich nach einem eingehaengten Container richtet.
##
## Ein Button in Godot misst nur seinen eigenen Text; angehaengte Knoten
## zaehlen nicht mit. Wo der Inhalt aus Symbol und mehreren Beschriftungen
## besteht (Reiter, Karten), waere der Knopf darum null Pixel breit. Diese
## Fassung uebernimmt die Mindestgroesse des Inhalts - der Weg, den in der
## Web-Fassung das Box-Modell von selbst geht.
##
## Der Wert wird beim Eintritt in den Baum gesetzt und nicht ueber
## _get_minimum_size() geliefert: Button ueberschreibt get_minimum_size() in
## C++, die Skript-Fassung wird dort nie gerufen.
class ContentButton extends Button:
	## Innenabstand um den Inhalt.
	var padding := Vector2(22, 0)

	func _ready() -> void:
		fit_to_content()

	func fit_to_content() -> void:
		var inner := Vector2.ZERO
		for child in get_children():
			if child is Control and (child as Control).visible:
				inner = inner.max((child as Control).get_combined_minimum_size())
		custom_minimum_size = Vector2(
			maxf(custom_minimum_size.x, inner.x + padding.x),
			maxf(custom_minimum_size.y, inner.y + padding.y)
		)

## Wie button(), nur mit ContentButton als Grundlage. Der Inhalt kommt als
## Kind dazu (mit PRESET_FULL_RECT), der Text bleibt leer.
static func content_button(
	accent: Color = CYAN, size: int = 12, spacing: float = 2.0
) -> ContentButton:
	var b := ContentButton.new()
	_style_button(b, "", accent, size, spacing)
	return b

static func _style_button(
	b: Button, content: String, accent: Color, size: int, spacing: float
) -> Button:
	b.text = content
	b.add_theme_font_override("font", Fonts.spaced(Fonts.mono(), spacing))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(DIM.r, DIM.g, DIM.b, 0.4))

	var normal := panel_box(Color(1, 1, 1, 0.03), Color(accent.r, accent.g, accent.b, 0.35))
	var hover := panel_box(Color(accent.r, accent.g, accent.b, 0.14), accent)
	var pressed := panel_box(Color(accent.r, accent.g, accent.b, 0.22), accent)
	var disabled := panel_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.06))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", hover)
	return b

## Quadratischer Knopf: Icon in der Mitte, Beschriftung darunter.
##
## Die Leisten im Spiel bestanden aus flachen Rechtecken, in denen das Icon
## links oben klebte und lange Beschriftungen seitlich herausliefen. Jetzt ist
## jeder Knopf ein Quadrat, das Icon sitzt mittig darueber, die Zeile darunter
## wird beschnitten statt ueberzulaufen.
##
## Rueckgabe: { button, icon, label } - die Aufrufer faerben das Icon je Zustand.
static func icon_button(
	code: String, content: String, accent: Color = CYAN,
	side: float = 76.0, icon_size: float = 28.0, text_size: int = 8
) -> Dictionary:
	var b := button("", accent, text_size, 1.0)
	b.custom_minimum_size = Vector2(side, side)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = content
	b.clip_contents = true

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon := Icons.icon_node(code, icon_size, accent)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var l := label(content, text_size, DIM, 1.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Ohne clip_text meldet ein Label seine Textbreite als Mindestbreite - der
	# Container gibt sie ihm, und die Schrift laeuft aus dem Knopf heraus.
	l.clip_text = true
	box.add_child(l)

	b.add_child(box)
	return {"button": b, "icon": icon, "label": l}

## Karte mit farbigem Balken links - Grundform aller neuen Kaesten.
static func card(
	accent: Color = CYAN, fill: Color = Color(1, 1, 1, 0.022), bar: int = 2
) -> PanelContainer:
	var p := PanelContainer.new()
	var box := panel_box(fill, LINE_SOFT)
	box.border_width_left = bar
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	p.add_theme_stylebox_override("panel", box)
	return p

## Abschnitts-Ueberschrift: farbiger Block, Text, duenne Linie bis zum Rand.
class SectionHeader extends HBoxContainer:
	func _init(text: String, accent: Color) -> void:
		add_theme_constant_override("separation", 8)
		var tick := ColorRect.new()
		tick.color = accent
		tick.custom_minimum_size = Vector2(3, 12)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(tick)
		add_child(UiTheme.label(text.to_upper(), 11, TEXT, 3.0))
		var rule := ColorRect.new()
		rule.color = Color(accent.r, accent.g, accent.b, 0.18)
		rule.custom_minimum_size = Vector2(0, 1)
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(rule)

static func section(text: String, accent: Color = CYAN) -> Control:
	return SectionHeader.new(text, accent)

## Tastenkappe: der Buchstabe im Kasten, daneben wofuer er steht.
static func key_cap(key: String, content: String, accent: Color = AMBER) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var cap := PanelContainer.new()
	var box := panel_box(Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.5), 3)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var k := label(key, 10, accent, 1.0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.custom_minimum_size = Vector2(maxf(12.0, key.length() * 7.0), 0)
	cap.add_child(k)
	row.add_child(cap)
	var t := label(content, 10, DIM, 1.0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row

## Eckwinkel um einen Bereich - technische Optik ohne vollen Rahmen.
class Brackets extends Control:
	var accent := CYAN
	var arm := 18.0
	var thickness := 2.0

	func _init(color: Color = CYAN, arm_length: float = 18.0) -> void:
		accent = color
		arm = arm_length
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Color(accent.r, accent.g, accent.b, 0.7)
		for corner: Array in [
			[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
			[Vector2(w, 0), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(0, h), Vector2(1, 0), Vector2(0, -1)],
			[Vector2(w, h), Vector2(-1, 0), Vector2(0, -1)],
		]:
			var p: Vector2 = corner[0]
			var dx: Vector2 = corner[1]
			var dy: Vector2 = corner[2]
			draw_line(p + dy * thickness * 0.5, p + dx * arm + dy * thickness * 0.5, c, thickness)
			draw_line(p + dx * thickness * 0.5, p + dy * arm + dx * thickness * 0.5, c, thickness)

## Fortschritts-/Messbalken (`.meter`, `.night-bar`).
class Meter extends Control:
	var value := 0.0  ## 0..1
	var fill_color := CYAN
	var track := Color("1a1e26")
	## Optionaler zweiter Farbton fuer den Verlauf (wie die Nachtleiste).
	var fill_to: Variant = null

	func _init(width: float = 110.0, height: float = 3.0) -> void:
		custom_minimum_size = Vector2(width, height)

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), track)
		var w := size.x * value
		if w <= 0.0:
			return
		if fill_to == null:
			draw_rect(Rect2(0, 0, w, size.y), fill_color)
		else:
			Draw2D.hgradient_rect(self, Rect2(0, 0, w, size.y), fill_color, fill_to)

static func meter(width: float = 110.0, height: float = 3.0) -> Meter:
	return Meter.new(width, height)

## Waagerechte Trennlinie.
static func separator(color: Color = LINE) -> Control:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, 1)
	return c

## Abstandhalter, der den restlichen Platz einnimmt.
static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## Beschriftung einer Taste. Die Vorlage schneidet dafuer den KeyboardEvent-
## Code zurecht ("Digit1" -> "1"); hier kommt sie aus der InputMap, damit sie
## auch nach einer Neubelegung stimmt.
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			match code:
				KEY_ENTER, KEY_KP_ENTER: return "ENTER"
				KEY_BACKSPACE: return "BACK"
				KEY_SPACE: return "LEER"
				KEY_ESCAPE: return "ESC"
				KEY_UP: return "↑"
				KEY_DOWN: return "↓"
				KEY_LEFT: return "←"
				KEY_RIGHT: return "→"
			return OS.get_keycode_string(code)
	return String(action)

## Zahl mit Tausenderpunkt, wie toLocaleString('de-DE') in der Vorlage.
static func money_text(value: float) -> String:
	var n := int(round(absf(value)))
	var digits := str(n)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out
