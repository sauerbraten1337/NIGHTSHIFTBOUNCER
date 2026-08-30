## Kleine Strich-Icons fuer die Aktions-Knoepfe.
##
## Portierung von src/ui/icons.js. Dort sind es Inline-SVGs mit
## `currentColor`, damit sie die Farbe des Knopfes erben. Godot kennt kein
## SVG im laufenden Betrieb, also sind dieselben Pfade hier als Striche
## nachgezeichnet - Koordinaten unveraendert im 24x24-Raster der Vorlage,
## Farbe kommt als Parameter herein.
##
## Die wenigen kleinen SVG-Bogensegmente (`a1 1 0 0 1 …`) sind als Halbkreise
## genaehert; bei 24 Pixel Kantenlaenge ist das nicht zu unterscheiden.
class_name Icons
extends RefCounted

const VIEW := 24.0
const STROKE := 1.6

## Zeichnet das Icon eines Aktionscodes in ein Quadrat der Kantenlaenge `size`.
static func draw_action_icon(
	ci: CanvasItem, code: String, size: float, origin: Vector2, color: Color
) -> void:
	var s := size / VIEW
	var w := STROKE * s
	var p := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x * s, y * s)
	var line := func(pts: PackedVector2Array) -> void:
		Draw2D.polyline_round(ci, pts, color, w)
	var circle := func(cx: float, cy: float, r: float) -> void:
		Draw2D.ellipse_outline(ci, p.call(cx, cy), Vector2(r * s, r * s), color, w)
	var dot := func(cx: float, cy: float, r: float) -> void:
		ci.draw_circle(p.call(cx, cy), r * s, color)
	var round_rect := func(x: float, y: float, rw: float, rh: float, r: float) -> void:
		Draw2D.stroke_round_rect(
			ci, Rect2(origin + Vector2(x * s, y * s), Vector2(rw * s, rh * s)), r * s, color, w
		)

	match code:
		# Ausweis verlangen: Karte mit Foto und Zeilen
		"id":
			round_rect.call(2.5, 5.0, 19.0, 14.0, 2.0)
			circle.call(8.0, 11.0, 2.2)
			# Schulterlinie des Portraits (zwei Bezierstuecke der Vorlage)
			var shoulder := Draw2D.quad_curve(p.call(5, 16.4), p.call(6.5, 14.0), p.call(8, 14.3))
			var shoulder2 := Draw2D.quad_curve(p.call(8, 14.3), p.call(9.5, 14.6), p.call(11, 16.4))
			line.call(shoulder)
			line.call(shoulder2)
			line.call(PackedVector2Array([p.call(14, 10), p.call(19, 10)]))
			line.call(PackedVector2Array([p.call(14, 13), p.call(19, 13)]))
			line.call(PackedVector2Array([p.call(14, 16), p.call(17, 16)]))

		# Ansprechen: Sprechblase mit Punkten
		"talk":
			line.call(PackedVector2Array([
				p.call(4, 5.5), p.call(20, 5.5), p.call(20, 15.5), p.call(9.5, 15.5),
				p.call(5, 19), p.call(5, 15.5), p.call(4, 15.5), p.call(4, 5.5),
			]))
			dot.call(9.0, 10.5, 0.9)
			dot.call(12.5, 10.5, 0.9)
			dot.call(16.0, 10.5, 0.9)

		# Abtasten: Hand an der Silhouette
		"search":
			circle.call(9.0, 4.8, 2.3)
			var body := PackedVector2Array([p.call(9, 7.6)])
			Draw2D.append_quad(body, p.call(5.2, 8.4), p.call(5.2, 11.4))
			body.append(p.call(5.2, 15.6))
			body.append(p.call(6.6, 15.6))
			body.append(p.call(7, 21.5))
			body.append(p.call(11, 21.5))
			body.append(p.call(11.4, 15.6))
			body.append(p.call(12.8, 15.6))
			body.append(p.call(12.8, 11.4))
			Draw2D.append_quad(body, p.call(12.8, 8.4), p.call(9, 7.6))
			line.call(body)
			# Hand: senkrechter Finger, Daumenbogen, Handkante
			line.call(PackedVector2Array([p.call(16, 13.5), p.call(16, 10.5)]))
			line.call(Draw2D.ellipse_points(
				p.call(17, 10.5), Vector2(1.0 * s, 1.0 * s), PI, TAU
			))
			line.call(PackedVector2Array([p.call(18, 10.5), p.call(18, 12.7)]))
			line.call(Draw2D.ellipse_points(
				p.call(19.65, 12.25), Vector2(1.0 * s, 1.0 * s), PI * 0.75, PI * 1.9
			))
			var palm := PackedVector2Array([p.call(20.4, 12.9), p.call(18.5, 15.3)])
			Draw2D.append_quad(palm, p.call(17.6, 16.4), p.call(16.1, 16.6))
			palm.append(p.call(15.1, 16.6))
			line.call(palm)

		# Alkotest: Messgeraet mit Mundstueck
		"alcohol":
			round_rect.call(3.5, 8.0, 14.0, 9.0, 2.0)
			round_rect.call(6.0, 10.6, 6.5, 3.8, 1.0)
			line.call(PackedVector2Array([p.call(17.5, 12.5), p.call(20, 12.5)]))
			line.call(PackedVector2Array([p.call(9.5, 8), p.call(9.5, 6.2)]))
			line.call(PackedVector2Array([p.call(13.5, 8), p.call(13.5, 6.2)]))
			dot.call(15.0, 12.5, 1.0)

		# Schlange beruhigen: drei Wartende
		"calm":
			circle.call(5.5, 7.0, 1.8)
			var a := PackedVector2Array([p.call(3, 19), p.call(3, 14.5)])
			Draw2D.append_quad(a, p.call(3, 11.9), p.call(5.5, 11.9))
			Draw2D.append_quad(a, p.call(8, 11.9), p.call(8, 14.5))
			a.append(p.call(8, 19))
			line.call(a)
			circle.call(12.0, 6.0, 2.0)
			var b := PackedVector2Array([p.call(9.2, 19), p.call(9.2, 14)])
			Draw2D.append_quad(b, p.call(9.2, 11.1), p.call(12, 11.1))
			Draw2D.append_quad(b, p.call(14.8, 11.1), p.call(14.8, 14))
			b.append(p.call(14.8, 19))
			line.call(b)
			circle.call(18.5, 7.0, 1.8)
			var c := PackedVector2Array([p.call(16, 19), p.call(16, 14.5)])
			Draw2D.append_quad(c, p.call(16, 11.9), p.call(18.5, 11.9))
			Draw2D.append_quad(c, p.call(21, 11.9), p.call(21, 14.5))
			c.append(p.call(21, 19))
			line.call(c)

		# Einlassen: offene Tuer mit Pfeil hinein
		"admit":
			line.call(PackedVector2Array([
				p.call(14, 3.5), p.call(19.5, 3.5), p.call(19.5, 20.5), p.call(14, 20.5),
			]))
			line.call(PackedVector2Array([p.call(4, 12), p.call(13, 12)]))
			line.call(PackedVector2Array([p.call(9.5, 8.5), p.call(13, 12), p.call(9.5, 15.5)]))

		# Durchlassen in die Schleuse: Pfeil durch zwei Pfosten
		"pass":
			line.call(PackedVector2Array([p.call(6, 4), p.call(6, 20)]))
			line.call(PackedVector2Array([p.call(18, 4), p.call(18, 20)]))
			line.call(PackedVector2Array([p.call(8.5, 12), p.call(15.5, 12)]))
			line.call(PackedVector2Array([p.call(12.5, 8.5), p.call(16, 12), p.call(12.5, 15.5)]))

		# Abweisen: Tuer mit Kreuz
		"reject":
			line.call(PackedVector2Array([
				p.call(10, 3.5), p.call(4.5, 3.5), p.call(4.5, 20.5), p.call(10, 20.5),
			]))
			line.call(PackedVector2Array([p.call(13.5, 9), p.call(20, 15.5)]))
			line.call(PackedVector2Array([p.call(20, 9), p.call(13.5, 15.5)]))

		# Unbekannte Codes bekommen einen Punkt.
		_:
			circle.call(12.0, 12.0, 4.0)

