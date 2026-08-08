class_name RepairPartPlacementHud
extends Control


signal part_activated(kind_id: StringName)
signal part_drag_started(kind_id: StringName)
signal part_dropped(kind_id: StringName, viewport_position: Vector2)
signal confirm_requested
signal drawer_toggled(is_open: bool)


const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const DRAWER_OPEN_Y := 702.0
const DRAWER_CLOSED_Y := 1014.0
const DRAG_THRESHOLD := 10.0
const CARD_SCENE := preload(
	"res://Resources/Prefabs/ui/repair_placement/repair_part_inventory_card.tscn"
)


@onready var _design_space: Control = %DesignSpace
@onready var _drawer: Control = %Drawer
@onready var _drawer_tab: Button = %DrawerTab
@onready var _inventory_row: HBoxContainer = %InventoryRow
@onready var _status_label: Label = %StatusLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _drag_ghost: Control = %DragGhost
@onready var _drag_icon: Label = %DragIcon
@onready var _drag_count: Label = %DragCount


var _cards: Dictionary = {}
var _snapshot: Array[Dictionary] = []
var _compatibility: Dictionary = {}
var _selected_socket_id: StringName
var _drawer_open := true
var _candidate_kind: StringName
var _candidate_start := Vector2.ZERO
var _dragging := false
var _design_scale := 1.0
var _design_offset := Vector2.ZERO
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drawer_tab.pressed.connect(toggle_drawer)
	_confirm_button.pressed.connect(func() -> void: confirm_requested.emit())
	_update_design_transform()
	_set_drawer_position(false)
	set_placement_visible(false)


func _process(_delta: float) -> void:
	if get_viewport_rect().size != _last_viewport_size:
		_update_design_transform()


func _input(event: InputEvent) -> void:
	if not visible or _candidate_kind.is_empty():
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _dragging \
				and motion.position.distance_to(_candidate_start) >= DRAG_THRESHOLD:
			_dragging = true
			_drag_ghost.visible = true
			part_drag_started.emit(_candidate_kind)
		if _dragging:
			_position_drag_ghost(motion.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
			return
		if _dragging:
			part_dropped.emit(_candidate_kind, mouse_button.position)
		else:
			part_activated.emit(_candidate_kind)
		_clear_drag()
		get_viewport().set_input_as_handled()


func set_placement_visible(value: bool) -> void:
	visible = value
	if value:
		_drawer_open = true
		_set_drawer_position(false)
	else:
		_clear_drag()


func render_inventory(
	snapshot: Array[Dictionary],
	selected_socket_id: StringName,
	compatibility: Dictionary
) -> void:
	_snapshot.clear()
	for data: Dictionary in snapshot:
		if int(data.get(&"available_count", 0)) > 0:
			_snapshot.append(data.duplicate(true))
	_selected_socket_id = selected_socket_id
	_compatibility = compatibility.duplicate(true)
	_rebuild_cards_if_needed()
	for data: Dictionary in _snapshot:
		var kind_id := StringName(data.get(&"kind_id", &""))
		var card := _cards.get(kind_id) as RepairPartInventoryCard
		if card == null:
			continue
		card.configure(data, bool(_compatibility.get(kind_id, false)))
	_confirm_button.disabled = false
	if _selected_socket_id.is_empty():
		set_status("보드의 소켓을 선택하면 배치 가능한 부품이 활성화됩니다.")
	else:
		set_status("선택한 소켓에 배치할 수리 부품을 고르세요.")


func set_status(message: String, is_error := false) -> void:
	_status_label.text = message
	_status_label.modulate = Color("ff8fa6") if is_error else Color("c6bda8")


func set_confirm_enabled(value: bool) -> void:
	_confirm_button.disabled = not value


func toggle_drawer() -> void:
	_drawer_open = not _drawer_open
	_set_drawer_position(true)
	drawer_toggled.emit(_drawer_open)


func is_drawer_open() -> bool:
	return _drawer_open


func get_design_size() -> Vector2:
	return DESIGN_SIZE


func is_drag_ghost_visible() -> bool:
	return _drag_ghost.visible


func get_card(kind_id: StringName) -> RepairPartInventoryCard:
	return _cards.get(kind_id) as RepairPartInventoryCard


func _rebuild_cards_if_needed() -> void:
	if _has_matching_card_ids():
		return
	if not _candidate_kind.is_empty() and not _snapshot_has_kind(_candidate_kind):
		_clear_drag()
	for child: Node in _inventory_row.get_children():
		_inventory_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	for data: Dictionary in _snapshot:
		var card := CARD_SCENE.instantiate() as RepairPartInventoryCard
		_inventory_row.add_child(card)
		var kind_id := StringName(data.get(&"kind_id", &""))
		_cards[kind_id] = card
		card.interaction_started.connect(_on_card_interaction_started)


func _has_matching_card_ids() -> bool:
	if _cards.size() != _snapshot.size():
		return false
	for data: Dictionary in _snapshot:
		var kind_id := StringName(data.get(&"kind_id", &""))
		if kind_id.is_empty() or not _cards.has(kind_id):
			return false
	return true


func _snapshot_has_kind(kind_id: StringName) -> bool:
	for data: Dictionary in _snapshot:
		if StringName(data.get(&"kind_id", &"")) == kind_id:
			return true
	return false


func _on_card_interaction_started(
	kind_id: StringName,
	viewport_position: Vector2
) -> void:
	_candidate_kind = kind_id
	_candidate_start = viewport_position
	_dragging = false
	var data := _find_data(kind_id)
	_drag_icon.text = String(data.get(&"placeholder_icon", "?"))
	_drag_count.text = "×1"
	_position_drag_ghost(viewport_position)


func _find_data(kind_id: StringName) -> Dictionary:
	for data: Dictionary in _snapshot:
		if StringName(data.get(&"kind_id", &"")) == kind_id:
			return data
	return {}


func _position_drag_ghost(viewport_position: Vector2) -> void:
	var design_position := (
		viewport_position - _design_offset
	) / maxf(_design_scale, 0.001)
	_drag_ghost.position = design_position - _drag_ghost.size * 0.5


func _clear_drag() -> void:
	_candidate_kind = &""
	_dragging = false
	if is_instance_valid(_drag_ghost):
		_drag_ghost.visible = false


func _set_drawer_position(animated: bool) -> void:
	var target_y := DRAWER_OPEN_Y if _drawer_open else DRAWER_CLOSED_Y
	_drawer_tab.text = (
		"수리 부품 인벤토리  ▼"
		if _drawer_open
		else "수리 부품 인벤토리  ▲"
	)
	if not animated or not is_inside_tree():
		_drawer.position.y = target_y
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_drawer, "position:y", target_y, 0.24)


func _update_design_transform() -> void:
	_last_viewport_size = get_viewport_rect().size
	_design_scale = maxf(minf(
		_last_viewport_size.x / DESIGN_SIZE.x,
		_last_viewport_size.y / DESIGN_SIZE.y
	), 0.001)
	_design_offset = (_last_viewport_size - DESIGN_SIZE * _design_scale) * 0.5
	_design_space.position = _design_offset
	_design_space.scale = Vector2.ONE * _design_scale
