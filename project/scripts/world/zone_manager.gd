extends Node

signal zone_transition_started(from_id: StringName, to_id: StringName)
signal zone_transition_preloaded(from_id: StringName, to_id: StringName)
signal zone_transition_finished(from_id: StringName, to_id: StringName)

var _world_graph: WorldGraph = WorldGraph.new()
var _locations: Array[SmartLocation] = []
var _current_zone_id: StringName = &"zone_a"
var _loaded_zones: Array[StringName] = []
var _zone_locations_by_id: Dictionary = {}
var _zone_connections: Array[Dictionary] = []
var _transitioning: bool = false
var _transition_from_id: StringName = &""
var _transition_to_id: StringName = &""
var _zone_graph_index: Dictionary = {}
var _next_zone_graph_index: int = 0

const FACTION_NONE: int = -1
const FACTION_SCAVENGERS: int = 1
const FACTION_THRESHOLD_GUARDIANS: int = 2
const GRAPH_ZONE_STRIDE: int = 1000
const INVALID_LOCATION_ID: int = -1
const WORLD_LAYOUT_SCALE: float = 2.0

const LAYOUT_PATH := "res://data/world_layout.tres"


func _ready() -> void:
	_bootstrap_zone_data()
	_load_zone(_current_zone_id)


func get_world_graph() -> WorldGraph:
	return _world_graph


func get_current_zone_id() -> StringName:
	return _current_zone_id


func get_loaded_zones() -> Array[StringName]:
	return _loaded_zones.duplicate()


func get_zone_lod_map() -> Dictionary:
	var lod_by_zone: Dictionary = {}
	for zone_id in _zone_locations_by_id.keys():
		if zone_id is StringName:
			lod_by_zone[zone_id] = 0

	for loaded_zone in _loaded_zones:
		lod_by_zone[loaded_zone] = 2

	for loaded_zone in _loaded_zones:
		for neighbor in _get_adjacent_zones(loaded_zone):
			if int(lod_by_zone.get(neighbor, 0)) < 1:
				lod_by_zone[neighbor] = 1

	return lod_by_zone


func get_graph_location_id(zone_id: StringName, local_location_id: int) -> int:
	return _to_graph_location_id(zone_id, local_location_id)


func compose_location_key(zone_id: StringName, local_location_id: int) -> String:
	if zone_id == &"" or local_location_id < 0:
		return ""
	return "%s:%d" % [String(zone_id), local_location_id]


func parse_location_key(location_key: String) -> Dictionary:
	var parts := location_key.strip_edges().split(":", false, 1)
	if parts.size() != 2:
		return {"valid": false, "zone_id": StringName(), "local_location_id": INVALID_LOCATION_ID}

	var zone_text := String(parts[0]).strip_edges()
	var local_text := String(parts[1]).strip_edges()
	if zone_text.is_empty() or not local_text.is_valid_int():
		return {"valid": false, "zone_id": StringName(), "local_location_id": INVALID_LOCATION_ID}

	var local_location_id := int(local_text)
	if local_location_id < 0:
		return {"valid": false, "zone_id": StringName(), "local_location_id": INVALID_LOCATION_ID}

	return {"valid": true, "zone_id": StringName(zone_text), "local_location_id": local_location_id}


func get_graph_location_id_from_key(location_key: String) -> int:
	var parsed := parse_location_key(location_key)
	if not bool(parsed.get("valid", false)):
		return INVALID_LOCATION_ID

	var zone_id: StringName = parsed.get("zone_id", &"")
	if zone_id == &"" or not _zone_locations_by_id.has(zone_id):
		return INVALID_LOCATION_ID

	var local_location_id := int(parsed.get("local_location_id", INVALID_LOCATION_ID))
	if local_location_id < 0:
		return INVALID_LOCATION_ID

	return _to_graph_location_id(zone_id, local_location_id)


func get_location_key_for_graph_id(graph_location_id: int) -> String:
	var location: SmartLocation = _world_graph.get_location(graph_location_id)
	if location == null:
		return ""

	var local_location_id := _to_local_location_id(graph_location_id)
	if local_location_id < 0:
		return ""

	return compose_location_key(location.zone_id, local_location_id)


func get_local_location_id_for_graph_id(graph_location_id: int) -> int:
	return _to_local_location_id(graph_location_id)