## Die Symbole von NIGHT//OS (Laptop im Buero).
##
## Portierung der ICONS-Tabelle aus src/ui/shop.js - dieselben SVG-Pfade,
## dieselbe Strichstaerke.
static func draw_os_icon(
	ci: CanvasItem, name: String, size: float, origin: Vector2, color: Color
) -> void:
	var s := size / VIEW
	var w := STROKE * s
	var p := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x * s, y * s)
	var line := func(pts: PackedVector2Array) -> void:
		Draw2D.polyline_round(ci, pts, color, w)
	var circle := func(cx: float, cy: float, r: float) -> void:
		Draw2D.ellipse_outline(ci, p.call(cx, cy), Vector2(r * s, r * s), color, w)

	match name:
		"logo":
			circle.call(12.0, 12.0, 8.0)
			line.call(PackedVector2Array([p.call(7, 12), p.call(17, 12)]))
		"wrench":
			# Der Schluessel: Bogen, Griff, Maulkopf.
			var wr := PackedVector2Array([p.call(14.5, 4.5)])
			Draw2D.append_quad(wr, p.call(10.0, 5.0), p.call(9.5, 9.5))
			wr.append(p.call(4, 15))
			wr.append(p.call(4, 20))
			wr.append(p.call(9, 20))
			wr.append(p.call(14.5, 14.5))
			Draw2D.append_quad(wr, p.call(19.5, 14.0), p.call(19.5, 9.5))
			wr.append(p.call(16.5, 12.5))
			wr.append(p.call(14.5, 10.5))
			wr.append(p.call(14.5, 4.5))
			line.call(wr)
		"spark":
			line.call(PackedVector2Array([
				p.call(12, 3), p.call(14.2, 8.8), p.call(20, 11),
				p.call(14.2, 13.2), p.call(12, 19), p.call(9.8, 13.2),
				p.call(4, 11), p.call(9.8, 8.8), p.call(12, 3),
			]))
		"note":
			circle.call(8.0, 17.0, 3.0)
			line.call(PackedVector2Array([p.call(11, 17), p.call(11, 5), p.call(19, 3), p.call(19, 14)]))
			circle.call(16.0, 14.0, 3.0)
		"folder":
			line.call(PackedVector2Array([
				p.call(3, 6), p.call(9, 6), p.call(11, 9), p.call(21, 9),
				p.call(21, 19), p.call(3, 19), p.call(3, 6),
			]))
		"shield":
			line.call(PackedVector2Array([
				p.call(12, 3), p.call(20, 6), p.call(20, 12),
			]))
			var sh := PackedVector2Array([p.call(20, 12)])
			Draw2D.append_quad(sh, p.call(19.0, 19.0), p.call(12, 21))
			Draw2D.append_quad(sh, p.call(5.0, 19.0), p.call(4, 12))
			sh.append(p.call(4, 6))
			sh.append(p.call(12, 3))
			line.call(sh)
		"door":
			line.call(PackedVector2Array([
				p.call(6, 3), p.call(15, 3), p.call(15, 21), p.call(6, 21), p.call(6, 3),
			]))
			circle.call(12.5, 12.0, 1.0)
			line.call(PackedVector2Array([p.call(15, 21), p.call(19, 21), p.call(19, 3), p.call(15, 3)]))
		"wave":
			line.call(PackedVector2Array([
				p.call(3, 12), p.call(6, 12), p.call(8, 6), p.call(11, 20),
				p.call(14, 9), p.call(16, 14), p.call(21, 14),
			]))
		"floor":
			line.call(PackedVector2Array([
				p.call(3, 8), p.call(21, 8), p.call(21, 20), p.call(3, 20), p.call(3, 8),
			]))
			line.call(PackedVector2Array([p.call(3, 14), p.call(21, 14)]))
			line.call(PackedVector2Array([p.call(9, 8), p.call(9, 20)]))
			line.call(PackedVector2Array([p.call(15, 8), p.call(15, 20)]))
		"heart":
			var ht := PackedVector2Array([p.call(12, 20)])
			Draw2D.append_quad(ht, p.call(5.0, 15.0), p.call(5, 11))
			Draw2D.append_quad(ht, p.call(6.0, 7.5), p.call(12, 8.4))
			Draw2D.append_quad(ht, p.call(18.0, 7.5), p.call(19, 11))
			Draw2D.append_quad(ht, p.call(19.0, 15.0), p.call(12, 20))
			line.call(ht)
		"coin":
			circle.call(12.0, 12.0, 8.0)
			line.call(PackedVector2Array([p.call(9, 10), p.call(15, 10)]))
			line.call(PackedVector2Array([p.call(9, 14), p.call(15, 14)]))
			line.call(PackedVector2Array([p.call(12, 7), p.call(12, 17)]))
		"star":
			line.call(PackedVector2Array([
				p.call(12, 3), p.call(14.6, 9.2), p.call(21, 9.7), p.call(16.1, 13.8),
				p.call(17.6, 20), p.call(12, 16.8), p.call(6.4, 20), p.call(7.9, 13.8),
				p.call(3, 9.7), p.call(9.4, 9.2), p.call(12, 3),
			]))
		"check":
			line.call(PackedVector2Array([p.call(4, 12), p.call(9, 17), p.call(20, 6)]))
		"search":
			circle.call(11.0, 11.0, 6.0)
			line.call(PackedVector2Array([p.call(20, 20), p.call(15.5, 15.5)]))
		"save":
			line.call(PackedVector2Array([
				p.call(4, 4), p.call(16, 4), p.call(20, 8),
				p.call(20, 20), p.call(4, 20), p.call(4, 4),
			]))
			line.call(PackedVector2Array([p.call(8, 4), p.call(8, 10), p.call(16, 10), p.call(16, 4)]))
			line.call(PackedVector2Array([p.call(8, 20), p.call(8, 14), p.call(16, 14), p.call(16, 20)]))
		"power":
			line.call(PackedVector2Array([p.call(12, 3), p.call(12, 12)]))
			line.call(Draw2D.ellipse_points(
				p.call(12, 12), Vector2(7.8 * s, 7.8 * s), PI * 0.75, PI * 2.25
			))
		"disk":
			circle.call(12.0, 12.0, 8.0)
			circle.call(12.0, 12.0, 2.0)
		_:  # "box"
			line.call(PackedVector2Array([
				p.call(4, 7), p.call(12, 3), p.call(20, 7),
				p.call(20, 17), p.call(12, 21), p.call(4, 17), p.call(4, 7),
			]))

