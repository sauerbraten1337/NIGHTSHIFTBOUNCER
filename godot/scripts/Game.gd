## Einstiegspunkt: Spielfluss, Modi (Solo / lokaler Koop / Online-Koop),
## Eingaben, Rendering, Audio.
##
## Online-Modell: Der Host simuliert, der Gast schickt Aktionen und rendert
## Schnappschuesse. Alle Aktionen laufen durch dieselbe Funktion `act()`.
##
## Portierung von src/main.js. Der feste Zeitschritt aus core/loop.js entfaellt:
## Godot ruft _physics_process() bereits mit festem dt auf, _process() variabel
## fuers Zeichnen - genau die Aufteilung, die createLoop() nachgebaut hat.
class_name Game
extends Node2D

## Das Spielobjekt, wie es die Systeme erwarten: state, rng, bus, players.
## Bewusst ein Dictionary, damit alle portierten Systeme unveraendert damit
## arbeiten (siehe GameState.gd).
var game: Dictionary = {}

var input := GameInput.new()
var renderer: Renderer = null
var audio: GameAudio = null

var paused := false
var local_role := "bouncer"
var net_role: Variant = null  # null | 'host' | 'guest'
var tutorial_wanted := true

var _pending_event: Variant = null
var _snapshot_timer := 0.0

## Die Oberflaeche. `hud` und `screens` sind bewusst als Node getypt und
## werden ueber call()/get() angesprochen: so laesst sich die Zeichenkette
## auch ohne UI pruefen (z.B. in tools/screenshot.gd), indem man sie null
## laesst.
var hud: Node = null
var screens: Node = null
var idcard: IdCard = null
var item_tray: ItemTray = null
var rulebook: Rulebook = null
var admin_hud: AdminHud = null

func _ready() -> void:
	game = {
		"state": GameState.create_initial_state("solo"),
		"rng": Rng.new(),
		"bus": Bus.new(),
		"players": Coop.create_players("solo"),
	}

	renderer = Renderer.new()
	renderer.game = game
	add_child(renderer)

	audio = GameAudio.new()
	add_child(audio)

	var bus: Bus = game["bus"]
	bus.on("sfx", func(name: Variant) -> void: audio.sfx(String(name)))
	bus.on("nightEnd", func(_p: Variant) -> void: _on_night_end())
	bus.on("upgradeBought", func(result: Variant) -> void:
		if bool((result as Dictionary).get("tierChanged", false)):
			GameState.push_log(
				game["state"], "Club-Stufe %d erreicht" % int((result as Dictionary)["tier"]),
				"good"
			)
	)

	game["net"] = Net.new(bus)
	_wire_net(bus)
	_build_ui()

	Admin.restore_admin()
	apply_settings()
	Settings.apply_window()
	Settings.on_changed(func(_key: String) -> void: apply_settings())
	apply_mode("solo")
	go_menu()

## Ton, Bildeffekte und Tutorial folgen den Einstellungen - beim Start und bei
## jeder Aenderung im Einstellungsbildschirm. Das Fenster selbst stellt
## Settings.apply_window() ein; das passiert nur dort, wo es gebraucht wird.
func apply_settings() -> void:
	audio.set_master_volume(Settings.get_float("master"))
	audio.set_music_volume(Settings.get_float("music"))
	audio.set_sfx_volume(Settings.get_float("sfx"))
	audio.set_muted(Settings.get_bool("muted"))
	tutorial_wanted = Settings.get_bool("tutorial")

