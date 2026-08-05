extends Node
## Debug: start a combat and dump a PNG screenshot to /tmp for layout checks.

func _ready() -> void:
	var main = get_node("../Main")
	await get_tree().process_frame
	GameState.new_run("kestrel")
	GameState.enemy_ship = Ship.create(GameState._enemy_def(3), "enemy")
	GameState.pending_encounter = {"action": "battle"}
	main._resolve_encounter()
	for i in 30:
		await get_tree().process_frame
	var probs: Array = main.combat_screen._check_layout()
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/combat.png")
	if probs.is_empty():
		print("LAYOUT OK")
	else:
		print("LAYOUT OVERLAPS: ", probs)
	if probs.is_empty():
		get_tree().quit(0)
	else:
		get_tree().quit(1)
	# map screenshot
	main._show_map()
	for i in 5:
		await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("/tmp/opencode/map.png")
	# store screenshot
	GameState.pending_encounter = {"action": "store"}
	main._resolve_encounter()
	for i in 5:
		await get_tree().process_frame
	var img3 := get_viewport().get_texture().get_image()
	img3.save_png("/tmp/opencode/store.png")
	print("SHOT SAVED state=", main.state)
	get_tree().quit()