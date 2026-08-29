## Die Spielansicht aus Sicht des Personals.
##
##   BOUNCER  - steht an der Tuer und sieht die Strasse, den Gast und die Schlange
##   SECURITY - steht in der Schleuse und sieht den Gast, Scanner und Clubtuer
##
## Beides sind 2D-Szenen (Frontansicht mit Tiefenstaffelung), kein 3D.
##
## Portierung von src/render/scene.js. Die Vorlage schneidet die Ansicht per
## ctx.clip() zu und verschiebt den Kontext; hier bekommt jede Ansicht ihren
## eigenen SubViewport (siehe Renderer.gd), und alle Koordinaten sind relativ
## zur Ansicht - der Versatz entfaellt damit ganz.
class_name Scene
extends RefCounted

## Zeichnet eine Stationsansicht.
##
## opts: { size: Vector2, area: 'outside'|'airlock', station, queue: [],
##         t, beat, pulse, dark }
##
## Rueckgabe: { zones: [], keys: [] } - anklickbare Abtast-Ringe und
## Abwehr-Tasten in Ansichtskoordinaten.
static func draw_station_view(
	ci: CanvasItem, fx_layer: Variant, game: Dictionary, opts: Dictionary
) -> Dictionary:
	if opts["area"] == "outside":
		_draw_outside(ci, fx_layer, game, opts)
	else:
		_draw_airlock(ci, fx_layer, game, opts)
	return _draw_guest_at_station(ci, fx_layer, game, opts)

# ----------------------------------------------------------------
# DRAUSSEN: Eingang, Strasse, Schlange
# ----------------------------------------------------------------

static func _draw_outside(
	ci: CanvasItem, fx_layer: Variant, game: Dictionary, opts: Dictionary
) -> void:
	var size: Vector2 = opts["size"]
	var t := float(opts["t"])
	var pulse := float(opts.get("pulse", 0.0))
	var dark := float(opts.get("dark", 0.0))
	var w := size.x
	var h := size.y
	var horizon := h * 0.5
	var light := 1.0 - dark

	# Himmel / Nachtluft
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, horizon), Color("080a10"), Color("141a26"))

	# Stadtsilhouette
	var building := Color("0d1119")
	var window_color := Palette.with_alpha(Color("ffd9a0"), 0.12 * light)
	var bx := -20.0
	var i := 0
	while bx < w + 40.0:
		var bw := 46.0 + fmod(i * 37.0, 60.0)
		var bh := 40.0 + fmod(i * 53.0, 90.0)
		ci.draw_rect(Rect2(bx, horizon - bh, bw, bh), building)
		# Fenster
		var wy := horizon - bh + 8.0
		while wy < horizon - 8.0:
			var wx := bx + 6.0
			while wx < bx + bw - 8.0:
				if fmod(wx * wy + i, 7.0) < 2.0:
					ci.draw_rect(Rect2(wx, wy, 4, 6), window_color)
				wx += 12.0
			wy += 14.0
		bx += bw + 10.0
		i += 1

	# Boden (Asphalt) mit Fluchtlinien
	Draw2D.vgradient_rect(
		ci, Rect2(0, horizon, w, h - horizon), Color("171c25"), Color("0d1015")
	)

	var line_color := Palette.with_alpha(Palette.LINE, 0.35 * light)
	for k in range(-6, 7):
		ci.draw_line(
			Vector2(w * 0.5 + k * 22.0, horizon), Vector2(w * 0.5 + k * 190.0, h),
			line_color, 1.0, true
		)
	for d in range(1, 7):
		var y := horizon + pow(float(d) / 6.0, 2.1) * (h - horizon)
		ci.draw_line(Vector2(0, y), Vector2(w, y), line_color, 1.0, true)

	# Clubwand links und rechts (wir stehen im Eingang)
	_draw_side_wall(ci, 0.0, w * 0.19, h, horizon, 1)
	_draw_side_wall(ci, w - w * 0.19, w * 0.19, h, horizon, -1)

	# Tuerlicht von hinten ueber die Schulter des Spielers
	Effects.glow(
		fx_layer, w * 0.5, h * 1.05, h * 0.9, Palette.RED, (0.2 + pulse * 0.08) * light
	)

	# Absperrgitter
	_draw_barrier(ci, w, horizon, h, light)

	# Warteschlange in der Tiefe
	_draw_queue_depth(ci, opts, horizon)

	# Strassenlaterne
	Effects.glow(fx_layer, w * 0.12, horizon - 30.0, 150.0, Palette.AMBER, 0.12 * light)
	Effects.glow(fx_layer, w * 0.88, horizon - 40.0, 120.0, Palette.CYAN, 0.06 * light)

	_draw_counter(ci, w, h, light, "TÜRPULT", Palette.RED)

