extends Node
class_name AlifeManager

signal strategic_tick(summary: String)

const ALIFE_EVENT_BUS_SCRIPT := preload("res://scripts/alife_event_bus.gd")
const _EVENT_SCHEMA_VERSION: int = 1
const _EVENT_BUDGET_PER_TICK: int = 6
const _CAUSE_LOCATION_CAPTURED: StringName = &"LOCATION_CAPTURED"
const _CAUSE_DOMINANCE_SHIFT: StringName = &"DOMINANCE_SHIFT"
const _CAUSE_RETURN_HOME_ORDER: StringName = &"RETURN_HOME_ORDER"

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
var _event_id_seq: int = 0


func setup(zone_manager: Variant, squad_manager: Variant) -> void:
	_zone_manager = zone_manager
	_squad_manager = squad_manager
	if _event_bus == null:
		_event_bus = ALIFE_EVENT_BUS_SCRIPT.new()
		_event_bus.subscribe(&"*", Callable(self, "_on_event_trace"))


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
		_publish_cause(_CAUSE_DOMINANCE_SHIFT, -1, {
			"zone": zone_name,
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


func _format_location_ref(location_id: int) -> String:
	if location_id < 0:
		return "n/a"
	if _zone_manager != null and _zone_manager.has_method("get_location_key_for_graph_id"):
		var key := String(_zone_manager.get_location_key_for_graph_id(location_id))
		if not key.is_empty():
			return key
	return str(location_id)
