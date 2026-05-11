@tool
extends VBoxContainer

const LAYOUT_DATA_SCRIPT := preload("res://scripts/world/world_layout_data.gd")
const DEFAULT_LAYOUT_PATH := "res://data/world_layout.tres"

var _locations: Array[SmartLocation] = []
var _zone_id: StringName = &"zone_a"
var _zone_connections: Array[Dictionary] = []

var _status_label: Label
var _path_edit: LineEdit
var _list: ItemList
var _zone_edit: LineEdit
var _conn_list: ItemList
var _conn_from_edit: LineEdit
var _conn_to_edit: LineEdit
var _conn_gate_id: SpinBox

# Edge editing state: -1 = none selected, otherwise index into _locations
var _edge_from_idx: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(340, 400)

	var title := Label.new()
	title.text = "World Builder"
	add_child(title)

	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	var zone_row := HBoxContainer.new()
	add_child(zone_row)
	var zone_label := Label.new()
	zone_label.text = "Active Zone ID:"
	zone_row.add_child(zone_label)
	_zone_edit = LineEdit.new()
	_zone_edit.text = String(_zone_id)
	_zone_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_edit.text_submitted.connect(_on_zone_text_submitted)
	zone_row.add_child(_zone_edit)

	# --- Location actions ---
	var loc_label := Label.new()
	loc_label.text = "Locations"
	add_child(loc_label)

	var loc_row := HBoxContainer.new()
	add_child(loc_row)

	var seed_btn := Button.new()
	seed_btn.text = "Seed Zone A"
	seed_btn.pressed.connect(_seed_zone_a)
	loc_row.add_child(seed_btn)

	var chain_btn := Button.new()
	chain_btn.text = "Generate A-T-B-T-C"
	chain_btn.pressed.connect(_seed_chain_a_t_b_t_c)
	loc_row.add_child(chain_btn)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_add_location)
	loc_row.add_child(add_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete Selected"
	del_btn.pressed.connect(_delete_selected_location)
	loc_row.add_child(del_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.pressed.connect(_clear_locations)
	loc_row.add_child(clear_btn)

	# --- Location list ---
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 150)
	add_child(_list)

	# --- Edge actions ---
	var edge_label := Label.new()
	edge_label.text = "Edges (select 2 locations → Add/Delete)"
	add_child(edge_label)

	var edge_row := HBoxContainer.new()
	add_child(edge_row)

	var edge_add_btn := Button.new()
	edge_add_btn.text = "Add Edge"
	edge_add_btn.pressed.connect(_add_edge)
	edge_row.add_child(edge_add_btn)

	var edge_del_btn := Button.new()
	edge_del_btn.text = "Delete Edge"
	edge_del_btn.pressed.connect(_delete_edge)
	edge_row.add_child(edge_del_btn)

	var edge_clear_btn := Button.new()
	edge_clear_btn.text = "Clear Edges on Selected"
	edge_clear_btn.pressed.connect(_clear_edges_on_selected)
	edge_row.add_child(edge_clear_btn)

	# --- Region connections ---
	var conn_label := Label.new()
	conn_label.text = "Region Transitions"
	add_child(conn_label)

	var conn_row := HBoxContainer.new()
	add_child(conn_row)
	_conn_from_edit = LineEdit.new()
	_conn_from_edit.placeholder_text = "from_zone (e.g. zone_a)"
	_conn_from_edit.text = String(_zone_id)
	_conn_from_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conn_row.add_child(_conn_from_edit)
	_conn_to_edit = LineEdit.new()
	_conn_to_edit.placeholder_text = "to_zone (e.g. zone_b)"
	_conn_to_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conn_row.add_child(_conn_to_edit)
	_conn_gate_id = SpinBox.new()
	_conn_gate_id.min_value = -1
	_conn_gate_id.max_value = 100000
	_conn_gate_id.step = 1
	_conn_gate_id.value = -1
	_conn_gate_id.custom_minimum_size = Vector2(80, 0)
	conn_row.add_child(_conn_gate_id)

	var conn_btn_row := HBoxContainer.new()
	add_child(conn_btn_row)
	var conn_add_btn := Button.new()
	conn_add_btn.text = "Add Transition"
	conn_add_btn.pressed.connect(_add_connection)
	conn_btn_row.add_child(conn_add_btn)
	var conn_del_btn := Button.new()
	conn_del_btn.text = "Delete Transition"
	conn_del_btn.pressed.connect(_delete_selected_connection)
	conn_btn_row.add_child(conn_del_btn)

	_conn_list = ItemList.new()
	_conn_list.custom_minimum_size = Vector2(0, 84)
	add_child(_conn_list)

	# --- Validate / Save / Load ---
	var io_label := Label.new()
	io_label.text = "Save / Load"
	add_child(io_label)

	var path_row := HBoxContainer.new()
	add_child(path_row)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = DEFAULT_LAYOUT_PATH
	_path_edit.text = DEFAULT_LAYOUT_PATH
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_path_edit)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.pressed.connect(_validate_and_report)
	add_child(validate_btn)

	var io_row := HBoxContainer.new()
	add_child(io_row)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_layout)
	io_row.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_layout)
	io_row.add_child(save_btn)

	_refresh_list()
	_refresh_connections()


