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
	_check(not GameState.map.reachable().is_empty(), "has reachable beacons")
	var guards := 0
	while main.state == main.State.MAP and guards < 30:
		guards += 1
		var reach: Array = GameState.map.reachable()
		if reach.is_empty():
			GameState.next_sector()
			continue
		main._on_beacon_clicked(reach[0])
		await get_tree().process_frame
	_check(guards < 30, "reached an encounter")
	_check(main.state == main.State.COMBAT and main.combat_screen != null, "combat screen active")
	main._on_combat_end(GameState.player_ship)
	await get_tree().process_frame
	_check(main.state == main.State.MAP, "returns to map after combat")
	print("FLOW ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _check(ok: bool, name: String) -> void:
	print(("[ok] " if ok else "[FAIL] ") + name)
	if not ok:
		fails += 1
