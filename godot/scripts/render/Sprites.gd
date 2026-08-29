## Prozedurale 2D-Charaktere (leicht erhoehte Top-Down-Perspektive).
## Alles wird zur Laufzeit gezeichnet - keine externen Assets.
##
## Portierung von src/render/sprites.js. roundRect() ist nach Draw2D
## gewandert, weil es dort von allen Zeichenmodulen gebraucht wird.
class_name Sprites
extends RefCounted

## Zeichnet eine animierte Figur.
##
## opts: { x, y, look, walkPhase, moving, sway, scale, accent, outline,
##         alpha, hatColor }
##
## Die Vorlage skaliert und dreht ueber den Kontext; hier baut die Funktion
## eine Transform2D und wendet sie auf die Punkte an. Das ist noetig, weil
## _draw() keinen Zustandsstapel hat.
static func draw_character(ci: CanvasItem, opts: Dictionary) -> void:
	var look: Dictionary = opts.get("look", {})
	var walk_phase := float(opts.get("walkPhase", 0.0))
	var moving := bool(opts.get("moving", false))
	var sway := float(opts.get("sway", 0.0))
	var scale := float(opts.get("scale", 1.0))
	var accent: Variant = opts.get("accent", null)
	var outline: Variant = opts.get("outline", null)
	var alpha := float(opts.get("alpha", 1.0))
	var hat_color: Variant = opts.get("hatColor", null)

	var s := scale * float(look.get("height", 1.0))
	var bulk := float(look.get("bulk", 1.0))
	var skin: Color = Palette.SKIN[int(look.get("skin", 0)) % Palette.SKIN.size()]
	var outfit: Color = Palette.OUTFIT[int(look.get("outfit", 0)) % Palette.OUTFIT.size()]
	var hair: Color = Palette.HAIR[int(look.get("hair", 0)) % Palette.HAIR.size()]

	# Betrunkene / nervoese Figuren schwanken sichtbar.
	var rotation := sin(walk_phase * 0.6) * sway if sway != 0.0 else 0.0
	var xf := Transform2D(rotation, Vector2(float(opts["x"]), float(opts["y"]))).scaled_local(
		Vector2(s, s)
	)

	var tint := func(c: Color) -> Color:
		return Color(c.r, c.g, c.b, c.a * alpha)

	# Schatten
	_ellipse_xf(ci, xf, Vector2(0, 2), Vector2(11.0 * bulk, 5.0), tint.call(Color(0, 0, 0, 0.45)))

	var step := sin(walk_phase) if moving else sin(walk_phase * 0.35) * 0.2
	var bob := absf(cos(walk_phase)) * 1.6 if moving else sin(walk_phase * 0.5) * 0.5

	# Beine
	var leg: Color = tint.call(Color("0e1015"))
	_line_xf(ci, xf, Vector2(-3, -8), Vector2(-3 + step * 3.4, 0), leg, 4.4 * bulk * s)
	_line_xf(ci, xf, Vector2(3, -8), Vector2(3 - step * 3.4, 0), leg, 4.4 * bulk * s)

	# Torso
	var torso_y := -22.0 - bob
	_round_rect_xf(
		ci, xf, Rect2(-7.5 * bulk, torso_y, 15.0 * bulk, 16.0), 4.0, tint.call(outfit)
	)

	# Akzentstreifen (Rollen-Farbe / VIP)
	if accent != null:
		_round_rect_xf(
			ci, xf, Rect2(-7.5 * bulk, torso_y + 10.0, 15.0 * bulk, 3.4), 1.6,
			tint.call(accent)
		)

	# Arme
	var arm: Color = tint.call(outfit)
	_line_xf(
		ci, xf, Vector2(-7.0 * bulk, torso_y + 3.0),
		Vector2(-9.5 * bulk, torso_y + 12.0 + step * 1.6), arm, 3.6 * bulk * s
	)
	_line_xf(
		ci, xf, Vector2(7.0 * bulk, torso_y + 3.0),
		Vector2(9.5 * bulk, torso_y + 12.0 - step * 1.6), arm, 3.6 * bulk * s
	)

	# Kopf
	var head_y := torso_y - 7.0
	_ellipse_xf(ci, xf, Vector2(0, head_y), Vector2(6.1, 6.1), tint.call(skin))

	# Haare / Muetze
	var cap_color: Color = hat_color if hat_color != null else hair
	_arc_xf(
		ci, xf, Vector2(0, head_y - 1.4), Vector2(6.1, 6.1),
		PI * 0.98, PI * 2.02, tint.call(cap_color)
	)
	if hat_color == null and int(look.get("hair", 0)) % 3 == 0:
		_round_rect_xf(ci, xf, Rect2(-6.1, head_y - 2.4, 12.2, 2.2), 0.0, tint.call(hair))

	if outline != null:
		var ring := Draw2D.ellipse_points(Vector2(0, -16), Vector2(13.0 * bulk, 24.0))
		ci.draw_polyline(_apply(xf, ring), tint.call(outline), 1.4 * s, true)

