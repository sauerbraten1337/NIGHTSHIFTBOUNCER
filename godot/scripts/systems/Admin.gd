## Admin-Zugang: Testhilfen hinter einem Code.
##
## Gedacht zum Pruefen des Spiels, nicht zum Spielen: mit dem richtigen Code
## lassen sich im Pausenmenue die Nacht frei waehlen und ein paar Schalter
## umlegen (kein Uebergriff, sofortige Aktionen, Wahrheit einblenden).
##
## Bewusst ohne Knoten und ohne Spielfluss-Aufrufe - die Schalter stehen hier,
## gedrueckt werden sie in ui/Screens.gd, ausgefuehrt in Game.gd.
##
## Portierung von src/systems/admin.js. Die Web-Fassung haelt den
## Freischaltzustand im sessionStorage, damit er einen Reload ueberdauert;
## eine laufende Godot-Instanz ist selbst die Sitzung, darum genuegen hier
## statische Felder.
class_name Admin
extends RefCounted

const ADMIN_CODE := "cig1337"

## Bis zu welcher Nacht darf im Menue gesprungen werden?
const ADMIN_MAX_NIGHT := 40

## Der Schaltzustand. Die Spiellogik liest ihn direkt, ohne dass er durch den
## Spielstand oder ueber das Netz wandern muss.
static var unlocked := false
## Niemand rastet mehr aus - die Abwehr-Sequenz bleibt aus.
static var no_aggro := false
## Kontrollen dauern praktisch keine Zeit mehr.
static var fast_actions := false
## Blendet die versteckte Wahrheit des Gastes ein.
static var reveal := false

static func restore_admin() -> bool:
	return unlocked

static func unlock_admin(code: String) -> bool:
	if code.strip_edges().to_lower() != ADMIN_CODE:
		return false
	unlocked = true
	return true

## Sperren heisst: alle Schalter zurueck auf Aus.
static func lock_admin() -> void:
	unlocked = false
	no_aggro = false
	fast_actions = false
	reveal = false

static func set_cheat(id: String, on: bool) -> bool:
	if not unlocked:
		return false
	match id:
		"noAggro":
			no_aggro = on
			return no_aggro
		"fastActions":
			fast_actions = on
			return fast_actions
		"reveal":
			reveal = on
			return reveal
		_:
			return false

static func get_cheat(id: String) -> bool:
	match id:
		"noAggro": return no_aggro
		"fastActions": return fast_actions
		"reveal": return reveal
		"unlocked": return unlocked
		_: return false

# ---------- Eingriffe in den Spielstand ----------

static func admin_add_money(state: Dictionary, amount: float = 5000.0) -> float:
	state["money"] = roundf(float(state["money"]) + amount)
	return state["money"]

static func admin_set_reputation(state: Dictionary, value: float = 100.0) -> float:
	state["reputation"] = clampf(value, 0.0, 100.0)
	return state["reputation"]

## Alle Kontrollen freigeben (sonst gibt das Tutorial sie nacheinander frei).
static func admin_unlock_all(state: Dictionary) -> Dictionary:
	state["unlocks"] = {"id": true, "talk": true, "search": true, "alcohol": true, "calm": true}
	state["tutorialDone"] = true
	return state["unlocks"]

## Nachtnummer vorbereiten: die naechste gestartete Schicht ist Nacht `n`.
## Die laufende Nacht wird dabei verworfen - der Aufrufer schickt danach ins
## Briefing (siehe Game.gd).
static func admin_prepare_night(state: Dictionary, n: int) -> int:
	var night := int(clampf(float(n), 1.0, float(ADMIN_MAX_NIGHT)))
	if state["night"] != null:
		(state["night"] as Dictionary)["running"] = false
	state["night"] = null
	state["nightIndex"] = night - 1
	admin_unlock_all(state)
	return night

## Die Gaesteliste kuerzen: nur noch so viele Leute bis Schichtende.
static func admin_shorten_shift(state: Dictionary, remaining: int = 3) -> int:
	var night: Variant = state["night"]
	if night == null:
		return 0
	var processed: int = night["processed"]
	night["quota"] = maxi(processed + 1, processed + remaining)
	return night["quota"]
