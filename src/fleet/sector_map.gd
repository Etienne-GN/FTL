class_name SectorMap
extends RefCounted
## Generates and simulates the sector map: a grid of beacon nodes with
## connections, a player position, and the rebel fleet that advances each jump.

const COLS := 7
const ROWS := 3

var sector := 1
var beacons: Array = []          # Dictionary: id, col, row, type, conns
var beacon_map := {}             # id -> beacon
var player_id := ""
var fleet_col := -2              # fleet column position (float floor)
var visited := {}                # id -> true
var _id_counter := 0
var jump_range := 1              # max columns the player may jump per move

func generate(sector_num: int) -> void:
	sector = sector_num
	beacons.clear()
	beacon_map.clear()
	visited.clear()
	_id_counter = 0
	# create nodes
	for col in range(COLS):
		for row in range(ROWS):
			var type := _beacon_type(col, row)
			var b := {
				"id": "b%d" % _id_counter,
				"col": col,
				"row": row,
				"type": type,
				"hazard": _beacon_hazard(col, row, type),
				"conns": [],
			}
			_id_counter += 1
			beacons.append(b)
			beacon_map[b.id] = b
	# connect adjacent columns
	for col in range(COLS - 1):
		for row in range(ROWS):
			var cur := _at(col, row)
			var targets: Array = []
			for dr in range(-1, 2):
				var nr := row + dr
				if nr >= 0 and nr < ROWS:
					targets.append(_at(col + 1, nr))
			# connect to 1-2 of them
			for t in targets:
				if randf() < 0.7:
					_connect(cur, t)
			# guarantee at least one forward connection
			var has_fwd := false
			for c in cur.conns:
				if beacon_map[c].col > cur.col:
					has_fwd = true
					break
			if not has_fwd:
				_connect(cur, targets[randi() % targets.size()])
	# start: leftmost middle beacon is the player start
	var start := _at(0, 1)
	start.type = "start"
	player_id = start.id
	visited[player_id] = true
	fleet_col = -2

func _beacon_type(col: int, row: int) -> String:
	if col == COLS - 1:
		return "exit"
	if col == 0:
		return "empty"
	var roll := randf()
	if roll < 0.30:
		return "empty"
	if roll < 0.55:
		return "event"
	if roll < 0.70:
		return "store"
	return "battle"

func _beacon_hazard(col: int, row: int, type: String) -> String:
	if col == 0 or type == "exit":
		return ""
	if randf() > 0.35:
		return ""
	var pool := ["nebula", "nebula", "asteroid", "sun", "ion"]
	return pool[randi() % pool.size()]

func _at(col: int, row: int) -> Dictionary:
	return beacons[col * ROWS + row]

func _connect(a: Dictionary, b: Dictionary) -> void:
	if not a.conns.has(b.id):
		a.conns.append(b.id)
	if not b.conns.has(a.id):
		b.conns.append(a.id)

func current() -> Dictionary:
	return beacon_map[player_id]

func reachable() -> Array:
	var out: Array = []
	var cur := current()
	var max_col: int = cur.col + jump_range
	for cid in cur.conns:
		var b: Dictionary = beacon_map[cid]
		if b.col > cur.col and b.col <= max_col and not visited.has(b.id):
			out.append(b.id)
	return out

func can_jump() -> bool:
	return not reachable().is_empty()

func jump_to(beacon_id: String) -> bool:
	if not beacon_map.has(beacon_id):
		return false
	if not reachable().has(beacon_id):
		return false
	# you cannot jump into a beacon the rebel fleet already occupies
	if beacon_map[beacon_id].col <= fleet_col:
		return false
	player_id = beacon_id
	visited[player_id] = true
	fleet_col += 1
	return true

func jump_distance_to(beacon_id: String) -> int:
	if not beacon_map.has(beacon_id):
		return 0
	return beacon_map[beacon_id].col - current().col

func repel_fleet(columns: int) -> void:
	fleet_col = maxi(-2, fleet_col - columns)

func at_exit() -> bool:
	return current().type == "exit"

func fleet_positions() -> Array:
	# rebel ships at fleet_col
	var out: Array = []
	if fleet_col < 0:
		return out
	for b in beacons:
		if b.col == fleet_col:
			out.append(b.id)
	return out

func caught() -> bool:
	var cur := current()
	return fleet_col >= cur.col

func progress() -> float:
	return float(current().col) / float(COLS - 1)

func to_dict() -> Dictionary:
	var visited_ids: Array = []
	for id in visited:
		visited_ids.append(id)
	return {
		"sector": sector,
		"beacons": beacons,
		"player_id": player_id,
		"fleet_col": fleet_col,
		"visited": visited_ids,
		"jump_range": jump_range,
	}

static func from_dict(data: Dictionary) -> SectorMap:
	var m := SectorMap.new()
	m.sector = int(data.get("sector", 1))
	m.beacons = data.get("beacons", [])
	m.player_id = str(data.get("player_id", ""))
	m.fleet_col = int(data.get("fleet_col", -2))
	m.visited = {}
	for id in data.get("visited", []):
		m.visited[id] = true
	m.beacon_map.clear()
	for b in m.beacons:
		m.beacon_map[b.id] = b
	m.jump_range = int(data.get("jump_range", 1))
	return m