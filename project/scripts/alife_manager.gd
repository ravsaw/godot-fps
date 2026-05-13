extends Node
class_name AlifeManager

signal strategic_tick(summary: String)

const ALIFE_EVENT_BUS_SCRIPT := preload("res://scripts/alife_event_bus.gd")
const ALIFE_CONSEQUENCE_REGISTRY_SCRIPT := preload("res://scripts/alife_consequence_registry.gd")
const _EVENT_SCHEMA_VERSION: int = 1
const _EVENT_BUDGET_PER_TICK: int = 6
const _CAUSE_LOCATION_CAPTURED: StringName = &"LOCATION_CAPTURED"
const _CAUSE_DOMINANCE_SHIFT: StringName = &"DOMINANCE_SHIFT"
const _CAUSE_RETURN_HOME_ORDER: StringName = &"RETURN_HOME_ORDER"
const _RETALIATE_COOLDOWN_TICKS: int = 3

var _zone_manager: Variant = null
var _squad_manager: Variant = null
var _tick_interval: float = 2.0
var _tick_ttl: float = 2.0
var _tick_index: int = 0
var _last_summary: String = "ALife: n/a"
var _last_dominant_faction: String = "Neutral"
var _away_ticks_by_name: Dictionary = {}
var _return_home_threshold: int = 4
var _event_bus: Variant = null
var _consequence_registry: Variant = null
var _event_id_seq: int = 0
var _last_retaliate_tick_by_squad: Dictionary = {}


func setup(zone_manager: Variant, squad_manager: Variant) -> void:
	_zone_manager = zone_manager
	_squad_manager = squad_manager
	if _event_bus == null:
		_event_bus = ALIFE_EVENT_BUS_SCRIPT.new()
		_event_bus.subscribe(&"*", Callable(self, "_on_event_trace"))
	if _consequence_registry == null:
		_consequence_registry = ALIFE_CONSEQUENCE_REGISTRY_SCRIPT.new()
		_consequence_registry.setup(Callable(self, "_emit_consequence_log"))
		_consequence_registry.register_handler(_CAUSE_LOCATION_CAPTURED, Callable(self, "_handle_consequence_investigate"))
		_consequence_registry.register_handler(_CAUSE_DOMINANCE_SHIFT, Callable(self, "_handle_consequence_retaliate"))
	if _event_bus != null and _consequence_registry != null:
		_event_bus.subscribe(&"*", Callable(_consequence_registry, "handle_event"))


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
					_publish_cause(_CAUSE_RETURN_HOME_ORDER, current_location_id, {
						"squad_name": squad_name,
						"home_location_id": home_location_id,
					})
					_away_ticks_by_name[squad_name] = 0
		else:
			_away_ticks_by_name[squad_name] = 0

	_apply_location_ownership_from_presence(location_presence)

	var dominant_faction_name := "Neutral"
	var dominant_faction_id: int = -1
	var dominant_score: int = -1
	for key in control_score.keys():
		var score: int = int(control_score[key])
		if score > dominant_score:
			dominant_score = score
			dominant_faction_id = int(key)
			dominant_faction_name = _zone_manager.get_faction_name(dominant_faction_id)

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
		_publish_cause(_CAUSE_DOMINANCE_SHIFT, -1, {
			"zone": zone_name,
			"dominant_faction_id": dominant_faction_id,
			"dominant_faction": dominant_faction_name,
		})
		_last_dominant_faction = dominant_faction_name

	_drain_event_bus()


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
		_publish_cause(_CAUSE_LOCATION_CAPTURED, location_id, {
			"faction_id": best_faction_id,
			"faction_name": _zone_manager.get_faction_name(best_faction_id),
		})


func _publish_cause(cause_type: StringName, location_id: int, payload: Dictionary = {}) -> void:
	if _event_bus == null:
		return

	_event_id_seq += 1
	var event_data := {
		"schema_version": _EVENT_SCHEMA_VERSION,
		"cause_id": "alife-%d-%d" % [_tick_index, _event_id_seq],
		"cause_type": String(cause_type),
		"source": "alife_manager",
		"location_key": _format_location_ref(location_id),
		"tick": _tick_index,
		"payload": payload.duplicate(true),
	}
	if not _event_bus.publish(event_data):
		push_warning("AlifeManager: failed to publish event cause=%s" % String(cause_type))


func _drain_event_bus() -> void:
	if _event_bus == null:
		return
	var result: Dictionary = _event_bus.drain(_EVENT_BUDGET_PER_TICK)
	var deferred: int = int(result.get("deferred", 0))
	if deferred > 0:
		emit_signal("strategic_tick", "ALifeEventBus: deferred=%d budget=%d" % [deferred, _EVENT_BUDGET_PER_TICK])


func _on_event_trace(event_data: Dictionary) -> void:
	var cause_type := String(event_data.get("cause_type", "n/a"))
	var location_key := String(event_data.get("location_key", "n/a"))
	var cause_id := String(event_data.get("cause_id", "n/a"))
	emit_signal("strategic_tick", "ALifeEvent: %s @%s [%s]" % [cause_type, location_key, cause_id])


func _emit_consequence_log(message: String) -> void:
	emit_signal("strategic_tick", message)


