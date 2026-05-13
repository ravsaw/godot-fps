extends Node
class_name SquadManager

signal squad_event(message: String)
signal squad_arrived(squad_name: String, location_key: String, faction_id: int)

var _zone_manager: Variant = null
var _scene_root: Node3D = null
var _squads: Array[SquadData] = []
var _visuals: Dictionary = {}
var _forced_next_target_by_name: Dictionary = {}
var _root: Node3D = null
var _sim_ttl_by_name: Dictionary = {}
var _selected_squad_name: String = ""
var _selection_marker: MeshInstance3D = null
var _goal_marker: MeshInstance3D = null
var _route_root: Node3D = null

const MIN_SQUAD_NPC_COUNT: int = 3
const MAX_SQUAD_NPC_COUNT: int = 5
const FORMATION_SPACING: float = 1.0

const FULL_SIM_INTERVAL: float = 0.0
const ADJACENT_SIM_INTERVAL: float = 0.15
const FAR_SIM_INTERVAL: float = 0.55



func _find_squad(squad_name: String) -> SquadData:
	for s in _squads:
		if s.squad_name == squad_name:
			return s
	return null


# ===== PUBLIC COMMAND API (UI/Debug Layer) =====

func issue_move_squad(squad_name: String, location_key: String) -> bool:
	"""Public command: move single squad to location by key (e.g. 'zone_a:5')."""
	log_command("move_squad", "%s -> %s" % [squad_name, location_key])
	return request_move_squad_to_location_key(squad_name, location_key)


func issue_move_all_squads(location_key: String) -> bool:
	"""Public command: move all squads to location by key."""
	log_command("move_all_squads", "-> %s" % location_key)
	return request_move_all_squads_to_location_key(location_key)


func issue_select_squad(squad_name: String) -> bool:
	"""Public command: select squad by name."""
	log_command("select_squad", squad_name)
	return select_squad(squad_name)


func issue_select_next_squad(step: int = 1) -> String:
	"""Public command: cycle to next squad in list."""
	log_command("select_next_squad", "step=%d" % step)
	return select_next_squad(step)


func issue_clear_goal(squad_name: String) -> bool:
	"""Public command: clear goal for specific squad."""
	log_command("clear_goal", squad_name)
	for squad in _squads:
		if squad.squad_name != squad_name:
			continue
		var had := squad.get_goal_stack_size() > 0
		squad.clear_goal()
		_refresh_selection_overlay()
		return had
	return false


func issue_clear_all_goals() -> bool:
	"""Public command: clear all squad goals."""
	var count := 0
	for s in _squads:
		if s.get_goal_stack_size() > 0:
			count += 1
	log_command("clear_all_goals", "count=%d" % count)
	return request_clear_all_squad_goals()


func query_selected_squad() -> String:
	"""Public query: name of currently selected squad."""
	return get_selected_squad_name()


func query_squad_near(world_pos: Vector3, max_distance: float = 3.5) -> String:
	"""Public query: find squad near position (for click-based selection)."""
	return get_nearest_squad_name(world_pos, max_distance)


func log_command(command: String, details: String = "") -> void:
	"""Telemetry: log player command for debugging."""
	var log_msg := "SquadCmd: %s" % command
	if not details.is_empty():
		log_msg += " [%s]" % details
	print_debug(log_msg)


func setup(zone_manager: Variant, scene_root: Node3D) -> void:
	_zone_manager = zone_manager
	_scene_root = scene_root
	_rebuild()


func rebuild() -> void:
	_rebuild()


func get_selected_squad_name() -> String:
	return _selected_squad_name


func select_next_squad(step: int = 1) -> String:
	if _squads.is_empty():
		_selected_squad_name = ""
		_refresh_selection_overlay()
		return ""

	var current_index := -1
	for i in range(_squads.size()):
		if _squads[i].squad_name == _selected_squad_name:
			current_index = i
			break

	if current_index < 0:
		current_index = 0
	else:
		current_index = posmod(current_index + step, _squads.size())

	_selected_squad_name = _squads[current_index].squad_name
	_refresh_selection_overlay()
	return _selected_squad_name


func select_squad(squad_name: String) -> bool:
	for squad in _squads:
		if squad.squad_name != squad_name:
			continue
		_selected_squad_name = squad_name
		_refresh_selection_overlay()
		return true
	return false


