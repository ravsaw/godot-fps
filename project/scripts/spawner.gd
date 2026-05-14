extends Node
class_name SceneSpawner

# Entity & Environment Spawning

var _player_spawn_position: Vector3 = Vector3(10, 10, 0)
var _npc_spawn_position: Vector3 = Vector3(0, 0.5, -8)


func spawn_player() -> Variant:
	if not ClassDB.class_exists("PlayerController"):
		return null

	var player: Variant = ClassDB.instantiate("PlayerController")
	player.name = "PlayerController"
	player.position = _player_spawn_position
	get_tree().get_root().add_child.call_deferred(player)

	# Setup collision
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.height = 1.0
	player_capsule.radius = 0.35
	player_shape.shape = player_capsule
	player_shape.position = Vector3(0, 1.0, 0)
	player.add_child(player_shape)

	# Setup mesh
	var player_mesh := MeshInstance3D.new()
	var player_capsule_mesh := CapsuleMesh.new()
	player_capsule_mesh.height = 1.0
	player_capsule_mesh.radius = 0.35
	player_mesh.mesh = player_capsule_mesh
	player_mesh.position = Vector3(0, 1.0, 0)
	var player_mat := StandardMaterial3D.new()
	player_mat.albedo_color = Color(0.2, 0.55, 1.0, 0.35)
	player_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	player_mesh.material_override = player_mat
	player_mesh.visible = false
	player.add_child(player_mesh)

	# Setup camera
	var cam := Camera3D.new()
	cam.name = "PlayerCamera"
	cam.current = true
	cam.position = Vector3(0, 1.6, 0)
	player.add_child(cam)
	player.set_camera_path(NodePath("PlayerCamera"))

	return player


func spawn_weapon(player: Variant) -> Variant:
	if not ClassDB.class_exists("WeaponBase"):
		return null

	var cam_node = player.get_node_or_null("PlayerCamera")
	if cam_node == null:
		return null

	var weapon: Variant = ClassDB.instantiate("WeaponBase")
	weapon.name = "WeaponBase"
	cam_node.add_child(weapon)
	weapon.position = Vector3(0.25, -0.2, -0.5)
	player.set_weapon_path(NodePath("PlayerCamera/WeaponBase"))

	var weapon_mesh := MeshInstance3D.new()
	var weapon_box := BoxMesh.new()
	weapon_box.size = Vector3(0.16, 0.12, 0.6)
	weapon_mesh.mesh = weapon_box
	weapon_mesh.position = Vector3(0, 0, 0)
	var weapon_mat := StandardMaterial3D.new()
	weapon_mat.albedo_color = Color(0.1, 0.1, 0.12)
	weapon_mesh.material_override = weapon_mat
	weapon.add_child(weapon_mesh)

	# Test: Mount a scope attachment
	if weapon.has_method("mount_acog_scope"):
		weapon.call("mount_acog_scope")

	return weapon


func spawn_npc() -> Variant:
	if not ClassDB.class_exists("NpcAgent3D"):
		return null

	var npc: Variant = ClassDB.instantiate("NpcAgent3D")
	npc.name = "TestNPC"
	npc.position = _npc_spawn_position
	get_tree().get_root().add_child.call_deferred(npc)

	var npc_capsule := CapsuleShape3D.new()
	npc_capsule.height = 1.76
	npc_capsule.radius = 0.35
	var npc_collision_shape := CollisionShape3D.new()
	npc_collision_shape.shape = npc_capsule
	npc.add_child(npc_collision_shape)

	# Head hitbox
	if ClassDB.class_exists("HitboxComponent"):
		var head_box: Variant = ClassDB.instantiate("HitboxComponent")
		head_box.name = "HeadHitbox"
		head_box.damage_multiplier = 2.0
		npc.add_child(head_box)

		var head_area := Area3D.new()
		head_area.name = "HeadArea"
		head_box.add_child(head_area)

		var head_shape := CollisionShape3D.new()
		var head_capsule := CapsuleShape3D.new()
		head_capsule.height = 0.35
		head_capsule.radius = 0.2
		head_shape.shape = head_capsule
		head_shape.position = Vector3(0, 0.9, 0)
		head_area.add_child(head_shape)

	# Body hitbox
	if ClassDB.class_exists("HitboxComponent"):
		var body_box: Variant = ClassDB.instantiate("HitboxComponent")
		body_box.name = "BodyHitbox"
		body_box.damage_multiplier = 1.0
		npc.add_child(body_box)

		var body_area := Area3D.new()
		body_area.name = "BodyArea"
		body_box.add_child(body_area)

		var body_shape := CollisionShape3D.new()
		var body_capsule := CapsuleShape3D.new()
		body_capsule.height = 1.0
		body_capsule.radius = 0.3
		body_shape.shape = body_capsule
		body_shape.position = Vector3(0, 0.3, 0)
		body_area.add_child(body_shape)

	# Visual mesh
	var npc_mesh := MeshInstance3D.new()
	var npc_capsule_mesh := CapsuleMesh.new()
	npc_capsule_mesh.height = 1.76
	npc_capsule_mesh.radius = 0.35
	npc_mesh.mesh = npc_capsule_mesh
	var npc_mat := StandardMaterial3D.new()
	npc_mat.albedo_color = Color(0.8, 0.3, 0.1)
	npc_mesh.material_override = npc_mat
	npc.add_child(npc_mesh)

	return npc


