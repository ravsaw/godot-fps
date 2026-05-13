extends Node
class_name AlifeManager

signal strategic_tick(summary: String)

var _zone_manager: Variant = null
var _squad_manager: Variant = null
var _tick_interval: float = 2.0
var _tick_ttl: float = 2.0
var _tick_index: int = 0
var _last_summary: String = "ALife: n/a"
var _last_dominant_faction: String = "Neutral"
var _away_ticks_by_name: Dictionary = {}
var _return_home_threshold: int = 4


func setup(zone_manager: Variant, squad_manager: Variant) -> void:
	_zone_manager = zone_manager
	_squad_manager = squad_manager


func get_debug_text() -> String:
	return _last_summary


func _process(delta: float) -> void:
	if _zone_manager == null or _squad_manager == null:
		return

	_tick_ttl -= delta
	if _tick_ttl > 0.0:
		return
	_tick_ttl = _tick_interval
	_tick_index += 1

	var moving_count: int = 0
	var resting_count: int = 0
	var control_score: Dictionary = {}
	var snapshot: Array[Dictionary] = _squad_manager.get_snapshot()

	var location_presence: Dictionary = {}
	for info in snapshot:
		var squad_name: String = String(info.get("name", ""))
		var faction_id: int = int(info.get("faction_id", -1))
		var squad_state: int = int(info.get("squad_state", 0))
		var current_location_id: int = int(info.get("current_location_id", -1))
		var home_location_id: int = int(info.get("home_location_id", -1))

		if squad_state == SquadData.STATE_MOVING:
			moving_count += 1
		else:
			resting_count += 1
			control_score[faction_id] = int(control_score.get(faction_id, 0)) + 1
			if current_location_id >= 0:
				var faction_counts: Dictionary = location_presence.get(current_location_id, {})
				faction_counts[faction_id] = int(faction_counts.get(faction_id, 0)) + 1
				location_presence[current_location_id] = faction_counts

		if home_location_id >= 0 and current_location_id != home_location_id:
			_away_ticks_by_name[squad_name] = int(_away_ticks_by_name.get(squad_name, 0)) + 1
			if int(_away_ticks_by_name[squad_name]) >= _return_home_threshold and squad_state != SquadData.STATE_MOVING:
				if _squad_manager.request_return_home_for_squad(squad_name):
					emit_signal("strategic_tick", "ALife order: %s returning to home" % squad_name)
					_away_ticks_by_name[squad_name] = 0
		else:
			_away_ticks_by_name[squad_name] = 0

	_apply_location_ownership_from_presence(location_presence)

	var dominant_faction_name := "Neutral"
	var dominant_score: int = -1
	for key in control_score.keys():
		var score: int = int(control_score[key])
		if score > dominant_score:
			dominant_score = score
			dominant_faction_name = _zone_manager.get_faction_name(int(key))

	var zone_name := String(_zone_manager.get_current_zone_id())
	_last_summary = "ALife t=%d | zone=%s | moving=%d resting=%d | dominant=%s" % [
		_tick_index,
		zone_name,
		moving_count,
		resting_count,
		dominant_faction_name,
	]

	if dominant_faction_name != _last_dominant_faction:
		emit_signal("strategic_tick", "ALife shift: %s now dominant in %s" % [dominant_faction_name, zone_name])
		_last_dominant_faction = dominant_faction_name


func _apply_location_ownership_from_presence(location_presence: Dictionary) -> void:
	if _zone_manager == null:
		return
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		return

	for location_key in location_presence.keys():
		var location_id: int = int(location_key)
		var faction_counts: Dictionary = location_presence[location_key]
		if faction_counts.is_empty():
			continue

		var best_faction_id: int = -1
		var best_count: int = -1
		var second_best_count: int = -1
		for faction_key in faction_counts.keys():
			var count: int = int(faction_counts[faction_key])
			if count > best_count:
				second_best_count = best_count
				best_count = count
				best_faction_id = int(faction_key)
			elif count > second_best_count:
				second_best_count = count

		if best_faction_id < 0:
			continue
		if best_count == second_best_count:
			continue

		var location: Variant = world_graph.get_location(location_id)
		if location == null:
			continue
		if int(location.faction_owner_id) == best_faction_id:
			continue

		location.faction_owner_id = best_faction_id
		emit_signal("strategic_tick", "Loc %s captured by %s" % [_format_location_ref(location_id), _zone_manager.get_faction_name(best_faction_id)])


func _format_location_ref(location_id: int) -> String:
	if location_id < 0:
		return "n/a"
	if _zone_manager != null and _zone_manager.has_method("get_location_key_for_graph_id"):
		var key := String(_zone_manager.get_location_key_for_graph_id(location_id))
		if not key.is_empty():
			return key
	return str(location_id)