## Das Pult, an dem der Spieler steht - unterer Bildrand.
static func _draw_counter(
	ci: CanvasItem, w: float, h: float, light: float, label: String, accent: Color
) -> void:
	var top := h * 0.9
	var top_color := Color("1a1f28")
	var bottom_color := Color("0a0d12")
	Draw2D.gradient_polygon(ci, PackedVector2Array([
		Vector2(-20, h), Vector2(w * 0.06, top), Vector2(w * 0.94, top), Vector2(w + 20, h),
	]), PackedColorArray([bottom_color, top_color, top_color, bottom_color]))

	ci.draw_line(
		Vector2(w * 0.06, top + 0.5), Vector2(w * 0.94, top + 0.5),
		Palette.with_alpha(accent, 0.4 * light), 2.0, true
	)

	# Klemmbrett mit Gaesteliste
	Draw2D.fill_round_rect(
		ci, Rect2(w * 0.1, top + 14.0, w * 0.14, h * 0.075), 3.0, Color("252b36")
	)
	var paper := Palette.with_alpha(Color("c9d2df"), 0.5 * light)
	for i in 4:
		ci.draw_rect(
			Rect2(w * 0.11, top + 24.0 + i * 10.0, w * 0.115 - (i % 2) * 12.0, 2.0), paper
		)

	Draw2D.text(
		ci, Fonts.mono_spaced(3.0), Vector2(w * 0.93, top + 22.0), label, 9,
		Palette.with_alpha(Palette.GREY, 0.55 * light), Draw2D.Align.RIGHT
	)

static func _draw_side_wall(
	ci: CanvasItem, x: float, ww: float, h: float, horizon: float, dir: int
) -> void:
	var near := Color("232935")
	var far := Color("141922")
	var points: PackedVector2Array
	var colors: PackedColorArray
	if dir == 1:
		points = PackedVector2Array([
			Vector2(0, 0), Vector2(ww, horizon * 0.55),
			Vector2(ww, h - horizon * 0.2), Vector2(0, h),
		])
		colors = PackedColorArray([near, far, far, near])
	else:
		points = PackedVector2Array([
			Vector2(x + ww, 0), Vector2(x, horizon * 0.55),
			Vector2(x, h - horizon * 0.2), Vector2(x + ww, h),
		])
		colors = PackedColorArray([near, far, far, near])
	Draw2D.gradient_polygon(ci, points, colors)
	Draw2D.stroke_path(ci, points, Color(0, 0, 0, 0.5), 1.0, true)

static func _draw_barrier(
	ci: CanvasItem, w: float, horizon: float, h: float, light: float
) -> void:
	var y := horizon + (h - horizon) * 0.42
	var post := Palette.with_alpha(Color("6d7684"), 0.5 * light)
	for side: float in [-1.0, 1.0]:
		var x := w * 0.5 + side * w * 0.34
		ci.draw_line(Vector2(x, y), Vector2(x, y - 46.0), post, 3.0, true)
		ci.draw_circle(Vector2(x, y - 50.0), 4.0, Color("8a929e"))
	# Kordel
	Draw2D.stroke_path(ci, Draw2D.quad_curve(
		Vector2(w * 0.5 - w * 0.34, y - 46.0),
		Vector2(w * 0.5, y - 26.0),
		Vector2(w * 0.5 + w * 0.34, y - 46.0)
	), Palette.with_alpha(Palette.RED, 0.55 * light), 4.0)

## Die Schlange verschwindet perspektivisch nach hinten.
static func _draw_queue_depth(ci: CanvasItem, opts: Dictionary, horizon: float) -> void:
	var size: Vector2 = opts["size"]
	var t := float(opts["t"])
	var queue: Array = opts.get("queue", [])
	var h := size.y
	var w := size.x
	var shown := mini(queue.size(), 9)

	for i in range(shown - 1, -1, -1):
		var guest: Dictionary = queue[i]
		var depth := float(i + 1) / 10.0
		var scale := 1.0 - pow(depth, 0.55) * 0.72
		var y := horizon + (h - horizon) * (0.5 - depth * 0.42)
		var offset := ((i % 2) * 2.0 - 1.0) * (26.0 + i * 5.0) * (1.0 - depth * 0.5)
		Figure.draw(ci, {
			"x": w * 0.5 + offset,
			"y": y,
			"h": h * 0.42 * scale,
			"look": guest["look"],
			"personality": guest["personality"],
			"t": t + float(guest["swayPhase"]),
			"drunk": float((guest["truth"] as Dictionary)["drunk"]),
			"vip": bool((guest["truth"] as Dictionary)["vip"]),
			# Auffaelligkeiten sieht man schon in der Schlange - wer hinsieht,
			# weiss vorher, was gleich vor ihm steht.
			"signs": (guest["truth"] as Dictionary).get("impairmentSigns", []),
			"dim": 0.25 + depth * 0.45,
		})

	if queue.size() > shown:
		Draw2D.text(
			ci, Fonts.mono(), Vector2(w * 0.5, horizon - 6.0),
			"+%d WEITERE" % (queue.size() - shown), 11,
			Palette.with_alpha(Palette.GREY, 0.7), Draw2D.Align.CENTER
		)