func is_transitioning() -> bool:
	return _transitioning


func get_locations() -> Array[SmartLocation]:
	return _locations.duplicate()


func get_locations_for_zone(zone_id: StringName) -> Array[SmartLocation]:
	if not _zone_locations_by_id.has(zone_id):
		return []
	return (_zone_locations_by_id[zone_id] as Array[SmartLocation]).duplicate()


func get_all_zone_ids() -> Array[StringName]:
	var zone_ids: Array[StringName] = []
	for zone_id in _zone_locations_by_id.keys():
		if zone_id is StringName:
			zone_ids.append(zone_id)
	return zone_ids


func get_nearest_location_id(world_pos: Vector3) -> int:
	return _world_graph.get_nearest_location_id(world_pos)


func get_nearest_location(world_pos: Vector3) -> SmartLocation:
	var location_id := get_nearest_location_id(world_pos)
	return _world_graph.get_location(location_id)


func get_zone_debug_text(world_pos: Vector3) -> String:
	var nearest := get_nearest_location(world_pos)
	if nearest == null:
		return "Zone: %s | Loaded: %s | Loc: n/a" % [String(_current_zone_id), _loaded_zone_names()]
	var owner_name := get_faction_name(nearest.faction_owner_id)
	return "Zone: %s | Loaded: %s | Loc: %s (%s) | Owner: %s" % [String(_current_zone_id), _loaded_zone_names(), nearest.location_name, String(nearest.location_type), owner_name]


func get_faction_name(faction_id: int) -> String:
	match faction_id:
		FACTION_SCAVENGERS:
			return "Scavengers"
		FACTION_THRESHOLD_GUARDIANS:
			return "Threshold Guardians"
		_:
			return "Neutral"


func request_zone_transition(to_id: StringName) -> void:
	if _transitioning:
		return
	if to_id == _current_zone_id:
		return
	if not _zone_locations_by_id.has(to_id):
		return
	var from_id := _current_zone_id
	_transitioning = true
	_transition_from_id = from_id
	_transition_to_id = to_id
	emit_signal("zone_transition_started", from_id, to_id)
	for zone_id in _compute_loaded_zones(from_id, to_id):
		_preload_zone(zone_id)
	_loaded_zones = _compute_loaded_zones(from_id, to_id)
	emit_signal("zone_transition_preloaded", from_id, to_id)


func commit_zone_transition() -> void:
	if not _transitioning:
		return
	var from_id := _transition_from_id
	var to_id := _transition_to_id
	_load_zone(to_id)
	_loaded_zones = _compute_loaded_zones(to_id)
	_transitioning = false
	_transition_from_id = &""
	_transition_to_id = &""
	emit_signal("zone_transition_finished", from_id, to_id)


func get_gate_target_zone(from_zone_id: StringName, from_location_id: int = -1) -> StringName:
	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		var from_zone: StringName = conn.get("from_zone", &"")
		var to_zone: StringName = conn.get("to_zone", &"")
		if from_zone != from_zone_id or to_zone == &"":
			continue
		if from_location_id >= 0:
			var has_from_loc := conn.has("from_location_id")
			if has_from_loc and int(conn.get("from_location_id", -1)) == from_location_id:
				return to_zone
		else:
			return to_zone

	# Backward compatible fallback.
	if from_zone_id == &"zone_a":
		return &"zone_t_ab"
	if from_zone_id == &"zone_t_ab":
		return &"zone_b"
	if from_zone_id == &"zone_b":
		return &"zone_t_bc"
	if from_zone_id == &"zone_t_bc":
		return &"zone_c"
	if from_zone_id == &"zone_c":
		return &"zone_t_bc"
	return &""


func get_transition_gate_position(from_zone_id: StringName, to_zone_id: StringName, from_location_id: int = -1) -> Vector3:
	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		if conn.get("from_zone", &"") != from_zone_id:
			continue
		if conn.get("to_zone", &"") != to_zone_id:
			continue
		if from_location_id >= 0 and int(conn.get("from_location_id", -1)) != from_location_id:
			continue

		var loc_id := int(conn.get("from_location_id", -1))
		if loc_id < 0:
			continue
		var locations: Array[SmartLocation] = get_locations_for_zone(from_zone_id)
		for loc in locations:
			if loc != null and loc.location_id == loc_id:
				return loc.world_position

	# Fallback to nearest gate in requested zone.
	var fallback: Array[SmartLocation] = get_locations_for_zone(from_zone_id)
	for loc in fallback:
		if loc != null and loc.location_type == &"gate":
			return loc.world_position
	return Vector3.ZERO


