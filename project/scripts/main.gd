extends Node3D

const WORLD_DEBUG_MANAGER_SCRIPT := preload("res://scripts/world_debug.gd")
const ZONE_MANAGER_SCRIPT := preload("res://scripts/world/zone_manager.gd")
const SQUAD_MANAGER_SCRIPT := preload("res://scripts/squad_manager.gd")
const ATTACHMENT_MANAGER_SCRIPT := preload("res://scripts/attachment_manager.gd")
const ALIFE_MANAGER_SCRIPT := preload("res://scripts/alife_manager.gd")
const TRANSITION_MANAGER_SCRIPT := preload("res://scripts/transition_manager.gd")
const MAP_COMMAND_CONTROLLER_SCRIPT := preload("res://scripts/map_command_controller.gd")
const DEBUG_OVERLAY_COMPOSER_SCRIPT := preload("res://scripts/debug_overlay_composer.gd")

enum DebugMode { NONE = 0, NPC_PICKUPS = 1, NPC_LOCATIONS = 2, ZONE_TRANSITIONS = 3, EVENT_SYSTEM_TEST = 4, TEST_AREA = 5 }

var _debug_mode: DebugMode = DebugMode.NONE
var _menu_layer: CanvasLayer = null

var _player: Variant = null
var _weapon: Variant = null
var _npc: Variant = null
var _hud: Variant = null
var _test_enemy_npc: Variant = null
var _test_enemy_squad: Variant = null
var _test_enemy_last_health: float = -1.0

var _respawn_ttl: float = -1.0
var _zone_transition_cooldown: float = 0.0
var _map_camera: Camera3D = null
var _map_mode: bool = false

const MAP_ZOOM_STEP: float = 6.0
const MAP_MIN_SIZE: float = 20.0
const MAP_MAX_SIZE: float = 140.0

var _npc_manager: NpcManager = null
var _inventory_manager: InventoryManager = null
var _spawner: SceneSpawner = null
var _zone_manager: Variant = null
var _world_debug: Variant = null
var _squad_manager: Variant = null
var _attachment_manager: Variant = null
var _alife_manager: Variant = null
var _transition_manager: Variant = null
var _map_command_controller: Variant = null
var _debug_overlay_composer: Variant = null
var _log_window: Window = null
var _log_view: RichTextLabel = null
var _log_lines: Array[String] = []
var _log_window_prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
const LOG_LINE_LIMIT: int = 300
var _gate_beacon: Node3D = null
var _transition_target_zone: StringName = &""
var _transition_commit_trigger: Area3D = null
var _transition_from_gate_id: int = -1


func _ready() -> void:
	print("Main scene loaded")
	ProjectSettings.set_setting("display/window/subwindows/embed_subwindows", false)
	_debug_overlay_composer = DEBUG_OVERLAY_COMPOSER_SCRIPT.new()

	_npc_manager = NpcManager.new()
	add_child(_npc_manager)

	_inventory_manager = InventoryManager.new()
	add_child(_inventory_manager)

	_spawner = SceneSpawner.new()
	add_child(_spawner)

	_zone_manager = ZONE_MANAGER_SCRIPT.new()
	add_child(_zone_manager)
	_zone_manager.connect("zone_transition_started", Callable(self, "_on_zone_transition_started"))
	_zone_manager.connect("zone_transition_preloaded", Callable(self, "_on_zone_transition_preloaded"))
	_zone_manager.connect("zone_transition_finished", Callable(self, "_on_zone_transition_finished"))

	_npc_manager.configure_spawn(_spawner, self)
	_npc_manager.npc_spawned.connect(_on_npc_spawned)
	_setup_log_window()
	_log_message("Main scene loaded")

	if ClassDB.class_exists("GameBootstrap"):
		var bootstrap: Variant = ClassDB.instantiate("GameBootstrap")
		add_child(bootstrap)
		_log_message("GameBootstrap instantiated from GDExtension")

	_show_debug_menu()


# ---------------------------------------------------------------------------
# Debug map selection menu
# ---------------------------------------------------------------------------

