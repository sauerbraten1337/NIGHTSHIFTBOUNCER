## Licht, Nebel, Partikel, Scanlines - die Atmosphaere der Szene.
##
## Portierung von src/render/effects.js. Zwei Dinge lassen sich nicht
## woertlich uebertragen:
##
##  - Canvas-Verlaufsobjekte (createRadialGradient/createLinearGradient) gibt
##    es in _draw() nicht. Stattdessen liegen die Verlaeufe einmal als
##    GradientTexture2D bereit und werden mit draw_texture_rect() plus
##    Modulationsfarbe gezeichnet. Der Kegel (beam) kommt ohne Textur aus:
##    ein Dreieck mit Farbe je Eckpunkt ergibt genau denselben linearen
##    Verlauf.
##  - globalCompositeOperation 'screen'/'lighter' ist eine Eigenschaft des
##    Zeichenaufrufs; in Godot haengt der Mischmodus am CanvasItem. Nebel,
##    Staub, Funken, Glow und Kegel gehoeren darum auf einen Knoten mit
##    additivem CanvasItemMaterial (siehe additive_material()), Scanlines und
##    Vignette auf einen normalen.
class_name Effects
extends RefCounted

var fog: Array[Dictionary] = []
var dust: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var t := 0.0

## Verlaufstexturen werden einmal gebaut und von allen Ansichten geteilt.
static var _radial_soft: GradientTexture2D = null
static var _radial_glow: GradientTexture2D = null
static var _vignette_tex: GradientTexture2D = null

func _init(rng: Variant = null) -> void:
	var roll := func() -> float:
		return (rng as Rng).next() if rng is Rng else randf()

	for i in 16:
		fog.append({
			"x": roll.call() * Layout.WORLD.x,
			"y": 340.0 + roll.call() * 360.0,
			"r": 90.0 + roll.call() * 160.0,
			"vx": (roll.call() - 0.5) * 8.0,
			"a": 0.03 + roll.call() * 0.05,
			"p": roll.call() * 6.28,
		})
	for i in 60:
		dust.append({
			"x": roll.call() * Layout.WORLD.x,
			"y": roll.call() * Layout.WORLD.y,
			"vy": -4.0 - roll.call() * 10.0,
			"vx": (roll.call() - 0.5) * 6.0,
			"r": 0.6 + roll.call() * 1.4,
			"a": 0.15 + roll.call() * 0.35,
		})

func update(dt: float) -> void:
	t += dt
	for f: Dictionary in fog:
		f["x"] = float(f["x"]) + float(f["vx"]) * dt
		f["p"] = float(f["p"]) + dt * 0.4
		var r := float(f["r"])
		if float(f["x"]) < -r:
			f["x"] = Layout.WORLD.x + r
		if float(f["x"]) > Layout.WORLD.x + r:
			f["x"] = -r
	for d: Dictionary in dust:
		d["x"] = float(d["x"]) + float(d["vx"]) * dt
		d["y"] = float(d["y"]) + float(d["vy"]) * dt
		if float(d["y"]) < -10.0:
			d["y"] = Layout.WORLD.y + 10.0
			d["x"] = randf() * Layout.WORLD.x
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["life"] = float(s["life"]) - dt
		s["x"] = float(s["x"]) + float(s["vx"]) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		s["vy"] = float(s["vy"]) + 220.0 * dt
		if float(s["life"]) <= 0.0:
			sparks.remove_at(i)

func burst(x: float, y: float, color: Color = Palette.AMBER, count: int = 14) -> void:
	for i in count:
		var a := randf() * TAU
		var sp := 60.0 + randf() * 160.0
		sparks.append({
			"x": x, "y": y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 60.0,
			"life": 0.4 + randf() * 0.5, "color": color,
		})

# ---------- Verlaufstexturen ----------

## Weicher Kreis: innen deckend, aussen durchsichtig - fuer Nebelschwaden.
static func radial_soft() -> GradientTexture2D:
	if _radial_soft == null:
		_radial_soft = _make_radial([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return _radial_soft

## Glow mit dem Knick bei 0.55 aus der Vorlage.
static func radial_glow() -> GradientTexture2D:
	if _radial_glow == null:
		_radial_glow = _make_radial(
			[0.0, 0.55, 1.0],
			[Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)]
		)
	return _radial_glow

## Vignette: Mitte frei, Rand schwarz.
static func vignette_texture() -> GradientTexture2D:
	if _vignette_tex == null:
		_vignette_tex = _make_radial(
			[0.0, 0.295, 1.0],
			[Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)]
		)
	return _vignette_tex

