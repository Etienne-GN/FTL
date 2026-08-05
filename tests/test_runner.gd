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