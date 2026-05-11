@tool
extends Resource
class_name WorldLayoutData

@export var zone_id: StringName = &"zone_a"
@export var locations: Array[SmartLocation] = []

# New format for multi-region authoring.
# Backward compatibility: old files still use zone_id + locations.
@export var zones: Array[StringName] = []
@export var zone_connections: Array[Dictionary] = []
