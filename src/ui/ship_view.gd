class_name ShipView
extends Node2D
## Renders a Ship model as 2D rooms with system colors, shields, hull,
## fires, breaches, and crew. Also handles tap position -> room lookup.

const SYSTEM_COLORS := {
	"shields": Color(0.15, 0.5, 1.0),
	"engines": Color(0.2, 0.85, 0.45),
	"weapons": Color(1.0, 0.3, 0.3),
	"drones": Color(0.7, 0.4, 1.0),
	"oxygen": Color(0.4, 0.9, 1.0),
	"medbay": Color(0.9, 0.9, 1.0),
	"teleporter": Color(1.0, 0.6, 0.2),
	"doors": Color(0.6, 0.6, 0.65),
	"piloting": Color(1.0, 0.9, 0.3),
	"cloak": Color(0.5, 0.8, 0.8),
	"battery": Color(0.9, 0.8, 0.4),
}
const BACKGROUND := Color(0.03, 0.05, 0.1, 0.9)
const WALL := Color(0.25, 0.3, 0.4)
const FIRE := Color(1.0, 0.5, 0.1)
const BREACH := Color(0.1, 0.2, 0.4)

var ship: Ship
var flipped := true                 # enemy ship drawn mirrored (rooms reversed)
var tile := Ship.TILE
var hull_texture: Texture2D = null
var sprite_atlas: AtlasTexture = null

func setup(s: Ship, is_enemy: bool = false) -> void:
	ship = s
	flipped = is_enemy
	var filename := ""
	match ship.ship_id:
		"kestrel", "kestrel_b":
			filename = "PC _ Computer - FTL_ Faster Than Light - Playable Ships - Kestrel Cruiser.png"
		"engi_a", "engi_b":
			filename = "PC _ Computer - FTL_ Faster Than Light - Playable Ships - Engi Cruiser.png"
		"mantis_raider":
			filename = "PC _ Computer - FTL_ Faster Than Light - Playable Ships - Mantis Cruiser.png"
		_:
			filename = "PC _ Computer - FTL_ Faster Than Light - Playable Ships - Kestrel Cruiser.png"
	var path := "res://assets/sprites/ships/%s" % filename
	if ResourceLoader.exists(path):
		hull_texture = load(path)
		if hull_texture != null:
			sprite_atlas = AtlasTexture.new()
			sprite_atlas.atlas = hull_texture
			# The first ship sprite variant on FTL sheets is typically top-left (~180x110 area)
			sprite_atlas.region = Rect2(0, 0, minf(hull_texture.get_width(), 320), minf(hull_texture.get_height(), 180))

func _draw() -> void:
	if ship == null:
		return
	if sprite_atlas != null:
		var dest_rect := Rect2(Vector2(-20, -20), Vector2(ship.grid.x * tile + 40, ship.grid.y * tile + 40))
		draw_texture_rect(sprite_atlas, dest_rect, false)
	for room_id in ship.room_order:
		_draw_room(room_id)
	_draw_crew()
	_draw_hull_bar()

func room_rect_px(room_id: String) -> Rect2:
	var rect: Rect2i = ship.rooms[room_id].rect
	var px := Rect2(Vector2(rect.position) * tile, Vector2(rect.size) * tile)
	if flipped:
		px.position.x = (ship.grid.x - rect.position.x - rect.size.x) * tile
	return px

func _draw_room(room_id: String) -> void:
	var room: Dictionary = ship.rooms[room_id]
	var px := room_rect_px(room_id)
	var sys_id: String = room.system
	var col: Color = SYSTEM_COLORS.get(sys_id, Color(0.13, 0.15, 0.2))
	var sys: SystemState = ship.systems.get(sys_id)
	var powered := sys != null and sys.active() and not sys.is_destroyed()
	var draw_col: Color = col if powered else col * 0.35
	draw_rect(px, draw_col.lerp(BACKGROUND, 0.15), true)
	# system damage overlay
	if sys != null and sys.is_destroyed():
		draw_rect(px, Color(0.4, 0.1, 0.1, 0.6), true)
	# ion
	if sys != null and sys.ion > 0:
		draw_rect(px, Color(0.6, 0.9, 1.0, 0.4), true)
	draw_rect(px, WALL, false, 2.0)
	# label
	var label: String = ship.systems.get(sys_id).name if sys != null else ""
	if label != "":
		draw_string(ThemeDB.fallback_font, px.position + Vector2(6, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	# fire
	if room.fire > 0.0:
		draw_rect(px.grow(-3), FIRE, true)
		draw_circle(px.get_center(), 6.0, FIRE.lightened(0.3))
	# breach
	if room.breach:
		draw_circle(px.get_center(), 8.0, BREACH)
	# oxygen low
	if room.oxygen < 0.3:
		draw_rect(px.grow(-6), Color(0.1, 0.4, 0.5, 0.5), true)

func _crew_px(pos: Vector2) -> Vector2:
	var x: float = pos.x * tile if not flipped else (ship.grid.x - pos.x) * tile
	return Vector2(x, pos.y * tile)

func _draw_crew() -> void:
	for cm in ship.crew:
		if not cm.alive():
			continue
		var center := _crew_px(cm.pos)
		draw_circle(center, 7.0, _crew_color(cm))
		draw_circle(center, 7.0, Color.WHITE, false, 1.5)
	for br in ship.boarders:
		if not br.alive():
			continue
		var center := _crew_px(br.pos)
		draw_circle(center, 7.0, Color(0.9, 0.2, 0.2))
		draw_circle(center, 7.0, Color.WHITE, false, 1.5)

func _crew_color(cm: CrewMember) -> Color:
	match cm.race:
		"engi": return Color(0.5, 0.9, 1.0)
		"mantis": return Color(0.3, 0.9, 0.3)
		"rock": return Color(0.8, 0.4, 0.2)
		"zoltan": return Color(1.0, 0.9, 0.2)
	return Color(0.9, 0.6, 0.4)

func _draw_hull_bar() -> void:
	var w: float = ship.grid.x * tile
	var y: float = -(tile + 10) if flipped else ship.grid.y * tile + 10
	var rect := Rect2(0, y, w, 8)
	draw_rect(rect, Color(0.2, 0.2, 0.25), true)
	var ratio := ship.hull_ratio()
	var col := Color(0.2, 1.0, 0.3) if ratio > 0.5 else (Color(1.0, 0.8, 0.2) if ratio > 0.25 else Color(1.0, 0.2, 0.2))
	draw_rect(Rect2(rect.position, Vector2(w * ratio, 8)), col, true)

func world_to_room(world_pos: Vector2) -> String:
	for room_id in ship.room_order:
		if room_rect_px(room_id).has_point(world_pos):
			return room_id
	return ""

func total_size() -> Vector2:
	return Vector2(ship.grid.x * tile, ship.grid.y * tile)