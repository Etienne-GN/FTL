class_name CombatScreen
extends Node2D
## Reusable combat screen: builds the two-ship battle view + HUD, drives the
## CombatManager, and emits battle_ended(winner) when the fight is over.

signal battle_ended(winner: Ship)
signal quit_to_menu

var player: Ship
var enemy: Ship
var sector_num: int = 1

var combat: CombatManager = null
var player_view: ShipView
var enemy_view: ShipView
var selected_weapon: WeaponState = null
var targeting_enemy := false
var selected_crew: CrewMember = null
var crew_buttons: Dictionary = {}
var _ended := false
var targeting_hack := false
var targeting_mc := false

var hud: Control
var top_bar: PanelContainer
var bottom_bar: PanelContainer
var resource_values := {}       # kind -> Label
var resource_icons := {}        # kind -> ResIcon
var reactor_pips := []          # array of ColorRect
var reactor_label: Label
var log_label: Label
var pause_button: Button
var battery_button: Button
var doors_button: Button
var cloak_button: Button
var power_boxes := {}           # system_id -> Label
var power_cols := {}           # system_id -> Control (column, for damage tint)
var weapon_buttons := []       # array of {name, bar, tgt, auto, weapon}
var enemy_info_label: Label
var jump_label: Label

var star_points := []
var background_texture: Texture2D

# Rectangles to sanity-check for screen overlap (global pixel rects).
var layout_rects := {}                 # name -> Rect2

func _rect_noise() -> void:
	layout_rects = {}
	layout_rects["player_ship"] = _ship_global_rect(player_view)
	layout_rects["enemy_ship"] = _ship_global_rect(enemy_view)
	if top_bar != null:
		layout_rects["top_bar"] = top_bar.get_global_rect()
	if bottom_bar != null:
		layout_rects["bottom_bar"] = bottom_bar.get_global_rect()
	if log_label != null:
		layout_rects["log"] = log_label.get_global_rect()
	if jump_label != null:
		layout_rects["jump"] = jump_label.get_global_rect()
	for child in hud.get_children():
		if child == top_bar or child == bottom_bar or child == jump_label or child == log_label:
			continue
		if child is PanelContainer:
			var name: String = "panel"
			if child.get_child_count() > 0 and child.get_child(0).get_child_count() > 0:
				name = child.get_child(0).get_child(0).text
			layout_rects[name] = child.get_global_rect()
		elif child is Button:
			layout_rects["btn_" + str(child.text)] = child.get_global_rect()

func _ship_global_rect(v: ShipView) -> Rect2:
	var size := v.total_size() * v.scale
	return Rect2(v.global_position, size)

func _check_layout() -> Array:
	_rect_noise()
	var problems: Array = []
	var names := layout_rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = layout_rects[names[i]]
			var b: Rect2 = layout_rects[names[j]]
			if a.size.x > 0 and b.size.x > 0 and a.intersects(b):
				problems.append("%s <-> %s overlap" % [names[i], names[j]])
	return problems

func start_battle(p: Ship, e: Ship, sector: int) -> void:
	player = p
	enemy = e
	sector_num = sector
	GameState.paused = false
	_ended = false
	player.doors_locked = false
	player.cloak_active = false
	player.hack_target_sys = ""
	player.hack_duration_left = 0.0
	player.mc_crew = null
	_build_background()
	combat = CombatManager.new(player, enemy, GameState.pending_encounter.get("hazard", ""))
	GameState.in_battle = true
	_build_starfield()
	_build_ships()
	_build_hud()
	_setup_signals()
	_refresh_ui()
	if combat.hazard != "":
		_log("Hazard: %s zone." % combat.hazard)
	queue_redraw()
	_check_layout()

# ---------- scene construction ----------

const BG_DIR := "res://assets/sprites/backgrounds/extracted/"

