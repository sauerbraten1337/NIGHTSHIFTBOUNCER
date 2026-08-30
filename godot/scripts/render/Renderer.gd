## Renderer: baut das Bild aus einer oder zwei Stationsansichten auf.
##
##   solo / online  -> eine Ansicht (die eigene Station), Vollbild
##   lokaler Koop   -> Splitscreen: links Tuer (draussen), rechts Schleuse (innen)
##
## Dazu Nebel, Vignette und Scanlines.
##
## Portierung von src/render/renderer.js. Zwei Vereinfachungen gegenueber der
## Vorlage:
##
##  - Skalierung und Zentrierung des 1280x720-Bildes uebernimmt Godot ueber
##    window/stretch/mode="canvas_items". toWorld()/toScreen() aus der
##    Web-Fassung entfallen deshalb ersatzlos; Mausklicks kommen bereits in
##    Weltkoordinaten an (get_global_mouse_position).
##  - ctx.clip() pro Ansicht wird zu einem SubViewport je Ansicht. Das schneidet
##    ueberstehende Figuren im Splitscreen sauber ab, ohne dass der Zeichencode
##    davon wissen muss.
class_name Renderer
extends Node2D

## Wird von Game.gd gesetzt.
var game: Dictionary = {}

var fx := Effects.new()
var _beat_time := 0.0
var _time := 0.0

## Rechtecke der aktuellen Ansichten (Weltkoordinaten) - fuers UI-Layout.
var view_rects: Array = []
## Anklickbare Abtast-Ringe (Weltkoordinaten) - fuers Zeigen mit der Maus.
var zone_hits: Array = []
## Anklickbare Abwehr-Tasten waehrend eines Uebergriffs.
var key_hits: Array = []

var beat: float:
	get: return fmod(_beat_time, 1.0)

# Knoten, die einmal angelegt und danach nur noch umgehaengt werden.
var _views: Array[Dictionary] = []   # { container, viewport, main, fx, id }
var _title := Node2D.new()
var _title_fx := FxReplay.new()
var _title_fx_list := DrawList.new()
var _overlay := Node2D.new()
var _world_fx := FxReplay.new()
var _world_fx_list := DrawList.new()

func _ready() -> void:
	# Titelszene (eigener Knoten, damit sie ihr eigenes _draw hat)
	_title.set_script(preload("res://scripts/render/TitleNode.gd"))
	_title.set("renderer", self)
	add_child(_title)
	_title_fx.list = _title_fx_list
	add_child(_title_fx)

	# Nebel/Staub/Funken ueber allen Ansichten
	_world_fx.list = _world_fx_list
	add_child(_world_fx)

	# Vignette und Scanlines ganz oben
	_overlay.set_script(preload("res://scripts/render/OverlayNode.gd"))
	_overlay.set("renderer", self)
	add_child(_overlay)

