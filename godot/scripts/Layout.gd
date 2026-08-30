## Weltkoordinaten der 2D-Szene (logische Auflösung 1280x720).
##
## Portierung von src/render/layout.js. Wird - wie dort - von Rendering UND
## Gameplay genutzt, damit Figuren und Kulisse zusammenpassen.
class_name Layout
extends RefCounted

const WORLD := Vector2(1280, 720)

const CLUB := Rect2(120, 20, 1040, 320)
const STREET := Rect2(0, 360, 1280, 360)
const SPAWN := Vector2(1245, 640)

const DOOR_X := 640.0
const DOOR_Y := 348.0
const DOOR_W := 96.0

const BACK_DOOR_X := 196.0
const BACK_DOOR_Y := 348.0
const BACK_DOOR_W := 64.0

const QUEUE_ORIGIN := Vector2(356, 470)
const QUEUE_SPACING := 54.0
const QUEUE_ROW_GAP := 66.0
const QUEUE_PER_ROW := 9

## Stationen: Position, Radius und Beschriftung.
const STATION_DOOR := {"pos": Vector2(592, 404), "r": 96.0, "label": "TÜR"}
const STATION_SEARCH := {"pos": Vector2(726, 404), "r": 96.0, "label": "KONTROLLE"}

## Innenbereiche des Clubs (skalieren später mit der Club-Stufe).
const DANCEFLOOR := Rect2(430, 60, 420, 210)
const FLOOR2 := Rect2(880, 70, 230, 190)
const BAR := Rect2(150, 70, 220, 90)
const VIP := Rect2(150, 190, 220, 110)
const BOOTH := Rect2(570, 34, 140, 44)
const BACKSTAGE := Rect2(150, 190, 130, 100)

static func station_for(role_id: String) -> Dictionary:
	return STATION_DOOR if role_id == "bouncer" else STATION_SEARCH

static func in_station(position: Vector2, role_id: String) -> bool:
	var station := station_for(role_id)
	return position.distance_to(station["pos"]) <= float(station["r"])
