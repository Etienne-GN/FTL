extends Node
func _ready() -> void:
	await get_tree().process_frame
	var main = get_node("../Main")
	main._start_with("kestrel")
	await get_tree().process_frame
	var guards := 0
	while guards < 25:
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
				for f in 30:
					await get_tree().process_frame
				main._on_combat_end(GameState.player_ship)
			_:
				pass
		await get_tree().process_frame
	print("smoke ok state=", main.state)
	get_tree().quit()
