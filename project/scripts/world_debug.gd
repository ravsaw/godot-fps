extends Node
class_name WorldDebugManager

signal zone_gate_entered(body: Node3D, target_zone_id: StringName, from_location_id: int)

var _zone_manager: Variant = null
var _scene_root: Node3D = null
var _root: Node3D = null


func setup(zone_manager: Variant, scene_root: Node3D) -> void:
	_zone_manager = zone_manager
	_scene_root = scene_root


func rebuild() -> void:
	if _zone_manager == null:
		return
	if _root != null and is_instance_valid(_root):
		_root.queue_free()

	_root = Node3D.new()
	_root.name = "WorldDebugGraph"
	_scene_root.add_child(_root)

	var zone_ids: Array[StringName] = _zone_manager.get_all_zone_ids()
	for zone_id in zone_ids:
		var locations: Array[SmartLocation] = _zone_manager.get_locations_for_zone(zone_id)
		var by_id: Dictionary = {}
		for location in locations:
			if location == null:
				continue
			by_id[location.location_id] = location
			_add_location_node(location)

		for location in locations:
			if location == null:
				continue
			for neighbor_raw in location.neighbor_location_ids:
				var neighbor_id := int(neighbor_raw)
				if neighbor_id <= location.location_id:
					continue
				if not by_id.has(neighbor_id):
					continue
				var neighbor: SmartLocation = by_id[neighbor_id]
				var dist := location.world_position.distance_to(neighbor.world_position)
				_add_edge(location.world_position, neighbor.world_position, dist)


func _add_location_node(location: SmartLocation) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "Loc_%d" % location.location_id
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	marker.mesh = sphere
	marker.position = location.world_position + Vector3(0, 0.25, 0)

	var mat := StandardMaterial3D.new()
	match String(location.location_type):
		"camp":
			mat.albedo_color = Color(0.35, 0.95, 0.35)
		"trader":
			mat.albedo_color = Color(0.35, 0.75, 1.0)
		"checkpoint":
			mat.albedo_color = Color(1.0, 0.45, 0.25)
		"anomaly":
			mat.albedo_color = Color(0.95, 0.35, 1.0)
		"gate":
			mat.albedo_color = Color(1.0, 0.95, 0.35)
		_:
			mat.albedo_color = Color(0.85, 0.85, 0.85)
	mat.emission = mat.albedo_color * 0.12
	marker.material_override = mat
	_root.add_child(marker)

	var label := Label3D.new()
	var owner_name := "Neutral"
	if _zone_manager != null:
		owner_name = _zone_manager.get_faction_name(location.faction_owner_id)
	label.text = "%s:%d\n%s\nOwner: %s" % [String(location.zone_id), location.location_id, location.location_name, owner_name]
	label.position = location.world_position + Vector3(0, 0.9, 0)
	label.modulate = Color(1, 1, 1, 0.95)
	_root.add_child(label)

	if location.location_type == &"gate":
		var portal := MeshInstance3D.new()
		var portal_mesh := CylinderMesh.new()
		portal_mesh.top_radius = 0.65
		portal_mesh.bottom_radius = 0.65
		portal_mesh.height = 5.2
		portal.mesh = portal_mesh
		portal.position = location.world_position + Vector3(0, 2.6, 0)
		var portal_mat := StandardMaterial3D.new()
		portal_mat.albedo_color = Color(0.1, 0.95, 1.0, 0.35)
		portal_mat.emission_enabled = true
		portal_mat.emission = Color(0.1, 0.95, 1.0)
		portal_mat.emission_energy_multiplier = 2.6
		portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		portal.material_override = portal_mat
		_root.add_child(portal)

		_add_gate_trigger(location)


func _add_edge(from_pos: Vector3, to_pos: Vector3, edge_distance: float) -> void:
	var delta := to_pos - from_pos
	var distance := delta.length()
	if distance < 0.01:
		return

	var edge := MeshInstance3D.new()
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = 0.05
	line_mesh.bottom_radius = 0.05
	line_mesh.height = distance
	edge.mesh = line_mesh
	edge.position = from_pos + delta * 0.5 + Vector3(0, 0.08, 0)
	edge.look_at_from_position(edge.position, to_pos + Vector3(0, 0.08, 0), Vector3.UP)
	edge.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.65, 0.72, 0.85, 0.75)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge.material_override = line_mat
	_root.add_child(edge)

	var distance_label := Label3D.new()
	distance_label.text = "%.1fm" % edge_distance
	distance_label.position = from_pos + delta * 0.5 + Vector3(0, 0.55, 0)
	distance_label.modulate = Color(0.88, 0.92, 1.0, 0.9)
	_root.add_child(distance_label)


func _add_gate_trigger(location: SmartLocation) -> void:
	var target_zone: StringName = _zone_manager.get_gate_target_zone(location.zone_id, location.location_id)
	if target_zone == &"":
		return

	var trigger := Area3D.new()
	trigger.name = "GateTrigger_%d" % location.location_id
	trigger.position = location.world_position + Vector3(0, 0.85, 0)
	trigger.monitoring = true
	trigger.monitorable = true
	trigger.collision_layer = 0
	trigger.collision_mask = 0x7fffffff

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 2.8
	capsule.height = 3.2
	shape.shape = capsule
	trigger.add_child(shape)

	trigger.body_entered.connect(Callable(self, "_on_gate_body_entered").bind(target_zone, location.location_id))
	_root.add_child(trigger)


func _on_gate_body_entered(body: Node3D, target_zone_id: StringName, from_location_id: int) -> void:
	emit_signal("zone_gate_entered", body, target_zone_id, from_location_id)
