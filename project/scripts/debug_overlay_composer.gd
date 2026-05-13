extends RefCounted
class_name DebugOverlayComposer

const MAP_LEGEND_TEXT: String = "Legend: yellow ring=selected squad, orange orb=goal, orange line=route"
const GATE_HINT_TEXT: String = "Use gate trigger to switch zone"


func compose_world_debug_text(zone_manager: Variant, player: Variant, squad_manager: Variant, alife_manager: Variant) -> String:
	var world_debug_text: String = "World: n/a"
	if zone_manager == null or player == null or not is_instance_valid(player):
		return world_debug_text

	world_debug_text = String(zone_manager.get_zone_debug_text(player.global_position))
	if squad_manager != null:
		world_debug_text += "\n" + String(squad_manager.get_status_text())
	if alife_manager != null:
		world_debug_text += "\n" + String(alife_manager.get_debug_text())
	return world_debug_text


func compose_map_overlay_text(map_mode: bool, squad_manager: Variant) -> String:
	if not map_mode:
		return ""

	var map_cmd_text: String = "MapCmd: n/a"
	if squad_manager != null and squad_manager.has_method("get_map_debug_text"):
		map_cmd_text = String(squad_manager.call("get_map_debug_text"))
	return "\n" + map_cmd_text + "\n" + MAP_LEGEND_TEXT


func compose_status_text(hp_text: String, ammo_text: String, view_mode_text: String, npc_debug_text: String, world_debug_text: String, map_overlay_text: String, controls_text: String) -> String:
	return hp_text + "\n" + ammo_text + "\n" + view_mode_text + "\n" + npc_debug_text + "\n" + world_debug_text + map_overlay_text + "\n" + GATE_HINT_TEXT + "\n" + controls_text
