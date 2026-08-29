## Deterministischer PRNG (mulberry32) + Hilfsfunktionen.
##
## Portierung von src/core/rng.js. Bewusst NICHT durch RandomNumberGenerator
## ersetzt: derselbe Seed muss dieselbe Folge liefern wie die Web-Fassung,
## sonst laufen Host und Gast im Online-Koop auseinander und gespeicherte
## Seeds erzeugen andere Naechte.
class_name Rng
extends RefCounted

const UINT32 := 0xFFFFFFFF

var seed: int = 0
var _a: int = 0

func _init(initial_seed: int = -1) -> void:
	if initial_seed < 0:
		initial_seed = int(Time.get_unix_time_from_system() * 1000.0) & UINT32
	seed = initial_seed & UINT32
	_a = seed

## 32-Bit-Multiplikation mit Ueberlauf, entspricht Math.imul().
## Aufgeteilt in zwei 16-Bit-Haelften, damit das Zwischenprodukt nicht ueber
## den signierten 64-Bit-Bereich laeuft.
static func _imul(a: int, b: int) -> int:
	a &= UINT32
	b &= UINT32
	var a_lo := a & 0xFFFF
	var a_hi := (a >> 16) & 0xFFFF
	return ((a_lo * b) + (((a_hi * b) & 0xFFFF) << 16)) & UINT32

## Naechster Wert in [0, 1).
func next() -> float:
	_a = (_a + 0x6d2b79f5) & UINT32
	var t := _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & UINT32
	return float((t ^ (t >> 14)) & UINT32) / 4294967296.0

func range_float(minimum: float, maximum: float) -> float:
	return minimum + next() * (maximum - minimum)

func range_int(minimum: int, maximum: int) -> int:
	return int(floor(range_float(float(minimum), float(maximum + 1))))

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[mini(arr.size() - 1, int(floor(next() * arr.size())))]

## Gewichtete Auswahl. `weight_key` liest das Gewicht aus dem Element,
## fehlt der Schluessel, zaehlt das Element mit 1.
func weighted_pick(arr: Array, weight_key: String = "weight") -> Variant:
	var total := 0.0
	for item: Variant in arr:
		total += maxf(0.0, _weight_of(item, weight_key))
	if total <= 0.0:
		return pick(arr)
	var roll := next() * total
	for item: Variant in arr:
		roll -= maxf(0.0, _weight_of(item, weight_key))
		if roll <= 0.0:
			return item
	return arr[arr.size() - 1]

static func _weight_of(item: Variant, weight_key: String) -> float:
	if item is Dictionary and (item as Dictionary).has(weight_key):
		return float((item as Dictionary)[weight_key])
	return 1.0

func chance(p: float) -> bool:
	return next() < p

## clamp() und lerp() gibt es in GDScript bereits als clampf()/lerpf() -
## die JS-Helfer aus rng.js entfallen ersatzlos.