# ----------------------------------------------------------------
# INNEN: Sicherheitsschleuse
# ----------------------------------------------------------------

static func _draw_airlock(
	ci: CanvasItem, fx_layer: Variant, game: Dictionary, opts: Dictionary
) -> void:
	var size: Vector2 = opts["size"]
	var t := float(opts["t"])
	var pulse := float(opts.get("pulse", 0.0))
	var dark := float(opts.get("dark", 0.0))
	var w := size.x
	var h := size.y
	var horizon := h * 0.46
	var light := 1.0 - dark
	var state: Dictionary = game["state"]

	# Rueckwand
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, horizon), Color("2a3140"), Color("1b212b"))

	# Betonfugen
	var joint := Color(0, 0, 0, 0.3)
	var y := 20.0
	while y < horizon:
		ci.draw_line(Vector2(0, y), Vector2(w, y), joint, 1.0, true)
		y += 34.0
	var x := 30.0
	while x < w:
		ci.draw_line(Vector2(x, 0), Vector2(x, horizon), joint, 1.0, true)
		x += 90.0

	# Boden mit Fluchtlinien
	Draw2D.vgradient_rect(
		ci, Rect2(0, horizon, w, h - horizon), Color("20262f"), Color("12161c")
	)
	var line_color := Palette.with_alpha(Palette.LINE, 0.4 * light)
	for k in range(-5, 6):
		ci.draw_line(
			Vector2(w * 0.5 + k * 26.0, horizon), Vector2(w * 0.5 + k * 200.0, h),
			line_color, 1.0, true
		)
	for d in range(1, 6):
		var fy := horizon + pow(float(d) / 5.0, 2.0) * (h - horizon)
		ci.draw_line(Vector2(0, fy), Vector2(w, fy), line_color, 1.0, true)

	# Warnstreifen auf dem Boden
	for s in 14:
		var stripe := Color("1b1f27") if s % 2 == 1 else Palette.AMBER
		stripe.a = 0.5 * light
		ci.draw_rect(Rect2(s * (w / 14.0), h * 0.86, w / 14.0, 8.0), stripe)

	# Tuer nach draussen (links) und in den Club (rechts)
	_draw_doorway(
		ci, w * 0.05, horizon * 0.42, w * 0.11, horizon * 0.58,
		Color("0a0d12"), Palette.CYAN, "RAUS", light
	)
	_draw_doorway(
		ci, w * 0.84, horizon * 0.38, w * 0.11, horizon * 0.62,
		Color("12060a"), Palette.RED, "CLUB", light
	)

	# Bass-Licht aus der Clubtuer
	Effects.glow(
		fx_layer, w * 0.895, horizon * 0.7, 110.0 + pulse * 50.0, Palette.RED,
		(0.16 + pulse * 0.16) * light
	)

	# Scanner-Bogen hinter dem Gast
	_draw_scanner_arch(
		ci, w, horizon, h, t, light, GameState.upgrade_level(state, "detector")
	)

	# Kamera
	_draw_camera(ci, w * 0.5, 22.0, t, GameState.upgrade_level(state, "cameras"))

	# Deckenlicht auf den Gast
	Effects.beam(fx_layer, w * 0.5, 0.0, 0.0, h * 0.8, w * 0.19, Color("cfe0ff"), 0.06 * light)
	Effects.glow(fx_layer, w * 0.5, h * 0.72, 190.0, Color("9fc0ff"), 0.05 * light)

	_draw_counter(ci, w, h, light, "KONTROLLTISCH", Palette.CYAN)

	# Wartende in der Schleuse
	var waiting: Array = opts.get("queue", [])
	for i in range(mini(waiting.size(), 3) - 1, -1, -1):
		var g: Dictionary = waiting[i]
		Figure.draw(ci, {
			"x": w * (0.18 + i * 0.07),
			"y": horizon + (h - horizon) * 0.42,
			"h": h * 0.34,
			"look": g["look"],
			"personality": g["personality"],
			"t": t + float(g["swayPhase"]),
			"drunk": float((g["truth"] as Dictionary)["drunk"]),
			"signs": (g["truth"] as Dictionary).get("impairmentSigns", []),
			"dim": 0.35 + i * 0.08,
		})

