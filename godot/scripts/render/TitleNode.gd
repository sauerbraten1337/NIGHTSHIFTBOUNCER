## Traegerknoten fuer die Titelszene.
##
## Title.gd zeichnet, dieser Knoten haelt nur den Zeitpunkt und die
## Effektliste - siehe Renderer.gd.
extends Node2D

var renderer: Node = null
var time := 0.0
var pulse := 0.0
var fx_list: DrawList = null

func _draw() -> void:
	if fx_list == null:
		return
	fx_list.clear()
	Title.draw_title_scene(self, fx_list, Layout.WORLD.x, Layout.WORLD.y, time, pulse)
