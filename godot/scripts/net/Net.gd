## Online-Koop: Raum erstellen / beitreten.
##
## Modell: Host-autoritativ. Der Host simuliert die Nacht und schickt ~12x pro
## Sekunde einen Schnappschuss; der Gast rendert daraus seine Schleusen-Ansicht
## und schickt nur seine Aktionen zurueck. So kann nichts auseinanderlaufen.
##
## Portierung von src/net/net.js. Die Web-Fassung spricht ueber einen
## WebSocket mit dem Relay in server/index.js. Godot bringt mit
## WebSocketPeer denselben Transport mit, also bleibt das Protokoll
## unveraendert - derselbe Server bedient beide Fassungen.
class_name Net
extends RefCounted

const DEFAULT_URL := "ws://localhost:8080/ws"

var _socket := WebSocketPeer.new()
var _bus: Bus = null
var _connected := false

var role: Variant = null   # 'host' | 'guest'
var code: Variant = null
var peer_ready := false
var status := "offline"
var url := DEFAULT_URL

func _init(bus: Bus, server_url: String = DEFAULT_URL) -> void:
	_bus = bus
	url = server_url

var connected: bool:
	get: return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

## Muss jeden Frame aufgerufen werden - WebSocketPeer pollt nicht selbst.
func poll() -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			status = "online"
		while _socket.get_available_packet_count() > 0:
			var raw := _socket.get_packet().get_string_from_utf8()
			var msg: Variant = JSON.parse_string(raw)
			if msg is Dictionary:
				_route(msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			status = "offline"
			peer_ready = false
			_bus.emit("net:closed")

func _connect_socket() -> bool:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return true
	status = "connecting"
	var err := _socket.connect_to_url(url)
	if err != OK:
		status = "error"
		_bus.emit("net:error", "Verbindung fehlgeschlagen")
		return false
	return true

func _route(msg: Dictionary) -> void:
	match msg.get("type", ""):
		"room":
			code = msg["code"]
			role = msg["role"]
			_bus.emit("net:room", {"code": code, "role": role})
		"peerJoined":
			peer_ready = true
			_bus.emit("net:peer", {"connected": true})
		"peerLeft":
			peer_ready = false
			_bus.emit("net:peer", {
				"connected": false, "fatal": bool(msg.get("fatal", false)),
			})
		"error":
			_bus.emit("net:error", msg.get("reason", ""))
		"snapshot":
			_bus.emit("net:snapshot", msg.get("data", null))
		"action":
			_bus.emit("net:action", msg)
		"phase":
			_bus.emit("net:phase", msg)
		"chat":
			_bus.emit("net:chat", msg)

func create_room() -> bool:
	if not _connect_socket():
		return false
	_queue_after_open({"type": "create"})
	return true

func join_room(room_code: String) -> bool:
	if not _connect_socket():
		return false
	_queue_after_open({"type": "join", "code": room_code.to_upper().strip_edges()})
	return true

## Nachrichten, die vor dem Verbindungsaufbau abgeschickt werden, warten hier.
## Die Web-Fassung loest das mit await auf das open-Ereignis.
var _pending: Array[Dictionary] = []

func _queue_after_open(msg: Dictionary) -> void:
	if connected:
		send(msg)
	else:
		_pending.append(msg)

## Aus poll() heraus aufrufen, sobald die Verbindung steht.
func _flush_pending() -> void:
	if not connected or _pending.is_empty():
		return
	for msg: Dictionary in _pending:
		send(msg)
	_pending.clear()

func send(msg: Dictionary) -> void:
	if connected:
		_socket.send_text(JSON.stringify(msg))

func send_action(role_id: String, action_code: String, payload: Dictionary) -> void:
	send({"type": "action", "role": role_id, "code": action_code, "payload": payload})

func send_snapshot(data: Dictionary) -> void:
	send({"type": "snapshot", "data": data})

func leave() -> void:
	send({"type": "leave"})
	_socket.close()
	role = null
	code = null
	peer_ready = false
	status = "offline"
	_connected = false
	_pending.clear()

# ------------------------------------------------------------------
# Schnappschuss: nur, was der Gast zum Spielen und Anzeigen braucht.
# Die versteckte Wahrheit ueber Gaeste bleibt beim Host.
# ------------------------------------------------------------------

static func serialize_state(game: Dictionary) -> Dictionary:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]

	var night_data: Variant = null
	if night != null:
		var queue: Array = night["queue"]
		var queue_view: Array = []
		for i in mini(9, queue.size()):
			queue_view.append(_view_guest(queue[i]))
		var airlock_view: Array = []
		for g: Dictionary in (night["airlockQueue"] as Array):
			airlock_view.append(_view_guest(g))
		var tutorial_step: Variant = null
		if night["tutorial"] != null:
			tutorial_step = (night["tutorial"] as Dictionary)["step"]

		night_data = {
			"clock": night["clock"],
			"quota": night["quota"],
			"processed": night["processed"],
			"running": night["running"],
			"event": night["event"],
			"artist": night["artist"],
			"stats": night["stats"],
			"activeEffects": night["activeEffects"],
			"toasts": night["toasts"],
			"queueLength": queue.size(),
			"queue": queue_view,
			"airlockQueue": airlock_view,
			"insideCount": (night["inside"] as Array).size(),
			"tutorialStep": tutorial_step,
			"stations": {
				"door": _view_station((night["stations"] as Dictionary)["door"]),
				"airlock": _view_station((night["stations"] as Dictionary)["airlock"]),
			},
		}

	var players: Array = []
	for p: Dictionary in (game["players"] as Array):
		players.append({
			"id": p["id"], "busy": p["busy"], "busyTotal": p["busyTotal"],
			"busyLabel": p["busyLabel"], "lastResult": p["lastResult"], "flash": p["flash"],
		})

	return {
		"mode": state["mode"],
		"phase": state["phase"],
		"money": state["money"],
		"reputation": state["reputation"],
		"upgrades": state["upgrades"],
		"talents": state["talents"],
		"unlocks": state["unlocks"],
		"nightIndex": state["nightIndex"],
		"xp": state["xp"],
		"night": night_data,
		"players": players,
	}