static func _draw_doorway(
	ci: CanvasItem, x: float, y: float, w: float, h: float,
	fill: Color, accent: Color, label: String, light: float
) -> void:
	ci.draw_rect(Rect2(x, y, w, h), fill)
	ci.draw_rect(
		Rect2(x + 0.5, y + 0.5, w - 1.0, h - 1.0),
		Palette.with_alpha(accent, 0.75 * light), false, 2.0
	)
	Draw2D.text(
		ci, Fonts.mono_spaced(3.0), Vector2(x + w * 0.5, y - 8.0), label, 10,
		Palette.with_alpha(accent, 0.85 * light), Draw2D.Align.CENTER
	)

static func _draw_scanner_arch(
	ci: CanvasItem, w: float, horizon: float, h: float, t: float, light: float, level: int
) -> void:
	var cx := w * 0.5
	var arch_w := w * 0.42
	var top := horizon * 0.46
	var bottom := horizon + (h - horizon) * 0.5

	var arch := PackedVector2Array([
		Vector2(cx - arch_w * 0.5, bottom), Vector2(cx - arch_w * 0.5, top + 20.0),
	])
	Draw2D.append_quad(arch, Vector2(cx, top - 10.0), Vector2(cx + arch_w * 0.5, top + 20.0))
	arch.append(Vector2(cx + arch_w * 0.5, bottom))
	Draw2D.polyline_round(ci, arch, Palette.with_alpha(Color("7c8593"), 0.8 * light), 10.0)

	# Statuslampen am Bogen
	var on := sin(t * 3.0) > 0.0
	for i in 6:
		var yy := top + 34.0 + i * ((bottom - top - 40.0) / 6.0)
		var lamp := Color("3a3a3a")
		if level >= 1:
			lamp = Palette.GREEN if on else Color("2c3a33")
		lamp.a = light
		for side: float in [-1.0, 1.0]:
			ci.draw_rect(Rect2(cx + side * (arch_w * 0.5) - 3.0, yy, 6.0, 4.0), lamp)

	Draw2D.text(
		ci, Fonts.mono_spaced(2.0), Vector2(cx, top + 4.0),
		"METALLDETEKTOR LV.%d" % level if level >= 1 else "KEIN DETEKTOR", 9,
		Palette.with_alpha(Palette.GREY, 0.7 * light), Draw2D.Align.CENTER
	)

static func _draw_camera(ci: CanvasItem, x: float, y: float, t: float, level: int) -> void:
	Draw2D.fill_round_rect(ci, Rect2(x - 14.0, y, 28.0, 12.0), 3.0, Color("1a1f28"))
	ci.draw_circle(Vector2(x + 10.0, y + 6.0), 5.0, Color("0b0e13"))
	if level >= 1:
		ci.draw_rect(
			Rect2(x - 10.0, y + 4.0, 4.0, 4.0),
			Palette.RED if sin(t * 2.0) > 0.0 else Color("3a1418")
		)

# ----------------------------------------------------------------
# Der Gast direkt vor dem Spieler
# ----------------------------------------------------------------

