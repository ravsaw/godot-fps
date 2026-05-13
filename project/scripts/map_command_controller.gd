extends Node
class_name MapCommandController

var _zone_manager: Variant = null
var _squad_manager: Variant = null
var _map_camera: Camera3D = null
var _show_event: Callable
var _map_dragging: bool = false

var _map_zoom_step: float = 6.0
var _map_min_size: float = 20.0
var _map_max_size: float = 140.0


func setup(map_camera: Camera3D, zone_manager: Variant, squad_manager: Variant, show_event: Callable, zoom_step: float, min_size: float, max_size: float) -> void:
	_map_camera = map_camera
	_zone_manager = zone_manager
	_squad_manager = squad_manager
	_show_event = show_event
	_map_zoom_step = zoom_step
	_map_min_size = min_size
	_map_max_size = max_size


func update_context(zone_manager: Variant, squad_manager: Variant) -> void:
	_zone_manager = zone_manager
	_squad_manager = squad_manager


func set_map_enabled(enabled: bool) -> void:
	if not enabled:
		_map_dragging = false


func handle_input(event: InputEvent) -> bool:
	if _map_camera == null or not is_instance_valid(_map_camera):
		return false

	if event is InputEventMouseMotion and _map_dragging:
		_pan_map_camera(event.relative)
		return true

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_issue_map_move_order(event.position, event.shift_pressed)
		return true

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_map_dragging = event.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_map_zoom(_map_camera.size - _map_zoom_step)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_map_zoom(_map_camera.size + _map_zoom_step)
				return true

	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	match event.keycode:
		KEY_TAB:
			if _squad_manager != null:
				var next_name: String = String(_squad_manager.issue_select_next_squad())
				if not next_name.is_empty():
					_emit_event("Selected squad: " + next_name)
			return true
		KEY_C:
			if _squad_manager != null:
				if Input.is_key_pressed(KEY_SHIFT):
					if _squad_manager.issue_clear_all_goals():
						_emit_event("Cleared goals for all squads")
				else:
					var selected: String = _squad_manager.query_selected_squad()
					if not selected.is_empty() and _squad_manager.issue_clear_goal(selected):
						_emit_event("Cleared selected squad goal")
			return true

	return false


func _emit_event(message: String) -> void:
	if _show_event.is_valid():
		_show_event.call(message)


func _set_map_zoom(new_size: float) -> void:
	if _map_camera == null or not is_instance_valid(_map_camera):
		return
	_map_camera.size = clampf(new_size, _map_min_size, _map_max_size)


func _pan_map_camera(relative: Vector2) -> void:
	if _map_camera == null or not is_instance_valid(_map_camera):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var units_per_pixel: float = _map_camera.size / viewport_size.y
	_map_camera.position.x -= relative.x * units_per_pixel
	_map_camera.position.z -= relative.y * units_per_pixel


func _try_issue_map_move_order(screen_pos: Vector2, all_squads: bool = false) -> void:
	if _map_camera == null or not is_instance_valid(_map_camera):
		return
	if _zone_manager == null or _squad_manager == null:
		return

	var ray_origin: Vector3 = _map_camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _map_camera.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.0001:
		return

	var distance_to_ground: float = -ray_origin.y / ray_dir.y
	if distance_to_ground < 0.0:
		return
	var world_pos: Vector3 = ray_origin + ray_dir * distance_to_ground

	var squad_name: String = String(_squad_manager.query_squad_near(world_pos))
	if not squad_name.is_empty():
		if _squad_manager.issue_select_squad(squad_name):
			_emit_event("Selected squad: " + squad_name)
		return

	var nearest: SmartLocation = _zone_manager.get_nearest_location(world_pos)
	if nearest == null:
		return
	if nearest.world_position.distance_to(world_pos) > 4.5:
		_emit_event("Kliknij bliżej znacznika lokacji")
		return
	var location_key: String = String(_zone_manager.get_location_key_for_graph_id(nearest.location_id))
	if location_key.is_empty():
		return

	if all_squads:
		if _squad_manager.issue_move_all_squads(location_key):
			_emit_event("All squads moving to %s" % location_key)
		return

	var selected_squad: String = String(_squad_manager.query_selected_squad())
	if selected_squad.is_empty():
		_emit_event("Najpierw wybierz squad klikając jego znacznik")
		return

	if _squad_manager.issue_move_squad(selected_squad, location_key):
		_emit_event("%s moving to %s" % [selected_squad, location_key])
