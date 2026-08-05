class_name SystemState
extends RefCounted
## Runtime state for one ship system (shields, engines, weapon, ...).
## - level: upgrade level (0..max_level). Raised with scrap.
## - power:  reactor power currently allocated to this system (0..level).
## A system functions only when it is powered and not damaged.

var id: String = ""
var name: String = ""
var level: int = 0
var power: int = 0
var health: int = 1          # 1 = intact, 0 = destroyed by system damage
var ion: int = 0             # ion turns remaining (disables system)
var hack_timer: float = 0.0  # seconds left of an enemy hacking drone lock
var min_power: int = 1
var max_level_def: int = 1

func _init(def: Dictionary, base_level: int, _reactor: int = 0):
	id = def.get("id", "")
	name = def.get("name", id)
	max_level_def = int(def.get("max_level", 1))
	min_power = int(def.get("min_power", 1))
	level = clampi(base_level, 0, max_level_def)
	power = 0

func set_level(l: int) -> void:
	level = clampi(l, 0, max_level_def)
	power = clampi(power, 0, level)

func stat(key: String, fallback = 0):
	return JSONHelpers.lvl(Content.get_system(id).get(key), level, fallback)

func clamp_power(v: int) -> int:
	return clampi(v, 0, level)

func active() -> bool:
	return health > 0 and level > 0 and hack_timer <= 0.0

func disabled_by_ion() -> bool:
	return ion > 0

func is_destroyed() -> bool:
	return health < 1

func level_tag() -> String:
	return "%d" % level