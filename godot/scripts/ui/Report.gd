## Night Report: die Bilanz nach jeder Nacht.
##
## Links die Zahlen der Schicht, rechts der eigene Tuersteher, der auf das
## Ergebnis reagiert: bei einer guten Nacht jubelt er im Konfettiregen, bei
## einer schlechten steht er im Nieselregen und laesst die Schultern haengen.
## Sterne, Balken und Zahlen laufen beim Oeffnen des Bildschirms an.
##
## Portierung von src/ui/report.js. Die Buehne rechts ist ein eigener
## Zeichenknoten (StageNode), der sich selbst weiterdreht - in der Vorlage
## macht das eine requestAnimationFrame-Schleife auf einem Canvas.
class_name Report
extends RefCounted

## Wie die Nacht gelaufen ist - Ton des ganzen Bildschirms.
const GRADES := [
	{
		"min": 5, "id": "legend", "label": "LEGENDÄRE NACHT", "color": "4ce08a",
		"mood": "happy", "pose": "cheer",
		"line": "Das war die beste Nacht seit Langem. Keiner ist durchgerutscht.",
	},
	{
		"min": 4, "id": "strong", "label": "STARKE NACHT", "color": "39d7ff",
		"mood": "proud", "pose": "cheer",
		"line": "Sauber gearbeitet. Der Chef wird morgen nichts zu meckern haben.",
	},
	{
		"min": 3, "id": "ok", "label": "SOLIDE NACHT", "color": "ffb638",
		"mood": "polite", "pose": "idle",
		"line": "Ging klar. Ein paar Sachen hätte ich früher sehen müssen.",
	},
	{
		"min": 2, "id": "weak", "label": "ZÄHE NACHT", "color": "ffb638",
		"mood": "tired", "pose": "idle",
		"line": "Lange Schicht. Da war zu viel Durcheinander an der Tür.",
	},
	{
		"min": 0, "id": "bad", "label": "MIESE NACHT", "color": "ff2f3c",
		"mood": "sad", "pose": "slump",
		"line": "Das war nichts. Morgen muss ich das wieder geradebiegen.",
	},
]

static func grade_for(rating: int) -> Dictionary:
	for g: Dictionary in GRADES:
		if rating >= int(g["min"]):
			return g
	return GRADES[GRADES.size() - 1]