func spawn_environment(scene_root: Node3D) -> void:
	# Add lighting
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 1.5
	scene_root.add_child(sun)

	# Add WorldEnvironment with ambient light
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.ambient_light_energy = 0.6
	world_env.environment = env
	scene_root.add_child(world_env)

	_spawn_zone_floor(scene_root, "FloorZoneA", Vector3(0.0, 0.0, 0.0), Vector3(48, 0.5, 56), Color(0.22, 0.32, 0.18))
	_spawn_zone_floor(scene_root, "FloorZoneTAB", Vector3(36.0, 0.0, 0.0), Vector3(24, 0.5, 28), Color(0.18, 0.34, 0.42))
	_spawn_zone_floor(scene_root, "FloorZoneB", Vector3(72.0, 0.0, 0.0), Vector3(48, 0.5, 56), Color(0.45, 0.25, 0.15))
	_spawn_zone_floor(scene_root, "FloorZoneTBC", Vector3(108.0, 0.0, 0.0), Vector3(24, 0.5, 28), Color(0.20, 0.30, 0.48))
	_spawn_zone_floor(scene_root, "FloorZoneC", Vector3(144.0, 0.0, 0.0), Vector3(48, 0.5, 56), Color(0.28, 0.22, 0.38))


func spawn_loot_item(
		scene_root: Node3D,
		item_name: String,
		item_position: Vector3,
		quantity: int = 1,
		item_type: String = "attachment"
	) -> Variant:
	var loot_script = load("res://scripts/loot_item.gd")
	if loot_script == null:
		return null

	var loot_item: Variant = loot_script.new()
	loot_item.item_name = item_name
	loot_item.item_type = item_type
	loot_item.quantity = quantity
	loot_item.position = item_position
	scene_root.add_child(loot_item)

	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.3
	sphere_mesh.height = 0.6
	mesh_inst.mesh = sphere_mesh

	var loot_mat := StandardMaterial3D.new()
	loot_mat.albedo_color = Color(1.0, 0.84, 0.0)
	loot_mat.emission = Color(1.0, 0.84, 0.0)
	loot_mat.emission_energy = 0.3
	mesh_inst.material_override = loot_mat
	loot_item.add_child(mesh_inst)

	return loot_item


func spawn_loot_items(scene_root: Node3D) -> void:
	var loots: Array = [
		{"name": "ACOG Scope", "pos": Vector3(3, 1.0, 0), "qty": 1},
		{"name": "Ammo Box", "pos": Vector3(-3, 1.0, 3), "qty": 2},
		{"name": "Suppressor", "pos": Vector3(0, 1.0, 5), "qty": 1},
		{"name": "Medical Kit", "pos": Vector3(-5, 1.0, -5), "qty": 1},
		{"name": "Stock Attachment", "pos": Vector3(4, 1.0, 4), "qty": 1},
	]

	for loot_data in loots:
		spawn_loot_item(
			scene_root,
			loot_data["name"],
			loot_data["pos"],
			loot_data["qty"],
			"attachment"
		)


func spawn_navigation_region(scene_root: Node3D) -> void:
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	scene_root.add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_height = 0.25
	nav_mesh.cell_size = 0.3
	nav_mesh.agent_height = 1.76
	nav_mesh.agent_radius = 0.35
	nav_mesh.agent_max_climb = 0.4

	nav_region.navigation_mesh = nav_mesh


