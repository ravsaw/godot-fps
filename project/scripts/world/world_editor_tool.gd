@tool
extends Node3D
class_name WorldEditorTool

## @tool helper for editor-time map visualization and initialization
## Generates world_layout.tres on first run, visualizes SmartLocations and edges

const LAYOUT_PATH := "res://data/world_layout.tres"
const LAYOUT_DATA_SCRIPT := preload("res://scripts/world/world_layout_data.gd")
const ZONE_MANAGER_SCRIPT := preload("res://scripts/world/zone_manager.gd")

var _is_editing: bool = false
var _visual_root: Node3D = null
var _last_layout_mtime: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	
	_is_editing = true
	_ensure_layout_file_exists()
	_rebuild_editor_visuals()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Detect file changes
	if ResourceLoader.exists(LAYOUT_PATH):
		var mtime := FileAccess.get_modified_time(LAYOUT_PATH)
		if mtime != _last_layout_mtime:
			_last_layout_mtime = mtime
			_rebuild_editor_visuals()


func _ensure_layout_file_exists() -> void:
	if ResourceLoader.exists(LAYOUT_PATH):
		_last_layout_mtime = FileAccess.get_modified_time(LAYOUT_PATH)
		return
	
	# Generate initial layout from hardcoded zone data
	var layout := LAYOUT_DATA_SCRIPT.new()
	var all_locations: Array[SmartLocation] = []
	var zone_connections: Array[Dictionary] = [
		{"from_zone": &"zone_a", "to_zone": &"zone_t_ab", "from_location_id": 8},
		{"from_zone": &"zone_t_ab", "to_zone": &"zone_a", "from_location_id": 1},
		{"from_zone": &"zone_t_ab", "to_zone": &"zone_b", "from_location_id": 3},
		{"from_zone": &"zone_b", "to_zone": &"zone_t_ab", "from_location_id": 8},
		{"from_zone": &"zone_b", "to_zone": &"zone_t_bc", "from_location_id": 9},
		{"from_zone": &"zone_t_bc", "to_zone": &"zone_b", "from_location_id": 1},
		{"from_zone": &"zone_t_bc", "to_zone": &"zone_c", "from_location_id": 3},
		{"from_zone": &"zone_c", "to_zone": &"zone_t_bc", "from_location_id": 8},
	]
	
	# Collect all zone locations
	for zone_id in [&"zone_a", &"zone_t_ab", &"zone_b", &"zone_t_bc", &"zone_c"]:
		all_locations.append_array(_build_locations_for_zone(zone_id))
	
	layout.zone_id = &"zone_a"
	layout.locations = all_locations
	layout.zone_connections = zone_connections
	layout.zones = [&"zone_a", &"zone_t_ab", &"zone_b", &"zone_t_bc", &"zone_c"]
	
	# Ensure parent dir exists
	DirAccess.make_abs_absolute("res://data")
	var err := ResourceSaver.save(layout, LAYOUT_PATH)
	if err != OK:
		push_error("WorldEditorTool: failed to save layout: %s" % error_string(err))
		return
	
	print("WorldEditorTool: generated initial layout at %s" % LAYOUT_PATH)
	_last_layout_mtime = FileAccess.get_modified_time(LAYOUT_PATH)


