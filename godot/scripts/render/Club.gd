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
##
## ## Der Ausbau ist das Bild
##
## Ohne Ausbau ist das hier ein Kellerloch: nackter Beton mit Flecken, zwei
## Gluehbirnen an einem durchhaengenden Kabel, eine Bohle auf zwei Boecken
## als Bar, Plastikstuehle statt Booths, eine klemmende Tuer. Jede gekaufte
## Stufe baut sichtbar daran weiter - Traverse und bewegte Scheinwerfer,
## leuchtende Bodenplatten, Boxenstapel, Spiegelkugel, Laser, Samt und Gold.
## `levels` (aus ClubScreen.levels_for) ist die einzige Quelle dafuer; jede
## Zeichenfunktion liest daraus, wie gut ihr Teil des Ladens gerade ist.
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
const WALL_TOP := Color("0d1017")
const WALL_BOTTOM := Color("181d27")
const FLOOR_FAR := Color("161a23")
const FLOOR_NEAR := Color("0d1016")
const WOOD := Color("4b3626")
const WOOD_DARK := Color("2c2016")
const METAL := Color("3c4453")
const METAL_DARK := Color("222932")
const TILE_DARK := Color("1c2230")
const RAW_CONCRETE := Color("20242c")
const RUST := Color("6b4026")

## Die Hausfarbe des Lichts waechst mit der Club-Stufe mit: unten kaltes
## Blau wie eine Notbeleuchtung, oben die volle Neonpalette.
const LIGHT_SETS := [
	[Color("2f6f8f"), Color("3c6f7a")],
	[Color("39d7ff"), Color("8b5cff"), Color("ffb638")],
	[Color("39d7ff"), Color("8b5cff"), Color("ff2f3c"), Color("ffb638")],
	[Color("39d7ff"), Color("8b5cff"), Color("ff2f3c"), Color("ffb638"), Color("4ce08a")],
]

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

# ---------------- Ausbau lesen ----------------

## Schriftgrad relativ zur Bildbreite - 1280 Pixel sind der Normalfall.
static func _pt(w: float, size_at_full: float) -> int:
	return maxi(6, int(round(size_at_full * w / CLUB_WORLD.x)))

static func _lv(levels: Dictionary, key: String) -> int:
	return int(levels.get(key, 0))

## Die Farben, mit denen der Laden heute leuchtet.
static func _light_colors(levels: Dictionary) -> Array:
	return LIGHT_SETS[clampi(_lv(levels, "lights"), 0, LIGHT_SETS.size() - 1)]

## Wie weit ist der Laden insgesamt? 0 = Kellerloch, 1 = Techno-Tempel.
## Faerbt alles, was nicht an einem einzelnen Ausbau haengt: Sauberkeit der
## Waende, Andrang, Grundhelligkeit.
static func _polish(levels: Dictionary) -> float:
	var sum := float(
		_lv(levels, "lights") + _lv(levels, "sound") + _lv(levels, "floor")
		+ _lv(levels, "bar") + _lv(levels, "vip") + _lv(levels, "door")
		+ _lv(levels, "comfort")
	)
	return clampf(sum / 16.0, 0.0, 1.0)

# ---------------- Bild ----------------

## `levels` kommt aus GameState (Ausbaustufen) und baut den Raum:
## { floor, bar, vip, lights, sound, door, comfort, backstage, cameras,
##   team, tier, artist, character }.
static func draw_club(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	_draw_shell(ci, fx, w, h, t, levels)
	_draw_stage(ci, fx, w, h, t, levels)
	_draw_mirrorball(ci, fx, w, h, t, levels)
	_draw_beams(fx, w, h, t, levels)
	_draw_dancefloor(ci, fx, w, h, t, levels)
	_draw_bar(ci, fx, w, h, t, levels)
	_draw_booths(ci, fx, w, h, t, levels)
	_draw_toilets(ci, fx, w, h, t, levels)
	_draw_entrance(ci, fx, w, h, t, levels)
	_draw_staff(ci, w, h, t, levels)
	_draw_owner(ci, w, h, t, levels.get("character", null))
	_draw_haze(ci, fx, w, h, t, levels)

## Waende, Boden, Deckentraverse - der leere Raum.
static func _draw_shell(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var polish := _polish(levels)
	var lights := _lv(levels, "lights")
	var colors := _light_colors(levels)

	# Deckend, egal was dahinter liegt: waehrend der Schicht steht die Nacht
	# hinter diesem Bildschirm.
	ci.draw_rect(Rect2(0, 0, w, h), Color("07090d"))
	# Je weniger gebaut ist, desto weniger Licht faellt an die Rueckwand.
	var lit := 0.35 + polish * 0.65
	Draw2D.vgradient_rect(
		ci, Rect2(0, 0, w, ROOM_TOP * h + 2.0),
		Draw2D.shade(WALL_TOP, -0.45 + lit * 0.45), Draw2D.shade(WALL_BOTTOM, -0.55 + lit * 0.55)
	)

	# Seitenwaende: die Keile links und rechts neben dem Grundriss. Sie
	# laufen nach hinten zusammen - daher der Zwei-Drittel-Blick.
	var room := floor_quad(w, h, {"x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0})
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(0, ROOM_TOP * h), room[0], room[3], Vector2(0, h),
	]), Color("0a0d13"))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(w, ROOM_TOP * h), Vector2(w, h), room[2], room[1],
	]), Color("0a0d13"))

	# Boden: der Grundriss als Trapez. Je besser ausgebaut, desto satter.
	var near: Color = Draw2D.mix(Color("090b0f"), Color("11161f"), polish)
	var far: Color = Draw2D.mix(Color("0e1117"), FLOOR_FAR, polish)
	ci.draw_polygon(room, PackedColorArray([far, far, near, near]))

	# Betonfugen der Rueckwand
	var joint := Color(1, 1, 1, 0.035)
	var y := 26.5
	while y < ROOM_TOP * h:
		ci.draw_line(Vector2(0, y), Vector2(w, y), joint, 1.0, true)
		y += 34.0

	_draw_wall_wear(ci, w, h, polish)
	_draw_wall_neon(ci, fx, w, h, t, levels, colors)
	_draw_cameras(ci, fx, w, h, t, levels)
	_draw_rig(ci, w, h, t, lights, colors)

## Was der Beton abbekommen hat: Flecken, Risse, ein Wasserfleck, verklebte
## Kabel. Verschwindet nicht mit dem Ausbau, wird aber deutlich leiser -
## man putzt, man reisst nicht ab.
static func _draw_wall_wear(ci: CanvasItem, w: float, h: float, polish: float) -> void:
	var grime := (1.0 - polish * 0.75)
	var wall_h := ROOM_TOP * h

	# Grosse Feuchteflecken, unregelmaessig wie echte Raender
	for i in 5:
		var f := _hash01(i * 4.1)
		var g := _hash01(i * 7.7 + 2.0)
		var cx := f * w
		var cy := wall_h * (0.2 + g * 0.6)
		Draw2D.ellipse(
			ci, Vector2(cx, cy), Vector2(w * (0.03 + g * 0.05), wall_h * (0.1 + f * 0.2)),
			Color(0.03, 0.035, 0.04, 0.3 * grime)
		)

	# Risse: kurze Zickzacklinien, immer an derselben Stelle
	for i in 4:
		var x := w * (0.1 + _hash01(i * 9.3) * 0.8)
		var path := PackedVector2Array([Vector2(x, wall_h * 0.15)])
		for s in 5:
			x += (_hash01(i * 3.0 + s) - 0.5) * w * 0.02
			path.append(Vector2(x, wall_h * (0.15 + (s + 1) * 0.13)))
		ci.draw_polyline(path, Color(0, 0, 0, 0.35 * grime), 1.0, true)

	# Verklebte Kabelstraenge laufen die Rueckwand entlang
	for i in 2:
		var cy := wall_h * (0.52 + i * 0.16)
		ci.draw_line(
			Vector2(w * 0.02, cy), Vector2(w * 0.98, cy + (8.0 if i == 0 else -5.0)),
			Color(0.02, 0.02, 0.03, 0.6), 2.0, true
		)

	# Ein paar abgerissene Plakatecken - das hier ist ein Keller, kein Foyer
	for i in 3:
		var px := w * (0.08 + _hash01(i * 11.0) * 0.8)
		var py := wall_h * 0.3
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(px, py), Vector2(px + w * 0.035, py - 4.0),
			Vector2(px + w * 0.03, py + h * 0.05), Vector2(px - 3.0, py + h * 0.045),
		]), Color(0.35, 0.33, 0.3, 0.05 + 0.04 * grime))