static func _make_radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

## Material fuer die additiven Ebenen (Nebel, Staub, Funken, Licht).
## Ersetzt globalCompositeOperation 'screen' / 'lighter'.
static func additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

# ---------- Zeichnen ----------
#
# Alle Funktionen hier gehoeren auf ein CanvasItem mit additive_material().

func draw_fog(ci: CanvasItem, intensity: float = 1.0) -> void:
	var tex := radial_soft()
	for f: Dictionary in fog:
		var r := float(f["r"]) * (1.0 + sin(float(f["p"])) * 0.08)
		var color := Color("9fb4c8")
		color.a = float(f["a"]) * intensity
		ci.draw_texture_rect(
			tex, Rect2(float(f["x"]) - r, float(f["y"]) - r, r * 2.0, r * 2.0), false, color
		)

func draw_dust(ci: CanvasItem) -> void:
	var base := Color("cfe3ff")
	for d: Dictionary in dust:
		var color := base
		color.a = float(d["a"])
		var r := float(d["r"])
		ci.draw_rect(Rect2(float(d["x"]), float(d["y"]), r, r), color)

func draw_sparks(ci: CanvasItem) -> void:
	for s: Dictionary in sparks:
		var color: Color = s["color"]
		color.a = maxf(0.0, float(s["life"]))
		ci.draw_rect(Rect2(float(s["x"]), float(s["y"]), 2.0, 2.0), color)

## Weicher Lichtkegel / Glow.
static func glow(
	ci: CanvasItem, x: float, y: float, radius: float, color: Color, alpha: float = 0.5
) -> void:
	var tint := color
	tint.a = alpha
	ci.draw_texture_rect(
		radial_glow(), Rect2(x - radius, y - radius, radius * 2.0, radius * 2.0), false, tint
	)

## Beweglicher Scheinwerfer-Kegel (fuer Tanzflaeche).
##
## Das Dreieck traegt die Farbe an den Eckpunkten: oben deckend, unten
## durchsichtig - dasselbe Ergebnis wie der lineare Verlauf der Vorlage,
## ohne Textur.
static func beam(
	ci: CanvasItem, x: float, y: float, angle: float, length: float,
	spread: float, color: Color, alpha: float = 0.22
) -> void:
	var top := color
	top.a = alpha
	var fade := Color(color.r, color.g, color.b, 0.0)
	var basis := Transform2D(angle, Vector2(x, y))
	var points := PackedVector2Array([
		basis * Vector2(0.0, 0.0),
		basis * Vector2(-spread, length),
		basis * Vector2(spread, length),
	])
	ci.draw_polygon(points, PackedColorArray([top, fade, fade]))

## Scanlines und Vignette gehoeren auf einen Knoten OHNE additives Material.
static func scanlines(ci: CanvasItem, width: float, height: float, alpha: float = 0.05) -> void:
	var color := Color(0, 0, 0, alpha)
	var y := 0.0
	while y < height:
		ci.draw_rect(Rect2(0.0, y, width, 1.0), color)
		y += 3.0

static func vignette(ci: CanvasItem, width: float, height: float, strength: float = 0.75) -> void:
	# Die Vorlage legt den Verlauf ueber einen Kreis mit 0.95 * Hoehe Radius,
	# gezeichnet wird aber die ganze Flaeche - darum ein Quadrat in dieser
	# Groesse, zentriert auf der Bildmitte.
	var radius := height * 0.95
	var center := Vector2(width * 0.5, height * 0.5)
	ci.draw_texture_rect(
		vignette_texture(),
		Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
		false, Color(1, 1, 1, strength)
	)
	# Ausserhalb des Kreises bleibt der Rand sonst hell: die vier Streifen
	# rundherum voll abdunkeln.
	var dark := Color(0, 0, 0, strength)
	var left := center.x - radius
	var top := center.y - radius
	var right := center.x + radius
	var bottom := center.y + radius
	if left > 0.0:
		ci.draw_rect(Rect2(0, 0, left, height), dark)
	if right < width:
		ci.draw_rect(Rect2(right, 0, width - right, height), dark)
	if top > 0.0:
		ci.draw_rect(Rect2(0, 0, width, top), dark)
	if bottom < height:
		ci.draw_rect(Rect2(0, bottom, width, height - bottom), dark)
