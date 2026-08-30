## Das Buero des Clubleiters - der Tag zwischen zwei Naechten.
##
## Tageslicht durch die Jalousie, Kleiderschrank links, Schreibtisch mit
## Laptop in der Mitte, Tuer rechts. Alles prozedural gezeichnet, wie der Rest
## des Spiels. Die anklickbaren Stellen liegen als Rechtecke in
## OFFICE_HOTSPOTS (Anteile der Flaeche) - die Oberflaeche legt ihre Felder
## genau darueber.
##
## Portierung von src/render/office.js.
class_name Office
extends RefCounted

const OFFICE_WORLD := Vector2(1280, 720)

const OFFICE_HOTSPOTS := {
	"wardrobe": {
		"x": 0.066, "y": 0.076, "w": 0.176, "h": 0.586,
		"label": "KLEIDERSCHRANK", "note": "Aussehen ändern",
	},
	"laptop": {
		"x": 0.474, "y": 0.505, "w": 0.164, "h": 0.170,
		"label": "LAPTOP", "note": "Upgrades kaufen",
	},
	"door": {
		"x": 0.738, "y": 0.118, "w": 0.180, "h": 0.500,
		"label": "TÜR", "note": "Nächste Nacht",
	},
}

## Warme Tagesfarben - der Gegenpol zur Nachtszene.
const WALL_TOP := Color("4c5464")
const WALL_BOTTOM := Color("343b48")
const FLOOR := Color("4a3b2d")
const FLOOR_DARK := Color("2e251c")
const WOOD := Color("4d3a2a")
const WOOD_DARK := Color("33251a")
const METAL := Color("5b6472")
const SKY := Color("8fc3e8")
const SUN := Color("ffe9b0")

static func draw_office(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, character: Variant
) -> void:
	var horizon := h * 0.61

	_draw_walls(ci, w, h, horizon)
	_draw_window(ci, fx, w, h, t)
	_draw_shelf_and_poster(ci, w, h)
	_draw_wardrobe(ci, w, h, t)
	_draw_door(ci, fx, w, h, t)
	_draw_desk(ci, fx, w, h, t)
	if character != null:
		_draw_owner(ci, w, h, t, character)
	_draw_light_and_dust(ci, fx, w, h, t)

# ---------- Raum ----------

static func _draw_walls(ci: CanvasItem, w: float, h: float, horizon: float) -> void:
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, horizon), WALL_TOP, WALL_BOTTOM)

	# Fugen der Betonplatten
	var joint := Color(0, 0, 0, 0.18)
	var y := 60.5
	while y < horizon:
		ci.draw_line(Vector2(0, y), Vector2(w, y), joint, 1.0, true)
		y += 74.0
	var x := 92.5
	while x < w:
		ci.draw_line(Vector2(x, 0), Vector2(x, horizon), joint, 1.0, true)
		x += 148.0

	# Boden mit Dielen in leichter Fluchtperspektive
	var mid := horizon + (h - horizon) * 0.35
	Draw2D.vgradient_rect(ci, Rect2(0, horizon, w, mid - horizon), FLOOR_DARK, FLOOR)
	Draw2D.vgradient_rect(ci, Rect2(0, mid, w, h - mid), FLOOR, Color("1d1712"))

	var plank := Color(0, 0, 0, 0.28)
	for i in range(-6, 19):
		var x_top := w * 0.5 + i * w * 0.055
		var x_bottom := w * 0.5 + i * w * 0.11
		ci.draw_line(Vector2(x_top, horizon), Vector2(x_bottom, h), plank, 1.5, true)

	# Sockelleiste
	ci.draw_rect(Rect2(0, horizon - 12.0, w, 12.0), Color("1b2029"))
	ci.draw_rect(Rect2(0, horizon - 12.0, w, 2.0), Color(1, 1, 1, 0.05))