func get_nearest_squad_name(world_pos: Vector3, max_distance: float = 3.5) -> String:
	var best_name := ""
	var best_dist := max_distance
	for info in get_snapshot():
		var squad_name: String = String(info.get("name", ""))
		var pos: Vector3 = info.get("position", Vector3.ZERO)
		var dist := world_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_name = squad_name
	return best_name


func get_status_text() -> String:
	if _squads.is_empty():
		return "Squads: n/a"
	var parts: Array[String] = []
	for squad in _squads:
		var part := String(squad.get_status_text())
		var goal_id := squad.get_active_goal()
		if goal_id >= 0:
			var stack_size: int = squad.get_goal_stack_size()
			if stack_size > 1:
				part += " -> goal:%s (+%d queued)" % [_format_location_ref(goal_id), stack_size - 1]
			else:
				part += " -> goal:%s" % _format_location_ref(goal_id)
		parts.append(part)
	return "Squads: " + ", ".join(parts)


func get_map_debug_text() -> String:
	if _squads.is_empty():
		return "MapCmd: no squads"

	if _selected_squad_name.is_empty():
		return "MapCmd: selected=none"

	var selected_info := _get_snapshot_by_name(_selected_squad_name)
	if selected_info.is_empty():
		return "MapCmd: selected=%s (snapshot missing)" % _selected_squad_name

	var current_id := int(selected_info.get("current_location_id", -1))
	var target_id := int(selected_info.get("target_location_id", -1))
	var _sel_squad := _find_squad(_selected_squad_name)
	var goal_id := _sel_squad.get_active_goal() if _sel_squad != null else -1
	var state_text := "moving" if int(selected_info.get("squad_state", 0)) == SquadData.STATE_MOVING else "rest"
	var current_ref := _format_location_ref(current_id)
	var target_ref := _format_location_ref(target_id)

	if goal_id >= 0:
		var stack_size: int = _sel_squad.get_goal_stack_size() if _sel_squad != null else 0
		var goal_ref := _format_location_ref(goal_id)
		if stack_size > 1:
			goal_ref += "(+%d)" % (stack_size - 1)
		return "MapCmd: [%s] %s | cur=%s next=%s goal=%s" % [_selected_squad_name, state_text, current_ref, target_ref, goal_ref]
	return "MapCmd: [%s] %s | cur=%s next=%s goal=none" % [_selected_squad_name, state_text, current_ref, target_ref]


func get_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for squad in _squads:
		var t: float = 0.0
		if squad.squad_state == SquadData.STATE_MOVING:
			t = clampf(float(squad.travel_elapsed) / maxf(0.01, float(squad.travel_duration)), 0.0, 1.0)
		var pos: Vector3 = squad.from_position.lerp(squad.to_position, t)
		snapshot.append({
			"name": squad.squad_name,
			"faction_id": squad.faction_id,
			"home_location_id": squad.home_location_id,
			"squad_state": squad.squad_state,
			"current_location_id": squad.current_location_id,
			"target_location_id": squad.target_location_id,
			"npc_count": squad.npc_count,
			"position": pos,
		})
	return snapshot


func request_return_home_for_squad(squad_name: String) -> bool:
	if _zone_manager == null:
		return false

	for squad in _squads:
		if squad.squad_name != squad_name:
			continue
		if squad.current_location_id == squad.home_location_id:
			return false
		squad.push_low_priority_goal(squad.home_location_id)
		if squad.squad_state != SquadData.STATE_MOVING:
			_begin_move(squad)
		return true

	return false


func request_move_all_squads_to_location(goal_location_id: int) -> bool:
	if _zone_manager == null:
		return false
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null or world_graph.get_location(goal_location_id) == null:
		return false

	var changed := false
	for squad in _squads:
		squad.set_explicit_goal(goal_location_id)
		if squad.squad_state != SquadData.STATE_MOVING:
			_begin_move(squad)
		changed = true
	return changed


func request_move_all_squads_to_location_key(goal_location_key: String) -> bool:
	var goal_location_id := _resolve_goal_location_id(goal_location_key)
	if goal_location_id < 0:
		return false
	return request_move_all_squads_to_location(goal_location_id)


func request_move_selected_squad_to_location(goal_location_id: int) -> bool:
	if _selected_squad_name.is_empty():
		return false
	return request_move_squad_to_location(_selected_squad_name, goal_location_id)


