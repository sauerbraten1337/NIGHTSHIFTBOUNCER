## Zentrale Tuning-Werte, Datentabellen und Balancing-Konstanten.
##
## Portierung von src/data/config.js. Reines Daten-Modul: keine Knoten, keine
## Seiteneffekte. Werte sind unveraendert uebernommen.
class_name Config
extends RefCounted

const CLUB_NAME := "NULLWERK"

const TUNING := {
	# Die Nacht endet NICHT nach Zeit, sondern wenn die Schicht abgearbeitet ist.
	# Die Uhr laeuft nur noch im Hintergrund fuer Stimmung, Musik und Ereignisse.
	"nightStartMinute": 0,
	"nightEndMinute": 300,
	"minutesPerSecond": 0.8,

	# So viele Gaeste muessen pro Nacht abgefertigt werden.
	"guestsPerNight": 16,
	"guestsPerNightGrowth": 2,
	"guestsPerNightMax": 40,

	# Praemie fuer jede selbst gefundene Unregelmaessigkeit.
	"findingBonus": 35,

	"baseEntryFee": 12,
	"baseCapacity": 120,
	"baseQueueCapacity": 22,

	# Dauer der Aktionen in Sekunden (Basis, wird durch Talente/Upgrades gesenkt).
	"actionTime": {
		"id": 1.6,
		"talk": 1.2,
		"scan": 1.4,
		"search": 0.9,
		"bag": 1.5,
		"pick": 0.35,
		"alcohol": 1.3,
		"calm": 1.0,
		"admit": 0.6,
		"reject": 0.6,
	},

	"patienceBase": 78,
	"drunkRejectThreshold": 0.72,
	"minAge": 18,

	"reputationStart": 42,
	"moneyStart": 400,

	# Wirtschaft
	"barSpendPerGuestPerMinute": 0.16,
	"incidentBaseCost": 90,
	"fineUnderage": 320,
}

## Spielmodi. Im Solo-Modus uebernimmt der Bouncer alle Aufgaben und es gibt
## keinen getrennten Security-Bereich.
const MODES := {
	"solo": {
		"id": "solo", "label": "SOLO",
		"desc": "Du machst Tuer und Kontrolle allein. Kein Security-Bereich.",
	},
	"local": {
		"id": "local", "label": "LOKALER KOOP",
		"desc": "Zwei Spieler an einer Tastatur, Splitscreen.",
	},
	"online": {
		"id": "online", "label": "ONLINE-KOOP",
		"desc": "Raum erstellen oder beitreten, jeder an seinem Rechner.",
	},
}

## Bereiche: der Bouncer arbeitet draussen, die Security in der Schleuse.
const AREAS := {
	"outside": {"id": "outside", "label": "EINGANG", "sub": "DRAUSSEN"},
	"airlock": {
		"id": "airlock", "label": "SICHERHEITSSCHLEUSE", "sub": "INNEN, VOR DEM CLUB",
	},
}

## Bewegungstasten je Spieler. Die Namen sind InputMap-Actions, angelegt in
## project.godot - der Web-Fassung entsprechen sie WASD bzw. den Pfeiltasten.
const KEYS_P1 := {"up": "p1_up", "down": "p1_down", "left": "p1_left", "right": "p1_right"}
const KEYS_P2 := {"up": "p2_up", "down": "p2_down", "left": "p2_left", "right": "p2_right"}

## Rollen je nach Modus.
## `pass` schickt den Gast in die Schleuse (nur Koop),
## `admit` laesst endgueltig in den Club.
static func roles_for(mode: String) -> Array[Dictionary]:
	if mode == "solo":
		return [{
			"id": "bouncer", "label": "BOUNCER", "accent": Color("ff3b3b"),
			"area": "outside", "solo": true, "keys": KEYS_P1,
			"actions": [
				{"key": "act_1", "code": "id", "label": "AUSWEIS"},
				{"key": "act_2", "code": "talk", "label": "ANSPRECHEN"},
				{"key": "act_3", "code": "search", "label": "ABTASTEN"},
				{"key": "act_4", "code": "alcohol", "label": "ALKOTEST"},
				{"key": "act_5", "code": "calm", "label": "SCHLANGE"},
				{"key": "act_admit", "code": "admit", "label": "EINLASSEN"},
				{"key": "act_reject", "code": "reject", "label": "ABWEISEN"},
			],
		}]
	return [
		{
			"id": "bouncer", "label": "BOUNCER", "accent": Color("ff3b3b"),
			"area": "outside", "solo": false, "keys": KEYS_P1,
			"actions": [
				{"key": "act_1", "code": "id", "label": "AUSWEIS"},
				{"key": "act_2", "code": "talk", "label": "ANSPRECHEN"},
				{"key": "act_3", "code": "calm", "label": "SCHLANGE"},
				{"key": "act_admit", "code": "pass", "label": "DURCHLASSEN"},
				{"key": "act_reject", "code": "reject", "label": "ABWEISEN"},
			],
		},
		{
			"id": "security", "label": "SECURITY", "accent": Color("39d7ff"),
			"area": "airlock", "solo": false, "keys": KEYS_P2,
			"actions": [
				{"key": "act_7", "code": "search", "label": "ABTASTEN"},
				{"key": "act_8", "code": "alcohol", "label": "ALKOTEST"},
				{"key": "act_admit2", "code": "admit", "label": "EINLASSEN"},
				{"key": "act_reject2", "code": "reject", "label": "ZURUECKSCHICKEN"},
			],
		},
	]

