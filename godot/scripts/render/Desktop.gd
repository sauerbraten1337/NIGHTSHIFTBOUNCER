## Hintergrundbild des Laptops - das "Wallpaper" von NIGHT//OS.
##
## Kein Foto, sondern gezeichnet wie der Rest des Spiels: Nachthimmel ueber
## der Stadt, ein Neon-Raster bis zum Horizont, die Silhouette des Clubs und
## ein leises Flackern der Roehre. Die Farbe des Rasters richtet sich nach der
## Club-Stufe, damit der Ausbau auch auf dem Desktop sichtbar wird.
##
## Portierung von src/render/desktop.js.
class_name Desktop
extends RefCounted

## Rasterfarbe je Club-Stufe: von kaltem Blau zu heissem Magenta.
const TIER_COLORS := [
	Color("2f6f8f"), Color("2f6f8f"), Color("2f8f9c"), Color("39d7ff"),
	Color("7a6cff"), Color("b45cff"), Color("ff4fa3"), Color("ff2f3c"),
]

static func tier_color(level: int) -> Color:
	return TIER_COLORS[clampi(level, 0, TIER_COLORS.size() - 1)]

## `fx` nimmt die additiven Anteile auf (Horizontschein).
static func draw_desktop(
	ci: CanvasItem, fx: Variant, w: float, h: float, t: float, tier: int = 1
) -> void:
	var accent := tier_color(tier)
	var horizon := h * 0.52

	_draw_sky(ci, fx, w, h, horizon, accent, t)
	_draw_skyline(ci, w, horizon, accent, t)
	_draw_grid(ci, w, h, horizon, accent, t)
	_draw_mark(ci, w, h, accent, t)
	_draw_scanlines(ci, w, h, t)

# ---------- Himmel ----------

static func _draw_sky(
	ci: CanvasItem, fx: Variant, w: float, h: float, horizon: float, accent: Color, t: float
) -> void:
	Draw2D.vgradient_rect(ci, Rect2(0, 0, w, horizon * 0.55), Color("05060c"), Color("0a0d1c"))
	Draw2D.vgradient_rect(
		ci, Rect2(0, horizon * 0.55, w, horizon * 0.45),
		Color("0a0d1c"), Palette.with_alpha(accent, 0.28)
	)
	Draw2D.vgradient_rect(
		ci, Rect2(0, horizon, w, h - horizon), Color("080a12"), Color("04050a")
	)

	# Sterne: fester Raster-Zufall, damit nichts springt.
	for i in 90:
		var x := float((i * 977) % 1000) / 1000.0 * w
		var y := float((i * 613) % 1000) / 1000.0 * horizon * 0.9
		var twinkle := 0.25 + 0.25 * sin(t * 1.4 + i)
		ci.draw_rect(
			Rect2(x, y, 1.5, 1.5), Palette.with_alpha(Palette.WHITE, twinkle * 0.5)
		)

	# Der Lichtschein ueber dem Horizont atmet.
	Effects.glow(
		fx, w * 0.5, horizon, w * 0.42, accent, 0.34 + 0.06 * sin(t * 0.8)
	)

# ---------- Stadt ----------

static func _draw_skyline(
	ci: CanvasItem, w: float, horizon: float, accent: Color, t: float
) -> void:
	var blocks := 26
	for i in blocks:
		var seed_v := float((i * 7919) % 100) / 100.0
		var bw := w / blocks
		var x := i * bw
		var bh := horizon * (0.12 + seed_v * 0.34)
		ci.draw_rect(Rect2(x, horizon - bh, bw - 2.0, bh), Color("070910"))

		# Fenster: ein paar leuchten, ein paar flackern mit.
		var fy := horizon - bh + 6.0
		while fy < horizon - 6.0:
			var fx_pos := x + 4.0
			while fx_pos < x + bw - 8.0:
				if fmod(fx_pos * 13.0 + fy * 7.0, 11.0) < 3.0:
					var flick := 0.35 + 0.25 * sin(t * 2.0 + fx_pos * 0.4 + fy)
					ci.draw_rect(
						Rect2(fx_pos, fy, 3, 3), Palette.with_alpha(accent, flick)
					)
				fx_pos += 7.0
			fy += 9.0

# ---------- Neon-Raster ----------

static func _draw_grid(
	ci: CanvasItem, w: float, h: float, horizon: float, accent: Color, t: float
) -> void:
	# Fluchtlinien
	var ray := Palette.with_alpha(accent, 0.3)
	for i in range(-14, 15):
		ci.draw_line(
			Vector2(w * 0.5 + i * (w * 0.035), horizon),
			Vector2(w * 0.5 + i * (w * 0.42), h),
			ray, 1.0, true
		)

	# Querlinien laufen auf den Betrachter zu.
	var speed := fmod(t * 0.25, 1.0)
	for i in 16:
		var p := pow((i + speed) / 16.0, 2.4)
		var y := horizon + (h - horizon) * p
		ci.draw_line(
			Vector2(0, y), Vector2(w, y), Palette.with_alpha(accent, 0.08 + 0.3 * p), 1.0, true
		)

	# Horizontkante
	ci.draw_line(
		Vector2(0, horizon), Vector2(w, horizon), Palette.with_alpha(accent, 0.85), 1.0, true
	)

# ---------- Logo-Wasserzeichen ----------

static func _draw_mark(ci: CanvasItem, w: float, h: float, accent: Color, t: float) -> void:
	var alpha := 0.10 + 0.02 * sin(t * 1.1)
	var color := Palette.with_alpha(accent, alpha)
	var center := Vector2(w * 0.5, h * 0.5)
	var width := maxf(2.0, w * 0.004)
	var r := minf(w, h) * 0.22

	Draw2D.ellipse_outline(ci, center, Vector2(r, r), color, width)
	Draw2D.stroke_path(ci, Draw2D.ellipse_points(
		center, Vector2(r * 0.68, r * 0.68), PI * 0.15, PI * 1.35
	), color, width)
	ci.draw_rect(
		Rect2(center.x - r * 0.5, center.y - r * 0.06, r, r * 0.12), color
	)

# ---------- Roehrenbild ----------

static func _draw_scanlines(ci: CanvasItem, w: float, h: float, t: float) -> void:
	var line := Color(0, 0, 0, 0.16)
	var y := 0.0
	while y < h:
		ci.draw_rect(Rect2(0, y, w, 1.0), line)
		y += 3.0

	# Ein heller Balken wandert langsam durchs Bild.
	var band := (fmod(t * 0.08, 1.3) - 0.15) * h
	var clear := Color(1, 1, 1, 0.0)
	var bright := Color(1, 1, 1, 0.035)
	Draw2D.vgradient_rect(ci, Rect2(0, band - h * 0.06, w, h * 0.06), clear, bright)
	Draw2D.vgradient_rect(ci, Rect2(0, band, w, h * 0.06), bright, clear)
