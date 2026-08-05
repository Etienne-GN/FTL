class_name Ship
extends RefCounted
## The complete runtime model of a starship: rooms, systems, power,
## crew, weapons, drones, shields, hull, oxygen and jump state.
## Pure data/logic (no rendering) so it can be simulated and tested.

const TILE := 48

var def: Dictionary = {}
var ship_id: String = ""
var side: String = "player"          # "player" | "enemy"
var grid: Vector2i = Vector2i(14, 7)

var rooms: Dictionary = {}            # id -> room dict
var room_order: Array = []            # stable room id list
var systems: Dictionary = {}          # id -> SystemState
var crew: Array = []                  # CrewMember
var weapons: Array = []               # WeaponState
var drones: Array = []                # DroneState
var boarders: Array = []              # CrewMember hostile to this ship (on-board)

var hull: float = 6.0
var hull_max: float = 6.0
var reactor: int = 4
var battery: float = 0.0              # extra power from battery system

var fuel := 0
var missiles := 0
var drone_parts := 0
var scrap := 0

var shield_bubbles := 0
var shield_max := 0
var shield_recharge := 0.0
var shield_recharge_time := 5.0

var o2_level: float = 1.0
var door_power := 1.0
var doors_locked := false     # powered doors lock: slows non-mantis boarders

var jump_charge := 0.0
var jump_target := 0.0                 # 1.0 = charged
var jumping := false
var jump_ready := false

var cloak_active := false
var cloak_timer := 0.0
var cloak_duration := 5.0
var cloak_charge := 1.0

var battery_capacity := 0                 # 1 if backup battery installed
var battery_active := false               # currently granting +1 power
var battery_time := 0.0                   # seconds remaining of active battery

var weapons_powered_override := true
var enemy_ai := true                   # enemy auto-targets

signal power_changed(system_id: String, power: int)
signal hull_changed(amount: float)
signal shield_changed(bubbles: int)

static func create(def_dict: Dictionary, side_name: String) -> Ship:
	var s := Ship.new()
	s.def = def_dict
	s.ship_id = def_dict.get("id", "ship")
	s.side = side_name
	s._build_layout()
	s._build_systems()
	s._build_weapons_drones()
	s._build_crew()
	return s

func _build_layout() -> void:
	var g: Dictionary = def.get("grid", {"w": 14, "h": 7})
	grid = Vector2i(int(g.get("w", 14)), int(g.get("h", 7)))
	var layout: Array = def.get("rooms", [])
	room_order.clear()
	rooms.clear()
	for r in layout:
		var rect := Rect2i(int(r.x), int(r.y), int(r.w), int(r.h))
		var room := {
			"id": str(r.id),
			"system": str(r.get("system", "")),
			"rect": rect,
			"oxygen": 1.0,
			"fire": 0.0,
			"breach": false,
		}
		rooms[room.id] = room
		room_order.append(room.id)

func _build_systems() -> void:
	systems.clear()
	hull_max = float(def.get("hull", 6))
	hull = hull_max
	reactor = int(def.get("reactor", 4))
	fuel = int(def.get("start_fuel", 6))
	missiles = int(def.get("start_missiles", 5))
	drone_parts = int(def.get("start_drone_parts", 0))
	scrap = int(def.get("start_scrap", 0))
	var sys_cfg: Dictionary = def.get("systems", {})
	for sid in Content.systems:
		var base := 0
		if sys_cfg.has(sid):
			base = int(sys_cfg[sid].get("level", 0))
		if base > 0:
			systems[sid] = SystemState.new(Content.get_system(sid), base, reactor)
	# ensure core systems exist even at level 0
	for sid in ["shields", "engines", "weapons", "oxygen"]:
		if not systems.has(sid):
			systems[sid] = SystemState.new(Content.get_system(sid), 0, reactor)
	# create states for any system referenced by a room (even if level 0)
	for r in rooms.values():
		var rid: String = r.system
		if rid != "" and not systems.has(rid) and Content.systems.has(rid):
			systems[rid] = SystemState.new(Content.get_system(rid), 0, reactor)
	# starting power allocation (player-configured per ship)
	var start_power: Dictionary = def.get("power", {})
	for sid in start_power:
		if systems.has(sid):
			allocate_power(sid, int(start_power[sid]))
	_refresh_shields()
	shield_recharge_time = systems.shields.stat("recharge_time", 5.0)

