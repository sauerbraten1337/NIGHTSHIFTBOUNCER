## Aufgezeichnete Zeichenbefehle fuer eine spaetere Ebene.
##
## Warum das noetig ist: Die Web-Fassung schaltet mitten im Zeichnen auf
## globalCompositeOperation 'lighter' um und wieder zurueck. In Godot haengt
## der Mischmodus am CanvasItem, nicht am Aufruf - Licht und Nebel muessen
## also auf einem eigenen Knoten mit additivem Material landen. Godot erlaubt
## Zeichenaufrufe aber ausschliesslich innerhalb des _draw() genau dieses
## Knotens.
##
## DrawList loest das: Wo die Vorlage einen additiven Aufruf macht, bekommt
## der Zeichencode statt eines CanvasItem diese Liste. Sie merkt sich den
## Aufruf, und der Effektknoten spielt ihn in seinem eigenen _draw() ab.
## Die Methodennamen sind bewusst dieselben wie beim CanvasItem, damit
## derselbe Zeichencode mit beidem umgehen kann.
class_name DrawList
extends RefCounted

var _calls: Array = []

func clear() -> void:
	_calls.clear()

func is_empty() -> bool:
	return _calls.is_empty()

# ---------- Aufzeichnen (Signaturen wie bei CanvasItem) ----------

func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	_calls.append(["rect", rect, color, filled, width])

func draw_circle(position: Vector2, radius: float, color: Color) -> void:
	_calls.append(["circle", position, radius, color])

func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0,
		antialiased: bool = false) -> void:
	_calls.append(["line", from, to, color, width, antialiased])

func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0,
		antialiased: bool = false) -> void:
	_calls.append(["polyline", points, color, width, antialiased])

func draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	_calls.append(["polygon", points, colors])

func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	_calls.append(["colored_polygon", points, color])

func draw_texture_rect(texture: Texture2D, rect: Rect2, tile: bool = false,
		modulate: Color = Color(1, 1, 1, 1)) -> void:
	_calls.append(["texture_rect", texture, rect, tile, modulate])

func draw_string(font: Font, pos: Vector2, text: String,
		alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0,
		font_size: int = 16, modulate: Color = Color(1, 1, 1, 1)) -> void:
	_calls.append(["string", font, pos, text, alignment, width, font_size, modulate])

# ---------- Abspielen ----------

## Im _draw() des Zielknotens aufrufen. `offset` verschiebt alle Befehle -
## damit kann eine Ansicht ihre Effekte an der richtigen Stelle abspielen,
## obwohl sie in eigenen Koordinaten gezeichnet hat.
func replay(ci: CanvasItem, offset: Vector2 = Vector2.ZERO) -> void:
	for call: Array in _calls:
		match call[0]:
			"rect":
				ci.draw_rect(
					Rect2(call[1].position + offset, call[1].size), call[2], call[3], call[4]
				)
			"circle":
				ci.draw_circle(call[1] + offset, call[2], call[3])
			"line":
				ci.draw_line(call[1] + offset, call[2] + offset, call[3], call[4], call[5])
			"polyline":
				ci.draw_polyline(_shift(call[1], offset), call[2], call[3], call[4])
			"polygon":
				ci.draw_polygon(_shift(call[1], offset), call[2])
			"colored_polygon":
				ci.draw_colored_polygon(_shift(call[1], offset), call[2])
			"texture_rect":
				ci.draw_texture_rect(
					call[1], Rect2(call[2].position + offset, call[2].size), call[3], call[4]
				)
			"string":
				ci.draw_string(
					call[1], call[2] + offset, call[3], call[4], call[5], call[6], call[7]
				)

static func _shift(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if offset == Vector2.ZERO:
		return points
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p + offset)
	return out
