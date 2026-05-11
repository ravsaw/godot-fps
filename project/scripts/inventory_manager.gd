extends Node
class_name InventoryManager

# Inventory & Loot Management
var _inventory: Dictionary = {}  # item_name -> quantity
var _hud: Variant = null


func set_hud(hud: Variant) -> void:
	_hud = hud


func add_to_inventory(item_name: String, quantity: int = 1) -> void:
	if not _inventory.has(item_name):
		_inventory[item_name] = 0
	_inventory[item_name] += quantity
	_update_display()
	print("Inventory: ", _inventory)


func on_loot_picked_up(item: Variant) -> void:
	if item == null or not is_instance_valid(item):
		return
	if item is LootItem:
		add_to_inventory(item.item_name, item.quantity)
		print("Picked up: ", item.item_name, " x", item.quantity)


func has_item(item_name: String, quantity: int = 1) -> bool:
	if not _inventory.has(item_name):
		return false
	return int(_inventory[item_name]) >= quantity


func consume_item(item_name: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not has_item(item_name, quantity):
		return false

	_inventory[item_name] = int(_inventory[item_name]) - quantity
	if int(_inventory[item_name]) <= 0:
		_inventory.erase(item_name)

	_update_display()
	return true


func _update_display() -> void:
	var inv_text := "Inventory:"
	for item_name in _inventory:
		var qty = _inventory[item_name]
		inv_text += "\n  " + item_name + " x" + str(qty)
	
	if _inventory.is_empty():
		inv_text = "Inventory: empty"
	
	if _hud != null and _hud.has_method("set_inventory_text"):
		_hud.call("set_inventory_text", inv_text)


func get_inventory() -> Dictionary:
	return _inventory.duplicate()
