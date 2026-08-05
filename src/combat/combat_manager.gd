class_name CombatManager
extends RefCounted
## Drives combat between the player ship and the enemy ship:
## weapon charging -> firing -> projectile flight -> resolution (dodge,
## shields, drones), plus basic enemy AI and combat drones.

signal projectile_fired(from_ship: Ship, projectile: Dictionary)
signal ship_hit(target: Ship, room_id: String, damage: float)
signal ship_dodged(target: Ship)
signal shot_blocked(target: Ship)

var player: Ship
var enemy: Ship
var projectiles: Array = []       # flying projectiles
var time := 0.0
var enemy_think := 0.0
var combat_active := false
var hazard := ""
var _hazard_tick := 0.0

func _init(p: Ship, e: Ship, hazard_id: String = ""):
	player = p
	enemy = e
	hazard = hazard_id
	combat_active = true

func tick(delta: float) -> void:
	if not combat_active:
		return
	time += delta
	player.tick(delta)
	enemy.tick(delta)
	_apply_hacks()
	_player_fire()
	_enemy_ai(delta)
	_drones(delta)
	_advance_projectiles(delta)
	_process_hazard(delta)
	_check_end()

func _apply_hacks() -> void:
	_apply_hack_from(player, enemy)
	_apply_hack_from(enemy, player)

func _apply_hack_from(hacker: Ship, victim: Ship) -> void:
	if hacker.hack_target_sys == "" or not victim.systems.has(hacker.hack_target_sys):
		return
	victim.systems[hacker.hack_target_sys].hack_timer = maxf(0.0, hacker.hack_duration_left)

func _process_hazard(delta: float) -> void:
	if hazard == "":
		return
	_hazard_tick += delta
	var interval := 2.5
	if _hazard_tick < interval:
		return
	_hazard_tick = 0.0
	match hazard:
		"asteroid":
			# stray rock: may hit either ship
			var target := enemy if randf() < 0.5 else player
			if target.shield_bubbles > 0:
				target.damage_bubble()
			else:
				target.apply_room_hit(target.random_room_id(), 1.0, {"fire_chance": 0.0, "breach_chance": 0.05})
		"sun":
			for s in [player, enemy]:
				s.rooms[s.random_room_id()].fire = minf(1.0, s.rooms[s.random_room_id()].fire + 0.5)
		"ion":
			for s in [player, enemy]:
				if not s.systems.is_empty():
					var sys: SystemState = s.systems[s.systems.keys()[randi() % s.systems.size()]]
					sys.ion = maxi(sys.ion, 1)

func _player_fire() -> void:
	for w in player.weapons_online():
		if w.ready:
			_fire_weapon(player, enemy, w)
			w.reset_charge()

func _enemy_ai(delta: float) -> void:
	enemy_think -= delta
	var should_fire := enemy_think <= 0.0
	enemy_think = 0.6
	for w in enemy.weapons_online():
		if w.ready and should_fire:
			var target := _pick_target(player, w)
			w.target_room_id = target
			_fire_weapon(enemy, player, w)
			w.reset_charge()
	_enemy_crew_ai(delta)

func _enemy_crew_ai(delta: float) -> void:
	var idle := 0
	for cm in enemy.crew:
		if not cm.alive():
			continue
		if cm.task == "move":
			continue
		# repair damaged systems first
		var rep := _damaged_system_room(enemy)
		if rep != "":
			enemy.assign_crew_to_room(cm, rep)
			continue
		idle += 1
	# manning: ensure each key station has someone
	for station in ["weapons", "shields", "engines", "piloting"]:
		if not _station_manned(enemy, station):
			for cm in enemy.crew:
				if cm.alive() and cm.task != "move":
					var rid := enemy.system_room_id(station)
					if rid != "":
						enemy.assign_crew_to_room(cm, rid)
					break
	# boarding: send crew to player ship if teleporter ready
	if enemy.teleporter_ready() and idle > 0:
		var crew_in_tp: Array = enemy.crew_in_room_ids(enemy.system_room_id("teleporter"))
		if crew_in_tp.size() < 2:
			for cm in enemy.crew:
				if cm.alive() and cm.task != "move":
					enemy.assign_crew_to_room(cm, enemy.system_room_id("teleporter"))
					idle -= 1
					break
		crew_in_tp = enemy.crew_in_room_ids(enemy.system_room_id("teleporter"))
		if not crew_in_tp.is_empty() and enemy.teleporter_ready():
			enemy.teleport_crew_to(player, _pick_target(player, null))

