## Der Club von innen - Zwei-Drittel-Ansicht von oben.
##
## Der Blick faellt schraeg von oben in den Raum: hinten die Buehne mit dem
## DJ-Pult, in der Mitte die Tanzflaeche, links die Bar, rechts die Booths,
## vorne rechts die Toiletten und vorne in der Mitte der Eingang - die Tuer,
## an der die Schicht beginnt.
##
## Grundriss und Bild sind getrennt: AREAS beschreibt die Flaechen als
## Anteile des Grundrisses (x nach rechts, y von der Rueckwand nach vorn),
## project() rechnet einen Grundrisspunkt in den Bildpunkt um. Weil die
## Projektion linear mit Breite und Hoehe skaliert, liefert dieselbe Rechnung
## mit w = h = 1 die Anteilsrechtecke fuer die anklickbaren Felder der
## Oberflaeche (hotspot_rect) - Bild und Klickflaeche koennen also nicht
## auseinanderlaufen.
class_name Club
extends RefCounted

const CLUB_WORLD := Vector2(1280, 720)

## Der Raum im Bild: hintere Kante, vordere Kante und wie stark sich der
## Grundriss nach hinten verjuengt (Zwei-Drittel-Blick statt Draufsicht).
const ROOM_TOP := 0.215
const ROOM_BOTTOM := 0.995
const FAR_WIDTH := 0.62

## Die Flaechen des Clubs im Grundriss. `lift` ist die Bauhoehe in Pixeln
## (bei 720 Bildhoehe), `label`/`note` beschriften das Klickfeld.
const AREAS := {
	"stage": {
		"x": 0.255, "y": 0.0, "w": 0.49, "h": 0.16, "lift": 34.0,
		"label": "BÜHNE · DJ-PULT", "note": "Der Act des Abends",
		"hint": "Bühne: Der DJ legt auf, das Pult steht bereit.",
	},
	"floor": {
		"x": 0.235, "y": 0.20, "w": 0.53, "h": 0.44, "lift": 0.0,
		"label": "TANZFLÄCHE", "note": "Voll ab Mitternacht",
		"hint": "Tanzfläche: Hier landet jeder, den du reinlässt.",
	},
	"bar": {
		"x": 0.025, "y": 0.20, "w": 0.16, "h": 0.46, "lift": 46.0,
		"label": "BAR", "note": "Getränke, Umsatz",
		"hint": "Bar: Was hier über den Tresen geht, zahlt deine Schicht.",
	},
	"booths": {
		"x": 0.815, "y": 0.14, "w": 0.16, "h": 0.52, "lift": 30.0,
		"label": "BOOTHS", "note": "Sitzecken und VIP",
		"hint": "Booths: Sitzecken für Stammgäste und VIPs.",
	},
	"toilets": {
		"x": 0.775, "y": 0.74, "w": 0.20, "h": 0.24, "lift": 74.0,
		"label": "TOILETTEN", "note": "Zwei Türen, eine Schlange",
		"hint": "Toiletten: zwei Türen, immer eine Schlange davor.",
	},
	"entrance": {
		"x": 0.375, "y": 0.80, "w": 0.25, "h": 0.20, "lift": 92.0,
		"label": "EINGANG", "note": "Schicht beginnen",
		"hint": "Eingang: raus an die Tür - die Schicht beginnt.",
	},
}

## Reihenfolge beim Zeichnen: hinten zuerst, vorne zuletzt.
const DRAW_ORDER := ["stage", "floor", "bar", "booths", "toilets", "entrance"]

# Farben: kalter Beton, warmes Holz, viel Schwarz - Nachtfassung der Palette.
const WALL_TOP := Color("11141c")
const WALL_BOTTOM := Color("1b202b")
const FLOOR_FAR := Color("161a23")
const FLOOR_NEAR := Color("0d1016")
const WOOD := Color("4b3626")
const WOOD_DARK := Color("2c2016")
const METAL := Color("3c4453")
const METAL_DARK := Color("222932")
const TILE_DARK := Color("1c2230")

# ---------------- Projektion ----------------

## Grundriss -> Bild. px: 0 links, 1 rechts. py: 0 Rueckwand, 1 vorne.
static func project(w: float, h: float, px: float, py: float) -> Vector2:
	# Die Tiefe waechst nach vorn: gleiche Schritte im Grundriss werden im
	# Bild vorne groesser. Das ist die ganze Perspektive.
	var d := py * 0.62 + py * py * 0.38
	var y := lerpf(ROOM_TOP, ROOM_BOTTOM, d) * h
	var spread := lerpf(FAR_WIDTH, 1.0, d)
	return Vector2((0.5 + (px - 0.5) * spread) * w, y)

