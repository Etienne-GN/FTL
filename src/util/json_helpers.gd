class_name JSONHelpers
extends RefCounted
## Static helpers for loading JSON files and helper lookups.

static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("load_json: cannot open %s (%s)" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary or parsed is Array:
		return parsed
	push_warning("load_json: parse failed for %s" % path)
	return {}

static func lvl(arr, level: int, default = 0):
	## Index into a per-level stat array, clamped.
	if arr == null or arr.is_empty():
		return default
	return arr[clamp(level, 0, arr.size() - 1)]