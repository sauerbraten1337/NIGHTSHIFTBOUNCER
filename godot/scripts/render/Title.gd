## Titelbildschirm: die Schauszene hinter dem Hauptmenue.
##
## Man sieht auf einen Blick, worum es geht - eine Clubfassade bei Nacht,
## Neonschrift ueber der Tuer, eine Schlange hinter der Kordel und davor der
## Tuersteher, der von hinten ins Bild ragt. Alles prozedural, kein Asset.
##
## Die Menuespalte liegt rechts, deshalb ist die Buehne nach links gewichtet
## und die rechte Bildhaelfte wird bewusst abgedunkelt.
##
## Portierung von src/render/title.js.
class_name Title
extends RefCounted

## Feste Zufallswerte: die Szene soll bei jedem Start gleich aussehen.
static func _seeded(i: float, salt: float = 0.0) -> float:
	var v := sin((i + 1.0) * 12.9898 + salt * 78.233) * 43758.5453
	return v - floor(v)

static var _crowd: Array[Dictionary] = []
static var _skyline: Array[Dictionary] = []

## Die Wartenden vor dem Club - Aussehen einmalig festgelegt.
static func crowd() -> Array[Dictionary]:
	if not _crowd.is_empty():
		return _crowd
	var moods := ["polite", "annoyed", "drunk", "arrogant", "nervous"]
	for i in 11:
		_crowd.append({
			"look": {
				"skin": int(floor(_seeded(i, 1) * Palette.SKIN.size())),
				"outfit": int(floor(_seeded(i, 2) * Palette.OUTFIT.size())),
				"hair": int(floor(_seeded(i, 3) * Palette.HAIR.size())),
				"bulk": 0.9 + _seeded(i, 4) * 0.3,
			},
			"personality": moods[int(floor(_seeded(i, 5) * 5))],
			"drunk": (0.5 + _seeded(i, 7) * 0.4) if _seeded(i, 6) > 0.7 else 0.0,
			"phase": _seeded(i, 8) * 6.28,
		})
	return _crowd

static func skyline() -> Array[Dictionary]:
	if not _skyline.is_empty():
		return _skyline
	for i in 26:
		_skyline.append({
			"w": 40.0 + _seeded(i, 11) * 74.0,
			"h": 60.0 + _seeded(i, 12) * 150.0,
		})
	return _skyline

## Zeichnet die ganze Schauszene. `fx` nimmt die additiven Anteile auf.
static func draw_title_scene(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, pulse: float = 0.0
) -> void:
	var horizon := h * 0.62

	_draw_sky(ci, fx, w, h, horizon, t)
	_draw_skyline(ci, w, horizon)
	_draw_street(ci, fx, w, h, horizon)
	_draw_facade(ci, fx, w, h, horizon, t, pulse)
	_draw_queue(ci, w, h, horizon, t)
	_draw_rope(ci, w, horizon, h)
	_draw_bouncer_back(ci, fx, w, h, t, pulse)
	_draw_atmosphere(ci, fx, w, h, horizon, t)
	_draw_scrim(ci, w, h)

# ---------------- Kulisse ----------------

static func _draw_sky(
	ci: CanvasItem, fx: Variant, w: float, h: float, horizon: float, t: float
) -> void:
	# Der Himmelsverlauf hat drei Stufen - in Godot zwei Rechtecke.
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, horizon * 0.55), Color("05070c"), Color("0c1018"))
	Draw2D.vgradient_rect(
		ci, Rect2(0, horizon * 0.55, w, horizon * 0.45), Color("0c1018"), Color("1a1320")
	)

	# Lichtschein der Stadt ueber dem Horizont
	fx.draw_polygon(
		PackedVector2Array([
			Vector2(0, horizon - 220.0), Vector2(w, horizon - 220.0),
			Vector2(w, horizon), Vector2(0, horizon),
		]),
		PackedColorArray([
			Palette.with_alpha(Palette.RED, 0.0), Palette.with_alpha(Palette.RED, 0.0),
			Palette.with_alpha(Palette.RED, 0.1), Palette.with_alpha(Palette.RED, 0.1),
		])
	)

	# Zwei Suchscheinwerfer wandern langsam ueber den Himmel
	for entry: Array in [[0, Palette.CYAN], [1, Palette.RED]]:
		var i: int = entry[0]
		var color: Color = entry[1]
		var base := w * (0.62 if i == 1 else 0.16)
		var angle := sin(t * 0.22 + i * 2.1) * 0.55 + (0.3 if i == 1 else -0.3)
		Effects.beam(fx, base, horizon, PI + angle, horizon * 1.15, 26.0, color, 0.05)