func _handle_consequence_investigate(event_data: Dictionary) -> Dictionary:
	if _zone_manager == null or _squad_manager == null:
		return {"action": "investigate", "outcome": "skipped:no_runtime_context"}

	var location_key := String(event_data.get("location_key", ""))
	if location_key.is_empty() or location_key == "n/a":
		return {"action": "investigate", "outcome": "skipped:invalid_location_key"}

	var target_location_id: int = int(_zone_manager.get_graph_location_id_from_key(location_key))
	if target_location_id < 0:
		return {"action": "investigate", "outcome": "skipped:unknown_location"}

	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		return {"action": "investigate", "outcome": "skipped:missing_world_graph"}
	var target_location: Variant = world_graph.get_location(target_location_id)
	if target_location == null:
		return {"action": "investigate", "outcome": "skipped:missing_target_location"}

	var payload: Dictionary = event_data.get("payload", {})
	var captured_by_faction: int = int(payload.get("faction_id", -1))
	var target_pos: Vector3 = target_location.world_position

	var best_squad_name: String = ""
	var best_distance: float = INF
	var snapshot: Array[Dictionary] = _squad_manager.get_snapshot()
	for squad_info in snapshot:
		var squad_name: String = String(squad_info.get("name", ""))
		if squad_name.is_empty():
			continue
		var squad_faction_id: int = int(squad_info.get("faction_id", -1))
		if captured_by_faction >= 0 and squad_faction_id == captured_by_faction:
			continue
		if int(squad_info.get("squad_state", 0)) == SquadData.STATE_MOVING:
			continue

		var squad_pos: Vector3 = squad_info.get("position", Vector3.ZERO)
		var dist: float = squad_pos.distance_to(target_pos)
		if dist < best_distance:
			best_distance = dist
			best_squad_name = squad_name

	if best_squad_name.is_empty():
		return {"action": "investigate", "outcome": "skipped:no_candidate"}

	if not _squad_manager.issue_move_squad(best_squad_name, location_key):
		return {"action": "investigate", "outcome": "failed:issue_move"}

	return {
		"action": "investigate",
		"outcome": "issued",
		"squad": best_squad_name,
		"location": location_key,
	}


func _handle_consequence_retaliate(event_data: Dictionary) -> Dictionary:
	if _zone_manager == null or _squad_manager == null:
		return {"action": "retaliate", "outcome": "skipped:no_runtime_context"}

	var payload: Dictionary = event_data.get("payload", {})
	var dominant_faction_id: int = int(payload.get("dominant_faction_id", -1))
	if dominant_faction_id < 0:
		return {"action": "retaliate", "outcome": "skipped:invalid_faction"}

	var target_location_key: String = _pick_retaliate_target_location_key(dominant_faction_id)
	if target_location_key.is_empty():
		return {"action": "retaliate", "outcome": "skipped:no_target_location"}

	var target_location_id: int = int(_zone_manager.get_graph_location_id_from_key(target_location_key))
	if target_location_id < 0:
		return {"action": "retaliate", "outcome": "skipped:invalid_target_location"}
	var world_graph: Variant = _zone_manager.get_world_graph()
	if world_graph == null:
		return {"action": "retaliate", "outcome": "skipped:missing_world_graph"}
	var target_location: Variant = world_graph.get_location(target_location_id)
	if target_location == null:
		return {"action": "retaliate", "outcome": "skipped:missing_target_node"}

	var best_squad_name: String = ""
	var best_distance: float = INF
	var snapshot: Array[Dictionary] = _squad_manager.get_snapshot()
	for squad_info in snapshot:
		var squad_name: String = String(squad_info.get("name", ""))
		if squad_name.is_empty():
			continue
		var squad_faction_id: int = int(squad_info.get("faction_id", -1))
		if squad_faction_id < 0 or squad_faction_id == dominant_faction_id:
			continue
		if int(squad_info.get("squad_state", 0)) == SquadData.STATE_MOVING:
			continue

		var last_tick: int = int(_last_retaliate_tick_by_squad.get(squad_name, -1000))
		if (_tick_index - last_tick) < _RETALIATE_COOLDOWN_TICKS:
			continue

		var squad_pos: Vector3 = squad_info.get("position", Vector3.ZERO)
		var dist: float = squad_pos.distance_to(target_location.world_position)
		if dist < best_distance:
			best_distance = dist
			best_squad_name = squad_name

	if best_squad_name.is_empty():
		return {"action": "retaliate", "outcome": "skipped:no_candidate_or_cooldown"}

	if not _squad_manager.issue_move_squad(best_squad_name, target_location_key):
		return {"action": "retaliate", "outcome": "failed:issue_move"}

	_last_retaliate_tick_by_squad[best_squad_name] = _tick_index
	return {
		"action": "retaliate",
		"outcome": "issued",
		"squad": best_squad_name,
		"location": target_location_key,
	}


func _pick_retaliate_target_location_key(dominant_faction_id: int) -> String:
	if _zone_manager == null:
		return ""
	for loc in _zone_manager.get_locations():
		if loc == null:
			continue
		if int(loc.faction_owner_id) != dominant_faction_id:
			continue
		var location_key: String = String(_zone_manager.get_location_key_for_graph_id(int(loc.location_id)))
		if not location_key.is_empty():
			return location_key
	return ""


func _format_location_ref(location_id: int) -> String:
	if location_id < 0:
		return "n/a"
	if _zone_manager != null and _zone_manager.has_method("get_location_key_for_graph_id"):
		var key := String(_zone_manager.get_location_key_for_graph_id(location_id))
		if not key.is_empty():
			return key
	return str(location_id)