func _load_zone(zone_id: StringName) -> void:
	if not _zone_locations_by_id.has(zone_id):
		_preload_zone(zone_id)
	if not _zone_locations_by_id.has(zone_id):
		return
	_current_zone_id = zone_id
	_locations = (_zone_locations_by_id[zone_id] as Array[SmartLocation]).duplicate()
	_rebuild_world_graph()
	for loaded_zone_id in _compute_loaded_zones(zone_id):
		_preload_zone(loaded_zone_id)
	_loaded_zones = _compute_loaded_zones(zone_id)


func _compute_loaded_zones(active_zone_id: StringName, extra_zone_id: StringName = &"") -> Array[StringName]:
	var zone_set: Dictionary = {}
	if active_zone_id != &"":
		zone_set[active_zone_id] = true
		for neighbor in _get_adjacent_zones(active_zone_id):
			zone_set[neighbor] = true
	if extra_zone_id != &"":
		zone_set[extra_zone_id] = true
		for neighbor in _get_adjacent_zones(extra_zone_id):
			zone_set[neighbor] = true

	var loaded: Array[StringName] = []
	for zone_id in zone_set.keys():
		if zone_id is StringName and _zone_locations_by_id.has(zone_id):
			loaded.append(zone_id)
	return loaded


func _get_adjacent_zones(zone_id: StringName) -> Array[StringName]:
	var result_set: Dictionary = {}
	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		var from_zone: StringName = conn.get("from_zone", &"")
		var to_zone: StringName = conn.get("to_zone", &"")
		if from_zone == zone_id and to_zone != &"":
			result_set[to_zone] = true
		elif to_zone == zone_id and from_zone != &"":
			result_set[from_zone] = true

	var result: Array[StringName] = []
	for neighbor in result_set.keys():
		if neighbor is StringName:
			result.append(neighbor)
	return result


func _preload_zone(zone_id: StringName) -> void:
	if _zone_locations_by_id.has(zone_id):
		return
	if _try_load_zone_from_file(zone_id):
		_ensure_zone_graph_index(zone_id)
		return
	_zone_locations_by_id[zone_id] = _build_locations_for_zone(zone_id)
	_ensure_zone_graph_index(zone_id)


func _bootstrap_zone_data() -> void:
	_zone_locations_by_id.clear()
	_zone_connections.clear()
	_zone_graph_index.clear()
	_next_zone_graph_index = 0
	if _try_load_all_from_file():
		if _zone_connections.is_empty():
			_set_default_connections()
		for zone_id in _zone_locations_by_id.keys():
			if zone_id is StringName:
				_ensure_zone_graph_index(zone_id)
		return

	# Fallback to hardcoded multi-region world.
	for zone_id in [&"zone_a", &"zone_t_ab", &"zone_b", &"zone_t_bc", &"zone_c"]:
		_zone_locations_by_id[zone_id] = _build_locations_for_zone(zone_id)
		_ensure_zone_graph_index(zone_id)
	_set_default_connections()