## Welche Kontrollen gehoeren zu welchem Bereich?
const AREA_CHECKS := {
	"outside": ["id", "talk"],
	"airlock": ["search", "alcohol"],
}

## Das Spiel spielt an einem festen fiktiven Datum - Basis fuer Ablauf/Alter.
const GAME_DATE := {"year": 2026, "month": 3, "day": 14}

## Wie viele Gaeste passen gleichzeitig in die Schleuse?
const AIRLOCK_CAPACITY := 4

## Tasten fuer die Abtast-Zonen (Spieler 2).
const PATDOWN_KEYS := [
	{"key": "zone_jacket", "zone": "jacket", "label": "JACKE"},
	{"key": "zone_pockets", "zone": "pockets", "label": "HOSENTASCHEN"},
	{"key": "zone_bag", "zone": "bag", "label": "TASCHE"},
]

## Grenzwert, der auf dem Alkoholtestgeraet aufgedruckt ist.
const ALCOHOL_LIMIT_PROMILLE := 1.7

## Gast-Archetypen. weight = relative Haeufigkeit.
const ARCHETYPES := [
	{
		"id": "regular", "label": "Standardgast", "weight": 30, "spend": [18, 46],
		"risk": [0.0, 0.35], "drunk": [0.0, 0.55], "vip": 0.0, "badIdChance": 0.06,
		"contrabandChance": 0.05, "patience": 1.0, "rep": 1.0,
	},
	{
		"id": "tourist", "label": "Tourist", "weight": 14, "spend": [40, 95],
		"risk": [0.0, 0.3], "drunk": [0.1, 0.8], "vip": 0.0, "badIdChance": 0.14,
		"contrabandChance": 0.04, "patience": 1.15, "rep": 0.6,
	},
	{
		"id": "local", "label": "Stammgast", "weight": 16, "spend": [22, 55],
		"risk": [0.0, 0.2], "drunk": [0.0, 0.5], "vip": 0.0, "badIdChance": 0.03,
		"contrabandChance": 0.03, "patience": 0.85, "rep": 1.4,
	},
	{
		"id": "influencer", "label": "Influencer", "weight": 6, "spend": [15, 40],
		"risk": [0.0, 0.3], "drunk": [0.0, 0.45], "vip": 0.2, "badIdChance": 0.05,
		"contrabandChance": 0.03, "patience": 0.6, "rep": 3.0,
	},
	{
		"id": "vip", "label": "VIP", "weight": 6, "spend": [120, 340],
		"risk": [0.0, 0.25], "drunk": [0.0, 0.5], "vip": 1.0, "badIdChance": 0.02,
		"contrabandChance": 0.02, "patience": 0.45, "rep": 2.5,
	},
	{
		"id": "trouble", "label": "Problemgast", "weight": 9, "spend": [10, 30],
		"risk": [0.55, 1.0], "drunk": [0.3, 1.0], "vip": 0.0, "badIdChance": 0.25,
		"contrabandChance": 0.42, "patience": 0.7, "rep": -1.0,
	},
	{
		"id": "scene", "label": "Szene-Gast", "weight": 8, "spend": [25, 70],
		"risk": [0.0, 0.35], "drunk": [0.0, 0.5], "vip": 0.1, "badIdChance": 0.05,
		"contrabandChance": 0.06, "patience": 0.5, "rep": 2.0,
	},
	{
		"id": "crew", "label": "Crew-Mitglied", "weight": 4, "spend": [0, 10],
		"risk": [0.0, 0.2], "drunk": [0.0, 0.3], "vip": 0.5, "badIdChance": 0.08,
		"contrabandChance": 0.05, "patience": 0.7, "rep": 1.5, "backstage": true,
	},
	{
		"id": "insider", "label": "Security-Insider", "weight": 3, "spend": [20, 50],
		"risk": [0.0, 0.2], "drunk": [0.0, 0.2], "vip": 0.0, "badIdChance": 0.35,
		"contrabandChance": 0.3, "patience": 1.2, "rep": 2.0, "inspector": true,
	},
	{
		"id": "mystery", "label": "Mystery-Gast", "weight": 4, "spend": [0, 260],
		"risk": [0.0, 1.0], "drunk": [0.0, 0.9], "vip": 0.35, "badIdChance": 0.2,
		"contrabandChance": 0.2, "patience": 0.9, "rep": 1.5,
	},
]

