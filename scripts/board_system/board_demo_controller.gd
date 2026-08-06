class_name BoardDemoController
extends Node2D


@export_node_path("BoardPlacementSession") var session_path: NodePath
@export_node_path("Label") var status_label_path: NodePath


@onready var session: BoardPlacementSession = get_node(
	session_path
) as BoardPlacementSession
@onready var status_label: Label = get_node(status_label_path) as Label


func _ready() -> void:
	session.state_changed.connect(_on_session_state_changed)
	session.placement_rejected.connect(_on_placement_rejected)
	session.placement_committed.connect(_on_placement_committed)
	session.begin_placement(&"board_demo_wave")
	_update_status(_editing_help())


func _unhandled_input(event: InputEvent) -> void:
	if session.current_state != BoardPlacementSession.State.EDITING:
		return
	if event.is_action_pressed(&"ui_accept"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if session.commit():
			get_viewport().set_input_as_handled()


func _on_session_state_changed(
	_previous_state: BoardPlacementSession.State,
	current_state: BoardPlacementSession.State
) -> void:
	if current_state == BoardPlacementSession.State.EDITING:
		_update_status(_editing_help())
	elif current_state == BoardPlacementSession.State.COMMITTED:
		_update_status("배치 확정 완료 — 검증을 통과해 편집이 잠겼습니다")


func _on_placement_rejected(result: BoardValidationResult) -> void:
	_update_status("배치 오류\n%s" % result.summary())


func _on_placement_committed(
	_wave_id: StringName,
	placements: Array[Dictionary],
	_consumed_counts: Dictionary
) -> void:
	_update_status("배치 확정 완료 — %d개 수리 부품" % placements.size())


func _update_status(text: String) -> void:
	status_label.text = text


func _editing_help() -> String:
	return "1~4 부품 선택 / 좌클릭 선택·배치 / 우클릭 회수 / Enter 확정"
