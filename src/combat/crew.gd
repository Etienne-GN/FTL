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
}

var name: String = "Crew"
var race: String = "human"
var ship: Ship = null          # owning ship
var hp: float = 1.0
var max_hp: float = 1.0
var room: Dictionary = {}       # room ref {id, rect}
var skills := {}                # skill -> level (1..2)
var task: String = "idle"       # idle|man|repair|fight|move|teleport
var target_room_id: String = ""

func _init(cdef: Dictionary = {}):
	race = cdef.get("race", "human")
	name = cdef.get("name", _random_name())
	skills = cdef.get("skills", {})
	var stats = RACES.get(race, RACES["human"])
	max_hp = stats.get("hp", 1.0)
	hp = max_hp
	# starts with 3 random skills at level 1 for skill-granted crew
	skills = cdef.get("skills", {})

func _random_name() -> String:
	var names := ["Ash", "Blaine", "Chen", "Dax", "Eli", "Fennec", "Gor", "Hiss",
		"Iba", "Jax", "Kyra", "Lux", "Miko", "Nox", "Oka", "Petr", "Rae", "Syr",
		"Tessa", "Ulka", "Vesper", "Wren", "Xa", "Yuki", "Zed"]
	return names[randi() % names.size()]

func alive() -> bool:
	return hp > 0.0

func stat(skill_key: String) -> int:
	return int(skills.get(skill_key, 0))

func skill_bonus(skill_key: String) -> float:
	return 1.0 + 0.5 * stat(skill_key)

func assign_room(r: Dictionary) -> void:
	room = r