## Gruppen verbotener Sachen. NUR diese Gruppen stehen in der Hausordnung -
## nicht die einzelnen Gegenstaende. Der Spieler muss also selbst einordnen,
## ob ein Schlagring eine Waffe ist und ob ein Flaeschchen ohne Etikett unter
## "unklare Substanzen" faellt. Abgelesen werden kann das nicht mehr.
const ITEM_CATEGORIES := [
	{
		"id": "weapon", "label": "Waffen und gefährliche Gegenstände", "severity": 3,
		"rule": "Stich- und Schneidwerkzeuge, Schlag- und Elektrogeräte sowie Reizstoffsprays jeder Art.",
	},
	{
		"id": "pyro", "label": "Pyrotechnik und offenes Feuer", "severity": 3,
		"rule": "Alles, was gezündet wird oder brennt, funkt oder qualmt. Feuerzeuge bleiben erlaubt.",
	},
	{
		"id": "drugs", "label": "Unklare Substanzen", "severity": 2,
		"rule": "Päckchen, Döschen, Briefchen und Fläschchen ohne lesbare Beschriftung. Beschriftete Medikamente aus der Apotheke sind zugelassen.",
	},
	{
		"id": "tool", "label": "Werkzeug", "severity": 2,
		"rule": "Handwerkszeug jeder Grösse, auch zusammengeklappt.",
	},
	{
		"id": "glass", "label": "Glas und mitgebrachte Getränke", "severity": 1,
		"rule": "Behälter aus Glas und Metall mit Inhalt. Leere Plastikflaschen sind zugelassen.",
	},
	{
		"id": "media", "label": "Professionelle Aufnahmetechnik", "severity": 1,
		"rule": "Kameras mit Wechselobjektiv, Actioncams, Objektive, Stative. Handys bleiben erlaubt.",
	},
	{
		"id": "light", "label": "Blendlicht", "severity": 1,
		"rule": "Laser und starke Blendleuchten, die in die Menge gerichtet werden können.",
	},
]

static func category_by_id(id: String) -> Variant:
	for c: Dictionary in ITEM_CATEGORIES:
		if c["id"] == id:
			return c
	return null