func _damaged_system_room(ship: Ship) -> String:
	for r in ship.room_order:
		var sid: String = ship.rooms[r].system
		if sid != "" and ship.systems.has(sid) and ship.systems[sid].health < 1:
			return r
	return ""

func _station_manned(ship: Ship, sid: String) -> bool:
	var rid := ship.system_room_id(sid)
	if rid == "":
		return false
	for cm in ship.crew:
		if cm.alive() and cm.room.id == rid:
			return true
	return false

func _pick_target(target_ship: Ship, w: WeaponState) -> String:
	# Prefer a powered, important system room; fall back to random.
	var pref := ["weapons", "shields", "engines", "oxygen", "medbay"]
	for p in pref:
		var rid := target_ship.system_room_id(p)
		if rid != "":
			return rid
	return target_ship.random_room_id()

func _fire_weapon(from: Ship, target: Ship, w: WeaponState) -> void:
	var wdef: Dictionary = w.def
	var type: String = wdef.get("type", "laser")
	if type == "beam":
		_fire_beam(from, target, w, wdef)
		return
	# missiles/bombs consume ammo
	if type == "missile" or type == "bomb":
		if from.missiles <= 0:
			w.charge = 0.0
			return
		from.missiles -= 1
	var target_room: String = w.target_room_id if w.target_room_id != "" else _pick_target(target, w)
	var shots := int(wdef.get("shots", 1))
	for i in shots:
		var travel := 1.5 + randf() * 1.5
		var proj := {
			"from": from,
			"target": target,
			"weapon": wdef,
			"room": target_room,
			"travel": travel,
			"age": 0.0,
			"dead": false,
			"pierce": int(wdef.get("pierce", 0)),
			"type": type,
		}
		projectiles.append(proj)
		projectile_fired.emit(from, proj)
	match type:
		"missile", "bomb":
			SFX.play("missile")
		"ion":
			SFX.play("ion")
		_:
			SFX.play_rand(["laser", "laser2"])

func _fire_beam(from: Ship, target: Ship, w: WeaponState, wdef: Dictionary) -> void:
	# Instant line beam: hits rooms along the beam length from target room.
	var target_room := w.target_room_id if w.target_room_id != "" else _pick_target(target, w)
	if not target.rooms.has(target_room):
		return
	var length := int(wdef.get("beam_length", 3))
	var row: int = target.rooms[target_room].rect.position.y
	var hit_rooms: Array = []
	for x in range(length):
		for r in target.room_order:
			var rr: Rect2i = target.rooms[r].rect
			if rr.position.y <= row and rr.end.y > row and rr.position.x <= target.rooms[target_room].rect.position.x + x and rr.end.x > target.rooms[target_room].rect.position.x + x:
				if not hit_rooms.has(r):
					hit_rooms.append(r)
	for rid in hit_rooms:
		_apply_hit(target, rid, wdef, true)
	SFX.play("beam")

func _drones(delta: float) -> void:
	# Player combat drones fire; defense drones intercept inbound missiles.
	for d in player.drones_online():
		if d.is_combat() and d.fire_ready():
			var wdef := {"type": "laser", "power": 1, "shots": 1, "damage": float(d.def.get("damage", 2.0)),
				"pierce": int(d.def.get("shield_bust", 1)), "fire_chance": 0.0, "breach_chance": 0.0}
			var proj := {"from": player, "target": enemy, "weapon": wdef, "room": _pick_target(enemy, null),
				"travel": 1.2 + randf(), "age": 0.0, "dead": false, "pierce": 1, "type": "laser"}
			projectiles.append(proj)
			d.reset_charge()
		if d.is_defense():
			_intercept_with(player, d)
	for d in enemy.drones_online():
		if d.is_combat() and d.fire_ready():
			var wdef := {"type": "laser", "power": 1, "shots": 1, "damage": float(d.def.get("damage", 2.0)),
				"pierce": int(d.def.get("shield_bust", 1)), "fire_chance": 0.0, "breach_chance": 0.0}
			var proj := {"from": enemy, "target": player, "weapon": wdef, "room": _pick_target(player, null),
				"travel": 1.2 + randf(), "age": 0.0, "dead": false, "pierce": 1, "type": "laser"}
			projectiles.append(proj)
			d.reset_charge()
		if d.is_defense():
			_intercept_with(enemy, d)

