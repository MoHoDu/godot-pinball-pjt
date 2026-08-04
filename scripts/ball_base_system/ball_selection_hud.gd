class_name BallSelectionHud
extends Control


@onready var title_label: Label = %TitleLabel
@onready var ball_name_label: Label = %BallNameLabel
@onready var stock_label: Label = %StockLabel
@onready var guide_label: Label = %GuideLabel


var _flow: WaveBallFlowController
var _inventory: WaveBallInventory


func _ready() -> void:
	visible = false


func bind_ball_flow(flow: WaveBallFlowController) -> bool:
	if flow == null or flow.inventory == null:
		return false
	_unbind()
	_flow = flow
	_inventory = flow.inventory
	_flow.state_changed.connect(_on_state_changed)
	_flow.selection_lock_changed.connect(_on_selection_lock_changed)
	_inventory.selection_started.connect(_on_selection_updated)
	_inventory.selection_changed.connect(_on_selection_updated)
	_refresh()
	return true


func _unbind() -> void:
	if _flow != null and is_instance_valid(_flow):
		if _flow.state_changed.is_connected(_on_state_changed):
			_flow.state_changed.disconnect(_on_state_changed)
		if _flow.selection_lock_changed.is_connected(_on_selection_lock_changed):
			_flow.selection_lock_changed.disconnect(_on_selection_lock_changed)
	if _inventory != null and is_instance_valid(_inventory):
		if _inventory.selection_started.is_connected(_on_selection_updated):
			_inventory.selection_started.disconnect(_on_selection_updated)
		if _inventory.selection_changed.is_connected(_on_selection_updated):
			_inventory.selection_changed.disconnect(_on_selection_updated)
	_flow = null
	_inventory = null


func _on_state_changed(
	_previous_state: WaveBallFlowController.State,
	_current_state: WaveBallFlowController.State
) -> void:
	_refresh()


func _on_selection_lock_changed(_is_locked: bool) -> void:
	_refresh()


func _on_selection_updated(
	_definition: BallDefinition,
	_remaining: int
) -> void:
	_refresh()


func _refresh() -> void:
	if _flow == null or _inventory == null:
		visible = false
		return
	visible = _flow.current_state == WaveBallFlowController.State.SELECTING
	if not visible:
		return
	var definition := _inventory.selected_definition
	ball_name_label.text = definition.display_name if definition != null else "선택 가능한 공 없음"
	stock_label.text = "이 공 %d개 / 전체 %d개 남음" % [
		_inventory.selected_remaining,
		_inventory.total_remaining,
	]
	if _flow.selection_locked:
		title_label.text = "웨이브 클리어 선택 대기"
		guide_label.text = "B: 웨이브 클리어    V: 남은 공 계속 사용"
	else:
		title_label.text = "다음 공 선택"
		guide_label.text = "A/D 또는 방향키: 선택    Space: 조준 시작"