# ---- Location operations -----------------------------------------------

func _seed_zone_a() -> void:
	var zone_script: Variant = load("res://scripts/world/zone_manager.gd")
	if zone_script == null:
		_set_status("ZoneManager script not found")
		return

	var zone_manager: Variant = (zone_script as GDScript).new()
	zone_manager.call("_load_zone", &"zone_a")
	var source_locations: Array = zone_manager.call("get_locations")

	_locations.clear()
	for item in source_locations:
		if item == null:
			continue
		_locations.append(_copy_location(item))
	_zone_id = &"zone_a"
	_zone_connections = [
		{"from_zone": &"zone_a", "to_zone": &"zone_b", "from_location_id": 8},
		{"from_zone": &"zone_b", "to_zone": &"zone_a", "from_location_id": 8},
	]
	_edge_from_idx = -1
	if _zone_edit != null:
		_zone_edit.text = String(_zone_id)
	if _conn_from_edit != null:
		_conn_from_edit.text = String(_zone_id)
	_refresh_list()
	_refresh_connections()
	_set_status("Seeded %d locations from Zone A" % _locations.size())


func _seed_chain_a_t_b_t_c() -> void:
	var zone_script: Variant = load("res://scripts/world/zone_manager.gd")
	if zone_script == null:
		_set_status("ZoneManager script not found")
		return

	var zone_manager: Variant = (zone_script as GDScript).new()
	var chain: Array[StringName] = [&"zone_a", &"zone_t_ab", &"zone_b", &"zone_t_bc", &"zone_c"]

	_locations.clear()
	for zone_id in chain:
		zone_manager.call("_load_zone", zone_id)
		var source_locations: Array = zone_manager.call("get_locations")
		for item in source_locations:
			if item == null:
				continue
			_locations.append(_copy_location(item))

	_zone_id = &"zone_a"
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
	_edge_from_idx = -1

	if _zone_edit != null:
		_zone_edit.text = String(_zone_id)
	if _conn_from_edit != null:
		_conn_from_edit.text = String(_zone_id)

	_refresh_list()
	_refresh_connections()
	_set_status("Generated chain A-T-B-T-C (%d locations, %d transitions)" % [_locations.size(), _zone_connections.size()])


func _add_location() -> void:
	if not ClassDB.class_exists("SmartLocation"):
		_set_status("SmartLocation class missing")
		return

	_zone_id = _active_zone_id()
	var loc := SmartLocation.new()
	loc.location_id = _next_location_id()
	loc.location_name = "Location %d" % loc.location_id
	loc.zone_id = _zone_id
	loc.location_type = &"camp"
	loc.max_population = 6
	loc.faction_owner_id = -1
	loc.neighbor_location_ids = PackedInt32Array()
	loc.world_position = _selected_world_position()
	_locations.append(loc)
	_refresh_list()
	_set_status("Added location id=%d at %s" % [loc.location_id, loc.world_position])


func _on_zone_text_submitted(_text: String) -> void:
	_zone_id = _active_zone_id()
	if _conn_from_edit != null:
		_conn_from_edit.text = String(_zone_id)
	_set_status("Active zone set to %s" % String(_zone_id))


