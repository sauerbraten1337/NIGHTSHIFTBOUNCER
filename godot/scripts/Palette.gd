## Farbwelt: Beton, Nacht, rote Warnlichter, kaltes Neon.
##
## Portierung von src/render/palette.js. Die Werte sind bewusst identisch,
## damit die Godot-Fassung neben der Web-Version gleich aussieht.
class_name Palette
extends RefCounted

const NIGHT := Color("090b10")
const ASPHALT := Color("151922")
const ASPHALT_LIGHT := Color("1d232e")
const CONCRETE := Color("272d38")
const CONCRETE_DARK := Color("1a1f28")
const CONCRETE_LIGHT := Color("39414f")
const LINE := Color("39414f")
const RED := Color("ff2f3c")
const RED_DIM := Color("8c1620")
const CYAN := Color("39d7ff")
const AMBER := Color("ffb638")
const GREEN := Color("4ce08a")
const WHITE := Color("e8ecf2")
const GREY := Color("8b93a1")
const PURPLE := Color("8b5cff")

const SKIN: Array[Color] = [
	Color("f0c9a4"), Color("dfa87a"), Color("c3855c"),
	Color("9a6440"), Color("71462b"), Color("4e3020"),
]

const OUTFIT: Array[Color] = [
	Color("1c1f26"), Color("24262e"), Color("2b1f2f"), Color("12232b"),
	Color("33202a"), Color("1a2a1f"), Color("2e2a1c"), Color("202433"),
]

const HAIR: Array[Color] = [
	Color("141519"), Color("2b2019"), Color("4a3524"),
	Color("6b6f78"), Color("8e2f3a"), Color("243a52"), Color("d8d3c8"),
]

## Ersetzt withAlpha() aus der JS-Fassung - in Godot trägt die Farbe
## den Alphakanal bereits, ein String-Umbau entfällt.
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
