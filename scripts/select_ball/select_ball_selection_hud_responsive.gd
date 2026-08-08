class_name SelectBallSelectionHudResponsive
extends SelectBallSelectionHud


const SLOT_WIDTH := 180.0
const SLOT_GAP := 12.0
const VISIBLE_SLOTS_WIDTH := 992.0
const SLOT_ROW_HEIGHT := 220.0


var _slots_scroll: ScrollContainer


func _ready() -> void:
	super()
	_install_scroll_container()


func _sync_slots() -> void:
	super()
	var select_inventory := _inventory as SelectBallInventory
	if select_inventory == null:
		return
	var owned_definitions := select_inventory.get_owned_definitions()
	var content_width := owned_definitions.size() * SLOT_WIDTH \
		+ maxi(owned_definitions.size() - 1, 0) * SLOT_GAP
	slots_container.custom_minimum_size = Vector2(
		maxf(VISIBLE_SLOTS_WIDTH, content_width),
		SLOT_ROW_HEIGHT
	)
	slots_container.alignment = (
		BoxContainer.ALIGNMENT_CENTER
		if content_width <= VISIBLE_SLOTS_WIDTH
		else BoxContainer.ALIGNMENT_BEGIN
	)
	for definition: BallDefinition in owned_definitions:
		var button := _slot_buttons.get(definition.ball_id) as Button
		if button == null:
			continue
		var texture := BallArtLibrary.icon_of(definition.ball_id, 88)
		if texture == null:
			texture = BallArtLibrary.icon_of(&"normal", 88)
		(button.get_node("%BallIcon") as TextureRect).texture = texture
	if _slots_scroll != null:
		call_deferred(&"_ensure_selected_slot_visible")


func _install_scroll_container() -> void:
	if slots_container == null or _slots_scroll != null:
		return
	var parent := slots_container.get_parent()
	var child_index := slots_container.get_index()
	parent.remove_child(slots_container)
	_slots_scroll = ScrollContainer.new()
	_slots_scroll.name = "SlotsScroll"
	_slots_scroll.custom_minimum_size = Vector2(0.0, SLOT_ROW_HEIGHT)
	_slots_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_slots_scroll)
	parent.move_child(_slots_scroll, child_index)
	_slots_scroll.add_child(slots_container)
	slots_container.unique_name_in_owner = false
	slots_container.unique_name_in_owner = true


func _ensure_selected_slot_visible() -> void:
	if _slots_scroll == null or _inventory == null:
		return
	var definition := _inventory.selected_definition
	if definition == null:
		return
	var button := _slot_buttons.get(definition.ball_id) as Control
	if button != null:
		_slots_scroll.ensure_control_visible(button)
