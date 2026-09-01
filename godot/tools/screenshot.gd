## Nimmt Bildschirmfotos des laufenden Spiels auf.
##
##   xvfb-run -a godot --path godot --script res://tools/screenshot.gd -- --out /pfad
##
## Ohne Bildschirm laeuft Godot nur headless, und headless zeichnet nichts -
## darum ein virtueller X-Server. Das Werkzeug startet die Hauptszene und
## laeuft den ganzen Spielfluss ab: Titel, Charaktereditor, Briefing, Nacht
## (solo und Koop), Nachtabschluss, Buero und Laptop.
extends SceneTree

var _out_dir := "user://shots"
var _game: Node = null
var _frame := 0

## Was wann passiert. Erst der Schritt, dann - ein paar Bilder spaeter -
## die Aufnahme, damit sich die Oberflaeche aufbauen kann.
var _plan: Array = []
var _step := 0

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

	_plan = [
		[40, func() -> void: _shot("01-titel")],
		# Einstellungen: eigener Bildschirm mit Bild, Ton, Spiel und Daten.
		[45, func() -> void: _screens().call("settings")],
		[60, func() -> void: _shot("01b-einstellungen")],
		[64, func() -> void: _screens().call("menu")],
		[70, func() -> void: _screens().call("character", func() -> void: pass)],
		[80, func() -> void: _shot("02-charaktereditor")],
		[90, func() -> void:
			_game.set("tutorial_wanted", false)
			_game.call("go_briefing")],
		[120, func() -> void: _shot("03-briefing")],
		[130, func() -> void: _game.call("begin_night", false)],
		[210, func() -> void: _shot("04-nacht-solo")],
		# Ausweis und Abtasten ausloesen, damit Ausweiskarte und Kontrolltisch
		# im Bild sind - beide erscheinen erst, wenn danach gefragt wurde.
		[212, func() -> void:
			_game.call("act", "bouncer", "id")
			_game.call("act", "bouncer", "search")],
		[216, func() -> void: _game.call("act", "bouncer", "zone", {"zone": "jacket"})],
		[250, func() -> void: _shot("04b-nacht-ausweis")],
		# Der Roentgenblick des Testzugangs - er zeigt die Wahrheit des Gastes.
		[252, func() -> void:
			Admin.unlock_admin(Admin.ADMIN_CODE)
			Admin.set_cheat("reveal", true)],
		[258, func() -> void: _shot("04c-roentgenblick")],
		[260, func() -> void: Admin.lock_admin()],
		[265, func() -> void: _game.call("toggle_pause")],
		[280, func() -> void: _shot("05-pause")],
		# Dasselbe Menue mit freigeschaltetem Testzugang - die Cheat-Schalter.
		[282, func() -> void:
			Admin.unlock_admin(Admin.ADMIN_CODE)
			Admin.set_cheat("reveal", true)
			_screens().call("pause")],
		[288, func() -> void: _shot("05b-pause-admin")],
		[290, func() -> void: Admin.lock_admin()],
		[292, func() -> void: _game.call("toggle_pause")],
		# Nachtabschluss: die Schicht abbrechen wie der Admin-Knopf.
		[294, func() -> void: _game.call("admin_end_shift")],
		# Der Admin-Knopf schliesst zuletzt den Bildschirm - fuer die Aufnahme
		# den Nachtabschluss danach noch einmal aufrufen.
		[300, func() -> void: _game.call("go_report")],
		[340, func() -> void: _shot("06-nachtabschluss")],
		[345, func() -> void: _game.call("go_office")],
		[380, func() -> void: _shot("07-buero")],
		[385, func() -> void: _screens().call("shop")],
		[440, func() -> void: _shot("08-laptop")],
		# Derselbe Blick im lokalen Koop - der Splitscreen ist eine eigene
		# Zeichenpfad-Variante.
		[450, func() -> void:
			var g: Dictionary = _game.get("game")
			(g["state"] as Dictionary)["night"] = null
			(g["state"] as Dictionary)["nightIndex"] = 0
			_game.call("apply_mode", "local")
			_game.call("go_briefing")],
		[480, func() -> void: _game.call("begin_night", false)],
		[560, func() -> void:
			_shot("09-nacht-koop")
			quit(0)],
	]

func _screens() -> Node:
	return _game.get("screens")

## SceneTree._process liefert bool: true wuerde die Schleife beenden.
func _process(_delta: float) -> bool:
	_frame += 1
	while _step < _plan.size() and int(_plan[_step][0]) <= _frame:
		(_plan[_step][1] as Callable).call()
		_step += 1
	return false

func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	var err := image.save_png(path)
	print("%s -> %s" % [name, "ok" if err == OK else "Fehler %d" % err])