func _rebuild_editor_visuals() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	_visual_root = null
	
	if not ResourceLoader.exists(LAYOUT_PATH):
		return
	
	var layout: Variant = ResourceLoader.load(LAYOUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if layout == null or not (layout is WorldLayoutData):
		return
	
	_visual_root = Node3D.new()
	_visual_root.name = "EditorLocations"
	add_child(_visual_root)
	
	# Visualize locations
	var locations: Array[SmartLocation] = layout.locations if layout.locations is Array else []
	var location_map: Dictionary = {}
	
	for loc in locations:
		if loc == null:
			continue
		location_map[loc.location_id] = loc
		_draw_location_marker(_visual_root, loc)
	
	# Visualize edges
	for loc in locations:
		if loc == null:
			continue
		for neighbor_id in loc.neighbor_location_ids:
			var neighbor: SmartLocation = location_map.get(neighbor_id, null)
			if neighbor != null and loc.zone_id == neighbor.zone_id:
				# Draw Bezier curve if path_points defined, otherwise draw straight line
				if loc.path_points.size() > 0:
					_draw_bezier_curve(_visual_root, loc.world_position, neighbor.world_position, loc.path_points)
				else:
					_draw_edge(_visual_root, loc.world_position, neighbor.world_position)


func _draw_location_marker(parent: Node3D, location: SmartLocation) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radii = Vector3.ONE * 0.3
	marker.mesh = mesh
	
	# Color by type
	var mat := StandardMaterial3D.new()
	match location.location_type:
		&"camp":
			mat.albedo_color = Color.GREEN
		&"trader":
			mat.albedo_color = Color.CYAN
		&"ruins":
			mat.albedo_color = Color.GRAY
		&"checkpoint":
			mat.albedo_color = Color.YELLOW
		&"warehouse":
			mat.albedo_color = Color.MAGENTA
		&"anomaly":
			mat.albedo_color = Color.RED
		&"gate":
			mat.albedo_color = Color.WHITE
		&"crossroad":
			mat.albedo_color = Color.BLUE
		_:
			mat.albedo_color = Color.LIGHT_GRAY
	
	marker.material = mat
	marker.position = location.world_position
	marker.name = location.location_name
	parent.add_child(marker)
	
	# Label
	var label := Label3D.new()
	label.text = "%s (%s)" % [location.location_name, location.location_type]
	label.position = location.world_position + Vector3(0, 1, 0)
	label.font_size = 24
	parent.add_child(label)


func _draw_edge(parent: Node3D, from_pos: Vector3, to_pos: Vector3) -> void:
	var line := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from_pos)
	mesh.surface_add_vertex(to_pos)
	mesh.surface_end()
	line.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.5, 0.5, 0.7)
	mat.wire_frame = false
	line.material = mat
	parent.add_child(line)


func _draw_bezier_curve(parent: Node3D, from_pos: Vector3, to_pos: Vector3, control_points: PackedVector3Array) -> void:
	# Draw Bezier curve as a polyline through control points
	var line := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Draw from start to control points to end
	var current_pos := from_pos
	for control_point in control_points:
		mesh.surface_add_vertex(current_pos)
		mesh.surface_add_vertex(control_point)
		current_pos = control_point
	
	# Final segment to end
	mesh.surface_add_vertex(current_pos)
	mesh.surface_add_vertex(to_pos)
	mesh.surface_end()
	line.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.2, 1.0)  # Yellow for Bezier curves
	mat.wire_frame = false
	line.material = mat
	parent.add_child(line)
	
	# Draw control points as small markers
	for control_point in control_points:
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radii = Vector3.ONE * 0.15
		marker.mesh = sphere
		marker.position = control_point
		
		var ctrl_mat := StandardMaterial3D.new()
		ctrl_mat.albedo_color = Color(1.0, 0.8, 0.0, 0.8)  # Darker yellow
		marker.material = ctrl_mat
		parent.add_child(marker)


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
	location.zone_id = zone_id
	location.location_type = location_type
	location.world_position = world_position
	location.neighbor_location_ids = neighbors
	location.faction_owner_id = _get_default_owner_for(location_type)
	return location


func _get_default_owner_for(location_type: StringName) -> int:
	const FACTION_SCAVENGERS := 1
	const FACTION_THRESHOLD_GUARDIANS := 2
	const FACTION_NONE := -1
	
	if location_type in [&"camp", &"trader", &"ruins"]:
		return FACTION_SCAVENGERS
	if location_type in [&"checkpoint", &"gate"]:
		return FACTION_THRESHOLD_GUARDIANS
	return FACTION_NONE
