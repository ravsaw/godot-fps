@tool
extends EditorPlugin

const DOCK_SCRIPT := preload("res://addons/world_builder/world_builder_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DOCK_SCRIPT.new()
	_dock.name = "World Builder"
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