## Leuchtstreifen an den Seitenwaenden - gibt es erst ab der ersten
## Lichtanlage, und ab Stufe 2 laufen sie als Lauflicht.
static func _draw_wall_neon(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float,
	levels: Dictionary, colors: Array
) -> void:
	var lights := _lv(levels, "lights")
	if lights <= 0:
		return
	for side in 2:
		var sign_x := -1.0 if side == 0 else 1.0
		var color: Color = colors[side % colors.size()]
		# Der Streifen folgt der Fluchtlinie der Seitenwand.
		var back := project(w, h, 0.5 + sign_x * 0.5, 0.02)
		var front := project(w, h, 0.5 + sign_x * 0.5, 0.98)
		var rise := h * 0.12
		var pulse := 0.5 + 0.5 * sin(t * 1.6 + side * PI)
		ci.draw_line(
			Vector2(back.x, back.y - rise * 0.6), Vector2(front.x, front.y - rise),
			Palette.with_alpha(color, 0.35 + lights * 0.12), 2.0 + lights, true
		)
		Effects.glow(
			fx, (back.x + front.x) * 0.5, (back.y + front.y) * 0.5 - rise * 0.8,
			w * 0.14, color, 0.05 + lights * 0.03 + pulse * 0.02
		)
		# Ab Stufe 2 laeuft ein helles Segment die Wand entlang.
		if lights >= 2:
			var f := fmod(t * 0.35 + side * 0.5, 1.0)
			var a := Vector2(back.x, back.y - rise * 0.6).lerp(
				Vector2(front.x, front.y - rise), f
			)
			var b := Vector2(back.x, back.y - rise * 0.6).lerp(
				Vector2(front.x, front.y - rise), minf(1.0, f + 0.12)
			)
			fx.draw_line(a, b, Palette.with_alpha(color, 0.6), 4.0, true)

