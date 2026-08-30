## Minimaler Event-Bus zur Entkopplung von Systemen, UI und Audio.
##
## Portierung von src/core/bus.js. Godot-Signale waeren die naheliegende
## Alternative, brauchen aber eine feste Deklaration je Ereignis; die
## Web-Fassung schickt frei benannte Ereignisse durch, und die UI haengt sich
## teils per '*' an alles. Darum bleibt der Bus als eigener Baustein.
class_name Bus
extends RefCounted

const ANY := "*"

var _handlers: Dictionary = {}

## Registriert einen Handler und liefert ein Callable zum Abmelden zurueck.
func on(type: String, fn: Callable) -> Callable:
	if not _handlers.has(type):
		_handlers[type] = []
	var list: Array = _handlers[type]
	if not list.has(fn):
		list.append(fn)
	return func() -> void: off(type, fn)

func off(type: String, fn: Callable) -> void:
	if not _handlers.has(type):
		return
	var list: Array = _handlers[type]
	list.erase(fn)

func emit(type: String, payload: Variant = null) -> void:
	if _handlers.has(type):
		# Ueber eine Kopie laufen: ein Handler darf sich selbst abmelden.
		for fn: Callable in (_handlers[type] as Array).duplicate():
			fn.call(payload)
	if _handlers.has(ANY):
		for fn: Callable in (_handlers[ANY] as Array).duplicate():
			fn.call({"type": type, "payload": payload})

func clear() -> void:
	_handlers.clear()