func _build_weapons_drones() -> void:
	weapons.clear()
	drones.clear()
	for wid in def.get("weapons", []):
		var wdef := Content.get_weapon(wid)
		if not wdef.is_empty():
			weapons.append(WeaponState.new(wdef))
	for did in def.get("drones", []):
		var ddef := Content.get_drone(did)
		if not ddef.is_empty():
			drones.append(DroneState.new(ddef))

func _build_crew() -> void:
	crew.clear()
	for c in def.get("crew", []):
		crew.append(CrewMember.new(c))
	# place crew in nearest room or a useful room
	var i := 0
	for cm in crew:
		var room_id := _crew_start_room(i)
		cm.ship = self
		cm.assign_room(rooms[room_id])
		cm.pos = _room_center_tile(room_id)
		cm.task = "man"
		i += 1

func add_crew(cdef: Dictionary) -> CrewMember:
	var cm := CrewMember.new(cdef)
	cm.ship = self
	var rid := _crew_start_room(crew.size())
	cm.assign_room(rooms[rid])
	cm.pos = _room_center_tile(rid)
	cm.task = "man"
	crew.append(cm)
	return cm

func _crew_start_room(i: int) -> String:
	# scatter across rooms with systems
	var prefer: Array = ["piloting", "weapons", "shields", "medbay", "engines"]
	for p in prefer:
		if room_with_system(p) != "":
			return room_with_system(p)
	return room_order[0]

func room_with_system(sid: String) -> String:
	for r in room_order:
		if rooms[r].system == sid:
			return r
	return ""

func install_system(sid: String) -> bool:
	if systems.has(sid) or not Content.systems.has(sid):
		return false
	var st := SystemState.new(Content.get_system(sid), 1, reactor)
	systems[sid] = st
	# give the new system a physical room (reuse an empty room or carve a new one)
	var rid := ""
	for r in room_order:
		if rooms[r].system == "":
			rid = r
			break
	if rid == "":
		rid = "sys_%s" % sid
		var rect := Rect2i(0, grid.y - 2, 3, 2)
		var room := {"id": rid, "system": sid, "rect": rect, "oxygen": 1.0, "fire": 0.0, "breach": false}
		rooms[rid] = room
		room_order.append(rid)
	else:
		rooms[rid].system = sid
	if sid == "shields":
		_refresh_shields()
	return true

func _refresh_shields() -> void:
	var sys: SystemState = systems.get("shields")
	shield_max = sys.stat("levels", 0)
	shield_recharge_time = sys.stat("recharge_time", 5.0)
	if not sys.active() or sys.is_destroyed():
		shield_max = 0
	shield_bubbles = mini(shield_bubbles, shield_max)
	# drones may add shield bubbles
	shield_max += _shield_drone_bonus()
	shield_bubbles = mini(shield_bubbles, shield_max)

func _shield_drone_bonus() -> int:
	var bonus := 0
	for d in drones:
		if d.type == "shield":
			bonus += int(d.def.get("shield_bubble_add", 1))
	return bonus

# ----- Power -----

func total_power_used() -> int:
	var total := 0
	for sys in systems.values():
		total += sys.power
	return total

func available_power() -> int:
	var total := reactor + int(battery)
	return total - total_power_used()

func allocate_power(sid: String, new_power: int) -> bool:
	var sys: SystemState = systems.get(sid)
	if sys == null:
		return false
	new_power = clamp(int(new_power), 0, sys.level)
	var delta := new_power - sys.power
	if delta > 0 and delta > available_power():
		return false
	sys.power = new_power
	if sid == "shields":
		_refresh_shields()
	power_changed.emit(sid, new_power)
	return true

func is_powered(sid: String) -> bool:
	var sys: SystemState = systems.get(sid)
	return sys != null and sys.active() and not sys.is_destroyed()

func set_battery(v: float) -> void:
	battery = maxf(0.0, v)

const BATTERY_DURATION := 12.0
const BATTERY_RECHARGE := 30.0

func battery_ready() -> bool:
	return battery_capacity > 0 and not battery_active and battery_time <= 0.0

func activate_battery() -> bool:
	if not battery_ready():
		return false
	battery_active = true
	battery_time = BATTERY_DURATION
	battery = 1.0
	return true

func battery_tick(delta: float) -> void:
	if battery_capacity <= 0:
		return
	if battery_active:
		battery_time -= delta
		if battery_time <= 0.0:
			battery_active = false
			battery = 0.0
			battery_time = BATTERY_RECHARGE   # countdown recharge
			for sys in systems.values():
				sys.power = mini(sys.power, sys.level)
	else:
		# recharge countdown runs while not active
		if battery_time > 0.0:
			battery_time -= delta
			if battery_time < 0.0:
				battery_time = 0.0

