extends Node3D
class_name LootItem

# Loot item that can be picked up
@export var item_name: String = "Item"
@export var item_type: String = "attachment"  # attachment, ammo, health, etc.
@export var quantity: int = 1

var _collision_area: Area3D = null
var _player_in_range: CharacterBody3D = null


func _ready() -> void:
	name = item_name
	_setup_collision()


func _setup_collision() -> void:
	var area := Area3D.new()
	area.name = "LootArea"
	add_child(area)
	
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.add_child(collision_shape)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_collision_area = area


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "PlayerController":
		_player_in_range = body
		var type_tag := item_type.to_upper()
		emit_signal("interaction_prompt", "[E] Pick up [" + type_tag + "] " + item_name + " x" + str(quantity), true, item_type)


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		emit_signal("interaction_prompt", "", false, "")


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null or event == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		emit_signal("interaction_prompt", "", false, "")
		emit_signal("loot_picked_up", self)
		queue_free()


signal loot_picked_up(item: LootItem)
signal interaction_prompt(text: String, visible: bool, item_type: String)
