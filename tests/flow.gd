extends Node
var fails := 0
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var main = get_node("../Main")
	_check(main.state == main.State.MENU, "starts at menu")
	main._start_with("kestrel")
	await get_tree().process_frame
	_check(main.state == main.State.MAP and main.map_view != null, "starts at map with view")
	# advance through encounters until we hit a battle (robust to random map)
	var reached_combat := false
	var guards := 0
	while not reached_combat and guards < 40:
		guards += 1
		match main.state:
			main.State.MAP:
				if GameState.player_ship.fuel <= 1:
					GameState.add_resources(5, 0, 0, 0)
				var reach: Array = GameState.map.reachable()
				if reach.is_empty():
					GameState.next_sector()
				else:
					main._on_beacon_clicked(reach[0])
			main.State.EVENT:
				main._choose_event(0)
			main.State.STORE:
				main._leave_store()
			main.State.COMBAT:
				reached_combat = true
		await get_tree().process_frame
	_check(reached_combat, "reached a battle encounter")
	_check(main.combat_screen != null, "combat screen mounted")
	if main.combat_screen != null:
		var hull_before: float = GameState.player_ship.hull
		main.combat_screen._process(2.0)
		main._on_combat_end(GameState.player_ship)
		await get_tree().process_frame
		_check(main.state == main.State.MAP and main.combat_screen == null, "returns to map, screen freed")
		_check(hull_before > 0.0, "player hull intact")
	print("FLOW ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _check(ok: bool, name: String) -> void:
	print(("[ok] " if ok else "[FAIL] ") + name)
	if not ok:
		fails += 1