# ----- Combat helpers -----

func dodge_chance() -> float:
	var sys: SystemState = systems.get("engines")
	if not is_powered("engines"):
		return 0.0
	var base := float(sys.stat("levels", 0))
	var manning := 0.0
	if _room_manned(system_room_id("engines")):
		manning = 5.0
	var pilot_bonus := 0.0
	var pilot_room := system_room_id("piloting")
	if _room_manned(pilot_room):
		pilot_bonus = 5.0
	var cloak_bonus := 30.0 if cloak_active else 0.0
	return clampf(base + manning + pilot_bonus + cloak_bonus, 0.0, 45.0)

func system_room_id(sid: String) -> String:
	return room_with_system(sid)

func _room_manned(room_id: String) -> bool:
	if room_id == "":
		return false
	for cm in crew:
		if cm.room.id == room_id and cm.alive():
			return true
	return false

# Zoltan crew grant one extra power pip to the system of the room they occupy.
func zoltan_bonus(sid: String) -> int:
	var rid := system_room_id(sid)
	if rid == "":
		return 0
	var bonus := 0
	for cm in crew:
		if cm.alive() and cm.race == "zoltan" and cm.room.id == rid:
			bonus += 1
	return bonus

func _ship_alive() -> bool:
	return hull > 0.0

func hull_ratio() -> float:
	return clampf(hull / hull_max, 0.0, 1.0)

func damage_hull(amount: float) -> void:
	hull = maxf(0.0, hull - amount)
	hull_changed.emit(-amount)
	_refresh_shields()

func repair_hull(amount: float) -> void:
	hull = minf(hull_max, hull + amount)
	hull_changed.emit(amount)

# Apply a landed projectile hit to a room.
func apply_room_hit(room_id: String, damage: float, weapon_def: Dictionary) -> void:
	if not rooms.has(room_id):
		return
	var room: Dictionary = rooms[room_id]
	var sys_id: String = room.system
	var breach_chance := float(weapon_def.get("breach_chance", 0.0))
	var fire_chance := float(weapon_def.get("fire_chance", 0.0))
	if damage > 0.0 and sys_id != "" and systems.has(sys_id):
		var sys: SystemState = systems[sys_id]
		if sys.health > 0:
			sys.health = 0
			_room_damage_sys(sys, room)
	if damage > 0.0:
		damage_hull(damage)
	if fire_chance > 0.0 and randf() < fire_chance:
		room.fire = minf(1.0, room.fire + 1.0)
	if breach_chance > 0.0 and randf() < breach_chance:
		room.breach = true
		_apply_breach(room)

func _room_damage_sys(sys: SystemState, room: Dictionary) -> void:
	# systems take one "hit" then go damaged; further hits go to hull
	sys.health = 0

func apply_ion(sid: String, amount: int) -> void:
	var sys: SystemState = systems.get(sid)
	if sys != null:
		sys.ion = maxi(sys.ion, amount)

func random_room_id() -> String:
	if room_order.is_empty():
		return ""
	return room_order[randi() % room_order.size()]

func room_rect_px(room_id: String) -> Rect2:
	var r: Dictionary = rooms[room_id]
	var rect: Rect2i = r.rect
	return Rect2(rect.position * TILE, rect.size * TILE)

func center_px(room_id: String) -> Vector2:
	var rr := room_rect_px(room_id)
	return rr.position + rr.size / 2.0

# ----- O2 / fires / breaches -----

func _process_environment(delta: float) -> void:
	var o2sys: SystemState = systems.get("oxygen")
	var gen := 0.0
	if o2sys.active() and not o2sys.is_destroyed():
		gen = float(o2sys.stat("o2_gen", 0.1))
	var vented := 0.0
	for r in room_order:
		var room: Dictionary = rooms[r]
		if room.breach:
			vented += 2.0
		# fires consume oxygen and can spread
		if room.fire > 0.0:
			room.oxygen = maxf(0.0, room.oxygen - 0.05 * delta * 4.0)
			if randf() < room.fire * delta:
				var nb := _neighbors(r)
				if not nb.is_empty():
					var nr = nb[randi() % nb.size()]
					rooms[nr].fire = minf(1.0, rooms[nr].fire + 0.5)
	o2_level += gen * delta * 6.0
	o2_level = clampf(o2_level, 0.0, 1.0)
	for r in room_order:
		var room: Dictionary = rooms[r]
		if room.breach:
			room.oxygen = maxf(0.0, room.oxygen - 2.0 * delta)
		else:
			room.oxygen = move_toward(room.oxygen, o2_level, delta)