static func _draw_skyline(ci: CanvasItem, w: float, horizon: float) -> void:
	var x := -30.0
	var buildings := skyline()
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if x > w + 40.0:
			break
		var bw := float(b["w"])
		var bh := float(b["h"])
		ci.draw_rect(
			Rect2(x, horizon - bh, bw, bh),
			Color("0a0e15") if i % 3 == 0 else Color("0d1119")
		)
		# beleuchtete Fenster
		var wy := horizon - bh + 10.0
		while wy < horizon - 10.0:
			var wx := x + 7.0
			while wx < x + bw - 8.0:
				var s := _seeded(round(wx), round(wy))
				if s > 0.78:
					var c := Color("9fd8ff") if s > 0.95 else Color("ffd9a0")
					c.a = 0.1 + s * 0.12
					ci.draw_rect(Rect2(wx, wy, 5, 7), c)
				wx += 13.0
			wy += 15.0
		x += bw + 8.0

static func _draw_street(
	ci: CanvasItem, fx: Variant, w: float, h: float, horizon: float
) -> void:
	var mid := horizon + (h - horizon) * 0.5
	Draw2D.vgradient_rect(ci, Rect2(0, horizon, w, mid - horizon), Color("171c25"), Color("11151d"))
	Draw2D.vgradient_rect(ci, Rect2(0, mid, w, h - mid), Color("11151d"), Color("080a0e"))

	# Nasser Asphalt: die Lichter spiegeln sich in Streifen
	for i in 26:
		var rx := _seeded(i, 21) * w
		var ry := horizon + _seeded(i, 22) * (h - horizon)
		var c := Palette.RED if i % 4 != 0 else Palette.CYAN
		c.a = 0.02 + _seeded(i, 23) * 0.03
		fx.draw_rect(Rect2(rx, ry, 20.0 + _seeded(i, 24) * 120.0, 2.0), c)

	# Bordstein
	ci.draw_line(
		Vector2(0, horizon + 8.5), Vector2(w, horizon + 8.5),
		Palette.with_alpha(Palette.LINE, 0.4), 2.0, true
	)