## Gegenstaende, die beim Abtasten zum Vorschein kommen.
## Die meisten sind voellig harmlos - genau darum muss man hinsehen.
## `zones` sagt, wo ein Gegenstand plausibel steckt, `cat` die Gruppe der
## Hausordnung (nur bei verbotenen Sachen gesetzt).
const RAW_ITEMS := [
	# --- harmlos ---
	{"id": "gum", "label": "Kaugummi", "zones": ["pockets", "bag"]},
	{"id": "phone", "label": "Handy", "zones": ["jacket", "pockets", "bag"]},
	{"id": "keys", "label": "Schlüsselbund", "zones": ["jacket", "pockets", "bag"]},
	{"id": "lighter", "label": "Feuerzeug", "zones": ["jacket", "pockets"]},
	{"id": "smokes", "label": "Zigaretten", "zones": ["jacket", "bag"]},
	{"id": "wallet", "label": "Portemonnaie", "zones": ["jacket", "pockets", "bag"]},
	{"id": "earbuds", "label": "Kopfhörer", "zones": ["jacket", "pockets", "bag"]},
	{"id": "coins", "label": "Kleingeld", "zones": ["pockets"]},
	{"id": "tissues", "label": "Taschentücher", "zones": ["jacket", "bag"]},
	{"id": "balm", "label": "Lippenpflege", "zones": ["pockets", "bag"]},
	{"id": "mints", "label": "Pfefferminz", "zones": ["pockets", "bag"]},
	{"id": "charger", "label": "Ladekabel", "zones": ["bag"]},
	{"id": "bottle", "label": "Plastikflasche, leer", "zones": ["bag"]},
	{"id": "book", "label": "Notizbuch", "zones": ["bag"]},
	{"id": "powerbank", "label": "Powerbank", "zones": ["jacket", "bag"]},
	{"id": "shades", "label": "Sonnenbrille", "zones": ["jacket", "bag"]},
	{"id": "meds", "label": "Tabletten, beschriftet", "zones": ["pockets", "bag"]},
	{"id": "deo", "label": "Deoroller", "zones": ["bag"]},
	{"id": "selfie", "label": "Selfiestick", "zones": ["bag"]},
	{"id": "pen", "label": "Kugelschreiber", "zones": ["jacket", "pockets", "bag"]},
	{"id": "snack", "label": "Müsliriegel", "zones": ["jacket", "bag"]},
	{"id": "earplugs", "label": "Ohrstöpsel", "zones": ["pockets", "bag"]},
	{"id": "vape", "label": "E-Zigarette", "zones": ["jacket", "pockets", "bag"]},
	{"id": "ticket", "label": "Ticket", "zones": ["jacket", "pockets"]},

	# --- Waffen: es gibt viele, in der Hausordnung steht nur "Waffen" ---
	{"id": "blade", "label": "Klappmesser", "cat": "weapon", "zones": ["jacket", "pockets"]},
	{"id": "cutter", "label": "Cuttermesser", "cat": "weapon", "zones": ["jacket", "pockets", "bag"]},
	{"id": "butterfly", "label": "Butterflymesser", "cat": "weapon", "zones": ["jacket", "pockets"]},
	{"id": "knuckles", "label": "Schlagring", "cat": "weapon", "zones": ["jacket", "pockets"]},
	{"id": "baton", "label": "Teleskopschlagstock", "cat": "weapon", "zones": ["jacket", "bag"]},
	{"id": "stun", "label": "Elektroschocker", "cat": "weapon", "zones": ["jacket", "bag"]},
	{
		"id": "spray", "label": "Reizgasspray", "cat": "weapon", "severity": 2,
		"zones": ["jacket", "pockets", "bag"],
	},

	# --- Pyrotechnik ---
	{"id": "flare", "label": "Bengalfackel", "cat": "pyro", "zones": ["bag"]},
	{
		"id": "banger", "label": "Böller", "cat": "pyro", "severity": 2,
		"zones": ["jacket", "pockets", "bag"],
	},
	{"id": "smokepot", "label": "Rauchtopf", "cat": "pyro", "zones": ["bag"]},
	{
		"id": "sparkler", "label": "Wunderkerzen", "cat": "pyro", "severity": 1,
		"zones": ["jacket", "bag"],
	},

	# --- unklare Substanzen ---
	{
		"id": "substance", "label": "Unbeschriftetes Päckchen", "cat": "drugs",
		"zones": ["jacket", "pockets", "bag"],
	},
	{"id": "pills", "label": "Döschen mit losen Pillen", "cat": "drugs", "zones": ["pockets", "bag"]},
	{"id": "powder", "label": "Briefchen mit Pulver", "cat": "drugs", "zones": ["jacket", "pockets"]},
	{"id": "vial", "label": "Fläschchen ohne Etikett", "cat": "drugs", "zones": ["pockets", "bag"]},

	# --- Werkzeug ---
	{"id": "tool", "label": "Multitool", "cat": "tool", "zones": ["jacket", "pockets", "bag"]},
	{"id": "screwdriver", "label": "Schraubendreher", "cat": "tool", "zones": ["jacket", "bag"]},
	{"id": "pliers", "label": "Kombizange", "cat": "tool", "zones": ["bag"]},

	# --- Glas und Getraenke ---
	{"id": "glass", "label": "Glasflasche", "cat": "glass", "zones": ["jacket", "bag"]},
	{"id": "flask", "label": "Flachmann", "cat": "glass", "zones": ["jacket", "pockets"]},
	{"id": "wine", "label": "Weinflasche", "cat": "glass", "zones": ["bag"]},

	# --- Aufnahmetechnik ---
	{"id": "camera", "label": "Profikamera", "cat": "media", "zones": ["bag"]},
	{"id": "lens", "label": "Teleobjektiv", "cat": "media", "zones": ["bag"]},
	{"id": "actioncam", "label": "Actioncam", "cat": "media", "zones": ["jacket", "pockets", "bag"]},

	# --- Blendlicht ---
	{"id": "laser", "label": "Laserpointer", "cat": "light", "zones": ["jacket", "pockets"]},
	{
		"id": "blinder", "label": "Blendleuchte", "cat": "light", "severity": 2,
		"zones": ["jacket", "bag"],
	},
]

## `forbidden` und `severity` ergeben sich aus der Gruppe - so kann keine
## Tabellenzeile aus Versehen widerspruechlich werden.
##
## In GDScript gibt es keine Konstante, die zur Ladezeit rechnet; die Liste
## wird darum beim ersten Zugriff einmal aufgebaut und gecacht.
static var _items_cache: Array[Dictionary] = []

static func items() -> Array[Dictionary]:
	if not _items_cache.is_empty():
		return _items_cache
	for raw: Dictionary in RAW_ITEMS:
		var cat_id: Variant = raw.get("cat", null)
		var category: Variant = category_by_id(cat_id) if cat_id != null else null
		var item := raw.duplicate(true)
		item["cat"] = cat_id
		item["catLabel"] = category["label"] if category != null else null
		item["forbidden"] = category != null
		if not item.has("severity"):
			item["severity"] = category["severity"] if category != null else 0
		_items_cache.append(item)
	return _items_cache

