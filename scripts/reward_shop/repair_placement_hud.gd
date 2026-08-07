class_name RepairPlacementHud
extends Control


## 배치 단계 자리표시자 HUD입니다. (기획서 9-1 — 소켓은 배치 단계에서만 표시)
##
## 정식 디자인 전까지 텍스트와 키 조작만 제공합니다.
##   Q/E     소켓 포커스 이동
##   1~3     해당 부품을 포커스 소켓에 예약 (같은 부품이면 해제)
##   X       포커스 소켓의 예약 해제
## 첫 발사가 곧 확정이므로 별도의 완료 입력은 없습니다(8-2).


## 숫자키 1~3에 대응하는 부품 순서입니다(카탈로그 노출 순서와 동일).
## v0.3에서 초승달 바늘이 삭제되어 세 부품만 남았습니다.
const PART_ORDER: Array[StringName] = [
	&"starlight_brooch",
	&"golden_gears",
	&"forgotten_star_bell",
]


var _controller: RepairPlacementController
var _inventory: RepairPartInventory
var _scene_map: RepairPartSceneMap
var _panel_label: Label


func bind(
	controller: RepairPlacementController,
	inventory: RepairPartInventory,
	scene_map: RepairPartSceneMap
) -> bool:
	if controller == null or inventory == null or scene_map == null:
		return false
	_controller = controller
	_inventory = inventory
	_scene_map = scene_map
	_controller.placement_started.connect(_on_placement_started)
	_controller.placement_finished.connect(_on_placement_finished)
	_controller.reservation_changed.connect(_on_reservation_changed)
	_inventory.part_count_changed.connect(_on_part_count_changed)
	visible = false
	return true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel_label = Label.new()
	_panel_label.name = "PlacementPanelLabel"
	_panel_label.position = Vector2(-560.0, 240.0)
	_panel_label.add_theme_font_size_override(&"font_size", 24)
	_panel_label.add_theme_color_override(
		&"font_color", Color(0.88, 0.91, 0.86)
	)
	_panel_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	_panel_label.add_theme_constant_override(&"outline_size", 6)
	add_child(_panel_label)


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null or not _controller.is_open:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_Q:
			_controller.move_focus(-1)
			_refresh_panel()
			get_viewport().set_input_as_handled()
		KEY_E:
			_controller.move_focus(1)
			_refresh_panel()
			get_viewport().set_input_as_handled()
		KEY_X:
			_controller.cancel_reservation(_controller.focused_socket_id)
			_refresh_panel()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var part_index := key_event.keycode - KEY_1
			_controller.reserve(
				_controller.focused_socket_id, PART_ORDER[part_index]
			)
			_refresh_panel()
			get_viewport().set_input_as_handled()


func _on_placement_started(_wave_id: int) -> void:
	visible = true
	_refresh_panel()


func _on_placement_finished(_wave_id: int) -> void:
	visible = false


func _on_reservation_changed(
	_socket_id: StringName,
	_part_id: StringName
) -> void:
	_refresh_panel()


func _on_part_count_changed(_part_id: StringName, _count: int) -> void:
	if visible:
		_refresh_panel()


func _refresh_panel() -> void:
	if _panel_label == null or _controller == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("수리 부품 배치 — 첫 발사 전까지 편집 가능")
	lines.append("Q/E 소켓 이동 · 1~4 부품 예약 · X 해제")
	lines.append("")
	for part_index in PART_ORDER.size():
		var part_id := PART_ORDER[part_index]
		lines.append("%d. %s · 재고 %d (예약 %d)" % [
			part_index + 1,
			_scene_map.display_name_of(part_id),
			_controller.available_stock_of(part_id),
			_controller.reserved_count_of(part_id),
		])
	lines.append("")
	var focused := _controller.focused_socket_id
	var reserved := _controller.reserved_part_at(focused)
	var reserved_text := "비어 있음" \
		if reserved == &"" else _scene_map.display_name_of(reserved)
	lines.append("소켓 %s · %s" % [focused, reserved_text])
	lines.append("배치 %d / %d" % [
		_controller.reservations.size(),
		RepairPlacementController.MAX_PLACED_PARTS,
	])
	_panel_label.text = "\n".join(lines)