func _rebuild_world_graph() -> void:
	var graph_locations: Array[SmartLocation] = []
	var graph_by_id: Dictionary = {}

	for zone_key in _zone_locations_by_id.keys():
		if not (zone_key is StringName):
			continue
		var zone_id: StringName = zone_key
		_ensure_zone_graph_index(zone_id)
		var zone_locations: Array[SmartLocation] = _zone_locations_by_id[zone_id]
		for source_loc in zone_locations:
			if source_loc == null:
				continue
			if source_loc.location_id < 0 or source_loc.location_id >= GRAPH_ZONE_STRIDE:
				push_warning("ZoneManager: skipped location with invalid local id %d in zone %s" % [source_loc.location_id, String(zone_id)])
				continue
			var graph_loc := _copy_location(source_loc)
			graph_loc.location_id = _to_graph_location_id(zone_id, source_loc.location_id)
			var graph_neighbors := PackedInt32Array()
			for neighbor_local_id in source_loc.neighbor_location_ids:
				var neighbor_local := int(neighbor_local_id)
				if neighbor_local < 0 or neighbor_local >= GRAPH_ZONE_STRIDE:
					push_warning("ZoneManager: skipped neighbor with invalid local id %d in zone %s" % [neighbor_local, String(zone_id)])
					continue
				graph_neighbors.append(_to_graph_location_id(zone_id, neighbor_local))
			graph_loc.neighbor_location_ids = graph_neighbors
			if graph_by_id.has(graph_loc.location_id):
				push_warning("ZoneManager: duplicate graph location id %d for zone %s" % [graph_loc.location_id, String(zone_id)])
				continue
			graph_locations.append(graph_loc)
			graph_by_id[graph_loc.location_id] = graph_loc

	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		var from_zone: StringName = conn.get("from_zone", &"")
		var to_zone: StringName = conn.get("to_zone", &"")
		if from_zone == &"" or to_zone == &"":
			push_warning("ZoneManager: skipped malformed zone connection (missing from_zone/to_zone)")
			continue
		var from_local_id := int(conn.get("from_location_id", -1))
		if from_local_id < 0:
			push_warning("ZoneManager: skipped connection %s->%s with invalid from_location_id=%d" % [String(from_zone), String(to_zone), from_local_id])
			continue
		if not _zone_has_local_location_id(from_zone, from_local_id):
			push_warning("ZoneManager: skipped connection %s->%s because source location key %s does not exist" % [String(from_zone), String(to_zone), compose_location_key(from_zone, from_local_id)])
			continue

		var to_local_id := _resolve_gate_id_for_transition_target(from_zone, to_zone)
		if to_local_id < 0:
			push_warning("ZoneManager: skipped connection %s->%s because target gate location could not be resolved" % [String(from_zone), String(to_zone)])
			continue
		if not _zone_has_local_location_id(to_zone, to_local_id):
			push_warning("ZoneManager: skipped connection %s->%s because target location key %s does not exist" % [String(from_zone), String(to_zone), compose_location_key(to_zone, to_local_id)])
			continue

		var from_graph_id := _to_graph_location_id(from_zone, from_local_id)
		var to_graph_id := _to_graph_location_id(to_zone, to_local_id)
		var from_loc: SmartLocation = graph_by_id.get(from_graph_id, null)
		var to_loc: SmartLocation = graph_by_id.get(to_graph_id, null)
		if from_loc == null or to_loc == null:
			push_warning("ZoneManager: skipped connection %s->%s because graph node is missing (%d -> %d)" % [String(from_zone), String(to_zone), from_graph_id, to_graph_id])
			continue
		_append_neighbor_if_missing(from_loc, to_graph_id)
		_append_neighbor_if_missing(to_loc, from_graph_id)

	_world_graph.set_locations(graph_locations)
	_report_world_graph_validation(_validate_world_graph())


func _zone_has_local_location_id(zone_id: StringName, local_location_id: int) -> bool:
	if local_location_id < 0:
		return false
	if not _zone_locations_by_id.has(zone_id):
		return false
	var zone_locations: Array[SmartLocation] = _zone_locations_by_id[zone_id]
	for loc in zone_locations:
		if loc != null and loc.location_id == local_location_id:
			return true
	return false


func _resolve_gate_id_for_transition_target(from_zone_id: StringName, to_zone_id: StringName) -> int:
	for reverse_conn in _zone_connections:
		if not (reverse_conn is Dictionary):
			continue
		if reverse_conn.get("from_zone", &"") != to_zone_id:
			continue
		if reverse_conn.get("to_zone", &"") != from_zone_id:
			continue
		var gate_id := int(reverse_conn.get("from_location_id", -1))
		if gate_id >= 0:
			return gate_id

	var target_locations: Array[SmartLocation] = get_locations_for_zone(to_zone_id)
	for loc in target_locations:
		if loc != null and loc.location_type == &"gate":
			return loc.location_id
	return -1


func _append_neighbor_if_missing(location: SmartLocation, neighbor_id: int) -> void:
	var neighbors: PackedInt32Array = location.neighbor_location_ids
	for existing in neighbors:
		if int(existing) == neighbor_id:
			return
	neighbors.append(neighbor_id)
	location.neighbor_location_ids = neighbors