func request_move_selected_squad_to_location_key(goal_location_key: String) -> bool:
	if _selected_squad_name.is_empty():
		return false
	return request_move_squad_to_location_key(_selected_squad_name, goal_location_key)


func request_clear_selected_squad_goal() -> bool:
	if _selected_squad_name.is_empty():
		return false
	var sel := _find_squad(_selected_squad_name)
	if sel == null:
		return false
	var had := sel.get_goal_stack_size() > 0
	sel.clear_goal()
	_refresh_selection_overlay()
	return had


func request_clear_all_squad_goals() -> bool:
	var had_goals := false
	for s in _squads:
		if s.get_goal_stack_size() > 0:
			had_goals = true
			s.clear_goal()
	if not had_goals:
		return false
	_refresh_selection_overlay()
	return true


func request_move_squad_to_location(squad_name: String, goal_location_id: int) -> bool:
	if _zone_manager == null:
		return false
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null or world_graph.get_location(goal_location_id) == null:
		return false

	for squad in _squads:
		if squad.squad_name != squad_name:
			continue
		squad.set_explicit_goal(goal_location_id)
		if squad.squad_state != SquadData.STATE_MOVING:
			_begin_move(squad)
		_refresh_selection_overlay()
		return true
	return false


func request_move_squad_to_location_key(squad_name: String, goal_location_key: String) -> bool:
	var goal_location_id := _resolve_goal_location_id(goal_location_key)
	if goal_location_id < 0:
		return false
	return request_move_squad_to_location(squad_name, goal_location_id)


func _process(delta: float) -> void:
	var lod_by_zone: Dictionary = {}
	if _zone_manager != null and _zone_manager.has_method("get_zone_lod_map"):
		lod_by_zone = _zone_manager.get_zone_lod_map()
	for squad in _squads:
		var tick_interval := _get_sim_interval_for_squad(squad, lod_by_zone)
		if tick_interval <= 0.0:
			_tick_squad(squad, delta)
			continue

		var ttl_key := squad.squad_name
		var ttl: float = float(_sim_ttl_by_name.get(ttl_key, tick_interval)) - delta
		if ttl > 0.0:
			_sim_ttl_by_name[ttl_key] = ttl
			continue
		_sim_ttl_by_name[ttl_key] = tick_interval
		_tick_squad(squad, tick_interval)
	_refresh_selection_overlay()


func _rebuild() -> void:
	_squads.clear()
	_visuals.clear()
	_sim_ttl_by_name.clear()
	_selected_squad_name = ""
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_selection_marker = null
	_goal_marker = null
	_route_root = null

	if _zone_manager == null or _scene_root == null:
		return

	_root = Node3D.new()
	_root.name = "DebugSquads"
	_scene_root.add_child(_root)
	_route_root = Node3D.new()
	_route_root.name = "SquadRoutes"
	_root.add_child(_route_root)

	var scav_start: int = int(_zone_manager.get_graph_location_id(&"zone_a", 1))
	var threshold_start: int = int(_zone_manager.get_graph_location_id(&"zone_a", 5))
	_squads.append(_create_squad("Scav Patrol", 1, scav_start, Color(0.35, 0.95, 0.35)))
	_squads.append(_create_squad("Threshold Patrol", 2, threshold_start, Color(1.0, 0.45, 0.25)))
	if not _squads.is_empty():
		_selected_squad_name = _squads[0].squad_name

	for squad in _squads:
		_begin_move(squad)
	_refresh_selection_overlay()


func _create_squad(squad_name: String, faction_id: int, start_location_id: int, color: Color) -> SquadData:
	var squad := SquadData.new()
	squad.squad_name = squad_name
	squad.faction_id = faction_id
	squad.npc_count = randi_range(MIN_SQUAD_NPC_COUNT, MAX_SQUAD_NPC_COUNT)
	squad.current_location_id = start_location_id
	squad.home_location_id = start_location_id
	squad.squad_state = SquadData.STATE_IDLE
	squad.target_location_id = -1
	squad.travel_elapsed = 0.0
	squad.travel_duration = 1.0
	squad.route_step = 0
	squad.from_position = Vector3.ZERO
	squad.to_position = Vector3.ZERO

	var visuals := _create_squad_visuals(squad_name, color, int(squad.npc_count))
	_root.add_child(visuals.get("leader", null))
	for member_node in visuals.get("members", []):
		_root.add_child(member_node)

	var label := Label3D.new()
	label.text = squad_name
	label.modulate = Color(1, 1, 1, 0.95)
	_root.add_child(label)

	visuals["label"] = label
	visuals["npc_count"] = int(squad.npc_count)
	_visuals[squad_name] = visuals
	return squad


