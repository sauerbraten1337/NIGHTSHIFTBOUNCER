## Grosse 2D-Figuren in Frontansicht - das, was der Tuersteher tatsaechlich
## sieht. Alles prozedural gezeichnet, kein Asset. Gesichtszuege, Haltung und
## Schwanken transportieren Stimmung und Betrunkenheit.
##
## Portierung von src/render/figure.js. ctx.save()/translate() faellt weg:
## statt den Kontext zu verschieben, rechnet draw() die Verschiebung direkt in
## die Koordinaten - das haelt die Rueckgabe der Ankerpunkte einfach und
## vermeidet verschachtelte Transformationen im _draw().
class_name Figure
extends RefCounted

const MOOD_FACE := {
	"polite": {"brow": 0.0, "mouth": 0.35, "eye": 1.0},
	"annoyed": {"brow": -0.5, "mouth": -0.4, "eye": 0.9},
	"drunk": {"brow": -0.1, "mouth": 0.15, "eye": 0.5},
	"arrogant": {"brow": -0.3, "mouth": -0.15, "eye": 0.8},
	"aggressive": {"brow": -0.9, "mouth": -0.7, "eye": 1.1},
	"nervous": {"brow": 0.5, "mouth": -0.2, "eye": 1.15},
	# Stimmungen des eigenen Charakters nach der Nacht.
	"happy": {"brow": 0.25, "mouth": 0.95, "eye": 1.0},
	"proud": {"brow": 0.1, "mouth": 0.6, "eye": 0.95},
	"tired": {"brow": 0.15, "mouth": -0.15, "eye": 0.6},
	"sad": {"brow": 0.75, "mouth": -0.95, "eye": 0.85},
}