func _build_background() -> void:
	var hazard: String = str(GameState.pending_encounter.get("hazard", ""))
	var bg_file := _hazard_bg(hazard)
	if bg_file.is_empty():
		bg_file = _theme_bg(str(GameState.sector_theme.get("id", "")))
	background_texture = _load_bg(bg_file)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _load_bg(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var img := Image.new()
	if img.load(BG_DIR + path) != OK:
		push_warning("Missing background: " + path)
		return null
	return ImageTexture.create_from_image(img)

func _theme_bg(theme_id: String) -> String:
	match theme_id:
		"civilian": return "bg_lonelystar.png"
		"nebula": return "bg_darknebula.png"
		"pirate": return "bg_lonelyRedStar.png"
		"engi": return "bg_blueStarcluster.png"
		"mantis": return "bg_lonelystar.png"
		"rock": return "bg_lonelyRedStar.png"
		"federation": return "bg_dullstars2.png"
		"rebel": return "bg_lonelyRedStar.png"
		_: return "bg_dullstars.png"

func _hazard_bg(hazard: String) -> String:
	match hazard:
		"asteroids": return "low_asteroid.png"
		"nebula": return "low_nebula.png"
		"ion": return "low_pulsar.png"
		"sun": return "low_sun.png"
		"storm": return "low_storm.png"
		_: return ""

func _build_ships() -> void:
	const SCALE := 0.5
	player_view = ShipView.new()
	player_view.setup(player, false)
	player_view.scale = Vector2(SCALE, SCALE)
	add_child(player_view)
	player_view.position = Vector2(230, 340)
	enemy_view = ShipView.new()
	enemy_view.setup(enemy, true)
	enemy_view.scale = Vector2(SCALE, SCALE)
	add_child(enemy_view)
	var es: Vector2 = enemy_view.total_size() * SCALE
	enemy_view.position = Vector2(VP().x - es.x - 144, 100)

func _build_starfield() -> void:
	for i in 300:
		star_points.append(Vector2(randf() * 1280, randf() * 720))

func _draw() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
	for p in star_points:
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, randf() * 0.5 + 0.2))

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.size = Vector2(VP().x, VP().y)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	_build_top_bar()
	_build_flow_buttons()
	_build_bottom_bar()

	var rail_y := _build_crew_panel()
	rail_y = _build_teleporter_panel(rail_y)
	rail_y = _build_advanced_panel(rail_y)
	_build_enemy_info()

	log_label = Label.new()
	log_label.position = Vector2(240, 52)
	log_label.custom_minimum_size = Vector2(320, 150)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(log_label)

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.position = Vector2(6, 4)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(hbox)
	resource_values = {}
	resource_icons = {}
	for kind in ["sector", "hull", "shields", "fuel", "missiles", "drones", "scrap"]:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 3)
		var icon := ResIcon.new(kind)
		icon.custom_minimum_size = Vector2(18, 14)
		entry.add_child(icon)
		resource_icons[kind] = icon
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		entry.add_child(lbl)
		resource_values[kind] = lbl
		hbox.add_child(entry)
	hud.add_child(top_bar)

	jump_label = Label.new()
	jump_label.position = Vector2(470, 2)
	jump_label.custom_minimum_size = Vector2(320, 32)
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_label.add_theme_font_size_override("font_size", 15)
	jump_label.modulate = Color(0.6, 0.9, 1.0)
	hud.add_child(jump_label)

func _build_flow_buttons() -> void:
	pause_button = _mk_btn("Pause", Vector2(VP().x - 110, 6), _toggle_pause)
	var flee_btn := _mk_btn("Flee", Vector2(VP().x - 110, 48), _flee)
	var quit_btn := _mk_btn("Menu", Vector2(VP().x - 110, 90), _quit_to_menu)

