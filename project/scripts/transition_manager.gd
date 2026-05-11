extends Node
class_name TransitionManager

# Monitors player proximity to ALife squads.
# When a squad enters player_radius → spawn NpcAgent3D as 3D proxy.
# When a squad leaves → remove the proxy node, ALife simulation continues.

const _CHECK_INTERVAL: float = 0.5
const _PLAYER_RADIUS: float = 30.0

var _player: Variant = null
var _squad_manager: Variant = null
var _scene_root: Node3D = null
var _check_ttl: float = 0.0
var _spawned: Dictionary = {}  # squad_name -> NpcAgent3D node


func setup(player: Variant, squad_manager: Variant, scene_root: Node3D) -> void:
	_player = player
	_squad_manager = squad_manager
	_scene_root = scene_root


func get_debug_text() -> String:
	return "3D proxies: %d" % _spawned.size()


func _process(delta: float) -> void:
	_check_ttl -= delta
	if _check_ttl > 0.0:
		return
	_check_ttl = _CHECK_INTERVAL
	_tick_transitions()


func _tick_transitions() -> void:
	if _player == null or _squad_manager == null:
		return
	if not is_instance_valid(_player):
		return

	var player_pos: Vector3 = _player.global_position
	var snapshot: Array[Dictionary] = _squad_manager.get_snapshot()
	var live_names: Dictionary = {}

	for info in snapshot:
		var squad_name: String = String(info.get("name", ""))
		if squad_name.is_empty():
			continue
		live_names[squad_name] = true

		var squad_pos: Vector3 = info.get("position", Vector3.ZERO)
		var dist: float = player_pos.distance_to(squad_pos)
		var is_spawned: bool = _spawned.has(squad_name)

		if dist <= _PLAYER_RADIUS and not is_spawned:
			_spawn_proxy(squad_name, squad_pos, info)
		elif dist > _PLAYER_RADIUS and is_spawned:
			_despawn_proxy(squad_name)
		elif is_spawned:
			# Keep proxy position in sync with ALife simulation
			var node: Variant = _spawned.get(squad_name)
			if node != null and is_instance_valid(node):
				node.position = squad_pos

	# Remove proxies for squads that no longer exist in the simulation
	for spawned_name in _spawned.keys():
		if not live_names.has(spawned_name):
			_despawn_proxy(spawned_name)


func _spawn_proxy(squad_name: String, position: Vector3, info: Dictionary) -> void:
	if not ClassDB.class_exists("NpcAgent3D"):
		return

	var npc: Variant = ClassDB.instantiate("NpcAgent3D")
	npc.name = "ALifeProxy_" + squad_name.replace(" ", "")
	npc.position = position

	# Collision shape (required for CharacterBody3D)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.76
	capsule.radius = 0.35
	shape.shape = capsule
	npc.add_child(shape)

	# Faction-colored mesh
	var faction_id: int = int(info.get("faction_id", -1))
	var color := _faction_color(faction_id)
	var mesh_inst := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.height = 1.76
	cap_mesh.radius = 0.35
	mesh_inst.mesh = cap_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.3
	mesh_inst.material_override = mat
	npc.add_child(mesh_inst)

	# Squad name label
	var label := Label3D.new()
	label.text = squad_name + "\n[ALife 3D]"
	label.position = Vector3(0, 1.5, 0)
	label.modulate = color
	npc.add_child(label)

	_scene_root.add_child(npc)
	_spawned[squad_name] = npc


func _despawn_proxy(squad_name: String) -> void:
	var node: Variant = _spawned.get(squad_name, null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_spawned.erase(squad_name)


func _faction_color(faction_id: int) -> Color:
	match faction_id:
		1: return Color(0.35, 0.95, 0.35)   # Scav - green
		2: return Color(1.0, 0.45, 0.25)     # Threshold - orange
		_: return Color(0.7, 0.7, 0.7)       # Unknown - grey
