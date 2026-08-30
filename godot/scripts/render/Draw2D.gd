## Canvas-2D-Kompatibilitaetsschicht fuer _draw().
##
## Die Web-Fassung zeichnet alles mit dem Canvas-2D-Kontext: Ellipsen,
## Bezierkurven, abgerundete Rechtecke, Linien mit runden Enden. Godots
## CanvasItem kennt draw_rect, draw_circle, draw_line, draw_polygon - aber
## keine Ellipse, keine Kurve, keine Linienenden. Dieses Modul schliesst die
## Luecke, damit der Zeichencode der Vorlage nahezu Zeile fuer Zeile
## uebertragbar bleibt.
##
## Alle Winkel in Radiant, alle Koordinaten in Weltkoordinaten (1280x720).
##
## Das Ziel `ci` ist bewusst als Variant getypt und nicht als CanvasItem:
## uebergeben wird entweder ein echter CanvasItem oder eine DrawList, die
## dieselben draw_*-Aufrufe aufzeichnet und spaeter additiv wiedergibt
## (siehe render/DrawList.gd). Beide sind hier gleichwertig.
class_name Draw2D
extends RefCounted

## Aufloesung der Kurven- und Ellipsennaeherung. 48 Segmente sind bei den
## hier vorkommenden Groessen (Koepfe, Augen, Taschen) nicht mehr von einer
## echten Ellipse zu unterscheiden.
const ELLIPSE_SEGMENTS := 48
const CURVE_SEGMENTS := 12

# ---------- Ellipsen ----------

static func ellipse_points(
	center: Vector2, radii: Vector2,
	start_angle: float = 0.0, end_angle: float = TAU,
	segments: int = ELLIPSE_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var span := end_angle - start_angle
	var count := maxi(3, int(ceil(segments * absf(span) / TAU)))
	for i in count + 1:
		var a := start_angle + span * (float(i) / count)
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points

## Gefuellte Ellipse. Entspricht ctx.ellipse(...) + ctx.fill().
static func ellipse(ci: Variant, center: Vector2, radii: Vector2, color: Color) -> void:
	ci.draw_colored_polygon(ellipse_points(center, radii), color)

## Gefuellter Ellipsenausschnitt. Canvas schliesst einen Teilbogen beim Fuellen
## mit einer Sehne (nicht als Tortenstueck) - genau das macht diese Funktion,
## und darauf beruhen die Frisuren in Figure.gd.
static func ellipse_arc(
	ci: Variant, center: Vector2, radii: Vector2,
	start_angle: float, end_angle: float, color: Color
) -> void:
	var points := ellipse_points(center, radii, start_angle, end_angle)
	if points.size() >= 3:
		ci.draw_colored_polygon(points, color)

## Umrissene Ellipse. Entspricht ctx.ellipse(...) + ctx.stroke().
static func ellipse_outline(
	ci: Variant, center: Vector2, radii: Vector2, color: Color, width: float = 1.0
) -> void:
	var points := ellipse_points(center, radii)
	ci.draw_polyline(points, color, width, true)

# ---------- Kurven ----------

## Punkte einer quadratischen Bezierkurve (ctx.quadraticCurveTo).
static func quad_curve(
	from: Vector2, control: Vector2, to: Vector2, segments: int = CURVE_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var inv := 1.0 - t
		points.append(inv * inv * from + 2.0 * inv * t * control + t * t * to)
	return points

## Haengt eine Kurve an einen bestehenden Pfad an, ohne den Startpunkt
## doppelt einzutragen.
static func append_quad(
	path: PackedVector2Array, control: Vector2, to: Vector2,
	segments: int = CURVE_SEGMENTS
) -> PackedVector2Array:
	var from := path[path.size() - 1] if path.size() > 0 else control
	var curve := quad_curve(from, control, to, segments)
	for i in range(1, curve.size()):
		path.append(curve[i])
	return path

# ---------- Rechtecke mit runden Ecken ----------

static func round_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(absf(rect.size.x) * 0.5, absf(rect.size.y) * 0.5))
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var path := PackedVector2Array([Vector2(x + r, y)])
	path.append(Vector2(x + w - r, y))
	append_quad(path, Vector2(x + w, y), Vector2(x + w, y + r), 6)
	path.append(Vector2(x + w, y + h - r))
	append_quad(path, Vector2(x + w, y + h), Vector2(x + w - r, y + h), 6)
	path.append(Vector2(x + r, y + h))
	append_quad(path, Vector2(x, y + h), Vector2(x, y + h - r), 6)
	path.append(Vector2(x, y + r))
	append_quad(path, Vector2(x, y), Vector2(x + r, y), 6)
	return path

static func fill_round_rect(ci: Variant, rect: Rect2, radius: float, color: Color) -> void:
	if radius <= 0.5:
		ci.draw_rect(rect, color)
		return
	ci.draw_colored_polygon(round_rect_points(rect, radius), color)

static func stroke_round_rect(
	ci: Variant, rect: Rect2, radius: float, color: Color, width: float = 1.0
) -> void:
	var points := round_rect_points(rect, radius)
	points.append(points[0])
	ci.draw_polyline(points, color, width, true)

# ---------- Linien ----------

## Linie mit runden Enden (ctx.lineCap = 'round'). Godots draw_line kennt
## keine Enden, darum sitzt an jedem Ende ein Kreis.
static func line_round(
	ci: Variant, from: Vector2, to: Vector2, color: Color, width: float
) -> void:
	ci.draw_line(from, to, color, width, true)
	var r := width * 0.5
	if r > 0.5:
		ci.draw_circle(from, r, color)
		ci.draw_circle(to, r, color)

## Linienzug mit runden Enden und Gelenken.
static func polyline_round(
	ci: Variant, points: PackedVector2Array, color: Color, width: float
) -> void:
	if points.size() < 2:
		return
	ci.draw_polyline(points, color, width, true)
	var r := width * 0.5
	if r > 0.5:
		for p: Vector2 in points:
			ci.draw_circle(p, r, color)

# ---------- Pfade ----------

static func fill_path(ci: Variant, points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		ci.draw_colored_polygon(points, color)

static func stroke_path(
	ci: Variant, points: PackedVector2Array, color: Color,
	width: float = 1.0, closed: bool = false
) -> void:
	if points.size() < 2:
		return
	var line := points
	if closed:
		line = points.duplicate()
		line.append(points[0])
	ci.draw_polyline(line, color, width, true)

# ---------- Verlaufsflaechen ----------
#
# Ersetzt createLinearGradient() fuer die haeufigsten Faelle: ein Rechteck
# oder ein Vieleck mit Farbverlauf. draw_polygon faerbt je Eckpunkt und
# interpoliert dazwischen - bei einer geraden Kante ist das exakt derselbe
# lineare Verlauf, ganz ohne Textur.

static func vgradient_rect(ci: Variant, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
		]),
		PackedColorArray([top, top, bottom, bottom])
	)