func _create_squad_visuals(squad_name: String, color: Color, npc_count: int) -> Dictionary:
	var leader := MeshInstance3D.new()
	leader.name = squad_name.replace(" ", "")
	var leader_mesh := CapsuleMesh.new()
	leader_mesh.radius = 0.24
	leader_mesh.height = 0.52
	leader.mesh = leader_mesh

	var leader_mat := StandardMaterial3D.new()
	leader_mat.albedo_color = color
	leader_mat.emission = color * 0.18
	leader.material_override = leader_mat

	var member_nodes: Array[Node3D] = []
	for i in range(max(1, npc_count) - 1):
		var member := MeshInstance3D.new()
		member.name = "%s_Member%d" % [squad_name.replace(" ", ""), i + 1]
		var member_mesh := CapsuleMesh.new()
		member_mesh.radius = 0.18
		member_mesh.height = 0.42
		member.mesh = member_mesh

		var member_mat := StandardMaterial3D.new()
		member_mat.albedo_color = color.lerp(Color.WHITE, 0.2)
		member_mat.emission = color * 0.08
		member.material_override = member_mat
		member_nodes.append(member)

	return {"leader": leader, "members": member_nodes}


func _begin_move(squad: SquadData) -> void:
	if _zone_manager == null:
		return
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		return

	var current_id: int = squad.current_location_id
	var current_loc: Variant = world_graph.get_location(current_id)
	if current_loc == null:
		return

	var neighbors: PackedInt32Array = world_graph.get_neighbors(current_id)
	if neighbors.is_empty():
		squad.squad_state = SquadData.STATE_RESTING
		squad.target_location_id = -1
		return

	var target_id: int = -1
	var goal_id: int = squad.get_active_goal()
	if goal_id >= 0:
		if current_id == goal_id:
			var next_goal := squad.pop_goal_and_get_next()
			if next_goal >= 0:
				# Chain to next goal in stack without resting.
				goal_id = next_goal
			else:
				squad.squad_state = SquadData.STATE_RESTING
				squad.target_location_id = -1
				return
		var next_hop := _find_next_hop_towards(world_graph, current_id, goal_id)
		if next_hop >= 0 and neighbors.has(next_hop):
			target_id = next_hop
		else:
			# No path to goal — pop it to avoid infinite stall, fall through to wander.
			push_warning("SquadManager: no path from %s to goal %s for squad '%s', dropping goal" % [
				_format_location_ref(current_id), _format_location_ref(goal_id), squad.squad_name])
			squad.pop_goal_and_get_next()

	if target_id < 0:
		var forced_target_id: int = int(_forced_next_target_by_name.get(squad.squad_name, -1))
		if forced_target_id >= 0 and neighbors.has(forced_target_id):
			target_id = forced_target_id
			_forced_next_target_by_name.erase(squad.squad_name)

	if target_id < 0:
		var next_index: int = posmod(squad.route_step, neighbors.size())
		target_id = int(neighbors[next_index])
	var target_loc: Variant = world_graph.get_location(target_id)
	if target_loc == null:
		return

	var edge_dist: float = float(world_graph.get_connection_distance(current_id, target_id))
	squad.target_location_id = target_id
	squad.squad_state = SquadData.STATE_MOVING
	squad.travel_elapsed = 0.0
	squad.travel_duration = maxf(1.1, edge_dist / 3.2)
	squad.route_step = squad.route_step + 1
	squad.from_position = current_loc.world_position + Vector3(0, 0.45, 0)
	squad.to_position = target_loc.world_position + Vector3(0, 0.45, 0)

	var vis: Dictionary = _visuals.get(squad.squad_name, {})
	var squad_node: Node3D = vis.get("leader", null)
	var label: Label3D = vis.get("label", null)
	if squad_node != null:
		_update_squad_formation_visuals(squad, vis)
	if label != null:
		label.position = squad.from_position + Vector3(0, 0.7, 0)
		label.text = "%s\n%s -> %s" % [squad.squad_name, _format_location_ref(current_id), _format_location_ref(target_id)]
	_refresh_selection_overlay()


