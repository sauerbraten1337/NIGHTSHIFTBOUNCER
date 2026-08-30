## Gegenstaende, prozedural gezeichnet - fuer die grosse Ansicht auf dem
## Kontrolltisch. Jedes Icon wird in ein Quadrat der Kantenlaenge `s`
## gezeichnet, Ursprung oben links (`origin`).
##
## Portierung von src/render/items.js. Die Vorlage haelt je Gegenstand eine
## Funktion in einem Objekt; hier steht alles in einer match-Verzweigung, weil
## GDScript keine Funktionen in Konstanten kennt. Die Zahlen sind unveraendert.
class_name Items
extends RefCounted

const METAL := Color("b7c0cd")
const METAL_DARK := Color("7d8794")
const PLASTIC := Color("2b323d")

## Zeichnet das Icon eines Gegenstands. Unbekannte Ids bekommen ein Fragezeichen.
static func draw_item_icon(
	ci: CanvasItem, id: String, s: float,
	origin: Vector2 = Vector2.ZERO, font: Font = null
) -> void:
	var o := origin
	# Punkt und Rechteck in Icon-Koordinaten (0..1 mal Kantenlaenge).
	var p := func(fx: float, fy: float) -> Vector2:
		return o + Vector2(s * fx, s * fy)
	var rect := func(fx: float, fy: float, fw: float, fh: float) -> Rect2:
		return Rect2(o + Vector2(s * fx, s * fy), Vector2(s * fw, s * fh))
	var fill := func(r: Rect2, radius: float, c: Color) -> void:
		Draw2D.fill_round_rect(ci, r, radius, c)
	var stroke := func(r: Rect2, radius: float, c: Color, w: float) -> void:
		Draw2D.stroke_round_rect(ci, r, radius, c, w)
	var line := func(a: Vector2, b: Vector2, c: Color, w: float) -> void:
		Draw2D.line_round(ci, a, b, c, w)

	match id:
		# ---------------- harmlos ----------------

		"gum":
			fill.call(rect.call(0.24, 0.2, 0.52, 0.6), s * 0.06, Color("e7eef7"))
			fill.call(rect.call(0.24, 0.34, 0.52, 0.2), 2.0, Color("5fc9d8"))
			stroke.call(rect.call(0.24, 0.2, 0.52, 0.6), s * 0.06, METAL_DARK, 1.5)

		"phone":
			fill.call(rect.call(0.28, 0.14, 0.44, 0.72), s * 0.07, PLASTIC)
			fill.call(rect.call(0.33, 0.21, 0.34, 0.54), s * 0.03, Color("5d7f9c"))
			fill.call(rect.call(0.35, 0.23, 0.12, 0.5), 2.0, Color(1, 1, 1, 0.18))

		"keys":
			Draw2D.ellipse_outline(
				ci, p.call(0.36, 0.32), Vector2(s * 0.14, s * 0.14), METAL, s * 0.05
			)
			for entry: Array in [[0.1, 0.34], [-0.02, 0.28]]:
				var dx: float = entry[0]
				var len: float = entry[1]
				line.call(
					p.call(0.46 + dx, 0.4), p.call(0.5 + dx, 0.4 + len), METAL, s * 0.07
				)
				line.call(
					p.call(0.5 + dx, 0.34 + len), p.call(0.58 + dx, 0.34 + len), METAL, s * 0.03
				)

		"lighter":
			fill.call(rect.call(0.34, 0.3, 0.32, 0.52), s * 0.05, Color("c8402f"))
			fill.call(rect.call(0.36, 0.2, 0.28, 0.12), 2.0, METAL)
			Draw2D.ellipse(
				ci, p.call(0.5, 0.16), Vector2(s * 0.05, s * 0.09),
				Palette.with_alpha(Palette.AMBER, 0.9)
			)

		"smokes":
			fill.call(rect.call(0.28, 0.24, 0.44, 0.56), s * 0.04, Color("e9edf3"))
			ci.draw_rect(rect.call(0.28, 0.24, 0.44, 0.14), Color("c1262c"))
			stroke.call(rect.call(0.28, 0.24, 0.44, 0.56), s * 0.04, METAL_DARK, 1.4)

		"wallet":
			fill.call(rect.call(0.2, 0.3, 0.6, 0.42), s * 0.05, Color("6b4a33"))
			fill.call(rect.call(0.2, 0.44, 0.6, 0.28), s * 0.05, Color("563a28"))
			fill.call(rect.call(0.44, 0.42, 0.12, 0.1), 2.0, METAL)

		"earbuds":
			ci.draw_circle(p.call(0.35, 0.32), s * 0.1, Color("eef2f7"))
			ci.draw_circle(p.call(0.65, 0.32), s * 0.1, Color("eef2f7"))
			Draw2D.stroke_path(ci, Draw2D.quad_curve(
				p.call(0.35, 0.42), p.call(0.5, 0.82), p.call(0.65, 0.42)
			), Color("dfe5ee"), s * 0.035)

		"coins":
			for entry: Array in [[0.38, 0.6, 0.15], [0.6, 0.52, 0.13], [0.5, 0.38, 0.12]]:
				var c: Vector2 = p.call(entry[0], entry[1])
				var r: float = s * entry[2]
				ci.draw_circle(c, r, Palette.AMBER)
				Draw2D.ellipse_outline(ci, c, Vector2(r, r), Color("a97b1f"), 1.4)

		"tissues":
			fill.call(rect.call(0.22, 0.34, 0.56, 0.38), s * 0.05, Color("dfe6f0"))
			Draw2D.fill_path(ci, PackedVector2Array([
				p.call(0.44, 0.36), p.call(0.5, 0.18), p.call(0.58, 0.36),
			]), Color(1, 1, 1, 1))
			stroke.call(rect.call(0.22, 0.34, 0.56, 0.38), s * 0.05, Color("9aa6b6"), 1.3)

		"balm":
			fill.call(rect.call(0.4, 0.28, 0.2, 0.5), s * 0.05, Color("d2568a"))
			fill.call(rect.call(0.4, 0.2, 0.2, 0.12), s * 0.03, Color("f0f3f8"))

		"mints":
			fill.call(rect.call(0.3, 0.3, 0.4, 0.44), s * 0.12, Color("cfe9f2"))
			stroke.call(rect.call(0.3, 0.3, 0.4, 0.44), s * 0.12, Color("7fa9bb"), 1.4)
			ci.draw_circle(p.call(0.5, 0.52), s * 0.07, Color("7fa9bb"))

		"charger":
			# Die Vorlage nutzt hier eine kubische Bezierkurve.
			Draw2D.stroke_path(ci, _cubic(
				p.call(0.24, 0.3), p.call(0.7, 0.3), p.call(0.3, 0.72), p.call(0.76, 0.72)
			), Color("e6ebf2"), s * 0.045)
			fill.call(rect.call(0.18, 0.24, 0.12, 0.12), 2.0, METAL)
			fill.call(rect.call(0.72, 0.66, 0.12, 0.12), 2.0, METAL)

		"bottle":
			fill.call(rect.call(0.36, 0.26, 0.28, 0.54), s * 0.06, Color(
				Color("9fd8e8").r, Color("9fd8e8").g, Color("9fd8e8").b, 0.65
			))
			fill.call(rect.call(0.42, 0.14, 0.16, 0.14), 2.0, Color("8fb9c9"))
			ci.draw_rect(rect.call(0.36, 0.48, 0.28, 0.12), Color("4c7f92"))

		"book":
			fill.call(rect.call(0.26, 0.22, 0.48, 0.58), s * 0.03, Color("2f3a4c"))
			ci.draw_rect(rect.call(0.3, 0.26, 0.4, 0.5), Color("e7ecf3"))
			for i in 5:
				line.call(
					p.call(0.34, 0.34 + i * 0.08), p.call(0.66, 0.34 + i * 0.08),
					Color("b9c3d0"), 1.0
				)

		"powerbank":
			fill.call(rect.call(0.26, 0.28, 0.48, 0.44), s * 0.06, Color("39414f"))
			stroke.call(rect.call(0.26, 0.28, 0.48, 0.44), s * 0.06, METAL_DARK, 1.4)
			for i in 3:
				ci.draw_rect(
					rect.call(0.32 + i * 0.1, 0.62, 0.06, 0.04),
					Palette.GREEN if i < 2 else Color("2b3a33")
				)
			fill.call(rect.call(0.44, 0.36, 0.12, 0.1), 2.0, METAL)

		"shades":
			fill.call(rect.call(0.18, 0.42, 0.26, 0.18), s * 0.08, Color("1b202a"))
			fill.call(rect.call(0.56, 0.42, 0.26, 0.18), s * 0.08, Color("1b202a"))
			line.call(p.call(0.44, 0.48), p.call(0.56, 0.48), METAL_DARK, s * 0.035)
			line.call(p.call(0.18, 0.46), p.call(0.1, 0.4), METAL_DARK, s * 0.035)
			line.call(p.call(0.82, 0.46), p.call(0.9, 0.4), METAL_DARK, s * 0.035)

		"meds":
			# Blister mit aufgedruckter Beschriftung - das unterscheidet ihn
			# vom Doeschen.
			fill.call(rect.call(0.22, 0.3, 0.56, 0.4), s * 0.04, Color("dfe6f0"))
			stroke.call(rect.call(0.22, 0.3, 0.56, 0.4), s * 0.04, Color("98a3b2"), 1.3)
			for i in 3:
				for j in 2:
					ci.draw_circle(
						p.call(0.33 + i * 0.17, 0.42 + j * 0.16), s * 0.05, Color("b9c3d0")
					)
			ci.draw_rect(rect.call(0.26, 0.72, 0.34, 0.03), Color("4a5464"))

		"deo":
			fill.call(rect.call(0.38, 0.3, 0.24, 0.48), s * 0.08, Color("4a7fb5"))
			Draw2D.ellipse(ci, p.call(0.5, 0.3), Vector2(s * 0.12, s * 0.06), Color("e7eef7"))
			ci.draw_rect(rect.call(0.42, 0.4, 0.04, 0.3), Color(1, 1, 1, 0.25))

		"selfie":
			line.call(p.call(0.24, 0.76), p.call(0.7, 0.3), METAL, s * 0.05)
			fill.call(rect.call(0.62, 0.18, 0.2, 0.16), s * 0.04, PLASTIC)
			line.call(p.call(0.24, 0.76), p.call(0.18, 0.82), PLASTIC, s * 0.08)

		"pen":
			line.call(p.call(0.3, 0.74), p.call(0.68, 0.3), Color("2f6fb5"), s * 0.07)
			Draw2D.fill_path(ci, PackedVector2Array([
				p.call(0.26, 0.78), p.call(0.34, 0.7), p.call(0.32, 0.68),
			]), METAL)
			line.call(p.call(0.6, 0.34), p.call(0.66, 0.42), METAL_DARK, s * 0.03)

		"snack":
			fill.call(rect.call(0.2, 0.4, 0.6, 0.22), s * 0.05, Color("8a5a2b"))
			ci.draw_rect(rect.call(0.34, 0.4, 0.32, 0.22), Color("c98b3f"))
			Draw2D.fill_path(ci, PackedVector2Array([
				p.call(0.2, 0.4), p.call(0.12, 0.34), p.call(0.12, 0.68), p.call(0.2, 0.62),
			]), Color("8a5a2b"))
			Draw2D.fill_path(ci, PackedVector2Array([
				p.call(0.8, 0.4), p.call(0.88, 0.34), p.call(0.88, 0.68), p.call(0.8, 0.62),
			]), Color("8a5a2b"))

		"earplugs":
			for entry: Array in [[0.38, 0.44], [0.6, 0.58]]:
				# Die Vorlage dreht die Ellipse um 0.4 rad.
				var center: Vector2 = p.call(entry[0], entry[1])
				var pts := _rotate_points(
					Draw2D.ellipse_points(Vector2.ZERO, Vector2(s * 0.11, s * 0.15)), 0.4, center
				)
				Draw2D.fill_path(ci, pts, Color("f0c96a"))
				Draw2D.stroke_path(ci, pts, Color("b9932f"), 1.3, true)

		"vape":
			fill.call(rect.call(0.42, 0.2, 0.16, 0.6), s * 0.05, Color("2b323d"))
			fill.call(rect.call(0.45, 0.42, 0.1, 0.18), 2.0, Color("5fc9d8"))
			fill.call(rect.call(0.44, 0.14, 0.12, 0.08), 2.0, Color("1b202a"))

		"ticket":
			fill.call(rect.call(0.16, 0.34, 0.68, 0.32), s * 0.04, Color("e7dfc8"))
			stroke.call(rect.call(0.16, 0.34, 0.68, 0.32), s * 0.04, Color("a89b78"), 1.3)
			# ctx.setLineDash([3, 3]) hat in Godot kein Gegenstueck - die
			# Perforation wird als Strichfolge gezeichnet.
			_dashed_line(ci, p.call(0.62, 0.34), p.call(0.62, 0.66), Color("a89b78"), 1.0, 3.0, 3.0)
			for i in 3:
				ci.draw_rect(rect.call(0.22, 0.42 + i * 0.07, 0.32, 0.03), Color("57503c"))

		# ---------------- verboten ----------------

		"camera":
			fill.call(rect.call(0.16, 0.32, 0.68, 0.42), s * 0.06, Color("1c222c"))
			fill.call(rect.call(0.36, 0.24, 0.2, 0.1), 2.0, Color("2b333f"))
			ci.draw_circle(p.call(0.5, 0.53), s * 0.16, Color("0d1117"))
			Draw2D.ellipse_outline(
				ci, p.call(0.5, 0.53), Vector2(s * 0.16, s * 0.16), METAL, s * 0.03
			)
			ci.draw_circle(p.call(0.45, 0.48), s * 0.05, Color(
				Color("7fd4ff").r, Color("7fd4ff").g, Color("7fd4ff").b, 0.5
			))

		"glass":
			var glass_path := PackedVector2Array([p.call(0.4, 0.82), p.call(0.4, 0.42)])
			Draw2D.append_quad(glass_path, p.call(0.42, 0.3), p.call(0.45, 0.24))
			glass_path.append(p.call(0.55, 0.24))
			Draw2D.append_quad(glass_path, p.call(0.58, 0.3), p.call(0.6, 0.42))
			glass_path.append(p.call(0.6, 0.82))
			Draw2D.fill_path(ci, glass_path, Color(
				Color("5f8f4e").r, Color("5f8f4e").g, Color("5f8f4e").b, 0.85
			))
			ci.draw_rect(rect.call(0.44, 0.18, 0.12, 0.08), Color("c1262c"))
			ci.draw_rect(rect.call(0.43, 0.46, 0.04, 0.3), Color(1, 1, 1, 0.25))

		"laser":
			fill.call(rect.call(0.28, 0.44, 0.44, 0.14), s * 0.05, Color("33404f"))
			fill.call(rect.call(0.68, 0.46, 0.08, 0.1), 2.0, METAL)
			line.call(
				p.call(0.78, 0.51), p.call(0.94, 0.51),
				Palette.with_alpha(Palette.GREEN, 0.9), 2.0
			)

		"substance":
			var sub := PackedVector2Array([
				p.call(0.3, 0.34), p.call(0.7, 0.34), p.call(0.64, 0.76), p.call(0.36, 0.76),
			])
			Draw2D.fill_path(ci, sub, Color("cfd6e0", 0.9))
			Draw2D.stroke_path(ci, sub, Color("8d97a5"), 1.5, true)
			ci.draw_rect(rect.call(0.3, 0.28, 0.4, 0.07), Color("8d97a5"))
			Draw2D.ellipse(
				ci, p.call(0.5, 0.62), Vector2(s * 0.12, s * 0.08), Color("f2f5f9", 0.85)
			)

		"spray":
			fill.call(rect.call(0.38, 0.3, 0.24, 0.5), s * 0.05, Color("c1272d"))
			fill.call(rect.call(0.42, 0.2, 0.16, 0.12), 2.0, Color("2b323d"))
			for i in 3:
				Draw2D.stroke_path(ci, Draw2D.ellipse_points(
					p.call(0.5, 0.18), Vector2(s * (0.1 + i * 0.06), s * (0.1 + i * 0.06)),
					PI * 1.2, PI * 1.8
				), Palette.with_alpha(Palette.AMBER, 0.8), 2.0)

		"tool":
			fill.call(rect.call(0.34, 0.3, 0.14, 0.5), s * 0.03, METAL)
			fill.call(rect.call(0.52, 0.3, 0.14, 0.5), s * 0.03, METAL)
			stroke.call(rect.call(0.34, 0.3, 0.14, 0.5), s * 0.03, METAL_DARK, 1.5)
			stroke.call(rect.call(0.52, 0.3, 0.14, 0.5), s * 0.03, METAL_DARK, 1.5)
			line.call(p.call(0.5, 0.3), p.call(0.5, 0.14), Color("dfe5ee"), s * 0.04)

		"baton":
			line.call(p.call(0.22, 0.72), p.call(0.56, 0.42), METAL_DARK, s * 0.09)
			line.call(p.call(0.56, 0.42), p.call(0.8, 0.24), METAL, s * 0.06)
			ci.draw_circle(p.call(0.2, 0.74), s * 0.08, PLASTIC)

		"blade":
			var blade := PackedVector2Array([
				p.call(0.22, 0.7), p.call(0.66, 0.28), p.call(0.74, 0.36), p.call(0.32, 0.78),
			])
			Draw2D.fill_path(ci, blade, METAL)
			Draw2D.stroke_path(ci, blade, METAL_DARK, 1.4, true)
			line.call(p.call(0.3, 0.76), p.call(0.16, 0.86), PLASTIC, s * 0.11)

		"cutter":
			fill.call(rect.call(0.2, 0.46, 0.44, 0.16), s * 0.03, Color("c8b03a"))
			stroke.call(rect.call(0.2, 0.46, 0.44, 0.16), s * 0.03, Color("8d7b22"), 1.3)
			var cut := PackedVector2Array([
				p.call(0.62, 0.48), p.call(0.86, 0.48), p.call(0.86, 0.58), p.call(0.62, 0.6),
			])
			Draw2D.fill_path(ci, cut, METAL)
			Draw2D.stroke_path(ci, cut, METAL_DARK, 1.0, true)
			ci.draw_circle(p.call(0.34, 0.54), s * 0.04, Color("8d7b22"))

		"butterfly":
			line.call(p.call(0.24, 0.72), p.call(0.5, 0.5), METAL_DARK, s * 0.07)
			line.call(p.call(0.3, 0.8), p.call(0.56, 0.58), METAL_DARK, s * 0.07)
			var bf := PackedVector2Array([
				p.call(0.5, 0.5), p.call(0.82, 0.22), p.call(0.88, 0.3), p.call(0.56, 0.58),
			])
			Draw2D.fill_path(ci, bf, METAL)
			Draw2D.stroke_path(ci, bf, METAL_DARK, 1.3, true)

		"knuckles":
			for i in 4:
				Draw2D.ellipse_outline(
					ci, p.call(0.28 + i * 0.15, 0.44),
					Vector2(s * 0.07, s * 0.07), METAL, s * 0.07
				)
			Draw2D.stroke_path(ci, Draw2D.quad_curve(
				p.call(0.22, 0.56), p.call(0.5, 0.76), p.call(0.78, 0.56)
			), METAL_DARK, s * 0.09)

		"stun":
			fill.call(rect.call(0.34, 0.36, 0.32, 0.44), s * 0.06, PLASTIC)
			line.call(p.call(0.42, 0.36), p.call(0.42, 0.2), METAL, s * 0.045)
			line.call(p.call(0.58, 0.36), p.call(0.58, 0.2), METAL, s * 0.045)
			Draw2D.stroke_path(ci, PackedVector2Array([
				p.call(0.42, 0.22), p.call(0.52, 0.28), p.call(0.46, 0.3), p.call(0.58, 0.22),
			]), Palette.with_alpha(Palette.CYAN, 0.95), s * 0.035)
			ci.draw_circle(p.call(0.5, 0.62), s * 0.05, Palette.RED)

		"flare":
			fill.call(rect.call(0.4, 0.36, 0.2, 0.46), s * 0.03, Color("b4322c"))
			ci.draw_rect(rect.call(0.4, 0.5, 0.2, 0.08), Color("e7dfc8"))
			var flame := PackedVector2Array([p.call(0.5, 0.08)])
			Draw2D.append_quad(flame, p.call(0.66, 0.26), p.call(0.5, 0.36))
			Draw2D.append_quad(flame, p.call(0.34, 0.26), p.call(0.5, 0.08))
			Draw2D.fill_path(ci, flame, Palette.with_alpha(Palette.AMBER, 0.95))

		"banger":
			fill.call(rect.call(0.36, 0.4, 0.28, 0.4), s * 0.04, Color("c1272d"))
			ci.draw_rect(rect.call(0.36, 0.56, 0.28, 0.07), Color("e7dfc8"))
			Draw2D.stroke_path(ci, Draw2D.quad_curve(
				p.call(0.5, 0.4), p.call(0.66, 0.3), p.call(0.6, 0.16)
			), Color("d6cba8"), s * 0.035)
			ci.draw_circle(p.call(0.6, 0.14), s * 0.04, Palette.with_alpha(Palette.AMBER, 0.9))

		"smokepot":
			fill.call(rect.call(0.34, 0.44, 0.32, 0.36), s * 0.05, Color("4d5a45"))
			stroke.call(rect.call(0.34, 0.44, 0.32, 0.36), s * 0.05, Color("2f382a"), 1.4)
			for i in 3:
				ci.draw_circle(
					p.call(0.42 + i * 0.09, 0.34 - i * 0.07),
					s * (0.08 - i * 0.012), Color("c9d2df", 0.5)
				)

		"sparkler":
			for dx: float in [-0.06, 0.0, 0.06]:
				line.call(
					p.call(0.42 + dx, 0.82), p.call(0.5 + dx, 0.3), METAL_DARK, s * 0.03
				)
			for i in 6:
				var a := (float(i) / 6.0) * TAU
				line.call(
					p.call(0.5, 0.26), p.call(0.5 + cos(a) * 0.16, 0.26 + sin(a) * 0.16),
					Palette.with_alpha(Palette.AMBER, 0.9), s * 0.025
				)

		"pills":
			fill.call(rect.call(0.34, 0.34, 0.32, 0.44), s * 0.06, Color("e7eef7", 0.85))
			stroke.call(rect.call(0.34, 0.34, 0.32, 0.44), s * 0.06, Color("98a3b2"), 1.5)
			fill.call(rect.call(0.32, 0.26, 0.36, 0.1), s * 0.03, Color("7f8b9b"))
			for entry: Array in [[0.43, 0.52], [0.56, 0.58], [0.48, 0.66]]:
				ci.draw_circle(p.call(entry[0], entry[1]), s * 0.055, Color("d76a8a"))

		"powder":
			# Gefaltetes Briefchen - ohne jede Beschriftung.
			var fold := PackedVector2Array([
				p.call(0.26, 0.4), p.call(0.74, 0.4), p.call(0.66, 0.7), p.call(0.34, 0.7),
			])
			Draw2D.fill_path(ci, fold, Color("e9edf3"))
			Draw2D.stroke_path(ci, fold, Color("98a3b2"), 1.4, true)
			line.call(p.call(0.5, 0.4), p.call(0.5, 0.7), Color("c3ccd8"), 1.4)
			line.call(p.call(0.3, 0.55), p.call(0.7, 0.55), Color("c3ccd8"), 1.4)

		"vial":
			fill.call(rect.call(0.4, 0.34, 0.2, 0.44), s * 0.04, Color("9fd8e8", 0.6))
			stroke.call(rect.call(0.4, 0.34, 0.2, 0.44), s * 0.04, Color("7fa9bb"), 1.4)
			fill.call(rect.call(0.43, 0.24, 0.14, 0.1), 2.0, Color("c8a45a"))
			ci.draw_rect(rect.call(0.42, 0.58, 0.16, 0.18), Color("b5d9a0", 0.9))

		"screwdriver":
			fill.call(rect.call(0.22, 0.6, 0.26, 0.16), s * 0.06, Color("c1272d"))
			line.call(p.call(0.48, 0.68), p.call(0.8, 0.68), METAL, s * 0.05)
			ci.draw_rect(rect.call(0.78, 0.63, 0.06, 0.1), METAL_DARK)

		"pliers":
			line.call(p.call(0.28, 0.82), p.call(0.56, 0.44), METAL, s * 0.06)
			line.call(p.call(0.5, 0.82), p.call(0.72, 0.44), METAL, s * 0.06)
			line.call(p.call(0.56, 0.44), p.call(0.46, 0.24), METAL_DARK, s * 0.05)
			line.call(p.call(0.72, 0.44), p.call(0.78, 0.24), METAL_DARK, s * 0.05)
			ci.draw_circle(p.call(0.64, 0.46), s * 0.05, Color("c1272d"))

		"flask":
			fill.call(rect.call(0.3, 0.3, 0.4, 0.48), s * 0.1, METAL)
			stroke.call(rect.call(0.3, 0.3, 0.4, 0.48), s * 0.1, METAL_DARK, 1.5)
			fill.call(rect.call(0.44, 0.2, 0.12, 0.12), 2.0, METAL_DARK)
			line.call(p.call(0.38, 0.4), p.call(0.38, 0.68), Color(1, 1, 1, 0.3), s * 0.03)

		"wine":
			var wine := PackedVector2Array([p.call(0.38, 0.84), p.call(0.38, 0.46)])
			Draw2D.append_quad(wine, p.call(0.42, 0.32), p.call(0.45, 0.22))
			wine.append(p.call(0.55, 0.22))
			Draw2D.append_quad(wine, p.call(0.58, 0.32), p.call(0.62, 0.46))
			wine.append(p.call(0.62, 0.84))
			Draw2D.fill_path(ci, wine, Color("3c2a45", 0.9))
			ci.draw_rect(rect.call(0.44, 0.14, 0.12, 0.1), Color("8a2b3a"))
			ci.draw_rect(rect.call(0.38, 0.56, 0.24, 0.16), Color("e7dfc8"))

		"lens":
			fill.call(rect.call(0.26, 0.3, 0.48, 0.46), s * 0.06, Color("1c222c"))
			for i in 3:
				line.call(
					p.call(0.26, 0.42 + i * 0.11), p.call(0.74, 0.42 + i * 0.11),
					METAL_DARK, 1.5
				)
			Draw2D.ellipse(ci, p.call(0.5, 0.3), Vector2(s * 0.24, s * 0.08), Color("0d1117"))
			Draw2D.ellipse(
				ci, p.call(0.5, 0.3), Vector2(s * 0.16, s * 0.05), Color("7fd4ff", 0.45)
			)

		"actioncam":
			fill.call(rect.call(0.28, 0.32, 0.44, 0.4), s * 0.06, Color("2b333f"))
			stroke.call(rect.call(0.28, 0.32, 0.44, 0.4), s * 0.06, METAL_DARK, 1.4)
			ci.draw_circle(p.call(0.46, 0.52), s * 0.11, Color("0d1117"))
			ci.draw_circle(p.call(0.43, 0.49), s * 0.04, Color("7fd4ff", 0.55))
			ci.draw_rect(rect.call(0.62, 0.38, 0.05, 0.05), Palette.RED)

		"blinder":
			fill.call(rect.call(0.24, 0.4, 0.34, 0.2), s * 0.05, Color("33404f"))
			Draw2D.fill_path(ci, PackedVector2Array([
				p.call(0.58, 0.34), p.call(0.72, 0.28), p.call(0.72, 0.72), p.call(0.58, 0.66),
			]), METAL)
			for i in range(-1, 2):
				line.call(
					p.call(0.74, 0.5 + i * 0.06), p.call(0.94, 0.5 + i * 0.16),
					Color("fff3c4", 0.9), 2.0
				)

		_:
			_draw_unknown(ci, s, o, font)