## Wie gross ist ein Ding in dieser Tiefe? (1.0 = vorderste Kante)
static func depth_scale(py: float) -> float:
	var d := py * 0.62 + py * py * 0.38
	return lerpf(FAR_WIDTH, 1.0, d)

## Die vier Eckpunkte einer Grundrissflaeche im Bild:
## hinten links, hinten rechts, vorne rechts, vorne links.
static func floor_quad(w: float, h: float, area: Dictionary) -> PackedVector2Array:
	var x0 := float(area["x"])
	var x1 := x0 + float(area["w"])
	var y0 := float(area["y"])
	var y1 := y0 + float(area["h"])
	return PackedVector2Array([
		project(w, h, x0, y0), project(w, h, x1, y0),
		project(w, h, x1, y1), project(w, h, x0, y1),
	])

static func _lift(points: PackedVector2Array, dy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(Vector2(p.x, p.y - dy))
	return out

## Das anklickbare Rechteck einer Flaeche - achsenparallel, also die
## umschliessende Box aus Grundflaeche und Bauhoehe.
static func hotspot_rect(id: String, w: float = 1.0, h: float = 1.0) -> Rect2:
	var area: Dictionary = AREAS[id]
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, float(area["lift"]) / CLUB_WORLD.y * h)
	var min_p := quad[0]
	var max_p := quad[0]
	for points: PackedVector2Array in [quad, top]:
		for p: Vector2 in points:
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	return Rect2(min_p, max_p - min_p)

# ---------------- Bild ----------------

## `levels` kommt aus GameState (Ausbaustufen) und faerbt den Raum:
## { floor, bar, vip, lights, sound, tier, artist }.
static func draw_club(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	_draw_shell(ci, w, h)
	_draw_stage(ci, fx, w, h, t, levels)
	_draw_beams(fx, w, h, t, levels)
	_draw_dancefloor(ci, fx, w, h, t, levels)
	_draw_bar(ci, fx, w, h, t, levels)
	_draw_booths(ci, fx, w, h, t, levels)
	_draw_toilets(ci, fx, w, h, t)
	_draw_entrance(ci, fx, w, h, t)
	_draw_owner(ci, w, h, t, levels.get("character", null))
	_draw_haze(ci, fx, w, h, t)

## Waende, Boden, Deckentraverse - der leere Raum.
static func _draw_shell(ci: CanvasItem, w: float, h: float) -> void:
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, ROOM_TOP * h + 2.0), WALL_TOP, WALL_BOTTOM)

	# Seitenwaende: die Keile links und rechts neben dem Grundriss. Sie
	# laufen nach hinten zusammen - daher der Zwei-Drittel-Blick.
	var room := floor_quad(w, h, {"x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0})
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(0, ROOM_TOP * h), room[0], room[3], Vector2(0, h),
	]), Color("0a0d13"))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(w, ROOM_TOP * h), Vector2(w, h), room[2], room[1],
	]), Color("0a0d13"))

	# Boden: der Grundriss als Trapez.
	ci.draw_polygon(room, PackedColorArray([FLOOR_FAR, FLOOR_FAR, FLOOR_NEAR, FLOOR_NEAR]))

	# Betonfugen der Rueckwand
	var joint := Color(1, 1, 1, 0.035)
	var y := 26.5
	while y < ROOM_TOP * h:
		ci.draw_line(Vector2(0, y), Vector2(w, y), joint, 1.0, true)
		y += 34.0

	# Traverse unter der Decke, quer ueber den Raum
	var truss_y := ROOM_TOP * h * 0.34
	ci.draw_rect(Rect2(w * 0.06, truss_y, w * 0.88, 7.0), METAL_DARK)
	ci.draw_rect(Rect2(w * 0.06, truss_y, w * 0.88, 2.0), Color(1, 1, 1, 0.07))
	var x := w * 0.08
	while x < w * 0.94:
		ci.draw_line(
			Vector2(x, truss_y + 7.0), Vector2(x + 26.0, truss_y), Color(1, 1, 1, 0.05), 2.0, true
		)
		x += 26.0

