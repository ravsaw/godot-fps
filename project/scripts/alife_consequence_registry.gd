extends RefCounted
class_name AlifeConsequenceRegistry

var _handlers_by_cause: Dictionary = {}
var _log_event: Callable


func setup(log_event: Callable = Callable()) -> void:
	_log_event = log_event


func register_handler(cause_type: StringName, handler: Callable) -> void:
	if not handler.is_valid():
		return
	_handlers_by_cause[String(cause_type)] = handler


func handle_event(event_data: Dictionary) -> void:
	var cause_type := String(event_data.get("cause_type", ""))
	if cause_type.is_empty():
		_emit_log("ConsequenceRegistry: rejected event with empty cause_type")
		return

	var handler: Callable = _handlers_by_cause.get(cause_type, Callable())
	if not handler.is_valid():
		_emit_log("ConsequenceRegistry: no handler for cause=%s" % cause_type)
		return

	var result: Variant = handler.call(event_data)
	if result is Dictionary:
		var result_dict: Dictionary = result
		var outcome := String(result_dict.get("outcome", "n/a"))
		var action := String(result_dict.get("action", "none"))
		_emit_log("Consequence: cause=%s action=%s outcome=%s" % [cause_type, action, outcome])
		return

	_emit_log("Consequence: cause=%s action=unknown outcome=done" % cause_type)


func _emit_log(message: String) -> void:
	if _log_event.is_valid():
		_log_event.call(message)