## Sicherheitskameras in den Ecken - eine Stufe, eine Kamera mehr.
static func _draw_cameras(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var cams := _lv(levels, "cameras")
	if cams <= 0:
		return
	var spots := [Vector2(w * 0.07, ROOM_TOP * h * 0.45), Vector2(w * 0.93, ROOM_TOP * h * 0.45)]
	for i in mini(cams, spots.size()):
		var p: Vector2 = spots[i]
		var dir := -1.0 if i == 0 else 1.0
		ci.draw_rect(Rect2(p.x - 3.0, p.y - 10.0, 6.0, 10.0), METAL_DARK)
		Draw2D.fill_round_rect(
			ci, Rect2(p.x - 11.0 * dir, p.y, 22.0, 9.0), 2.0, Color("2a313d")
		)
		ci.draw_circle(Vector2(p.x + 9.0 * dir, p.y + 4.5), 2.5, Color("05070a"))
		# Aufnahme-LED blinkt
		var on := sin(t * 2.4 + i) > 0.0
		ci.draw_circle(
			Vector2(p.x - 6.0 * dir, p.y + 3.0), 1.6,
			Palette.with_alpha(Palette.RED, 0.9 if on else 0.2)
		)
		if on:
			Effects.glow(fx, p.x - 6.0 * dir, p.y + 3.0, 22.0, Palette.RED, 0.12)

## Was unter der Decke haengt: ohne Lichtanlage nur ein durchhaengendes
## Kabel mit zwei Gluehbirnen, danach eine echte Traverse mit Scheinwerfern.
static func _draw_rig(
	ci: CanvasItem, w: float, h: float, t: float, lights: int, colors: Array
) -> void:
	var truss_y := ROOM_TOP * h * 0.34

	if lights <= 0:
		# Kabel mit Durchhang, zwei nackte Birnen. Eine davon flackert.
		var path := Draw2D.quad_curve(
			Vector2(w * 0.05, truss_y), Vector2(w * 0.5, truss_y + 26.0),
			Vector2(w * 0.95, truss_y + 4.0)
		)
		ci.draw_polyline(path, Color(0.03, 0.03, 0.04, 0.9), 2.0, true)
		for i in 2:
			var p: Vector2 = path[int(path.size() * (0.3 + i * 0.4))]
			ci.draw_line(p, p + Vector2(0, 16.0), Color(0.05, 0.05, 0.06, 0.9), 1.0, true)
			var flick := 1.0 if i == 0 or sin(t * 13.0) < 0.8 else 0.25
			ci.draw_circle(p + Vector2(0, 21.0), 5.0, Palette.with_alpha(Palette.AMBER, 0.75 * flick))
		return

	# Traverse: zwei Gurte mit Diagonalen, darunter die Scheinwerfer.
	ci.draw_rect(Rect2(w * 0.06, truss_y, w * 0.88, 5.0), METAL_DARK)
	ci.draw_rect(Rect2(w * 0.06, truss_y + 13.0, w * 0.88, 5.0), METAL_DARK)
	ci.draw_rect(Rect2(w * 0.06, truss_y, w * 0.88, 1.5), Color(1, 1, 1, 0.1))
	var x := w * 0.08
	while x < w * 0.94:
		ci.draw_line(
			Vector2(x, truss_y + 16.0), Vector2(x + 24.0, truss_y + 2.0),
			Color(1, 1, 1, 0.06), 2.0, true
		)
		ci.draw_line(
			Vector2(x, truss_y + 2.0), Vector2(x + 24.0, truss_y + 16.0),
			Color(1, 1, 1, 0.04), 2.0, true
		)
		x += 24.0

	# Die Koepfe haengen unter der Traverse und schwenken mit.
	var count := 4 + lights * 2
	for i in count:
		var hx := w * (0.14 + float(i) / maxf(1.0, count - 1.0) * 0.72)
		var color: Color = colors[i % colors.size()]
		var tilt := sin(t * (0.7 + i * 0.13) + i) * 5.0
		ci.draw_rect(Rect2(hx - 5.0, truss_y + 18.0, 10.0, 7.0), Color("1a1f28"))
		Draw2D.fill_round_rect(
			ci, Rect2(hx - 6.0 + tilt, truss_y + 24.0, 12.0, 11.0), 2.0, Color("232a36")
		)
		ci.draw_circle(
			Vector2(hx + tilt, truss_y + 34.0), 3.0, Palette.with_alpha(color, 0.9)
		)

## Buehne mit DJ-Pult, Boxen und der Wand dahinter.
static func _draw_stage(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["stage"]
	var sound := _lv(levels, "sound")
	var lights := _lv(levels, "lights")
	var backstage := _lv(levels, "backstage")
	var colors := _light_colors(levels)
	var lift := float(area["lift"]) / CLUB_WORLD.y * h * (0.4 if backstage <= 0 else 1.0)
	var deck: Dictionary = area
	if backstage <= 0:
		deck = {
			"x": float(area["x"]) + float(area["w"]) * 0.24, "y": float(area["y"]) + 0.03,
			"w": float(area["w"]) * 0.52, "h": float(area["h"]) - 0.04,
		}
	var quad := floor_quad(w, h, deck)
	var top := _lift(quad, lift)

	# Podest: ohne Backstage nur ein paar zusammengeschobene Paletten.
	ci.draw_colored_polygon(
		PackedVector2Array([quad[3], quad[2], top[2], top[3]]),
		Color("14181f") if backstage > 0 else Color("15100b")
	)
	ci.draw_polygon(top, PackedColorArray([
		Color("232a36"), Color("232a36"), Color("1a2028"), Color("1a2028"),
	]) if backstage > 0 else PackedColorArray([
		Color("1b150e"), Color("1b150e"), Color("140f09"), Color("140f09"),
	]))
	if backstage <= 0:
		# Palettenfugen: man sieht, dass das kein Podest ist.
		for i in 5:
			var f := (i + 1) / 6.0
			ci.draw_line(
				top[0].lerp(top[1], f), top[3].lerp(top[2], f), Color(0, 0, 0, 0.35), 1.0, true
			)
	else:
		ci.draw_line(top[3], top[2], Palette.with_alpha(colors[0], 0.45), 2.0, true)
		Effects.glow(
			fx, (top[2].x + top[3].x) * 0.5, (top[2].y + top[3].y) * 0.5,
			w * 0.3, colors[0], 0.05
		)

	# Boxen links und rechts. Stufe 0: zwei Monitore auf Bierkisten.
	for side: float in [0.0, 1.0]:
		var bx := lerpf(float(area["x"]) - 0.045, float(area["x"]) + float(area["w"]) + 0.045, side)
		var base := project(w, h, bx, float(area["y"]) + float(area["h"]) * 0.5)
		var bw := w * (0.034 + sound * 0.008)
		var bh := h * (0.07 + sound * 0.035)
		var rect := Rect2(base.x - bw * 0.5, base.y - bh, bw, bh)

		if sound <= 0:
			# Bierkiste als Ständer, darauf ein kleiner Lautsprecher.
			ci.draw_rect(Rect2(rect.position.x, rect.position.y + bh * 0.6, bw, bh * 0.4), RUST)
			Draw2D.fill_round_rect(
				ci, Rect2(rect.position.x, rect.position.y, bw, bh * 0.6), 2.0, Color("191c22")
			)
			ci.draw_circle(
				Vector2(rect.position.x + bw * 0.5, rect.position.y + bh * 0.3),
				bw * 0.26, Color("0a0c10")
			)
			continue

		Draw2D.fill_round_rect(ci, rect, 3.0, Color("14171d"))
		ci.draw_rect(rect, Color(1, 1, 1, 0.05), false, 1.0)
		for i in 2 + sound:
			var cy := rect.position.y + bh * (0.18 + i * 0.2)
			var r := bw * (0.32 - i * 0.03)
			ci.draw_circle(Vector2(rect.position.x + bw * 0.5, cy), r, Color("0a0c10"))
			Draw2D.ellipse_outline(
				ci, Vector2(rect.position.x + bw * 0.5, cy), Vector2(r, r),
				Color(1, 1, 1, 0.06), 1.0
			)
		# Bass driftet sichtbar: ein leichter Puls auf der Membran
		var pulse := 0.5 + sin(t * 6.4 + side * 1.7) * 0.5
		Effects.glow(
			fx, rect.position.x + bw * 0.5, rect.position.y + bh * 0.3, bw * 1.8,
			colors[0], 0.04 + pulse * 0.04 * sound
		)

	# DJ-Pult in der Mitte des Podests
	var mid := project(w, h, 0.5, float(area["y"]) + float(area["h"]) * 0.62)
	var dw := w * (0.11 + backstage * 0.02)
	var dh := h * 0.055
	var desk := Rect2(mid.x - dw * 0.5, mid.y - lift - dh * 0.35, dw, dh)

	if backstage <= 0:
		# Klapptisch mit Decke drueber: das Pult ist geliehen.
		Draw2D.fill_round_rect(ci, desk, 1.0, Color("241c14"))
		ci.draw_rect(Rect2(desk.position.x, desk.position.y, desk.size.x, 3.0), Color("3a2e21"))
		for leg: float in [0.1, 0.86]:
			ci.draw_rect(Rect2(
				desk.position.x + desk.size.x * leg, desk.position.y + dh, 3.0, dh * 0.7
			), METAL_DARK)
	else:
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
		var fader_x := desk.position.x + desk.size.x * (0.42 + i * 0.035)
		ci.draw_rect(
			Rect2(fader_x, desk.position.y + dh * 0.16, 2.0, dh * 0.3), Color(1, 1, 1, 0.18)
		)

	# Der DJ dahinter - Kopf und Schultern ueber dem Pult
	var djx := mid.x
	var djy := desk.position.y - h * 0.012
	var sway := sin(t * 2.2) * w * 0.006
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(djx - dw * 0.18 + sway, djy), Vector2(djx + dw * 0.18 + sway, djy),
		Vector2(djx + dw * 0.14 + sway, djy - h * 0.05),
		Vector2(djx - dw * 0.14 + sway, djy - h * 0.05),
	]), Color("11151c"))
	ci.draw_circle(Vector2(djx + sway, djy - h * 0.068), h * 0.024, Color("2a2018"))
	# Kopfhoerer
	Draw2D.stroke_path(ci, Draw2D.ellipse_points(
		Vector2(djx + sway, djy - h * 0.068), Vector2(h * 0.03, h * 0.03), PI, TAU
	), Palette.with_alpha(colors[0], 0.6), 3.0)

	# Der Schriftzug an der Rueckwand: ohne Licht nur gepinselt, mit Licht
	# eine Roehre mit Schein - und ab Stufe 2 flackert sie wie eine echte.
	var name_text: String = String(levels.get("artist", "NULLWERK"))
	var name_y := ROOM_TOP * h * 0.72
	if lights <= 0:
		Draw2D.text(
			ci, Fonts.mono_spaced(6.0), Vector2(w * 0.5, name_y), name_text, _pt(w, 20.0),
			Color(0.62, 0.6, 0.56, 0.3), Draw2D.Align.CENTER
		)
		return
	var flick := 1.0
	if lights >= 2 and sin(t * 9.0) > 0.93:
		flick = 0.45
	var neon: Color = Palette.RED if lights < 3 else colors[1]
	var size_px := _pt(w, 22.0 + lights * 2.0)
	var font := Fonts.display_spaced(6.0) if lights >= 2 else Fonts.mono_spaced(6.0)
	var width := Draw2D.text_width(font, name_text, size_px)
	for spread: float in [5.0, 2.5]:
		for a in 6:
			var ang := float(a) / 6.0 * TAU
			fx.draw_string(
				font, Vector2(w * 0.5 - width * 0.5, name_y) + Vector2(cos(ang), sin(ang)) * spread,
				name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
				Palette.with_alpha(neon, 0.09 * flick)
			)
	fx.draw_string(
		font, Vector2(w * 0.5 - width * 0.5, name_y), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Palette.with_alpha(Color("ffe9ea"), 0.85 * flick)
	)
	Effects.glow(fx, w * 0.5, name_y - size_px * 0.3, w * 0.45, neon, 0.1 * flick)

