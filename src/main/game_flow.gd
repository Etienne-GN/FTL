extends Node2D
## GameFlow: top-level controller. Manages the run's screen state machine:
## menu -> map -> (combat | event | store) -> map -> ... -> victory/game-over.

enum State { MENU, MAP, COMBAT, EVENT, STORE, OVER }

var state := State.MENU
var combat_screen: CombatScreen = null
var map_view: MapView = null
var jump_range := 1

var header_label: Label
var hint_label: Label

func _ready() -> void:
	randomize()
	Content.load_all()
	_build_background()
	_show_menu()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

# ---------- menu ----------

func _show_menu() -> void:
	_clear()
	state = State.MENU
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	add_child(vbox)
	var title := Label.new()
	title.text = "FASTER THAN LIGHT"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "open reimplementation -- Android"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var prog := Label.new()
	var best_sector := 1
	var meta_file := JSONHelpers.load_json("user://meta.save")
	if not meta_file.is_empty():
		best_sector = int(meta_file.get("highest_sector", 1))
	prog.text = "Best run: Sector %d  |  Ships unlocked: %d" % [best_sector, SaveManager.load_meta().size()]
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prog)
	var continue_btn := Button.new()
	continue_btn.text = "Continue Run" if SaveManager.has_save() else "New Game"
	continue_btn.custom_minimum_size = Vector2(260, 48)
	continue_btn.pressed.connect(_start_game)
	vbox.add_child(continue_btn)
	# ship select
	var ships := SaveManager.load_meta()
	for sid in ships:
		var b := Button.new()
		b.text = "Start: %s" % Content.get_ship(sid).get("name", sid)
		b.custom_minimum_size = Vector2(260, 40)
		b.pressed.connect(_start_with.bind(sid))
		vbox.add_child(b)

func _start_with(ship_id: String) -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
	GameState.new_run(ship_id)
	_show_map()

func _start_game() -> void:
	if SaveManager.has_save():
		SaveManager.load_run()
	else:
		GameState.new_run("kestrel")
	if GameState.in_battle and GameState.enemy_ship != null:
		_show_combat()
	else:
		_show_map()

# ---------- map ----------

func _show_map() -> void:
	_clear()
	state = State.MAP
	var header := PanelContainer.new()
	header.position = Vector2(12, 8)
	var hb := VBoxContainer.new()
	header.add_child(hb)
	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 18)
	header_label.text = _header_text()
	hb.add_child(header_label)
	hint_label = Label.new()
	hint_label.text = "Tap a highlighted beacon to jump (fuel:1). Rebel fleet advances each jump."
	hint_label.add_theme_font_size_override("font_size", 14)
	hb.add_child(hint_label)
	var range_h := HBoxContainer.new()
	for r in [1, 2, 3]:
		var b := Button.new()
		b.text = "Jump %d" % r
		b.custom_minimum_size = Vector2(90, 36)
		b.pressed.connect(_set_range.bind(r))
		range_h.add_child(b)
	var quit_b := Button.new()
	quit_b.text = "Menu (save)"
	quit_b.custom_minimum_size = Vector2(120, 36)
	quit_b.pressed.connect(_quit_to_menu)
	range_h.add_child(quit_b)
	hb.add_child(range_h)
	add_child(header)

	map_view = MapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.setup(GameState.map)
	map_view.clicked.connect(_on_beacon_clicked)
	add_child(map_view)
	if GameState.run_active and GameState.player_ship != null:
		SaveManager.save_run()

func _exit_tree() -> void:
	if GameState.player_ship != null and GameState.run_active and GameState.in_battle:
		SaveManager.save_run()

func _header_text() -> String:
	var p := GameState.player_ship
	return "Sector %d   Hull %d/%d   Fuel %d   Scrap %d   Missiles %d   Drones %d" % [
		GameState.sector, int(p.hull), int(p.hull_max), p.fuel, p.scrap, p.missiles, p.drone_parts]

func _set_range(r: int) -> void:
	jump_range = r
	if hint_label != null:
		hint_label.text = "Range set to %d. Tap a highlighted beacon to jump." % r