func _active_zone_id() -> StringName:
	if _zone_edit == null:
		return _zone_id
	var text := _zone_edit.text.strip_edges()
	if text.is_empty():
		return _zone_id
	return StringName(text)


func _add_connection() -> void:
	if _conn_from_edit == null or _conn_to_edit == null:
		return
	var from_zone := StringName(_conn_from_edit.text.strip_edges())
	var to_zone := StringName(_conn_to_edit.text.strip_edges())
	if String(from_zone) == "" or String(to_zone) == "":
		_set_status("Transition needs from_zone and to_zone")
		return
	var gate_id := int(_conn_gate_id.value)
	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		if conn.get("from_zone", &"") == from_zone and conn.get("to_zone", &"") == to_zone and int(conn.get("from_location_id", -1)) == gate_id:
			_set_status("Transition already exists")
			return
	var entry: Dictionary = {
		"from_zone": from_zone,
		"to_zone": to_zone,
	}
	if gate_id >= 0:
		entry["from_location_id"] = gate_id
	_zone_connections.append(entry)
	_refresh_connections()
	_set_status("Added transition %s -> %s (gate_id=%d)" % [String(from_zone), String(to_zone), gate_id])


func _delete_selected_connection() -> void:
	if _conn_list == null:
		return
	var selected := _conn_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select transition first")
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _zone_connections.size():
		return
	_zone_connections.remove_at(idx)
	_refresh_connections()
	_set_status("Transition removed")


func _delete_selected_location() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a location first")
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _locations.size():
		return
	var removed_id: int = _locations[idx].location_id
	_locations.remove_at(idx)
	# Clean up references from neighbor lists
	for loc in _locations:
		if loc == null:
			continue
		var new_neighbors := PackedInt32Array()
		for nid in loc.neighbor_location_ids:
			if int(nid) != removed_id:
				new_neighbors.append(nid)
		loc.neighbor_location_ids = new_neighbors
	_edge_from_idx = -1
	_refresh_list()
	_set_status("Deleted location id=%d, cleaned up edges" % removed_id)


func _clear_locations() -> void:
	_locations.clear()
	_edge_from_idx = -1
	_refresh_list()
	_set_status("Locations cleared")


# ---- Edge operations ---------------------------------------------------

func _add_edge() -> void:
	var selected := _list.get_selected_items()
	if selected.size() < 2:
		_set_status("Select exactly 2 locations for Add Edge")
		return
	var idx_a: int = selected[0]
	var idx_b: int = selected[1]
	if not _indices_valid(idx_a, idx_b):
		return
	var loc_a := _locations[idx_a]
	var loc_b := _locations[idx_b]
	var id_a: int = loc_a.location_id
	var id_b: int = loc_b.location_id
	if _has_edge(loc_a, id_b):
		_set_status("Edge %d↔%d already exists" % [id_a, id_b])
		return
	# Bidirectional edge
	loc_a.neighbor_location_ids.append(id_b)
	loc_b.neighbor_location_ids.append(id_a)
	var dist := loc_a.world_position.distance_to(loc_b.world_position)
	_refresh_list()
	_set_status("Edge added: %d↔%d (dist=%.1f)" % [id_a, id_b, dist])


func _delete_edge() -> void:
	var selected := _list.get_selected_items()
	if selected.size() < 2:
		_set_status("Select exactly 2 locations for Delete Edge")
		return
	var idx_a: int = selected[0]
	var idx_b: int = selected[1]
	if not _indices_valid(idx_a, idx_b):
		return
	var loc_a := _locations[idx_a]
	var loc_b := _locations[idx_b]
	var id_a: int = loc_a.location_id
	var id_b: int = loc_b.location_id
	if not _has_edge(loc_a, id_b):
		_set_status("No edge between %d and %d" % [id_a, id_b])
		return
	loc_a.neighbor_location_ids = _remove_from_packed(loc_a.neighbor_location_ids, id_b)
	loc_b.neighbor_location_ids = _remove_from_packed(loc_b.neighbor_location_ids, id_a)
	_refresh_list()
	_set_status("Edge deleted: %d↔%d" % [id_a, id_b])


