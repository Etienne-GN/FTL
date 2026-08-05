extends Node
## Boss flow test: force sector 8 boss, win, assert victory + unlock.

func _ready() -> void:
	var main = get_node("../Main")
	await get_tree().process_frame
	var asserts := 0

	GameState.new_run("kestrel")
	GameState.sector = 8
	GameState.victory_flag = false
	GameState.enemy_ship = Ship.create(GameState._boss_def(), "enemy")
	GameState.pending_encounter = {"action": "battle", "boss": true}

	main._resolve_encounter()
	await get_tree().process_frame
	if main.state != main.State.COMBAT:
		print("[FAIL] boss did not enter combat")
		_quit(asserts)
		return
	asserts += 1
	print("[ok] boss enters combat")

	# give the player overwhelming firepower and wipe the boss
	var p := GameState.player_ship
	p.weapons = [WeaponState.new(Content.get_weapon("halberd_beam")), WeaponState.new(Content.get_weapon("burst_laser_2"))]
	var guard := 0
	while guard < 600 and GameState.enemy_ship.hull > 0.0:
		guard += 1
		GameState.enemy_ship.hull -= 2.0
	await get_tree().process_frame

	main._on_combat_end(GameState.player_ship)
	await get_tree().process_frame
	if main.state != main.State.OVER:
		print("[FAIL] victory screen not shown")
		_quit(asserts)
		return
	asserts += 1
	print("[ok] victory screen shown")
	if not GameState.victory_flag:
		print("[FAIL] victory flag not set")
		_quit(asserts)
		return
	asserts += 1
	print("[ok] victory flag set")

	var unlocked: Array = SaveManager.load_meta()
	if unlocked.size() < 3:
		print("[FAIL] ships not unlocked")
		_quit(asserts)
		return
	asserts += 1
	print("[ok] ships unlocked: ", unlocked)

	if asserts == 4:
		print("BOSS ALL PASSED")
	else:
		print("BOSS FAILED at asserts=", asserts)
	_quit(asserts)

func _quit(asserts: int) -> void:
	await get_tree().process_frame
	get_tree().quit()