func _intercept_with(ship: Ship, d: DroneState) -> void:
	for p in projectiles:
		if p.dead:
			continue
		if p.target == ship and d.can_intercept(p.type):
			if randf() < 0.85:
				p.dead = true
				shot_blocked.emit(ship)
			return

func _advance_projectiles(delta: float) -> void:
	for p in projectiles:
		if p.dead:
			continue
		p.age += delta
		if p.age >= p.travel:
			p.dead = true
			_resolve_projectile(p)

func _resolve_projectile(p: Dictionary) -> void:
	var target: Ship = p.target
	var wdef: Dictionary = p.weapon
	var room_id: String = p.room
	# cloaked ships are untargetable: every shot misses
	if target.cloak_active:
		ship_dodged.emit(target)
		return
	# dodge (nebulas muddy the sensors)
	var evade := target.dodge_chance()
	if hazard == "nebula":
		evade = maxf(0.0, evade - 12.0)
	if randf() * 100.0 < evade:
		ship_dodged.emit(target)
		return
	# shields
	var pierce: int = p.pierce
	if target.shield_bubbles > pierce:
		target.damage_bubble()
		shot_blocked.emit(target)
		_sfx("shieldhit")
		# ion hits shields, disrupts recharge
		if wdef.get("type", "laser") == "ion":
			var ss: SystemState = target.systems.get("shields")
			if ss != null:
				ss.ion = maxi(ss.ion, 1)
		return
	if wdef.get("type", "laser") == "ion":
		_apply_ion_hit(target, room_id, wdef)
		return
	_apply_hit(target, room_id, wdef, false)

func _apply_ion_hit(target: Ship, room_id: String, wdef: Dictionary) -> void:
	var room: Dictionary = target.rooms.get(room_id)
	if room.is_empty():
		room_id = target.random_room_id()
		room = target.rooms.get(room_id)
	var sys_id: String = room.system
	var ion_amount := int(wdef.get("ion_damage", 1))
	if sys_id != "" and target.systems.has(sys_id):
		target.apply_ion(sys_id, ion_amount)
	ship_hit.emit(target, room_id, 0.0)

func _apply_hit(target: Ship, room_id: String, wdef: Dictionary, beam: bool) -> void:
	var damage := float(wdef.get("damage", 0.0))
	if beam and damage <= 0.0 and wdef.get("fire_chance", 0.0) > 0.0:
		damage = 0.0
	var room: Dictionary = target.rooms.get(room_id)
	if room.is_empty():
		room_id = target.random_room_id()
		room = target.rooms.get(room_id)
	target.apply_room_hit(room_id, damage, wdef)
	# beams apply ion per room
	if beam and wdef.get("ion_damage", 0) > 0 and room.system != "":
		target.apply_ion(room.system, int(wdef.get("ion_damage", 0)))
	if not beam:
		match wdef.get("type", "laser"):
			"missile", "bomb":
				_sfx("explosion")
			"ion":
				_sfx("ion")
			_:
				_sfx("hullhit")
	ship_hit.emit(target, room_id, damage)

func _sfx(name: String) -> void:
	SFX.play(name)

func _check_end() -> void:
	if player.hull <= 0.0 or enemy.hull <= 0.0:
		combat_active = false
		return
	# a ship with nobody left to fight is captured: only boarder-viable crews
	if _abandoned(enemy) and player.hull > 0.0:
		combat_active = false
		return

func _abandoned(s: Ship) -> bool:
	return s.crew_count() == 0 and s.boarders.filter(func(b): return b.alive()).size() == 0

func combat_over() -> bool:
	return not combat_active

func winner() -> Ship:
	if player.hull <= 0.0:
		return enemy
	if enemy.hull <= 0.0:
		return player
	if _abandoned(enemy):
		return player
	return null