func _ensure_zone_graph_index(zone_id: StringName) -> void:
	if _zone_graph_index.has(zone_id):
		return
	_zone_graph_index[zone_id] = _next_zone_graph_index
	_next_zone_graph_index += 1


func _to_graph_location_id(zone_id: StringName, local_location_id: int) -> int:
	_ensure_zone_graph_index(zone_id)
	var zone_idx := int(_zone_graph_index[zone_id])
	return zone_idx * GRAPH_ZONE_STRIDE + local_location_id


func _to_local_location_id(graph_location_id: int) -> int:
	if graph_location_id < 0:
		return INVALID_LOCATION_ID
	var zone_idx := graph_location_id / GRAPH_ZONE_STRIDE
	if _zone_id_for_graph_index(zone_idx) == &"":
		return INVALID_LOCATION_ID
	var local_id := graph_location_id % GRAPH_ZONE_STRIDE
	if local_id < 0:
		return INVALID_LOCATION_ID
	return local_id


func _zone_id_for_graph_index(zone_index: int) -> StringName:
	for zone_id in _zone_graph_index.keys():
		if int(_zone_graph_index[zone_id]) == zone_index:
			return zone_id
	return &""


func _validate_world_graph() -> Dictionary:
	var all_ids: PackedInt32Array = _world_graph.get_all_location_ids()
	var id_set: Dictionary = {}
	for loc_id in all_ids:
		id_set[int(loc_id)] = true

	var orphan_ids: PackedInt32Array = PackedInt32Array()
	var missing_target_edges: Array[String] = []
	var one_way_edges: Array[String] = []
	var non_positive_cost_edges: Array[String] = []
	var zone_metrics: Dictionary = {}
	var checked_undirected_edges: Dictionary = {}

	for loc_id_raw in all_ids:
		var loc_id := int(loc_id_raw)
		var loc: SmartLocation = _world_graph.get_location(loc_id)
		var zone_id: StringName = loc.zone_id if loc != null else &"unknown"
		if not zone_metrics.has(zone_id):
			zone_metrics[zone_id] = {
				"nodes": 0,
				"orphans": 0,
				"missing_targets": 0,
				"one_way": 0,
				"non_positive_cost": 0,
			}
		(zone_metrics[zone_id] as Dictionary)["nodes"] = int((zone_metrics[zone_id] as Dictionary).get("nodes", 0)) + 1

		var neighbors: PackedInt32Array = _world_graph.get_neighbors(loc_id)
		if neighbors.is_empty():
			orphan_ids.append(loc_id)
			(zone_metrics[zone_id] as Dictionary)["orphans"] = int((zone_metrics[zone_id] as Dictionary).get("orphans", 0)) + 1
			continue

		for neighbor_raw in neighbors:
			var neighbor_id := int(neighbor_raw)
			if not id_set.has(neighbor_id):
				missing_target_edges.append("%d->%d" % [loc_id, neighbor_id])
				(zone_metrics[zone_id] as Dictionary)["missing_targets"] = int((zone_metrics[zone_id] as Dictionary).get("missing_targets", 0)) + 1
				continue

			var reverse_neighbors: PackedInt32Array = _world_graph.get_neighbors(neighbor_id)
			if not reverse_neighbors.has(loc_id):
				one_way_edges.append("%d->%d" % [loc_id, neighbor_id])
				(zone_metrics[zone_id] as Dictionary)["one_way"] = int((zone_metrics[zone_id] as Dictionary).get("one_way", 0)) + 1

			var edge_a := mini(loc_id, neighbor_id)
			var edge_b := maxi(loc_id, neighbor_id)
			var edge_key := "%d:%d" % [edge_a, edge_b]
			if checked_undirected_edges.has(edge_key):
				continue
			checked_undirected_edges[edge_key] = true

			var edge_cost := float(_world_graph.get_connection_distance(loc_id, neighbor_id))
			if edge_cost <= 0.0:
				var neighbor_loc: SmartLocation = _world_graph.get_location(neighbor_id)
				var is_allowed_zero_gate_link := (
					edge_cost == 0.0
					and loc != null
					and neighbor_loc != null
					and loc.location_type == &"gate"
					and neighbor_loc.location_type == &"gate"
					and loc.zone_id != neighbor_loc.zone_id
				)
				if not is_allowed_zero_gate_link:
					non_positive_cost_edges.append("%d<->%d (%.3f)" % [edge_a, edge_b, edge_cost])
					(zone_metrics[zone_id] as Dictionary)["non_positive_cost"] = int((zone_metrics[zone_id] as Dictionary).get("non_positive_cost", 0)) + 1

	var zone_report_lines: Array[String] = []
	var sorted_zone_names: Array[String] = []
	for zone_key in zone_metrics.keys():
		sorted_zone_names.append(String(zone_key))
	sorted_zone_names.sort()
	for zone_name in sorted_zone_names:
		var metrics: Dictionary = zone_metrics.get(StringName(zone_name), {})
		zone_report_lines.append(
			"%s nodes=%d orphan=%d missing=%d one_way=%d bad_cost=%d" % [
				zone_name,
				int(metrics.get("nodes", 0)),
				int(metrics.get("orphans", 0)),
				int(metrics.get("missing_targets", 0)),
				int(metrics.get("one_way", 0)),
				int(metrics.get("non_positive_cost", 0)),
			]
		)

	return {
		"total_nodes": all_ids.size(),
		"orphan_ids": orphan_ids,
		"missing_target_edges": missing_target_edges,
		"one_way_edges": one_way_edges,
		"non_positive_cost_edges": non_positive_cost_edges,
		"zone_report_lines": zone_report_lines,
	}