func _neighbors(room_id: String) -> Array:
	# Rooms connect if their rectangles come within 1 tile of each other
	# (ships have 1-tile corridor gaps between rooms).
	var out: Array = []
	var rect: Rect2i = rooms[room_id].rect
	for r in room_order:
		if r == room_id:
			continue
		var rr: Rect2i = rooms[r].rect
		if rect.grow(2).intersects(rr):
			out.append(r)
	return out

func _apply_breach(room: Dictionary) -> void:
	room.breach = true

# ----- Crew tasks -----

func assign_crew_to_room(cm: CrewMember, room_id: String) -> void:
	if not rooms.has(room_id):
		return
	var from_room: String = cm.room.id if not cm.room.is_empty() else ""
	cm.assign_room(rooms[room_id])
	cm.target_room_id = room_id
	cm.path.clear()
	if from_room != "" and from_room != room_id:
		cm.task = "move"
		cm.path = path_between(from_room, room_id)
		cm.pos = _room_center_tile(from_room)
	else:
		cm.task = "man"

func path_between(from_id: String, to_id: String) -> Array:
	# BFS over adjacent rooms.
	if from_id == to_id:
		return []
	var frontier: Array = [[from_id]]
	var seen := {from_id: true}
	while not frontier.is_empty():
		var path: Array = frontier.pop_front()
		var last: String = path[path.size() - 1]
		for n in _neighbors(last):
			if seen.has(n):
				continue
			seen[n] = true
			var np: Array = path.duplicate()
			np.append(n)
			if n == to_id:
				return np.slice(1)
			frontier.append(np)
	return []

func _room_center_tile(room_id: String) -> Vector2:
	var rect: Rect2i = rooms[room_id].rect
	return Vector2(rect.position) + Vector2(rect.size) * 0.5

func _process_crew(delta: float) -> void:
	for cm in crew:
		if not cm.alive():
			continue
		_process_crew_one(cm, delta)
	_process_boarders(delta)

func _process_crew_one(cm: CrewMember, delta: float) -> void:
	_move_crew(cm, delta)
	var room: Dictionary = cm.room
	# hazard damage
	if room.fire > 0.3 and not _fire_resist(cm):
		cm.hp -= 3.0 * delta
	if room.oxygen < 0.2 and cm.needs_oxygen():
		cm.hp -= 3.0 * delta
	# medbay heal
	var medroom := system_room_id("medbay")
	if medroom != "" and room.id == medroom and is_powered("medbay"):
		cm.hp = minf(cm.max_hp, cm.hp + float(systems.medbay.stat("heal_rate", 2.0)) * delta)
	# auto behaviors when not traveling
	if cm.task == "move":
		return
	var sys: SystemState = systems.get(room.system)
	# manning a powered station earns skill xp
	if room.system != "" and is_powered(room.system):
		var skill := _station_skill(room.system)
		if skill != "":
			cm.gain_xp(skill, 8.0 * delta)
	# fight fire
	if room.fire > 0.2:
		if not _fire_resist(cm):
			room.fire = maxf(0.0, room.fire - cm.skill_bonus("repair") * delta * 0.8)
			cm.gain_xp("repair", 6.0 * delta)
	# repair damaged system in this room
	if sys != null and sys.health < 1:
		sys.health = 1
		cm.hp = maxf(0.0, cm.hp - 1.0)  # small hp cost to simulate risk
		cm.gain_xp("repair", 10.0 * delta)
	# combat with hostiles present
	var hostiles := _hostiles_in_room(cm.room.id)
	if not hostiles.is_empty():
		_crew_fight(cm, hostiles, delta)
		cm.gain_xp("fight", 5.0 * delta)

func _station_skill(sid: String) -> String:
	match sid:
		"weapons":
			return "weapons"
		"shields":
			return "shields"
		"engines":
			return "engines"
		"piloting":
			return "piloting"
		"drones":
			return "drones"
		"medbay":
			return "med"
		"oxygen":
			return "oxygen"
	return ""