## Jeden Frame aus Game.gd aufrufen.
func render(dt: float) -> void:
	if game.is_empty():
		return
	var state: Dictionary = game["state"]
	_time += dt
	fx.update(dt)

	var night: Variant = state["night"]
	var phase := {"intensity": 0.35, "label": "CLOSED"}
	if night != null:
		phase = NightCycle.current_phase(NightCycle.shift_progress(night))
	_beat_time += dt * (128.0 / 60.0) * (0.8 + float(phase["intensity"]) * 0.4)
	var pulse := pow(1.0 - fmod(_beat_time, 1.0), 3.0)

	# Titelbildschirm: eigene Schauszene mit Club, Schlange und Tuersteher.
	if night == null or state["phase"] != "night":
		zone_hits = []
		key_hits = []
		view_rects = []
		_set_view_count(0)
		_title.visible = true
		_title_fx.visible = true
		_title.set("time", _time)
		_title.set("pulse", pulse)
		_title.set("fx_list", _title_fx_list)
		_title.queue_redraw()
		_title_fx.queue_redraw()
		_world_fx.visible = false
		_overlay.set("vignette_strength", 0.55)
		_overlay.set("scanline_alpha", 0.03 if Settings.get_bool("effects") else 0.0)
		_overlay.queue_redraw()
		return

	_title.visible = false
	_title_fx.visible = false
	_world_fx.visible = true

	var blackout := false
	for e: Dictionary in (night["activeEffects"] as Array):
		if e["id"] == "blackout":
			blackout = true
			break
	var dark := 0.7 if blackout else 0.0

	var views := _layout_views()
	view_rects = views
	_set_view_count(views.size())

	var hits: Array = []
	var keys: Array = []
	for i in views.size():
		var view: Dictionary = views[i]
		var slot: Dictionary = _views[i]
		var rect: Rect2 = view["rect"]
		var container: SubViewportContainer = slot["container"]
		container.position = rect.position
		container.size = rect.size
		# Bei stretch=true bestimmt der Container die Groesse des SubViewports;
		# ihn selbst zu setzen quittiert Godot mit einer Warnung.

		var main: StationView = slot["main"]
		main.game = game
		main.opts = {
			"size": rect.size,
			"area": view["area"],
			"station": view["station"],
			"queue": view["queue"],
			"t": _time,
			"beat": beat,
			"pulse": pulse,
			"dark": dark,
		}
		main.queue_redraw()
		(slot["fx"] as FxReplay).queue_redraw()

		# Die Treffer der VORIGEN Zeichnung liegen bereits vor; sie in
		# Weltkoordinaten umrechnen reicht, weil sich zwischen zwei Frames
		# nichts sprunghaft verschiebt.
		for z: Dictionary in main.zones:
			var entry := z.duplicate()
			entry["x"] = float(z["x"]) + rect.position.x
			entry["y"] = float(z["y"]) + rect.position.y
			entry["role"] = view["role"]
			hits.append(entry)
		for k: Dictionary in main.keys:
			var entry_k := k.duplicate()
			entry_k["x"] = float(k["x"]) + rect.position.x
			entry_k["y"] = float(k["y"]) + rect.position.y
			entry_k["role"] = view["role"]
			keys.append(entry_k)
	zone_hits = hits
	key_hits = keys

	# Nebel, Staub, Funken ueber der ganzen Welt. Wer die Bildeffekte
	# abschaltet, spart genau diese Ebenen.
	var effects := Settings.get_bool("effects")
	_world_fx_list.clear()
	if effects:
		fx.draw_fog(_world_fx_list, 0.45 + float(phase["intensity"]) * 0.4)
		fx.draw_dust(_world_fx_list)
		fx.draw_sparks(_world_fx_list)
	_world_fx.queue_redraw()

	_overlay.set("split_at", views[0]["rect"].size.x if views.size() == 2 else -1.0)
	_overlay.set("vignette_strength", 0.9 if blackout else 0.5)
	_overlay.set("scanline_alpha", 0.03 if effects else 0.0)
	_overlay.queue_redraw()

## Welche Ansichten werden gezeigt?
func _layout_views() -> Array:
	var state: Dictionary = game["state"]
	var night: Dictionary = state["night"]
	var solo := GameState.is_solo(state)
	var local_coop: bool = state["mode"] == "local"
	var stations: Dictionary = night["stations"]

	var door_view := {
		"id": "outside", "area": "outside", "role": "bouncer",
		"station": stations["door"], "queue": night["queue"],
	}
	var airlock_view := {
		"id": "airlock", "area": "airlock", "role": "security",
		"station": stations["airlock"], "queue": night["airlockQueue"],
	}

	if solo:
		door_view["rect"] = Rect2(Vector2.ZERO, Layout.WORLD)
		return [door_view]
	if local_coop:
		var half := floorf(Layout.WORLD.x * 0.5)
		door_view["rect"] = Rect2(0, 0, half, Layout.WORLD.y)
		airlock_view["rect"] = Rect2(half + 3.0, 0, Layout.WORLD.x - half - 3.0, Layout.WORLD.y)
		return [door_view, airlock_view]
	# Online: jeder sieht nur seine eigene Station.
	var own := airlock_view if game.get("localRole", "bouncer") == "security" else door_view
	own["rect"] = Rect2(Vector2.ZERO, Layout.WORLD)
	return [own]

## Legt Ansichts-Knoten an oder blendet ueberzaehlige aus.
func _set_view_count(count: int) -> void:
	while _views.size() < count:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var viewport := SubViewport.new()
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally = false
		var main := StationView.new()
		var view_fx := FxReplay.new()
		viewport.add_child(main)
		viewport.add_child(view_fx)
		container.add_child(viewport)
		# Den Effektknoten erst nach dem Hinzufuegen verdrahten, damit der
		# Pfad aufloesbar ist.
		view_fx.source_path = view_fx.get_path_to(main)
		# Die Ansichten liegen unter der Titelszene, damit Nebel und Overlay
		# darueber bleiben.
		add_child(container)
		move_child(container, 0)
		_views.append({
			"container": container, "viewport": viewport, "main": main, "fx": view_fx,
		})
	for i in _views.size():
		(_views[i]["container"] as SubViewportContainer).visible = i < count
