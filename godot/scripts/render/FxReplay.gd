## Spielt die additiven Zeichenbefehle einer Ansicht ab.
##
## Der Knoten traegt ein CanvasItemMaterial mit BLEND_MODE_ADD und liegt hinter
## seiner Quelle im Baum, damit sein _draw() nach deren _draw() laeuft und die
## Befehlsliste bereits gefuellt ist.
class_name FxReplay
extends Node2D

## Woher kommen die Befehle? Entweder ein StationView oder eine freie DrawList.
@export var source_path: NodePath
var list: DrawList = null
var offset := Vector2.ZERO

func _ready() -> void:
	material = Effects.additive_material()

func _draw() -> void:
	var target := list
	if target == null and not source_path.is_empty():
		var node := get_node_or_null(source_path)
		if node is StationView:
			target = (node as StationView).fx
	if target != null:
		target.replay(self, offset)