## Ein OS-Symbol als eigener Knoten.
class OsIconRect extends Control:
	var icon_name := ""
	var color := UiTheme.TEXT

	func _init(name: String, icon_size: float = 18.0, icon_color: Color = UiTheme.TEXT) -> void:
		icon_name = name
		color = icon_color
		custom_minimum_size = Vector2(icon_size, icon_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icons.draw_os_icon(self, icon_name, minf(size.x, size.y), Vector2.ZERO, color)

static func os_icon(name: String, size: float = 18.0, color: Color = UiTheme.TEXT) -> OsIconRect:
	return OsIconRect.new(name, size, color)

## Ein Icon als eigener Knoten - so laesst es sich in einen Knopf haengen.
class IconRect extends Control:
	var code := ""
	var color := UiTheme.TEXT

	func _init(icon_code: String, icon_size: float = 22.0, icon_color: Color = UiTheme.TEXT) -> void:
		code = icon_code
		color = icon_color
		custom_minimum_size = Vector2(icon_size, icon_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_color(c: Color) -> void:
		color = c
		queue_redraw()

	func _draw() -> void:
		Icons.draw_action_icon(self, code, minf(size.x, size.y), Vector2.ZERO, color)

static func icon_node(code: String, size: float = 22.0, color: Color = UiTheme.TEXT) -> IconRect:
	return IconRect.new(code, size, color)