## Fenster mit Jalousie: der Tag steht im Raum.
static func _draw_window(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var x := w * 0.255
	var y := h * 0.13
	var ww := w * 0.245
	var wh := h * 0.29

	# Rahmen
	Draw2D.fill_round_rect(
		ci, Rect2(x - 12.0, y - 12.0, ww + 24.0, wh + 24.0), 4.0, Color("1c2129")
	)

	# Himmel und Stadt draussen
	Draw2D.vgradient_rect(ci, Rect2(x, y, ww, wh * 0.65), Color("b9dcf5"), SKY)
	Draw2D.vgradient_rect(ci, Rect2(x, y + wh * 0.65, ww, wh * 0.35), SKY, Color("c9cfd6"))

	ci.draw_circle(
		Vector2(x + ww * 0.74, y + wh * 0.26), wh * 0.11, Palette.with_alpha(SUN, 0.9)
	)

	# Haeuser gegenueber
	var houses := Color(90.0 / 255.0, 105.0 / 255.0, 125.0 / 255.0, 0.55)
	for i in 7:
		var bw := ww * (0.09 + (i % 3) * 0.035)
		var bh := wh * (0.22 + fmod(i * 37.0, 100.0) / 100.0 * 0.32)
		ci.draw_rect(Rect2(x + i * ww * 0.145, y + wh - bh, bw, bh), houses)

	# Wolke zieht langsam durch
	var cloud_x := x + fmod(t * 9.0, ww + 160.0) - 80.0
	var cloud := Color(1, 1, 1, 0.6)
	Draw2D.ellipse(ci, Vector2(cloud_x, y + wh * 0.22), Vector2(34, 12), cloud)
	Draw2D.ellipse(ci, Vector2(cloud_x + 24.0, y + wh * 0.19), Vector2(22, 10), cloud)

	# Jalousie, halb heruntergelassen
	var slat := Color(226.0 / 255.0, 222.0 / 255.0, 208.0 / 255.0, 0.82)
	var sy := y
	while sy < y + wh * 0.42:
		ci.draw_rect(Rect2(x, sy, ww, 6.0), slat)
		sy += 9.0
	ci.draw_rect(Rect2(x + 0.5, y + 0.5, ww - 1.0, wh - 1.0), Color(0, 0, 0, 0.25), false, 1.0)

	# Sprossen
	ci.draw_rect(Rect2(x + ww * 0.5 - 3.0, y, 6.0, wh), Color("1c2129"))

	# Lichtbahn in den Raum
	fx.draw_polygon(
		PackedVector2Array([
			Vector2(x, y + wh), Vector2(x + ww, y + wh),
			Vector2(x + ww * 1.9, h), Vector2(x - ww * 0.35, h),
		]),
		PackedColorArray([
			Palette.with_alpha(SUN, 0.22), Palette.with_alpha(SUN, 0.22),
			Palette.with_alpha(SUN, 0.0), Palette.with_alpha(SUN, 0.0),
		])
	)

## Regal, Pinnwand und Uhr - damit die Wand nicht leer wirkt.
static func _draw_shelf_and_poster(ci: CanvasItem, w: float, h: float) -> void:
	# Pinnwand
	var px := w * 0.545
	var py := h * 0.14
	var pw := w * 0.13
	var ph := h * 0.19
	Draw2D.fill_round_rect(ci, Rect2(px, py, pw, ph), 3.0, Color("6b5334"))
	ci.draw_rect(Rect2(px, py, pw, ph), Color("2a2117"), false, 3.0)

	var notes := [Color("f2ead6"), Color("e8d7a8"), Color("dfe8ef")]
	for i in 6:
		var nx := px + 10.0 + (i % 3) * (pw / 3.0)
		var ny := py + 12.0 + floorf(i / 3.0) * (ph / 2.2)
		var basis := Transform2D((1.0 if i % 2 == 1 else -1.0) * 0.06, Vector2(nx, ny))
		var nw := pw / 4.0
		var nh := ph / 3.2
		ci.draw_colored_polygon(PackedVector2Array([
			basis * Vector2(0, 0), basis * Vector2(nw, 0),
			basis * Vector2(nw, nh), basis * Vector2(0, nh),
		]), notes[i % 3])
		var ink := Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, 0.35)
		for l in 3:
			ci.draw_colored_polygon(PackedVector2Array([
				basis * Vector2(3, 5 + l * 6), basis * Vector2(nw - 5.0, 5 + l * 6),
				basis * Vector2(nw - 5.0, 7 + l * 6), basis * Vector2(3, 7 + l * 6),
			]), ink)

	# Wanduhr - zeigt Nachmittag
	var cx := w * 0.715
	var cy := h * 0.17
	var r := h * 0.052
	ci.draw_circle(Vector2(cx, cy), r, Color("e7e3d8"))
	Draw2D.ellipse_outline(ci, Vector2(cx, cy), Vector2(r, r), Color("1b2029"), 3.0)
	ci.draw_line(
		Vector2(cx, cy), Vector2(cx + r * 0.5, cy - r * 0.25), Color("1b2029"), 3.0, true
	)
	ci.draw_line(Vector2(cx, cy), Vector2(cx, cy - r * 0.7), Color("1b2029"), 2.0, true)

	# Regal mit Ordnern
	var sx := w * 0.545
	var sy := h * 0.40
	var sw := w * 0.20
	ci.draw_rect(Rect2(sx, sy, sw, 10.0), WOOD_DARK)
	var colors := [
		Color("7d3b3b"), Color("3b5b7d"), Color("6b6b3b"), Color("4a3b6b"), Color("3b6b52"),
	]
	for i in 9:
		var bwid := sw / 11.0
		var bx := sx + 6.0 + i * (bwid + 2.0)
		ci.draw_rect(Rect2(bx, sy - 44.0, bwid, 44.0), colors[i % colors.size()])
		ci.draw_rect(Rect2(bx, sy - 34.0, bwid, 6.0), Color(1, 1, 1, 0.16))

