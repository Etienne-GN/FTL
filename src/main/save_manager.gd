extends Node
## SaveManager: persist/load a full run snapshot (ship + sector map + resources)
## so you can quit and resume anytime on Android.

const SAVE_PATH := "user://run.save"
const META_PATH := "user://meta.save"

func save_run() -> void:
	if GameState.player_ship == null or not GameState.run_active:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(GameState.snapshot()))
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
	GameState.restore(data)
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)