## Baut die Oberflaeche auf. Reihenfolge wie in index.html: die Handstuecke
## liegen im HUD, der Roentgenblick darueber auf einer eigenen Ebene.
func _build_ui() -> void:
	var h := Hud.new(self)
	add_child(h)
	hud = h

	var overlay := h.overlay_root()

	# Beide Handstuecke sitzen unten und wachsen nach oben, so hoch ihr Inhalt
	# ist - wie `bottom: …px` mit automatischer Hoehe in styles/ui.css.
	idcard = IdCard.new(self, "bouncer")
	idcard.anchor_left = 0.0
	idcard.anchor_top = 1.0
	idcard.anchor_right = 0.0
	idcard.anchor_bottom = 1.0
	idcard.offset_left = 44
	idcard.offset_bottom = -58
	idcard.grow_horizontal = Control.GROW_DIRECTION_END
	idcard.grow_vertical = Control.GROW_DIRECTION_BEGIN
	idcard.rotation = deg_to_rad(-2.4)
	overlay.add_child(idcard)

	item_tray = ItemTray.new(self, "security")
	item_tray.anchor_left = 0.5
	item_tray.anchor_top = 1.0
	item_tray.anchor_right = 0.5
	item_tray.anchor_bottom = 1.0
	item_tray.offset_bottom = -104
	item_tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	item_tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(item_tray)

	rulebook = Rulebook.new()
	overlay.add_child(rulebook)

	var s := Screens.new(self)
	add_child(s)
	screens = s

	# Der Roentgenblick gehoert nicht zur Schicht, sondern zum Testwerkzeug -
	# er bleibt auch sichtbar, wenn das HUD ausgeblendet ist.
	var admin_layer := CanvasLayer.new()
	admin_layer.layer = 3
	add_child(admin_layer)
	var admin_root := Control.new()
	admin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	admin_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	admin_layer.add_child(admin_root)
	admin_hud = AdminHud.new(self)
	admin_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	admin_hud.offset_left = -336
	admin_hud.offset_right = -16
	admin_hud.offset_top = 124
	admin_root.add_child(admin_hud)

# ---------------- Netzwerk ----------------

func _wire_net(bus: Bus) -> void:
	bus.on("net:room", func(payload: Variant) -> void:
		var p: Dictionary = payload
		net_role = p["role"]
		apply_mode("online")
		if screens != null:
			screens.call("lobby_set_room", String(p["code"]), String(p["role"]))
			screens.call("lobby_set_status", "Warte auf den Partner …" \
				if p["role"] == "host" else "Verbunden. Warte auf den Host …")
	)

	bus.on("net:peer", func(payload: Variant) -> void:
		var p: Dictionary = payload
		if bool(p.get("connected", false)):
			if screens != null:
				screens.call("lobby_set_status", "Partner ist da. Ihr könnt starten.", "ok")
				screens.call("lobby_show_start", is_host)
			if hud != null:
				hud.call("set_net", "ONLINE · PARTNER VERBUNDEN", false)
		else:
			if hud != null:
				hud.call("set_net", "HOST HAT DEN RAUM GESCHLOSSEN" \
					if bool(p.get("fatal", false)) else "PARTNER GETRENNT", true)
			if screens != null:
				screens.call("lobby_set_status", "Partner getrennt.", "bad")
				screens.call("lobby_show_start", false)
	)

	bus.on("net:error", func(reason: Variant) -> void:
		if screens != null:
			screens.call("lobby_set_status", String(reason), "bad")
	)

	bus.on("net:closed", func(_p: Variant) -> void:
		if game["state"]["mode"] == "online" and hud != null:
			hud.call("set_net", "VERBINDUNG GETRENNT", true)
	)

	# Host: Aktionen des Gastes anwenden.
	bus.on("net:action", func(payload: Variant) -> void:
		if not is_host:
			return
		var msg: Dictionary = payload
		if msg.get("role", "") != "security":
			return   # der Gast steuert nur die Schleuse
		for p: Dictionary in (game["players"] as Array):
			if p["id"] == "security":
				Coop.try_action(game, p, String(msg["code"]), msg.get("payload", {}))
				return
	)

	# Gast: Schnappschuss uebernehmen.
	bus.on("net:snapshot", func(data: Variant) -> void:
		if not is_guest or data == null:
			return
		var was_phase: String = game["state"]["phase"]
		Net.apply_snapshot(game, data, func(id: String) -> Dictionary: return role_by_id(id))
		var phase: String = game["state"]["phase"]
		if phase == "night" and was_phase != "night":
			if screens != null:
				screens.call("hide_screen")
			if hud != null:
				hud.call("show_hud")
			audio.start()
		elif phase != "night" and was_phase == "night":
			go_report()
	)

	bus.on("net:phase", func(payload: Variant) -> void:
		if not is_guest:
			return
		if (payload as Dictionary).get("phase", "") == "briefing" and screens != null:
			screens.call("waiting", "Der Host startet gleich die Schicht …")
	)

