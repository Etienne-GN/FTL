extends Node
## Debug: start a combat and dump a PNG screenshot to /tmp for layout checks.

func _ready() -> void:
	var main = get_node("../Main")
	await get_tree().process_frame
	GameState.new_run("kestrel")
	var p := GameState.player_ship
	for i in 8:
		p.add_crew({"name": "Cr%d" % i, "race": "human"})
	p.battery_capacity = 1
	GameState.enemy_ship = Ship.create(GameState._enemy_def(3), "enemy")
	GameState.pending_encounter = {"action": "battle"}
	main._resolve_encounter()
	for i in 30:
		await get_tree().process_frame
	var probs: Array = main.combat_screen._check_layout()
	await get_tree().process_frame
	var img: Image = get_window().get_texture().get_image()
	if img != null:
		img.save_png("/tmp/opencode/combat.png")
		print("COMBAT SHOT SAVED")
	else:
		print("COMBAT SHOT NULL")
	if probs.is_empty():
		print("LAYOUT OK")
	else:
		print("LAYOUT OVERLAPS: ", probs)
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
	get_tree().quit(0 if probs.is_empty() else 1)