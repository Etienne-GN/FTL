extends Node
## GameState: holds the current run's data: player ship, enemy, sector map,
## resources and battle state. Bridges the pure-data Ship model to the UI.

signal ship_ready
signal enemy_changed
signal run_over(victory: bool)
signal battle_tick(delta: float)

var player_ship: Ship = null
var enemy_ship: Ship = null
var in_battle := false
var paused := false
var run_active := false

var sector := 0
var map: SectorMap = null
var beacons: Array = []          # Dictionary beacon nodes
var current_beacon: Dictionary = {}
var fleet_offset := 0.0          # rebel fleet advance
var jumped_this_sector := 0
var victory_flag := false

var last_result := ""
var pending_encounter: Dictionary = {}   # {action, ...} at current beacon

func new_run(ship_id: String = "kestrel") -> void:
	var def := Content.get_ship(ship_id)
	player_ship = Ship.create(def, "player")
	paused = false
	in_battle = false
	run_active = true
	victory_flag = false
	sector = 1
	map = SectorMap.new()
	map.generate(sector)
	beacons = map.beacons
	beacons = []
	fleet_offset = 0.0
	jumped_this_sector = 0
	pending_encounter = {}
	ship_ready.emit()

func spawn_enemy(rank: int = 0) -> Ship:
	var e := _make_enemy(rank)
	enemy_ship = e
	in_battle = true
	enemy_changed.emit()
	return e

func _make_enemy(rank: int) -> Ship:
	var def := _enemy_def(rank)
	return Ship.create(def, "enemy")

func _enemy_def(rank: int) -> Dictionary:
	# Generate a weighted enemy ship definition by rank (0..7 sector).
	var difficulty := 0.7 + float(rank) * 0.2
	var hull := int(round(5 + difficulty * 2))
	var reactor := int(round(3 + difficulty))
	var shield_lvl := 1 if rank >= 1 else 0
	if rank >= 4:
		shield_lvl = 2
	var engine_lvl := 1 + int(rank / 2)
	var weapons: Array = []
	var pool := ["basic_laser", "burst_laser_1", "emp_laser", "artemis", "fire_beam"]
	for i in range(1 + int(rank / 2)):
		weapons.append(pool[randi() % pool.size()])
	var weapon_lvl := 2 + int(rank / 2)
	var sys_cfg := {
		"shields": {"level": shield_lvl},
		"engines": {"level": engine_lvl},
		"weapons": {"level": weapon_lvl},
		"oxygen": {"level": 1},
	}
	var start_power := {"shields": mini(1, reactor), "engines": mini(1, reactor), "weapons": mini(1, reactor)}
	# higher-rank enemies get a teleporter for boarding
	var has_tp := rank >= 3
	if has_tp and reactor >= 4:
		sys_cfg["teleporter"] = {"level": 1}
		start_power["teleporter"] = 1
	var crew := _enemy_crew(rank)
	return {
		"id": "enemy_%d" % rank,
		"name": "Enemy Frigate",
		"grid": {"w": 12, "h": 6},
		"hull": hull,
		"reactor": reactor,
		"power": start_power,
		"start_fuel": 0,
		"start_missiles": 0,
		"start_drone_parts": 0,
		"start_scrap": 0,
		"crew": crew,
		"systems": sys_cfg,
		"weapons": weapons,
		"drones": [],
		"rooms": _enemy_rooms(),
	}

func _enemy_crew(rank: int) -> Array:
	var count := clampi(1 + int(rank / 2), 1, 4)
	var races := ["human", "human", "mantis", "rock", "engi"]
	var out: Array = []
	for i in range(count):
		out.append({"name": "Intruder %d" % i, "race": races[randi() % races.size()]})
	return out

func _enemy_rooms() -> Array:
	return [
		{"id": "shield", "system": "shields", "x": 1, "y": 0, "w": 4, "h": 1},
		{"id": "piloting", "system": "piloting", "x": 6, "y": 0, "w": 3, "h": 2},
		{"id": "weapons", "system": "weapons", "x": 0, "y": 2, "w": 4, "h": 2},
		{"id": "engines", "system": "engines", "x": 8, "y": 2, "w": 4, "h": 2},
		{"id": "oxygen", "system": "oxygen", "x": 3, "y": 4, "w": 4, "h": 2},
	]

func is_over() -> bool:
	if player_ship != null and player_ship.hull <= 0.0:
		run_active = false
		last_result = "destroyed"
		run_over.emit(false)
		return true
	if victory_flag:
		run_active = false
		last_result = "victory"
		run_over.emit(true)
		return true
	return false

func add_resources(fuel_add: int = 0, missile_add: int = 0, drone_add: int = 0, scrap_add: int = 0) -> void:
	if player_ship == null:
		return
	player_ship.fuel = maxi(0, player_ship.fuel + fuel_add)
	player_ship.missiles = maxi(0, player_ship.missiles + missile_add)
	player_ship.drone_parts = maxi(0, player_ship.drone_parts + drone_add)
	player_ship.scrap = maxi(0, player_ship.scrap + scrap_add)

# ----- Run structure (sector map / jumps / encounters) -----

func can_jump() -> bool:
	return map != null and map.can_jump() and player_ship != null and player_ship.fuel >= 1

func attempt_jump(beacon_id: String, distance: int) -> bool:
	if player_ship == null or map == null:
		return false
	if player_ship.fuel < 1:
		return false
	if not map.jump_to(beacon_id):
		return false
	player_ship.fuel -= 1
	player_ship.charge_jump()
	# risky jumps may damage hull
	if distance > 1 and randf() < 0.12 * (distance - 1):
		player_ship.damage_hull(1.0)
	pending_encounter = _make_encounter()
	return true

func _make_encounter() -> Dictionary:
	var b := map.current()
	match b.type:
		"battle":
			spawn_enemy(sector)
			return {"action": "battle"}
		"event":
			return {"action": "event", "event": Content.random_event()}
		"store":
			return {"action": "store"}
		"exit":
			if sector >= 8:
				spawn_enemy(9)
				return {"action": "battle", "boss": true}
			return {"action": "next_sector"}
	return {"action": "empty"}

func resolve_event(choice_index: int) -> String:
	var enc: Dictionary = pending_encounter
	var ev: Dictionary = enc.get("event", {})
	var choices: Array = ev.get("choices", [])
	if choice_index >= choices.size():
		return "No choice."
	var outcome: Dictionary = choices[choice_index].get("outcome", {})
	var scrap_add := int(outcome.get("scrap", 0))
	add_resources(int(outcome.get("fuel", 0)), int(outcome.get("missiles", 0)),
		int(outcome.get("drone_parts", 0)), scrap_add)
	var dmg := float(outcome.get("damage", 0.0))
	if dmg > 0.0:
		player_ship.damage_hull(dmg)
	if outcome.has("battle"):
		spawn_enemy(sector)
		pending_encounter = {"action": "battle"}
		return "Battle!"
	if outcome.get("crew_lose", 0) > 0 and not player_ship.crew.is_empty():
		var removed: Array = player_ship.crew.pop_back()
	pending_encounter = {}
	return "Resolved."

func next_sector() -> void:
	sector += 1
	if sector > 8:
		victory_flag = true
		return
	map.generate(sector)
	beacons = map.beacons
	pending_encounter = {}
	player_ship.refresh_after_sector()