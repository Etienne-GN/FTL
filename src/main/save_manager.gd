extends Node
## SaveManager: persist/load a run snapshot so you can quit and resume on Android.

const SAVE_PATH := "user://run.save"
const META_PATH := "user://meta.save"

func save_run() -> void:
	if GameState.player_ship == null or not GameState.run_active:
		return
	var data := _snapshot()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func save_meta() -> void:
	var unlocked := ["kestrel"]
	if GameState.victory_flag:
		unlocked = ["kestrel", "engi_a"]
	var meta := {"unlocked": unlocked}
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta))
		file.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func meta_exists() -> bool:
	return FileAccess.file_exists(META_PATH)

func load_meta() -> Array:
	if not meta_exists():
		return ["kestrel"]
	var data := JSONHelpers.load_json(META_PATH)
	return data.get("unlocked", ["kestrel"])

func load_run() -> bool:
	if not has_save():
		return false
	var data := JSONHelpers.load_json(SAVE_PATH)
	if data.is_empty():
		return false
	# Rebuild player ship and current sector/enemy snapshot
	GameState.new_run(data.get("ship_id", "kestrel"))
	GameState.sector = int(data.get("sector", 1))
	GameState.in_battle = bool(data.get("in_battle", false))
	if GameState.in_battle:
		GameState.spawn_enemy(int(data.get("enemy_rank", 0)))
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _snapshot() -> Dictionary:
	return {
		"ship_id": GameState.player_ship.ship_id,
		"sector": GameState.sector,
		"in_battle": GameState.in_battle,
		"enemy_rank": _enemy_rank(GameState.enemy_ship),
	}

func _enemy_rank(ship) -> int:
	if ship == null:
		return 0
	var id_str: String = ship.ship_id
	if id_str.begins_with("enemy_"):
		return id_str.trim_prefix("enemy_").to_int()
	return 0