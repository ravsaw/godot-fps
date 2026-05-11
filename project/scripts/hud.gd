extends CanvasLayer
class_name DebugHud

const LEFT_MARGIN := 12.0
const RIGHT_MARGIN := 12.0
const TOP_MARGIN := 12.0
const SECTION_GAP := 10.0
const STATUS_WIDTH := 520.0
const RIGHT_BLOCK_WIDTH := 300.0
const COMPACT_WIDTH_THRESHOLD := 1500.0
const COMPACT_HEIGHT_THRESHOLD := 850.0

var _hud_label: Label = null
var _event_label: Label = null
var _hitmarker_label: Label = null
var _hp_bar: ProgressBar = null
var _ammo_bar: ProgressBar = null
var _durability_bar: ProgressBar = null
var _reliability_label: Label = null
var _loadout_label: Label = null
var _attachment_panel_label: Label = null
var _attachment_menu_label: Label = null
var _interact_prompt_label: Label = null
var _inventory_label: Label = null
var _event_ttl: float = 0.0
var _hitmarker_ttl: float = 0.0
var _is_compact_mode: bool = false


func _ready() -> void:
	name = "DebugHudLayer"

	# Main debug label (top-left)
	var hud := Label.new()
	hud.name = "DebugHudLabel"
	hud.position = Vector2(LEFT_MARGIN, TOP_MARGIN)
	hud.size = Vector2(STATUS_WIDTH, 220)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.text = "HUD init"
	add_child(hud)
	_hud_label = hud

	# HP Bar
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.position = Vector2(12, 32)
	hp_bar.size = Vector2(220, 18)
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = true
	add_child(hp_bar)
	_hp_bar = hp_bar

	# Ammo Bar
	var ammo_bar := ProgressBar.new()
	ammo_bar.name = "AmmoBar"
	ammo_bar.position = Vector2(12, 54)
	ammo_bar.size = Vector2(220, 18)
	ammo_bar.min_value = 0
	ammo_bar.max_value = 30
	ammo_bar.value = 30
	ammo_bar.show_percentage = false
	add_child(ammo_bar)
	_ammo_bar = ammo_bar

	# Durability Bar
	var durability_bar := ProgressBar.new()
	durability_bar.name = "DurabilityBar"
	durability_bar.position = Vector2(12, 76)
	durability_bar.size = Vector2(220, 18)
	durability_bar.min_value = 0.0
	durability_bar.max_value = 1.0
	durability_bar.value = 1.0
	durability_bar.show_percentage = true
	durability_bar.self_modulate = Color.ORANGE
	add_child(durability_bar)
	_durability_bar = durability_bar

	# Reliability Label
	var reliability := Label.new()
	reliability.name = "ReliabilityLabel"
	reliability.position = Vector2(12, 100)
	reliability.text = "Reliability: 100%"
	add_child(reliability)
	_reliability_label = reliability

	# Loadout Label (right side, below bars)
	var loadout := Label.new()
	loadout.name = "LoadoutLabel"
	loadout.position = Vector2(12, 100)
	loadout.size = Vector2(RIGHT_BLOCK_WIDTH, 120)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.text = "Loadout:\n  Scope: none\n  Barrel: none\n  Stock: none"
	add_child(loadout)
	_loadout_label = loadout

	# Attachment panel
	var attachment_panel := Label.new()
	attachment_panel.name = "AttachmentPanelLabel"
	attachment_panel.position = Vector2(12, 176)
	attachment_panel.size = Vector2(420, 160)
	attachment_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attachment_panel.text = "Attachments:\n  [1] ACOG Scope x0\n  [2] Suppressor x0\n  [3] Stock Attachment x0\n  [0] Clear equipped"
	add_child(attachment_panel)
	_attachment_panel_label = attachment_panel

	var attachment_menu := Label.new()
	attachment_menu.name = "AttachmentMenuLabel"
	attachment_menu.position = Vector2(12, 280)
	attachment_menu.size = Vector2(420, 190)
	attachment_menu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attachment_menu.text = ""
	attachment_menu.visible = false
	add_child(attachment_menu)
	_attachment_menu_label = attachment_menu

	var interact_prompt := Label.new()
	interact_prompt.name = "InteractPromptLabel"
	interact_prompt.position = Vector2(12, 12)
	interact_prompt.text = ""
	interact_prompt.visible = false
	add_child(interact_prompt)
	_interact_prompt_label = interact_prompt

	# Event Label
	var event := Label.new()
	event.name = "DebugEventLabel"
	event.position = Vector2(12, 128)
	event.size = Vector2(500, 28)
	event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event.text = ""
	add_child(event)
	_event_label = event

	# Inventory Label (bottom-left)
	var inventory := Label.new()
	inventory.name = "InventoryLabel"
	inventory.position = Vector2(12, 600)
	inventory.text = "Inventory: empty"
	add_child(inventory)
	_inventory_label = inventory

	# Hitmarker (center)
	var hitmarker := Label.new()
	hitmarker.name = "HitMarkerLabel"
	hitmarker.text = ""
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.size = Vector2(32, 32)
	add_child(hitmarker)
	_hitmarker_label = hitmarker

	_reposition_hud()


func set_status_text(text: String) -> void:
	if _hud_label != null:
		var viewport_size := get_viewport().get_visible_rect().size
		var compact := viewport_size.x < COMPACT_WIDTH_THRESHOLD or viewport_size.y < COMPACT_HEIGHT_THRESHOLD
		if compact:
			var lines := text.split("\n")
			if lines.size() > 6:
				text = "\n".join(lines.slice(0, 6)) + "\n..."
		_hud_label.text = text


func set_hp(value: float) -> void:
	if _hp_bar != null:
		_hp_bar.value = value


