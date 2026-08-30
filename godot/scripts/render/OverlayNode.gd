## Bildabschluss: Trennlinie im Splitscreen, Vignette, Scanlines.
##
## Liegt als letzter Knoten unter dem Renderer und traegt bewusst KEIN
## additives Material - anders als die Lichtebene.
extends Node2D

var renderer: Node = null
## x-Position der Splitscreen-Trennlinie, oder -1 wenn keine gezeichnet wird.
var split_at := -1.0
var vignette_strength := 0.5
var scanline_alpha := 0.03

func _draw() -> void:
	if split_at >= 0.0:
		draw_rect(Rect2(split_at - 1.0, 0.0, 4.0, Layout.WORLD.y), Color("05070b"))
	Effects.vignette(self, Layout.WORLD.x, Layout.WORLD.y, vignette_strength)
	Effects.scanlines(self, Layout.WORLD.x, Layout.WORLD.y, scanline_alpha)