func _move_crew(cm: CrewMember, delta: float) -> void:
	if cm.path.is_empty():
		return
	var next_room: String = cm.path[0]
	var target: Vector2 = _room_center_tile(next_room)
	var dir: Vector2 = target - cm.pos
	var dist: float = dir.length()
	var step: float = cm.speed * delta
	# powered doors slow non-mantis boarders trying to move through the ship
	if doors_locked and boarders.has(cm) and cm.race != "mantis" and is_powered("doors"):
		step *= 0.55
	if dist <= step:
		cm.pos = target
		cm.path.pop_front()
		cm.assign_room(rooms[next_room])
		if cm.path.is_empty():
			cm.task = "man"
	else:
		cm.pos += dir / dist * step

func _hostiles_in_room(room_id: String) -> Array:
	var out: Array = []
	for b in boarders:
		if b.alive() and b.room.id == room_id:
			out.append(b)
	return out

func _crew_fight(cm: CrewMember, hostiles: Array, delta: float) -> void:
	for h in hostiles:
		if not h.alive():
			continue
		var dmg := 1.2 * cm.skill_bonus("fight") * delta
		h.hp -= dmg
		# retaliation
		var rdmg: float = 1.2 * float(h.skill_bonus("fight")) * delta
		cm.hp -= rdmg
		if cm.hp <= 0.0:
			cm.hp = 0.0
		break

func _fire_resist(cm: CrewMember) -> bool:
	var stats = CrewMember.RACES.get(cm.race, {})
	return stats.get("fire_resist", false)

func _process_boarders(delta: float) -> void:
	for b in boarders:
		if not b.alive():
			continue
		_move_crew(b, delta)
		# pick a target room when idle: a crewed room to fight, else a system room
		if b.task == "man" or b.path.is_empty():
			var target := _boarder_target(b)
			if target != "":
				b.task = "move"
				b.path = path_between(b.room.id, target)
		# hazards
		if b.room.fire > 0.3 and not _fire_resist(b):
			b.hp -= 3.0 * delta
		# damage systems when unopposed
		var defenders := _crew_in_room(b.room.id)
		if defenders.is_empty():
			var sys: SystemState = systems.get(b.room.system)
			if sys != null and sys.health > 0:
				if randf() < 0.5 * delta:
					sys.health = 0
			# also damage hull slowly when in a room with a system-less interior? skip
		else:
			_crew_fight(defenders[0], [b], delta)
			defenders[0].gain_xp("fight", 5.0 * delta)
			b.gain_xp("fight", 5.0 * delta)
	# remove dead boarders
	boarders = boarders.filter(func(c): return c.alive())

func _crew_in_room(room_id: String) -> Array:
	var out: Array = []
	for cm in crew:
		if cm.alive() and cm.room.id == room_id:
			out.append(cm)
	return out

func _boarder_target(b: CrewMember) -> String:
	# prefer a room with crew to fight, else a powered system room
	for cm in crew:
		if cm.alive():
			return cm.room.id
	var prefer := ["weapons", "shields", "engines", "oxygen", "medbay"]
	for p in prefer:
		var rid := system_room_id(p)
		if rid != "":
			return rid
	return random_room_id()

# ----- Teleporter / boarding -----

var teleporter_charge := 1.0

func teleporter_ready() -> bool:
	return is_powered("teleporter") and teleporter_charge >= 1.0

func teleporter_charge_time() -> float:
	return float(systems.teleporter.stat("charge_time", 20.0))

func _process_teleporter(delta: float) -> void:
	if not is_powered("teleporter"):
		return
	if teleporter_charge < 1.0:
		teleporter_charge = minf(1.0, teleporter_charge + delta / maxf(teleporter_charge_time(), 0.1))

func crew_in_room_ids(room_id: String) -> Array:
	var out: Array = []
	for cm in crew:
		if cm.alive() and cm.room.id == room_id:
			out.append(cm)
	return out

func teleport_crew_to(target: Ship, room_id: String) -> bool:
	if not teleporter_ready():
		return false
	if not target.rooms.has(room_id):
		return false
	_sfx("teleport")
	var tp_room := system_room_id("teleporter")
	if tp_room == "":
		return false
	var to_send := crew_in_room_ids(tp_room)
	if to_send.is_empty():
		return false
	for cm in to_send:
		cm.hostile = true
		cm.assign_room(target.rooms[room_id])
		cm.pos = target._room_center_tile(room_id)
		cm.path.clear()
		cm.task = "man"
		target.boarders.append(cm)
		crew.erase(cm)
	teleporter_charge = 0.0
	return true