## Spiegelkugel ueber der Tanzflaeche - erst ab der zweiten Lichtstufe.
static func _draw_mirrorball(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	if _lv(levels, "lights") < 2:
		return
	var area: Dictionary = AREAS["floor"]
	var anchor := project(w, h, 0.5, float(area["y"]) + float(area["h"]) * 0.35)
	var cy := ROOM_TOP * h + h * 0.045
	var r := h * 0.036

	# Aufhaengung
	ci.draw_line(
		Vector2(anchor.x, ROOM_TOP * h * 0.36), Vector2(anchor.x, cy - r),
		Color(0.06, 0.07, 0.08, 0.9), 1.5, true
	)
	# Kugel aus Facetten: Ringe von Vierecken, hell nach dunkel gedreht.
	ci.draw_circle(Vector2(anchor.x, cy), r, Color("20262f"))
	for row in 5:
		var ry := cy - r + (row + 0.5) * (r * 2.0 / 5.0)
		var rr := sqrt(maxf(0.0, r * r - (ry - cy) * (ry - cy)))
		for col in 8:
			var f := fmod(float(col) / 8.0 + t * 0.06, 1.0)
			var fx_x := anchor.x - rr + f * rr * 2.0
			var bright := 0.05 + 0.4 * pow(sin(f * PI), 3.0)
			ci.draw_rect(
				Rect2(fx_x - rr * 0.11, ry - r * 0.18, rr * 0.22, r * 0.36),
				Color(0.8, 0.9, 1.0, bright)
			)
	Effects.glow(fx, anchor.x, cy, r * 5.0, Palette.WHITE, 0.07)

	# Die Lichtpunkte, die sie in den Raum wirft.
	for i in 30:
		var ang := float(i) / 30.0 * TAU + t * 0.5
		var rad := 0.16 + _hash01(i * 3.3) * 0.34
		var px := 0.5 + cos(ang) * rad
		var py := float(area["y"]) + float(area["h"]) * (0.1 + _hash01(i * 7.1) * 0.9)
		var p := project(w, h, clampf(px, 0.02, 0.98), py)
		var s := depth_scale(py)
		fx.draw_circle(p, 2.4 * s, Color(0.75, 0.88, 1.0, 0.16 + 0.1 * sin(t * 2.0 + i)))

## Lichtkegel von der Traverse auf die Tanzflaeche - der Raum lebt vom Licht.
static func _draw_beams(fx: Variant, w: float, h: float, t: float, levels: Dictionary) -> void:
	var lights := _lv(levels, "lights")
	var colors := _light_colors(levels)
	var truss_y := ROOM_TOP * h * 0.36

	if lights <= 0:
		# Zwei matte Kegel von den Gluehbirnen, sonst nichts.
		for i in 2:
			var src_x := w * (0.35 + i * 0.3)
			var hit := project(w, h, 0.5 + (src_x / w - 0.5) * 1.2, 0.6)
			fx.draw_polygon(
				PackedVector2Array([
					Vector2(src_x - 4.0, truss_y + 20.0), Vector2(src_x + 4.0, truss_y + 20.0),
					Vector2(hit.x + w * 0.09, hit.y), Vector2(hit.x - w * 0.09, hit.y),
				]),
				PackedColorArray([
					Palette.with_alpha(Palette.AMBER, 0.06),
					Palette.with_alpha(Palette.AMBER, 0.06),
					Palette.with_alpha(Palette.AMBER, 0.0),
					Palette.with_alpha(Palette.AMBER, 0.0),
				])
			)
		return

	var count := 4 + lights
	for i in count:
		var src_x := w * (0.14 + float(i) / maxf(1.0, count - 1.0) * 0.72)
		var swing := sin(t * (0.7 + i * 0.13) + i) * w * 0.16
		var hit := project(w, h, 0.5 + (src_x / w - 0.5) * 1.25, 0.62)
		var color: Color = colors[i % colors.size()]
		var strength := 0.09 + (i % 2) * 0.02 + lights * 0.018
		var spread := w * (0.045 + lights * 0.007)
		fx.draw_polygon(
			PackedVector2Array([
				Vector2(src_x - 5.0, truss_y + 28.0), Vector2(src_x + 5.0, truss_y + 28.0),
				Vector2(hit.x + swing + spread, hit.y),
				Vector2(hit.x + swing - spread, hit.y),
			]),
			PackedColorArray([
				Palette.with_alpha(color, strength), Palette.with_alpha(color, strength),
				Palette.with_alpha(color, 0.0), Palette.with_alpha(color, 0.0),
			])
		)
		# Der Fleck, den der Kegel auf dem Boden macht.
		Effects.glow(fx, hit.x + swing, hit.y, spread * 2.2, color, strength * 0.4)
		fx.draw_circle(Vector2(src_x, truss_y + 32.0), 4.0, Palette.with_alpha(color, 0.7))

	# Volle Lichtshow: ein Laserfaecher ueber die Koepfe.
	if lights >= 3:
		var origin := Vector2(w * 0.5, ROOM_TOP * h * 0.5)
		for i in 9:
			var ang := PI * 0.5 + (float(i) / 8.0 - 0.5) * 1.5 + sin(t * 0.9) * 0.25
			var to := origin + Vector2(cos(ang), sin(ang)) * h * 0.55
			fx.draw_line(origin, to, Palette.with_alpha(Palette.GREEN, 0.09), 1.0, true)

## Tanzflaeche: leuchtende Platten und die Leute darauf.
static func _draw_dancefloor(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["floor"]
	var floor_level := _lv(levels, "floor")
	var lights := _lv(levels, "lights")
	var colors := _light_colors(levels)
	var cols := 6 + floor_level
	var rows := 5 + floor_level
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

			if floor_level <= 0:
				# Roher Estrich: Farbunterschiede, abgelaufene Stellen, Flecken.
				var wear := _hash01(col * 3.1 + row * 7.7)
				ci.draw_colored_polygon(
					quad, Draw2D.shade(Color("1a1e25"), -0.18 + wear * 0.22)
				)
				if wear > 0.86:
					var c := (quad[0] + quad[2]) * 0.5
					Draw2D.ellipse(
						ci, c, Vector2(w * 0.008, h * 0.0035), Color(0, 0, 0, 0.22)
					)
				ci.draw_polyline(
					PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
					Color(0, 0, 0, 0.18), 1.0, true
				)
				continue

			var wave := sin(t * 2.6 + col * 0.7 + row * 0.5) * 0.5 + 0.5
			var lit := (col + row) % 2 == 0
			# Immer nur zwei Farben auf einmal - ab Stufe 3 wechselt das Paar
			# langsam durch, damit die Flaeche laeuft statt bunt zu sein.
			var k: int = (int(t * 0.5) % colors.size()) if floor_level >= 3 else 0
			var tint: Color = colors[k] if lit else colors[(k + 1) % colors.size()]
			var strength := minf(
				0.24, (0.04 + wave * 0.1 + beat * 0.04) * (1.0 + floor_level * 0.3)
			)
			ci.draw_colored_polygon(quad, TILE_DARK)
			ci.draw_colored_polygon(quad, Palette.with_alpha(tint, strength))
			# Leuchtfuge zwischen den Platten - erst ab Stufe 2 sichtbar.
			if floor_level >= 2:
				ci.draw_polyline(
					PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
					Palette.with_alpha(tint, 0.25 + beat * 0.15), 1.0, true
				)
			else:
				ci.draw_polyline(
					PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
					Color(0, 0, 0, 0.35), 1.0, true
				)

	# Die Tanzenden: fester Platz im Grundriss, nur der Takt bewegt sie.
	# Ohne Ausbau verlaeuft sich hier niemand.
	var crowd := 5 + floor_level * 4 + _lv(levels, "sound") * 2 + int(_polish(levels) * 6.0)
	for i in crowd:
		var f := _hash01(i * 3.7)
		var g := _hash01(i * 9.1 + 4.0)
		var px := float(area["x"]) + 0.05 + f * (float(area["w"]) - 0.1)
		var py := float(area["y"]) + 0.06 + g * (float(area["h"]) - 0.12)
		var rim: Color = colors[i % colors.size()]
		_draw_dancer(ci, w, h, px, py, t + i * 0.7, i, rim, floor_level > 0, lights)

	# Der Schein der Flaeche faellt in den Raum
	if floor_level > 0 or lights > 0:
		var mid := project(w, h, 0.5, float(area["y"]) + float(area["h"]) * 0.5)
		Effects.glow(
			fx, mid.x, mid.y, w * 0.55, colors[0],
			0.02 + floor_level * 0.012 + beat * 0.02
		)

static func _draw_dancer(
	ci: CanvasItem, w: float, h: float, px: float, py: float, t: float, index: int,
	rim: Color = Palette.WHITE, reflect: bool = false, lights: int = 0
) -> void:
	var base := project(w, h, px, py)
	var scale := depth_scale(py)
	var bob := absf(sin(t * 3.1)) * h * 0.008
	var body_h := h * 0.052 * scale
	var body_w := w * 0.021 * scale
	var outfit: Color = Palette.OUTFIT[index % Palette.OUTFIT.size()]
	var tilt := sin(t * 3.1 + index) * body_w * 0.35

	# Spiegelung: auf einer polierten Flaeche steht jeder auf seinem Abbild.
	if reflect:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - body_w * 0.34, base.y),
			Vector2(base.x + body_w * 0.34, base.y),
			Vector2(base.x + body_w * 0.4 + tilt, base.y + body_h * 0.6),
			Vector2(base.x - body_w * 0.4 + tilt, base.y + body_h * 0.6),
		]), Palette.with_alpha(rim, 0.07))

	Draw2D.ellipse(
		ci, base, Vector2(body_w * 0.75, body_w * 0.3), Color(0, 0, 0, 0.45)
	)
	# Schultern breiter als die Huefte - von oben sieht man vor allem die.
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - body_w * 0.34, base.y - bob),
		Vector2(base.x + body_w * 0.34, base.y - bob),
		Vector2(base.x + body_w * 0.5 + tilt, base.y - body_h - bob),
		Vector2(base.x - body_w * 0.5 + tilt, base.y - body_h - bob),
	]), Draw2D.shade(outfit, -0.28))
	# Der Lichtsaum auf den Schultern - sonst verschwinden alle im Dunkeln.
	# Je mehr Licht haengt, desto farbiger faellt es aus.
	var saum: Color = Draw2D.mix(Palette.WHITE, rim, clampf(lights * 0.3, 0.0, 0.85))
	ci.draw_line(
		Vector2(base.x - body_w * 0.5 + tilt, base.y - body_h - bob),
		Vector2(base.x + body_w * 0.5 + tilt, base.y - body_h - bob),
		Palette.with_alpha(saum, 0.14 + lights * 0.05), maxf(1.0, body_w * 0.16), true
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
	var bar := _lv(levels, "bar")
	var lift := float(area["lift"]) / CLUB_WORLD.y * h * (0.7 if bar <= 0 else 1.0)
	var counter: Dictionary = area
	if bar <= 0:
		counter = {
			"x": float(area["x"]) + float(area["w"]) * 0.3, "y": float(area["y"]) + 0.06,
			"w": float(area["w"]) * 0.7, "h": float(area["h"]) - 0.14,
		}
	var quad := floor_quad(w, h, counter)
	var top := _lift(quad, lift)

	# Flaschenregal an der Wand hinter dem Tresen: eine schraege Platte
	# entlang der linken Wand, darauf die Flaschen im Gegenlicht.
	var shelf_back := project(w, h, float(area["x"]) - 0.015, float(area["y"]))
	var shelf_front := project(w, h, float(area["x"]) - 0.015, float(area["y"]) + float(area["h"]))
	var shelf_h := h * 0.05
	# Hoechstens drei Bretter - hoeher waere die Wand im Bild zu Ende.
	var boards := mini(3, 1 + bar)

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
		]), WOOD_DARK if bar > 0 else Color("2a2620"))
		if bar > 0:
			ci.draw_line(b0, b1, Palette.with_alpha(Palette.AMBER, 0.35), 1.5, true)
		for b in (7 if bar > 0 else 4):
			var f := 0.06 + b * (0.14 if bar > 0 else 0.22)
			var p := b0.lerp(b1, f)
			var s := depth_scale(float(area["y"]) + float(area["h"]) * f)
			ci.draw_rect(
				Rect2(p.x - w * 0.026, p.y - shelf_h * 0.55, 7.0 * s, shelf_h * 0.55),
				Draw2D.shade(Palette.AMBER if b % 2 == 0 else Palette.GREEN, -0.2 - (0.35 if bar <= 0 else 0.0))
			)
		if bar > 0:
			Effects.glow(
				fx, (b0.x + b1.x) * 0.5 - w * 0.012, (b0.y + b1.y) * 0.5, w * 0.12,
				Palette.AMBER, 0.05 + bar * 0.02
			)

	if bar <= 0:
		# Eine Bohle auf zwei Boecken. Mehr ist das hier noch nicht.
		# Erst die Boecke, dann die Bohle darauf - sonst stehen die Beine im Holz.
		for legf: float in [0.2, 0.75]:
			var lp := project(
				w, h, float(counter["x"]) + float(counter["w"]) * 0.5,
				float(counter["y"]) + float(counter["h"]) * legf
			)
			Draw2D.stroke_path(ci, PackedVector2Array([
				Vector2(lp.x - 7.0, lp.y), Vector2(lp.x, lp.y - lift * 0.95),
				Vector2(lp.x + 7.0, lp.y),
			]), Draw2D.shade(METAL_DARK, -0.45), 2.0)
		ci.draw_colored_polygon(
			PackedVector2Array([quad[3], quad[2], top[2], top[3]]), Color("18120c")
		)
		ci.draw_polygon(top, PackedColorArray([
			Color("1d170f"), Color("1d170f"), Color("15100a"), Color("15100a"),
		]))
		ci.draw_line(top[3], top[2], Color(0, 0, 0, 0.5), 1.0, true)
	else:
		# Tresen als Block: Vorderkante, rechte Seite, Platte
		ci.draw_colored_polygon(
			PackedVector2Array([quad[3], quad[2], top[2], top[3]]), Draw2D.shade(WOOD_DARK, -0.2)
		)
		ci.draw_colored_polygon(
			PackedVector2Array([quad[1], quad[2], top[2], top[1]]), WOOD_DARK
		)
		ci.draw_polygon(top, PackedColorArray([
			Draw2D.shade(WOOD, 0.12 + bar * 0.06), Draw2D.shade(WOOD, 0.12 + bar * 0.06), WOOD, WOOD,
		]))
		# Lichtleiste unter der Platte
		ci.draw_line(top[3], top[2], Palette.with_alpha(Palette.AMBER, 0.35 + bar * 0.15), 2.0, true)
		Effects.glow(
			fx, (top[2].x + top[3].x) * 0.5, (top[2].y + top[3].y) * 0.5, w * 0.2,
			Palette.AMBER, 0.06 + bar * 0.02 + sin(t * 1.6) * 0.02
		)
		# Ab der Premium-Bar haengt eine Reihe Glaeser kopfueber ueber dem Tresen.
		if bar >= 3:
			for i in 6:
				var gp := project(
					w, h, float(area["x"]) + float(area["w"]) * 0.75,
					float(area["y"]) + float(area["h"]) * (0.1 + i * 0.16)
				)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(gp.x - 4.0, gp.y - lift * 2.2), Vector2(gp.x + 4.0, gp.y - lift * 2.2),
					Vector2(gp.x + 2.0, gp.y - lift * 1.9), Vector2(gp.x - 2.0, gp.y - lift * 1.9),
				]), Palette.with_alpha(Palette.WHITE, 0.25))

	# Glaeser auf der Platte
	for i in (5 if bar > 0 else 2):
		var gy := float(counter["y"]) + float(counter["h"]) * (0.12 + i * 0.19)
		var p := project(w, h, float(counter["x"]) + float(counter["w"]) * 0.5, gy)
		var s := depth_scale(gy)
		ci.draw_rect(
			Rect2(p.x - 3.0 * s, p.y - lift - 12.0 * s, 6.0 * s, 12.0 * s),
			Palette.with_alpha(Palette.WHITE, 0.3)
		)

	# Barkeeper hinter dem Tresen, Gaeste davor
	var colors := _light_colors(levels)
	_draw_dancer(
		ci, w, h, float(area["x"]) + 0.005,
		float(area["y"]) + float(area["h"]) * 0.4, t * 0.4, 7, Palette.AMBER
	)
	for i in 1 + bar:
		var gy := float(area["y"]) + float(area["h"]) * (0.2 + i * 0.24)
		_draw_dancer(
			ci, w, h, float(area["x"]) + float(area["w"]) + 0.035, gy, t * 0.5 + i, i + 2,
			colors[i % colors.size()]
		)

