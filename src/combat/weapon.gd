class_name WeaponState
extends RefCounted
## Runtime state for a single mounted weapon.

var def: Dictionary = {}
var id: String = ""
var type: String = "laser"
var charge: float = 0.0
var cooldown: float = 8.0
var ready: bool = false
var enabled: bool = true
var autofire: bool = true
var target_room_id: String = ""       # empty -> auto-pick
var target_system: String = ""        # prefer a system to aim at

func _init(def_: Dictionary):
	def = def_
	id = def.get("id", "")
	type = def.get("type", "laser")
	cooldown = float(def.get("cooldown", 8.0))
	charge = 0.0
	ready = false

func power_cost() -> int:
	return int(def.get("power", 1))

func power() -> bool:
	return int(def.get("power", 1))

func _process(delta: float) -> void:
	if not enabled:
		return
	charge += delta
	if charge >= cooldown:
		charge = cooldown
		ready = true

func reset_charge() -> void:
	charge = 0.0
	ready = false

func progress() -> float:
	return clampf(charge / maxf(cooldown, 0.001), 0.0, 1.0)