## Buehne mit DJ-Pult, Boxen und der Wand dahinter.
static func _draw_stage(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["stage"]
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Podest: Vorderkante und Deck
	ci.draw_colored_polygon(
		PackedVector2Array([quad[3], quad[2], top[2], top[3]]), Color("14181f")
	)
	ci.draw_polygon(top, PackedColorArray([
		Color("232a36"), Color("232a36"), Color("1a2028"), Color("1a2028"),
	]))
	ci.draw_line(top[3], top[2], Palette.with_alpha(Palette.CYAN, 0.35), 2.0, true)

	# Boxenstapel links und rechts, Hoehe nach Soundanlage
	var sound := int(levels.get("sound", 0))
	for side: float in [0.0, 1.0]:
		var bx := lerpf(float(area["x"]) - 0.045, float(area["x"]) + float(area["w"]) + 0.045, side)
		var base := project(w, h, bx, float(area["y"]) + float(area["h"]) * 0.5)
		var bw := w * 0.052
		var bh := h * (0.15 + sound * 0.022)
		var rect := Rect2(base.x - bw * 0.5, base.y - bh, bw, bh)
		Draw2D.fill_round_rect(ci, rect, 3.0, Color("14171d"))
		ci.draw_rect(rect, Color(1, 1, 1, 0.05), false, 1.0)
		for i in 2 + sound:
			var cy := rect.position.y + bh * (0.22 + i * 0.24)
			var r := bw * (0.3 - i * 0.03)
			ci.draw_circle(Vector2(rect.position.x + bw * 0.5, cy), r, Color("0a0c10"))
			Draw2D.ellipse_outline(
				ci, Vector2(rect.position.x + bw * 0.5, cy), Vector2(r, r),
				Color(1, 1, 1, 0.06), 1.0
			)
		# Bass driftet sichtbar: ein leichter Puls auf der Membran
		var pulse := 0.5 + sin(t * 6.4 + side * 1.7) * 0.5
		Effects.glow(
			fx, rect.position.x + bw * 0.5, rect.position.y + bh * 0.3, bw * 1.6,
			Palette.CYAN, 0.05 + pulse * 0.05
		)

	# DJ-Pult in der Mitte des Podests
	var mid := project(w, h, 0.5, float(area["y"]) + float(area["h"]) * 0.62)
	var dw := w * 0.15
	var dh := h * 0.055
	var desk := Rect2(mid.x - dw * 0.5, mid.y - lift - dh * 0.35, dw, dh)
	Draw2D.fill_round_rect(ci, desk, 3.0, Color("2b3340"))
	Draw2D.fill_round_rect(
		ci, Rect2(desk.position.x + 4.0, desk.position.y + 3.0, desk.size.x - 8.0, dh * 0.42),
		2.0, Color("171c24")
	)
	# Zwei Plattenteller und die Fader dazwischen
	for side: float in [0.28, 0.72]:
		var cx := desk.position.x + desk.size.x * side
		var cy := desk.position.y + dh * 0.28
		Draw2D.ellipse(ci, Vector2(cx, cy), Vector2(dw * 0.09, dh * 0.2), Color("0b0e13"))
		Draw2D.ellipse(
			ci, Vector2(cx + cos(t * 3.0) * dw * 0.03, cy + sin(t * 3.0) * dh * 0.06),
			Vector2(dw * 0.02, dh * 0.05), Palette.with_alpha(Palette.AMBER, 0.8)
		)
	for i in 5:
		var fx_x := desk.position.x + desk.size.x * (0.42 + i * 0.035)
		ci.draw_rect(
			Rect2(fx_x, desk.position.y + dh * 0.16, 2.0, dh * 0.3), Color(1, 1, 1, 0.18)
		)

	# Der DJ dahinter - Kopf und Schultern ueber dem Pult
	var djx := mid.x
	var djy := desk.position.y - h * 0.012
	var sway := sin(t * 2.2) * w * 0.006
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(djx - dw * 0.16 + sway, djy), Vector2(djx + dw * 0.16 + sway, djy),
		Vector2(djx + dw * 0.12 + sway, djy - h * 0.05),
		Vector2(djx - dw * 0.12 + sway, djy - h * 0.05),
	]), Color("11151c"))
	ci.draw_circle(Vector2(djx + sway, djy - h * 0.068), h * 0.024, Color("2a2018"))
	# Kopfhoerer
	Draw2D.stroke_path(ci, Draw2D.ellipse_points(
		Vector2(djx + sway, djy - h * 0.068), Vector2(h * 0.03, h * 0.03), PI, TAU
	), Palette.with_alpha(Palette.CYAN, 0.6), 3.0)

	# Leuchtschrift an der Rueckwand
	var name_text: String = String(levels.get("artist", "NULLWERK"))
	Draw2D.text(
		ci, Fonts.mono_spaced(6.0), Vector2(w * 0.5, ROOM_TOP * h * 0.72), name_text, 22,
		Palette.with_alpha(Palette.RED, 0.65 + sin(t * 1.8) * 0.2), Draw2D.Align.CENTER
	)
	Effects.glow(fx, w * 0.5, ROOM_TOP * h * 0.66, w * 0.5, Palette.RED, 0.1)