func _build_bottom_bar() -> void:
	bottom_bar = PanelContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -154.0
	hud.add_child(bottom_bar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	bottom_bar.add_child(hbox)
	hbox.add_child(_build_reactor_panel())
	var modules := HBoxContainer.new()
	modules.add_theme_constant_override("separation", 4)
	modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ordered := ["shields", "engines", "weapons", "drones", "oxygen", "doors",
		"medbay", "piloting", "teleporter", "cloak", "hacking", "mind_control"]
	for sid in ordered:
		if player.systems.has(sid):
			modules.add_child(_make_system_col(sid))
	hbox.add_child(modules)
	hbox.add_child(_build_weapons_panel())

func _build_reactor_panel() -> Control:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "REACTOR"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	reactor_pips = []
	for i in 16:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(10, 10)
		pips.add_child(r)
		reactor_pips.append(r)
	vbox.add_child(pips)
	reactor_label = Label.new()
	reactor_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(reactor_label)
	if player.systems.has("doors"):
		doors_button = _mk_small_btn("Lock Doors", _toggle_doors)
		vbox.add_child(doors_button)
	if player.systems.has("cloak"):
		cloak_button = _mk_small_btn("Cloak", _toggle_cloak)
		vbox.add_child(cloak_button)
	if player.battery_capacity > 0:
		battery_button = _mk_small_btn("Battery", _toggle_battery)
		vbox.add_child(battery_button)
	return panel

func _mk_btn(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(100, 36)
	b.pressed.connect(cb)
	hud.add_child(b)
	return b

func _mk_small_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 28)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b

func _build_enemy_info() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(800, 30)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	enemy_info_label = Label.new()
	enemy_info_label.add_theme_font_size_override("font_size", 13)
	enemy_info_label.custom_minimum_size = Vector2(336, 26)
	vbox.add_child(enemy_info_label)
	hud.add_child(panel)

func _build_weapons_panel() -> Control:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "WEAPONS"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	weapon_buttons.clear()
	for w in player.weapons:
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(158, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		card.add_child(name_lbl)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(64, 12)
		bar.max_value = 1.0
		bar.show_percentage = false
		card.add_child(bar)
		var tgt := Button.new()
		tgt.text = "Tgt"
		tgt.custom_minimum_size = Vector2(40, 26)
		var captured: WeaponState = w
		tgt.pressed.connect(_select_weapon.bind(captured))
		card.add_child(tgt)
		var auto := Button.new()
		auto.text = "AU"
		auto.custom_minimum_size = Vector2(34, 26)
		auto.add_theme_font_size_override("font_size", 10)
		auto.pressed.connect(_toggle_autofire.bind(captured, auto))
		card.add_child(auto)
		vbox.add_child(card)
		weapon_buttons.append({"name": name_lbl, "bar": bar, "tgt": tgt, "auto": auto, "weapon": w})
	return panel

func _toggle_autofire(w: WeaponState, btn: Button) -> void:
	w.autofire = not w.autofire
	btn.text = "AU" if w.autofire else "MAN"
	btn.modulate = Color.WHITE if w.autofire else Color(0.6, 0.6, 0.6)
	_log("Autofire on." if w.autofire else "Manual fire. Lock target, then press Tgt to fire.")

func _build_crew_panel() -> int:
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 44)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "CREW (%d)" % player.crew.size()
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(206, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	vbox.add_child(scroll)
	crew_buttons = {}
	for cm in player.crew:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 32)
		btn.text = "%s (%s)  HP %d" % [cm.name, cm.race, int(ceil(cm.hp))]
		btn.tooltip_text = _crew_skill_text(cm)
		var captured: CrewMember = cm
		btn.pressed.connect(_select_crew.bind(captured))
		list.add_child(btn)
		crew_buttons[cm] = btn
	hud.add_child(panel)
	return 44 + int(panel.get_minimum_size().y) + 12

func _crew_skill_text(cm: CrewMember) -> String:
	var parts: Array = []
	for sk in cm.skills.keys():
		var lv := cm.stat(sk)
		if lv > 0:
			parts.append("%s %s" % [sk.capitalize(), _roman(lv)])
	for sk in cm.xp.keys():
		if not parts.any(func(p): return str(p).begins_with(sk.capitalize() + " ")):
			var lv := cm.stat(sk)
			if lv > 0:
				parts.append("%s %s" % [sk.capitalize(), _roman(lv)])
	return "Skills:\n" + ("\n".join(parts) if not parts.is_empty() else "None")

func _roman(lv: int) -> String:
	return "I" if lv <= 1 else "II"

func _build_teleporter_panel(y: int) -> int:
	if player.systems.has("teleporter"):
		var panel := PanelContainer.new()
		panel.position = Vector2(6, y)
		var vbox := VBoxContainer.new()
		panel.add_child(vbox)
		var title := Label.new()
		title.text = "TELEPORTER"
		title.add_theme_font_size_override("font_size", 13)
		vbox.add_child(title)
		var send := Button.new()
		send.text = "Send crew (enemy)"
		send.custom_minimum_size = Vector2(200, 32)
		send.pressed.connect(_teleport_send)
		vbox.add_child(send)
		var recall := Button.new()
		recall.text = "Recall boarders"
		recall.custom_minimum_size = Vector2(200, 32)
		recall.pressed.connect(_teleport_recall)
		vbox.add_child(recall)
		hud.add_child(panel)
		return y + int(panel.get_minimum_size().y) + 10
	return y

var hack_button: Button
var mc_button: Button

func _build_advanced_panel(y: int) -> int:
	hack_button = null
	mc_button = null
	if player.systems.has("hacking"):
		hack_button = Button.new()
		hack_button.text = "Hack (enemy system)"
		hack_button.custom_minimum_size = Vector2(200, 32)
		hack_button.pressed.connect(_select_hack)
		var p := PanelContainer.new()
		p.position = Vector2(6, y)
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(hack_button)
		hud.add_child(p)
		y += int(p.get_minimum_size().y) + 10
	if player.systems.has("mind_control"):
		mc_button = Button.new()
		mc_button.text = "Mind Control (crew)"
		mc_button.custom_minimum_size = Vector2(200, 32)
		mc_button.pressed.connect(_select_mc)
		var p2 := PanelContainer.new()
		p2.position = Vector2(6, y)
		var v2 := VBoxContainer.new()
		p2.add_child(v2)
		v2.add_child(mc_button)
		hud.add_child(p2)
		y += int(p2.get_minimum_size().y) + 10
	return y

func _select_hack() -> void:
	targeting_hack = true
	targeting_mc = false
	if hack_button != null:
		hack_button.modulate = Color(1, 1, 0.4)
	_log("Select an enemy system room to hack.")

func _select_mc() -> void:
	targeting_mc = true
	targeting_hack = false
	if mc_button != null:
		mc_button.modulate = Color(1, 1, 0.4)
	_log("Select an enemy crew member to control.")

func _refresh_advanced() -> void:
	if hack_button != null:
		if player.hack_target_sys != "":
			hack_button.text = "Hacking (%ds)" % int(ceil(player.hack_duration_left))
		elif player.hack_ready():
			hack_button.text = "Hack (enemy system)"
		else:
			hack_button.text = "Hack (%.0f%%)" % (player.hack_charge * 100)
	if mc_button != null:
		if player.mc_crew != null:
			mc_button.text = "Controlling (%ds)" % int(ceil(player.mc_crew.mc_timer))
		elif player.mc_ready():
			mc_button.text = "Mind Control (crew)"
		else:
			mc_button.text = "Mind Ctl (%.0f%%)" % (player.mc_charge * 100)

func _select_crew(cm: CrewMember) -> void:
	selected_crew = cm
	_log("Selected %s. Tap a room on your ship to move them." % cm.name)

func _teleport_send() -> void:
	if player.teleport_crew_to(enemy, enemy.random_room_id()):
		_log("Crew beamed to enemy ship!")
	else:
		_log("Teleporter not ready, unpowered, or no crew in teleporter room.")

func _teleport_recall() -> void:
	player.recall_boarding(enemy)
	_log("Boarders recalled.")

func _make_system_col(sid: String) -> Control:
	var sys: SystemState = player.systems[sid]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.tooltip_text = Content.get_system(sid).get("name", sid)
	var name_lbl := Label.new()
	name_lbl.text = Content.get_system(sid).get("name", sid)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.custom_minimum_size = Vector2(62, 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	var pwr_label := Label.new()
	pwr_label.text = "%d/%d" % [sys.power, sys.level]
	pwr_label.add_theme_font_size_override("font_size", 12)
	pwr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pwr_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(18, 18)
	minus.add_theme_font_size_override("font_size", 10)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(18, 18)
	plus.add_theme_font_size_override("font_size", 10)
	minus.pressed.connect(_adj_power.bind(sid, -1))
	plus.pressed.connect(_adj_power.bind(sid, 1))
	row.add_child(minus)
	row.add_child(plus)
	col.add_child(row)
	power_boxes[sid] = pwr_label
	power_cols[sid] = col
	return col

func _adj_power(sid: String, delta: int) -> void:
	var ok := player.allocate_power(sid, player.systems[sid].power + delta)
	if not ok:
		_log("Not enough reactor power.")
	_refresh_ui()

class ResIcon:
	extends Control
	## Tiny placeholder icon drawn for a resource kind (hull, fuel, ...).

	var kind := "hull"

	func _init(k: String):
		kind = k

	func _draw() -> void:
		var c := size / 2.0
		match kind:
			"sector":
				var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(2, -2), c + Vector2(6, 0),
					c + Vector2(2, 2), c + Vector2(0, 6), c + Vector2(-2, 2), c + Vector2(-6, 0), c + Vector2(-2, -2)])
				draw_colored_polygon(pts, Color(1.0, 0.85, 0.3))
			"hull":
				draw_rect(Rect2(2, 4, size.x - 4, 5), Color(0.2, 0.2, 0.25), true)
				draw_rect(Rect2(2, 4, size.x - 4, 5), Color(0.2, 1.0, 0.3), false, 1.0)
			"shields":
				draw_arc(c + Vector2(0, 4), 8.0, PI, TAU, 24, Color(0.4, 0.8, 1.0), 2.0)
			"fuel":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 2),
					c + Vector2(0, 6), c + Vector2(-5, 2)]), Color(0.9, 0.5, 0.2))
			"missiles":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 6), c + Vector2(6, 0),
					c + Vector2(-6, -6), c + Vector2(-3, 0)]), Color(1.0, 0.4, 0.4))
			"drones":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 0),
					c + Vector2(0, 6), c + Vector2(-5, 0)]), Color(0.7, 0.5, 1.0))
			"scrap":
				draw_circle(c, 5, Color(1.0, 0.8, 0.3))
				draw_circle(c, 2, Color(0.3, 0.2, 0.05))