func _on_beacon_clicked(beacon_id: String) -> void:
	if state != State.MAP:
		return
	if GameState.attempt_jump(beacon_id, jump_range):
		SaveManager.save_run()
		_resolve_encounter()
	else:
		_refresh_map_header()

func _refresh_map_header() -> void:
	if header_label != null:
		header_label.text = _header_text()
	if hint_label != null:
		hint_label.text = "Cannot jump (no fuel or unreachable)."

func _quit_to_menu() -> void:
	if GameState.player_ship != null and GameState.run_active:
		SaveManager.save_run()
	_show_menu()

# ---------- encounter resolution ----------

func _resolve_encounter() -> void:
	var enc: Dictionary = GameState.pending_encounter
	match enc.get("action", "empty"):
		"battle":
			_show_combat()
		"event":
			_show_event(enc.get("event", {}))
		"store":
			_show_store()
		"next_sector":
			GameState.next_sector()
			_show_map()
		_:
			_show_map()

# ---------- combat ----------

func _show_combat() -> void:
	_clear()
	state = State.COMBAT
	combat_screen = CombatScreen.new()
	combat_screen.battle_ended.connect(_on_combat_end)
	combat_screen.quit_to_menu.connect(_quit_to_menu)
	add_child(combat_screen)
	GameState.player_ship.refresh_after_sector()
	combat_screen.start_battle(GameState.player_ship, GameState.enemy_ship, GameState.sector)

func _on_combat_end(winner: Ship) -> void:
	if combat_screen != null:
		combat_screen.queue_free()
		combat_screen = null
	if winner == GameState.player_ship and GameState.enemy_ship != null:
		var reward := 12 + GameState.sector * 4
		var fuel_add := 1
		if GameState.pending_encounter.get("boss", false):
			SaveManager.save_meta()
			_show_victory()
			return
		GameState.pending_encounter = {}
		GameState.add_resources(fuel_add, randi() % 3, randi() % 2, reward)
		GameState.enemy_ship = null
		SaveManager.save_run()
		_show_map()
	elif winner == null:
		# fled or ship destroyed without boss; proceed on map (fled) or game over
		GameState.pending_encounter = {}
		GameState.enemy_ship = null
		if GameState.player_ship.hull <= 0.0:
			SaveManager.delete_save()
			_show_gameover()
		else:
			SaveManager.save_run()
			_show_map()
	else:
		GameState.enemy_ship = null
		SaveManager.delete_save()
		_show_gameover()

# ---------- event ----------

func _show_event(ev: Dictionary) -> void:
	state = State.EVENT
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "EVENT"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var txt := Label.new()
	txt.text = ev.get("text", "Something happens.")
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(560, 0)
	box.add_child(txt)
	for i in ev.get("choices", []).size():
		var b := Button.new()
		b.text = str(ev["choices"][i].get("text", "Choose"))
		b.custom_minimum_size = Vector2(560, 40)
		b.pressed.connect(_choose_event.bind(i))
		box.add_child(b)
	add_child(panel)

func _choose_event(i: int) -> void:
	GameState.resolve_event(i)
	_show_map()

# ---------- store ----------

