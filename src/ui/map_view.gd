class_name MapView
extends Control
## Renders the sector map as a grid of beacon nodes with connection lines,
## the player marker, and the rebel-fleet advance zone. Emits clicked(id)
## for reachable beacons.

signal clicked(beacon_id: String)

var map: SectorMap
var spacing := Vector2(170, 120)
var origin := Vector2(70, 150)
var r := 16.0

func setup(m: SectorMap) -> void:
	map = m
	queue_redraw()

func beacon_px(b: Dictionary) -> Vector2:
	return origin + Vector2(b.col, b.row) * spacing

func _draw() -> void:
	if map == null:
		return
	# rebel fleet zone (red)
	var fleet := map.fleet_col
	if fleet >= 0:
		var zone_x: float = origin.x - spacing.x + (fleet + 1) * spacing.x
		draw_rect(Rect2(0, 0, zone_x, size.y), Color(0.4, 0.0, 0.05, 0.28), true)
		draw_string(ThemeDB.fallback_font, Vector2(8, origin.y - 30), "REBEL FLEET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.4, 0.4))
	# connection lines
	for b in map.beacons:
		for cid in b.conns:
			if map.beacon_map.has(cid):
				var other: Dictionary = map.beacon_map[cid]
				if other.col > b.col:
					draw_line(beacon_px(b), beacon_px(other), Color(0.3, 0.35, 0.5, 0.8), 2.0)
	# beacons
	for b in map.beacons:
		var px := beacon_px(b)
		var col: Color = _type_color(b.type)
		draw_circle(px, r, col)
		# visited marker
		if map.visited.has(b.id):
			draw_arc(px, r + 3, 0, TAU, 24, Color.WHITE, 1.5)
		# reachable highlight
		if map.reachable().has(b.id):
			draw_arc(px, r + 6, 0, TAU, 24, Color(0.5, 1.0, 0.6), 2.0)
	# player marker
	var cur := map.current()
	draw_circle(beacon_px(cur), r + 10, Color(0, 1, 1), false, 3.0)
	draw_string(ThemeDB.fallback_font, beacon_px(cur) + Vector2(-12, r + 30), "YOU", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.CYAN)

func _type_color(t: String) -> Color:
	match t:
		"event": return Color(0.9, 0.8, 0.3)
		"store": return Color(0.3, 0.9, 0.9)
		"battle": return Color(0.9, 0.3, 0.3)
		"exit": return Color(1.0, 1.0, 1.0)
		"start": return Color(0.4, 1.0, 0.4)
	return Color(0.5, 0.5, 0.6)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	var reach := map.reachable()
	for b in map.beacons:
		if reach.has(b.id) and beacon_px(b).distance_to(pos) <= r + 8:
			clicked.emit(b.id)
			return