func VP() -> Vector2:
	return get_viewport().get_visible_rect().size

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _handle_tap(pos: Vector2) -> void:
	if targeting_hack or targeting_mc:
		if enemy_view != null:
			var elocal: Vector2 = enemy_view.to_local(pos)
			var eroom: String = enemy_view.world_to_room(elocal)
			if eroom != "":
				if targeting_hack:
					var sid: String = enemy.rooms[eroom].get("system", "")
					if player.activate_hack(sid):
						_log("Hacking their %s!" % Content.get_system(sid).get("name", sid))
					else:
						_log("Not ready to hack (no system there or cooldown).")
					targeting_hack = false
					return
				if targeting_mc:
					var target: CrewMember = null
					for cm in enemy.crew:
						if cm.alive() and cm.room.id == eroom:
							target = cm
							break
					if target != null and player.activate_mc(target):
						_log("%s fights for us now!" % target.name)
					else:
						_log("Could not mind-control that crew member.")
					targeting_mc = false
					return
	if targeting_enemy and selected_weapon != null and enemy_view != null:
		var local: Vector2 = enemy_view.to_local(pos)
		var room_id: String = enemy_view.world_to_room(local)
		if room_id != "":
			selected_weapon.target_room_id = room_id
			targeting_enemy = false
			_log("Target locked.")
		return
	if player_view == null:
		return
	var plocal: Vector2 = player_view.to_local(pos)
	var proom: String = player_view.world_to_room(plocal)
	if proom != "":
		if selected_crew != null:
			player.assign_crew_to_room(selected_crew, proom)
			selected_crew = null
			queue_redraw()
		else:
			_select_crew_in_room(proom)

