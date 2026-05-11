extends Node
class_name AttachmentManager

signal attachment_event(message: String)

var _weapon: Variant = null
var _inventory: InventoryManager = null
var _hud: Variant = null
var _equipped: Dictionary = {}
var _menu_open: bool = false
var _menu_index: int = 0
var _menu_items: Array[String] = ["ACOG Scope", "Suppressor", "Stock Attachment"]


func setup(weapon: Variant, inventory: InventoryManager, hud: Variant) -> void:
	_weapon = weapon
	_inventory = inventory
	_hud = hud
	refresh_visuals()


func mark_equipped(item_name: String) -> void:
	_equipped[item_name] = true
	refresh_visuals()


func try_equip(item_name: String) -> void:
	if _weapon == null or _inventory == null:
		return
	if bool(_equipped.get(item_name, false)):
		emit_signal("attachment_event", "Already equipped: " + item_name)
		return
	if not _inventory.has_item(item_name, 1):
		emit_signal("attachment_event", "Missing: " + item_name)
		return

	var ok: bool = false
	if item_name == "ACOG Scope" and _weapon.has_method("mount_acog_scope"):
		_weapon.call("mount_acog_scope")
		ok = true
	elif item_name == "Suppressor" and _weapon.has_method("mount_suppressor"):
		_weapon.call("mount_suppressor")
		ok = true
	elif item_name == "Stock Attachment" and _weapon.has_method("mount_stock"):
		_weapon.call("mount_stock")
		ok = true

	if not ok:
		emit_signal("attachment_event", "Cannot equip: " + item_name)
		return

	if _inventory.consume_item(item_name, 1):
		_equipped[item_name] = true
		refresh_visuals()
		emit_signal("attachment_event", "Equipped: " + item_name)


func clear_all() -> void:
	if _weapon != null and _weapon.has_method("clear_all_attachments"):
		_weapon.call("clear_all_attachments")
	_equipped.clear()
	refresh_visuals()
	emit_signal("attachment_event", "Attachments cleared")


func toggle_menu() -> void:
	_menu_open = not _menu_open
	_update_menu_hud()


func is_menu_open() -> bool:
	return _menu_open


func menu_navigate(dir: int) -> void:
	_menu_index = posmod(_menu_index + dir, _menu_items.size())
	_update_menu_hud()


func menu_confirm() -> void:
	try_equip(_menu_items[_menu_index])
	_update_menu_hud()


func update_hud_panels() -> void:
	_update_loadout_hud()
	_update_panel_hud()
	_update_menu_hud()


func refresh_visuals() -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	_clear_visuals()
	if bool(_equipped.get("ACOG Scope", false)):
		_add_visual_box("ACOG", Vector3(0.0, 0.09, -0.03), Vector3(0.08, 0.06, 0.12), Color(0.16, 0.16, 0.18))
	if bool(_equipped.get("Suppressor", false)):
		_add_visual_cylinder("Suppressor", Vector3(0.0, 0.0, -0.36), 0.03, 0.26, Color(0.12, 0.12, 0.12))
	if bool(_equipped.get("Stock Attachment", false)):
		_add_visual_box("Stock", Vector3(0.0, -0.03, 0.30), Vector3(0.10, 0.08, 0.16), Color(0.22, 0.18, 0.12))
	update_hud_panels()


func _clear_visuals() -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	for child: Node in _weapon.get_children():
		if String(child.name).begins_with("AttachmentVisual_"):
			child.queue_free()


func _add_visual_box(part_name: String, local_pos: Vector3, size: Vector3, color: Color) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "AttachmentVisual_" + part_name
	mesh_inst.position = local_pos
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission = color * 0.15
	mesh_inst.material_override = mat
	_weapon.add_child(mesh_inst)


func _add_visual_cylinder(part_name: String, local_pos: Vector3, radius: float, height: float, color: Color) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "AttachmentVisual_" + part_name
	mesh_inst.position = local_pos
	mesh_inst.rotation_degrees = Vector3(90, 0, 0)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_inst.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission = color * 0.1
	mesh_inst.material_override = mat
	_weapon.add_child(mesh_inst)


func _update_loadout_hud() -> void:
	if _hud == null or not _hud.has_method("set_loadout_text"):
		return
	var scope := "ACOG" if bool(_equipped.get("ACOG Scope", false)) else "none"
	var barrel := "Suppressor" if bool(_equipped.get("Suppressor", false)) else "none"
	var stock := "Combat Stock" if bool(_equipped.get("Stock Attachment", false)) else "none"
	_hud.call("set_loadout_text", "Loadout:\n  Scope: %s\n  Barrel: %s\n  Stock: %s" % [scope, barrel, stock])


func _update_panel_hud() -> void:
	if _hud == null or _inventory == null or not _hud.has_method("set_attachment_panel_text"):
		return
	var inv := _inventory.get_inventory()
	var text := "Attachment Equip:\n"
	text += "  [1] ACOG Scope x%d" % int(inv.get("ACOG Scope", 0))
	if bool(_equipped.get("ACOG Scope", false)):
		text += "  EQUIPPED"
	text += "\n  [2] Suppressor x%d" % int(inv.get("Suppressor", 0))
	if bool(_equipped.get("Suppressor", false)):
		text += "  EQUIPPED"
	text += "\n  [3] Stock Attachment x%d" % int(inv.get("Stock Attachment", 0))
	if bool(_equipped.get("Stock Attachment", false)):
		text += "  EQUIPPED"
	text += "\n  [0] Clear equipped"
	_hud.call("set_attachment_panel_text", text)


func _update_menu_hud() -> void:
	if _hud == null:
		return
	if _hud.has_method("set_attachment_menu_visible"):
		_hud.call("set_attachment_menu_visible", _menu_open)
	if not _menu_open:
		return
	if _inventory == null or not _hud.has_method("set_attachment_menu_text"):
		return
	var inv := _inventory.get_inventory()
	var text := "ATTACHMENT MENU [I close]\nUse Up/Down + Enter\n\n"
	for i in range(_menu_items.size()):
		var item: String = _menu_items[i]
		var prefix := "> " if i == _menu_index else "  "
		var qty: int = int(inv.get(item, 0))
		text += prefix + item + " x" + str(qty)
		if bool(_equipped.get(item, false)):
			text += "  EQUIPPED"
		text += "\n"
	_hud.call("set_attachment_menu_text", text)
