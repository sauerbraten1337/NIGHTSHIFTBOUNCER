## Nimmt Bildschirmfotos des laufenden Spiels auf.
##
##   xvfb-run -a godot --path godot --script res://tools/screenshot.gd -- --out /pfad
##
## Ohne Bildschirm laeuft Godot nur headless, und headless zeichnet nichts -
## darum ein virtueller X-Server. Das Werkzeug startet die Hauptszene, laesst
## sie ein paar Sekunden laufen und legt Aufnahmen ab: Titelbildschirm, dann
## eine laufende Nacht.
extends SceneTree

var _out_dir := "user://shots"
var _game: Node = null
var _frame := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var main: PackedScene = load("res://scenes/Main.tscn")
	_game = main.instantiate()
	root.add_child(_game)
	print("Szene gestartet, Aufnahmen nach ", _out_dir)

## SceneTree._process liefert bool: true wuerde die Schleife beenden.
func _process(_delta: float) -> bool:
	_frame += 1

	# Titelbildschirm, sobald sich das Bild aufgebaut hat.
	if _frame == 40:
		_shot("01-titel")

	# In die Nacht wechseln: ohne Oberflaeche fuehrt go_briefing() direkt
	# hinein (siehe Game.gd).
	if _frame == 45:
		_game.call("go_briefing")

	if _frame == 120:
		_shot("02-nacht-solo")

	# Denselben Blick im lokalen Koop - der Splitscreen ist eine eigene
	# Zeichenpfad-Variante.
	if _frame == 125:
		_game.set("tutorial_wanted", false)
		var g: Dictionary = _game.get("game")
		(g["state"] as Dictionary)["night"] = null
		(g["state"] as Dictionary)["nightIndex"] = 0
		_game.call("apply_mode", "local")
		_game.call("go_briefing")

	if _frame == 220:
		_shot("03-nacht-koop")
		quit(0)
		return true

	return false

func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	var err := image.save_png(path)
	print("%s -> %s" % [name, "ok" if err == OK else "Fehler %d" % err])