func _select_crew_in_room(room_id: String) -> void:
	for cm in player.crew:
		if cm.alive() and cm.room.id == room_id:
			selected_crew = cm
			_log("Selected %s (%s). Tap a room to move them." % [cm.name, cm.race])
			return
	_log("No crew in that room.")

func _select_weapon(w: WeaponState) -> void:
	if not w.autofire and w.ready and w.target_room_id != "" and combat != null:
		if combat.manual_fire(w):
			_log("Fired %s." % Content.get_weapon(w.id).get("name", w.id))
			return
	selected_weapon = w
	targeting_enemy = true
	_log("Selected %s. Tap the enemy ship to target it." % Content.get_weapon(w.id).get("name", w.id))

func _toggle_pause() -> void:
	GameState.paused = not GameState.paused
	pause_button.text = "Resume" if GameState.paused else "Pause"

func _toggle_battery() -> void:
	if player.battery_active:
		return
	if player.activate_battery():
		_refresh_battery_button()
		_log("Backup battery engaged (+1 power).")

func _toggle_doors() -> void:
	player.doors_locked = not player.doors_locked
	doors_button.text = "Unlock" if player.doors_locked else "Lock Doors"
	_log("Doors locked." if player.doors_locked else "Doors unlocked.")

func _toggle_cloak() -> void:
	if player.activate_cloak():
		_log("Cloaking engaged. Incoming shots miss until it wears off.")
		_refresh_cloak_button()
	else:
		_log("Cloak on cooldown or unpowered.")