static func build(game: Node, on_continue: Callable) -> Control:
	var g: Dictionary = game.get("game")
	var state: Dictionary = g["state"]
	var night: Dictionary = state["night"]
	var s: Dictionary = night["stats"]
	var rating := int(night.get("rating", 0))
	var grade := grade_for(rating)
	var grade_color := Color(grade["color"])
	var rep := snappedf(float(night.get("repDelta", 0.0)), 0.1)
	var netto := float(s["revenue"]) - float(s["artistFee"])
	var prog := Progression.rank_progress(state)
	var decisions := int(s["correct"]) + int(s["mistakes"])
	var accuracy := float(s["correct"]) / decisions if decisions > 0 else 0.0
	var flow := 1.0 - float(s["left"]) / float(s["arrived"]) if int(s["arrived"]) > 0 else 1.0
	var character := CharacterSys.normalize_character(state["character"])

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)

	# Kopf: Sterne und Note
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	top.add_child(UiTheme.label("NIGHT %s · %s · %s" % [
		str(state["nightIndex"]).pad_zeros(2),
		(night["event"] as Dictionary)["label"],
		GameState.club_tier(state)["label"],
	], 10, UiTheme.DIM, 3.0))
	top.add_child(UiTheme.label("NIGHT COMPLETE", 30, UiTheme.TEXT, 5.0, true))
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 4)
	for i in 5:
		stars.add_child(UiTheme.label(
			"★", 26, UiTheme.AMBER if i < rating else Color(1, 1, 1, 0.12)
		))
	top.add_child(stars)
	top.add_child(UiTheme.label(grade["label"], 14, grade_color, 4.0, true))
	wrap.add_child(top)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)

	# ---- links: Zahlen ----
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)

	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 18)
	heroes.add_child(_hero(
		"NETTO", "€%s" % UiTheme.money_text(netto),
		UiTheme.GREEN if netto >= 0.0 else UiTheme.RED
	))
	heroes.add_child(_hero(
		"RUF", "%s%s" % ["+" if rep >= 0.0 else "", str(rep)],
		UiTheme.GREEN if rep >= 0.0 else UiTheme.RED
	))
	heroes.add_child(_hero("ERFAHRUNG", "+%d XP" % int(night["xpGained"]), UiTheme.CYAN))
	left.add_child(heroes)

	left.add_child(_bar("TREFFERQUOTE", accuracy, "%d/%d" % [int(s["correct"]), decisions]))
	left.add_child(_bar("ANDRANG GEHALTEN", flow, "%d abgesprungen" % int(s["left"])))
	var next_rank: Variant = prog["next"]
	left.add_child(_bar(
		"RANG · %s" % GameState.rank(state)["label"],
		float(prog["ratio"]) if next_rank != null else 1.0,
		"→ %s" % (next_rank as Dictionary)["label"] if next_rank != null else "MAX"
	))

	left.add_child(_sec("DIE NACHT IN ZAHLEN"))
	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", 14)
	tiles.add_theme_constant_override("v_separation", 6)
	tiles.add_child(_tile("GÄSTE", s["arrived"]))
	tiles.add_child(_tile("EINLASS", s["admitted"], UiTheme.GREEN))
	tiles.add_child(_tile("ABGEWIESEN", s["rejected"]))
	tiles.add_child(_tile(
		"ABGESPRUNGEN", s["left"],
		UiTheme.RED if int(s["left"]) > int(s["admitted"]) * 0.3 else UiTheme.TEXT
	))
	tiles.add_child(_tile("UMSATZ", s["revenue"], UiTheme.GREEN, "€"))
	tiles.add_child(_tile(
		"VORFÄLLE", s["incidents"],
		UiTheme.RED if int(s["incidents"]) > 0 else UiTheme.GREEN
	))
	tiles.add_child(_tile("VIPS", s["vips"]))
	tiles.add_child(_tile(
		"GEFUNDEN", s["findings"],
		UiTheme.GREEN if int(s["findings"]) > 0 else UiTheme.TEXT
	))
	left.add_child(tiles)

	left.add_child(_sec("EIGENE BEFUNDE"))
	left.add_child(_kv(
		"Gefundene Unregelmäßigkeiten", str(int(s["findings"])),
		UiTheme.GREEN if int(s["findings"]) > 0 else UiTheme.TEXT
	))
	left.add_child(_kv(
		"Zu Unrecht beanstandet", str(int(s["falseAlarms"])),
		UiTheme.RED if int(s["falseAlarms"]) > 0 else UiTheme.TEXT
	))
	left.add_child(_kv(
		"Übersehen", str(int(s["overlooked"])),
		UiTheme.RED if int(s["overlooked"]) > 0 else UiTheme.TEXT
	))

	if int(s["attacks"]) > 0:
		left.add_child(_sec("ÜBERGRIFFE"))
		left.add_child(_kv("Auf dich losgegangen", str(int(s["attacks"]))))
		left.add_child(_kv(
			"Abgewehrt", str(int(s["defended"])),
			UiTheme.GREEN if int(s["defended"]) > 0 else UiTheme.TEXT
		))
		left.add_child(_kv(
			"Erwischt worden", str(int(s["attacksLanded"])),
			UiTheme.RED if int(s["attacksLanded"]) > 0 else UiTheme.TEXT
		))

	left.add_child(_sec("BILANZ"))
	left.add_child(_kv("Eintritt", "€%s" % UiTheme.money_text(float(s["entry"])), UiTheme.GREEN))
	left.add_child(_kv("Bar & VIP", "€%s" % UiTheme.money_text(float(s["bar"])), UiTheme.GREEN))
	left.add_child(_kv(
		"Prämie für Befunde", "€%s" % UiTheme.money_text(float(s["findingPay"])),
		UiTheme.GREEN if float(s["findingPay"]) > 0.0 else UiTheme.TEXT
	))
	if float(s["defensePay"]) > 0.0:
		left.add_child(_kv(
			"Prämie für Abwehr", "€%s" % UiTheme.money_text(float(s["defensePay"])), UiTheme.GREEN
		))
	if float(s["fines"]) > 0.0:
		left.add_child(_kv(
			"Bußgelder & Schäden", "−€%s" % UiTheme.money_text(float(s["fines"])), UiTheme.RED
		))
	if float(s["artistFee"]) > 0.0:
		left.add_child(_kv(
			"Gage", "−€%s" % UiTheme.money_text(float(s["artistFee"])), UiTheme.RED
		))
	left.add_child(_kv(
		"Netto", "€%s" % UiTheme.money_text(netto),
		UiTheme.GREEN if netto >= 0.0 else UiTheme.RED
	))
	if night["artist"] != null:
		var artist_state := "abgewiesen"
		var artist_ok := false
		if bool(night.get("artistPlaying", false)):
			artist_state = "hat gespielt"
			artist_ok = true
		elif bool(night.get("artistMissed", false)):
			artist_state = "nie eingelassen"
		left.add_child(_kv(
			"Act: %s" % (night["artist"] as Dictionary)["name"], artist_state,
			UiTheme.GREEN if artist_ok else UiTheme.RED
		))

	var quote_index := (int(state["nightIndex"]) * 7) % Dialogue.REPORT_QUOTES.size()
	left.add_child(_gap(8))
	var quote := UiTheme.body_label(
		"\"%s\"" % Dialogue.REPORT_QUOTES[quote_index], 12, UiTheme.DIM
	)
	left.add_child(quote)
	body.add_child(left)

	# ---- rechts: die Buehne ----
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	var stage := StageNode.new(grade, rating, character)
	right.add_child(stage)
	var bubble := UiTheme.panel()
	bubble.custom_minimum_size = Vector2(360, 0)
	bubble.add_child(UiTheme.body_label(grade["line"], 12, UiTheme.TEXT))
	right.add_child(bubble)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.add_child(UiTheme.label(character["name"], 15, UiTheme.TEXT, 2.0, true))
	who.add_child(UiTheme.label("%s · SCHICHT %s" % [
		GameState.rank(state)["label"], str(state["nightIndex"]).pad_zeros(2),
	], 10, UiTheme.DIM, 2.0))
	right.add_child(who)
	body.add_child(right)

	wrap.add_child(body)

	var next := UiTheme.button("FEIERABEND — INS BÜRO", UiTheme.GREEN, 12, 3.0)
	next.pressed.connect(on_continue)
	wrap.add_child(next)
	return wrap

