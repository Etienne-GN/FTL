class_name CrewMember
extends RefCounted
## A single crew member on a ship.

const RACES := {
	"human": {"hp": 100.0, "speed": 1.0},
	"engi": {"hp": 75.0, "speed": 0.8, "repair": 2.0},
	"mantis": {"hp": 60.0, "speed": 1.2, "fight": 1.5},
	"rock": {"hp": 130.0, "speed": 0.6, "fire_resist": true},
	"zoltan": {"hp": 60.0, "speed": 1.0, "power": 1},
	"human_mantis": {"hp": 80.0, "speed": 1.1},
	"slug": {"hp": 90.0, "speed": 1.0, "no_oxygen": false, "breach_resist": false},
	"lanius": {"hp": 100.0, "speed": 1.0, "no_oxygen": true},
	"crystal": {"hp": 150.0, "speed": 1.0, "fight": 1.1},
}

var name: String = "Crew"
var race: String = "human"
var ship: Ship = null          # owning ship
var hp: float = 1.0
var max_hp: float = 1.0
var room: Dictionary = {}       # room ref {id, rect}
var skills := {}                # skill -> base level (0..1 from ship def)
var xp := {}                    # skill -> accumulated xp towards higher levels
var task: String = "idle"       # idle|man|repair|fight|move|teleport
var target_room_id: String = ""
var pos: Vector2 = Vector2.ZERO # position in ship-local tile coords
var path: Array = []            # queue of room ids to traverse
var speed := 1.4                # tiles per second
var hostile := false            # true when boarding an enemy ship
var mc_timer := 0.0             # seconds left of mind control (turned crew)

const XP_PER_LEVEL := 100
const MAX_LEVEL := 2

func _init(cdef: Dictionary = {}):
	race = cdef.get("race", "human")
	name = cdef.get("name", _random_name())
	skills = cdef.get("skills", {})
	xp = cdef.get("xp", {})
	var stats = RACES.get(race, RACES["human"])
	max_hp = stats.get("hp", 1.0)
	hp = max_hp
	speed = stats.get("speed", 1.0) * 1.4

func _random_name() -> String:
	var names := ["Ash", "Blaine", "Chen", "Dax", "Eli", "Fennec", "Gor", "Hiss",
		"Iba", "Jax", "Kyra", "Lux", "Miko", "Nox", "Oka", "Petr", "Rae", "Syr",
		"Tessa", "Ulka", "Vesper", "Wren", "Xa", "Yuki", "Zed"]
	return names[randi() % names.size()]

func alive() -> bool:
	return hp > 0.0

func stat(skill_key: String) -> int:
	return clampi(int(skills.get(skill_key, 0)) + int(xp.get(skill_key, 0)) / XP_PER_LEVEL, 0, MAX_LEVEL)

func gain_xp(skill_key: String, amount: float) -> void:
	if not xp.has(skill_key):
		xp[skill_key] = 0
	xp[skill_key] += int(amount)

func skill_bonus(skill_key: String) -> float:
	return 1.0 + 0.5 * stat(skill_key)

func needs_oxygen() -> bool:
	return not bool(RACES.get(race, {}).get("no_oxygen", false))

func assign_room(r: Dictionary) -> void:
	room = r