## Zeichnet eine Person frontal.
##
## opts: { x, y (Fusspunkt), h (Gesamthoehe in px), look, personality,
##         t (Zeit), drunk, holdingId, accent, dim, vip, bag, bagOut,
##         signs, rage, pose }
##
## Rueckgabe: Ankerpunkte der Abtast-Zonen in Weltkoordinaten.
static func draw(ci: CanvasItem, opts: Dictionary) -> Dictionary:
	var x := float(opts["x"])
	var y := float(opts["y"])
	var h := float(opts.get("h", 300.0))
	var look: Dictionary = opts.get("look", {})
	var personality := String(opts.get("personality", "polite"))
	var t := float(opts.get("t", 0.0))
	var drunk := float(opts.get("drunk", 0.0))
	var holding_id := bool(opts.get("holdingId", false))
	var accent: Variant = opts.get("accent", null)
	var dim := float(opts.get("dim", 0.0))
	var vip := bool(opts.get("vip", false))
	var bag := bool(opts.get("bag", false))
	var bag_out := bool(opts.get("bagOut", false))
	var signs: Array = opts.get("signs", [])
	var rage := float(opts.get("rage", 0.0))
	var pose := String(opts.get("pose", "idle"))

	# Fahle Haut ist eines der Anzeichen, die man von aussen sieht.
	var base_skin: Color = Palette.SKIN[int(look.get("skin", 0)) % Palette.SKIN.size()]
	var skin := Draw2D.mix(base_skin, Color("b9c0cb"), 0.4) if signs.has("pale") else base_skin
	var outfit: Color = Palette.OUTFIT[int(look.get("outfit", 0)) % Palette.OUTFIT.size()]
	var hair: Color = Palette.HAIR[int(look.get("hair", 0)) % Palette.HAIR.size()]
	var bulk := float(look.get("bulk", 1.0))

	var shaky := sin(t * 22.0) * 1.6 if signs.has("shake") else 0.0
	# Wer nicht stillstehen kann, tritt sichtbar von einem Bein aufs andere.
	var restless := sin(t * 4.5) * 4.0 if signs.has("restless") else 0.0
	var sway := sin(t * (0.9 + drunk * 2.2)) * (1.5 + drunk * 9.0) + shaky + restless
	var breath := sin(t * 1.6) * 0.006 * h

	# Haltung: jubeln (Huepfer, Arme hoch) oder haengen lassen (Schultern runter).
	var cheer := absf(sin(t * 3.1)) if pose == "cheer" else 0.0
	var slump := 1.0 if pose == "slump" else 0.0
	# Der Koerper hebt beim Huepfen ab und sackt beim Haengenlassen zusammen.
	var shift := slump * h * 0.03 - cheer * h * 0.055

	var head_r := h * 0.095 * bulk
	var head_y := y - h + head_r
	var shoulder_y := head_y + head_r * 1.5
	var hip_y := y - h * 0.40
	var shoulder_w := h * 0.125 * bulk

	# Die Vorlage verschiebt den Kontext um x + sway * 0.4; hier wandert das
	# in einen Versatz, der jedem Punkt zugerechnet wird.
	var ox := x + sway * 0.4

	# Schatten - bleibt am Boden, auch wenn die Figur abhebt.
	Draw2D.ellipse(
		ci, Vector2(ox, y),
		Vector2(shoulder_w * (1.5 - cheer * 0.35), h * 0.022),
		Color(0, 0, 0, 0.5 - cheer * 0.2)
	)

	# Ab hier hebt/sackt der Koerper (ctx.translate(0, shift)).
	var oy := shift

	# Beine
	var leg_color := Draw2D.shade(outfit, -0.35)
	var leg_w := h * 0.044 * bulk
	Draw2D.line_round(
		ci, Vector2(ox - shoulder_w * 0.38, hip_y + oy),
		Vector2(ox - shoulder_w * 0.58, y - h * 0.012 + oy), leg_color, leg_w
	)
	Draw2D.line_round(
		ci, Vector2(ox + shoulder_w * 0.38, hip_y + oy),
		Vector2(ox + shoulder_w * 0.6, y - h * 0.012 + oy), leg_color, leg_w
	)

	# Schuhe
	var shoe := Color("0a0c10")
	Draw2D.fill_round_rect(ci, Rect2(
		ox - shoulder_w * 0.72, y - h * 0.022 + oy, shoulder_w * 0.5, h * 0.022
	), 2.0, shoe)
	Draw2D.fill_round_rect(ci, Rect2(
		ox + shoulder_w * 0.24, y - h * 0.022 + oy, shoulder_w * 0.5, h * 0.022
	), 2.0, shoe)

	# Torso / Jacke
	var torso_top := shoulder_y - breath
	var torso := PackedVector2Array([Vector2(ox - shoulder_w, torso_top + h * 0.02 + oy)])
	Draw2D.append_quad(
		torso,
		Vector2(ox - shoulder_w * 1.06, torso_top + oy),
		Vector2(ox - shoulder_w * 0.55, torso_top - h * 0.008 + oy)
	)
	torso.append(Vector2(ox + shoulder_w * 0.55, torso_top - h * 0.008 + oy))
	Draw2D.append_quad(
		torso,
		Vector2(ox + shoulder_w * 1.06, torso_top + oy),
		Vector2(ox + shoulder_w, torso_top + h * 0.02 + oy)
	)
	torso.append(Vector2(ox + shoulder_w * 0.78, hip_y + h * 0.03 + oy))
	torso.append(Vector2(ox - shoulder_w * 0.78, hip_y + h * 0.03 + oy))
	Draw2D.fill_path(ci, torso, outfit)

	# Jackenoeffnung + Shirt
	var shirt := PackedVector2Array([
		Vector2(ox - shoulder_w * 0.3, torso_top - h * 0.006 + oy),
		Vector2(ox + shoulder_w * 0.3, torso_top - h * 0.006 + oy),
		Vector2(ox + shoulder_w * 0.12, hip_y + oy),
		Vector2(ox - shoulder_w * 0.12, hip_y + oy),
	])
	Draw2D.fill_path(ci, shirt, Draw2D.shade(outfit, 0.22))
	Draw2D.stroke_path(ci, shirt, Draw2D.shade(outfit, -0.45), maxf(1.0, h * 0.004), true)

	ci.draw_rect(Rect2(
		ox - shoulder_w * 0.8, hip_y + h * 0.012 + oy, shoulder_w * 1.6, h * 0.014
	), Draw2D.shade(outfit, -0.55))

	if accent != null:
		Draw2D.fill_round_rect(ci, Rect2(
			ox - shoulder_w * 0.85, hip_y - h * 0.03 + oy, shoulder_w * 1.7, h * 0.012
		), 2.0, accent)
	if vip:
		var vip_color := Palette.with_alpha(Palette.AMBER, 0.85)
		Draw2D.stroke_path(ci, Draw2D.ellipse_points(
			Vector2(ox, torso_top + h * 0.045 + oy), Vector2(h * 0.03, h * 0.03),
			PI * 0.15, PI * 0.85
		), vip_color, maxf(1.0, h * 0.005))

	# Arme
	var arm_swing := sin(t * 1.1) * h * 0.006
	var arm_w := h * 0.042 * bulk
	# Beim Uebergriff greift er nach vorn - die Haende kommen auf einen zu.
	var reach := sin(t * 9.0) * h * 0.02 if rage > 0.0 else 0.0

	var hand_l: Vector2
	var hand_r: Vector2
	if cheer > 0.0 or slump > 0.0:
		hand_l = _posed_hand(-1.0, slump, cheer, t, h, shoulder_w, hip_y, torso_top)
		hand_r = _posed_hand(1.0, slump, cheer, t, h, shoulder_w, hip_y, torso_top)
	elif rage > 0.0:
		hand_l = Vector2(-shoulder_w * 0.92, torso_top + h * 0.11 + reach)
		hand_r = Vector2(shoulder_w * 0.92, torso_top + h * 0.11 - reach)
	elif holding_id:
		hand_l = Vector2(-shoulder_w * 1.1, torso_top + h * 0.13 + arm_swing)
		hand_r = Vector2(shoulder_w * 0.55, torso_top + h * 0.14)
	else:
		hand_l = Vector2(-shoulder_w * 1.02, hip_y + arm_swing)
		hand_r = Vector2(shoulder_w * 1.02, hip_y - arm_swing)
	hand_l += Vector2(ox, oy)
	hand_r += Vector2(ox, oy)

	Draw2D.line_round(
		ci, Vector2(ox - shoulder_w * 0.9, torso_top + h * 0.03 + oy), hand_l, outfit, arm_w
	)
	Draw2D.line_round(
		ci, Vector2(ox + shoulder_w * 0.9, torso_top + h * 0.03 + oy), hand_r, outfit, arm_w
	)

	# Haende (beim Uebergriff zu Faeusten geballt und deutlich groesser, weil nah)
	var hand_radius := h * (0.03 if rage > 0.0 else 0.021)
	ci.draw_circle(hand_l, hand_radius, skin)
	ci.draw_circle(hand_r, hand_radius, skin)

	if holding_id and rage <= 0.0:
		_draw_held_card(ci, ox + shoulder_w * 0.55, torso_top + h * 0.145 + oy, h)

	# Umhaengetasche: an der Huefte getragen, beim Abtasten vor dem Koerper
	# hochgehalten.
	var bag_center: Variant = null
	if bag:
		var bw := h * 0.19
		var bh := h * 0.14
		if bag_out:
			# hochgehalten: vor dem Bauch, leicht wippend
			var lift := sin(t * 2.4) * h * 0.008
			var bx := ox - bw * 0.5
			var by := torso_top + h * 0.1 + lift + oy
			Items.draw_shoulder_bag(ci, {
				"x": bx, "y": by, "w": bw, "h": bh,
				"strapX": ox - shoulder_w * 0.75, "strapY": torso_top + h * 0.01 + oy,
			})
			bag_center = Vector2(bx + bw * 0.5, by + bh * 0.5)
		else:
			var bx2 := ox + shoulder_w * 0.62
			var by2 := hip_y - h * 0.03 + oy
			Items.draw_shoulder_bag(ci, {
				"x": bx2, "y": by2, "w": bw, "h": bh,
				"strapX": ox - shoulder_w * 0.7, "strapY": torso_top + h * 0.005 + oy,
			})
			bag_center = Vector2(bx2 + bw * 0.5, by2 + bh * 0.5)

	# Hals
	ci.draw_rect(Rect2(
		ox - head_r * 0.35, head_y + head_r * 0.6 + oy, head_r * 0.7, head_r * 0.9
	), Draw2D.shade(skin, -0.2))

	# Kopf
	draw_head(
		ci, ox, head_y - breath + oy, head_r, skin, hair, look, personality, drunk, t, signs, rage
	)

	if dim > 0.0:
		ci.draw_rect(Rect2(
			ox - shoulder_w * 2.0, y - h * 1.1 + oy, shoulder_w * 4.0, h * 1.15
		), Color(4.0 / 255.0, 6.0 / 255.0, 10.0 / 255.0, dim))

	# Ankerpunkte in Weltkoordinaten - die Abtast-Ringe sitzen genau dort,
	# wo die jeweilige Stelle wirklich gezeichnet wurde.
	return {
		"jacket": {
			"x": ox, "y": torso_top + h * 0.09 + shift,
			"rx": shoulder_w * 0.95, "ry": h * 0.075,
		},
		"pockets": {
			"x": ox, "y": hip_y + h * 0.03 + shift,
			"rx": shoulder_w * 0.85, "ry": h * 0.06,
		},
		"bag": {
			"x": (bag_center as Vector2).x, "y": (bag_center as Vector2).y,
			"rx": h * 0.13, "ry": h * 0.1,
		} if bag_center != null else null,
	}

