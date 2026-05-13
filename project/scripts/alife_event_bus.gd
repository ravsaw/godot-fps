extends RefCounted
class_name AlifeEventBus

const CAUSE_ANY: StringName = &"*"

var _queue: Array[Dictionary] = []
var _subscribers_by_cause: Dictionary = {}


func subscribe(cause_type: StringName, handler: Callable) -> void:
	if not handler.is_valid():
		return
	var key := String(cause_type)
	var handlers: Array = _subscribers_by_cause.get(key, [])
	handlers.append(handler)
	_subscribers_by_cause[key] = handlers


func publish(event_data: Dictionary) -> bool:
	if not _validate_event_payload(event_data):
		return false
	_queue.append(event_data.duplicate(true))
	return true


func drain(max_events: int) -> Dictionary:
	var budget: int = max(0, max_events)
	if budget <= 0 or _queue.is_empty():
		return {"processed": 0, "deferred": _queue.size()}

	var processed: int = 0
	while processed < budget and not _queue.is_empty():
		var event_data: Dictionary = _queue.pop_front()
		_dispatch_event(event_data)
		processed += 1

	return {"processed": processed, "deferred": _queue.size()}


func pending_count() -> int:
	return _queue.size()


func _dispatch_event(event_data: Dictionary) -> void:
	var cause_key := String(event_data.get("cause_type", ""))
	var handlers: Array = _subscribers_by_cause.get(cause_key, [])
	for handler in handlers:
		if handler is Callable and handler.is_valid():
			handler.call(event_data)

	var wildcard_handlers: Array = _subscribers_by_cause.get(String(CAUSE_ANY), [])
	for handler in wildcard_handlers:
		if handler is Callable and handler.is_valid():
			handler.call(event_data)


func _validate_event_payload(event_data: Dictionary) -> bool:
	if event_data.is_empty():
		push_warning("AlifeEventBus: rejected empty event payload")
		return false

	var required_fields := ["schema_version", "cause_id", "cause_type", "source", "location_key"]
	for field_name in required_fields:
		if not event_data.has(field_name):
			push_warning("AlifeEventBus: missing required field '%s'" % field_name)
			return false

	if int(event_data.get("schema_version", 0)) <= 0:
		push_warning("AlifeEventBus: invalid schema_version")
		return false
	if String(event_data.get("cause_id", "")).is_empty():
		push_warning("AlifeEventBus: invalid cause_id")
		return false
	if String(event_data.get("cause_type", "")).is_empty():
		push_warning("AlifeEventBus: invalid cause_type")
		return false
	if String(event_data.get("source", "")).is_empty():
		push_warning("AlifeEventBus: invalid source")
		return false
	if String(event_data.get("location_key", "")).is_empty():
		push_warning("AlifeEventBus: invalid location_key")
		return false

	return true
