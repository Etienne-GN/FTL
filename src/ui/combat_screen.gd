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

var hud: Control
var resources_label: Label
var log_label: Label
var pause_button: Button
var battery_button: Button
var doors_button: Button
var power_panel: PanelContainer
var power_boxes := {}          # system_id -> Label
var weapon_buttons := []       # array of {button, weapon}

var star_points := []

# Rectangles to sanity-check for screen overlap (global pixel rects).
var layout_rects := {}                 # name -> Rect2

func _rect_noise() -> void:
	layout_rects = {}
	layout_rects["player_ship"] = _ship_global_rect(player_view)
	layout_rects["enemy_ship"] = _ship_global_rect(enemy_view)
	if resources_label != null:
		layout_rects["resources"] = resources_label.get_global_rect()
	if log_label != null:
		layout_rects["log"] = log_label.get_global_rect()
	layout_rects["systems"] = power_panel.get_global_rect()
	for child in hud.get_children():
		if child == power_panel:
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

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _build_ships() -> void:
	const SCALE := 0.35
	player_view = ShipView.new()
	player_view.setup(player, false)
	player_view.scale = Vector2(SCALE, SCALE)
	add_child(player_view)
	var ps: Vector2 = player_view.total_size() * SCALE
	player_view.position = Vector2(60, 340)
	enemy_view = ShipView.new()
	enemy_view.setup(enemy, true)
	enemy_view.scale = Vector2(SCALE, SCALE)
	add_child(enemy_view)
	var es: Vector2 = enemy_view.total_size() * SCALE
	enemy_view.position = Vector2(VP().x - es.x - 20, 70)

func _build_starfield() -> void:
	for i in 300:
		star_points.append(Vector2(randf() * 1280, randf() * 720))

func _draw() -> void:
	for p in star_points:
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, randf() * 0.5 + 0.2))

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	resources_label = Label.new()
	resources_label.position = Vector2(12, 8)
	resources_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(resources_label)

	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.position = Vector2(VP().x - 100, 8)
	pause_button.custom_minimum_size = Vector2(90, 40)
	pause_button.pressed.connect(_toggle_pause)
	hud.add_child(pause_button)

	var end_btn := Button.new()
	end_btn.text = "Flee"
	end_btn.position = Vector2(VP().x - 200, 8)
	end_btn.custom_minimum_size = Vector2(90, 40)
	end_btn.pressed.connect(_flee)
	hud.add_child(end_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.position = Vector2(VP().x - 300, 8)
	quit_btn.custom_minimum_size = Vector2(90, 40)
	quit_btn.pressed.connect(_quit_to_menu)
	hud.add_child(quit_btn)

	if player.battery_capacity > 0:
		battery_button = Button.new()
		battery_button.text = "Battery"
		battery_button.position = Vector2(VP().x - 400, 8)
		battery_button.custom_minimum_size = Vector2(90, 40)
		battery_button.pressed.connect(_toggle_battery)
		hud.add_child(battery_button)

	if player.systems.has("doors"):
		doors_button = Button.new()
		doors_button.text = "Lock Doors"
		doors_button.position = Vector2(VP().x - 490, 8)
		doors_button.custom_minimum_size = Vector2(90, 40)
		doors_button.pressed.connect(_toggle_doors)
		hud.add_child(doors_button)

	power_panel = PanelContainer.new()
	power_panel.position = Vector2(12, 540)
	var vbox := VBoxContainer.new()
	power_panel.add_child(vbox)
	var title := Label.new()
	title.text = "SYSTEMS"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	for sid in player.systems.keys():
		if sid == "hull":
			continue
		vbox.add_child(_make_system_row(sid))
	hud.add_child(power_panel)

	_build_weapons_panel()
	_build_crew_panel()
	_build_teleporter_panel(self)

	log_label = Label.new()
	log_label.position = Vector2(700, 340)
	log_label.custom_minimum_size = Vector2(300, 120)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(log_label)

func _build_weapons_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(1040, 470)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "WEAPONS"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	weapon_buttons.clear()
	for w in player.weapons:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 40)
		btn.text = "%s  [0%%]" % Content.get_weapon(w.id).get("name", w.id)
		var captured: WeaponState = w
		btn.pressed.connect(_select_weapon.bind(captured))
		vbox.add_child(btn)
		weapon_buttons.append({"button": btn, "weapon": w})
	hud.add_child(panel)

func _build_crew_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(700, 60)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "CREW (%d)" % player.crew.size()
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	crew_buttons = {}
	for cm in player.crew:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 30)
		btn.text = "%s (%s)" % [cm.name, cm.race]
		btn.tooltip_text = _crew_skill_text(cm)
		var captured: CrewMember = cm
		btn.pressed.connect(_select_crew.bind(captured))
		vbox.add_child(btn)
		crew_buttons[cm] = btn
	hud.add_child(panel)

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

func _build_teleporter_panel(_ignore) -> void:
	if player.systems.has("teleporter"):
		var panel := PanelContainer.new()
		panel.position = Vector2(480, 60)
		var vbox := VBoxContainer.new()
		panel.add_child(vbox)
		var title := Label.new()
		title.text = "TELEPORTER"
		title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(title)
		var send := Button.new()
		send.text = "Send crew (enemy)"
		send.custom_minimum_size = Vector2(160, 32)
		send.pressed.connect(_teleport_send)
		vbox.add_child(send)
		var recall := Button.new()
		recall.text = "Recall boarders"
		recall.custom_minimum_size = Vector2(160, 32)
		recall.pressed.connect(_teleport_recall)
		vbox.add_child(recall)
		hud.add_child(panel)

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

func _make_system_row(sid: String) -> Control:
	var sys: SystemState = player.systems[sid]
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = sys.name
	lbl.custom_minimum_size = Vector2(90, 0)
	var pwr_label := Label.new()
	pwr_label.text = "%d/%d" % [sys.power, sys.level]
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

func _adj_power(sid: String, delta: int, label: Label) -> void:
	var ok := player.allocate_power(sid, player.systems[sid].power + delta)
	if not ok:
		_log("Not enough reactor power.")
	_refresh_ui()

func _flee() -> void:
	if not _ended:
		_ended = true
		battle_ended.emit(null)

# ---------- loop ----------

func _process(delta: float) -> void:
	if combat == null or GameState.paused or _ended:
		return
	if selected_weapon != null and selected_weapon.target_room_id != "":
		selected_weapon.enabled = true
	player.battery_tick(delta)
	combat.tick(delta)
	_refresh_weapon_buttons()
	if battery_button != null and player.battery_capacity > 0:
		_refresh_battery_button()
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
	for entry in weapon_buttons:
		var w: WeaponState = entry.weapon
		var name: String = Content.get_weapon(w.id).get("name", w.id)
		var state := "[READY]" if w.ready else "[%.0f%%]" % (w.progress() * 100)
		entry.button.text = "%s  %s" % [name, state]

func _refresh_ui() -> void:
	if player == null:
		return
	resources_label.text = "Sector %d   Hull %s   Power %d/%d\nFuel %d   Missiles %d   Drones %d   Scrap %d" % [
		sector_num, str(int(player.hull)), player.total_power_used(), player.reactor + int(player.battery),
		player.fuel, player.missiles, player.drone_parts, player.scrap]
	for sid in power_boxes:
		var sys: SystemState = player.systems.get(sid)
		if sys != null:
			power_boxes[sid].text = "%d/%d" % [sys.power, sys.level]

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