## Lichtkegel von der Traverse auf die Tanzflaeche - der Raum lebt vom Licht.
static func _draw_beams(fx: Variant, w: float, h: float, t: float, levels: Dictionary) -> void:
	var lights := int(levels.get("lights", 0))
	var count := 4 + lights
	var colors := [Palette.CYAN, Palette.PURPLE, Palette.RED, Palette.AMBER, Palette.GREEN]
	var truss_y := ROOM_TOP * h * 0.36
	for i in count:
		var src_x := w * (0.16 + float(i) / maxf(1.0, count - 1.0) * 0.68)
		var swing := sin(t * (0.7 + i * 0.13) + i) * w * 0.16
		var hit := project(w, h, 0.5 + (src_x / w - 0.5) * 1.25, 0.62)
		var color: Color = colors[i % colors.size()]
		var strength := 0.16 + (i % 2) * 0.05 + lights * 0.02
		fx.draw_polygon(
			PackedVector2Array([
				Vector2(src_x - 5.0, truss_y), Vector2(src_x + 5.0, truss_y),
				Vector2(hit.x + swing + w * 0.075, hit.y),
				Vector2(hit.x + swing - w * 0.075, hit.y),
			]),
			PackedColorArray([
				Palette.with_alpha(color, strength), Palette.with_alpha(color, strength),
				Palette.with_alpha(color, 0.0), Palette.with_alpha(color, 0.0),
			])
		)
		fx.draw_circle(Vector2(src_x, truss_y + 6.0), 5.0, Palette.with_alpha(color, 0.55))

## Tanzflaeche: leuchtende Platten und die Leute darauf.
static func _draw_dancefloor(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["floor"]
	var floor_level := int(levels.get("floor", 0))
	var cols := 8
	var rows := 6
	var beat := 0.5 + sin(t * 4.2) * 0.5

	for row in rows:
		for col in cols:
			var x0 := float(area["x"]) + float(area["w"]) * (float(col) / cols)
			var y0 := float(area["y"]) + float(area["h"]) * (float(row) / rows)
			var cell := {
				"x": x0, "y": y0,
				"w": float(area["w"]) / cols, "h": float(area["h"]) / rows,
			}
			var quad := floor_quad(w, h, cell)
			var wave := sin(t * 2.6 + col * 0.7 + row * 0.5) * 0.5 + 0.5
			var lit := (col + row) % 2 == 0
			var tint: Color = Palette.CYAN if lit else Palette.PURPLE
			var strength := (0.06 + wave * 0.16 + beat * 0.06) * (1.0 + floor_level * 0.15)
			ci.draw_colored_polygon(quad, TILE_DARK)
			ci.draw_colored_polygon(quad, Palette.with_alpha(tint, strength))
			ci.draw_polyline(
				PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
				Color(0, 0, 0, 0.35), 1.0, true
			)

	# Die Tanzenden: fester Platz im Grundriss, nur der Takt bewegt sie.
	var crowd := 10 + floor_level * 3
	for i in crowd:
		var f := _hash01(i * 3.7)
		var g := _hash01(i * 9.1 + 4.0)
		var px := float(area["x"]) + 0.05 + f * (float(area["w"]) - 0.1)
		var py := float(area["y"]) + 0.06 + g * (float(area["h"]) - 0.12)
		_draw_dancer(ci, w, h, px, py, t + i * 0.7, i)

	# Der Schein der Flaeche faellt in den Raum
	var mid := project(w, h, 0.5, float(area["y"]) + float(area["h"]) * 0.5)
	Effects.glow(fx, mid.x, mid.y, w * 0.55, Palette.CYAN, 0.05 + beat * 0.04)

static func _draw_dancer(
	ci: CanvasItem, w: float, h: float, px: float, py: float, t: float, index: int
) -> void:
	var base := project(w, h, px, py)
	var scale := depth_scale(py)
	var bob := absf(sin(t * 3.1)) * h * 0.008
	var body_h := h * 0.052 * scale
	var body_w := w * 0.021 * scale

	Draw2D.ellipse(
		ci, base, Vector2(body_w * 0.75, body_w * 0.3), Color(0, 0, 0, 0.45)
	)
	var outfit: Color = Palette.OUTFIT[index % Palette.OUTFIT.size()]
	var tilt := sin(t * 3.1 + index) * body_w * 0.35
	# Schultern breiter als die Huefte - von oben sieht man vor allem die.
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - body_w * 0.34, base.y - bob),
		Vector2(base.x + body_w * 0.34, base.y - bob),
		Vector2(base.x + body_w * 0.5 + tilt, base.y - body_h - bob),
		Vector2(base.x - body_w * 0.5 + tilt, base.y - body_h - bob),
	]), Draw2D.shade(outfit, -0.28))
	# Der Lichtsaum auf den Schultern - sonst verschwinden alle im Dunkeln.
	ci.draw_line(
		Vector2(base.x - body_w * 0.5 + tilt, base.y - body_h - bob),
		Vector2(base.x + body_w * 0.5 + tilt, base.y - body_h - bob),
		Palette.with_alpha(Palette.WHITE, 0.16), maxf(1.0, body_w * 0.14), true
	)
	ci.draw_circle(
		Vector2(base.x + tilt * 1.3, base.y - body_h - bob - body_w * 0.42),
		body_w * 0.36, Draw2D.shade(Palette.SKIN[index % Palette.SKIN.size()], -0.2)
	)
	# Arme oben, wenn der Takt es hergibt
	if index % 3 == 0:
		var hand := Vector2(base.x + tilt * 2.2, base.y - body_h * 1.75 - bob)
		ci.draw_line(
			Vector2(base.x + tilt, base.y - body_h * 0.95 - bob), hand,
			Draw2D.shade(outfit, -0.15), maxf(1.5, body_w * 0.2), true
		)