func _clear_edges_on_selected() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a location first")
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _locations.size():
		return
	var loc := _locations[idx]
	var id: int = loc.location_id
	# Remove outgoing edges from other locations first
	for other in _locations:
		if other == null or other.location_id == id:
			continue
		other.neighbor_location_ids = _remove_from_packed(other.neighbor_location_ids, id)
	loc.neighbor_location_ids = PackedInt32Array()
	_refresh_list()
	_set_status("Cleared all edges on location id=%d" % id)


# ---- Validation --------------------------------------------------------

func _validate_and_report() -> void:
	var errors := _validate()
	if errors.is_empty():
		_set_status("Validation OK — %d locations, no issues" % _locations.size())
	else:
		_set_status("Validation errors:\n" + "\n".join(errors))


func _validate() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var loc_id_set: Dictionary = {}

	for loc in _locations:
		if loc == null:
			errors.append("Null location in array")
			continue
		loc_id_set[loc.location_id] = true
		if loc.location_id < 0:
			errors.append("Location has invalid id=%d" % loc.location_id)
		if seen_ids.has(loc.location_id):
			errors.append("Duplicate location_id=%d" % loc.location_id)
		seen_ids[loc.location_id] = true

	for loc in _locations:
		if loc == null:
			continue
		var neighbor_set: Dictionary = {}
		for nid in loc.neighbor_location_ids:
			var n: int = int(nid)
			if not loc_id_set.has(n):
				errors.append("Location id=%d has edge to non-existent id=%d" % [loc.location_id, n])
			if neighbor_set.has(n):
				errors.append("Location id=%d has duplicate edge to id=%d" % [loc.location_id, n])
			neighbor_set[n] = true
			if n == loc.location_id:
				errors.append("Location id=%d has self-loop edge" % loc.location_id)

	if _locations.size() > 0 and errors.is_empty():
		# Warn on isolated nodes
		for loc in _locations:
			if loc == null:
				continue
			if loc.neighbor_location_ids.is_empty():
				errors.append("Warning: location id=%d '%s' is isolated (no edges)" % [loc.location_id, loc.location_name])

	var zone_set: Dictionary = {}
	for loc in _locations:
		if loc != null:
			zone_set[loc.zone_id] = true

	for conn in _zone_connections:
		if not (conn is Dictionary):
			errors.append("Transition entry is not a dictionary")
			continue
		var from_zone: StringName = conn.get("from_zone", &"")
		var to_zone: StringName = conn.get("to_zone", &"")
		if from_zone == &"" or to_zone == &"":
			errors.append("Transition has empty from/to zone")
			continue
		if not zone_set.has(from_zone):
			errors.append("Transition from_zone '%s' has no locations" % String(from_zone))
		if not zone_set.has(to_zone):
			errors.append("Transition to_zone '%s' has no locations" % String(to_zone))
		if conn.has("from_location_id"):
			var from_id := int(conn.get("from_location_id", -1))
			var found := false
			for loc in _locations:
				if loc != null and loc.zone_id == from_zone and loc.location_id == from_id:
					found = true
					break
			if not found:
				errors.append("Transition %s->%s references missing gate id=%d" % [String(from_zone), String(to_zone), from_id])

	return errors


# ---- Save / Load -------------------------------------------------------

func _save_layout() -> void:
	var path := _layout_path()
	if not path.ends_with(".tres"):
		_set_status("Path must end with .tres")
		return

	var errors := _validate()
	var hard_errors := errors.filter(func(e): return not e.begins_with("Warning:"))
	if not hard_errors.is_empty():
		_set_status("Fix errors before saving:\n" + "\n".join(hard_errors))
		return

	# Ensure parent dir exists
	var dir := DirAccess.open("res://")
	if dir != null and not DirAccess.dir_exists_absolute(path.get_base_dir()):
		dir.make_dir_recursive(path.get_base_dir().replace("res://", ""))

	var layout := LAYOUT_DATA_SCRIPT.new()
	layout.zone_id = _zone_id
	layout.locations = _locations.duplicate()
	layout.zone_connections = _zone_connections.duplicate()
	layout.zones = _collect_zones()

	var err := ResourceSaver.save(layout, path)
	if err != OK:
		_set_status("Save failed: %s" % error_string(err))
		return
	_set_status("Saved %d locations to %s" % [_locations.size(), path])