func _refresh_cloak_button() -> void:
	if cloak_button == null:
		return
	if player.cloak_active:
		cloak_button.text = "Cloaked (%ds)" % int(ceil(player.cloak_timer))
	elif player.cloak_ready():
		cloak_button.text = "Cloak"
	else:
		cloak_button.text = "Cloak (%.0f%%)" % (player.cloak_charge * 100)

func _refresh_battery_button() -> void:
	if battery_button == null:
		return
	if player.battery_active:
		battery_button.text = "Battery (%ds)" % int(player.battery_time)
	elif player.battery_ready():
		battery_button.text = "Battery"
	else:
		battery_button.text = "Recharging (%ds)" % int(player.battery_time)

func _quit_to_menu() -> void:
	GameState.paused = false
	quit_to_menu.emit()

func _flee() -> void:
	if _ended:
		return
	if GameState.pending_encounter.get("boss", false):
		_log("The flagship's weapons lock you in. You cannot flee!")
		return
	if player.dodge_chance() <= 0.0:
		_log("Engines are down. You cannot flee!")
		return
	# fleeing takes time; engines give you a chance to slip away
	if randf() * 100.0 > player.dodge_chance() + 15.0:
		_log("You failed to escape!")
		return
	_ended = true
	battle_ended.emit(null)

# ---------- loop ----------

func _process(delta: float) -> void:
	if combat == null or GameState.paused or _ended:
		return
	if selected_weapon != null and selected_weapon.target_room_id != "":
		selected_weapon.enabled = true
	player.battery_tick(delta)
	if hack_button != null:
		hack_button.modulate = Color.WHITE
	if mc_button != null:
		mc_button.modulate = Color.WHITE
	combat.tick(delta)
	_refresh_weapon_buttons()
	if battery_button != null and player.battery_capacity > 0:
		_refresh_battery_button()
	if cloak_button != null:
		_refresh_cloak_button()
	_refresh_advanced()
	_refresh_ui()
	player_view.queue_redraw()
	enemy_view.queue_redraw()
	if combat.combat_over():
		_end_battle(combat.winner())

func _end_battle(winner: Ship) -> void:
	combat = null
	GameState.in_battle = false
	_ended = true
	battle_ended.emit(winner)

func _refresh_weapon_buttons() -> void:
	var powered := player.is_powered("weapons")
	for entry in weapon_buttons:
		var w: WeaponState = entry.weapon
		var name: String = Content.get_weapon(w.id).get("name", w.id)
		var ammo := ""
		if w.def.get("ammo") == "missiles":
			ammo = "  %d rnd" % player.missiles
		var state := "[READY]" if w.ready else "[%.0f%%]" % (w.progress() * 100)
		entry.name.text = "%s  %s%s" % [name, state, ammo]
		if not powered:
			entry.name.modulate = Color(0.55, 0.55, 0.55)
		elif w.ready and not w.autofire:
			entry.name.modulate = Color(1.0, 0.85, 0.3)
		else:
			entry.name.modulate = Color.WHITE
		entry.bar.value = w.progress()
		entry.bar.modulate = Color(0.3, 1.0, 0.4) if w.ready else Color(1.0, 1.0, 1.0)
		entry.auto.text = "AU" if w.autofire else "MAN"
		entry.auto.modulate = Color.WHITE if w.autofire else Color(0.6, 0.6, 0.6)
	# show the target reticle on the enemy hull
	if enemy_view != null:
		var tr: String = ""
		if selected_weapon != null and selected_weapon.target_room_id != "":
			tr = selected_weapon.target_room_id
		enemy_view.target_room = tr