func recall_boarding(from: Ship) -> void:
	if not teleporter_ready():
		return
	var tp_room := system_room_id("teleporter")
	var returned: Array = []
	for b in from.boarders:
		if b.alive() and b.ship == self:
			b.ship = self
			b.hostile = false
			b.assign_room(rooms[tp_room])
			b.pos = _room_center_tile(tp_room)
			b.path.clear()
			b.task = "man"
			crew.append(b)
			returned.append(b)
	for b in returned:
		from.boarders.erase(b)
	if not returned.is_empty():
		teleporter_charge = 0.0

# ----- Weapon/drone control -----

func weapons_online() -> Array:
	var ws: SystemState = systems.get("weapons")
	if not is_powered("weapons"):
		return []
	var out: Array = []
	for w in weapons:
		if w.enabled:
			out.append(w)
	return out

func drones_online() -> Array:
	var ds: SystemState = systems.get("drones")
	if not is_powered("drones"):
		return []
	var out: Array = []
	for d in drones:
		if d.active:
			out.append(d)
	return out

func _process_weapons(delta: float) -> void:
	var ws: SystemState = systems.get("weapons")
	var pwr := ws.power if ws != null else 0
	pwr += zoltan_bonus("weapons")
	var consumed := 0
	for w in weapons:
		if not w.enabled:
			continue
		# weapons consume power from weapon system pool
		if consumed + w.power_cost() <= pwr:
			consumed += w.power_cost()
			w._process(delta)
		else:
			w.charge = 0.0
			w.ready = false

func _process_drones(delta: float) -> void:
	var ds: SystemState = systems.get("drones")
	var pwr := ds.power if ds != null else 0
	pwr += zoltan_bonus("drones")
	var consumed := 0
	for d in drones:
		if not d.active:
			continue
		if consumed + d.power_cost() <= pwr:
			consumed += d.power_cost()
			d._process(delta)
		else:
			d.charge = 0.0

func _process_jump(delta: float) -> void:
	if jump_ready:
		return
	var eng: SystemState = systems.get("engines")
	var rate := 0.5 if eng != null and eng.active() else 0.0
	jump_charge += rate * delta
	if jump_charge >= 1.0:
		jump_charge = 1.0
		jump_ready = true

func charge_jump() -> void:
	jump_charge = 0.0
	jump_ready = false

func _process_cloak(delta: float) -> void:
	if not is_powered("cloak"):
		return
	if cloak_active:
		cloak_timer -= delta
		if cloak_timer <= 0.0:
			cloak_active = false
			cloak_charge = 0.0
	elif cloak_charge < 1.0:
		var cd := float(systems.cloak.stat("charge_time", 20.0))
		cloak_charge = minf(1.0, cloak_charge + delta / maxf(cd, 0.1))

func cloak_ready() -> bool:
	return is_powered("cloak") and not cloak_active and cloak_charge >= 1.0

func activate_cloak() -> bool:
	if not cloak_ready():
		return false
	cloak_active = true
	cloak_charge = 0.0
	cloak_timer = float(systems.cloak.stat("duration", 6.0))
	cloak_duration = cloak_timer
	return true

# ----- Hacking (disables a target system on the enemy ship) -----

var hack_charge := 1.0
var hack_target_sys := ""
var hack_duration_left := 0.0

func hack_ready() -> bool:
	return is_powered("hacking") and hack_target_sys == "" and hack_charge >= 1.0

func hack_charge_time() -> float:
	return float(systems.hacking.stat("charge_time", 20.0))

func hack_duration() -> float:
	return float(systems.hacking.stat("hack_duration", 12.0))

func activate_hack(sid: String) -> bool:
	if not hack_ready() or not Content.systems.has(sid):
		return false
	hack_target_sys = sid
	hack_duration_left = hack_duration()
	hack_charge = 0.0
	_sfx("hack")
	return true

func _process_hack(delta: float) -> void:
	if not is_powered("hacking"):
		hack_target_sys = ""
		hack_charge = 0.0
		return
	if hack_target_sys != "":
		hack_duration_left -= delta
		if hack_duration_left <= 0.0:
			hack_duration_left = 0.0
			hack_target_sys = ""
	else:
		hack_charge = minf(1.0, hack_charge + delta / maxf(hack_charge_time(), 0.1))

# ----- Mind control (turns an enemy crew member against their ship) -----

var mc_charge := 1.0
var mc_crew: CrewMember = null

func mc_ready() -> bool:
	return is_powered("mind_control") and mc_crew == null and mc_charge >= 1.0