static func item_by_id(id: String) -> Variant:
	for i: Dictionary in items():
		if i["id"] == id:
			return i
	return null

## Alle verbotenen Sachen einer Gruppe (fuers Balancing und fuer Tests).
static func items_of_category(cat_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: Dictionary in items():
		if i["cat"] == cat_id:
			out.append(i)
	return out

## Abtast-Zonen. 'bag' gibt es nur, wenn der Gast wirklich eine Tasche dabei hat.
const ZONES := [
	{"id": "jacket", "label": "JACKE", "key": "zone_jacket", "needsBag": false, "capacity": [1, 3]},
	{"id": "pockets", "label": "HOSENTASCHEN", "key": "zone_pockets", "needsBag": false, "capacity": [1, 3]},
	{"id": "bag", "label": "TASCHE", "key": "zone_bag", "needsBag": true, "capacity": [2, 4]},
]

## Was der Spieler im Lauf der Karriere zusaetzlich beachten muss.
## Jede Stufe schaltet eine neue Auffaelligkeit frei und wird im Briefing angekuendigt.
const DIFFICULTY_STEPS := [
	{
		"night": 1, "id": "basics", "label": "AUSWEIS",
		"desc": "Foto, Name, Geburtsdatum, Gültigkeit, Hologramm.",
	},
	{
		"night": 2, "id": "items", "label": "GEGENSTÄNDE",
		"desc": "Beim Abtasten kommt alles auf den Tisch. Such heraus, was nicht reindarf.",
	},
	{
		"night": 3, "id": "alcohol", "label": "ALKOHOL",
		"desc": "Das Testgerät zeigt den Wert - den Grenzwert musst du selbst lesen.",
	},
	{
		"night": 4, "id": "impaired", "label": "ZUSTAND",
		"desc": "Nicht jeder Rausch riecht nach Alkohol: weite Pupillen, Schwitzen, Zittern, mahlender Kiefer.",
	},
	{
		"night": 5, "id": "aggression", "label": "ÜBERGRIFFE",
		"desc": "Manche lassen sich das Abweisen nicht gefallen und gehen auf dich los. Dann zählt nur noch, wie schnell du die eingeblendeten Tasten triffst.",
	},
	{
		"night": 6, "id": "subtleId", "label": "FEINE FÄLSCHUNGEN",
		"desc": "Hologramme sind nur noch teilweise matt, Manipulationen kleiner.",
	},
	{
		"night": 8, "id": "blacklist", "label": "HAUSVERBOTE",
		"desc": "Bekannte Gesichter mit Hausverbot versuchen es erneut. Der Scanner kennt sie.",
	},
	{
		"night": 10, "id": "multi", "label": "MEHRFACHE MÄNGEL",
		"desc": "Ein sauberer Ausweis heisst gar nichts mehr - es kommt oft mehreres zusammen.",
	},
]

## Die Punkte, die der Spieler auf seinem Notizzettel selbst beurteilt.
## `truth` sagt dem Spiel, ob die Beurteilung am Ende zutraf.
const NOTE_TOPICS := [
	{"id": "document", "label": "Dokument", "area": "outside", "hint": "Foto, Name, Datum, Merkmale"},
	{"id": "person", "label": "Zustand der Person", "area": "outside", "hint": "Auftreten, Augen, Hände"},
	{"id": "statement", "label": "Aussage", "area": "outside", "hint": "Passt, was er sagt, zum Rest?"},
	{"id": "items", "label": "Mitgeführte Sachen", "area": "airlock", "hint": "Jacke, Taschen, Beutel"},
	{"id": "alcohol", "label": "Alkoholwert", "area": "airlock", "hint": "Messwert gegen Grenzwert"},
]

## Punkte der Checkliste (Seite 1) - der Spieler hakt selbst ab.
const CHECKLIST := [
	{"id": "id", "label": "Ausweis verlangt", "area": "outside"},
	{"id": "fields", "label": "Alle Felder geprüft", "area": "outside"},
	{"id": "talk", "label": "Person angesprochen", "area": "outside"},
	{"id": "look", "label": "Person angesehen", "area": "outside"},
	{"id": "search", "label": "Abgetastet", "area": "airlock"},
	{"id": "alcohol", "label": "Alkoholtest gemacht", "area": "airlock"},
]

## Sichtbare Anzeichen fuer Substanzeinfluss (abstrakt, ohne Konsumdetails).
##
## Alles hier ist von aussen erkennbar, bevor man den Gast ueberhaupt
## anspricht: rote Augen, fahle Haut, Augenringe, ein glasiger Blick. Wer
## hinsieht, braucht dafuer kein Geraet.
const IMPAIRMENT_SIGNS := [
	{"id": "redEyes", "label": "gerötete Augen", "min": 0.3, "face": true},
	{"id": "pupils", "label": "weite Pupillen", "min": 0.35, "face": true},
	{"id": "glassy", "label": "glasiger Blick", "min": 0.4, "face": true},
	{"id": "absent", "label": "wirkt abwesend", "min": 0.45, "face": false},
	{"id": "rings", "label": "dunkle Augenringe", "min": 0.5, "face": true},
	{"id": "sweat", "label": "schwitzt stark", "min": 0.5, "face": true},
	{"id": "pale", "label": "fahle Haut", "min": 0.55, "face": true},
	{"id": "jaw", "label": "mahlender Kiefer", "min": 0.6, "face": true},
	{"id": "restless", "label": "steht keine Sekunde still", "min": 0.65, "face": false},
	{"id": "shake", "label": "zitternde Hände", "min": 0.7, "face": false},
]

const ID_ISSUES := [
	{"id": "expired", "label": "Ausweis abgelaufen"},
	{"id": "photo", "label": "Foto passt nicht"},
	{"id": "name", "label": "Name unstimmig"},
	{"id": "marks", "label": "Sicherheitsmerkmale fehlen"},
	{"id": "age", "label": "Geburtsdatum manipuliert"},
]

## Was gerade aktiv ist. Der Fokus liegt vorerst allein auf der Kontrolle an
## der Tuer: Sondernaechte, Zufallsereignisse, Acts und ungeduldige Gaeste sind
## abgeschaltet. Zum Wiedereinschalten reicht ein `true`.
const FEATURES := {
	"nightEvents": false,
	"randomEvents": false,
	"artists": false,
	"queueImpatience": false,
	"aggression": true,
}

## Tasten, die bei einem Angriff auf dem Bildschirm erscheinen. Bewusst weit
## auseinander und nicht mit den Aktionstasten belegt, damit man im Reflex
## nicht aus Versehen jemanden einlaesst.
const DEFENSE_KEYS := [
	{"key": "def_q", "label": "Q"},
	{"key": "def_w", "label": "W"},
	{"key": "def_e", "label": "E"},
	{"key": "def_r", "label": "R"},
	{"key": "def_a", "label": "A"},
	{"key": "def_s", "label": "S"},
	{"key": "def_d", "label": "D"},
	{"key": "def_f", "label": "F"},
]

## Abwehr von Angriffen.
##
## Ein Gast rastet nur selten aus - und wenn, dann kommt er auf einen zu und
## man hat wenige Sekunden, die eingeblendeten Tasten zu treffen.
const AGGRESSION := {
	"rejectChance": 0.07,
	"idleChancePerSecond": 0.004,
	"minNight": 5,

	"chargeTime": 0.9,
	"keys": [3, 5],
	"keyTime": 1.5,
	"keyTimeStep": 0.12,
	"keyTimeMin": 0.7,
	"strikes": 2,
	"resultTime": 1.4,

	"winRep": 1.6,
	"winBonus": 60,
	"winXp": 20,
	"failRep": -3.5,
	"failCost": 220,
	"failStun": 2.2,
}

## Nacht-Events.
const NIGHT_EVENTS := [
	{
		"id": "normal", "label": "NORMAL NIGHT", "desc": "Normale Gäste, ruhiger Betrieb.",
		"spawn": 1.0, "vip": 1.0, "trouble": 1.0, "spend": 1.0, "minNight": 1,
	},
	{
		"id": "rave", "label": "UNDERGROUND RAVE", "desc": "Massive Warteschlange, harter Andrang.",
		"spawn": 1.75, "vip": 0.9, "trouble": 1.3, "spend": 1.0, "minNight": 2,
	},
	{
		"id": "vipnight", "label": "VIP NIGHT", "desc": "Deutlich mehr VIPs, hohe Erwartungen.",
		"spawn": 1.1, "vip": 3.0, "trouble": 0.9, "spend": 1.35, "minNight": 3,
	},
	{
		"id": "artist", "label": "ARTIST NIGHT", "desc": "Grosser Act. Backstage-Kontrolle noetig.",
		"spawn": 1.45, "vip": 1.6, "trouble": 1.1, "spend": 1.25, "minNight": 3,
	},
	{
		"id": "soldout", "label": "SOLD OUT", "desc": "Extremer Andrang, Kapazität wird knapp.",
		"spawn": 2.1, "vip": 1.2, "trouble": 1.2, "spend": 1.1, "minNight": 5,
	},
	{
		"id": "inspection", "label": "INSPECTION NIGHT",
		"desc": "Behörden kontrollieren. Fehler kosten doppelt.",
		"spawn": 1.0, "vip": 0.8, "trouble": 1.4, "spend": 0.95, "minNight": 4, "inspection": true,
	},
	{
		"id": "chaos", "label": "CHAOS NIGHT", "desc": "Zufällige Zwischenfälle, hohe Frequenz.",
		"spawn": 1.5, "vip": 1.2, "trouble": 1.6, "spend": 1.1, "minNight": 6, "chaos": true,
	},
]

## Fiktive In-Game-Acts.
const ARTISTS := [
	{"id": "philo", "name": "PHILO", "genre": "Deep Techno", "fee": 300, "pop": 1, "vipPull": 1.1, "spend": 1.1},
	{"id": "tilo", "name": "TILO", "genre": "Hard Groove", "fee": 650, "pop": 2, "vipPull": 1.2, "spend": 1.15},
	{"id": "baxboy", "name": "TJ BAXBOY", "genre": "Acid", "fee": 1100, "pop": 3, "vipPull": 1.35, "spend": 1.2},
	{"id": "nerok", "name": "NERO K", "genre": "Industrial", "fee": 1800, "pop": 4, "vipPull": 1.5, "spend": 1.3},
	{"id": "vexa", "name": "VEXA", "genre": "Hypnotic", "fee": 2600, "pop": 5, "vipPull": 1.7, "spend": 1.4},
	{"id": "kayr", "name": "KAYR", "genre": "Trance Revival", "fee": 3800, "pop": 6, "vipPull": 1.9, "spend": 1.5},
	{"id": "voidctrl", "name": "VOIDCTRL", "genre": "Warehouse", "fee": 5200, "pop": 7, "vipPull": 2.2, "spend": 1.7},
]

## Upgrades. `tier` zaehlt in die sichtbare Club-Stufe ein.
## cost[level] -> Preis fuer den naechsten Ausbau.
const UPGRADES := [
	{
		"id": "scanner", "label": "Prüfplatz", "max": 3, "tier": 1, "group": "Sicherheit",
		"desc": [
			"Bessere Lampe am Pult: du arbeitest schneller.",
			"Ordentlicher Prüftisch: Kontrollen gehen deutlich zügiger.",
			"Voll ausgestatteter Prüfplatz: schnellstmögliche Abfertigung.",
		],
		"cost": [450, 1200, 2800],
	},
	{
		"id": "detector", "label": "Metalldetektor", "max": 2, "tier": 1, "group": "Sicherheit",
		"desc": [
			"Markiert die verdächtige Körperzone beim Abtasten.",
			"Erkennt gefaehrliche Gegenstaende automatisch.",
		],
		"cost": [600, 1900],
	},
	{
		"id": "cameras", "label": "Sicherheitskameras", "max": 2, "tier": 1, "group": "Sicherheit",
		"desc": [
			"Crowd-Monitoring: senkt den Schaden bei Zwischenfällen.",
			"Lückenlose Aufzeichnung: noch weniger Schaden.",
		],
		"cost": [520, 1500],
	},
	{
		"id": "team", "label": "Security-Team", "max": 3, "tier": 1, "group": "Sicherheit",
		"desc": [
			"Ein zusätzlicher Mitarbeiter beruhigt die Schlange.",
			"Zweiter Mitarbeiter, weniger Eskalationen.",
			"Volles Team: Zwischenfälle werden meist abgefangen.",
		],
		"cost": [700, 1600, 3400],
	},
	{
		"id": "door", "label": "Eingang & Tür", "max": 3, "tier": 1, "group": "Eingang",
		"desc": [
			"Breitere Tür: schnellerer Einlass.",
			"Zweiter Eingang: längere Warteschlange möglich.",
			"VIP-Eingang: VIPs warten geduldiger.",
		],
		"cost": [400, 1300, 3000],
	},
	{
		"id": "lights", "label": "Lichtanlage", "max": 3, "tier": 1, "group": "Technik",
		"desc": [
			"Neue Neon-Beleuchtung am Eingang.",
			"Laser und bewegliche Scheinwerfer.",
			"LED-Waende und volle Lichtshow.",
		],
		"cost": [380, 1400, 3600],
	},
	{
		"id": "sound", "label": "Soundanlage", "max": 3, "tier": 1, "group": "Technik",
		"desc": [
			"Neue Stacks: Gäste bleiben länger.",
			"Subbass-Array: mehr Umsatz.",
			"Gigantisches Soundsystem: internationaler Standard.",
		],
		"cost": [500, 1700, 4200],
	},
	{
		"id": "floor", "label": "Tanzfläche", "max": 3, "tier": 1, "group": "Innenbereich",
		"desc": [
			"Größere Tanzfläche: +80 Kapazität.",
			"Zweiter Floor: +140 Kapazität.",
			"Dritter Floor: +220 Kapazität.",
		],
		"cost": [800, 2200, 5000],
	},
	{
		"id": "bar", "label": "Bar", "max": 3, "tier": 1, "group": "Innenbereich",
		"desc": [
			"Größere Bar: mehr Umsatz pro Gast.",
			"Zweite Bar: deutlich mehr Umsatz.",
			"Premium-Bar: maximaler Umsatz.",
		],
		"cost": [450, 1500, 3800],
	},
	{
		"id": "vip", "label": "VIP-Bereich", "max": 2, "tier": 1, "group": "Innenbereich",
		"desc": [
			"VIP-Lounge: VIPs geben deutlich mehr aus.",
			"Premium-Lounge mit eigenem Service.",
		],
		"cost": [1500, 4000],
	},
	{
		"id": "comfort", "label": "Komfort", "max": 2, "tier": 0, "group": "Komfort",
		"desc": [
			"Garderobe und bessere Toiletten: Ruf steigt schneller.",
			"Sitzbereiche und Belüftung: Gäste bleiben länger.",
		],
		"cost": [600, 1800],
	},
	{
		"id": "backstage", "label": "Backstage", "max": 2, "tier": 1, "group": "Innenbereich",
		"desc": [
			"Backstage-Bereich: Acts können gebucht werden.",
			"Künstler-Lounge: bessere Acts verfuegbar.",
		],
		"cost": [1200, 3600],
	},
]

## Sichtbare Club-Stufen.
const CLUB_TIERS := [
	{"level": 1, "label": "KELLERCLUB", "need": 0},
	{"level": 2, "label": "GROSSER EINGANG", "need": 3},
	{"level": 3, "label": "NEUE RAEUME", "need": 6},
	{"level": 4, "label": "ZWEITE TANZFLÄCHE", "need": 10},
	{"level": 5, "label": "VIP-BEREICH", "need": 14},
	{"level": 6, "label": "UNDERGROUND-KOMPLEX", "need": 19},
	{"level": 7, "label": "TECHNO-TEMPEL", "need": 24},
]

const RANKS := [
	{"level": 1, "label": "ROOKIE", "xp": 0},
	{"level": 2, "label": "DOOR STAFF", "xp": 250},
	{"level": 3, "label": "SECURITY", "xp": 700},
	{"level": 4, "label": "HEAD BOUNCER", "xp": 1500},
	{"level": 5, "label": "SECURITY CHIEF", "xp": 2800},
	{"level": 6, "label": "CLUB MANAGER", "xp": 4800},
]

const TALENTS := [
	{"id": "street", "label": "Street Smarts", "max": 3, "desc": "Verdächtige Gäste zeigen frueher Warnzeichen."},
	{"id": "scanner", "label": "Routine", "max": 3, "desc": "Alle Kontrollen laufen schneller ab."},
	{"id": "charisma", "label": "Charisma", "max": 3, "desc": "Gäste warten geduldiger, CALM wirkt staerker."},
	{"id": "reputation", "label": "Reputation", "max": 3, "desc": "Mehr Ruf pro richtiger Entscheidung."},
	{"id": "management", "label": "Management", "max": 3, "desc": "Upgrades kosten weniger, Bar bringt mehr."},
]

const RANDOM_EVENTS := [
	{"id": "blackout", "label": "STROMAUSFALL", "desc": "Licht und Scanner fallen kurz aus.", "weight": 8},
	{"id": "scannerFail", "label": "PRÜFGERÄT DEFEKT", "desc": "Das Dokumenten-Prüfgerät streikt.", "weight": 10},
	{"id": "rush", "label": "ANSTURM", "desc": "Eine grosse Gruppe trifft gleichzeitig ein.", "weight": 14},
	{"id": "celebrity", "label": "UNERWARTETER GAST", "desc": "Eine bekannte Person steht ploetzlich vorne.", "weight": 8},
	{"id": "complaint", "label": "BESCHWERDE", "desc": "Die Schlange wird unruhig.", "weight": 12},
	{"id": "influencerPost", "label": "INFLUENCER POSTET", "desc": "Der Club geht viral. Mehr Andrang, mehr Ruf.", "weight": 7},
	{"id": "artistLate", "label": "ACT VERSPAETET", "desc": "Der Künstler kommt später als geplant.", "weight": 6},
	{"id": "fakePass", "label": "FALSCHER BACKSTAGE-PASS", "desc": "Jemand behauptet, zur Crew zu gehoeren.", "weight": 9},
]

const FIRST_NAMES := [
	"Mira", "Jonas", "Lena", "Tarek", "Nils", "Sasha", "Ada", "Bruno", "Kim", "Elif",
	"Vito", "Nora", "Kaspar", "Juno", "Rico", "Svea", "Milan", "Ida", "Anton", "Zoe",
	"Ferro", "Malte", "Nadja", "Ole", "Pia", "Ravi", "Toni", "Ulla", "Wanda", "Yuri",
]

const LAST_NAMES := [
	"Falk", "Brandt", "Vogel", "Kern", "Marek", "Stein", "Roth", "Kilic", "Sander", "Novak",
	"Bauer", "Lorenz", "Haas", "Petrov", "Weiss", "Dorn", "Kaiser", "Berg", "Frost", "Neumann",
]