func _load_layout() -> void:
	var path := _layout_path()
	if not ResourceLoader.exists(path):
		_set_status("Layout not found at: %s" % path)
		return

	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res == null or not (res is WorldLayoutData):
		_set_status("Invalid layout resource")
		return

	var layout: WorldLayoutData = res
	_zone_id = layout.zone_id
	_locations.clear()
	_zone_connections.clear()
	_edge_from_idx = -1
	for loc in layout.locations:
		if loc == null:
			continue
		_locations.append(_copy_location(loc))
	for conn in layout.zone_connections:
		if conn is Dictionary:
			_zone_connections.append(conn)
	if _zone_edit != null:
		_zone_edit.text = String(_zone_id)
	if _conn_from_edit != null:
		_conn_from_edit.text = String(_zone_id)
	_refresh_list()
	_refresh_connections()
	_set_status("Loaded %d locations (zone=%s)" % [_locations.size(), String(_zone_id)])


# ---- Helpers -----------------------------------------------------------

func _refresh_list() -> void:
	if _list == null:
		return
	var prev_selected := _list.get_selected_items()
	_list.clear()
	for loc in _locations:
		if loc == null:
			continue
		var neighbor_str := ""
		for nid in loc.neighbor_location_ids:
			if neighbor_str.length() > 0:
				neighbor_str += ","
			neighbor_str += str(int(nid))
		var line := "id=%d | %s | zone=%s | %s | owner=%d | edges=[%s]" % [
			loc.location_id,
			loc.location_name,
			String(loc.zone_id),
			String(loc.location_type),
			loc.faction_owner_id,
			neighbor_str,
		]
		_list.add_item(line)
	# Restore selection if still valid
	for idx in prev_selected:
		if idx < _list.item_count:
			_list.select(idx, false)


func _refresh_connections() -> void:
	if _conn_list == null:
		return
	_conn_list.clear()
	for conn in _zone_connections:
		if not (conn is Dictionary):
			continue
		var from_zone: StringName = conn.get("from_zone", &"")
		var to_zone: StringName = conn.get("to_zone", &"")
		var gate_id := int(conn.get("from_location_id", -1))
		var text := "%s -> %s" % [String(from_zone), String(to_zone)]
		if gate_id >= 0:
			text += " | gate_id=%d" % gate_id
		_conn_list.add_item(text)


func _collect_zones() -> Array[StringName]:
	var zone_set: Dictionary = {}
	for loc in _locations:
		if loc != null:
			zone_set[loc.zone_id] = true
	var result: Array[StringName] = []
	for zone_id in zone_set.keys():
		result.append(zone_id)
	return result


func _layout_path() -> String:
	var path := _path_edit.text.strip_edges()
	if path.is_empty():
		return DEFAULT_LAYOUT_PATH
	return path


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _next_location_id() -> int:
	var max_id := 0
	for loc in _locations:
		if loc == null:
			continue
		max_id = maxi(max_id, int(loc.location_id))
	return max_id + 1


func _selected_world_position() -> Vector3:
	var sel := EditorInterface.get_selection()
	if sel == null:
		return Vector3.ZERO
	var nodes := sel.get_selected_nodes()
	if nodes.is_empty():
		return Vector3.ZERO
	var first := nodes[0]
	if first is Node3D:
		return (first as Node3D).global_position
	return Vector3.ZERO


func _has_edge(loc: SmartLocation, other_id: int) -> bool:
	for nid in loc.neighbor_location_ids:
		if int(nid) == other_id:
			return true
	return false


func _remove_from_packed(arr: PackedInt32Array, value: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for v in arr:
		if int(v) != value:
			result.append(v)
	return result


func _indices_valid(idx_a: int, idx_b: int) -> bool:
	if idx_a == idx_b:
		_set_status("Select two different locations")
		return false
	if idx_a < 0 or idx_a >= _locations.size() or idx_b < 0 or idx_b >= _locations.size():
		_set_status("Invalid selection indices")
		return false
	return true


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