func _show_debug_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "DebugMenu"
	add_child(_menu_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_top = 10
	panel.offset_left = 10
	_menu_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(460, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG MAP SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	vbox.add_child(_make_map_button(
		"1 — NPC + Pickups",
		"Gracz, broń, NPC w walce.\nLoot do podniesienia na ziemi.\nKlasyczny sandbox combat.",
		DebugMode.NPC_PICKUPS
	))

	vbox.add_child(_make_separator())

	vbox.add_child(_make_map_button(
		"2 — NPC + Lokacje (ALife)",
		"Gracz, broń, NPC.\nDebug świat: SmartLocacje, WorldGraph,\nSquady ALife, TransitionManager.",
		DebugMode.NPC_LOCATIONS
	))

	vbox.add_child(_make_separator())

	vbox.add_child(_make_map_button(
		"3 — Przejścia między strefami",
		"Gracz przy bramie strefy.\nDebug grafu, gate triggery, seamless\nprzejście zone_a ↔ zone_b.",
		DebugMode.ZONE_TRANSITIONS
	))

	vbox.add_child(_make_separator())

	vbox.add_child(_make_map_button(
		"4 — Event System Test",
		"Testowanie EventBus, konwencje przyczyn,\nhandlery konsekwencji, telemetria zdarzeń.",
		DebugMode.EVENT_SYSTEM_TEST
	))

	vbox.add_child(_make_separator())

	vbox.add_child(_make_map_button(
		"5 — Obszar Testowy",
		"Zamknięty pokój z sufitem i skrzynkami.\nChodzenie, skakanie, broń. Brak ALife.",
		DebugMode.TEST_AREA
	))


func _make_separator() -> HSeparator:
	return HSeparator.new()


func _make_map_button(title_text: String, desc_text: String, mode: DebugMode) -> VBoxContainer:
	var row := VBoxContainer.new()

	var btn := Button.new()
	btn.text = title_text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_on_map_selected.bind(mode))
	row.add_child(btn)

	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	row.add_child(desc)

	return row


func _on_map_selected(mode: DebugMode) -> void:
	_debug_mode = mode
	if _menu_layer != null:
		_menu_layer.queue_free()
		_menu_layer = null

	_spawn_base_nodes()
	_setup_debug_hud()
	_attachment_manager = ATTACHMENT_MANAGER_SCRIPT.new()
	add_child(_attachment_manager)
	_attachment_manager.attachment_event.connect(_show_event)
	_attachment_manager.setup(_weapon, _inventory_manager, _hud)
	_attachment_manager.mark_equipped("ACOG Scope")

	match mode:
		DebugMode.NPC_PICKUPS:
			_boot_npc_pickups()
		DebugMode.NPC_LOCATIONS:
			_boot_npc_locations()
		DebugMode.ZONE_TRANSITIONS:
			_boot_zone_transitions()
		DebugMode.EVENT_SYSTEM_TEST:
			_boot_event_system_test()
		DebugMode.TEST_AREA:
			_boot_test_area()


# ---------------------------------------------------------------------------
# Shared base: player + weapon + environment + nav
# ---------------------------------------------------------------------------

func _spawn_base_nodes() -> void:
	_player = _spawner.spawn_player()
	if _player == null:
		return
	_player.connect("player_died", Callable(self, "_on_player_died"))
	_npc_manager.set_player(_player)

	_weapon = _spawner.spawn_weapon(_player)
	if _weapon != null:
		_weapon.connect("fired", Callable(self, "_on_weapon_fired"))
		_weapon.connect("bullet_hit", Callable(self, "_on_weapon_bullet_hit"))
		_weapon.connect("reloaded", Callable(self, "_on_weapon_reloaded"))
		_weapon.connect("durability_changed", Callable(self, "_on_weapon_durability_changed"))
		_weapon.connect("weapon_jammed", Callable(self, "_on_weapon_jammed"))

	_spawner.spawn_environment(self)
	_sync_loaded_zone_visuals()
	_spawner.spawn_navigation_region(self)
	_setup_map_camera()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ---------------------------------------------------------------------------
# Mode 1: NPC + Pickups
# ---------------------------------------------------------------------------

func _boot_npc_pickups() -> void:
	# Spawn one NPC and loot items on the floor
	var npc: Variant = _spawner.spawn_npc()
	if npc != null:
		_npc = npc
		_npc_manager.set_npc(npc)
		npc.connect("npc_died", Callable(self, "_on_npc_died"))
	_spawner.spawn_loot_items(self)
	_show_event("Map 1: NPC + Pickups")


# ---------------------------------------------------------------------------
# Mode 2: NPC + Locations (ALife world)
# ---------------------------------------------------------------------------

func _boot_npc_locations() -> void:
	# Spawn one NPC
	var npc: Variant = _spawner.spawn_npc()
	if npc != null:
		_npc = npc
		_npc_manager.set_npc(npc)
		npc.connect("npc_died", Callable(self, "_on_npc_died"))

	_world_debug = WORLD_DEBUG_MANAGER_SCRIPT.new()
	add_child(_world_debug)
	_world_debug.setup(_zone_manager, self)
	_world_debug.zone_gate_entered.connect(_on_zone_gate_entered)
	_world_debug.rebuild()

	_squad_manager = SQUAD_MANAGER_SCRIPT.new()
	add_child(_squad_manager)
	_squad_manager.squad_event.connect(_show_event)
	_squad_manager.squad_arrived.connect(_on_squad_arrived)
	_squad_manager.setup(_zone_manager, self)

	_alife_manager = ALIFE_MANAGER_SCRIPT.new()
	add_child(_alife_manager)
	_alife_manager.setup(_zone_manager, _squad_manager)
	_alife_manager.strategic_tick.connect(_show_event)

	_transition_manager = TRANSITION_MANAGER_SCRIPT.new()
	add_child(_transition_manager)
	_transition_manager.setup(_player, _squad_manager, self)
	if _map_command_controller != null:
		_map_command_controller.update_context(_zone_manager, _squad_manager)

	_show_event("Map 2: NPC + ALife Locations")


# ---------------------------------------------------------------------------
# Mode 3: Zone Transitions
# ---------------------------------------------------------------------------

func _boot_zone_transitions() -> void:
	# Spawn near current region edge gate.
	# Use .position (local) — player added via call_deferred, not in tree yet
	if _player != null and is_instance_valid(_player):
		_player.position = Vector3(18, 2, 0)

	_world_debug = WORLD_DEBUG_MANAGER_SCRIPT.new()
	add_child(_world_debug)
	_world_debug.setup(_zone_manager, self)
	_world_debug.zone_gate_entered.connect(_on_zone_gate_entered)
	_world_debug.rebuild()

	var current_zone: StringName = _zone_manager.get_current_zone_id()
	var next_zone: StringName = _zone_manager.get_gate_target_zone(current_zone)
	var beacon_pos: Vector3 = _zone_manager.get_transition_gate_position(current_zone, next_zone)
	_spawn_gate_beacon(current_zone, next_zone, beacon_pos)

	_show_event("Map 3: Przejście między strefami")
	_show_event(">> Idź do SŁUPA [EDGE] na krawędzi regionu <<")
	_show_event("Regiony tranzytowe mają własną podłogę")
	_show_event("[F1] Powrót do menu")


func _boot_event_system_test() -> void:
	# Spawn player in zone_a
	if _player != null and is_instance_valid(_player):
		_player.position = Vector3(0, 2, 0)

	# Setup world with zones and squads
	_world_debug = WORLD_DEBUG_MANAGER_SCRIPT.new()
	add_child(_world_debug)
	_world_debug.setup(_zone_manager, self)
	_world_debug.rebuild()

	# Subscribe to ALife strategic tick for telemetry logging
	if _alife_manager != null:
		_alife_manager.strategic_tick.connect(_on_alife_telemetry)

	_show_event("Map 4: Event System Test")
	_show_event(">> EventBus, ConsequenceRegistry, Telemetry <<")
	_show_event("Squady ALife generują zdarzenia DEATH, WOUND, itd.")
	_show_event("Patrz console/debug HUD na telemetrii EventBus.")
	_show_event("[F1] Powrót do menu")


func _on_alife_telemetry(msg: String) -> void:
	if msg.is_empty():
		return
	_show_event("[ALife] %s" % msg)


# ---------------------------------------------------------------------------
# Mode 5: Enclosed Test Area
# ---------------------------------------------------------------------------

func _boot_test_area() -> void:
	if _player != null and is_instance_valid(_player):
		_player.position = Vector3(0, 2, 0)

	_spawner.spawn_test_area(self)
	
	# Spawn test NPC with squad
	var test_npc: Variant = _spawner.spawn_npc()
	if test_npc != null:
		test_npc.position = Vector3(5, 1, 5)
		
		# Create test squad for the NPC
		var test_squad: Variant = null
		if ClassDB.class_exists("SquadData"):
			test_squad = ClassDB.instantiate("SquadData")
		if test_squad != null:
			test_squad.set_squad_name("TestEnemy")
			test_squad.set_faction_id(2)
			test_squad.set_npc_count(1)
			test_squad.set_morale(1.0)
		
		# Attach squad reference to NPC so damage can flow through
		if test_squad != null:
			test_npc.set_meta("squad_ref", test_squad)
			_test_enemy_npc = test_npc
			_test_enemy_squad = test_squad
			_test_enemy_last_health = test_npc.get_health()
	
	_show_event("Map 5: Obszar Testowy")
	_show_event("Pokój 20x20, skrzynki, broń, grawitacja.")
	_show_event("Test enemy spawned with morale system active.")
	_show_event("[F1] Powrót do menu")


# ---------------------------------------------------------------------------
# Continuing processing / input (same for all modes)
# ---------------------------------------------------------------------------


func _process(delta: float) -> void:
	if _npc_manager != null:
		_npc_manager.process(delta)

	_sync_test_enemy_morale_from_health()

	if _zone_transition_cooldown > 0.0:
		_zone_transition_cooldown = maxf(0.0, _zone_transition_cooldown - delta)

	_update_respawn_timers(delta)
	_update_debug_hud(delta)


func _sync_test_enemy_morale_from_health() -> void:
	if _debug_mode != DebugMode.TEST_AREA:
		return
	if _test_enemy_npc == null or not is_instance_valid(_test_enemy_npc):
		return
	if _test_enemy_squad == null:
		return
	if not _test_enemy_npc.has_method("get_health"):
		return

	var hp: float = _test_enemy_npc.get_health()
	if _test_enemy_last_health < 0.0:
		_test_enemy_last_health = hp
		return

	var damage_taken: float = _test_enemy_last_health - hp
	if damage_taken > 0.0 and _test_enemy_squad.has_method("take_damage"):
		_test_enemy_squad.take_damage(damage_taken * 0.05)
	_test_enemy_last_health = hp


func _unhandled_input(event: InputEvent) -> void:
	if _map_mode and _map_command_controller != null:
		if _map_command_controller.handle_input(event):
			return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if _handle_global_key_input(event.keycode):
		return

	if _handle_attachment_menu_key(event.keycode):
		return

	_handle_loadout_key(event.keycode)


func _handle_global_key_input(keycode: Key) -> bool:
	if keycode == KEY_QUOTELEFT:
		_toggle_log_window()
		return true

	if keycode == KEY_F1 and _debug_mode != DebugMode.NONE:
		_teardown_world()
		_show_debug_menu()
		return true

	if keycode == KEY_I:
		_attachment_manager.toggle_menu()
		_show_event("Attachment menu open" if _attachment_manager.is_menu_open() else "Attachment menu closed")
		return true

	return false


func _handle_attachment_menu_key(keycode: Key) -> bool:
	if not _attachment_manager.is_menu_open():
		return false

	match keycode:
		KEY_UP, KEY_W:
			_attachment_manager.menu_navigate(-1)
			return true
		KEY_DOWN, KEY_S:
			_attachment_manager.menu_navigate(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_attachment_manager.menu_confirm()
			return true

	return false


func _handle_loadout_key(keycode: Key) -> void:
	match keycode:
		KEY_1:
			_attachment_manager.try_equip("ACOG Scope")
		KEY_2:
			_attachment_manager.try_equip("Suppressor")
		KEY_3:
			_attachment_manager.try_equip("Stock Attachment")
		KEY_0:
			_attachment_manager.clear_all()
		KEY_M:
			_toggle_map()


func _setup_debug_hud() -> void:
	var hud_script: Variant = load("res://scripts/hud.gd")
	if hud_script == null:
		return

	var hud_layer: Variant = hud_script.new()
	if hud_layer == null:
		return

	add_child(hud_layer)
	_hud = hud_layer
	_inventory_manager.set_hud(_hud)


func _setup_log_window() -> void:
	if _log_window != null and is_instance_valid(_log_window):
		return

	_log_window = Window.new()
	_log_window.name = "LogWindow"
	_log_window.title = "Project Logs"
	_log_window.mode = Window.MODE_WINDOWED
	_log_window.size = Vector2i(760, 420)
	_log_window.position = Vector2i(32, 32)
	_log_window.always_on_top = true
	_log_window.visible = false
	add_child(_log_window)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_window.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var logs := RichTextLabel.new()
	logs.name = "LogView"
	logs.scroll_following = true
	logs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logs.text = "Logs will appear here."
	margin.add_child(logs)
	_log_view = logs


func _toggle_log_window() -> void:
	if _log_window == null or not is_instance_valid(_log_window):
		return
	if not _log_window.visible:
		_log_window_prev_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_log_window.visible = true
		_log_window.show()
	else:
		_log_window.visible = false
		Input.set_mouse_mode(_log_window_prev_mouse_mode)


func _setup_map_camera() -> void:
	_map_camera = Camera3D.new()
	_map_camera.name = "MapCamera"
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = 70.0
	_map_camera.position = Vector3(23, 80, 0)
	_map_camera.rotation_degrees = Vector3(-90, 0, 0)
	add_child(_map_camera)

	if _map_command_controller == null:
		_map_command_controller = MAP_COMMAND_CONTROLLER_SCRIPT.new()
		add_child(_map_command_controller)
	_map_command_controller.setup(
		_map_camera,
		_zone_manager,
		_squad_manager,
		Callable(self, "_show_event"),
		MAP_ZOOM_STEP,
		MAP_MIN_SIZE,
		MAP_MAX_SIZE
	)


func _toggle_map() -> void:
	_map_mode = not _map_mode
	if _map_mode:
		if _map_camera != null and is_instance_valid(_map_camera):
			_map_camera.make_current()
		_set_player_input_enabled(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_event("[M] Map ON")
		_show_event("LMB: select/target | Shift+LMB: all squads | Tab: next squad | C: clear goal")
	else:
		var player_cam: Camera3D = _player.get_node_or_null("PlayerCamera") if _player != null and is_instance_valid(_player) else null
		if player_cam != null:
			player_cam.make_current()
		_set_player_input_enabled(true)
		if _map_command_controller != null:
			_map_command_controller.set_map_enabled(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_show_event("[M] Map OFF")


func _get_hp_snapshot() -> Dictionary:
	var hp_value: float = 0.0
	var hp_text: String = "HP: n/a"
	if _player != null and _player.has_method("get_health"):
		hp_value = float(_player.call("get_health"))
		hp_text = "HP: " + str(hp_value)
	return {"value": hp_value, "text": hp_text}


func _get_ammo_snapshot() -> Dictionary:
	var ammo_text: String = "Ammo: n/a"
	var mag: int = 0
	var reserve: int = 0
	if _weapon != null:
		if _weapon.has_method("get_ammo_in_mag"):
			mag = int(_weapon.call("get_ammo_in_mag"))
		if _weapon.has_method("get_ammo_reserve"):
			reserve = int(_weapon.call("get_ammo_reserve"))
		ammo_text = "Ammo: " + str(mag) + " / " + str(reserve)
	return {"text": ammo_text, "mag": mag, "reserve": reserve}


func _update_weapon_durability_hud() -> void:
	if _weapon != null and _weapon.has_method("get_durability_percent"):
		var durability: float = float(_weapon.call("get_durability_percent"))
		if _hud != null and _hud.has_method("set_durability"):
			_hud.call("set_durability", durability)


func _get_npc_debug_text() -> String:
	var npc_state_text := "n/a"
	if _npc != null and is_instance_valid(_npc) and _npc.has_method("get_state"):
		npc_state_text = str(int(_npc.call("get_state")))

	return "NPC s=" + npc_state_text \
		+ " d=" + str(snappedf(_npc_manager._last_distance_to_player, 0.01)) \
		+ " los=" + str(_npc_manager._last_los_ok) \
		+ " block=" + _npc_manager._last_attack_block_reason


func _apply_hud_snapshot(status_text: String, hp_value: float, mag: int, reserve: int, delta: float) -> void:
	if _hud == null:
		return
	if _hud.has_method("set_status_text"):
		_hud.call("set_status_text", status_text)
	if _hud.has_method("set_hp"):
		_hud.call("set_hp", hp_value)
	if _hud.has_method("set_ammo"):
		_hud.call("set_ammo", mag, reserve)
	if _hud.has_method("tick"):
		_hud.call("tick", delta)


func _update_debug_hud(delta: float) -> void:
	var hp_snapshot: Dictionary = _get_hp_snapshot()
	var hp_text: String = String(hp_snapshot.get("text", "HP: n/a"))
	var hp_value: float = float(hp_snapshot.get("value", 0.0))

	var ammo_snapshot: Dictionary = _get_ammo_snapshot()
	var ammo_text: String = String(ammo_snapshot.get("text", "Ammo: n/a"))
	var mag: int = int(ammo_snapshot.get("mag", 0))
	var reserve: int = int(ammo_snapshot.get("reserve", 0))

	_update_weapon_durability_hud()
	var npc_debug_text: String = _get_npc_debug_text()

	var world_debug_text := "World: n/a"
	var map_overlay_text := ""
	if _debug_overlay_composer != null:
		world_debug_text = _debug_overlay_composer.compose_world_debug_text(_zone_manager, _player, _squad_manager, _alife_manager)
		map_overlay_text = _debug_overlay_composer.compose_map_overlay_text(_map_mode, _squad_manager)

	var view_mode_text := "View: MAP" if _map_mode else "View: FPS"
	var controls_text := "Keys: M map, LMB select/assign, Shift+LMB all squads, Tab cycle squad, C clear goal, RMB/MMB drag, Wheel zoom | F1 menu"

	var status_text: String = hp_text + "\n" + ammo_text + "\n" + view_mode_text + "\n" + npc_debug_text + "\n" + world_debug_text + map_overlay_text + "\nUse gate trigger to switch zone\n" + controls_text
	if _debug_overlay_composer != null:
		status_text = _debug_overlay_composer.compose_status_text(hp_text, ammo_text, view_mode_text, npc_debug_text, world_debug_text, map_overlay_text, controls_text)
	_apply_hud_snapshot(status_text, hp_value, mag, reserve, delta)


func _update_respawn_timers(delta: float) -> void:
	if _respawn_ttl > 0.0:
		_respawn_ttl -= delta
		if _respawn_ttl <= 0.0:
			_try_respawn_player()


func _try_respawn_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	_player.global_position = Vector3(10, 10, 0)
	_player.velocity = Vector3.ZERO

	if _weapon != null and _weapon.has_method("reset_durability"):
		_weapon.call("reset_durability")

	if _player.has_method("heal"):
		_player.call("heal", 100)

	if _weapon != null and _weapon.has_method("set_ammo_counts"):
		_weapon.call("set_ammo_counts", 30, 240)

	_show_event("PLAYER RESPAWNED")


func _show_event(message: String) -> void:
	_log_message(message)
	if _hud != null and _hud.has_method("show_event"):
		_hud.call("show_event", message)


func _log_message(message: String) -> void:
	if message.is_empty():
		return
	_log_lines.append(message)
	if _log_lines.size() > LOG_LINE_LIMIT:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_LINE_LIMIT, _log_lines.size())
	if _log_view != null:
		_log_view.text = "\n".join(_log_lines)
		_log_view.scroll_following = true


func _show_hitmarker() -> void:
	if _hud != null and _hud.has_method("show_hitmarker"):
		_hud.call("show_hitmarker")


func _on_player_died() -> void:
	_show_event("PLAYER DEAD")
	_respawn_ttl = 2.0


func _on_npc_died(p_npc_id: int, p_source_id: int) -> void:
	_log_message("NPC died: %d source: %d" % [p_npc_id, p_source_id])
	_show_event("NPC " + str(p_npc_id) + " down")
	var death_loc_key: String = _resolve_location_key_from_world_pos(_player.global_position if _player != null and is_instance_valid(_player) else Vector3.ZERO)
	_publish_runtime_cause(&"DEATH", death_loc_key, {
		"npc_id": p_npc_id,
		"source_id": p_source_id,
	})
	_npc = null
	_npc_manager.clear_npc()
	_npc_manager.schedule_respawn(3.0)


func _on_npc_spawned(npc: Variant) -> void:
	_npc = npc
	if _npc != null and is_instance_valid(_npc):
		_npc.connect("npc_died", Callable(self, "_on_npc_died"))
	_show_event("NPC RESPAWN")


func _on_weapon_fired(ammo_in_mag: int, reserve: int) -> void:
	if _hud != null and _hud.has_method("set_ammo"):
		_hud.call("set_ammo", ammo_in_mag, reserve)


func _on_weapon_bullet_hit(hit_success: bool, target_id: int, _hit_position: Vector3) -> void:
	if hit_success:
		_show_event("Hit id=" + str(target_id))
		_show_hitmarker()
		var wound_loc_key: String = _resolve_location_key_from_world_pos(_hit_position)
		_publish_runtime_cause(&"WOUND", wound_loc_key, {
			"target_id": target_id,
		})


func _on_squad_arrived(squad_name: String, location_key: String, faction_id: int) -> void:
	_publish_runtime_cause(&"SQUAD_ARRIVE", location_key, {
		"squad_name": squad_name,
		"faction_id": faction_id,
	})


func _publish_runtime_cause(cause_type: StringName, location_key: String, payload: Dictionary = {}) -> void:
	if _alife_manager == null:
		return
	if not _alife_manager.has_method("publish_runtime_cause"):
		return
	if location_key.is_empty():
		return
	_alife_manager.call("publish_runtime_cause", cause_type, location_key, "main", payload)


func _resolve_location_key_from_world_pos(world_pos: Vector3) -> String:
	if _zone_manager == null:
		return ""
	if not _zone_manager.has_method("get_nearest_location"):
		return ""
	var nearest: SmartLocation = _zone_manager.get_nearest_location(world_pos)
	if nearest == null:
		return ""
	if not _zone_manager.has_method("get_location_key_for_graph_id"):
		return ""
	return String(_zone_manager.get_location_key_for_graph_id(nearest.location_id))


func _on_weapon_reloaded(new_mag: int, reserve: int) -> void:
	_show_event("Reloaded")
	if _hud != null and _hud.has_method("set_ammo"):
		_hud.call("set_ammo", new_mag, reserve)


func _on_weapon_durability_changed(percent: float) -> void:
	if _hud != null and _hud.has_method("set_durability"):
		_hud.call("set_durability", percent)


func _on_weapon_jammed() -> void:
	_show_event("WEAPON JAMMED!")


# ---------------------------------------------------------------------------
# Gate beacon for mode 3
# ---------------------------------------------------------------------------

func _spawn_gate_beacon(from_zone_id: StringName, to_zone_id: StringName, pos: Vector3) -> void:
	var beacon := Node3D.new()
	beacon.name = "GateBeacon"
	beacon.position = pos
	add_child(beacon)
	_gate_beacon = beacon

	var accent := _zone_accent_color(to_zone_id)

	var pillar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 5.0, 0.5)
	pillar.mesh = box
	pillar.position = Vector3(0, 2.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 3.0
	pillar.material_override = mat
	beacon.add_child(pillar)

	var zone_label := Label3D.new()
	zone_label.text = "BRAMA EDGE\n%s -> %s\n%s" % [
		_zone_display_name(from_zone_id),
		_zone_display_name(to_zone_id),
		"[TRANSITION]" if String(to_zone_id).begins_with("zone_t_") else "[REGION]",
	]
	zone_label.position = Vector3(0, 6.2, 0)
	zone_label.modulate = accent
	zone_label.font_size = 52
	zone_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.add_child(zone_label)


func _zone_display_name(zone_id: StringName) -> String:
	match zone_id:
		&"zone_a":
			return "Region A"
		&"zone_t_ab":
			return "Przejscie A-B"
		&"zone_b":
			return "Region B"
		&"zone_t_bc":
			return "Przejscie B-C"
		&"zone_c":
			return "Region C"
		_:
			return String(zone_id)


func _zone_accent_color(zone_id: StringName) -> Color:
	match zone_id:
		&"zone_a":
			return Color(0.86, 0.80, 0.30)
		&"zone_t_ab":
			return Color(0.32, 0.86, 0.96)
		&"zone_b":
			return Color(0.95, 0.54, 0.22)
		&"zone_t_bc":
			return Color(0.36, 0.68, 0.98)
		&"zone_c":
			return Color(0.82, 0.50, 0.92)
		_:
			return Color(1.0, 0.85, 0.2)


# ---------------------------------------------------------------------------
# Teardown world (called before returning to menu via F1)
# ---------------------------------------------------------------------------

func _teardown_world() -> void:
	# Managers / overlays that are direct children of self
	for node: Variant in [_world_debug, _squad_manager, _alife_manager,
			_transition_manager, _attachment_manager, _hud, _map_command_controller]:
		if node != null and is_instance_valid(node):
			node.queue_free()

	# Named nodes added to self by spawner / setup
	for node_name: String in ["Sun", "WorldEnvironment", "FloorZoneA", "FloorZoneTAB", "FloorZoneB", "FloorZoneTBC", "FloorZoneC", "NavRegion",
			"MapCamera", "GateBeacon", "TransitionGuide"]:
		var n: Node = get_node_or_null(node_name)
		if n != null:
			n.queue_free()

	# Player and NPC are children of scene root (added via get_tree().get_root())
	var root: Window = get_tree().get_root()
	for node_name: String in ["PlayerController", "TestNPC"]:
		var n: Node = root.get_node_or_null(node_name)
		if n != null:
			n.queue_free()

	_player = null
	_weapon = null
	_npc = null
	_hud = null
	_test_enemy_npc = null
	_test_enemy_squad = null
	_test_enemy_last_health = -1.0
	_map_camera = null
	_world_debug = null
	_squad_manager = null
	_attachment_manager = null
	_alife_manager = null
	_transition_manager = null
	_map_command_controller = null
	_debug_overlay_composer = null
	_gate_beacon = null
	_transition_commit_trigger = null
	_transition_target_zone = &""
	_transition_from_gate_id = -1
	_debug_mode = DebugMode.NONE
	_map_mode = false
	_respawn_ttl = -1.0
	_zone_transition_cooldown = 0.0
	if _zone_manager != null:
		_zone_manager.call("_load_zone", &"zone_a")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_zone_transition_started(from_id: StringName, to_id: StringName) -> void:
	_show_event("Zone transition: %s -> %s" % [String(from_id), String(to_id)])
	_play_zone_flash()


func _on_zone_transition_preloaded(from_id: StringName, to_id: StringName) -> void:
	_show_event("Loaded next region: %s + %s" % [String(from_id), String(to_id)])
	_sync_loaded_zone_visuals()
	if _world_debug != null:
		_world_debug.rebuild()
	_spawn_transition_guide(from_id, to_id)
	_show_event("Przejście aktywne: idź do strefy docelowej")


func _play_zone_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.9, 0.95, 1.0, 0.85)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_callback(layer.queue_free)


func _on_zone_transition_finished(_from_id: StringName, to_id: StringName) -> void:
	_clear_transition_guide()
	_sync_loaded_zone_visuals()
	if _world_debug != null:
		_world_debug.rebuild()
	if _squad_manager != null:
		_squad_manager.rebuild()
	if _debug_mode == DebugMode.ZONE_TRANSITIONS:
		if _gate_beacon != null and is_instance_valid(_gate_beacon):
			_gate_beacon.queue_free()
			_gate_beacon = null
		var next_target: StringName = _zone_manager.get_gate_target_zone(to_id)
		var beacon_pos: Vector3 = _zone_manager.get_transition_gate_position(to_id, next_target)
		if beacon_pos == Vector3.ZERO:
			beacon_pos = _zone_manager.get_transition_gate_position(to_id, _from_id)
		_spawn_gate_beacon(to_id, next_target, beacon_pos)
		_show_event("Jesteś w: " + _zone_display_name(to_id))
		_show_event("Następny cel: " + _zone_display_name(next_target))
		_show_event(">> Idź do SŁUPA [EDGE] <<")


func _on_zone_gate_entered(body: Node3D, target_zone_id: StringName, from_location_id: int) -> void:
	if _zone_manager == null:
		return
	if _zone_transition_cooldown > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if body == null:
		return
	if body != _player and not _player.is_ancestor_of(body):
		return
	if _zone_manager.get_current_zone_id() == target_zone_id or _zone_manager.is_transitioning():
		return

	_transition_from_gate_id = from_location_id
	_zone_transition_cooldown = 0.75
	_zone_manager.request_zone_transition(target_zone_id)


func _on_transition_commit_entered(body: Node3D) -> void:
	if body != _player:
		return
	if _zone_manager == null or not _zone_manager.is_transitioning():
		return
	if _transition_target_zone == &"":
		return
	if _zone_manager.get_current_zone_id() == _transition_target_zone:
		return
	_show_event("Wejście do regionu: " + String(_transition_target_zone))
	_zone_manager.commit_zone_transition()


func _sync_loaded_zone_visuals() -> void:
	if _spawner == null or _zone_manager == null:
		return
	_spawner.set_zone_lods(self, _zone_manager.get_zone_lod_map())


func _set_player_input_enabled(enabled: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("set_input_enabled"):
		_player.call("set_input_enabled", enabled)


func _spawn_transition_guide(from_zone_id: StringName, to_zone_id: StringName) -> void:
	_clear_transition_guide()
	_transition_target_zone = to_zone_id

	var from_pos: Vector3 = _zone_manager.get_transition_gate_position(from_zone_id, to_zone_id, _transition_from_gate_id)
	var to_pos: Vector3 = _zone_manager.get_transition_gate_position(to_zone_id, from_zone_id)
	if from_pos == Vector3.ZERO:
		from_pos = _zone_manager.get_transition_gate_position(from_zone_id, to_zone_id)
	if to_pos == Vector3.ZERO:
		to_pos = from_pos + Vector3(4, 0, 0)

	var guide := Node3D.new()
	guide.name = "TransitionGuide"
	add_child(guide)

	# Corridor line between gates to visualize overlap traversal.
	var delta := to_pos - from_pos
	var distance := delta.length()
	if distance > 0.05:
		var corridor := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.4
		mesh.bottom_radius = 1.4
		mesh.height = distance
		corridor.mesh = mesh
		corridor.position = from_pos + delta * 0.5 + Vector3(0, 1.0, 0)
		corridor.look_at_from_position(corridor.position, to_pos + Vector3(0, 1.0, 0), Vector3.UP)
		corridor.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.8, 1.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.8, 1.0)
		mat.emission_energy_multiplier = 1.8
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		corridor.material_override = mat
		guide.add_child(corridor)

		# Bright transition band at midpoint so region change area is obvious.
		var transition_band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 4.4
		band_mesh.bottom_radius = 4.4
		band_mesh.height = 0.45
		transition_band.mesh = band_mesh
		transition_band.position = from_pos + delta * 0.5 + Vector3(0, 0.95, 0)
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color(0.15, 0.95, 1.0, 0.55)
		band_mat.emission_enabled = true
		band_mat.emission = Color(0.15, 0.95, 1.0)
		band_mat.emission_energy_multiplier = 3.0
		band_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		transition_band.material_override = band_mat
		guide.add_child(transition_band)

		var transition_beacon := MeshInstance3D.new()
		var beacon_mesh := CylinderMesh.new()
		beacon_mesh.top_radius = 0.7
		beacon_mesh.bottom_radius = 0.7
		beacon_mesh.height = 8.0
		transition_beacon.mesh = beacon_mesh
		transition_beacon.position = from_pos + delta * 0.5 + Vector3(0, 4.0, 0)
		var beacon_mat := StandardMaterial3D.new()
		beacon_mat.albedo_color = Color(0.2, 1.0, 1.0, 0.35)
		beacon_mat.emission_enabled = true
		beacon_mat.emission = Color(0.2, 1.0, 1.0)
		beacon_mat.emission_energy_multiplier = 3.5
		beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		transition_beacon.material_override = beacon_mat
		guide.add_child(transition_beacon)

	var commit_area := Area3D.new()
	commit_area.name = "TransitionCommitTrigger"
	commit_area.position = to_pos + Vector3(0, 0.85, 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 3.2
	capsule.height = 3.8
	shape.shape = capsule
	commit_area.add_child(shape)
	commit_area.body_entered.connect(_on_transition_commit_entered)
	guide.add_child(commit_area)
	_transition_commit_trigger = commit_area

	var label := Label3D.new()
	label.text = "WEJSCIE REGIONU\n" + String(to_zone_id)
	label.position = to_pos + Vector3(0, 3.1, 0)
	label.modulate = Color(0.35, 0.85, 1.0, 0.98)
	label.font_size = 44
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide.add_child(label)


func _clear_transition_guide() -> void:
	if _transition_commit_trigger != null and is_instance_valid(_transition_commit_trigger):
		_transition_commit_trigger = null
	var guide := get_node_or_null("TransitionGuide")
	if guide != null:
		guide.queue_free()
	_transition_target_zone = &""
	_transition_from_gate_id = -1
