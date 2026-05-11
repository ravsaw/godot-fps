extends RefCounted

var _locations: Dictionary = {}  # location_id -> SmartLocation
var _edge_distances: Dictionary = {}  # location_id -> { neighbor_id: distance }


func set_locations(locations: Array[SmartLocation]) -> void:
	_locations.clear()
	_edge_distances.clear()
	for location in locations:
		if location == null:
			continue
		_locations[location.location_id] = location
	_rebuild_edges()


func add_location(location: SmartLocation) -> void:
	if location == null:
		return
	_locations[location.location_id] = location
	_rebuild_edges()


func get_location(location_id: int) -> SmartLocation:
	if not _locations.has(location_id):
		return null
	return _locations[location_id] as SmartLocation


func get_neighbors(location_id: int) -> PackedInt32Array:
	if not _edge_distances.has(location_id):
		return PackedInt32Array()
	var neighbors := PackedInt32Array()
	for neighbor_id in _edge_distances[location_id].keys():
		neighbors.append(int(neighbor_id))
	return neighbors


func get_neighbor_distances(location_id: int) -> Dictionary:
	if not _edge_distances.has(location_id):
		return {}
	return (_edge_distances[location_id] as Dictionary).duplicate(true)


func has_connection(from_id: int, to_id: int) -> bool:
	return get_connection_distance(from_id, to_id) >= 0.0


func get_connection_distance(from_id: int, to_id: int) -> float:
	if from_id == to_id:
		return 0.0
	if not _locations.has(from_id) or not _locations.has(to_id):
		return -1.0

	var distances: Dictionary = {from_id: 0.0}
	var pending: Array[int] = [from_id]

	while not pending.is_empty():
		var current_id := _pop_closest_pending(pending, distances)
		var current_distance: float = float(distances.get(current_id, INF))
		if current_id == to_id:
			return current_distance

		var neighbor_distances := get_neighbor_distances(current_id)
		for neighbor_key in neighbor_distances.keys():
			var neighbor_id := int(neighbor_key)
			var edge_distance: float = float(neighbor_distances[neighbor_key])
			var candidate_distance := current_distance + edge_distance
			if candidate_distance < float(distances.get(neighbor_id, INF)):
				distances[neighbor_id] = candidate_distance
				if not pending.has(neighbor_id):
					pending.append(neighbor_id)

	return -1.0


func get_shortest_path(from_id: int, to_id: int) -> Array[int]:
	if not _locations.has(from_id) or not _locations.has(to_id):
		return []
	if from_id == to_id:
		return [from_id]

	var distances: Dictionary = {from_id: 0.0}
	var previous: Dictionary = {}
	var pending: Array[int] = [from_id]

	while not pending.is_empty():
		var current_id := _pop_closest_pending(pending, distances)
		if current_id == to_id:
			break

		var current_distance: float = float(distances.get(current_id, INF))
		var neighbor_distances := get_neighbor_distances(current_id)
		for neighbor_key in neighbor_distances.keys():
			var neighbor_id := int(neighbor_key)
			var edge_distance: float = float(neighbor_distances[neighbor_key])
			var candidate_distance := current_distance + edge_distance
			if candidate_distance < float(distances.get(neighbor_id, INF)):
				distances[neighbor_id] = candidate_distance
				previous[neighbor_id] = current_id
				if not pending.has(neighbor_id):
					pending.append(neighbor_id)

	if not previous.has(to_id):
		return []

	var path: Array[int] = [to_id]
	var cursor := to_id
	while previous.has(cursor):
		cursor = int(previous[cursor])
		path.push_front(cursor)
		if cursor == from_id:
			break
	return path if not path.is_empty() and path[0] == from_id else []


func get_all_location_ids() -> Array[int]:
	var ids: Array[int] = []
	for id_key in _locations.keys():
		ids.append(int(id_key))
	ids.sort()
	return ids


func get_nearest_location_id(world_pos: Vector3) -> int:
	var best_id := -1
	var best_dist_sq := INF

	for id_key in _locations.keys():
		var location: SmartLocation = _locations[id_key] as SmartLocation
		if location == null:
			continue
		var dist_sq := world_pos.distance_squared_to(location.world_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = int(id_key)

	return best_id


func _rebuild_edges() -> void:
	_edge_distances.clear()
	for location_id in _locations.keys():
		_edge_distances[int(location_id)] = {}

	for location_id in _locations.keys():
		var location := _locations[location_id] as SmartLocation
		if location == null:
			continue
		for neighbor_id in location.neighbor_location_ids:
			var neighbor := get_location(int(neighbor_id))
			if neighbor == null:
				continue
			var distance := location.world_position.distance_to(neighbor.world_position)
			(_edge_distances[location.location_id] as Dictionary)[neighbor.location_id] = distance
			(_edge_distances[neighbor.location_id] as Dictionary)[location.location_id] = distance


func _pop_closest_pending(pending: Array[int], distances: Dictionary) -> int:
	var best_index := 0
	var best_id := pending[0]
	var best_distance: float = float(distances.get(best_id, INF))

	for i in range(1, pending.size()):
		var candidate_id := pending[i]
		var candidate_distance: float = float(distances.get(candidate_id, INF))
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_index = i
			best_id = candidate_id

	pending.remove_at(best_index)
	return best_id