static func _draw_guest_at_station(
	ci: CanvasItem, fx_layer: Variant, game: Dictionary, opts: Dictionary
) -> Dictionary:
	var size: Vector2 = opts["size"]
	var station: Variant = opts.get("station", null)
	var t := float(opts["t"])
	var area := String(opts["area"])
	var guest: Variant = station["guest"] if station != null else null
	var w := size.x
	var h := size.y
	var base_y := h * (0.93 if area == "outside" else 0.92)

	if guest == null:
		Draw2D.text(
			ci, Fonts.mono_spaced(4.0), Vector2(w * 0.5, h * 0.62),
			"NIEMAND AN DER TÜR" if area == "outside" else "SCHLEUSE FREI", 12,
			Palette.with_alpha(Palette.GREY, 0.55), Draw2D.Align.CENTER
		)
		return {"zones": [], "keys": []}

	# Bei einem Uebergriff kommt der Gast auf einen zu: er wird gross, er wackelt.
	var aggro: Variant = station["aggro"]
	var near := pow(float(aggro.get("approach", 0.0)), 0.8) if aggro != null else 0.0
	var rattle := 0.0
	if aggro != null:
		rattle = sin(t * 30.0) * (
			2.0 + float(aggro.get("shake", 0.0)) * 6.0
			+ (5.0 if float(aggro["missFlash"]) > 0.0 else 0.0)
		)

	var checks: Dictionary = station["checks"]
	var holding: bool = checks["id"] != null and aggro == null
	var figure_h := _guest_height(w, h) * (1.0 + near * 0.55)
	var truth: Dictionary = guest["truth"]
	var accent: Variant = null
	if bool(guest.get("isArtist", false)):
		accent = Palette.AMBER
	elif bool(truth["vip"]):
		accent = Palette.PURPLE

	var bag_out := false
	if station["patdown"] != null:
		bag_out = bool((station["patdown"] as Dictionary)["bagOut"])

	var anchors := Figure.draw(ci, {
		"x": w * 0.5 + rattle,
		"y": base_y + near * h * 0.06,
		"h": figure_h,
		"look": guest["look"],
		"personality": "aggressive" if aggro != null else guest["personality"],
		"t": t + float(guest["swayPhase"]),
		"drunk": float(truth["drunk"]),
		"holdingId": holding,
		"vip": bool(truth["vip"]),
		"bag": bool(truth["hasBag"]) and aggro == null,
		"bagOut": bag_out,
		"signs": truth.get("impairmentSigns", []),
		"rage": maxf(0.35, near) if aggro != null else 0.0,
		"accent": accent,
	})

	# Angriff: Tastenfolge statt Kontrolle - alles andere hat jetzt Pause.
	if aggro != null:
		var keys := _draw_defense_overlay(ci, fx_layer, aggro, w, h, t)
		if guest["said"] != null and float(guest["saidTimer"]) > 0.0:
			# Die Figur ragt jetzt ueber den Bildrand hinaus - die Blase bleibt
			# im Bild.
			Sprites.draw_speech(
				ci, Fonts.mono(), w * 0.5, maxf(h * 0.14, base_y - figure_h - 26.0),
				guest["said"], Palette.RED, minf(320.0, w * 0.62)
			)
		return {"zones": [], "keys": keys}

	# Abtast-Zonen einblenden - die Ringe sitzen auf den echten Koerperstellen
	var zones: Array = []
	if station["patdown"] != null and not bool((station["patdown"] as Dictionary)["complete"]):
		zones = _draw_patdown_overlay(ci, fx_layer, station, t, anchors)

	# Alkoholtestgeraet liegt auf dem Tisch, sobald gemessen wurde
	if checks["alcohol"] != null:
		_draw_breathalyzer(
			ci, w, h, t, checks["alcohol"], "%s:%s" % [station["id"], guest["id"]]
		)

	# Sprechblase
	if guest["said"] != null and float(guest["saidTimer"]) > 0.0:
		Sprites.draw_speech(
			ci, Fonts.mono(), w * 0.5, base_y - figure_h - 26.0,
			guest["said"], Palette.WHITE, minf(320.0, w * 0.62)
		)

	# Kennzeichnung
	if bool(truth["vip"]) or bool(guest.get("isArtist", false)):
		var is_artist := bool(guest.get("isArtist", false))
		Draw2D.text(
			ci, Fonts.mono_spaced(3.0), Vector2(w * 0.5, base_y - figure_h - 34.0),
			"ACT" if is_artist else "VIP", 10,
			Palette.AMBER if is_artist else Palette.PURPLE, Draw2D.Align.CENTER
		)

	return {"zones": zones, "keys": []}

# ----------------------------------------------------------------
# Uebergriff: die Tasten, die jetzt sitzen muessen
# ----------------------------------------------------------------