func _tick_squad(squad: SquadData, delta: float) -> void:
	var vis: Dictionary = _visuals.get(squad.squad_name, {})
	var squad_node: Node3D = vis.get("leader", null)
	var label: Label3D = vis.get("label", null)
	if squad_node == null or label == null or not is_instance_valid(squad_node) or not is_instance_valid(label):
		return

	var target_id: int = squad.target_location_id
	if target_id < 0:
		_begin_move(squad)
		return

	# Call C++ movement tick
	squad.tick_movement(delta)

	# Update visuals from C++ computed position
	_update_squad_formation_visuals(squad, vis)
	label.position = squad.get_computed_position() + Vector3(0, 0.7, 0)

	# Check if arrived (computed in C++)
	if squad.get_arrived_this_frame():
		squad.current_location_id = target_id
		squad.squad_state = SquadData.STATE_RESTING
		squad.target_location_id = -1
		var faction_name := ""
		if _zone_manager != null:
			faction_name = _zone_manager.get_faction_name(squad.faction_id)
		label.text = "%s\nAt %s" % [squad.squad_name, _format_location_ref(target_id)]
		emit_signal("squad_arrived", squad.squad_name, _format_location_ref(target_id), squad.faction_id)
		if faction_name != "":
			emit_signal("squad_event", "%s reached loc %s" % [faction_name, _format_location_ref(target_id)])
	else:
		var t: float = maxf(0.0, float(squad.travel_elapsed) / maxf(0.01, float(squad.travel_duration)))
		label.text = "%s\nMoving %.0f%%" % [squad.squad_name, clampf(t, 0.0, 1.0) * 100.0]


func _update_squad_formation_visuals(squad: SquadData, vis: Dictionary) -> void:
	var leader: Node3D = vis.get("leader", null)
	if leader == null or not is_instance_valid(leader):
		return

	var members: Array = vis.get("members", [])

	# Call C++ to compute formation positions
	squad.compute_formation_positions()
	var positions: Array[Vector3] = squad.get_formation_positions()

	# Place leader at position[0]
	if positions.size() > 0:
		leader.position = positions[0]

	# Place members at positions[1..]
	for i in range(min(members.size(), positions.size() - 1)):
		var member_node: Node3D = members[i]
		if member_node == null or not is_instance_valid(member_node):
			continue
		member_node.position = positions[i + 1]



func _find_next_hop_towards(world_graph: Variant, from_location_id: int, goal_location_id: int) -> int:
	if from_location_id == goal_location_id:
		return from_location_id

	var path_ids: PackedInt32Array = world_graph.get_shortest_path(from_location_id, goal_location_id)
	if path_ids.size() < 2:
		return -1
	return int(path_ids[1])


func _get_sim_interval_for_squad(squad: SquadData, lod_by_zone: Dictionary) -> float:
	if _zone_manager == null:
		return FAR_SIM_INTERVAL
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		return FAR_SIM_INTERVAL

	var ref_location_id := squad.current_location_id
	if squad.squad_state == SquadData.STATE_MOVING and squad.target_location_id >= 0:
		ref_location_id = squad.target_location_id

	var loc: SmartLocation = world_graph.get_location(ref_location_id)
	if loc == null:
		return FAR_SIM_INTERVAL

	var lod_level := int(lod_by_zone.get(loc.zone_id, 0))
	if lod_level >= 2:
		return FULL_SIM_INTERVAL
	if lod_level == 1:
		return ADJACENT_SIM_INTERVAL
	return FAR_SIM_INTERVAL


func _refresh_selection_overlay() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_ensure_selection_visuals()
	if _selected_squad_name.is_empty():
		_selection_marker.visible = false
		_goal_marker.visible = false
		_clear_route_visuals()
		return

	var selected_info := _get_snapshot_by_name(_selected_squad_name)
	if selected_info.is_empty():
		_selection_marker.visible = false
		_goal_marker.visible = false
		_clear_route_visuals()
		return

	var squad_pos: Vector3 = selected_info.get("position", Vector3.ZERO)
	_selection_marker.visible = true
	_selection_marker.position = squad_pos + Vector3(0, 0.06, 0)

	var _sel_s := _find_squad(_selected_squad_name)
	var goal_id := _sel_s.get_active_goal() if _sel_s != null else -1
	if goal_id < 0 or _zone_manager == null:
		_goal_marker.visible = false
		_clear_route_visuals()
		return

	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		_goal_marker.visible = false
		_clear_route_visuals()
		return

	var goal_loc: SmartLocation = world_graph.get_location(goal_id)
	if goal_loc == null:
		_goal_marker.visible = false
		_clear_route_visuals()
		return

	_goal_marker.visible = true
	_goal_marker.position = goal_loc.world_position + Vector3(0, 1.4, 0)
	_redraw_route_visuals(selected_info, world_graph, goal_id)