func _report_world_graph_validation(summary: Dictionary) -> void:
	var total_nodes := int(summary.get("total_nodes", 0))
	var orphan_ids: PackedInt32Array = summary.get("orphan_ids", PackedInt32Array())
	var missing_target_edges: Array = summary.get("missing_target_edges", [])
	var one_way_edges: Array = summary.get("one_way_edges", [])
	var non_positive_cost_edges: Array = summary.get("non_positive_cost_edges", [])
	var zone_report_lines: Array = summary.get("zone_report_lines", [])

	for line in zone_report_lines:
		print("ZoneManager: zone stats | %s" % String(line))

	if orphan_ids.is_empty() and missing_target_edges.is_empty() and one_way_edges.is_empty() and non_positive_cost_edges.is_empty():
		print("ZoneManager: graph validation OK (%d nodes)" % total_nodes)
		return

	if not orphan_ids.is_empty():
		push_warning("ZoneManager: orphan locations detected: %s" % [str(orphan_ids)])
	if not one_way_edges.is_empty():
		push_warning("ZoneManager: one-way edges detected: %s" % [", ".join(PackedStringArray(one_way_edges))])
	if not missing_target_edges.is_empty():
		var missing_edges_text := ", ".join(PackedStringArray(missing_target_edges))
		push_error("ZoneManager: missing edge targets detected: %s" % missing_edges_text)
		if OS.is_debug_build():
			assert(false, "World graph has missing edge targets")
	if not non_positive_cost_edges.is_empty():
		var bad_cost_text := ", ".join(PackedStringArray(non_positive_cost_edges))
		push_error("ZoneManager: non-positive edge costs detected: %s" % bad_cost_text)
		if OS.is_debug_build():
			assert(false, "World graph has non-positive edge costs")


