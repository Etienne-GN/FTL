extends Node
## Headless test runner scene. Run:
##   godot --headless res://tests/test_runner.tscn

var failures := 0
var _in_progress := false

func _ready() -> void:
	run_tests()

func run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_test("content loads", _test_content())
	_run_test("ship builds", _test_ship_build())
	_run_test("power allocation", _test_power())
	_run_test("dodge math", _test_dodge())
	_run_test("crew pathing", _test_crew())
	await _test_combat()
	await _test_boarding()
	_run_test("sector map", _test_sector_map())
	_run_test("jump flow", _test_jump())
	_run_test("run completion", _test_run_completion())
	_run_test("boss encounter", _test_boss())
	_run_test("save round-trip", _test_save())
	_run_test("battery", _test_battery())
	_run_test("crew hire", _test_crew_hire())
	_run_test("crew xp", _test_crew_xp())
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _run_test(name: String, ok: bool) -> void:
	if ok:
		print("[ok] ", name)
	else:
		print("[FAIL] ", name)
		failures += 1

func _test_content() -> bool:
	var weapon := Content.get_weapon("basic_laser")
	if weapon.is_empty():
		return false
	if Content.get_ship("kestrel").is_empty():
		return false
	if Content.get_system("shields").is_empty():
		return false
	return Content.events.size() >= 1

func _test_ship_build() -> bool:
	var ship := Ship.create(Content.get_ship("kestrel"), "player")
	if ship.rooms.size() != 10:
		return false
	if ship.hull_max != 6.0:
		return false
	if ship.weapons.size() != 2:
		return false
	if ship.systems.get("shields").level != 1:
		return false
	return ship.crew.size() == 2

func _test_power() -> bool:
	var ship := Ship.create(Content.get_ship("kestrel"), "player")
	if ship.available_power() < 0:
		return false
	ship.allocate_power("shields", ship.systems.shields.level)
	ship.allocate_power("engines", ship.systems.engines.level)
	ship.allocate_power("weapons", ship.systems.weapons.level)
	return ship.available_power() >= 0

func _test_dodge() -> bool:
	var ship := Ship.create(Content.get_ship("kestrel"), "player")
	var d := ship.dodge_chance()
	return d >= 0.0 and d <= 45.0

func _test_crew() -> bool:
	var ship := Ship.create(Content.get_ship("kestrel"), "player")
	if ship.path_between("weapons", "engines").is_empty():
		return false
	var cm: CrewMember = ship.crew[0]
	ship.assign_crew_to_room(cm, "engines")
	if cm.task != "move" or cm.path.is_empty():
		return false
	# simulate movement
	var guard := 0
	while cm.task == "move" and guard < 600:
		ship._move_crew(cm, 0.5)
		guard += 1
	return cm.room.id == "engines" and guard < 600

func _test_combat() -> void:
	var p := Ship.create(Content.get_ship("kestrel"), "player")
	var e := Ship.create(GameState._enemy_def(2), "enemy")
	var combat := CombatManager.new(p, e)
	var guard := 0
	while not combat.combat_over() and guard < 2400:
		for i in 10:
			combat.tick(1.0)
		guard += 10
	if combat.winner() == null:
		_run_test("combat resolves", false)
		return
	var w := combat.winner()
	var loser: Ship = e if w == p else p
	_run_test("combat resolves", w.hull > 0.0 and loser.hull <= 0.0)
	_run_test("winner has resources", w.resource_str().length() > 0)

func _test_boarding() -> void:
	var p := Ship.create(Content.get_ship("kestrel"), "player")
	var e := Ship.create(GameState._enemy_def(3), "enemy")
	var combat := CombatManager.new(p, e)
	p.systems.teleporter.set_level(1)
	p.allocate_power("teleporter", 1)
	p.systems.teleporter.health = 1
	var tp_room: String = p.system_room_id("teleporter")
	p.assign_crew_to_room(p.crew[0], tp_room)
	# make sure the crew has arrived at the teleporter room
	var guard := 0
	while p.crew[0].task == "move" and guard < 200:
		p._move_crew(p.crew[0], 0.5)
		guard += 1
	p.teleporter_charge = 1.0
	var sent := p.teleport_crew_to(e, e.system_room_id("weapons"))
	_run_test("boarding sends crew", sent and e.boarders.size() == 1)
	# recall immediately
	p.teleporter_charge = 1.0
	p.recall_boarding(e)
	var back := p.crew_count() == 2 and e.boarders.size() == 0
	_run_test("boarding recall", back)
	# send again and let boarders damage systems
	p.teleporter_charge = 1.0
	p.assign_crew_to_room(p.crew[0], tp_room)
	guard = 0
	while p.crew[0].task == "move" and guard < 200:
		p._move_crew(p.crew[0], 0.5)
		guard += 1
	p.teleporter_charge = 1.0
	sent = p.teleport_crew_to(e, e.system_room_id("weapons"))
	var sys_before: int = e.systems.weapons.health
	guard = 0
	while sys_before == e.systems.weapons.health and guard < 200:
		combat.tick(1.0)
		guard += 1
	_run_test("boarders damage systems", e.systems.weapons.health < 1)