## Die Clubfassade mit Tuer, Neonschrift und Bass-Licht.
static func _draw_facade(
	ci: CanvasItem, fx: Variant, w: float, h: float, horizon: float, t: float, pulse: float
) -> void:
	var fx_pos := w * 0.06
	var fw := w * 0.62
	var fy := h * 0.04
	var fh := horizon - fy + 10.0

	# Mauerwerk
	Draw2D.vgradient_rect(ci, Rect2(fx_pos, fy, fw, fh * 0.6), Color("1b2029"), Color("151a22"))
	Draw2D.vgradient_rect(
		ci, Rect2(fx_pos, fy + fh * 0.6, fw, fh * 0.4), Color("151a22"), Color("0f1319")
	)

	var joint := Color(0, 0, 0, 0.35)
	var y := fy + 26.0
	while y < fy + fh:
		ci.draw_line(Vector2(fx_pos, y), Vector2(fx_pos + fw, y), joint, 1.0, true)
		y += 26.0
	var x := fx_pos + 44.0
	while x < fx_pos + fw:
		ci.draw_line(Vector2(x, fy), Vector2(x, fy + fh), joint, 1.0, true)
		x += 44.0

	# Plakate an der Wand
	var poster_colors := [Color("d8d2c4"), Color("c4b6a2"), Color("b9c3d0")]
	for i in 4:
		var px := fx_pos + 26.0 + i * 62.0
		var py := fy + fh * 0.42 + _seeded(i, 31) * 30.0
		var basis := Transform2D((_seeded(i, 32) - 0.5) * 0.12, Vector2(px, py))
		var paper: Color = poster_colors[i % 3]
		paper.a = 0.14
		ci.draw_colored_polygon(PackedVector2Array([
			basis * Vector2(0, 0), basis * Vector2(44, 0),
			basis * Vector2(44, 60), basis * Vector2(0, 60),
		]), paper)
		var band := Palette.RED if i % 2 == 1 else Palette.CYAN
		band.a = 0.18
		ci.draw_colored_polygon(PackedVector2Array([
			basis * Vector2(4, 6), basis * Vector2(40, 6),
			basis * Vector2(40, 24), basis * Vector2(4, 24),
		]), band)

	# Tuernische
	var dw := fw * 0.3
	var dx := fx_pos + fw * 0.52
	var dh := fh * 0.5
	var dy := fy + fh - dh
	ci.draw_rect(Rect2(dx - 16.0, dy - 18.0, dw + 32.0, dh + 18.0), Color("0b0e14"))
	ci.draw_rect(
		Rect2(dx - 16.5, dy - 18.5, dw + 33.0, dh + 19.0),
		Palette.with_alpha(Palette.CONCRETE_LIGHT, 0.5), false, 2.0
	)

	# Offene Tuer: rotes Licht drueckt auf die Strasse
	Draw2D.vgradient_rect(
		ci, Rect2(dx, dy, dw, dh),
		Palette.with_alpha(Palette.RED, 0.5 + pulse * 0.3),
		Palette.with_alpha(Color("2b0509"), 0.95)
	)

	# Silhouetten im Tuerrahmen
	var shadow := Color(5.0 / 255.0, 3.0 / 255.0, 5.0 / 255.0, 0.82)
	for i in 3:
		var sx := dx + dw * (0.3 + i * 0.24) + sin(t * 1.4 + i) * 4.0
		var sh := dh * (0.34 + _seeded(i, 41) * 0.08)
		Draw2D.ellipse(
			ci, Vector2(sx, dy + dh - sh * 0.5), Vector2(dw * 0.065, sh * 0.5), shadow
		)
		ci.draw_circle(Vector2(sx, dy + dh - sh), dw * 0.04, shadow)

	# Lichtteppich vor der Tuer
	fx.draw_polygon(
		PackedVector2Array([
			Vector2(dx, dy + dh), Vector2(dx + dw, dy + dh),
			Vector2(dx + dw * 2.1, h), Vector2(dx - dw * 1.1, h),
		]),
		PackedColorArray([
			Palette.with_alpha(Palette.RED, 0.22 + pulse * 0.1),
			Palette.with_alpha(Palette.RED, 0.22 + pulse * 0.1),
			Palette.with_alpha(Palette.RED, 0.0),
			Palette.with_alpha(Palette.RED, 0.0),
		])
	)

	Effects.glow(
		fx, dx + dw * 0.5, dy + dh * 0.9, 260.0 + pulse * 90.0, Palette.RED,
		0.16 + pulse * 0.1
	)

	# Vordach mit zwei Lampen
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(dx - 44.0, dy - 18.0), Vector2(dx + dw + 44.0, dy - 18.0),
		Vector2(dx + dw + 22.0, dy - 44.0), Vector2(dx - 22.0, dy - 44.0),
	]), Color("0d1117"))
	for side: float in [0.18, 0.82]:
		var lx := dx + dw * side
		ci.draw_circle(Vector2(lx, dy - 22.0), 5.0, Palette.with_alpha(Palette.AMBER, 0.9))
		Effects.glow(fx, lx, dy - 22.0, 90.0, Palette.AMBER, 0.1)

	# Hausnummer neben der Tuer
	Draw2D.text(
		ci, Fonts.mono_spaced(4.0), Vector2(dx - 12.0, dy + dh - 8.0),
		"NR. 01 · NACHTS", 13, Palette.with_alpha(Palette.GREY, 0.5)
	)

	_draw_neon(ci, fx, dx + dw * 0.5, dy - 78.0, w, t)