## Booths an der rechten Wand: Tisch, Bank, Gaeste. Ab VIP-Ausbau mit Samt.
static func _draw_booths(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["booths"]
	var vip := _lv(levels, "vip")
	var count := 3 + (1 if vip > 0 else 0)
	var seat: Color = Color("5a2233") if vip > 0 else Color("23272f")

	for i in count:
		var y0 := float(area["y"]) + float(area["h"]) * (float(i) / count) + 0.01
		var cell := {
			"x": float(area["x"]), "y": y0,
			"w": float(area["w"]), "h": float(area["h"]) / count - 0.025,
		}
		var lift := float(area["lift"]) / CLUB_WORLD.y * h * depth_scale(y0)
		var quad := floor_quad(w, h, cell)
		var top := _lift(quad, lift * 0.35)

		if vip <= 0:
			# Klappstuhl und Campingtisch: Sitzgelegenheit, kein Bereich.
			var sp := project(w, h, float(area["x"]) + 0.05, y0 + float(cell["h"]) * 0.5)
			var s0 := depth_scale(y0 + float(cell["h"]) * 0.5)
			Draw2D.ellipse(ci, sp, Vector2(w * 0.016 * s0, h * 0.007 * s0), Color(0, 0, 0, 0.4))
			ci.draw_rect(
				Rect2(sp.x - 11.0 * s0, sp.y - lift * 0.55, 22.0 * s0, 4.0 * s0), seat
			)
			ci.draw_rect(
				Rect2(sp.x - 11.0 * s0, sp.y - lift * 1.0, 22.0 * s0, lift * 0.45),
				Draw2D.shade(seat, -0.3)
			)
			for legx: float in [-9.0, 9.0]:
				ci.draw_line(
					Vector2(sp.x + legx * s0, sp.y - lift * 0.52), Vector2(sp.x + legx * 0.6 * s0, sp.y),
					METAL_DARK, 2.0, true
				)
			# Ein Aschenbecher statt einer Kerze.
			var tp0 := project(w, h, float(area["x"]) - 0.03, y0 + float(cell["h"]) * 0.5)
			Draw2D.ellipse(
				ci, Vector2(tp0.x, tp0.y - h * 0.02 * s0),
				Vector2(w * 0.015 * s0, h * 0.008 * s0), Color("2a2c30")
			)
			_draw_dancer(
				ci, w, h, float(area["x"]) + 0.02, y0 + float(cell["h"]) * 0.4,
				t * 0.3 + i * 2.0, i * 2 + 1, Palette.GREY
			)
			continue

		# Bank an der Wand (die rechte Haelfte der Zelle)
		var back := PackedVector2Array([
			quad[1], quad[2], Vector2(quad[2].x, quad[2].y - lift),
			Vector2(quad[1].x, quad[1].y - lift),
		])
		ci.draw_colored_polygon(back, Draw2D.shade(seat, -0.35))
		ci.draw_line(back[3], back[2], Palette.with_alpha(Palette.WHITE, 0.08), 1.0, true)
		# Knopfheftung im Samt - erst in der Premium-Lounge.
		if vip >= 2:
			for b in 4:
				var bp: Vector2 = back[3].lerp(back[2], 0.15 + b * 0.24)
				ci.draw_circle(
					Vector2(bp.x, bp.y + lift * 0.45), 1.8, Palette.with_alpha(Palette.AMBER, 0.45)
				)

		# Sitzflaeche
		ci.draw_polygon(top, PackedColorArray([
			seat, seat, Draw2D.shade(seat, -0.25), Draw2D.shade(seat, -0.25),
		]))
		if vip >= 2:
			ci.draw_line(top[3], top[2], Palette.with_alpha(Palette.AMBER, 0.4), 1.5, true)

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
				y0 + float(cell["h"]) * (0.3 + g * 0.4), t * 0.3 + i * 2.0 + g, i * 2 + g + 1,
				Palette.AMBER
			)

	# Die Kordel vor der Lounge: das VIP-Versprechen in einem Strich.
	if vip >= 2:
		var p0 := project(w, h, float(area["x"]) - 0.06, float(area["y"]) + 0.02)
		var p1 := project(w, h, float(area["x"]) - 0.06, float(area["y"]) + float(area["h"]) - 0.02)
		Draw2D.stroke_path(ci, Draw2D.quad_curve(
			Vector2(p0.x, p0.y - h * 0.05),
			Vector2((p0.x + p1.x) * 0.5 - w * 0.01, (p0.y + p1.y) * 0.5 - h * 0.03),
			Vector2(p1.x, p1.y - h * 0.06)
		), Palette.with_alpha(Palette.AMBER, 0.6), 3.0)