static func hgradient_rect(ci: Variant, rect: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
		]),
		PackedColorArray([left, right, right, left])
	)

## Vieleck mit einer Farbe je Eckpunkt - fuer Trapeze wie das Pult und die
## Seitenwaende, deren Verlauf nicht achsenparallel liegt.
static func gradient_polygon(
	ci: Variant, points: PackedVector2Array, colors: PackedColorArray
) -> void:
	if points.size() >= 3:
		ci.draw_polygon(points, colors)

# ---------- Farben ----------
#
# Ersetzt shade()/mix() aus figure.js. Godots Color rechnet in 0..1, die
# Formeln sind aber identisch zur Vorlage (die in 0..255 rechnet).

## amount > 0 hellt zu Weiss auf, amount < 0 dunkelt ab.
static func shade(color: Color, amount: float) -> Color:
	if amount >= 0.0:
		return Color(
			clampf(color.r + (1.0 - color.r) * amount, 0.0, 1.0),
			clampf(color.g + (1.0 - color.g) * amount, 0.0, 1.0),
			clampf(color.b + (1.0 - color.b) * amount, 0.0, 1.0),
			color.a
		)
	var f := 1.0 + amount
	return Color(
		clampf(color.r * f, 0.0, 1.0),
		clampf(color.g * f, 0.0, 1.0),
		clampf(color.b * f, 0.0, 1.0),
		color.a
	)

static func mix(a: Color, b: Color, t: float) -> Color:
	return Color(
		a.r + (b.r - a.r) * t,
		a.g + (b.g - a.g) * t,
		a.b + (b.b - a.b) * t,
		a.a
	)

# ---------- Text ----------
#
# Die Vorlage setzt Text ueber ctx.fillText mit textAlign/textBaseline.
# draw_string() richtet an der Grundlinie aus; diese Helfer rechnen die
# Ausrichtung wie im Canvas um.

enum Align { LEFT, CENTER, RIGHT }
enum Baseline { TOP, MIDDLE, ALPHABETIC, BOTTOM }

static func text(
	ci: Variant, font: Font, pos: Vector2, content: String, size: int, color: Color,
	align: Align = Align.LEFT, baseline: Baseline = Baseline.ALPHABETIC
) -> void:
	if content.is_empty():
		return
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ascent := font.get_ascent(size)
	var descent := font.get_descent(size)

	var x := pos.x
	match align:
		Align.CENTER: x -= width * 0.5
		Align.RIGHT: x -= width

	var y := pos.y
	match baseline:
		Baseline.TOP: y += ascent
		Baseline.MIDDLE: y += (ascent - descent) * 0.5
		Baseline.BOTTOM: y -= descent

	ci.draw_string(font, Vector2(x, y), content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_width(font: Font, content: String, size: int) -> float:
	return font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Zeilenumbruch wie wrapText() in sprites.js.
static func wrap_text(font: Font, content: String, size: int, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word: String in content.split(" "):
		var test := word if line.is_empty() else "%s %s" % [line, word]
		if text_width(font, test, size) > max_width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = test
	if not line.is_empty():
		lines.append(line)
	return lines