func _show_store() -> void:
	state = State.STORE
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "STORE"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var stock: Array = GameState.stock_systems()
	for sid in stock:
		var sys: SystemState = GameState.player_ship.systems[sid]
		if sys.level >= sys.max_level_def:
			continue
		var cost := 18 + sys.level * 15
		var b := Button.new()
		b.text = "Upgrade %s (%d) [%d scrap]" % [sys.name, sys.level + 1, cost]
		b.custom_minimum_size = Vector2(560, 40)
		b.pressed.connect(_buy_upgrade.bind(sid, cost))
		box.add_child(b)
	for wid in GameState.stock_weapons():
		var cost := int(Content.get_weapon(wid).get("price", 30))
		var b := Button.new()
		b.text = "Buy %s [%d scrap]" % [Content.get_weapon(wid).get("name", wid), cost]
		b.custom_minimum_size = Vector2(560, 40)
		b.pressed.connect(_buy_weapon.bind(wid, cost))
		box.add_child(b)
	# provisions
	var p := GameState.player_ship
	if p.hull < p.hull_max:
		var repair_cost := int((p.hull_max - p.hull)) * 10
		var rb := Button.new()
		rb.text = "Repair hull (%d hull) [%d scrap]" % [int(p.hull_max - p.hull), repair_cost]
		rb.custom_minimum_size = Vector2(560, 40)
		rb.pressed.connect(_buy_repair.bind(repair_cost))
		box.add_child(rb)
	if p.crew.size() < 8:
		var cb := Button.new()
		cb.text = "Hire crew [50 scrap]"
		cb.custom_minimum_size = Vector2(560, 40)
		cb.pressed.connect(_buy_crew)
		box.add_child(cb)
	var fb := Button.new()
	fb.text = "Buy fuel (4) [15 scrap]"
	fb.custom_minimum_size = Vector2(560, 40)
	fb.pressed.connect(_buy_fuel)
	box.add_child(fb)
	if p.battery_capacity == 0:
		var bb := Button.new()
		bb.text = "Install backup battery [45 scrap]"
		bb.custom_minimum_size = Vector2(560, 40)
		bb.pressed.connect(_buy_battery)
		box.add_child(bb)
	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(560, 40)
	leave.pressed.connect(_leave_store)
	box.add_child(leave)
	add_child(panel)

func _buy_upgrade(sid: String, cost: int) -> void:
	if GameState.player_ship.scrap >= cost:
		GameState.player_ship.scrap -= cost
		GameState.player_ship.systems[sid].set_level(GameState.player_ship.systems[sid].level + 1)
		_show_store()

func _buy_weapon(wid: String, cost: int) -> void:
	if GameState.player_ship.scrap >= cost and GameState.player_ship.weapons.size() < 4:
		GameState.player_ship.scrap -= cost
		GameState.player_ship.weapons.append(WeaponState.new(Content.get_weapon(wid)))
		_show_store()

func _buy_repair(cost: int) -> void:
	var p := GameState.player_ship
	if p.scrap >= cost:
		p.scrap -= cost
		p.hull = p.hull_max
		_show_store()

func _buy_crew() -> void:
	var p := GameState.player_ship
	if p.scrap < 50 or p.crew.size() >= 8:
		return
	p.scrap -= 50
	var races := ["human", "human", "human", "engi", "mantis", "rock"]
	p.add_crew({"name": "Recruit %d" % (p.crew.size() + 1), "race": races[randi() % races.size()]})
	_show_store()

func _buy_fuel() -> void:
	var p := GameState.player_ship
	if p.scrap >= 15:
		p.scrap -= 15
		p.fuel += 4
		_show_store()

func _buy_battery() -> void:
	var p := GameState.player_ship
	if p.scrap >= 45:
		p.scrap -= 45
		p.battery_capacity = 1
		_show_store()

func _leave_store() -> void:
	GameState.pending_encounter = {}
	_show_map()

# ---------- end screens ----------

func _show_gameover() -> void:
	_clear()
	state = State.OVER
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	var t := Label.new()
	t.text = "GAME OVER"
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "Your ship was destroyed."
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b := Button.new()
	b.text = "Menu"
	b.custom_minimum_size = Vector2(200, 44)
	b.pressed.connect(_show_menu)
	v.add_child(b)
	add_child(v)

func _show_victory() -> void:
	_clear()
	state = State.OVER
	GameState.victory_flag = true
	SaveManager.save_meta()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	var t := Label.new()
	t.text = "VICTORY"
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "The flagship is destroyed. New ships unlocked!"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b := Button.new()
	b.text = "Menu"
	b.custom_minimum_size = Vector2(200, 44)
	b.pressed.connect(_show_menu)
	v.add_child(b)
	add_child(v)

func _clear() -> void:
	for child in get_children():
		if child is ColorRect:
			continue
		child.queue_free()
	map_view = null
	combat_screen = null