func mc_charge_time() -> float:
	return float(systems.mind_control.stat("charge_time", 20.0))

func mc_duration() -> float:
	return float(systems.mind_control.stat("mc_duration", 10.0))

func activate_mc(crew: CrewMember) -> bool:
	if not mc_ready() or crew == null or not crew.alive():
		return false
	mc_crew = crew
	mc_charge = 0.0
	crew.mc_timer = mc_duration()
	crew.hostile = true
	# the turned crew fights for you from inside their own hull
	var owner: Ship = crew.ship
	owner.crew.erase(crew)
	owner.boarders.append(crew)
	_sfx("mindcontrol")
	return true

func _process_mc(delta: float) -> void:
	if not is_powered("mind_control"):
		mc_crew = null
		mc_charge = 0.0
		return
	if mc_crew == null:
		mc_charge = minf(1.0, mc_charge + delta / maxf(mc_charge_time(), 0.1))
		return
	if mc_crew.mc_timer > 0.0:
		mc_crew.mc_timer -= delta
	if mc_crew.mc_timer <= 0.0 or not mc_crew.alive():
		var owner: Ship = mc_crew.ship
		owner.boarders.erase(mc_crew)
		if mc_crew.alive():
			mc_crew.hostile = false
			mc_crew.pos = owner._room_center_tile(mc_crew.room.id)
			owner.crew.append(mc_crew)
		mc_crew = null

# ----- Main tick -----

func tick(delta: float) -> void:
	_process_weapons(delta)
	_process_drones(delta)
	_process_repair_drones(delta)
	_process_environment(delta)
	_process_crew(delta)
	_process_jump(delta)
	_process_cloak(delta)
	_process_shields(delta)
	_process_teleporter(delta)
	_process_hack(delta)
	_process_mc(delta)
	# ion decay
	for sys in systems.values():
		if sys.ion > 0:
			sys.ion -= 1

func _process_repair_drones(delta: float) -> void:
	var ds: SystemState = systems.get("drones")
	if ds == null or not ds.active():
		return
	var pwr := ds.power + zoltan_bonus("drones")
	var consumed := 0
	for d in drones:
		if not d.active or d.type != "repair":
			continue
		if consumed + d.power_cost() > pwr:
			continue
		consumed += d.power_cost()
		var rate := float(d.def.get("repair_rate", 1.0))
		if hull < hull_max:
			repair_hull(rate * delta)
		for rid in room_order:
			var room: Dictionary = rooms[rid]
			if room.fire > 0.0:
				room.fire = maxf(0.0, room.fire - rate * delta * 0.5)

func _process_shields(delta: float) -> void:
	if shield_bubbles >= shield_max:
		return
	shield_recharge += delta
	if shield_recharge >= shield_recharge_time:
		shield_recharge = 0.0
		shield_bubbles = mini(shield_max, shield_bubbles + 1)
		shield_changed.emit(shield_bubbles)

func damage_bubble() -> void:
	if shield_bubbles > 0:
		shield_bubbles -= 1
		shield_changed.emit(shield_bubbles)

func can_block(pierce: int) -> bool:
	return shield_bubbles > pierce

func crew_count() -> int:
	var n := 0
	for c in crew:
		if c.alive():
			n += 1
	return n

func resource_str() -> String:
	return "Hull %d  Fuel %d  Missiles %d  DroneParts %d  Scrap %d" % [
		int(hull), fuel, missiles, drone_parts, scrap]

func refresh_after_sector() -> void:
	# advance into a new sector: reset jump, clear lingering ion
	charge_jump()
	for sys in systems.values():
		sys.ion = 0

func _sfx(name: String) -> void:
	SFX.play(name)

# ----- Serialization (save/quit) -----

func to_dict() -> Dictionary:
	var sys_d := {}
	for sid in systems:
		var s: SystemState = systems[sid]
		sys_d[sid] = {"level": s.level, "power": s.power, "health": s.health, "ion": s.ion}
	var crew_d: Array = []
	for cm in crew:
		crew_d.append({"name": cm.name, "race": cm.race, "hp": cm.hp, "room": cm.room.id, "skills": cm.skills, "xp": cm.xp})
	return {
		"ship_id": ship_id,
		"side": side,
		"hull": hull,
		"hull_max": hull_max,
		"grid": {"w": grid.x, "h": grid.y},
		"rooms": _room_defs(),
		"reactor": reactor,
		"battery": battery,
		"battery_capacity": battery_capacity,
		"battery_active": battery_active,
		"battery_time": battery_time,
		"fuel": fuel,
		"missiles": missiles,
		"drone_parts": drone_parts,
		"scrap": scrap,
		"systems": sys_d,
		"weapons": _weapon_ids(),
		"drones": _drone_ids(),
		"crew": crew_d,
		"shield_bubbles": shield_bubbles,
		"jump_charge": jump_charge,
		"cloak_active": cloak_active,
		"cloak_charge": cloak_charge,
		"hack_charge": hack_charge,
		"hack_target_sys": hack_target_sys,
		"hack_duration_left": hack_duration_left,
		"mc_charge": mc_charge,
	}