## Von ui/Screens.gd aus dem Lobby-Bildschirm gerufen.
func net_host() -> void:
	net_role = "host"
	if (game["net"] as Net).create_room():
		if screens != null:
			screens.call("lobby_set_status", "Raum wird erstellt …")
	elif screens != null:
		screens.call("lobby_set_status", "Server nicht erreichbar. Läuft \"npm start\"?", "bad")

func net_join(code: String) -> void:
	var trimmed := code.strip_edges()
	if trimmed.length() < 4:
		if screens != null:
			screens.call("lobby_set_status", "Bitte den 5-stelligen Code eingeben.", "bad")
		return
	net_role = "guest"
	if (game["net"] as Net).join_room(trimmed):
		if screens != null:
			screens.call("lobby_set_status", "Verbinde …")
	elif screens != null:
		screens.call("lobby_set_status", "Server nicht erreichbar.", "bad")

func net_start() -> void:
	(game["net"] as Net).send({"type": "phase", "phase": "briefing"})
	go_briefing()

func net_cancel() -> void:
	(game["net"] as Net).leave()
	go_menu()

# ---------------- Spielobjekt-Helfer (wie in main.js) ----------------

var is_guest: bool:
	get: return net_role == "guest"

var is_host: bool:
	get: return net_role == "host"

## Steuert dieser Client die Rolle?
func controls(role_id: String) -> bool:
	if game["state"]["mode"] != "online":
		return true
	return role_id == "security" if is_guest else role_id == "bouncer"

## Welche Station zeigt das Befund-Panel? Im Splitscreen die rechte (Schleuse).
var dossier_role: String:
	get:
		var mode: String = game["state"]["mode"]
		if mode == "local":
			return "security"
		if mode == "online":
			return local_role
		return "bouncer"

func role_by_id(id: String) -> Dictionary:
	var roles := Config.roles_for(game["state"]["mode"])
	for r: Dictionary in roles:
		if r["id"] == id:
			return r
	return roles[0]

## Station einer Rolle - funktioniert auch auf dem Schnappschuss des Gastes.
func station_for(role_id: String) -> Variant:
	var state: Dictionary = game["state"]
	var night: Variant = state["night"]
	if night == null:
		return null
	var stations: Dictionary = night["stations"]
	if GameState.is_solo(state):
		return stations["door"]
	return stations["airlock"] if role_id == "security" else stations["door"]

## Zentrale Aktionsschleuse: lokal ausfuehren oder zum Host schicken.
func act(role_id: String, code: String, payload: Dictionary = {}) -> void:
	if not controls(role_id):
		return
	if is_guest:
		if game.has("net") and game["net"] != null:
			(game["net"] as Net).send_action(role_id, code, payload)
		return
	for p: Dictionary in (game["players"] as Array):
		if p["id"] == role_id:
			Coop.try_action(game, p, code, payload)
			return

func save() -> bool:
	return false if is_guest else SaveGame.save_game(game["state"])

# ---------------- Modus / Spielfluss ----------------

func apply_mode(mode: String) -> void:
	var state: Dictionary = game["state"]
	state["mode"] = mode
	game["players"] = Coop.create_players(mode)
	local_role = "security" if is_guest else "bouncer"
	for p: Dictionary in (game["players"] as Array):
		p["remote"] = not controls(p["id"])
	if idcard != null:
		idcard.role_id = local_role
	# Der Kontrolltisch gehoert zu der Station, an der abgetastet wird.
	if item_tray != null:
		item_tray.role_id = "bouncer" if GameState.is_solo(state) else "security"
	if hud != null:
		hud.call("rebuild")

func go_menu() -> void:
	game["state"]["phase"] = "menu"
	game["state"]["night"] = null
	paused = false
	net_role = null
	if hud != null:
		hud.call("hide_hud")
	audio.set_intensity(0.25)
	if screens != null:
		screens.call("menu")

## Zurueck zum Titel - von ueberall aus. Eine laufende Nacht wird verworfen,
## ein offener Online-Raum verlassen; der Karrierestand bleibt gespeichert.
func quit_to_menu() -> void:
	if game["state"]["mode"] == "online" and game.has("net") and game["net"] != null:
		(game["net"] as Net).leave()
	paused = false
	_pending_event = null
	go_menu()