## Jubel reisst die Arme hoch, Enttaeuschung laesst sie nach unten fallen.
static func _posed_hand(
	side: float, slump: float, cheer: float, t: float,
	h: float, shoulder_w: float, hip_y: float, torso_top: float
) -> Vector2:
	if slump > 0.0:
		return Vector2(
			side * shoulder_w * 0.86,
			hip_y + h * 0.09 + sin(t * 1.2 + side) * h * 0.004
		)
	return Vector2(
		side * shoulder_w * (1.05 + cheer * 0.16),
		torso_top - h * (0.03 + cheer * 0.09) + sin(t * 3.1 + side * 0.4) * h * 0.006
	)

static func draw_head(
	ci: CanvasItem, x: float, y: float, r: float, skin: Color, hair: Color,
	look: Dictionary, personality: String, drunk: float, t: float,
	signs: Array = [], rage: float = 0.0
) -> void:
	var face: Dictionary = MOOD_FACE.get(personality, MOOD_FACE["polite"])

	# Kopfform
	Draw2D.ellipse(ci, Vector2(x, y), Vector2(r * 0.86, r), skin)
	# Ohren
	Draw2D.ellipse(ci, Vector2(x - r * 0.86, y + r * 0.08), Vector2(r * 0.14, r * 0.2), skin)
	Draw2D.ellipse(ci, Vector2(x + r * 0.86, y + r * 0.08), Vector2(r * 0.14, r * 0.2), skin)

	# Augen (blinzeln, bei Betrunkenen halb geschlossen)
	var blink := 0.12 if (sin(t * 0.7) > 0.985 or sin(t * 1.9 + 2.0) > 0.99) else 1.0
	var wide := signs.has("pupils")
	var absent := signs.has("absent")
	# Geroetete Augen sieht man schon aus zwei Metern - bei Rausch wie bei Alkohol.
	var red_eyes: bool = signs.has("redEyes") or drunk > 0.7
	var glassy := signs.has("glassy")
	var rings := signs.has("rings")
	var open := maxf(
		0.12, float(face["eye"]) * (1.0 - drunk * 0.55) * (1.25 if wide else 1.0)
	) * blink
	var eye_y := y - r * 0.05
	var eye_dx := r * 0.34

	# Dunkle Augenringe liegen unter dem Auge, also zuerst.
	if rings:
		var ring_color := Palette.with_alpha(Color("3a2a3d"), 0.5)
		for side: float in [-1.0, 1.0]:
			Draw2D.ellipse(
				ci, Vector2(x + side * eye_dx, eye_y + r * 0.13),
				Vector2(r * 0.17, r * 0.09), ring_color
			)

	for side: float in [-1.0, 1.0]:
		var ex := x + side * eye_dx
		# Deutlich rot: das ist das Anzeichen, das man auf Distanz erkennen soll.
		Draw2D.ellipse(
			ci, Vector2(ex, eye_y), Vector2(r * 0.155, r * 0.105 * open),
			Color("efaeae") if red_eyes else Color("f2f4f8")
		)

		# Geplatzte Aederchen: zwei feine rote Striche im Weissen.
		if red_eyes and open > 0.4:
			var vein := Palette.with_alpha(Color("c22626"), 0.95)
			var vein_w := maxf(0.8, r * 0.03)
			for dir: float in [-1.0, 1.0]:
				Draw2D.line_round(
					ci,
					Vector2(ex + dir * r * 0.14, eye_y - r * 0.02 * dir),
					Vector2(ex + dir * r * 0.05, eye_y + r * 0.03 * dir),
					vein, vein_w
				)

		# Gereizter Rand rund ums Auge
		if red_eyes:
			Draw2D.ellipse_outline(
				ci, Vector2(ex, eye_y),
				Vector2(r * 0.175, r * 0.125 * maxf(0.5, open)),
				Palette.with_alpha(Color("c04545"), 0.55), maxf(0.8, r * 0.025)
			)

		# Weite Pupillen sind das deutlichste sichtbare Anzeichen.
		var pupil := r * (0.105 if wide else 0.062) * maxf(0.4, open)
		var drift := sin(t * 0.35) * r * 0.05 if absent else sin(t * 0.5) * r * 0.025
		ci.draw_circle(Vector2(ex + drift, eye_y), pupil, Color("151a22"))

		# Glasiger Blick: nasser Glanz auf dem Auge.
		if glassy and open > 0.4:
			ci.draw_circle(
				Vector2(ex + drift - pupil * 0.4, eye_y - pupil * 0.4),
				maxf(0.8, pupil * 0.42), Color(1, 1, 1, 0.8)
			)

	# Augenbrauen
	var brow_color := Draw2D.shade(hair, -0.1)
	var brow_w := maxf(1.0, r * 0.09)
	var brow := float(face["brow"])
	for side: float in [-1.0, 1.0]:
		var inner := y - r * 0.26 + brow * r * 0.12 * side * -1.0
		var outer := y - r * 0.3 - brow * r * 0.08
		Draw2D.line_round(
			ci,
			Vector2(x + side * (eye_dx - r * 0.18), inner),
			Vector2(x + side * (eye_dx + r * 0.18), outer),
			brow_color, brow_w
		)

	# Nase
	Draw2D.line_round(
		ci, Vector2(x, y + r * 0.05), Vector2(x - r * 0.08, y + r * 0.3),
		Draw2D.shade(skin, -0.3), maxf(1.0, r * 0.06)
	)

	# Mund
	var jaw := absf(sin(t * 7.0)) * r * 0.12 if signs.has("jaw") else 0.0
	var mouth_y := y + r * 0.5 + jaw
	Draw2D.stroke_path(ci, Draw2D.quad_curve(
		Vector2(x - r * 0.2, mouth_y),
		Vector2(x, mouth_y + float(face["mouth"]) * r * 0.18),
		Vector2(x + r * 0.2, mouth_y)
	), Draw2D.shade(skin, -0.55), maxf(1.0, r * 0.07))

	# Schweiss auf der Stirn
	if signs.has("sweat"):
		var sweat := Palette.with_alpha(Color("bfe6ff"), 0.75)
		for i in 3:
			var drop_y := y - r * 0.55 + fmod(t * 22.0 + i * 30.0, 40.0) * r * 0.012
			Draw2D.ellipse(
				ci, Vector2(x + (i - 1) * r * 0.42, drop_y),
				Vector2(r * 0.045, r * 0.075), sweat
			)

	# Haare - der eigene Charakter bestimmt die Frisur unabhaengig von der Farbe.
	var style := int(look.get("hairStyle", look.get("hair", 0))) % 4
	match style:
		0:
			Draw2D.ellipse_arc(
				ci, Vector2(x, y - r * 0.28), Vector2(r * 0.92, r * 0.75), PI, TAU, hair
			)
		1:
			Draw2D.ellipse_arc(
				ci, Vector2(x, y - r * 0.1), Vector2(r * 0.95, r * 0.95),
				PI * 1.02, PI * 1.98, hair
			)
		2:
			Draw2D.ellipse_arc(
				ci, Vector2(x, y - r * 0.35), Vector2(r * 0.7, r * 0.5), PI, TAU, hair
			)
		_:
			Draw2D.ellipse_arc(
				ci, Vector2(x, y - r * 0.2), Vector2(r * 0.9, r * 0.85),
				PI * 0.95, PI * 2.05, hair
			)
	if style == 3:
		# Seitenpartien
		ci.draw_rect(Rect2(x - r * 0.92, y - r * 0.35, r * 0.2, r * 0.7), hair)
		ci.draw_rect(Rect2(x + r * 0.72, y - r * 0.35, r * 0.2, r * 0.7), hair)

	# Bartschatten
	var beard: bool = look["beard"] if look.has("beard") else (int(look.get("outfit", 0)) % 3 == 0)
	if beard:
		Draw2D.ellipse(
			ci, Vector2(x, y + r * 0.66), Vector2(r * 0.5, r * 0.22),
			Palette.with_alpha(Draw2D.shade(hair, -0.45), 0.2)
		)

	# Uebergriff: das Gesicht laeuft rot an.
	if rage > 0.0:
		Draw2D.ellipse(
			ci, Vector2(x, y), Vector2(r * 0.86, r),
			Palette.with_alpha(Color("c8232c"), 0.16 + rage * 0.14)
		)

	# Betrunken: geroetete Wangen
	if drunk > 0.45:
		var cheek := Palette.with_alpha(Color("ff5a5a"), (drunk - 0.45) * 0.5)
		Draw2D.ellipse(ci, Vector2(x - r * 0.45, y + r * 0.25), Vector2(r * 0.2, r * 0.13), cheek)
		Draw2D.ellipse(ci, Vector2(x + r * 0.45, y + r * 0.25), Vector2(r * 0.2, r * 0.13), cheek)