## Die Bar an der linken Wand: Tresen, Flaschenregal, Hocker, Barkeeper.
static func _draw_bar(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["bar"]
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Flaschenregal an der Wand hinter dem Tresen: eine schraege Platte
	# entlang der linken Wand, darauf die Flaschen im Gegenlicht.
	var shelf_back := project(w, h, float(area["x"]) - 0.015, float(area["y"]))
	var shelf_front := project(w, h, float(area["x"]) - 0.015, float(area["y"]) + float(area["h"]))
	var shelf_h := h * 0.05
	# Hoechstens drei Bretter - hoeher waere die Wand im Bild zu Ende.
	var boards := mini(3, 2 + int(levels.get("bar", 0)))

	# Dunkle Rueckwand hinter den Brettern, damit die Flaschen stehen und
	# nicht schweben.
	var panel_rise := lift * 1.1 + boards * shelf_h
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(shelf_back.x, shelf_back.y - panel_rise),
		Vector2(shelf_front.x, shelf_front.y - panel_rise),
		Vector2(shelf_front.x - w * 0.035, shelf_front.y - lift * 0.6),
		Vector2(shelf_back.x - w * 0.035, shelf_back.y - lift * 0.6),
	]), Color("101319"))

	for level in boards:
		var rise := lift * 1.1 + level * shelf_h
		var b0 := Vector2(shelf_back.x, shelf_back.y - rise)
		var b1 := Vector2(shelf_front.x, shelf_front.y - rise)
		# Das Brett: eine schmale Platte, aus diesem Blickwinkel als Band.
		ci.draw_colored_polygon(PackedVector2Array([
			b0, b1,
			Vector2(b1.x - w * 0.035, b1.y + 9.0), Vector2(b0.x - w * 0.035, b0.y + 9.0),
		]), WOOD_DARK)
		ci.draw_line(b0, b1, Palette.with_alpha(Palette.AMBER, 0.35), 1.5, true)
		for b in 7:
			var f := 0.06 + b * 0.14
			var p := b0.lerp(b1, f)
			var s := depth_scale(float(area["y"]) + float(area["h"]) * f)
			ci.draw_rect(
				Rect2(p.x - w * 0.026, p.y - shelf_h * 0.55, 7.0 * s, shelf_h * 0.55),
				Draw2D.shade(Palette.AMBER if b % 2 == 0 else Palette.GREEN, -0.2)
			)
		Effects.glow(
			fx, (b0.x + b1.x) * 0.5 - w * 0.012, (b0.y + b1.y) * 0.5, w * 0.12,
			Palette.AMBER, 0.07
		)

	# Tresen als Block: Vorderkante, rechte Seite, Platte
	ci.draw_colored_polygon(
		PackedVector2Array([quad[3], quad[2], top[2], top[3]]), Draw2D.shade(WOOD_DARK, -0.2)
	)
	ci.draw_colored_polygon(
		PackedVector2Array([quad[1], quad[2], top[2], top[1]]), WOOD_DARK
	)
	ci.draw_polygon(top, PackedColorArray([
		Draw2D.shade(WOOD, 0.12), Draw2D.shade(WOOD, 0.12), WOOD, WOOD,
	]))
	# Lichtleiste unter der Platte
	ci.draw_line(top[3], top[2], Palette.with_alpha(Palette.AMBER, 0.5), 2.0, true)
	Effects.glow(
		fx, (top[2].x + top[3].x) * 0.5, (top[2].y + top[3].y) * 0.5, w * 0.2,
		Palette.AMBER, 0.09 + sin(t * 1.6) * 0.02
	)

	# Glaeser auf der Platte
	for i in 5:
		var p := project(
			w, h, float(area["x"]) + float(area["w"]) * 0.5,
			float(area["y"]) + float(area["h"]) * (0.12 + i * 0.19)
		)
		var s := depth_scale(float(area["y"]) + float(area["h"]) * (0.12 + i * 0.19))
		ci.draw_rect(
			Rect2(p.x - 3.0 * s, p.y - lift - 12.0 * s, 6.0 * s, 12.0 * s),
			Palette.with_alpha(Palette.WHITE, 0.35)
		)

	# Barkeeper hinter dem Tresen, Gaeste davor
	_draw_dancer(
		ci, w, h, float(area["x"]) + 0.005,
		float(area["y"]) + float(area["h"]) * 0.4, t * 0.4, 7
	)
	for i in 3:
		var gy := float(area["y"]) + float(area["h"]) * (0.2 + i * 0.3)
		_draw_dancer(
			ci, w, h, float(area["x"]) + float(area["w"]) + 0.035, gy, t * 0.5 + i, i + 2
		)