# ---------- Moebel ----------

static func _rect(spot: Dictionary, w: float, h: float) -> Rect2:
	return Rect2(
		float(spot["x"]) * w, float(spot["y"]) * h,
		float(spot["w"]) * w, float(spot["h"]) * h
	)

static func _draw_wardrobe(ci: CanvasItem, w: float, h: float, t: float) -> void:
	var r := _rect(OFFICE_HOTSPOTS["wardrobe"], w, h)

	# Korpus (Verlauf quer: dunkel - hell - dunkel, also zwei Haelften)
	Draw2D.hgradient_rect(
		ci, Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y)), WOOD_DARK, WOOD
	)
	Draw2D.hgradient_rect(
		ci, Rect2(r.position + Vector2(r.size.x * 0.5, 0), Vector2(r.size.x * 0.5, r.size.y)),
		WOOD, Color("2c2018")
	)
	ci.draw_rect(r, Color(0, 0, 0, 0.55), false, 3.0)

	# Zwei Tueren
	ci.draw_line(
		Vector2(r.position.x + r.size.x * 0.5, r.position.y + 8.0),
		Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 8.0),
		Color(0, 0, 0, 0.4), 2.0, true
	)
	for side: float in [0.25, 0.75]:
		ci.draw_rect(Rect2(
			r.position.x + r.size.x * side - r.size.x * 0.18, r.position.y + 22.0,
			r.size.x * 0.36, r.size.y - 44.0
		), Color(1, 1, 1, 0.08), false, 2.0)

	# Griffe
	Draw2D.fill_round_rect(ci, Rect2(
		r.position.x + r.size.x * 0.5 - 12.0, r.position.y + r.size.y * 0.48, 7.0, 44.0
	), 3.0, METAL)
	Draw2D.fill_round_rect(ci, Rect2(
		r.position.x + r.size.x * 0.5 + 5.0, r.position.y + r.size.y * 0.48, 7.0, 44.0
	), 3.0, METAL)

	# Spiegel auf der linken Tuer - faengt das Fensterlicht
	var mirror := Rect2(
		r.position.x + r.size.x * 0.09, r.position.y + r.size.y * 0.08,
		r.size.x * 0.32, r.size.y * 0.5
	)
	ci.draw_rect(mirror, Palette.with_alpha(Color("cfe4f2"), 0.16))
	ci.draw_rect(mirror, Color(1, 1, 1, 0.2), false, 1.0)

	# Crew-Jacke haengt an der Seite
	var jx := r.position.x + r.size.x + 12.0
	var jy := r.position.y + r.size.y * 0.16
	ci.draw_line(Vector2(jx - 6.0, jy - 14.0), Vector2(jx + 14.0, jy - 14.0), METAL, 3.0, true)
	var hem := jy + 110.0 + sin(t * 1.2) * 2.0
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(jx + 4.0, jy - 10.0), Vector2(jx + 26.0, jy + 16.0),
		Vector2(jx + 20.0, hem), Vector2(jx - 12.0, hem),
		Vector2(jx - 18.0, jy + 16.0),
	]), Color("1b1f27"))
	ci.draw_rect(
		Rect2(jx - 16.0, jy + 52.0, 40.0, 5.0), Palette.with_alpha(Palette.RED, 0.7)
	)

	# Schatten auf dem Boden
	Draw2D.ellipse(
		ci, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y + 6.0),
		Vector2(r.size.x * 0.62, 12.0), Color(0, 0, 0, 0.35)
	)