## Schicht vorzeitig abschliessen: Night Report wie am Ende einer Nacht.
func end_shift_now() -> void:
	paused = false
	if screens != null:
		screens.call("hide_screen")
	var night: Variant = game["state"]["night"]
	if night != null and bool((night as Dictionary).get("running", false)):
		NightCycle.end_night(game)
	else:
		go_report()

func go_briefing() -> void:
	var state: Dictionary = game["state"]
	state["phase"] = "briefing"
	if hud != null:
		hud.call("hide_hud")
	if is_guest:
		if screens != null:
			screens.call("waiting", "Der Host bereitet die Schicht vor …")
		return
	apply_mode(state["mode"])
	_pending_event = NightCycle.pick_night_event(game["rng"], state)
	var tutorial: bool = tutorial_wanted and not bool(state["tutorialDone"])
	if screens != null:
		screens.call("briefing", _pending_event, tutorial)
	else:
		begin_night(tutorial)

func begin_night(tutorial: bool) -> void:
	var state: Dictionary = game["state"]
	var artist: Variant = state["bookedArtist"]
	state["bookedArtist"] = null
	apply_mode(state["mode"])
	NightCycle.start_night(game, _pending_event, artist, {"tutorial": tutorial})
	if not tutorial:
		state["unlocks"] = {
			"id": true, "talk": true, "search": true, "alcohol": true, "calm": true,
		}
	if screens != null:
		screens.call("hide_screen")
	if hud != null:
		hud.call("show_hud")
	audio.start()
	audio.set_intensity(0.3)
	if is_host:
		_send_snapshot()

func go_report() -> void:
	if hud != null:
		hud.call("hide_hud")
	if is_guest:
		if screens != null:
			screens.call("waiting", "Der Host sieht sich den Night Report an …")
		return
	if screens != null:
		screens.call("report")
	else:
		go_office()

func go_office() -> void:
	game["state"]["phase"] = "office"
	if hud != null:
		hud.call("hide_hud")
	if screens != null:
		screens.call("office")

func _on_night_end() -> void:
	if is_guest:
		return
	var state: Dictionary = game["state"]
	var before := int(GameState.rank(state)["level"])
	var up: Variant = Progression.check_rank_up(state, before)
	if up != null:
		GameState.push_log(state, "Aufstieg: %s" % (up as Dictionary)["label"], "good")
	save()
	audio.set_intensity(0.2)
	go_report()

# ---------------- Schleifen ----------------

func _physics_process(delta: float) -> void:
	if game.has("net") and game["net"] != null:
		(game["net"] as Net).poll()
	var state: Dictionary = game["state"]
	if state["phase"] != "night" or paused:
		input.end_frame()
		return

	if is_guest:
		# Der Gast simuliert nicht - er schickt nur seine Eingaben.
		_read_guest_input()
		input.end_frame()
		return

	Coop.update_players(game, delta, input)
	NightCycle.update_night(game, delta)

	var night: Variant = state["night"]
	if night != null:
		var phase := NightCycle.current_phase(NightCycle.shift_progress(night))
		var load := minf(1.0, (night["queue"] as Array).size() / 14.0)
		audio.set_intensity(float(phase["intensity"]) * 0.75 + load * 0.25)

	if is_host:
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer = 0.08
			_send_snapshot()
	input.end_frame()

func _process(delta: float) -> void:
	renderer.render(delta)
	var state: Dictionary = game["state"]
	if state["phase"] == "night":
		if hud != null:
			hud.call("update_hud")
		if idcard != null:
			idcard.update_card()
		if item_tray != null:
			item_tray.update_tray()
	if admin_hud != null:
		admin_hud.update_admin()

## Eingaben des Gastes: direkt als Netzwerk-Aktion.
func _read_guest_input() -> void:
	var role := role_by_id("security")
	var station: Variant = station_for("security")

	# Uebergriff: es zaehlt nur noch die Abwehr, alles andere ist gesperrt.
	var aggro: Variant = station["aggro"] if station != null else null
	if aggro != null and aggro["phase"] != "over":
		for entry: Dictionary in Config.DEFENSE_KEYS:
			if input.just_pressed(entry["key"]):
				act("security", "defend", {"key": entry["key"]})
		return

	for action: Dictionary in (role["actions"] as Array):
		if input.just_pressed(action["key"]):
			act("security", action["code"])
	if station != null and station["patdown"] != null \
			and not bool((station["patdown"] as Dictionary)["complete"]):
		for entry: Dictionary in Config.PATDOWN_KEYS:
			if input.just_pressed(entry["key"]):
				act("security", "zone", {"zone": entry["zone"]})

