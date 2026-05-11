extends Resource

@export var location_id: int = -1
@export var location_name: String = "Unknown"
@export var zone_id: StringName = &"zone_a"
@export var location_type: StringName = &"camp"
@export var world_position: Vector3 = Vector3.ZERO
@export var max_population: int = 6
@export var faction_owner_id: int = -1
@export var neighbor_location_ids: PackedInt32Array = PackedInt32Array()


func to_debug_string() -> String:
	return "%s (%s)" % [location_name, String(location_type)]
