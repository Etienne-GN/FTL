extends Node2D
## Main playable scene: builds the combat screen (two ships, starfield, HUD),
## drives the CombatManager, and handles touch/mouse input for power
## allocation, weapon targeting and crew movement.

var combat: CombatManager = null
var player_view: ShipView
var enemy_view: ShipView
var selected_weapon: WeaponState = null
var targeting_enemy := false
var selected_crew: CrewMember = null

var hud: Control
var resources_label: Label
var log_label: Label
var pause_button: Button
var power_boxes := {}          # system_id -> VBoxContainer
var weapon_buttons := []       # button -> weapon

var star_points := []
var enemies := []

func _ready() -> void:
	randomize()
	Content.load_all()
	_build_background()
	if SaveManager.has_save():
		SaveManager.load_run()
	else:
		GameState.new_run("kestrel")
	if GameState.enemy_ship == null:
		GameState.spawn_enemy(GameState.sector)
	combat = CombatManager.new(GameState.player_ship, GameState.enemy_ship)
	GameState.in_battle = true
	_build_starfield()
	_build_ships()
	_build_hud()
	_setup_signals()
	_refresh_ui()

# ---------- scene construction ----------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _build_ships() -> void:
	player_view = ShipView.new()
	player_view.setup(GameState.player_ship, false)
	add_child(player_view)
	player_view.position = Vector2(90, 60)
	enemy_view = ShipView.new()
	enemy_view.setup(GameState.enemy_ship, true)
	add_child(enemy_view)
	enemy_view.position = Vector2(90, 0)

func _build_starfield() -> void:
	for i in 400:
		star_points.append(Vector2(randf() * 1280, randf() * 720))

func _draw() -> void:
	# background handled by a ColorRect; stars drawn here
	for p in star_points:
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, randf() * 0.5 + 0.2))

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	# top-left: sector + resources
	resources_label = Label.new()
	resources_label.position = Vector2(12, 8)
	resources_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(resources_label)

	# pause button top-right
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.position = Vector2(VP().x - 100, 8)
	pause_button.custom_minimum_size = Vector2(90, 40)
	pause_button.pressed.connect(_toggle_pause)
	hud.add_child(pause_button)

	# power allocation panel (bottom-left)
	var power_panel := PanelContainer.new()
	power_panel.position = Vector2(12, VP().y - 230)
	var vbox := VBoxContainer.new()
	power_panel.add_child(vbox)
	var title := Label.new()
	title.text = "SYSTEMS"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	for sid in GameState.player_ship.systems.keys():
		if sid == "hull":
			continue
		var row := _make_system_row(sid)
		vbox.add_child(row)
	hud.add_child(power_panel)

	# weapons panel
	_build_weapons_panel()

	# log
	log_label = Label.new()
	log_label.position = Vector2(12, VP().y - 360)
	log_label.custom_minimum_size = Vector2(300, 120)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(log_label)

func _build_weapons_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(VP().x - 240, VP().y - 260)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "WEAPONS"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	weapon_buttons.clear()
	for w in GameState.player_ship.weapons:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 40)
		btn.text = "%s  [%.0f%%]" % [Content.get_weapon(w.id).get("name", w.id), w.progress() * 100]
		var captured: WeaponState = w
		btn.pressed.connect(_select_weapon.bind(captured))
		vbox.add_child(btn)
		weapon_buttons.append({"button": btn, "weapon": w})
	hud.add_child(panel)

func _make_system_row(sid: String) -> Control:
	var sys: SystemState = GameState.player_ship.systems[sid]
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = sys.name
	lbl.custom_minimum_size = Vector2(90, 0)
	var pwr_label := Label.new()
	pwr_label.text = "0/%d" % sys.level
	pwr_label.custom_minimum_size = Vector2(50, 0)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(30, 28)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(30, 28)
	minus.pressed.connect(_adj_power.bind(sid, -1, pwr_label))
	plus.pressed.connect(_adj_power.bind(sid, 1, pwr_label))
	hbox.add_child(lbl)
	hbox.add_child(minus)
	hbox.add_child(plus)
	hbox.add_child(pwr_label)
	power_boxes[sid] = pwr_label
	return hbox