# ---------- Bausteine ----------

static func _hero(key: String, value: String, color: Color) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiTheme.label(key, 9, UiTheme.DIM, 3.0))
	col.add_child(UiTheme.label(value, 22, color, 1.0, true))
	return col

static func _bar(label: String, ratio: float, note: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label(label, 10, UiTheme.DIM, 2.0))
	head.add_child(UiTheme.spacer())
	var pct := int(round(clampf(ratio, 0.0, 1.0) * 100.0))
	head.add_child(UiTheme.label("%d%%" % pct, 11, UiTheme.TEXT))
	col.add_child(head)
	var meter := UiTheme.meter(360.0, 4.0)
	meter.set_value(clampf(ratio, 0.0, 1.0))
	col.add_child(meter)
	col.add_child(UiTheme.label(note, 9, UiTheme.DIM))
	return col

static func _tile(key: String, value: Variant, color: Color = UiTheme.TEXT, prefix: String = "") -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(110, 0)
	col.add_child(UiTheme.label(key, 9, UiTheme.DIM, 2.0))
	col.add_child(UiTheme.label(
		"%s%s" % [prefix, UiTheme.money_text(float(value))], 18, color
	))
	return col

static func _kv(key: String, value: String, color: Color = UiTheme.TEXT) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiTheme.label(key, 11, UiTheme.DIM))
	row.add_child(UiTheme.spacer())
	row.add_child(UiTheme.label(value, 12, color))
	return row

static func _sec(text: String) -> Control:
	return UiTheme.label(text, 12, UiTheme.TEXT, 3.0)

static func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

# ---------- Die Buehne rechts ----------