static func _view_guest(guest: Variant) -> Variant:
	if guest == null:
		return null
	var t: Dictionary = guest["truth"]
	return {
		"id": guest["id"],
		"name": guest["name"],
		"archetypeLabel": guest["archetypeLabel"],
		"personality": guest["personality"],
		"look": guest["look"],
		"doc": guest["doc"],
		"said": guest["said"],
		"saidTimer": guest["saidTimer"],
		"isArtist": bool(guest.get("isArtist", false)),
		"swayPhase": guest["swayPhase"],
		"walkPhase": guest["walkPhase"],
		"patience": guest["patience"],
		"patienceMax": guest["patienceMax"],
		"doorVerdict": guest.get("doorVerdict", null),
		# Nur, was man sehen kann - keine versteckten Verstoesse.
		"truth": {
			"drunk": t["drunk"],
			"vip": t["vip"],
			"hasBag": t["hasBag"],
			# Sichtbare Anzeichen gehoeren zum Bild, nicht zur versteckten Wahrheit.
			"impairmentSigns": t.get("impairmentSigns", []),
		},
	}

static func _view_station(station: Dictionary) -> Dictionary:
	return {
		"id": station["id"],
		"guest": _view_guest(station["guest"]),
		"checks": _view_checks(station["checks"]),
		"patdown": station["patdown"],
		"notes": station["notes"],
		# Uebergriff: der Gast am anderen Rechner muss dieselben Tasten sehen.
		"aggro": station["aggro"],
	}

## Die Wahrheit bleibt auf dem Host: weder die echten Ausweisfehler noch die
## Information, welche Aussage gelogen war, gehen ueber die Leitung.
static func _view_checks(checks: Dictionary) -> Dictionary:
	var out := checks.duplicate()
	if checks["id"] != null:
		var id_view := (checks["id"] as Dictionary).duplicate()
		id_view.erase("faults")
		out["id"] = id_view
	if checks["talk"] != null:
		var talk_view := (checks["talk"] as Dictionary).duplicate()
		var said: Array = []
		for s: Dictionary in ((checks["talk"] as Dictionary).get("said", []) as Array):
			said.append({"id": s["id"], "text": s["text"]})
		talk_view["said"] = said
		out["talk"] = talk_view
	return out

## Baut aus einem Schnappschuss ein Objekt, das sich fuer Renderer und HUD
## wie ein echtes Spiel verhaelt (nur eben ohne Simulation).
static func apply_snapshot(game: Dictionary, data: Dictionary, roles_source: Callable) -> Dictionary:
	var state: Dictionary = game["state"]
	state["mode"] = data["mode"]
	state["phase"] = data["phase"]
	state["money"] = data["money"]
	state["reputation"] = data["reputation"]
	state["upgrades"] = data["upgrades"]
	state["talents"] = data["talents"]
	state["unlocks"] = data["unlocks"]
	state["nightIndex"] = data["nightIndex"]
	state["xp"] = data["xp"]

	if data["night"] == null:
		state["night"] = null
		return game

	var n: Dictionary = data["night"]
	var inside: Array = []
	for i in int(n["insideCount"]):
		inside.append(0)
	state["night"] = {
		"clock": n["clock"],
		"quota": n["quota"],
		"processed": n["processed"],
		"running": n["running"],
		"event": n["event"],
		"artist": n["artist"],
		"stats": n["stats"],
		"activeEffects": n["activeEffects"],
		"toasts": n["toasts"],
		"queue": n["queue"],
		"queueLength": n["queueLength"],
		"airlockQueue": n["airlockQueue"],
		"inside": inside,
		"leaving": [],
		"stations": n["stations"],
		"tutorial": {"step": n["tutorialStep"]} if n["tutorialStep"] != null else null,
	}

	var players: Array = []
	for p: Dictionary in (data["players"] as Array):
		var entry := p.duplicate()
		# Der Bereich muss mitkommen, sonst landen Rolle, Panel und
		# Aktionsleiste beim Gast im falschen Bereich.
		var role: Dictionary = roles_source.call(p["id"])
		entry["role"] = role
		entry["area"] = role["area"]
		players.append(entry)
	game["players"] = players
	return game