func VP() -> Vector2:
	return get_viewport().get_visible_rect().size

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)

func _handle_tap(pos: Vector2) -> void:
	# enemy targeting
	if targeting_enemy and selected_weapon != null:
		var local: Vector2 = to_local_with(enemy_view, pos)
		var room_id: String = enemy_view.world_to_room(local)
		if room_id != "":
			selected_weapon.target_room_id = room_id
			targeting_enemy = false
			_log("Targeting %s at enemy system." % selected_weapon.target_system)
		return
	# crew selection / move on player ship
	var plocal: Vector2 = to_local_with(player_view, pos)
	var proom: String = player_view.world_to_room(plocal)
	if proom != "":
		if selected_crew != null:
			GameState.player_ship.assign_crew_to_room(selected_crew, proom)
			selected_crew.task = "man"
			selected_crew = null
			queue_redraw()
		else:
			_select_crew_in_room(proom)

func to_local_with(node: Node2D, global_pos: Vector2) -> Vector2:
	return node.to_local(global_pos)

func _select_crew_in_room(room_id: String) -> void:
	for cm in GameState.player_ship.crew:
		if cm.alive() and cm.room.id == room_id:
			selected_crew = cm
			_log("Selected %s (%s). Tap a room to move them." % [cm.name, cm.race])
			return
	_log("No crew in that room.")

func _select_weapon(w: WeaponState) -> void:
	selected_weapon = w
	targeting_enemy = true
	_log("Selected %s. Tap the enemy ship to target it (auto-fires on charge)." % Content.get_weapon(w.id).get("name", w.id))

func _toggle_pause() -> void:
	GameState.paused = not GameState.paused
	pause_button.text = "Resume" if GameState.paused else "Pause"

func _adj_power(sid: String, delta: int, label: Label) -> void:
	var ok := GameState.player_ship.allocate_power(sid, GameState.player_ship.systems[sid].power + delta)
	_refresh_ui()
	if not ok:
		_log("Not enough reactor power.")
	label.text = "%d/%d" % [GameState.player_ship.systems[sid].power, GameState.player_ship.systems[sid].level]

# ---------- loop ----------

func _process(delta: float) -> void:
	if combat == null or GameState.paused:
		return
	if selected_weapon != null and selected_weapon.target_room_id != "":
		selected_weapon.enabled = true
	combat.tick(delta)
	_refresh_weapon_buttons()
	player_view.queue_redraw()
	enemy_view.queue_redraw()
	if combat.combat_over():
		_end_battle(combat.winner())

func _end_battle(winner: Ship) -> void:
	combat = null
	GameState.in_battle = false
	if winner == GameState.player_ship:
		var reward := 12 + GameState.sector * 4
		GameState.add_resources(1, (randi() % 3), (randi() % 2), reward)
		_log("Ship destroyed! +1 fuel, +%d scrap." % reward)
	else:
		_log("Your ship was destroyed.")
		GameState.is_over()

func _refresh_weapon_buttons() -> void:
	for entry in weapon_buttons:
		var w: WeaponState = entry.weapon
		var name: String = Content.get_weapon(w.id).get("name", w.id)
		var state := "[READY]" if w.ready else "[%.0f%%]" % (w.progress() * 100)
		entry.button.text = "%s  %s" % [name, state]

func _refresh_ui() -> void:
	if GameState.player_ship == null:
		return
	var p := GameState.player_ship
	resources_label.text = "Sector %d   Hull %s   Power %d/%d\nFuel %d   Missiles %d   Drones %d   Scrap %d" % [
		GameState.sector, str(int(p.hull)), p.total_power_used(), p.reactor + int(p.battery),
		p.fuel, p.missiles, p.drone_parts, p.scrap]
	for sid in power_boxes:
		var sys: SystemState = p.systems.get(sid)
		if sys != null:
			power_boxes[sid].text = "%d/%d" % [sys.power, sys.level]

func _setup_signals() -> void:
	combat.ship_hit.connect(_on_ship_hit)

func _on_ship_hit(target: Ship, room_id: String, amount: float) -> void:
	_refresh_ui()
	queue_redraw()

func _log(text: String) -> void:
	log_label.text = text + "\n" + log_label.text
	log_label.text = log_label.text.substr(0, 400)