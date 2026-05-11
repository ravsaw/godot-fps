extends Node
class_name NpcManager

signal npc_spawned(npc: Variant)

# NPC Combat & AI Management
var _npc: Variant = null
var _player: Variant = null
var _spawner: SceneSpawner = null
var _scene_root: Node3D = null

var _attack_cooldown: float = 0.0
var _attack_interval: float = 0.65
var _attack_range: float = 18.0
var _damage_per_shot: float = 8.0
var _view_distance: float = 18.0
var _memory_duration: float = 2.5

var _can_see_player: bool = false
var _memory_ttl: float = 0.0
var _last_known_player_pos: Vector3 = Vector3.ZERO
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_pause_ttl: float = 0.0
var _debug_enabled: bool = false
var _debug_ttl: float = 0.0

var _last_distance_to_player: float = 0.0
var _last_los_ok: bool = false
var _last_attack_block_reason: String = "init"
var _respawn_ttl: float = -1.0


func configure_spawn(spawner: SceneSpawner, scene_root: Node3D) -> void:
	_spawner = spawner
	_scene_root = scene_root


func set_npc(npc: Variant) -> void:
	_npc = npc
	_setup_patrol_points()


func set_player(player: Variant) -> void:
	_player = player


func clear_npc() -> void:
	_npc = null


func schedule_respawn(delay_seconds: float) -> void:
	_respawn_ttl = maxf(0.0, delay_seconds)


func set_patrol_points(points: Array[Vector3]) -> void:
	_patrol_points = points


func process(delta: float) -> void:
	_tick_respawn(delta)
	update_awareness(delta)
	update_patrol(delta)
	simulate_attack(delta)
	debug_combat(delta)


func _tick_respawn(delta: float) -> void:
	if _respawn_ttl < 0.0:
		return
	_respawn_ttl = maxf(_respawn_ttl - delta, 0.0)
	if _respawn_ttl > 0.0:
		return
	_respawn_ttl = -1.0
	if _spawner == null or _scene_root == null:
		return

	var respawned_npc: Variant = _spawner.spawn_npc()
	if respawned_npc == null:
		return

	set_npc(respawned_npc)
	if _player != null:
		set_player(_player)
	emit_signal("npc_spawned", respawned_npc)


func update_awareness(delta: float) -> void:
	if _npc == null or not is_instance_valid(_npc) or _player == null:
		_can_see_player = false
		_memory_ttl = 0.0
		_patrol_pause_ttl = 0.0
		return
	if not (_npc as Node3D).is_inside_tree() or not (_player as Node3D).is_inside_tree():
		return

	var npc_origin := Vector3(_npc.global_position) + Vector3(0, 1.4, 0)
	var player_target := Vector3(_player.global_position) + Vector3(0, 1.2, 0)
	if _player.has_node("PlayerCamera"):
		var cam_node: Node = _player.get_node("PlayerCamera")
		if cam_node is Node3D:
			player_target = (cam_node as Node3D).global_position

	var to_player: Vector3 = player_target - npc_origin
	var distance: float = to_player.length()
	var in_range: bool = distance <= _view_distance and distance > 0.001
	_last_distance_to_player = distance
	var los_ok := _has_line_of_sight(npc_origin, player_target)
	var close_quarters_ok := distance <= 3.0
	_can_see_player = in_range and (los_ok or close_quarters_ok)
	_last_los_ok = _can_see_player

	if _can_see_player:
		var look_target := Vector3(player_target.x, _npc.global_position.y, player_target.z)
		if look_target.distance_to(_npc.global_position) > 0.05:
			_npc.look_at(look_target, Vector3.UP)

		_memory_ttl = _memory_duration
		_last_known_player_pos = Vector3(_player.global_position)
		if _npc.has_method("set_target_position"):
			_npc.call("set_target_position", _last_known_player_pos)
		if _npc.has_method("set_state"):
			_npc.call("set_state", 3)
	else:
		_memory_ttl = max(_memory_ttl - delta, 0.0)
		if _memory_ttl > 0.0 and _npc.has_method("set_target_position"):
			_npc.call("set_target_position", _last_known_player_pos)
			if _npc.has_method("set_state"):
				_npc.call("set_state", 2)


func update_patrol(delta: float) -> void:
	if _npc == null or not is_instance_valid(_npc):
		return
	if _patrol_points.is_empty():
		return
	if _can_see_player or _memory_ttl > 0.0:
		return

	if _npc.has_method("set_state"):
		_npc.call("set_state", 1)

	_patrol_pause_ttl -= delta
	if _patrol_pause_ttl <= 0.0:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		var target_pos = _patrol_points[_patrol_index]
		if _npc.has_method("set_target_position"):
			_npc.call("set_target_position", target_pos)
		_patrol_pause_ttl = 0.55


func simulate_attack(delta: float) -> void:
	if _npc == null or not is_instance_valid(_npc) or _player == null:
		return

	_attack_cooldown = max(_attack_cooldown - delta, 0.0)

	_last_attack_block_reason = ""

	if not _can_see_player:
		_last_attack_block_reason = "no_los"
		return
	if _attack_cooldown > 0.0:
		_last_attack_block_reason = "cooldown"
		return
	if _npc.global_position.distance_to(_player.global_position) > _attack_range:
		_last_attack_block_reason = "out_range"
		return

	_attack_cooldown = _attack_interval

	if not _npc.has_method("fire_projectile"):
		return

	var npc_pos = _npc.global_position
	var player_pos = _player.global_position
	var direction = (player_pos - npc_pos).normalized()
	_npc.call("fire_projectile", direction, _damage_per_shot)


func debug_combat(delta: float) -> void:
	if not _debug_enabled:
		return
	_debug_ttl -= delta
	if _debug_ttl > 0.0:
		return
	_debug_ttl = 0.6

	var npc_state := -1
	if _npc != null and is_instance_valid(_npc) and _npc.has_method("get_state"):
		npc_state = int(_npc.call("get_state"))

	print(
		"NPC DBG | state=", npc_state,
		" dist=", snappedf(_last_distance_to_player, 0.01),
		" los=", _last_los_ok,
		" cd=", snappedf(_attack_cooldown, 0.01),
		" can_see=", _can_see_player,
		" block=", _last_attack_block_reason
	)


func _setup_patrol_points() -> void:
	_patrol_points = [
		Vector3(-8, 1, -8),
		Vector3(8, 1, -8),
		Vector3(8, 1, 8),
		Vector3(-8, 1, 8),
	]


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	if _npc == null or not is_instance_valid(_npc):
		return false
	if not (_npc as Node3D).is_inside_tree():
		return false
	var space_state = (_npc as Node3D).get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.hit_from_inside = false
	var result = space_state.intersect_ray(query)
	return result.is_empty()
