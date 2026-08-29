## Eine Stationsansicht (Tuer oder Schleuse) als eigener Knoten.
##
## Zeichnet ueber Scene.draw_station_view(). Die additiven Anteile (Licht,
## Glow) landen in einer DrawList, die der Geschwisterknoten StationFx in
## seinem eigenen _draw() abspielt - siehe DrawList.gd.
class_name StationView
extends Node2D

## Wird von Renderer.gd vor jedem Neuzeichnen gesetzt.
var game: Dictionary = {}
var opts: Dictionary = {}

## Additive Befehle dieser Ansicht.
var fx := DrawList.new()

## Ergebnis des letzten Zeichnens: anklickbare Ringe und Abwehrtasten.
var zones: Array = []
var keys: Array = []

func _draw() -> void:
	fx.clear()
	zones = []
	keys = []
	if game.is_empty() or opts.is_empty():
		return
	var result := Scene.draw_station_view(self, fx, game, opts)
	zones = result["zones"]
	keys = result["keys"]