## Booths an der rechten Wand: Tisch, Bank, Gaeste. Ab VIP-Ausbau mit Samt.
static func _draw_booths(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["booths"]
	var vip := int(levels.get("vip", 0))
	var count := 3 + (1 if vip > 0 else 0)
	var seat: Color = Color("5a2233") if vip > 0 else Color("2a3140")

	for i in count:
		var y0 := float(area["y"]) + float(area["h"]) * (float(i) / count) + 0.01
		var cell := {
			"x": float(area["x"]), "y": y0,
			"w": float(area["w"]), "h": float(area["h"]) / count - 0.025,
		}
		var lift := float(area["lift"]) / CLUB_WORLD.y * h * depth_scale(y0)
		var quad := floor_quad(w, h, cell)
		var top := _lift(quad, lift * 0.35)

		# Bank an der Wand (die rechte Haelfte der Zelle)
		var back := PackedVector2Array([
			quad[1], quad[2], Vector2(quad[2].x, quad[2].y - lift),
			Vector2(quad[1].x, quad[1].y - lift),
		])
		ci.draw_colored_polygon(back, Draw2D.shade(seat, -0.35))
		ci.draw_line(back[3], back[2], Palette.with_alpha(Palette.WHITE, 0.08), 1.0, true)

		# Sitzflaeche
		ci.draw_polygon(top, PackedColorArray([
			seat, seat, Draw2D.shade(seat, -0.25), Draw2D.shade(seat, -0.25),
		]))

		# Tisch mit Kerze
		var tp := project(
			w, h, float(area["x"]) - 0.03, y0 + float(cell["h"]) * 0.5
		)
		var s := depth_scale(y0 + float(cell["h"]) * 0.5)
		Draw2D.ellipse(ci, tp, Vector2(w * 0.022 * s, h * 0.012 * s), Color(0, 0, 0, 0.4))
		Draw2D.ellipse(
			ci, Vector2(tp.x, tp.y - h * 0.026 * s), Vector2(w * 0.022 * s, h * 0.011 * s),
			Color("2f2a24")
		)
		ci.draw_rect(
			Rect2(tp.x - 2.0 * s, tp.y - h * 0.026 * s, 4.0 * s, h * 0.026 * s), METAL_DARK
		)
		var flame := Vector2(tp.x, tp.y - h * 0.042 * s)
		ci.draw_circle(flame, 2.4 * s, Palette.with_alpha(Palette.AMBER, 0.9))
		Effects.glow(
			fx, flame.x, flame.y, w * 0.06, Palette.AMBER, 0.1 + sin(t * 3.0 + i) * 0.03
		)

		# Zwei Gaeste je Booth
		for g in 2:
			_draw_dancer(
				ci, w, h, float(area["x"]) + 0.02 + g * 0.05,
				y0 + float(cell["h"]) * (0.3 + g * 0.4), t * 0.3 + i * 2.0 + g, i * 2 + g + 1
			)

## Toiletten vorne rechts: zwei Tueren mit Schild, davor wartet immer jemand.
static func _draw_toilets(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var area: Dictionary = AREAS["toilets"]
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Trennwand mit den beiden Tueren, leicht angeschnitten wie die Bar
	ci.draw_colored_polygon(
		PackedVector2Array([quad[0], quad[1], top[1], top[0]]), Color("171b23")
	)
	ci.draw_colored_polygon(
		PackedVector2Array([quad[0], quad[3], top[3], top[0]]), Color("11151c")
	)
	ci.draw_line(top[0], top[1], Color(1, 1, 1, 0.06), 1.0, true)

	var wall_left := top[0]
	var wall_right := top[1]
	for i in 2:
		var f := 0.2 + i * 0.42
		var dx := lerpf(wall_left.x, wall_right.x, f)
		var dy := lerpf(wall_left.y, wall_right.y, f)
		var dw := absf(wall_right.x - wall_left.x) * 0.3
		var dh := lift * 0.78
		Draw2D.fill_round_rect(
			ci, Rect2(dx - dw * 0.5, dy + lift * 0.2, dw, dh), 2.0, Color("242b38")
		)
		ci.draw_rect(
			Rect2(dx - dw * 0.5, dy + lift * 0.2, dw, dh), Color(1, 1, 1, 0.06), false, 1.0
		)
		# Schild: Kopf und Schultern als Piktogramm
		var sy := dy + lift * 0.34
		ci.draw_circle(Vector2(dx, sy), 3.0, Palette.with_alpha(Palette.CYAN, 0.75))
		ci.draw_rect(
			Rect2(dx - 4.0, sy + 4.0, 8.0, 8.0), Palette.with_alpha(Palette.CYAN, 0.55)
		)
		if i == 1:
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(dx - 7.0, sy + 12.0), Vector2(dx + 7.0, sy + 12.0),
				Vector2(dx + 4.0, sy + 4.0), Vector2(dx - 4.0, sy + 4.0),
			]), Palette.with_alpha(Palette.CYAN, 0.55))
		# Klinke
		ci.draw_circle(
			Vector2(dx + dw * 0.32, dy + lift * 0.6), 2.5, Palette.with_alpha(Palette.WHITE, 0.5)
		)

	# Leuchtschild ueber den Tueren
	var sign_mid := Vector2((wall_left.x + wall_right.x) * 0.5, (wall_left.y + wall_right.y) * 0.5)
	Draw2D.fill_round_rect(
		ci, Rect2(sign_mid.x - w * 0.035, sign_mid.y - h * 0.006, w * 0.07, h * 0.028),
		2.0, Color("0e1218")
	)
	Draw2D.text(
		ci, Fonts.mono_spaced(4.0), Vector2(sign_mid.x, sign_mid.y + h * 0.017), "WC", 13,
		Palette.with_alpha(Palette.CYAN, 0.85), Draw2D.Align.CENTER
	)
	Effects.glow(fx, sign_mid.x, sign_mid.y + h * 0.01, w * 0.14, Palette.CYAN, 0.09)

	# Die Schlange davor
	for i in 2:
		_draw_dancer(
			ci, w, h, float(area["x"]) - 0.045 - i * 0.04,
			float(area["y"]) + 0.06 + i * 0.05, t * 0.25 + i * 3.0, i + 11
		)

