extends Node
## Boss flow test: force sector 8 boss, win, assert victory + unlock.

func _ready() -> void:
	var main = get_node("../Main")
	await get_tree().process_frame
	var asserts := 0

	GameState.new_run("kestrel")
	GameState.sector = 8
	GameState.victory_flag = false
	GameState.enemy_ship = Ship.create(GameState._boss_def(1), "enemy")
	GameState.pending_encounter = {"action": "battle", "boss": true}

	# fight through all three flagship stages
	var stage_wins := 0
	for stage in 3:
		if GameState.boss_stage == 0:
			GameState.boss_stage = stage + 1
		main._resolve_encounter()
		await get_tree().process_frame
		if main.state != main.State.COMBAT:
			print("[FAIL] boss stage %d did not enter combat (state=%d, enc=%s)" % [stage + 1, main.state, GameState.pending_encounter])
			_quit(asserts)
			return
		asserts += 1
		print("[ok] boss stage %d enters combat" % (stage + 1))

		var p := GameState.player_ship
		p.weapons = [WeaponState.new(Content.get_weapon("halberd_beam")), WeaponState.new(Content.get_weapon("burst_laser_2"))]
		GameState.paused = true   # freeze the live combat screen while we force the kill
		var guard := 0
		while guard < 600 and GameState.enemy_ship.hull > 0.0:
			guard += 1
			GameState.enemy_ship.hull -= 2.0
		await get_tree().process_frame
		main.combat_screen._end_battle(GameState.player_ship)
		await get_tree().process_frame
		stage_wins += 1

	if main.state != main.State.OVER:
		print("[FAIL] victory screen not shown after 3 stages")
		_quit(asserts)
		return
	asserts += 1
	print("[ok] victory screen shown after 3 stages")
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

	if asserts == 6:
		print("BOSS ALL PASSED")
	else:
		print("BOSS FAILED at asserts=", asserts)
	_quit(asserts)

func _quit(asserts: int) -> void:
	await get_tree().process_frame
	get_tree().quit()