func _ensure_selection_visuals() -> void:
	if _selection_marker == null or not is_instance_valid(_selection_marker):
		_selection_marker = MeshInstance3D.new()
		_selection_marker.name = "SelectedSquadMarker"
		var selection_mesh := CylinderMesh.new()
		selection_mesh.top_radius = 0.7
		selection_mesh.bottom_radius = 0.7
		selection_mesh.height = 0.12
		_selection_marker.mesh = selection_mesh
		var selection_mat := StandardMaterial3D.new()
		selection_mat.albedo_color = Color(1.0, 1.0, 0.25, 0.85)
		selection_mat.emission_enabled = true
		selection_mat.emission = Color(1.0, 1.0, 0.25)
		selection_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_selection_marker.material_override = selection_mat
		_root.add_child(_selection_marker)

	if _goal_marker == null or not is_instance_valid(_goal_marker):
		_goal_marker = MeshInstance3D.new()
		_goal_marker.name = "SelectedSquadGoalMarker"
		var goal_mesh := SphereMesh.new()
		goal_mesh.radius = 0.45
		goal_mesh.height = 0.9
		_goal_marker.mesh = goal_mesh
		var goal_mat := StandardMaterial3D.new()
		goal_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.9)
		goal_mat.emission_enabled = true
		goal_mat.emission = Color(1.0, 0.55, 0.2)
		goal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_goal_marker.material_override = goal_mat
		_root.add_child(_goal_marker)


func _get_snapshot_by_name(squad_name: String) -> Dictionary:
	for info in get_snapshot():
		if String(info.get("name", "")) == squad_name:
			return info
	return {}


func _clear_route_visuals() -> void:
	if _route_root == null or not is_instance_valid(_route_root):
		return
	for child in _route_root.get_children():
		child.queue_free()


func _redraw_route_visuals(selected_info: Dictionary, world_graph: Variant, goal_id: int) -> void:
	_clear_route_visuals()
	if _route_root == null or not is_instance_valid(_route_root):
		return

	var current_id := int(selected_info.get("current_location_id", -1))
	var target_id := int(selected_info.get("target_location_id", -1))
	var squad_pos: Vector3 = selected_info.get("position", Vector3.ZERO)
	var path_ids: PackedInt32Array = world_graph.get_shortest_path(current_id, goal_id)
	if path_ids.is_empty():
		return

	var points: Array[Vector3] = [squad_pos + Vector3(0, 0.2, 0)]
	var start_index := 0
	if target_id >= 0 and path_ids.size() > 1:
		start_index = 1
	for i in range(start_index, path_ids.size()):
		var loc: SmartLocation = world_graph.get_location(path_ids[i])
		if loc != null:
			points.append(loc.world_position + Vector3(0, 0.2, 0))

	for i in range(points.size() - 1):
		_add_route_segment(points[i], points[i + 1])


func _add_route_segment(from_pos: Vector3, to_pos: Vector3) -> void:
	var delta := to_pos - from_pos
	var distance := delta.length()
	if distance < 0.05:
		return

	var segment := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.12
	mesh.height = distance
	segment.mesh = mesh
	segment.position = from_pos + delta * 0.5
	segment.look_at_from_position(segment.position, to_pos, Vector3.UP)
	segment.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.68, 0.18, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.68, 0.18)
	mat.emission_energy_multiplier = 1.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	segment.material_override = mat
	_route_root.add_child(segment)


func _resolve_goal_location_id(goal_location_key: String) -> int:
	if _zone_manager == null:
		return -1
	if not _zone_manager.has_method("get_graph_location_id_from_key"):
		return -1
	return int(_zone_manager.get_graph_location_id_from_key(goal_location_key))


func _format_location_ref(location_id: int) -> String:
	if location_id < 0:
		return "n/a"
	if _zone_manager != null and _zone_manager.has_method("get_location_key_for_graph_id"):
		var key := String(_zone_manager.get_location_key_for_graph_id(location_id))
		if not key.is_empty():
			return key
	return str(location_id)