static func _draw_desk(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var dx := w * 0.40
	var dy := h * 0.655
	var dw := w * 0.30
	var dh := h * 0.045

	# Schatten
	Draw2D.ellipse(
		ci, Vector2(dx + dw * 0.5, dy + h * 0.20), Vector2(dw * 0.6, 20.0),
		Color(0, 0, 0, 0.4)
	)

	# Buerostuhl - steht hinter dem Tisch, die Lehne schaut ueber die Platte.
	var cx := dx + dw * 0.13
	# Der Stuhl steht weiter hinten im Raum: sein Fuss sitzt fast auf der
	# Tischkante, damit die Platte davor liegt und nur die Lehne herausschaut.
	var cy := dy + dh + h * 0.012
	Draw2D.ellipse(ci, Vector2(cx, cy + 26.0), Vector2(44.0, 8.0), Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(cx - 4.0, cy - 10.0, 8.0, 34.0), METAL)
	Draw2D.fill_round_rect(ci, Rect2(cx - 46.0, cy - 30.0, 92.0, 22.0), 6.0, Color("20252e"))
	Draw2D.fill_round_rect(ci, Rect2(cx - 40.0, cy - 128.0, 80.0, 96.0), 12.0, Color("262c36"))
	Draw2D.fill_round_rect(
		ci, Rect2(cx - 32.0, cy - 118.0, 64.0, 34.0), 8.0, Color(1, 1, 1, 0.06)
	)

	# Beine
	ci.draw_rect(Rect2(dx + 16.0, dy + dh, 12.0, h * 0.17), METAL)
	ci.draw_rect(Rect2(dx + dw - 28.0, dy + dh, 12.0, h * 0.17), METAL)

	# Platte
	Draw2D.fill_round_rect(ci, Rect2(dx, dy, dw, dh), 4.0, WOOD_DARK)
	Draw2D.vgradient_rect(ci, Rect2(dx + 2.0, dy, dw - 4.0, dh), Color("6a4f38"), WOOD_DARK)
	ci.draw_rect(
		Rect2(dx + 4.0, dy + 3.0, dw - 8.0, 3.0), Palette.with_alpha(Color("ffd9a0"), 0.12)
	)

	# Papierstapel und Kaffeetasse
	var paper_basis := Transform2D(-0.05, Vector2(dx + dw * 0.12, dy - 12.0))
	ci.draw_colored_polygon(PackedVector2Array([
		paper_basis * Vector2(0, 0), paper_basis * Vector2(62, 0),
		paper_basis * Vector2(62, 12), paper_basis * Vector2(0, 12),
	]), Color("e9e4d4"))
	ci.draw_colored_polygon(PackedVector2Array([
		paper_basis * Vector2(2, -5), paper_basis * Vector2(64, -5),
		paper_basis * Vector2(64, 3), paper_basis * Vector2(2, 3),
	]), Color("d5cfbc"))

	var cup_x := dx + dw * 0.82
	Draw2D.fill_round_rect(ci, Rect2(cup_x, dy - 26.0, 26.0, 26.0), 3.0, Color("d8dee6"))
	Draw2D.stroke_path(ci, Draw2D.ellipse_points(
		Vector2(cup_x + 30.0, dy - 13.0), Vector2(8.0, 8.0), -PI * 0.5, PI * 0.5
	), Color("d8dee6"), 3.0)
	# Dampf
	for i in 2:
		var sx := cup_x + 8.0 + i * 10.0
		Draw2D.stroke_path(ci, Draw2D.quad_curve(
			Vector2(sx, dy - 30.0),
			Vector2(sx + sin(t * 2.0 + i) * 6.0, dy - 44.0),
			Vector2(sx, dy - 58.0)
		), Color(1, 1, 1, 0.25), 2.0)

	_draw_laptop(ci, fx, w, h, t)

## Der Laptop: hier laufen die Bestellungen fuer den Ausbau.
static func _draw_laptop(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var r := _rect(OFFICE_HOTSPOTS["laptop"], w, h)
	var base_y := r.position.y + r.size.y * 0.82

	# Deckel: die Vorlage schert ihn mit ctx.transform(1,0,-0.16,1,0,0).
	var lid := Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	lid.origin = Vector2(r.position.x + r.size.x * 0.5, base_y)

	var shell := Draw2D.round_rect_points(Rect2(
		-r.size.x * 0.42, -r.size.y * 0.78, r.size.x * 0.84, r.size.y * 0.72
	), 5.0)
	var shell_points := PackedVector2Array()
	for p: Vector2 in shell:
		shell_points.append(lid * p)
	Draw2D.fill_path(ci, shell_points, Color("20252e"))

	# Bildschirm mit Shop-Oberflaeche
	var scr_top := lid * Vector2(-r.size.x * 0.37, -r.size.y * 0.72)
	var scr_tr := lid * Vector2(r.size.x * 0.37, -r.size.y * 0.72)
	var scr_br := lid * Vector2(r.size.x * 0.37, -r.size.y * 0.12)
	var scr_bl := lid * Vector2(-r.size.x * 0.37, -r.size.y * 0.12)
	ci.draw_polygon(
		PackedVector2Array([scr_top, scr_tr, scr_br, scr_bl]),
		PackedColorArray([Color("0d3448"), Color("0d3448"), Color("07141d"), Color("07141d")])
	)

	var bar := Palette.with_alpha(Palette.CYAN, 0.75)
	_lid_rect(ci, lid, Rect2(-r.size.x * 0.32, -r.size.y * 0.66, r.size.x * 0.3, 4.0), bar)
	var amber := Palette.with_alpha(Palette.AMBER, 0.6)
	for i in 3:
		var bw := r.size.x * (0.18 + fmod(i * 13.0, 7.0) / 20.0) \
			* (0.7 + sin(t * 1.4 + i) * 0.1)
		_lid_rect(
			ci, lid,
			Rect2(-r.size.x * 0.32, -r.size.y * 0.54 + i * r.size.y * 0.14, bw, 7.0), amber
		)

	# Tastaturteil
	Draw2D.fill_round_rect(ci, Rect2(
		r.position.x + r.size.x * 0.06, base_y, r.size.x * 0.88, r.size.y * 0.13
	), 4.0, Color("2b313b"))
	ci.draw_rect(Rect2(
		r.position.x + r.size.x * 0.18, base_y + 3.0, r.size.x * 0.64, 5.0
	), Color("3a414d"))

	# Bildschirmschein auf der Tischplatte
	Effects.glow(
		fx, r.position.x + r.size.x * 0.5, base_y, r.size.x,
		Palette.CYAN, 0.16 + sin(t * 2.0) * 0.03
	)

static func _lid_rect(ci: CanvasItem, lid: Transform2D, rect: Rect2, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		lid * rect.position,
		lid * (rect.position + Vector2(rect.size.x, 0)),
		lid * (rect.position + rect.size),
		lid * (rect.position + Vector2(0, rect.size.y)),
	]), color)