# ---------- Transformationshelfer ----------
#
# Godots _draw() kennt keinen Zustandsstapel; die Vorlage nutzt aber
# translate/rotate/scale. Diese Helfer rechnen die Punkte einmal um.

static func _apply(xf: Transform2D, points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(xf * p)
	return out

static func _ellipse_xf(
	ci: CanvasItem, xf: Transform2D, center: Vector2, radii: Vector2, color: Color
) -> void:
	ci.draw_colored_polygon(_apply(xf, Draw2D.ellipse_points(center, radii)), color)

static func _arc_xf(
	ci: CanvasItem, xf: Transform2D, center: Vector2, radii: Vector2,
	start_angle: float, end_angle: float, color: Color
) -> void:
	ci.draw_colored_polygon(
		_apply(xf, Draw2D.ellipse_points(center, radii, start_angle, end_angle)), color
	)

static func _round_rect_xf(
	ci: CanvasItem, xf: Transform2D, rect: Rect2, radius: float, color: Color
) -> void:
	ci.draw_colored_polygon(_apply(xf, Draw2D.round_rect_points(rect, radius)), color)

static func _line_xf(
	ci: CanvasItem, xf: Transform2D, from: Vector2, to: Vector2, color: Color, width: float
) -> void:
	Draw2D.line_round(ci, xf * from, xf * to, color, width)

# ---------- Tanzende und Sprechblasen ----------

## Kleine Menge tanzender Silhouetten auf dem Floor.
static func draw_dancer(
	ci: CanvasItem, x: float, y: float, phase: float, beat: float, color: Color
) -> void:
	var bounce := sin(phase + beat * TAU) * 2.4
	var origin := Vector2(x, y - bounce)
	Draw2D.ellipse(ci, origin, Vector2(3.4, 6.4), color)
	ci.draw_circle(origin + Vector2(0, -8), 2.6, color)
	var arm_angle := sin(phase * 1.7 + beat * 6.28) * 0.7
	Draw2D.line_round(
		ci, origin + Vector2(-2.6, -3), origin + Vector2(-5.5, -8.0 - arm_angle * 3.0),
		color, 1.5
	)
	Draw2D.line_round(
		ci, origin + Vector2(2.6, -3), origin + Vector2(5.5, -8.0 + arm_angle * 3.0),
		color, 1.5
	)

## Sprechblase ueber einer Figur.
static func draw_speech(
	ci: CanvasItem, font: Font, x: float, y: float, content: String,
	accent: Color = Palette.WHITE, max_width: float = 210.0
) -> void:
	if content.is_empty():
		return
	var size := 12
	var lines := Draw2D.wrap_text(font, content, size, max_width - 18.0)
	var widest := 0.0
	for line: String in lines:
		widest = maxf(widest, Draw2D.text_width(font, line, size))
	var w := minf(max_width, widest + 18.0)
	var h := lines.size() * 15.0 + 12.0
	var bx := x - w * 0.5
	var by := y - h

	var back := Color(8.0 / 255.0, 10.0 / 255.0, 14.0 / 255.0, 0.88)
	Draw2D.fill_round_rect(ci, Rect2(bx, by, w, h), 3.0, back)
	Draw2D.stroke_round_rect(
		ci, Rect2(bx, by, w, h), 3.0, Palette.with_alpha(accent, 0.55), 1.0
	)

	# Spitze der Sprechblase
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 5.0, by + h), Vector2(x, by + h + 6.0), Vector2(x + 5.0, by + h),
	]), back)

	for i in lines.size():
		Draw2D.text(
			ci, font, Vector2(x, by + 12.0 + i * 15.0), lines[i], size, Palette.WHITE,
			Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
		)