func _test_sector_map() -> bool:
	var m := SectorMap.new()
	m.generate(1)
	if m.beacons.size() != SectorMap.COLS * SectorMap.ROWS:
		return false
	if m.current().type != "start":
		return false
	# must be able to reach the exit column through jumps
	var reached_exit := false
	var guard := 0
	var probe := m
	while not reached_exit and guard < 20:
		guard += 1
		var r := probe.reachable()
		if r.is_empty():
			return false
		probe.jump_to(r[0])
		reached_exit = probe.at_exit()
	return reached_exit

func _test_jump() -> bool:
	GameState.new_run("kestrel")
	if not GameState.can_jump():
		return false
	var reach := GameState.map.reachable()
	if reach.is_empty():
		return false
	var fuel_before: int = GameState.player_ship.fuel
	var ok := GameState.attempt_jump(reach[0], 1)
	if not ok:
		return false
	if GameState.player_ship.fuel != fuel_before - 1:
		return false
	# jumping to exit advances sector
	return true

func _test_run_completion() -> bool:
	GameState.new_run("kestrel")
	for s in range(8):
		GameState.next_sector()
	return GameState.victory_flag

func _test_boss() -> bool:
	GameState.new_run("kestrel")
	GameState.sector = 8
	# force current beacon to be the exit and ensure boss encounter spawns
	var exit_b: Dictionary = {}
	for b in GameState.map.beacons:
		if b.type == "exit":
			exit_b = b
			break
	if exit_b.is_empty():
		return false
	GameState.map.player_id = exit_b.id
	GameState.pending_encounter = GameState._make_encounter()
	return GameState.pending_encounter.get("boss", false) and GameState.enemy_ship != null

func _test_save() -> bool:
	GameState.new_run("kestrel")
	GameState.player_ship.scrap = 33
	GameState.player_ship.fuel = 4
	GameState.player_ship.damage_hull(1.0)
	GameState.player_ship.systems.shields.set_level(2)
	var snap := GameState.snapshot()
	var restored := Ship.from_dict(snap["ship"])
	if int(restored.scrap) != 33 or int(restored.fuel) != 4:
		return false
	if absf(restored.hull - GameState.player_ship.hull) > 0.01:
		return false
	if restored.systems.shields.level != 2:
		return false
	# full GameState restore (incl. mid-battle enemy)
	GameState.spawn_enemy(3)
	GameState.in_battle = true
	var gs_snap := GameState.snapshot()
	GameState.new_run("kestrel")
	GameState.restore(gs_snap)
	if GameState.map == null or GameState.player_ship.scrap != 33 or not GameState.run_active:
		return false
	if GameState.enemy_ship == null or not GameState.in_battle:
		return false
	if GameState.enemy_ship.side != "enemy":
		return false
	return true

func _test_battery() -> bool:
	GameState.new_run("kestrel")
	var p := GameState.player_ship
	p.battery_capacity = 1
	if not p.battery_ready():
		return false
	if not p.activate_battery():
		return false
	var before := p.available_power()
	p.battery_tick(13.0)
	if p.battery_active:
		return false
	var after := p.available_power()
	if after not in [before - 1, before]:
		return false
	if p.battery_ready():
		return false
	p.battery_tick(31.0)
	if not p.battery_ready():
		return false
	# survives a save round-trip
	var snap := GameState.snapshot()
	GameState.new_run("kestrel")
	GameState.restore(snap)
	if GameState.player_ship.battery_capacity != 1 or GameState.player_ship.battery_active:
		return false
	return true

func _test_crew_hire() -> bool:
	GameState.new_run("kestrel")
	var p := GameState.player_ship
	var before := p.crew.size()
	var cm := p.add_crew({"name": "Test", "race": "mantis"})
	if p.crew.size() != before + 1:
		return false
	if cm.ship != p or cm.room == null:
		return false
	cm.hp = 40.0
	var snap := GameState.snapshot()
	GameState.new_run("kestrel")
	GameState.restore(snap)
	if GameState.player_ship.crew.size() != before + 1:
		return false
	return true

func _test_crew_xp() -> bool:
	var cm := CrewMember.new({"name": "X", "race": "human", "skills": {"weapons": 1}})
	if cm.stat("weapons") != 1:
		return false
	cm.gain_xp("weapons", 100)
	if cm.stat("weapons") != 2:
		return false
	cm.gain_xp("weapons", 500)
	if cm.stat("weapons") > 2:
		return false
	if not cm.skill_bonus("weapons") > 1.5:
		return false
	if cm.stat("fight") != 0:
		return false
	return true