## Zeichnet Warnrahmen, Tastenfolge und Zeitfenster.
## Gibt die Tastenfelder zurueck, damit man sie auch anklicken kann - wer
## lieber mit der Maus spielt, soll nicht wehrlos sein.
static func _draw_defense_overlay(
	ci: CanvasItem, fx_layer: Variant, aggro: Dictionary,
	w: float, h: float, t: float
) -> Array:
	var hits: Array = []
	var phase := String(aggro["phase"])
	var danger := 0.2 + float(aggro.get("approach", 0.0)) * 0.25 \
		+ (0.25 if float(aggro["missFlash"]) > 0.0 else 0.0)
	if phase == "fail":
		danger = 0.55
	elif phase == "win":
		danger = 0.1

	# Roter Rahmen, der mit jedem Fehlgriff aufblitzt.
	# Der Verlauf hat drei Stufen (oben rot, Mitte durchsichtig, unten rot) -
	# darum zwei Rechtecke statt einem.
	var edge := Palette.with_alpha(Palette.RED, danger)
	var clear := Palette.with_alpha(Palette.RED, 0.0)
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, h * 0.45), edge, clear)
	Draw2D.vgradient_rect(ci, Rect2(0, h * 0.45, w, h * 0.55), clear, edge)

	# Feste Hoehe auf Brusthoehe: die Tasten sollen immer an derselben Stelle
	# stehen, egal wie nah der Gast schon ist.
	var cx := w * 0.5
	var cy := h * 0.5

	if phase == "charge":
		Draw2D.text(
			ci, Fonts.display_spaced(4.0), Vector2(cx, cy), "ER KOMMT AUF DICH ZU", 20,
			Palette.RED, Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
		Draw2D.text(
			ci, Fonts.mono(), Vector2(cx, cy + 26.0),
			"TASTEN DRÜCKEN, SOBALD SIE ERSCHEINEN", 11,
			Palette.with_alpha(Palette.WHITE, 0.8), Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
		return hits

	if phase == "win" or phase == "fail":
		var won := phase == "win"
		Draw2D.text(
			ci, Fonts.display_spaced(5.0), Vector2(cx, cy),
			"ABGEWEHRT" if won else "ERWISCHT", 26,
			Palette.GREEN if won else Palette.RED,
			Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
		Draw2D.text(
			ci, Fonts.mono_spaced(2.0), Vector2(cx, cy + 28.0),
			"ER FLIEGT RAUS" if won else "DAS TEAM ZIEHT IHN WEG", 11,
			Palette.with_alpha(Palette.WHITE, 0.75),
			Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
		return hits

	# --- laufende Tastenfolge ---
	var size := minf(64.0, w * 0.075)
	var gap := size * 0.42
	var keys: Array = aggro["keys"]
	var total := keys.size()
	var start_x := cx - ((total - 1) * (size + gap)) * 0.5
	var index := int(aggro["index"])

	for i in total:
		var entry: Dictionary = keys[i]
		var x := start_x + i * (size + gap)
		var done := i < index
		var current := i == index
		var scale := 0.78
		if current:
			scale = 1.0 + sin(t * 9.0) * 0.04 + (0.06 if float(aggro["hitFlash"]) > 0.0 else 0.0)
		var box := size * scale
		var color := Palette.GREY
		if done:
			color = Palette.GREEN
		elif current:
			color = Palette.WHITE

		if current:
			Effects.glow(
				fx_layer, x, cy, box * 2.4,
				Palette.RED if float(aggro["missFlash"]) > 0.0 else Palette.CYAN, 0.35
			)
			hits.append({
				"key": entry["key"], "x": x, "y": cy, "rx": box * 0.8, "ry": box * 0.8,
			})

		var box_rect := Rect2(x - box * 0.5, cy - box * 0.5, box, box)
		Draw2D.fill_round_rect(
			ci, box_rect, box * 0.18, Color("0b0e14", 0.6 if done else 0.9)
		)
		Draw2D.stroke_round_rect(
			ci, box_rect, box * 0.18, Palette.with_alpha(color, 0.5 if done else 1.0),
			3.0 if current else 2.0
		)

		Draw2D.text(
			ci, Fonts.display(), Vector2(x, cy + box * 0.03), entry["label"],
			int(round(box * 0.5)), Palette.with_alpha(color, 0.5 if done else 1.0),
			Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)

		# Zeitfenster als schrumpfender Ring um die aktuelle Taste
		if current:
			var left := maxf(0.0, float(aggro["keyLeft"]) / float(aggro["keyTime"]))
			Draw2D.stroke_path(ci, Draw2D.ellipse_points(
				Vector2(x, cy), Vector2(box * 0.78, box * 0.78),
				-PI * 0.5, -PI * 0.5 + TAU * left
			), Palette.CYAN if left > 0.4 else Palette.RED, 4.0)

	# Fehlversuche
	Draw2D.text(
		ci, Fonts.mono_spaced(3.0), Vector2(cx, cy - size * 1.15),
		"ABWEHR %d/%d" % [index, total], 11,
		Palette.with_alpha(Palette.WHITE, 0.8), Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)
	var lives := maxi(0, int(aggro["maxStrikes"]) - int(aggro["strikes"]) + 1)
	var dots := "●".repeat(lives) + "○".repeat(maxi(0, int(aggro["maxStrikes"]) + 1 - lives))
	Draw2D.text(
		ci, Fonts.mono_spaced(3.0), Vector2(cx, cy + size * 1.2), dots, 11,
		Palette.with_alpha(Palette.AMBER, 0.9) if lives > 1 else Palette.RED,
		Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)
	return hits

## Hoehe der Figur: nie breiter als die (im Splitscreen halbe) Ansicht.
static func _guest_height(w: float, h: float) -> float:
	return minf(h * 0.56, w * 0.62)

const ZONE_LABEL := {
	"jacket": {"label": "JACKE", "key": "J"},
	"pockets": {"label": "HOSENTASCHEN", "key": "K"},
	"bag": {"label": "TASCHE", "key": "L"},
}

## Abtast-Zonen: ruhiger Ring auf der tatsaechlichen Koerperstelle, umlaufender
## Suchbogen fuer die offene Zone, Haekchen fuer erledigt, Ausrufezeichen fuer
## Fund. Gibt die Ringe zurueck, damit man sie auch mit der Maus anklicken kann.
static func _draw_patdown_overlay(
	ci: CanvasItem, fx_layer: Variant, station: Dictionary, t: float, anchors: Dictionary
) -> Array:
	var pat: Dictionary = station["patdown"]
	var hits: Array = []
	var zones: Dictionary = pat["zones"]

	for key: String in zones:
		var zone: Dictionary = zones[key]
		var anchor: Variant = anchors.get(zone["id"], null)
		if anchor == null or not ZONE_LABEL.has(zone["id"]):
			continue
		var cfg: Dictionary = ZONE_LABEL[zone["id"]]

		var cx := float(anchor["x"])
		var cy := float(anchor["y"])
		var radius_x := float(anchor["rx"])
		var radius_y := float(anchor["ry"])
		var open: bool = zone["state"] == "open"
		var done: bool = zone["state"] == "done"
		if not done:
			hits.append({
				"zone": zone["id"], "x": cx, "y": cy, "rx": radius_x, "ry": radius_y,
			})
		# Nur die Angabe des SPIELERS faerbt den Ring - nicht die Wahrheit.
		var flagged_count: int = (zone["flagged"] as Array).size()
		var flagged := flagged_count > 0
		var color := Palette.CYAN
		if done:
			color = Palette.AMBER if flagged else Palette.GREEN
		var pulse := 0.5 + sin(t * (5.0 if open else 2.2) + radius_y) * 0.5

		if open:
			Effects.glow(fx_layer, cx, cy, radius_x * 2.0, color, 0.1 + pulse * 0.12)

		Draw2D.ellipse_outline(
			ci, Vector2(cx, cy), Vector2(radius_x, radius_y),
			Palette.with_alpha(color, 0.85 if done else 0.4 + pulse * 0.3),
			2.5 if done else 2.0
		)
		Draw2D.ellipse_outline(
			ci, Vector2(cx, cy), Vector2(radius_x * 0.72, radius_y * 0.72),
			Palette.with_alpha(color, 0.16), 1.0
		)

		var tick := Palette.with_alpha(color, 0.55)
		for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			var sx := cx + cos(a) * radius_x
			var sy := cy + sin(a) * radius_y
			ci.draw_line(
				Vector2(sx + cos(a) * 3.0, sy + sin(a) * 3.0),
				Vector2(sx + cos(a) * 9.0, sy + sin(a) * 9.0),
				tick, 1.5, true
			)

		if open:
			var start := fmod(t * 2.4, TAU)
			Draw2D.stroke_path(ci, Draw2D.ellipse_points(
				Vector2(cx, cy), Vector2(radius_x, radius_y), start, start + PI * 0.55
			), Palette.with_alpha(color, 0.95), 3.0)

		if done:
			Draw2D.text(
				ci, Fonts.mono(), Vector2(cx, cy), "!" if flagged else "✓",
				int(round(radius_y * 1.3)), color,
				Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
			)

		# Die Beschriftung sitzt IMMER rechts vom Ring. Frueher wechselte sie
		# die Seite, sobald sich der Gast (und damit der Ring) bewegte - das
		# flackerte.
		var note: String
		if done:
			note = "%d BEANSTANDET" % flagged_count if flagged else "ABGESCHLOSSEN"
		elif open:
			note = "AUSGELEERT"
		else:
			note = "[%s] ODER KLICKEN" % cfg["key"]
		Draw2D.text(
			ci, Fonts.mono(), Vector2(cx + radius_x + 12.0, cy),
			"%s · %s" % [cfg["label"], note], 11,
			Palette.with_alpha(color, 0.95), Draw2D.Align.LEFT, Draw2D.Baseline.MIDDLE
		)

	return hits

# ----------------------------------------------------------------
# Alkoholtestgeraet
# ----------------------------------------------------------------

## Startzeit je Messung, damit der Wert von 0 hochzaehlen kann.
static var _alco_anim: Dictionary = {}

static func _measured_value(key: String, target: float, t: float) -> Dictionary:
	if not _alco_anim.has(key):
		_alco_anim[key] = t
	if _alco_anim.size() > 40:
		_alco_anim.erase(_alco_anim.keys()[0])
	var elapsed := t - float(_alco_anim[key])
	var dur := 1.8
	if elapsed >= dur:
		return {"value": target, "running": false}
	# Weiches Hochzaehlen mit leichtem Zittern, wie bei einem echten Geraet.
	var p := elapsed / dur
	var eased := 1.0 - pow(1.0 - p, 2.2)
	var jitter := (1.0 - p) * 0.06 * sin(t * 34.0)
	return {"value": maxf(0.0, target * eased + jitter), "running": true}

## Alkoholtestgeraet auf dem Tisch: zeigt nur den Wert und den aufgedruckten
## Grenzwert. Die Bewertung macht der Spieler.
static func _draw_breathalyzer(
	ci: CanvasItem, w: float, h: float, t: float, result: Dictionary, key: String
) -> void:
	var dw := minf(220.0, w * 0.25)
	var dh := dw * 0.5
	var x := minf(w * 0.62, w - dw - 24.0)
	var y := h * 0.9 - dh - 4.0

	# Gehaeuse
	Draw2D.fill_round_rect(ci, Rect2(x, y, dw, dh), 8.0, Color("232a35"))
	Draw2D.stroke_round_rect(ci, Rect2(x, y, dw, dh), 8.0, Color("39414f"), 2.0)

	# Mundstueck
	Draw2D.fill_round_rect(
		ci, Rect2(x + dw * 0.42, y - dh * 0.22, dw * 0.16, dh * 0.24), 3.0, Color("c9d2df")
	)

	# Display - der Wert laeuft von 0 auf das Messergebnis hoch
	var shown := _measured_value(key, float(result["promille"]), t)
	var live := bool(shown["running"])
	var over: bool = not live and float(result["promille"]) >= float(result["limit"])
	var dx := x + dw * 0.08
	var dy := y + dh * 0.2
	var dwi := dw * 0.56
	var dhi := dh * 0.6
	Draw2D.fill_round_rect(ci, Rect2(dx, dy, dwi, dhi), 4.0, Color("0b1410"))
	Draw2D.stroke_round_rect(ci, Rect2(dx, dy, dwi, dhi), 4.0, Color("101c16"), 1.0)

	# ctx.shadowBlur hat kein direktes Gegenstueck; der Leuchtrand entsteht
	# hier aus mehreren halbdurchsichtigen Kopien hinter der Ziffer.
	var digit_color := Color("ffd479") if live else (Color("ff6b6b") if over else Color("7dffb0"))
	var glow_color := Palette.AMBER if live else (Palette.RED if over else Palette.GREEN)
	var digit_size := int(round(dhi * 0.62))
	var digit_pos := Vector2(dx + dwi * 0.46, dy + dhi * 0.52)
	var text_value := "%.1f" % float(shown["value"])
	for offset: Vector2 in [
		Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)
	]:
		Draw2D.text(
			ci, Fonts.display(), digit_pos + offset, text_value, digit_size,
			Palette.with_alpha(glow_color, 0.25),
			Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
	Draw2D.text(
		ci, Fonts.display(), digit_pos, text_value, digit_size, digit_color,
		Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)
	Draw2D.text(
		ci, Fonts.mono(), Vector2(dx + dwi * 0.86, dy + dhi * 0.62), "‰",
		int(round(dhi * 0.26)), Palette.with_alpha(Color("7dffb0"), 0.7),
		Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)

	# Aufgedruckter Grenzwert + Statuslampe
	Draw2D.text(
		ci, Fonts.mono(), Vector2(x + dw * 0.68, y + dh * 0.3), "GRENZWERT", 9, Palette.GREY
	)
	Draw2D.text(
		ci, Fonts.mono(), Vector2(x + dw * 0.68, y + dh * 0.5),
		"%.1f ‰" % float(result["limit"]), 13, Palette.AMBER
	)

	var blink := sin(t * 6.0) > 0.0
	var lamp: Color
	if live:
		lamp = Palette.with_alpha(Palette.AMBER, 1.0 if blink else 0.3)
	elif over:
		lamp = Palette.with_alpha(Palette.RED, 1.0 if blink else 0.35)
	else:
		lamp = Palette.with_alpha(Palette.GREEN, 0.9)
	ci.draw_circle(Vector2(x + dw * 0.73, y + dh * 0.74), 5.0, lamp)
	Draw2D.text(
		ci, Fonts.mono(), Vector2(x + dw * 0.8, y + dh * 0.77),
		"MESSUNG …" if live else "ALCO-CHECK 4", 8, Palette.GREY
	)
