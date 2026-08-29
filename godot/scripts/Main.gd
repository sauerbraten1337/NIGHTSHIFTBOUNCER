## Platzhalterszene: zeichnet die Grundkulisse aus Layout.gd.
##
## Sie existiert, damit das Projekt nach dem Import sofort startet und man
## sieht, dass Koordinaten und Farben übernommen wurden. Der eigentliche
## Aufbau folgt in render/scene.js -> StationView.gd.
extends Node2D

func _draw() -> void:
	# Strasse und Clubblock
	draw_rect(Layout.STREET, Palette.ASPHALT)
	draw_rect(Layout.CLUB, Palette.CONCRETE)
	draw_rect(Layout.CLUB, Palette.CONCRETE_LIGHT, false, 2.0)

	# Innenbereiche als Umrisse
	for area: Rect2 in [Layout.DANCEFLOOR, Layout.FLOOR2, Layout.BAR, Layout.VIP]:
		draw_rect(area, Palette.with_alpha(Palette.PURPLE, 0.25), false, 2.0)

	# Türen
	draw_rect(Rect2(Layout.DOOR_X - Layout.DOOR_W * 0.5, Layout.DOOR_Y, Layout.DOOR_W, 12), Palette.RED)
	draw_rect(
		Rect2(Layout.BACK_DOOR_X - Layout.BACK_DOOR_W * 0.5, Layout.BACK_DOOR_Y, Layout.BACK_DOOR_W, 12),
		Palette.RED_DIM
	)

	# Stationen
	var font := ThemeDB.fallback_font
	for station: Dictionary in [Layout.STATION_DOOR, Layout.STATION_SEARCH]:
		var pos: Vector2 = station["pos"]
		draw_circle(pos, float(station["r"]), Palette.with_alpha(Palette.CYAN, 0.06))
		draw_arc(pos, float(station["r"]), 0.0, TAU, 64, Palette.with_alpha(Palette.CYAN, 0.5), 2.0)
		draw_string(
			font, pos + Vector2(-40, 6), String(station["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.WHITE
		)

	draw_string(
		font, Vector2(24, 40), "NULLWERK - Godot-Portierung, Gerüst",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.GREY
	)