## Der eigene Charakter reagiert: Haltung, Gesicht, Licht und Partikel haengen
## alle an der Sternewertung.
class StageNode extends Control:
	var grade: Dictionary = {}
	var rating := 0
	var character: Dictionary = {}
	var _t := 0.0
	var _bits: Array[Dictionary] = []
	var _good := false
	var _bad := false
	var _look: Dictionary = {}
	var _accent: Variant = null
	var _fx := DrawList.new()
	var _fx_node: FxReplay = null

	func _init(g: Dictionary, r: int, c: Dictionary) -> void:
		grade = g
		rating = r
		character = c
		custom_minimum_size = Vector2(400, 400)
		_good = rating >= 4
		_bad = rating <= 1
		_look = CharacterSys.character_look(character)
		_accent = CharacterSys.accent_color(character)

		# Konfetti bei guter Nacht, Regen bei schlechter.
		var count := 90 if _good else (120 if _bad else 26)
		var colors := [
			Palette.AMBER, Palette.CYAN, Palette.GREEN, Palette.RED, Palette.WHITE,
		]
		for i in count:
			_bits.append({
				"x": randf() * 400.0,
				"y": randf() * 400.0,
				"vy": (420.0 + randf() * 260.0) if _bad else (60.0 + randf() * 110.0),
				"vx": -60.0 if _bad else (randf() - 0.5) * 60.0,
				"size": 1.0 if _bad else 3.0 + randf() * 5.0,
				"spin": randf() * 6.28,
				"color": colors[i % 5],
			})

	func _ready() -> void:
		_fx_node = FxReplay.new()
		_fx_node.list = _fx
		add_child(_fx_node)

	func _process(delta: float) -> void:
		var dt := minf(0.05, delta)
		_t += dt
		for b: Dictionary in _bits:
			b["y"] = float(b["y"]) + float(b["vy"]) * dt
			b["x"] = float(b["x"]) + float(b["vx"]) * dt
			if float(b["y"]) > size.y + 10.0:
				b["y"] = -10.0
				b["x"] = randf() * size.x
			if float(b["x"]) < -10.0:
				b["x"] = size.x + 10.0
		queue_redraw()
		if _fx_node != null:
			_fx_node.queue_redraw()

	func _draw() -> void:
		_fx.clear()
		var w := size.x
		var h := size.y
		var floor_y := h * 0.9
		var grade_color := Color(grade["color"])

		Draw2D.vgradient_rect(self, Rect2(0, 0, w, h), Color("0a0d14"), Color("05070b"))

		# Lichtkegel in der Farbe der Bewertung
		var pulse := 0.5 + sin(_t * 2.2) * 0.5
		Effects.glow(_fx, w * 0.5, floor_y, h * 0.95, grade_color, 0.24 + pulse * 0.1)

		# Ringe auf dem Boden
		for i in 3:
			var p := fmod(_t * (0.6 if _good else 0.25) + i / 3.0, 1.0)
			Draw2D.ellipse_outline(
				self, Vector2(w * 0.5, floor_y),
				Vector2(40.0 + p * w * 0.42, 8.0 + p * h * 0.05),
				Palette.with_alpha(grade_color, (1.0 - p) * 0.35), 2.0
			)

		# Sterne als Aura ueber dem Kopf, einer je erreichtem Stern
		for i in rating:
			var a := (float(i) / maxi(1, rating)) * TAU + _t * (1.1 if _good else 0.3)
			_star(
				w * 0.5 + cos(a) * w * 0.19, h * 0.2 + sin(a) * h * 0.045,
				9.0 + sin(_t * 3.0 + i) * 2.0, Palette.with_alpha(Palette.AMBER, 0.85)
			)

		Figure.draw(self, {
			"x": w * 0.5, "y": floor_y, "h": h * 0.72,
			"look": _look, "personality": grade["mood"], "pose": grade["pose"],
			"t": _t, "accent": _accent,
		})

		# Partikel: Konfetti faellt, Regen stuerzt.
		for b: Dictionary in _bits:
			var pos := Vector2(float(b["x"]), float(b["y"]))
			if _bad:
				draw_line(
					pos, pos + Vector2(-4, 14),
					Color(150.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0, 0.25), 1.0, true
				)
			else:
				var s: float = b["size"]
				var basis := Transform2D(float(b["spin"]) + _t * 3.0, pos)
				draw_colored_polygon(PackedVector2Array([
					basis * Vector2(-s * 0.5, -s * 0.25),
					basis * Vector2(s * 0.5, -s * 0.25),
					basis * Vector2(s * 0.5, s * 0.25),
					basis * Vector2(-s * 0.5, s * 0.25),
				]), Palette.with_alpha(b["color"], 0.85))

		# Boden
		Draw2D.vgradient_rect(
			self, Rect2(0, floor_y - 10.0, w, h - floor_y + 10.0),
			Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)
		)

	func _star(x: float, y: float, r: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 10:
			var rad := r if i % 2 == 0 else r * 0.44
			var a := (PI / 5.0) * i - PI * 0.5
			points.append(Vector2(x + cos(a) * rad, y + sin(a) * rad))
		draw_colored_polygon(points, color)