func set_ammo(mag: int, reserve: int) -> void:
	if _ammo_bar != null:
		_ammo_bar.value = float(mag)
		_ammo_bar.max_value = mag + reserve if mag + reserve > 0 else 30


func set_durability(percent: float) -> void:
	if _durability_bar != null:
		_durability_bar.value = clamp(percent, 0.0, 1.0)


func set_reliability(percent: float) -> void:
	if _reliability_label != null:
		_reliability_label.text = "Reliability: %.0f%%" % (percent * 100.0)


func set_loadout_text(text: String) -> void:
	if _loadout_label != null:
		_loadout_label.text = text


func set_attachment_panel_text(text: String) -> void:
	if _attachment_panel_label != null:
		_attachment_panel_label.text = text


func set_attachment_menu_text(text: String) -> void:
	if _attachment_menu_label != null:
		_attachment_menu_label.text = text


func set_attachment_menu_visible(visible_flag: bool) -> void:
	if _attachment_menu_label != null:
		_attachment_menu_label.visible = visible_flag


func set_interact_prompt(text: String, visible_flag: bool, item_type: String = "") -> void:
	if _interact_prompt_label != null:
		_interact_prompt_label.text = text
		_interact_prompt_label.visible = visible_flag
		match item_type:
			"ammo":
				_interact_prompt_label.modulate = Color(1.0, 0.82, 0.36)
			"attachment":
				_interact_prompt_label.modulate = Color(0.72, 0.89, 1.0)
			"health":
				_interact_prompt_label.modulate = Color(0.55, 1.0, 0.55)
			_:
				_interact_prompt_label.modulate = Color(1.0, 1.0, 1.0)


func set_inventory_text(text: String) -> void:
	if _inventory_label != null:
		_inventory_label.text = text


func show_event(message: String, duration: float = 1.2) -> void:
	if _event_label == null:
		return
	_event_label.text = message
	_event_ttl = duration


func show_hitmarker(duration: float = 0.12) -> void:
	if _hitmarker_label == null:
		return
	_hitmarker_label.text = "+"
	_hitmarker_ttl = duration


func tick(delta: float) -> void:
	_reposition_hud()

	if _hitmarker_label != null:
		var viewport_center := get_viewport().get_visible_rect().size * 0.5
		_hitmarker_label.position = viewport_center - _hitmarker_label.size * 0.5

	if _event_ttl > 0.0:
		_event_ttl -= delta
		if _event_ttl <= 0.0 and _event_label != null:
			_event_label.text = ""

	if _hitmarker_ttl > 0.0:
		_hitmarker_ttl -= delta
		if _hitmarker_ttl <= 0.0 and _hitmarker_label != null:
			_hitmarker_label.text = ""


func _reposition_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_is_compact_mode = viewport_size.x < COMPACT_WIDTH_THRESHOLD or viewport_size.y < COMPACT_HEIGHT_THRESHOLD

	var left_margin := 8.0 if _is_compact_mode else LEFT_MARGIN
	var right_margin := 8.0 if _is_compact_mode else RIGHT_MARGIN
	var top_margin := 8.0 if _is_compact_mode else TOP_MARGIN
	var section_gap := 6.0 if _is_compact_mode else SECTION_GAP
	var right_block_width := 250.0 if _is_compact_mode else RIGHT_BLOCK_WIDTH
	var status_min_width := 250.0 if _is_compact_mode else 320.0
	var x_right := viewport_size.x - right_block_width - right_margin
	var x_bar := viewport_size.x - 220.0 - right_margin
	var left_y := top_margin

	if _hud_label != null:
		_hud_label.position = Vector2(left_margin, left_y)
		_hud_label.size.x = minf(STATUS_WIDTH, maxf(status_min_width, viewport_size.x - right_block_width - left_margin - right_margin - section_gap))
		left_y += _hud_label.get_minimum_size().y + section_gap

	if _hp_bar != null:
		_hp_bar.position = Vector2(x_bar, 32)
	if _ammo_bar != null:
		_ammo_bar.position = Vector2(x_bar, 54)
	if _durability_bar != null:
		_durability_bar.position = Vector2(x_bar, 76)

	if _reliability_label != null:
		_reliability_label.position = Vector2(x_right, 100 if not _is_compact_mode else 96)

	if _loadout_label != null:
		_loadout_label.position = Vector2(x_right, 122 if not _is_compact_mode else 114)
		_loadout_label.size.x = right_block_width

	if _event_label != null:
		_event_label.position = Vector2((viewport_size.x - _event_label.size.x) * 0.5, 12)

	if _attachment_panel_label != null:
		_attachment_panel_label.position = Vector2(left_margin, left_y)
		_attachment_panel_label.size.x = minf(420.0, maxf(300.0, viewport_size.x * 0.42))
		left_y += _attachment_panel_label.get_minimum_size().y + section_gap

	if _attachment_menu_label != null:
		_attachment_menu_label.position = Vector2(left_margin, left_y)
		_attachment_menu_label.size.x = _attachment_panel_label.size.x if _attachment_panel_label != null else 420.0
		left_y += _attachment_menu_label.get_minimum_size().y + section_gap

	if _interact_prompt_label != null:
		var prompt_size := _interact_prompt_label.get_minimum_size()
		var prompt_x := (viewport_size.x - prompt_size.x) * 0.5
		var prompt_y := viewport_size.y - 88.0
		_interact_prompt_label.position = Vector2(prompt_x, prompt_y)

	if _inventory_label != null:
		var inv_min := _inventory_label.get_minimum_size()
		var inv_y := viewport_size.y - inv_min.y - 18.0
		_inventory_label.position = Vector2(left_margin, maxf(inv_y, left_y))
