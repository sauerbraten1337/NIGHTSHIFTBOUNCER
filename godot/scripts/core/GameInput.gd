## Tastatur-Input mit Edge-Detection (gedrueckt / gerade gedrueckt).
##
## Portierung von src/core/input.js. Godots Input-Singleton liefert
## is_action_pressed()/is_action_just_pressed() bereits; diese Huelle bildet
## darueber hinaus zwei Eigenheiten der Web-Fassung ab:
##
##  - `just_pressed()` liefert pro physischem Tastendruck genau EINMAL true,
##    auch wenn mehrere Systeme im selben Frame fragen (consumed-Menge),
##  - `set_enabled(false)` schaltet die Eingabe hart ab, ohne dass jeder
##    Aufrufer das selbst prueft (Screens, Pause, Netzwerk-Gastrolle).
class_name GameInput
extends RefCounted

var _consumed: Dictionary = {}
var _enabled: bool = true

func is_down(action: StringName) -> bool:
	if not _enabled:
		return false
	return Input.is_action_pressed(action)

## true genau einmal pro physischem Tastendruck.
func just_pressed(action: StringName) -> bool:
	if not _enabled:
		return false
	if not Input.is_action_just_pressed(action):
		return false
	if _consumed.has(action):
		return false
	_consumed[action] = true
	return true

func any_down(actions: Array) -> bool:
	for action: Variant in actions:
		if is_down(action):
			return true
	return false

## Am Ende jedes Frames aufrufen.
func end_frame() -> void:
	_consumed.clear()

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_consumed.clear()
