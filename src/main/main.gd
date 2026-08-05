extends Node2D
## Main: boots the run, owns the CombatManager and the game loop.

var combat: CombatManager = null

func _ready() -> void:
	randomize()
	if SaveManager.has_save():
		SaveManager.load_run()
	else:
		GameState.new_run("kestrel")
	GameState.spawn_enemy(1)
	combat = CombatManager.new(GameState.player_ship, GameState.enemy_ship)
	GameState.in_battle = true
	_console("[boot] Battle started: %s vs %s" % [GameState.player_ship.ship_id, GameState.enemy_ship.ship_id])

func _process(delta: float) -> void:
	if combat == null or GameState.paused:
		return
	combat.tick(delta)
	if combat.combat_over():
		var w := combat.winner()
		if w != null:
			_console("[combat] Victor: %s (%s)" % [w.ship_id, w.side])
			combat = null
			GameState.in_battle = false
			GameState.add_resources(1, 0, 0, 10)
			_console("[reward] +1 fuel, +10 scrap")

func _console(text: String) -> void:
	print(text)