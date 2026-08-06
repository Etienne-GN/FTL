class_name MapView
extends Control
## Renders the sector map as a grid of beacon nodes with connection lines,
## the player marker, and the rebel-fleet advance zone. Emits clicked(id)
## for reachable beacons.

signal clicked(beacon_id: String)

var map: SectorMap
var spacing := Vector2(170, 120)
var origin := Vector2(70, 150)
var r := 18.0
var beacon_buttons := {}
var _tex_cache := {}
var _decor := []                 # [{texture, pos, size, color}]
var _theme_id := ""

const BG_DIR := "res://assets/sprites/backgrounds/extracted/"
const PLANET_DIR := "res://assets/sprites/planets/extracted/"
const AST_DIR := "res://assets/sprites/asteroids/extracted/"
const NEBULA := "res://assets/sprites/nebula/extracted/nebula_full.png"

func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img := Image.new()
	if img.load(path) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

func setup(m: SectorMap) -> void:
	map = m
	_theme_id = str(GameState.sector_theme.get("id", ""))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_decorations()
	_build_buttons()
	queue_redraw()

func _build_decorations() -> void:
	_decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.sector) * 7919 + 13
	var planets := []
	var pfiles := ["s01_164639.png", "s02_164639.png", "s03_164639.png", "s04_164639.png",
		"s05_164639.png", "s06_112219.png", "s07_112219.png", "s08_53833.png", "s09_28691.png"]
	for fn in pfiles:
		var t := _load_tex(PLANET_DIR + fn)
		if t != null:
			planets.append(t)
	# scenic planet slots (avoid top-left header region)
	var slots := [
		Vector2(1120, 90), Vector2(1160, 430), Vector2(1120, 600),
		Vector2(640, 685), Vector2(80, 620), Vector2(80, 360), Vector2(950, 105),
	]
	for slot in slots:
		var tex: Texture2D = planets[rng.randi_range(0, planets.size() - 1)]
		var w: float = tex.get_width()
		var h: float = tex.get_height()
		var scale := rng.randf_range(0.16, 0.34)
		var p: Vector2 = slot + Vector2(rng.randf_range(-26, 26), rng.randf_range(-20, 20))
		_decor.append({
			"texture": tex, "pos": p - Vector2(w, h) * scale * 0.5,
			"size": Vector2(w, h) * scale,
			"color": Color(1, 1, 1, 0.9),
		})
	# asteroids scattered in the margins
	var a_files := ["s00_9265.png", "s01_4684.png", "s02_2446.png", "s03_2446.png",
		"s04_2371.png", "s05_2370.png", "s06_2300.png", "s07_2216.png"]
	var asteroids := []
	for fn in a_files:
		var t := _load_tex(AST_DIR + fn)
		if t != null:
			asteroids.append(t)
	for i in 14:
		var tex: Texture2D = asteroids[rng.randi_range(0, asteroids.size() - 1)]
		var w := float(tex.get_width())
		var s := rng.randf_range(0.5, 0.9)
		var p := Vector2(rng.randf_range(30, 1250), rng.randf_range(30, 690))
		if p.x < 300 and p.y < 160:
			p.y += 150
		_decor.append({
			"texture": tex, "pos": p,
			"size": Vector2(w, w) * s,
			"color": Color(1, 1, 1, rng.randf_range(0.55, 0.85)),
		})
	# nebula backdrop for nebula themes
	if _theme_id == "nebula":
		var neb := _load_tex(NEBULA)
		if neb != null:
			var nw := float(neb.get_width())
			var nh := float(neb.get_height())
			var ns := 0.3
			_decor.append({
				"texture": neb, "pos": Vector2(560, 60),
				"size": Vector2(nw, nh) * ns,
				"color": Color(1, 1, 1, 0.92),
			})

func _theme_bg() -> String:
	match _theme_id:
		"civilian": return "bg_lonelystar.png"
		"nebula": return "bg_darknebula.png"
		"pirate": return "bg_lonelyRedStar.png"
		"rock": return "bg_lonelyRedStar.png"
		"rebel": return "bg_lonelyRedStar.png"
		"engi": return "bg_blueStarcluster.png"
		"federation": return "bg_dullstars2.png"
		"mantis": return "bg_lonelystar.png"
		_: return "bg_dullstars.png"

func _build_buttons() -> void:
	for child in get_children():
		child.queue_free()
	beacon_buttons.clear()
	if map == null:
		return
	for b in map.beacons:
		var btn := Button.new()
		btn.text = ""
		btn.flat = true
		btn.custom_minimum_size = Vector2(r * 2.5, r * 2.5)
		btn.position = beacon_px(b) - Vector2(r * 1.25, r * 1.25)
		var bid: String = b.id
		btn.pressed.connect(func(): _on_beacon_pressed(bid))
		add_child(btn)
		beacon_buttons[bid] = btn
	_update_button_states()

func _update_button_states() -> void:
	if map == null:
		return
	var reach := map.reachable()
	for bid in beacon_buttons:
		var btn: Button = beacon_buttons[bid]
		btn.disabled = not reach.has(bid)

func _on_beacon_pressed(beacon_id: String) -> void:
	clicked.emit(beacon_id)

func beacon_px(b: Dictionary) -> Vector2:
	return origin + Vector2(b.col, b.row) * spacing

func _draw() -> void:
	if map == null:
		return
	# sector space background
	var bg := _load_tex(BG_DIR + _theme_bg())
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
	# decorative planets / asteroids / nebula
	for d in _decor:
		if d["texture"] != null:
			draw_texture_rect(d["texture"], Rect2(d["pos"], d["size"]), false, d["color"])
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