func _refresh_ui() -> void:
	if player == null:
		return
	var power_used: int = player.total_power_used()
	resource_values["sector"].text = str(sector_num)
	resource_values["hull"].text = str(int(player.hull))
	resource_values["shields"].text = str(player.shield_bubbles)
	resource_values["fuel"].text = str(player.fuel)
	resource_values["missiles"].text = str(player.missiles)
	resource_values["drones"].text = str(player.drone_parts)
	resource_values["scrap"].text = str(player.scrap)
	resource_icons["hull"].modulate = Color(1.0, 0.3, 0.3) if player.hull_ratio() < 0.3 else Color.WHITE
	_refresh_reactor(power_used)
	for sid in power_boxes:
		var sys: SystemState = player.systems.get(sid)
		if sys != null:
			power_boxes[sid].text = "%d/%d" % [sys.power, sys.level]
			var col: Control = power_cols.get(sid)
			if col != null:
				if sys.is_destroyed():
					col.modulate = Color(1.0, 0.35, 0.35)
				elif sys.ion > 0:
					col.modulate = Color(0.55, 0.9, 1.0)
				elif sys.active():
					col.modulate = Color.WHITE
				else:
					col.modulate = Color(0.6, 0.6, 0.6)
	if jump_label != null:
		jump_label.text = "FTL JUMP\nDISABLED (IN COMBAT)"
	if enemy_info_label != null and enemy != null:
		enemy_info_label.text = "%s    Hull %d/%d    Shields %d" % [
			enemy.def.get("name", "Enemy"), int(ceil(enemy.hull)), int(enemy.hull_max), enemy.shield_bubbles]
	for cm in crew_buttons:
		var btn: Button = crew_buttons[cm]
		if not cm.alive():
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.text = "%s (%s)  DEAD" % [cm.name, cm.race]
			continue
		btn.text = "%s (%s)  HP %d  %s" % [cm.name, cm.race, int(ceil(cm.hp)), _room_display(cm.room.id)]
		if cm == selected_crew:
			btn.modulate = Color(1, 1, 0.4)
		elif cm.room.id in player.rooms and player.rooms[cm.room.id].get("system", "") != "" \
				and player.is_powered(player.rooms[cm.room.id]["system"]):
			btn.modulate = Color(0.5, 1.0, 0.6)
		else:
			btn.modulate = Color.WHITE
	player_view.queue_redraw()
	enemy_view.queue_redraw()

func _refresh_reactor(used: int) -> void:
	if reactor_label == null:
		return
	var total: int = player.reactor + int(player.battery)
	var battery_start: int = player.reactor
	reactor_label.text = "%d / %d" % [used, total]
	for i in reactor_pips.size():
		var r: ColorRect = reactor_pips[i]
		if i < used:
			r.color = Color(0.3, 0.9, 1.0) if i < battery_start else Color(1.0, 0.85, 0.3)
		elif i < total:
			r.color = Color(0.18, 0.18, 0.25)
		else:
			r.color = Color(0.08, 0.08, 0.12)

func _room_display(room_id: String) -> String:
	var room: Dictionary = player.rooms.get(room_id, {})
	var sys_id: String = room.get("system", "")
	if sys_id != "":
		return Content.get_system(sys_id).get("name", sys_id)
	return "Room"

func _setup_signals() -> void:
	combat.ship_hit.connect(_on_ship_hit)

func _on_ship_hit(target: Ship, room_id: String, amount: float) -> void:
	_refresh_ui()
	if target == player:
		queue_redraw()

func _log(text: String) -> void:
	if log_label == null:
		return
	log_label.text = text + "\n" + log_label.text
	log_label.text = log_label.text.substr(0, 400)