func _room_defs() -> Array:
	var out: Array = []
	for rid in room_order:
		var r: Dictionary = rooms[rid]
		var rect: Rect2i = r.rect
		out.append({"id": rid, "system": r.system, "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y})
	return out

func _weapon_ids() -> Array:
	var out: Array = []
	for w in weapons:
		out.append(w.id)
	return out

func _drone_ids() -> Array:
	var out: Array = []
	for d in drones:
		out.append(d.id)
	return out

static func from_dict(data: Dictionary) -> Ship:
	var def := {}
	if data.has("rooms") and not (data.get("rooms") as Array).is_empty():
		def = {
			"id": str(data.get("ship_id", "ship")),
			"grid": data.get("grid", {"w": 14, "h": 7}),
			"rooms": data.get("rooms", []),
			"hull": data.get("hull_max", data.get("hull", 6)),
			"reactor": data.get("reactor", 4),
			"start_fuel": 0,
			"start_missiles": 0,
			"start_drone_parts": 0,
			"start_scrap": 0,
			"weapons": data.get("weapons", []),
			"drones": data.get("drones", []),
		}
	else:
		def = Content.get_ship(str(data.get("ship_id", "kestrel")))
	var s := Ship.create(def, str(data.get("side", "player")))
	s.hull = float(data.get("hull", s.hull_max))
	s.hull = minf(s.hull, s.hull_max)
	s.reactor = int(data.get("reactor", s.reactor))
	s.battery = float(data.get("battery", 0.0))
	s.battery_capacity = int(data.get("battery_capacity", 0))
	s.battery_active = bool(data.get("battery_active", false))
	s.battery_time = float(data.get("battery_time", 0.0))
	s.fuel = int(data.get("fuel", 0))
	s.missiles = int(data.get("missiles", 0))
	s.drone_parts = int(data.get("drone_parts", 0))
	s.scrap = int(data.get("scrap", 0))
	var sys_d: Dictionary = data.get("systems", {})
	for sid in sys_d:
		if s.systems.has(sid):
			var st: SystemState = s.systems[sid]
			var sd: Dictionary = sys_d[sid]
			st.set_level(int(sd.get("level", st.level)))
			st.power = int(sd.get("power", 0))
			st.health = int(sd.get("health", 1))
			st.ion = int(sd.get("ion", 0))
	# weapons/drones already rebuilt from def; restore ids is implicit
	var crew_d: Array = data.get("crew", [])
	s.crew.clear()
	for cd in crew_d:
		var cm := CrewMember.new({"name": str(cd.get("name", "Crew")), "race": str(cd.get("race", "human")), "skills": cd.get("skills", {}), "xp": cd.get("xp", {})})
		cm.hp = float(cd.get("hp", cm.max_hp))
		var room_id: String = str(cd.get("room", ""))
		if not s.rooms.has(room_id):
			room_id = s.room_order[0]
		cm.ship = s
		cm.assign_room(s.rooms[room_id])
		cm.pos = s._room_center_tile(room_id)
		cm.task = "man"
		s.crew.append(cm)
	s.shield_bubbles = int(data.get("shield_bubbles", 0))
	s.shield_max = mini(s.shield_max, s.systems.shields.stat("levels", 0) + s._shield_drone_bonus())
	s.jump_charge = float(data.get("jump_charge", 0.0))
	if s.jump_charge >= 1.0:
		s.jump_ready = true
	s.cloak_active = bool(data.get("cloak_active", false))
	s.cloak_charge = float(data.get("cloak_charge", 1.0))
	s.hack_charge = float(data.get("hack_charge", 1.0))
	s.hack_target_sys = str(data.get("hack_target_sys", ""))
	s.hack_duration_left = float(data.get("hack_duration_left", 0.0))
	s.mc_charge = float(data.get("mc_charge", 1.0))
	return s