static func _draw_held_card(ci: CanvasItem, x: float, y: float, h: float) -> void:
	var w := h * 0.075
	var ch := w * 0.64
	# Die Karte liegt leicht gedreht in der Hand (ctx.rotate(-0.15)).
	var basis := Transform2D(-0.15, Vector2(x, y))
	var card := Draw2D.round_rect_points(Rect2(-w * 0.5, -ch * 0.5, w, ch), 2.0)
	var rotated := PackedVector2Array()
	for p: Vector2 in card:
		rotated.append(basis * p)
	Draw2D.fill_path(ci, rotated, Color("c9d2df"))

	var strip := PackedVector2Array([
		basis * Vector2(-w * 0.5 + 2.0, -ch * 0.5 + 2.0),
		basis * Vector2(-w * 0.5 + 2.0 + w * 0.3, -ch * 0.5 + 2.0),
		basis * Vector2(-w * 0.5 + 2.0 + w * 0.3, ch * 0.5 - 2.0),
		basis * Vector2(-w * 0.5 + 2.0, ch * 0.5 - 2.0),
	])
	Draw2D.fill_path(ci, strip, Color("8e99a8"))

## Kleines Portrait fuers Ausweisfoto.
static func draw_portrait(
	ci: CanvasItem, look: Dictionary, w: float, h: float, origin: Vector2 = Vector2.ZERO
) -> void:
	# Der lineare Hintergrundverlauf wird als Rechteck mit Farbe je Eckpunkt
	# gezeichnet - dasselbe Ergebnis ohne Textur.
	var top := Color("9aa6b6")
	var bottom := Color("6d7887")
	ci.draw_polygon(
		PackedVector2Array([
			origin, origin + Vector2(w, 0), origin + Vector2(w, h), origin + Vector2(0, h),
		]),
		PackedColorArray([top, top, bottom, bottom])
	)

	var skin: Color = Palette.SKIN[int(look.get("skin", 0)) % Palette.SKIN.size()]
	var hair: Color = Palette.HAIR[int(look.get("hair", 0)) % Palette.HAIR.size()]
	var outfit: Color = Palette.OUTFIT[int(look.get("outfit", 0)) % Palette.OUTFIT.size()]
	var cx := origin.x + w * 0.5
	var r := w * 0.29
	var cy := origin.y + h * 0.44

	# Schultern
	Draw2D.ellipse(ci, Vector2(cx, origin.y + h * 1.08), Vector2(w * 0.52, h * 0.42), outfit)

	draw_head(ci, cx, cy, r, skin, hair, look, "polite", 0.0, 0.0)