static func _draw_unknown(ci: CanvasItem, s: float, o: Vector2, font: Font) -> void:
	Draw2D.stroke_round_rect(
		ci, Rect2(o + Vector2(s * 0.28, s * 0.28), Vector2(s * 0.44, s * 0.44)),
		4.0, Palette.GREY, 2.0
	)
	var f := font if font != null else ThemeDB.fallback_font
	Draw2D.text(
		ci, f, o + Vector2(s * 0.5, s * 0.52), "?", int(round(s * 0.3)), Palette.GREY,
		Draw2D.Align.CENTER, Draw2D.Baseline.MIDDLE
	)

## Umhaengetasche an der Figur.
## Der Riemen laeuft von der gegenueberliegenden Schulter schraeg ueber den
## Koerper zur Tasche an der Huefte - so, wie man sie wirklich traegt.
static func draw_shoulder_bag(ci: CanvasItem, opts: Dictionary) -> void:
	var x := float(opts["x"])
	var y := float(opts["y"])
	var w := float(opts["w"])
	var h := float(opts["h"])
	var color: Color = opts.get("color", Color("3a4557"))

	# Riemen
	if opts.has("strapX"):
		var strap_x := float(opts["strapX"])
		var strap_y := float(opts["strapY"])
		Draw2D.stroke_path(ci, Draw2D.quad_curve(
			Vector2(strap_x, strap_y),
			Vector2((strap_x + x + w * 0.5) * 0.5, (strap_y + y) * 0.5 + h * 0.1),
			Vector2(x + w * 0.5, y + h * 0.12)
		), Color("20262f"), maxf(2.5, w * 0.11))

	# Korpus
	Draw2D.fill_round_rect(ci, Rect2(x, y, w, h), w * 0.14, color)
	# Deckelklappe
	Draw2D.fill_round_rect(ci, Rect2(x, y, w, h * 0.42), w * 0.14, Color(0, 0, 0, 0.3))
	# Verschluss
	Draw2D.fill_round_rect(
		ci, Rect2(x + w * 0.4, y + h * 0.34, w * 0.2, h * 0.16), 2.0, METAL_DARK
	)
	Draw2D.stroke_round_rect(ci, Rect2(x, y, w, h), w * 0.14, Color(0, 0, 0, 0.45), 1.4)

# ---------- Hilfen ----------

## Kubische Bezierkurve (ctx.bezierCurveTo) - nur das Ladekabel braucht sie.
static func _cubic(
	from: Vector2, c1: Vector2, c2: Vector2, to: Vector2, segments: int = 18
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var u := 1.0 - t
		points.append(
			u * u * u * from + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * to
		)
	return points

static func _rotate_points(
	points: PackedVector2Array, angle: float, offset: Vector2
) -> PackedVector2Array:
	var xf := Transform2D(angle, offset)
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(xf * p)
	return out

## Gestrichelte Linie - Ersatz fuer ctx.setLineDash().
static func _dashed_line(
	ci: CanvasItem, from: Vector2, to: Vector2, color: Color,
	width: float, dash: float, gap: float
) -> void:
	var total := from.distance_to(to)
	if total <= 0.0:
		return
	var dir := (to - from) / total
	var pos := 0.0
	while pos < total:
		var end := minf(pos + dash, total)
		ci.draw_line(from + dir * pos, from + dir * end, color, width, true)
		pos = end + gap