## Toiletten vorne rechts: zwei Tueren mit Schild, davor wartet immer jemand.
static func _draw_toilets(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["toilets"]
	var comfort := _lv(levels, "comfort")
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Trennwand mit den beiden Tueren, leicht angeschnitten wie die Bar
	ci.draw_colored_polygon(
		PackedVector2Array([quad[0], quad[1], top[1], top[0]]),
		Color("171b23") if comfort > 0 else Color("1d1d1c")
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
			ci, Rect2(dx - dw * 0.5, dy + lift * 0.2, dw, dh), 2.0,
			Color("242b38") if comfort > 0 else Color("2b2620")
		)
		ci.draw_rect(
			Rect2(dx - dw * 0.5, dy + lift * 0.2, dw, dh), Color(1, 1, 1, 0.06), false, 1.0
		)
		if comfort <= 0:
			# Die linke Tuer ist mit Klebeband geflickt, dazu ein Zettel.
			ci.draw_line(
				Vector2(dx - dw * 0.4, dy + lift * 0.45), Vector2(dx + dw * 0.4, dy + lift * 0.6),
				Color(0.6, 0.58, 0.5, 0.14), 2.0, true
			)
		# Schild: Kopf und Schultern als Piktogramm
		var sign_color: Color = Palette.CYAN if comfort > 0 else Palette.GREY
		var sy := dy + lift * 0.34
		ci.draw_circle(Vector2(dx, sy), 3.0, Palette.with_alpha(sign_color, 0.75))
		ci.draw_rect(
			Rect2(dx - 4.0, sy + 4.0, 8.0, 8.0), Palette.with_alpha(sign_color, 0.55)
		)
		if i == 1:
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(dx - 7.0, sy + 12.0), Vector2(dx + 7.0, sy + 12.0),
				Vector2(dx + 4.0, sy + 4.0), Vector2(dx - 4.0, sy + 4.0),
			]), Palette.with_alpha(sign_color, 0.55))
		# Klinke
		ci.draw_circle(
			Vector2(dx + dw * 0.32, dy + lift * 0.6), 2.5, Palette.with_alpha(Palette.WHITE, 0.5)
		)

	# Leuchtschild ueber den Tueren. Ohne Komfort-Ausbau ist die Roehre halb
	# durch - sie zuckt, statt zu leuchten.
	var sign_mid := Vector2((wall_left.x + wall_right.x) * 0.5, (wall_left.y + wall_right.y) * 0.5)
	Draw2D.fill_round_rect(
		ci, Rect2(sign_mid.x - w * 0.035, sign_mid.y - h * 0.006, w * 0.07, h * 0.028),
		2.0, Color("0e1218")
	)
	var flick := 1.0 if comfort > 0 else (0.2 if sin(t * 12.0) > 0.4 else 0.85)
	Draw2D.text(
		ci, Fonts.mono_spaced(4.0), Vector2(sign_mid.x, sign_mid.y + h * 0.017), "WC", _pt(w, 13.0),
		Palette.with_alpha(Palette.CYAN, 0.85 * flick), Draw2D.Align.CENTER
	)
	Effects.glow(fx, sign_mid.x, sign_mid.y + h * 0.01, w * 0.14, Palette.CYAN, 0.09 * flick)

	if comfort <= 0:
		# Ein Eimer faengt auf, was von der Decke kommt.
		var bp := project(w, h, float(area["x"]) - 0.02, float(area["y"]) + 0.16)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(bp.x - 8.0, bp.y - 14.0), Vector2(bp.x + 8.0, bp.y - 14.0),
			Vector2(bp.x + 6.0, bp.y), Vector2(bp.x - 6.0, bp.y),
		]), Color("3a4048"))
		Draw2D.ellipse(ci, Vector2(bp.x, bp.y - 14.0), Vector2(8.0, 3.0), Color("1a1e24"))
	else:
		# Garderobentresen neben den Tueren - der Komfort-Ausbau.
		var gp := project(w, h, float(area["x"]) - 0.03, float(area["y"]) + 0.2)
		Draw2D.fill_round_rect(
			ci, Rect2(gp.x - w * 0.03, gp.y - h * 0.05, w * 0.06, h * 0.05), 2.0, WOOD_DARK
		)
		ci.draw_line(
			Vector2(gp.x - w * 0.03, gp.y - h * 0.05), Vector2(gp.x + w * 0.03, gp.y - h * 0.05),
			Palette.with_alpha(Palette.AMBER, 0.4), 2.0, true
		)

	# Die Schlange davor - je weniger Komfort, desto laenger.
	for i in (4 - comfort):
		_draw_dancer(
			ci, w, h, float(area["x"]) - 0.045 - i * 0.04,
			float(area["y"]) + 0.06 + i * 0.05, t * 0.25 + i * 3.0, i + 11, Palette.CYAN
		)