func _send_snapshot() -> void:
	if not is_host or not game.has("net") or game["net"] == null:
		return
	var net: Net = game["net"]
	if not net.peer_ready:
		return
	net.send_snapshot(Net.serialize_state(game))

# ---------------- Maus: Abtast-Ringe direkt anklicken ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		# Abwehr geht auch mit der Maus - wer lieber klickt, ist nicht wehrlos.
		var key: Variant = _hit_at(renderer.key_hits, p)
		if key != null:
			act(key["role"], "defend", {"key": key["key"]})
			get_viewport().set_input_as_handled()
			return
		var zone: Variant = _hit_at(renderer.zone_hits, p)
		if zone != null:
			act(zone["role"], "zone", {"zone": zone["zone"]})
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_pause") and game["state"]["phase"] == "night" and not is_guest:
		toggle_pause()
	elif event.is_action_pressed("mute"):
		# Auch die Taste schreibt in die Einstellungen: sonst waere der Ton
		# beim naechsten Start wieder an.
		Settings.set_value("muted", audio.toggle_mute())

## Welcher Ring liegt unter dem Mauszeiger? (Ellipsentest wie in main.js)
func _hit_at(hits: Array, p: Vector2) -> Variant:
	if game["state"]["phase"] != "night" or paused:
		return null
	for hit: Dictionary in hits:
		var dx := (p.x - float(hit["x"])) / float(hit["rx"])
		var dy := (p.y - float(hit["y"])) / float(hit["ry"])
		if dx * dx + dy * dy <= 1.0:
			return hit
	return null

func toggle_pause() -> void:
	paused = not paused
	if screens == null:
		return
	if paused:
		screens.call("pause")
	else:
		screens.call("hide_screen")

# ---------------- Admin: Testhilfen aus dem Pausenmenue ----------------
#
# Die Eingriffe, die den Spielfluss betreffen. Der Schaltzustand liegt in
# systems/Admin.gd; hier steht nur, was beim Druck auf den Knopf passiert.

## Direkt ins Briefing der gewaehlten Nacht - die laufende Schicht faellt weg.
func admin_night(n: int) -> String:
	var number := Admin.admin_prepare_night(game["state"], n)
	paused = false
	tutorial_wanted = false
	if hud != null:
		hud.call("hide_hud")
	if screens != null:
		screens.call("hide_screen")
	go_briefing()
	return "Nacht %d vorbereitet." % number

func admin_money() -> String:
	Admin.admin_add_money(game["state"], 5000.0)
	return "Geld: €%d." % int(round(float(game["state"]["money"])))

func admin_rep() -> String:
	Admin.admin_set_reputation(game["state"], 100.0)
	return "Ruf auf 100 gesetzt."

func admin_unlock_all() -> String:
	Admin.admin_unlock_all(game["state"])
	if hud != null:
		hud.call("rebuild")
	return "Alle Kontrollen freigeschaltet."

func admin_shorten() -> String:
	var night: Variant = game["state"]["night"]
	if night == null:
		return "Keine laufende Schicht."
	var quota := Admin.admin_shorten_shift(game["state"], 3)
	return "Liste gekürzt: %d/%d." % [int(night["processed"]), quota]

## Uebergriff sofort ausloesen - zum Testen der Abwehr.
func admin_attack() -> String:
	var night: Variant = game["state"]["night"]
	if night == null:
		return "Niemand an der Kontrolle."
	var stations: Dictionary = night["stations"]
	for key: String in stations:
		var s: Dictionary = stations[key]
		if s["guest"] != null and not Aggression.aggression_active(s):
			Aggression.start_aggression(game, s, "idle")
			paused = false
			if screens != null:
				screens.call("hide_screen")
			return "Übergriff läuft."
	return "Niemand an der Kontrolle."

func admin_end_shift() -> String:
	var night: Variant = game["state"]["night"]
	if night == null or not bool(night["running"]):
		return "Keine laufende Schicht."
	paused = false
	GameState.add_toast(night, "ADMIN: SCHICHT BEENDET", "info")
	NightCycle.end_night(game)
	if screens != null:
		screens.call("hide_screen")
	return "Schicht beendet."