func spawn_test_area(scene_root: Node3D) -> void:
	const ROOM_W: float = 20.0
	const ROOM_D: float = 20.0
	const WALL_H: float = 5.0
	const WALL_T: float = 0.5

	# Floor
	_spawn_box(scene_root, "TestFloor",
		Vector3(0, -0.25, 0),
		Vector3(ROOM_W, 0.5, ROOM_D),
		Color(0.30, 0.30, 0.30))

	# Ceiling
	_spawn_box(scene_root, "TestCeiling",
		Vector3(0, WALL_H + 0.25, 0),
		Vector3(ROOM_W, 0.5, ROOM_D),
		Color(0.20, 0.20, 0.20))

	# North wall
	_spawn_box(scene_root, "WallN",
		Vector3(0, WALL_H * 0.5, -ROOM_D * 0.5 - WALL_T * 0.5),
		Vector3(ROOM_W + WALL_T * 2, WALL_H, WALL_T),
		Color(0.38, 0.35, 0.30))

	# South wall
	_spawn_box(scene_root, "WallS",
		Vector3(0, WALL_H * 0.5, ROOM_D * 0.5 + WALL_T * 0.5),
		Vector3(ROOM_W + WALL_T * 2, WALL_H, WALL_T),
		Color(0.38, 0.35, 0.30))

	# West wall
	_spawn_box(scene_root, "WallW",
		Vector3(-ROOM_W * 0.5 - WALL_T * 0.5, WALL_H * 0.5, 0),
		Vector3(WALL_T, WALL_H, ROOM_D),
		Color(0.35, 0.32, 0.28))

	# East wall
	_spawn_box(scene_root, "WallE",
		Vector3(ROOM_W * 0.5 + WALL_T * 0.5, WALL_H * 0.5, 0),
		Vector3(WALL_T, WALL_H, ROOM_D),
		Color(0.35, 0.32, 0.28))

	# A few low boxes to jump on
	_spawn_box(scene_root, "CrateA", Vector3(-4, 0.5, -4), Vector3(1.4, 1.0, 1.4), Color(0.55, 0.40, 0.20))
	_spawn_box(scene_root, "CrateB", Vector3(4, 0.5, 3), Vector3(1.4, 1.0, 1.4), Color(0.55, 0.40, 0.20))
	_spawn_box(scene_root, "CrateC", Vector3(0, 1.0, -6), Vector3(1.4, 2.0, 1.4), Color(0.50, 0.36, 0.18))


func _spawn_box(scene_root: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	scene_root.add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material_override = mat
	body.add_child(mesh)


func set_loaded_zones(scene_root: Node3D, loaded_zones: Array[StringName]) -> void:
	var lod_by_zone: Dictionary = {
		&"zone_a": 0,
		&"zone_t_ab": 0,
		&"zone_b": 0,
		&"zone_t_bc": 0,
		&"zone_c": 0,
	}
	for zone_id in loaded_zones:
		lod_by_zone[zone_id] = 2
	set_zone_lods(scene_root, lod_by_zone)


func set_zone_lods(scene_root: Node3D, lod_by_zone: Dictionary) -> void:
	_set_floor_lod(scene_root.get_node_or_null("FloorZoneA"), int(lod_by_zone.get(&"zone_a", 0)))
	_set_floor_lod(scene_root.get_node_or_null("FloorZoneTAB"), int(lod_by_zone.get(&"zone_t_ab", 0)))
	_set_floor_lod(scene_root.get_node_or_null("FloorZoneB"), int(lod_by_zone.get(&"zone_b", 0)))
	_set_floor_lod(scene_root.get_node_or_null("FloorZoneTBC"), int(lod_by_zone.get(&"zone_t_bc", 0)))
	_set_floor_lod(scene_root.get_node_or_null("FloorZoneC"), int(lod_by_zone.get(&"zone_c", 0)))


func _set_floor_lod(node: Node, lod_level: int) -> void:
	if node == null:
		return
	var loaded_mat: Material = node.get_meta("lod_loaded_mat", null) as Material
	var medium_mat: Material = node.get_meta("lod_medium_mat", null) as Material
	var far_mat: Material = node.get_meta("lod_far_mat", null) as Material
	var material_to_use: Material = far_mat
	if lod_level >= 2:
		material_to_use = loaded_mat
	elif lod_level == 1:
		material_to_use = medium_mat

	var collision_enabled := lod_level >= 2
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_child := child as MeshInstance3D
			mesh_child.set_deferred("visible", true)
			if material_to_use != null:
				mesh_child.set_deferred("material_override", material_to_use)
		elif child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not collision_enabled)


func _spawn_zone_floor(scene_root: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = node_name
	floor_body.position = pos
	scene_root.add_child(floor_body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(0, -0.25, 0)
	floor_body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = Vector3(0, -0.25, 0)
	var loaded_mat := StandardMaterial3D.new()
	loaded_mat.albedo_color = color
	loaded_mat.roughness = 0.85
	mesh.material_override = loaded_mat

	var medium_mat := StandardMaterial3D.new()
	medium_mat.albedo_color = color.darkened(0.25)
	medium_mat.roughness = 0.95

	var far_mat := StandardMaterial3D.new()
	far_mat.albedo_color = color.darkened(0.50)
	far_mat.roughness = 1.0
	far_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	floor_body.set_meta("lod_loaded_mat", loaded_mat)
	floor_body.set_meta("lod_medium_mat", medium_mat)
	floor_body.set_meta("lod_far_mat", far_mat)
	floor_body.add_child(mesh)