## Der Eingang - hier beginnt die Schicht. Doppeltuer, Lichtspalt, Kordel.
static func _draw_entrance(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var area: Dictionary = AREAS["entrance"]
	var door := _lv(levels, "door")
	var lift := float(area["lift"]) / CLUB_WORLD.y * h
	var quad := floor_quad(w, h, area)
	var top := _lift(quad, lift)

	# Der Windfang steht vorne im Bild: seine Rueckseite zeigt zum Raum.
	# Ohne Ausbau ist er schmal - eine Tuer, mehr passt da nicht durch.
	var narrow := 0.0 if door > 0 else 0.16
	var back_left := quad[0].lerp(quad[1], narrow)
	var back_right := quad[1].lerp(quad[0], narrow)
	var head_left := Vector2(back_left.x, back_left.y - lift)
	var head_right := Vector2(back_right.x, back_right.y - lift)

	ci.draw_colored_polygon(
		PackedVector2Array([back_left, back_right, head_right, head_left]), Color("0f131a")
	)
	# Rahmen: gestrichen und rostig, oder sauber mit Neonkante.
	Draw2D.stroke_path(ci, PackedVector2Array([
		back_left, head_left, head_right, back_right,
	]), Palette.with_alpha(Palette.RED if door > 0 else RUST, 0.5 + door * 0.12), 3.0)

	# Tuerfluegel: einer ohne Ausbau, zwei danach.
	var span := head_right.x - head_left.x
	var wings := 1 if door <= 0 else 2
	for i in wings:
		var dx := head_left.x + span * (0.12 + i * 0.47) if wings == 2 \
			else head_left.x + span * 0.16
		var dw := span * (0.37 if wings == 2 else 0.68)
		var rect := Rect2(dx, head_left.y + lift * 0.1, dw, lift * 0.86)
		Draw2D.fill_round_rect(ci, rect, 2.0, Color("1a1f28") if door > 0 else Color("20211e"))
		ci.draw_rect(rect, Color(1, 1, 1, 0.05), false, 1.0)
		if door <= 0:
			# Kratzer und ein Aufkleber - die Tuer hat schon einiges gesehen.
			for s in 3:
				var sy := rect.position.y + rect.size.y * (0.25 + s * 0.2)
				ci.draw_line(
					Vector2(rect.position.x + dw * 0.15, sy),
					Vector2(rect.position.x + dw * 0.7, sy + 4.0),
					Color(1, 1, 1, 0.05), 1.0, true
				)
		ci.draw_rect(
			Rect2(rect.position.x + dw * (0.82 if i == 0 and wings == 2 else 0.1),
				rect.position.y + lift * 0.42, dw * 0.08, lift * 0.16),
			Palette.with_alpha(Palette.WHITE, 0.4)
		)

	# Der Spalt: draussen ist Nacht, drinnen brennt das Tuerlicht
	if door > 0:
		var gap_x := head_left.x + span * 0.47
		Draw2D.vgradient_rect(
			fx, Rect2(gap_x, head_left.y + lift * 0.1, span * 0.06, lift * 0.86),
			Palette.with_alpha(Palette.CYAN, 0.35), Palette.with_alpha(Palette.CYAN, 0.05)
		)

	# Leuchtschild ueber der Tuer - ohne Ausbau nur eine Notausgangslampe.
	if door > 0:
		Draw2D.text(
			ci, Fonts.mono_spaced(4.0), Vector2((head_left.x + head_right.x) * 0.5,
				head_left.y - h * 0.012),
			"EINGANG", _pt(w, 15.0), Palette.with_alpha(Palette.RED, 0.7 + sin(t * 2.6) * 0.25),
			Draw2D.Align.CENTER
		)
		Effects.glow(
			fx, (head_left.x + head_right.x) * 0.5, head_left.y - h * 0.008, w * 0.2,
			Palette.RED, 0.12 + sin(t * 2.6) * 0.04
		)
	else:
		var lamp := Vector2((head_left.x + head_right.x) * 0.5, head_left.y - h * 0.018)
		Draw2D.fill_round_rect(
			ci, Rect2(lamp.x - 16.0, lamp.y - 6.0, 32.0, 12.0), 2.0, Color("15311f")
		)
		Draw2D.text(
			ci, Fonts.mono_spaced(2.0), Vector2(lamp.x, lamp.y + 4.0), "EXIT", _pt(w, 9.0),
			Palette.with_alpha(Palette.GREEN, 0.6), Draw2D.Align.CENTER
		)

	# Absperrung: ohne Ausbau eine rostige Kette, danach Pfosten mit Kordel,
	# ab Stufe 3 eine zweite, goldene Spur fuer die VIPs.
	var lanes: Array = [[0.0, Palette.RED]] if door < 3 else [[0.0, Palette.RED], [1.0, Palette.AMBER]]
	for lane: Array in lanes:
		var shift: float = float(lane[0]) * 0.06
		var rope_color: Color = lane[1]
		for side: float in [-1.0, 1.0]:
			var p0 := project(w, h, 0.5 + side * (0.16 + shift), float(area["y"]) - 0.02 - shift)
			var p1 := project(w, h, 0.5 + side * (0.09 + shift), float(area["y"]) - 0.02 - shift)
			if door <= 0:
				# Ein in den Boden gedrehter Haken, daran eine Kette.
				ci.draw_rect(Rect2(p0.x - 2.0, p0.y - h * 0.03, 4.0, h * 0.03), RUST)
				Draw2D.stroke_path(ci, Draw2D.quad_curve(
					Vector2(p0.x, p0.y - h * 0.028),
					Vector2((p0.x + p1.x) * 0.5, p0.y - h * 0.012),
					Vector2(p1.x, p1.y - h * 0.028)
				), Palette.with_alpha(Color("6b6f78"), 0.6), 2.0)
				continue
			ci.draw_rect(Rect2(p0.x - 3.0, p0.y - h * 0.06, 6.0, h * 0.06), METAL)
			ci.draw_circle(
				Vector2(p0.x, p0.y - h * 0.062), 5.0,
				Draw2D.shade(METAL, 0.25) if door < 3 else Palette.AMBER
			)
			Draw2D.stroke_path(ci, Draw2D.quad_curve(
				Vector2(p0.x, p0.y - h * 0.055),
				Vector2((p0.x + p1.x) * 0.5, p0.y - h * 0.035),
				Vector2(p1.x, p1.y - h * 0.055)
			), Palette.with_alpha(rope_color, 0.75), 4.0)

	# Prueftisch und Metalldetektor stehen neben der Tuer, sobald es sie gibt.
	_draw_checkpoint(ci, fx, w, h, t, levels)

## Der Prueferplatz gleich hinter der Tuer: Tisch mit Lampe (Prüfplatz) und
## ein Torbogen (Metalldetektor). Beide erscheinen erst mit ihrem Ausbau.
static func _draw_checkpoint(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var scanner := _lv(levels, "scanner")
	var detector := _lv(levels, "detector")

	if scanner > 0:
		var p := project(w, h, 0.30, 0.80)
		var tw := w * 0.05
		var th := h * 0.03
		Draw2D.fill_round_rect(
			ci, Rect2(p.x - tw * 0.5, p.y - th * 2.2, tw, th), 2.0, Color("232a36")
		)
		for legx: float in [-0.4, 0.4]:
			ci.draw_rect(Rect2(p.x + tw * legx, p.y - th * 1.3, 3.0, th * 1.3), METAL_DARK)
		# Schwanenhalslampe ueber dem Tisch
		var lamp := Vector2(p.x + tw * 0.34, p.y - th * 3.4)
		Draw2D.stroke_path(ci, Draw2D.quad_curve(
			Vector2(p.x + tw * 0.4, p.y - th * 2.2), Vector2(p.x + tw * 0.55, p.y - th * 3.6), lamp
		), METAL_DARK, 2.0)
		ci.draw_circle(lamp, 3.5, Palette.with_alpha(Palette.AMBER, 0.85))
		Effects.glow(fx, lamp.x, lamp.y + 6.0, w * 0.06, Palette.AMBER, 0.08 + scanner * 0.03)

	if detector > 0:
		var p := project(w, h, 0.70, 0.80)
		var gw := w * 0.05
		var gh := h * 0.11
		for side: float in [-1.0, 1.0]:
			ci.draw_rect(
				Rect2(p.x + side * gw * 0.5 - 3.0, p.y - gh, 6.0, gh), Color("2a313d")
			)
		ci.draw_rect(Rect2(p.x - gw * 0.5 - 3.0, p.y - gh, gw + 6.0, 5.0), Color("2a313d"))
		# Die Lampenreihe im Rahmen - ab Stufe 2 laeuft sie durch.
		for i in 5:
			var ly := p.y - gh * (0.2 + i * 0.16)
			var on: bool = detector >= 2 and fmod(t * 3.0, 5.0) > i and fmod(t * 3.0, 5.0) < i + 1
			ci.draw_circle(
				Vector2(p.x - gw * 0.5, ly), 1.8,
				Palette.with_alpha(Palette.GREEN if on else Palette.LINE, 0.9 if on else 0.6)
			)

## Das Team an der Tuer: fuer jede Stufe Security-Team steht einer mehr
## sichtbar im Raum. Ohne Team steht dort niemand ausser dir.
static func _draw_staff(
	ci: CanvasItem, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var team := _lv(levels, "team")
	var spots := [Vector2(0.66, 0.74), Vector2(0.18, 0.66), Vector2(0.80, 0.52)]
	for i in mini(team, spots.size()):
		var spot: Vector2 = spots[i]
		var base := project(w, h, spot.x, spot.y)
		var scale := depth_scale(spot.y)
		var body_h := h * 0.075 * scale
		var body_w := w * 0.028 * scale
		var sway := sin(t * 0.7 + i * 2.0) * body_w * 0.08

		Draw2D.ellipse(ci, base, Vector2(body_w * 0.85, body_w * 0.32), Color(0, 0, 0, 0.5))
		# Breite Schultern, verschraenkte Arme - Haltung statt Tanz.
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - body_w * 0.42 + sway, base.y),
			Vector2(base.x + body_w * 0.42 + sway, base.y),
			Vector2(base.x + body_w * 0.62 + sway, base.y - body_h),
			Vector2(base.x - body_w * 0.62 + sway, base.y - body_h),
		]), Color("12151b"))
		ci.draw_line(
			Vector2(base.x - body_w * 0.5 + sway, base.y - body_h * 0.6),
			Vector2(base.x + body_w * 0.5 + sway, base.y - body_h * 0.6),
			Color("0a0c10"), maxf(2.0, body_w * 0.3), true
		)
		ci.draw_circle(
			Vector2(base.x + sway, base.y - body_h - body_w * 0.42), body_w * 0.36,
			Draw2D.shade(Palette.SKIN[(i + 2) % Palette.SKIN.size()], -0.3)
		)
		# Ohrhoerer mit gruener Lampe: das Team ist auf Funk.
		ci.draw_circle(
			Vector2(base.x + sway + body_w * 0.32, base.y - body_h - body_w * 0.45),
			maxf(1.2, body_w * 0.1),
			Palette.with_alpha(Palette.GREEN, 0.9 if sin(t * 3.0 + i) > 0.0 else 0.25)
		)
		# CREW-Streifen auf dem Ruecken
		ci.draw_line(
			Vector2(base.x - body_w * 0.5 + sway, base.y - body_h * 0.25),
			Vector2(base.x + body_w * 0.5 + sway, base.y - body_h * 0.25),
			Palette.with_alpha(Palette.CYAN, 0.25), maxf(1.0, body_w * 0.1), true
		)

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