## Die Tuer: dahinter beginnt die naechste Nacht.
static func _draw_door(ci: CanvasItem, fx: Variant, w: float, h: float, t: float) -> void:
	var r := _rect(OFFICE_HOTSPOTS["door"], w, h)

	# Rahmen
	ci.draw_rect(Rect2(
		r.position.x - 14.0, r.position.y - 14.0, r.size.x + 28.0, r.size.y + 14.0
	), Color("1b2029"))

	Draw2D.hgradient_rect(
		ci, Rect2(r.position, Vector2(r.size.x * 0.55, r.size.y)),
		Color("4a3729"), Color("5d4633")
	)
	Draw2D.hgradient_rect(
		ci, Rect2(r.position + Vector2(r.size.x * 0.55, 0), Vector2(r.size.x * 0.45, r.size.y)),
		Color("5d4633"), Color("38291d")
	)

	var groove := Color(0, 0, 0, 0.45)
	for entry: Array in [[0.07, 0.34], [0.5, 0.42]]:
		ci.draw_rect(Rect2(
			r.position.x + r.size.x * 0.14, r.position.y + r.size.y * entry[0],
			r.size.x * 0.72, r.size.y * entry[1]
		), groove, false, 3.0)

	# Klinke
	var brass := Color("c9a35c")
	Draw2D.fill_round_rect(ci, Rect2(
		r.position.x + r.size.x * 0.06, r.position.y + r.size.y * 0.52, r.size.x * 0.2, 10.0
	), 5.0, brass)
	ci.draw_circle(
		Vector2(r.position.x + r.size.x * 0.14, r.position.y + r.size.y * 0.53), 9.0, brass
	)

	# Schild "NACHTSCHICHT" - der Weg nach draussen
	Draw2D.fill_round_rect(ci, Rect2(
		r.position.x + r.size.x * 0.16, r.position.y + r.size.y * 0.14, r.size.x * 0.68, 34.0
	), 3.0, Color("12161d"))
	Draw2D.text(
		ci, Fonts.mono_spaced(3.0),
		Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.14 + 22.0),
		"NACHTSCHICHT", 13,
		Palette.with_alpha(Palette.RED, 0.7 + sin(t * 2.4) * 0.25), Draw2D.Align.CENTER
	)

	# Lichtspalt unter der Tuer
	Draw2D.vgradient_rect(
		fx, Rect2(r.position.x - 10.0, r.position.y + r.size.y - 6.0, r.size.x + 20.0, 46.0),
		Palette.with_alpha(Palette.AMBER, 0.3), Palette.with_alpha(Palette.AMBER, 0.0)
	)

## Der eigene Tuersteher steht im Raum und wartet auf den Abend.
static func _draw_owner(
	ci: CanvasItem, w: float, h: float, t: float, character: Variant
) -> void:
	Figure.draw(ci, {
		"x": w * 0.335,
		"y": h * 0.93,
		"h": h * 0.52,
		"look": CharacterSys.character_look(character),
		"personality": "polite",
		"accent": CharacterSys.accent_color(character),
		"t": t,
	})

static func _draw_light_and_dust(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float
) -> void:
	# Staub im Sonnenlicht
	for i in 40:
		var seed_v := sin(i * 12.9898) * 43758.5453
		var f := seed_v - floorf(seed_v)
		var x := w * 0.16 + fmod((f * w * 0.5) + sin(t * 0.25 + i) * 26.0, w * 0.5)
		var y := fmod(h * 0.2 + f * h * 0.7 + t * (6.0 + f * 10.0), h * 0.85)
		fx.draw_circle(Vector2(x, y), 1.0 + f * 1.6, Palette.with_alpha(SUN, 0.12 + f * 0.12))

	# Weiche Vignette, damit die Raender nicht flach wirken
	Effects.vignette(ci, w, h, 0.42)
