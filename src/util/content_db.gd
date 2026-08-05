extends Node
## ContentDB: loads and caches all content JSON (weapons, systems, ships,
## drones) so game systems can reference content by id at runtime.

const SYS_PATH := "res://data/systems/systems.json"
const WEAPON_PATH := "res://data/weapons/weapons.json"
const DRONE_PATH := "res://data/drone/drones.json"
const SHIP_PATH := "res://data/ships/ships.json"
const EVENT_PATH := "res://data/events/events.json"
const THEME_PATH := "res://data/sectors/sector_themes.json"

var systems: Dictionary = {}     # id -> system def (Dictionary)
var weapons := {}                # id -> weapon def
var drones := {}                # id -> drone def
var ships := {}                 # id -> ship def (layout)
var ship_list: Array = []
var events := []                # array of event defs
var sector_themes := []         # array of theme defs

func _ready() -> void:
	load_all()

func load_all() -> void:
	systems = _load_map(SYS_PATH, "id", "systems")
	weapons = _load_map(WEAPON_PATH, "id", "weapons")
	drones = _load_map(DRONE_PATH, "id", "drones")
	ships = _load_map(SHIP_PATH, "id", "ships")
	var ship_defs: Array = JSONHelpers.load_json(SHIP_PATH).get("ships", [])
	for s in ship_defs:
		ship_list.append(s.id)
	events = JSONHelpers.load_json(EVENT_PATH).get("events", [])
	sector_themes = JSONHelpers.load_json(THEME_PATH).get("themes", [])

func _load_map(path: String, key: String, wrap: String) -> Dictionary:
	var data := JSONHelpers.load_json(path)
	if data.is_empty():
		push_warning("ContentDB: could not load %s" % path)
		return {}
	var out := {}
	for entry in data.get(wrap, []):
		out[entry.get(key)] = entry
	return out

func get_system(id: String) -> Dictionary:
	return systems.get(id, {})

func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func get_drone(id: String) -> Dictionary:
	return drones.get(id, {})

func get_ship(id: String) -> Dictionary:
	return ships.get(id, {})

func random_event() -> Dictionary:
	if events.is_empty():
		return {}
	return events[randi() % events.size()]