## Nebel und Vignette - der Raum bekommt Tiefe. Eine Nebelmaschine gehoert
## zur Soundanlage: ohne sie haengt hier nur Zigarettenrauch.
static func _draw_haze(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, levels: Dictionary
) -> void:
	var sound := _lv(levels, "sound")
	var density := 20 + sound * 8
	var alpha := 0.015 + sound * 0.006
	for i in density:
		var f := _hash01(i * 5.3)
		var g := _hash01(i * 2.1 + 9.0)
		var x := fmod(f * w + t * (8.0 + g * 14.0), w)
		var y := ROOM_TOP * h + g * h * 0.6 + sin(t * 0.4 + i) * 6.0
		fx.draw_circle(Vector2(x, y), 26.0 + f * 40.0, Color(0.16, 0.22, 0.32, alpha))

	# Der Stoss aus der Nebelmaschine neben der Buehne, alle paar Sekunden.
	if sound >= 2:
		var cycle := fmod(t, 9.0)
		if cycle < 2.2:
			var puff := project(w, h, 0.22, 0.14)
			var grow := cycle / 2.2
			Effects.glow(
				fx, puff.x + grow * w * 0.08, puff.y - grow * h * 0.04,
				w * (0.05 + grow * 0.16), Palette.WHITE, 0.09 * (1.0 - grow)
			)

	# Ohne Licht bleibt der Raum duester: die Vignette zieht dann staerker zu.
	Effects.vignette(ci, w, h, 0.62 - _polish(levels) * 0.16)

## Kleiner, stabiler Zufall - dieselbe Zahl bei jedem Bild.
static func _hash01(seed_value: float) -> float:
	var v := sin(seed_value * 12.9898) * 43758.5453
	return v - floorf(v)
