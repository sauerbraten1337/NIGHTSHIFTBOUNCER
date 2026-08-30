## Schreibt die InputMap in project.godot.
##
## Von Hand serialisierte InputEventKey-Objekte in project.godot sind fehler-
## anfaellig; darum legt dieses Werkzeug sie ueber ProjectSettings an und
## laesst Godot selbst speichern:
##
##   godot --headless --path godot --script res://tools/write_input_map.gd
##
## Die Tastenbelegung entspricht src/data/config.js (KEYS_P1/KEYS_P2, die
## Aktionslisten in rolesFor(), PATDOWN_KEYS und DEFENSE_KEYS).
extends SceneTree

const BINDINGS := {
	# Spieler 1: WASD
	"p1_up": KEY_W,
	"p1_down": KEY_S,
	"p1_left": KEY_A,
	"p1_right": KEY_D,
	# Spieler 2: Pfeiltasten
	"p2_up": KEY_UP,
	"p2_down": KEY_DOWN,
	"p2_left": KEY_LEFT,
	"p2_right": KEY_RIGHT,
	# Aktionen Bouncer
	"act_1": KEY_1,
	"act_2": KEY_2,
	"act_3": KEY_3,
	"act_4": KEY_4,
	"act_5": KEY_5,
	"act_admit": KEY_E,
	"act_reject": KEY_X,
	# Ziffern 6, 9 und 0: im Solo greifen die Zifferntasten direkt in die
	# geoeffnete Abtast-Zone (siehe Coop.update_players), darum muessen alle
	# neun plus die Null belegt sein.
	"act_6": KEY_6,
	"act_9": KEY_9,
	"act_close_zone": KEY_0,
	# Aktionen Security
	"act_7": KEY_7,
	"act_8": KEY_8,
	"act_admit2": KEY_ENTER,
	"act_reject2": KEY_BACKSPACE,
	# Abtast-Zonen
	"zone_jacket": KEY_J,
	"zone_pockets": KEY_K,
	"zone_bag": KEY_L,
	# Abwehrtasten bei Uebergriffen
	"def_q": KEY_Q,
	"def_w": KEY_W,
	"def_e": KEY_E,
	"def_r": KEY_R,
	"def_a": KEY_A,
	"def_s": KEY_S,
	"def_d": KEY_D,
	"def_f": KEY_F,
	# Allgemein
	"ui_pause": KEY_ESCAPE,
	"notepad": KEY_N,
	"rulebook": KEY_H,
	"mute": KEY_M,
}

func _init() -> void:
	for action: String in BINDINGS:
		var path := "input/" + action
		var event := InputEventKey.new()
		event.physical_keycode = BINDINGS[action]
		ProjectSettings.set_setting(path, {
			"deadzone": 0.2,
			"events": [event],
		})
		ProjectSettings.set_initial_value(path, {"deadzone": 0.2, "events": []})
	var err := ProjectSettings.save()
	if err != OK:
		push_error("project.godot konnte nicht gespeichert werden: %d" % err)
	else:
		print("InputMap geschrieben: %d Aktionen" % BINDINGS.size())
	quit(0 if err == OK else 1)