func _try_load_all_from_file() -> bool:
	if not ResourceLoader.exists(LAYOUT_PATH):
		return false
	var res: Variant = ResourceLoader.load(LAYOUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return false

	var file_locations: Variant = res.get("locations")
	if file_locations == null:
		return false

	# Collect zones from explicit list and from location.zone_id values.
	var known_zones: Dictionary = {}
	var zones_from_file: Variant = res.get("zones")
	if zones_from_file is Array:
		for z in (zones_from_file as Array):
			if z is StringName and String(z) != "":
				known_zones[z] = true

	for item in (file_locations as Array):
		if not (item is SmartLocation):
			continue
		var loc := item as SmartLocation
		known_zones[loc.zone_id] = true

	if known_zones.is_empty():
		var legacy_zone: StringName = res.get("zone_id", &"")
		if legacy_zone != &"":
			known_zones[legacy_zone] = true

	if known_zones.is_empty():
		return false

	for zone_key in known_zones.keys():
		_zone_locations_by_id[zone_key] = []

	for item in (file_locations as Array):
		if not (item is SmartLocation):
			continue
		var source := item as SmartLocation
		var copy := _copy_location(source)
		if not _zone_locations_by_id.has(copy.zone_id):
			_zone_locations_by_id[copy.zone_id] = []
		(_zone_locations_by_id[copy.zone_id] as Array).append(copy)

	var conn_from_file: Variant = res.get("zone_connections")
	if conn_from_file is Array:
		for conn in (conn_from_file as Array):
			if conn is Dictionary:
				_zone_connections.append(conn)

	print("ZoneManager: loaded %d zones from %s" % [_zone_locations_by_id.size(), LAYOUT_PATH])
	return _zone_locations_by_id.size() > 0


func _try_load_zone_from_file(zone_id: StringName) -> bool:
	if not _try_load_all_from_file():
		return false
	return _zone_locations_by_id.has(zone_id)


func _set_default_connections() -> void:
	_zone_connections = [
		{"from_zone": &"zone_a", "to_zone": &"zone_t_ab", "from_location_id": 8},
		{"from_zone": &"zone_t_ab", "to_zone": &"zone_a", "from_location_id": 1},
		{"from_zone": &"zone_t_ab", "to_zone": &"zone_b", "from_location_id": 3},
		{"from_zone": &"zone_b", "to_zone": &"zone_t_ab", "from_location_id": 8},
		{"from_zone": &"zone_b", "to_zone": &"zone_t_bc", "from_location_id": 9},
		{"from_zone": &"zone_t_bc", "to_zone": &"zone_b", "from_location_id": 1},
		{"from_zone": &"zone_t_bc", "to_zone": &"zone_c", "from_location_id": 3},
		{"from_zone": &"zone_c", "to_zone": &"zone_t_bc", "from_location_id": 8},
	]


func _loaded_zone_names() -> String:
	var names: Array[String] = []
	for z in _loaded_zones:
		names.append(String(z))
	return ",".join(names)


func _build_locations_for_zone(zone_id: StringName) -> Array[SmartLocation]:
	match zone_id:
		&"zone_a":
			return [
				_make_location(1, "A Camp", zone_id, &"camp", Vector3(-8, 0, -7), PackedInt32Array([2, 3])),
				_make_location(2, "A Workshop", zone_id, &"trader", Vector3(-3, 0, -3), PackedInt32Array([1, 4])),
				_make_location(3, "A Ruins", zone_id, &"ruins", Vector3(-9, 0, 3), PackedInt32Array([1, 4])),
				_make_location(4, "A Crossroad", zone_id, &"crossroad", Vector3(0, 0, 0), PackedInt32Array([2, 3, 5, 6])),
				_make_location(5, "A Checkpoint", zone_id, &"checkpoint", Vector3(8, 0, -4), PackedInt32Array([4, 7])),
				_make_location(6, "A Warehouse", zone_id, &"warehouse", Vector3(7, 0, 5), PackedInt32Array([4, 7, 8])),
				_make_location(7, "A Anomaly", zone_id, &"anomaly", Vector3(9, 0, 1), PackedInt32Array([5, 6, 8])),
				_make_location(8, "A Edge Gate", zone_id, &"gate", Vector3(12, 0, 0), PackedInt32Array([6, 7])),
			]
		&"zone_t_ab":
			return [
				_make_location(1, "AB Gate West", zone_id, &"gate", Vector3(12, 0, 0), PackedInt32Array([2])),
				_make_location(2, "AB Corridor", zone_id, &"crossroad", Vector3(18, 0, 0), PackedInt32Array([1, 3, 4])),
				_make_location(3, "AB Gate East", zone_id, &"gate", Vector3(24, 0, 0), PackedInt32Array([2])),
				_make_location(4, "AB Service", zone_id, &"warehouse", Vector3(18, 0, 4), PackedInt32Array([2])),
			]
		&"zone_b":
			return [
				_make_location(1, "B Outpost", zone_id, &"camp", Vector3(28, 0, -8), PackedInt32Array([2, 3])),
				_make_location(2, "B Trader", zone_id, &"trader", Vector3(31, 0, -3), PackedInt32Array([1, 4, 8])),
				_make_location(3, "B Junkyard", zone_id, &"ruins", Vector3(30, 0, 4), PackedInt32Array([1, 4, 8])),
				_make_location(4, "B Crossroad", zone_id, &"crossroad", Vector3(36, 0, 0), PackedInt32Array([2, 3, 5, 6])),
				_make_location(5, "B Checkpoint", zone_id, &"checkpoint", Vector3(42, 0, -5), PackedInt32Array([4, 7, 9])),
				_make_location(6, "B Warehouse", zone_id, &"warehouse", Vector3(41, 0, 6), PackedInt32Array([4, 7, 9])),
				_make_location(7, "B Anomaly", zone_id, &"anomaly", Vector3(45, 0, 2), PackedInt32Array([5, 6])),
				_make_location(8, "B Gate West", zone_id, &"gate", Vector3(24, 0, 0), PackedInt32Array([2, 3])),
				_make_location(9, "B Gate East", zone_id, &"gate", Vector3(48, 0, 0), PackedInt32Array([5, 6])),
			]
		&"zone_t_bc":
			return [
				_make_location(1, "BC Gate West", zone_id, &"gate", Vector3(48, 0, 0), PackedInt32Array([2])),
				_make_location(2, "BC Corridor", zone_id, &"crossroad", Vector3(54, 0, 0), PackedInt32Array([1, 3, 4])),
				_make_location(3, "BC Gate East", zone_id, &"gate", Vector3(60, 0, 0), PackedInt32Array([2])),
				_make_location(4, "BC Cover", zone_id, &"ruins", Vector3(54, 0, -4), PackedInt32Array([2])),
			]
		&"zone_c":
			return [
				_make_location(1, "C Camp", zone_id, &"camp", Vector3(64, 0, -7), PackedInt32Array([2, 3])),
				_make_location(2, "C Workshop", zone_id, &"trader", Vector3(68, 0, -3), PackedInt32Array([1, 4])),
				_make_location(3, "C Ruins", zone_id, &"ruins", Vector3(66, 0, 4), PackedInt32Array([1, 4])),
				_make_location(4, "C Crossroad", zone_id, &"crossroad", Vector3(72, 0, 0), PackedInt32Array([2, 3, 5, 6])),
				_make_location(5, "C Checkpoint", zone_id, &"checkpoint", Vector3(78, 0, -5), PackedInt32Array([4, 7])),
				_make_location(6, "C Warehouse", zone_id, &"warehouse", Vector3(77, 0, 6), PackedInt32Array([4, 7, 8])),
				_make_location(7, "C Anomaly", zone_id, &"anomaly", Vector3(80, 0, 1), PackedInt32Array([5, 6])),
				_make_location(8, "C Gate West", zone_id, &"gate", Vector3(60, 0, 0), PackedInt32Array([6])),
			]
		_:
			return []


func _make_location(
		location_id: int,
		location_name: String,
		zone_id: StringName,
		location_type: StringName,
		world_position: Vector3,
		neighbors: PackedInt32Array
	) -> SmartLocation:
	var location := SmartLocation.new()
	location.location_id = location_id
	location.location_name = location_name
	location.location_type = location_type
	location.zone_id = zone_id
	location.world_position = Vector3(world_position.x * WORLD_LAYOUT_SCALE, world_position.y, world_position.z * WORLD_LAYOUT_SCALE)
	location.faction_owner_id = _get_default_owner_for(location_type)
	location.neighbor_location_ids = neighbors
	return location


func _copy_location(source: SmartLocation) -> SmartLocation:
	var copy := SmartLocation.new()
	copy.location_id = source.location_id
	copy.location_name = source.location_name
	copy.zone_id = source.zone_id
	copy.location_type = source.location_type
	copy.world_position = source.world_position
	copy.max_population = source.max_population
	copy.faction_owner_id = source.faction_owner_id
	copy.neighbor_location_ids = source.neighbor_location_ids.duplicate()
	return copy


func _get_default_owner_for(location_type: StringName) -> int:
	if location_type == &"camp" or location_type == &"trader" or location_type == &"ruins":
		return FACTION_SCAVENGERS
	if location_type == &"checkpoint" or location_type == &"gate":
		return FACTION_THRESHOLD_GUARDIANS
	return FACTION_NONE
