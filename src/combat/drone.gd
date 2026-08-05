class_name DroneState
extends RefCounted
## Runtime state for a single mounted drone.

var def: Dictionary = {}
var id: String = ""
var type: String = "combat"
var charge: float = 0.0
var cooldown: float = 5.0
var active: bool = true

func _init(def_: Dictionary):
	def = def_
	id = def.get("id", "")
	type = def.get("type", "combat")
	cooldown = float(def.get("cooldown", 5.0))

func power_cost() -> int:
	return int(def.get("power", 2))

func is_combat() -> bool:
	return type == "combat" or type == "fire" or type == "beam"

func is_defense() -> bool:
	return type == "defense"

func can_intercept(projectile_type: String) -> bool:
	var intercept = def.get("interceptor", "missile")
	if intercept == "any":
		return true
	return intercept == projectile_type

func _process(delta: float) -> void:
	if not active:
		return
	charge += delta
	if charge >= cooldown:
		charge = cooldown

func fire_ready() -> bool:
	return charge >= cooldown

func reset_charge() -> void:
	charge = 0.0