## Der Eingang - hier beginnt die Schicht. Doppeltuer, Lichtspalt, Kordel.
static func _draw_entrance(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var area: Dictionary = AREAS["entrance"]
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Der Windfang steht vorne im Bild: seine Rueckseite zeigt zum Raum.
	var back_left := quad[0]
	var back_right := quad[1]
	var head_left := Vector2(back_left.x, back_left.y - lift)
	var head_right := Vector2(back_right.x, back_right.y - lift)

	ci.draw_colored_polygon(
		PackedVector2Array([back_left, back_right, head_right, head_left]), Color("0f131a")
	)
	# Rahmen
	Draw2D.stroke_path(ci, PackedVector2Array([
		back_left, head_left, head_right, back_right,
	]), Palette.with_alpha(Palette.RED, 0.5), 3.0)

	# Zwei Tuerfluegel, dazwischen der Spalt mit dem Nachtlicht
	var span := head_right.x - head_left.x
	for i in 2:
		var dx := head_left.x + span * (0.08 + i * 0.47)
		var dw := span * 0.37
		var rect := Rect2(dx, head_left.y + lift * 0.1, dw, lift * 0.86)
		Draw2D.fill_round_rect(ci, rect, 2.0, Color("1a1f28"))
		ci.draw_rect(rect, Color(1, 1, 1, 0.05), false, 1.0)
		ci.draw_rect(
			Rect2(rect.position.x + dw * (0.82 if i == 0 else 0.1), rect.position.y + lift * 0.42,
				dw * 0.08, lift * 0.16),
			Palette.with_alpha(Palette.WHITE, 0.4)
		)

	# Der Spalt: draussen ist Nacht, drinnen brennt das Tuerlicht
	var gap_x := head_left.x + span * 0.47
	Draw2D.vgradient_rect(
		fx, Rect2(gap_x, head_left.y + lift * 0.1, span * 0.06, lift * 0.86),
		Palette.with_alpha(Palette.CYAN, 0.35), Palette.with_alpha(Palette.CYAN, 0.05)
	)

	# Leuchtschild ueber der Tuer
	Draw2D.text(
		ci, Fonts.mono_spaced(4.0), Vector2((head_left.x + head_right.x) * 0.5,
			head_left.y - h * 0.012),
		"EINGANG", 15, Palette.with_alpha(Palette.RED, 0.7 + sin(t * 2.6) * 0.25),
		Draw2D.Align.CENTER
	)
	Effects.glow(
		fx, (head_left.x + head_right.x) * 0.5, head_left.y - h * 0.008, w * 0.2,
		Palette.RED, 0.12 + sin(t * 2.6) * 0.04
	)

	# Absperrkordel links und rechts der Tuer
	for side: float in [-1.0, 1.0]:
		var p0 := project(
			w, h, 0.5 + side * 0.16, float(area["y"]) - 0.02
		)
		var p1 := project(w, h, 0.5 + side * 0.09, float(area["y"]) - 0.02)
		ci.draw_rect(Rect2(p0.x - 3.0, p0.y - h * 0.06, 6.0, h * 0.06), METAL)
		ci.draw_circle(Vector2(p0.x, p0.y - h * 0.062), 5.0, Draw2D.shade(METAL, 0.25))
		Draw2D.stroke_path(ci, Draw2D.quad_curve(
			Vector2(p0.x, p0.y - h * 0.055),
			Vector2((p0.x + p1.x) * 0.5, p0.y - h * 0.035),
			Vector2(p1.x, p1.y - h * 0.055)
		), Palette.with_alpha(Palette.RED, 0.75), 4.0)

## Man selbst steht neben dem Eingang und schaut in den Laden - der Beweis,
## dass man nach der Tuer im eigenen Club steht.
static func _draw_owner(ci: CanvasItem, w: float, h: float, t: float, character: Variant) -> void:
	if character == null:
		return
	var base := project(w, h, 0.255, 0.90)
	Draw2D.ellipse(ci, base, Vector2(w * 0.024, h * 0.01), Color(0, 0, 0, 0.45))
	Figure.draw(ci, {
		"x": base.x,
		"y": base.y,
		"h": h * 0.21,
		"look": CharacterSys.character_look(character),
		"personality": "polite",
		"accent": CharacterSys.accent_color(character),
		"t": t,
	})

## Nebel und Vignette - der Raum bekommt Tiefe.
static func _draw_haze(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	for i in 26:
		var f := _hash01(i * 5.3)
		var g := _hash01(i * 2.1 + 9.0)
		var x := fmod(f * w + t * (8.0 + g * 14.0), w)
		var y := ROOM_TOP * h + g * h * 0.6 + sin(t * 0.4 + i) * 6.0
		fx.draw_circle(Vector2(x, y), 26.0 + f * 40.0, Color(0.16, 0.22, 0.32, 0.02))
	Effects.vignette(ci, w, h, 0.55)

## Kleiner, stabiler Zufall - dieselbe Zahl bei jedem Bild.
static func _hash01(seed_value: float) -> float:
	var v := sin(seed_value * 12.9898) * 43758.5453
	return v - floorf(v)