## Neonschriftzug des Clubs ueber der Tuer - flackert wie eine echte Roehre.
static func _draw_neon(
	ci: CanvasItem, fx: Variant, cx: float, cy: float, w: float, t: float
) -> void:
	var flick := 1.0
	if sin(t * 11.0) > 0.82:
		flick = 0.45
	elif sin(t * 2.3) > 0.98:
		flick = 0.7

	# Halterung
	ci.draw_line(
		Vector2(cx - w * 0.14, cy + 26.0), Vector2(cx + w * 0.14, cy + 26.0),
		Color(0, 0, 0, 0.6), 3.0, true
	)

	# ctx.shadowBlur gibt es nicht; der Neon-Schein entsteht aus mehreren
	# groesser gesetzten, halbdurchsichtigen Kopien auf der additiven Ebene.
	var size := int(round(w * 0.042))
	var font := Fonts.display_spaced(10.0)
	for spread: float in [6.0, 3.5, 1.5]:
		var halo := Palette.with_alpha(Color("ff6a72"), 0.1 * flick)
		for a in 8:
			var ang := (float(a) / 8.0) * TAU
			fx.draw_string(
				font, Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * spread
					+ Vector2(-Draw2D.text_width(font, Config.CLUB_NAME, size) * 0.5, size * 0.36),
				Config.CLUB_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo
			)
	# Die Vorlage zeichnet den Schriftzug selbst unter 'lighter' - er leuchtet
	# also additiv und nimmt die Farbe der Fassade an, statt sie zu verdecken.
	# Darum gehoert er auf die Effektebene, nicht auf die Grundebene.
	var name_width := Draw2D.text_width(font, Config.CLUB_NAME, size)
	var baseline := Vector2(cx - name_width * 0.5, cy + (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	fx.draw_string(
		font, baseline, Config.CLUB_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Palette.with_alpha(Color("ff6a72"), 0.85 * flick)
	)
	fx.draw_string(
		font, baseline, Config.CLUB_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Palette.with_alpha(Color("ffe9ea"), 0.9 * flick)
	)

	Draw2D.text(
		ci, Fonts.mono_spaced(8.0), Vector2(cx, cy + 34.0), "NACHTS OFFEN", 12,
		Palette.with_alpha(Palette.CYAN, 0.55 * flick),
		Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)

# ---------------- Menschen ----------------

## Die Schlange: von der Tuer weg nach links hinten, in die Tiefe kleiner.
static func _draw_queue(ci: CanvasItem, w: float, h: float, horizon: float, t: float) -> void:
	var people := crowd()
	# Hinten zuerst: die vorderen Gaeste sollen die hinteren ueberdecken.
	for i in range(people.size() - 1, -1, -1):
		var p: Dictionary = people[i]
		var depth := float(i) / float(people.size() - 1)
		var scale := 1.0 - depth * 0.42
		var x := w * (0.47 - depth * 0.3) + sin(depth * 9.0) * 10.0
		var y := horizon + (h - horizon) * (0.62 - depth * 0.34)
		Figure.draw(ci, {
			"x": x, "y": y,
			"h": h * 0.34 * scale,
			"look": p["look"],
			"personality": p["personality"],
			"t": t + float(p["phase"]),
			"drunk": float(p["drunk"]),
			"bag": i % 4 == 0,
			"dim": 0.12 + depth * 0.38,
		})

## Absperrkordel zwischen zwei Pfosten.
static func _draw_rope(ci: CanvasItem, w: float, horizon: float, h: float) -> void:
	var y := horizon + (h - horizon) * 0.4
	var posts := [w * 0.28, w * 0.52]
	var post_color := Palette.with_alpha(Color("77808e"), 0.7)
	for px: float in posts:
		ci.draw_line(Vector2(px, y), Vector2(px, y - 62.0), post_color, 4.0, true)
		ci.draw_circle(Vector2(px, y - 68.0), 6.0, Color("98a1ad"))
		Draw2D.ellipse(ci, Vector2(px, y + 2.0), Vector2(14.0, 4.0), Color(0, 0, 0, 0.45))
	Draw2D.stroke_path(ci, Draw2D.quad_curve(
		Vector2(posts[0], y - 62.0),
		Vector2((posts[0] + posts[1]) * 0.5, y - 28.0),
		Vector2(posts[1], y - 62.0)
	), Palette.with_alpha(Palette.RED, 0.75), 6.0)

## Der Tuersteher im Vordergrund - von hinten, angeschnitten, sehr gross.
## Er ist fast eine Silhouette; nur die Kanten fangen das Tuerlicht.
static func _draw_bouncer_back(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, pulse: float
) -> void:
	var cx := w * 0.155 + sin(t * 0.6) * 3.0
	var base := h * 1.14
	var bh := h * 0.86
	var shoulder_w := bh * 0.27
	var head_r := bh * 0.085
	var shoulder_y := base - bh + head_r * 2.6

	# Koerper
	var body := PackedVector2Array([Vector2(cx - shoulder_w, shoulder_y + bh * 0.05)])
	Draw2D.append_quad(
		body, Vector2(cx - shoulder_w * 1.05, shoulder_y - bh * 0.02),
		Vector2(cx - shoulder_w * 0.5, shoulder_y - bh * 0.03)
	)
	Draw2D.append_quad(
		body, Vector2(cx, shoulder_y - bh * 0.055),
		Vector2(cx + shoulder_w * 0.5, shoulder_y - bh * 0.03)
	)
	Draw2D.append_quad(
		body, Vector2(cx + shoulder_w * 1.05, shoulder_y - bh * 0.02),
		Vector2(cx + shoulder_w, shoulder_y + bh * 0.05)
	)
	body.append(Vector2(cx + shoulder_w * 1.04, base))
	body.append(Vector2(cx - shoulder_w * 1.04, base))
	# Verlauf von den Schultern zum Boden: Farbe je Eckpunkt nach Hoehe.
	var colors := PackedColorArray()
	var top_c := Color("0d1119")
	var bottom_c := Color("04060a")
	for p: Vector2 in body:
		var f := clampf((p.y - shoulder_y) / maxf(1.0, base - shoulder_y), 0.0, 1.0)
		colors.append(Draw2D.mix(top_c, bottom_c, f))
	ci.draw_polygon(body, colors)

	# Arme, vor der Brust verschraenkt (von hinten: Ellbogen stehen ab)
	for side: float in [-1.0, 1.0]:
		Draw2D.line_round(
			ci,
			Vector2(cx + side * shoulder_w * 0.85, shoulder_y + bh * 0.07),
			Vector2(cx + side * shoulder_w * 1.16, shoulder_y + bh * 0.2),
			Color("0b0e15"), bh * 0.075
		)

	# Nacken und kahler Kopf
	var head_color := Color("0d1117")
	ci.draw_rect(Rect2(
		cx - head_r * 0.55, shoulder_y - head_r * 1.1, head_r * 1.1, head_r * 1.4
	), head_color)
	Draw2D.ellipse(
		ci, Vector2(cx, shoulder_y - head_r * 1.5),
		Vector2(head_r * 0.94, head_r), head_color
	)
	# Ohren
	Draw2D.ellipse(
		ci, Vector2(cx - head_r * 0.92, shoulder_y - head_r * 1.45),
		Vector2(head_r * 0.16, head_r * 0.26), head_color
	)
	Draw2D.ellipse(
		ci, Vector2(cx + head_r * 0.92, shoulder_y - head_r * 1.45),
		Vector2(head_r * 0.16, head_r * 0.26), head_color
	)

	# Kantenlicht vom Tuerlicht rechts hinten
	var rim := PackedVector2Array([
		Vector2(cx + shoulder_w * 1.02, base),
		Vector2(cx + shoulder_w * 0.99, shoulder_y + bh * 0.05),
	])
	Draw2D.append_quad(
		rim, Vector2(cx + shoulder_w * 1.04, shoulder_y - bh * 0.02),
		Vector2(cx + shoulder_w * 0.5, shoulder_y - bh * 0.03)
	)
	fx.draw_polyline(rim, Palette.with_alpha(Palette.RED, 0.4 + pulse * 0.25), 3.0, true)
	fx.draw_polyline(
		Draw2D.ellipse_points(
			Vector2(cx, shoulder_y - head_r * 1.5),
			Vector2(head_r * 0.94, head_r * 0.94), -PI * 0.42, PI * 0.28
		),
		Palette.with_alpha(Palette.RED, 0.4 + pulse * 0.25), 3.0, true
	)
	var rim_l := PackedVector2Array([
		Vector2(cx - shoulder_w * 1.02, base),
		Vector2(cx - shoulder_w * 0.99, shoulder_y + bh * 0.05),
	])
	Draw2D.append_quad(
		rim_l, Vector2(cx - shoulder_w * 1.04, shoulder_y - bh * 0.02),
		Vector2(cx - shoulder_w * 0.5, shoulder_y - bh * 0.03)
	)
	fx.draw_polyline(rim_l, Palette.with_alpha(Palette.CYAN, 0.12), 3.0, true)

	# Headset-Buegel und Ohrhoerer
	Draw2D.stroke_path(ci, Draw2D.ellipse_points(
		Vector2(cx, shoulder_y - head_r * 1.55),
		Vector2(head_r * 1.02, head_r * 1.02), PI * 1.12, PI * 1.88
	), Color("1b212b"), maxf(2.0, head_r * 0.14))
	ci.draw_circle(
		Vector2(cx - head_r * 0.96, shoulder_y - head_r * 1.42), head_r * 0.24, Color("262d38")
	)
	ci.draw_circle(
		Vector2(cx - head_r * 0.96, shoulder_y - head_r * 1.42), head_r * 0.08,
		Palette.with_alpha(Palette.GREEN, 0.9 if sin(t * 3.0) > 0.0 else 0.25)
	)

	# CREW-Aufdruck auf dem Ruecken
	Draw2D.text(
		ci, Fonts.display_spaced(8.0), Vector2(cx, shoulder_y + bh * 0.3), "SECURITY",
		int(round(bh * 0.05)), Palette.with_alpha(Color("7a8493"), 0.32), Draw2D.Align.CENTER
	)

# ---------------- Stimmung ----------------

static func _draw_atmosphere(
	ci: CanvasItem, fx: Variant, w: float, h: float, horizon: float, t: float
) -> void:
	# Bodennebel
	for i in 9:
		var fxp := fmod(i * 173.0 + t * 12.0, w + 400.0) - 200.0
		var fyp := horizon + 40.0 + _seeded(i, 51) * (h - horizon) * 0.7
		var r := 130.0 + _seeded(i, 52) * 140.0
		var c := Color("4b5b78") if i % 3 != 0 else Palette.RED
		Effects.glow(fx, fxp, fyp, r, c, 0.05)

	# Nieselregen - duenne, schraege Striche
	var rain := Color(180.0 / 255.0, 205.0 / 255.0, 235.0 / 255.0, 0.16)
	for i in 90:
		var speed := 380.0 + _seeded(i, 61) * 260.0
		var x := fmod(_seeded(i, 62) * w + t * 40.0, w)
		var y := fmod(_seeded(i, 63) * h + t * speed, h)
		ci.draw_line(Vector2(x, y), Vector2(x - 4.0, y + 16.0), rain, 1.0, true)

## Rechte Bildhaelfte abdunkeln, damit das Menue sauber darauf liegt.
static func _draw_scrim(ci: CanvasItem, w: float, h: float) -> void:
	var clear := Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.0)
	var mid := Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.62)
	var full := Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.9)
	# Der Verlauf beginnt bei 42% Breite - links davon liegt nichts.
	var start := w * 0.42
	var mid_x := start + (w - start) * 0.45
	Draw2D.hgradient_rect(ci, Rect2(start, 0, mid_x - start, h), clear, mid)
	Draw2D.hgradient_rect(ci, Rect2(mid_x, 0, w - mid_x, h), mid, full)

	var bottom_clear := Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.0)
	var bottom_full := Color(4.0 / 255.0, 5.0 / 255.0, 9.0 / 255.0, 0.75)
	Draw2D.vgradient_rect(ci, Rect2(0, h * 0.82, w, h * 0.18), bottom_clear, bottom_full)
