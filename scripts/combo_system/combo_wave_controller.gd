class_name ComboWaveController
extends Node


signal wave_configured(stage_id: StringName, wave_index: int, target_score: int)
signal target_score_reached(current_score: int, target_score: int)
signal clear_choice_requested(current_score: int, target_score: int, remaining_balls: int)
signal wave_clear_requested(current_score: int, target_score: int)
signal wave_retried


var _combo_system: Node
var _ball_flow: WaveBallFlowController
var _stage_settings: Resource
var _wave_index: int = 0
var _target_score: int = 0
var _target_reached: bool = false
var _ball_is_active: bool = false
var _choice_is_pending: bool = false
var _continue_until_balls_exhausted: bool = false
var _clear_was_requested: bool = false


@export var clear_action: StringName = &"wave_choose_clear"
@export var continue_action: StringName = &"wave_choose_remaining_balls"


var target_score: int:
	get:
		return _target_score

var target_reached: bool:
	get:
		return _target_reached

var ball_is_active: bool:
	get:
		return _ball_is_active

var choice_is_pending: bool:
	get:
		return _choice_is_pending

var is_waiting_for_remaining_balls: bool:
	get:
		return _continue_until_balls_exhausted

var clear_was_requested: bool:
	get:
		return _clear_was_requested


func _unhandled_input(event: InputEvent) -> void:
	if not _choice_is_pending:
		return
	if event.is_action_pressed(clear_action):
		if choose_clear():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(continue_action):
		if choose_remaining_balls():
			get_viewport().set_input_as_handled()


func bind_combo_system(combo_system: Node) -> bool:
	if combo_system == null \
			or not combo_system.has_signal(&"score_changed") \
			or not combo_system.has_method(&"on_ball_drained"):
		return false
	if _combo_system == combo_system:
		return true
	unbind_combo_system()
	_combo_system = combo_system
	var callback := Callable(self, &"_on_score_changed")
	_combo_system.connect(&"score_changed", callback)
	_apply_stage_base_score()
	_refresh_target_state()
	return true


func unbind_combo_system() -> void:
	if _combo_system == null or not is_instance_valid(_combo_system):
		_combo_system = null
		return
	var callback := Callable(self, &"_on_score_changed")
	if _combo_system.is_connected(&"score_changed", callback):
		_combo_system.disconnect(&"score_changed", callback)
	_combo_system = null


func bind_ball_flow(ball_flow: WaveBallFlowController) -> bool:
	if ball_flow == null:
		return false
	if _ball_flow == ball_flow:
		return true
	unbind_ball_flow()
	_ball_flow = ball_flow
	_ball_flow.ball_launched.connect(_on_flow_ball_launched)
	_ball_flow.ball_drained.connect(_on_flow_ball_drained)
	_ball_flow.set_selection_locked(_choice_is_pending or _clear_was_requested)
	return true


func unbind_ball_flow() -> void:
	if _ball_flow == null or not is_instance_valid(_ball_flow):
		_ball_flow = null
		return
	if _ball_flow.ball_launched.is_connected(_on_flow_ball_launched):
		_ball_flow.ball_launched.disconnect(_on_flow_ball_launched)
	if _ball_flow.ball_drained.is_connected(_on_flow_ball_drained):
		_ball_flow.ball_drained.disconnect(_on_flow_ball_drained)
	_ball_flow.set_selection_locked(false)
	_ball_flow = null


## wave_index는 0부터 시작합니다. 설정되지 않은 웨이브의 목표 점수는 0입니다.
func configure_wave(stage_settings: Resource, wave_index: int) -> bool:
	if stage_settings == null \
			or not stage_settings.has_method(&"get_wave_target_score"):
		return false
	_stage_settings = stage_settings
	_wave_index = maxi(wave_index, 0)
	_target_score = int(_stage_settings.call(
		&"get_wave_target_score",
		_wave_index
	))
	_reset_flow_state()
	_apply_stage_base_score()
	_refresh_target_state()
	wave_configured.emit(
		StringName(_stage_settings.get(&"stage_id")),
		_wave_index,
		_target_score
	)
	return true


## 선택 대기나 클리어 요청 상태에서는 새 공을 시작하지 않습니다.
func on_ball_launched() -> bool:
	if _combo_system == null \
			or _ball_is_active \
			or _choice_is_pending \
			or _clear_was_requested:
		return false
	_combo_system.call(&"on_ball_launched")
	_ball_is_active = true
	return true


## 남은 공 개수는 현재 낙하한 공을 제외한 값입니다.
func on_ball_drained(remaining_balls: int) -> int:
	if _combo_system == null or not _ball_is_active:
		return 0
	_ball_is_active = false
	var awarded_score := int(_combo_system.call(&"on_ball_drained"))
	_refresh_target_state()
	if not _target_reached:
		return awarded_score

	var safe_remaining := maxi(remaining_balls, 0)
	if _continue_until_balls_exhausted:
		if safe_remaining <= 0:
			_request_wave_clear()
		return awarded_score

	if safe_remaining <= 0:
		_request_wave_clear()
		return awarded_score

	if not _choice_is_pending:
		_choice_is_pending = true
		clear_choice_requested.emit(
			_get_total_score(),
			_target_score,
			safe_remaining
		)
	return awarded_score


func choose_clear() -> bool:
	if not _choice_is_pending:
		return false
	_choice_is_pending = false
	_set_ball_selection_locked(true)
	if _ball_flow != null:
		_ball_flow.end_wave()
	_request_wave_clear()
	return true


func choose_remaining_balls() -> bool:
	if not _choice_is_pending:
		return false
	_choice_is_pending = false
	_continue_until_balls_exhausted = true
	_set_ball_selection_locked(false)
	return true


func on_wave_retried() -> void:
	if _combo_system != null:
		_combo_system.call(&"on_wave_retried")
	_reset_flow_state()
	_set_ball_selection_locked(false)
	if _ball_flow != null:
		_ball_flow.retry_wave()
	wave_retried.emit()


func _on_score_changed(_total_score: int, _added_score: int) -> void:
	_refresh_target_state()


func _on_flow_ball_launched(_ball: Pinball, _remaining_balls: int) -> void:
	on_ball_launched()


func _on_flow_ball_drained(_ball: Pinball, remaining_balls: int) -> void:
	on_ball_drained(remaining_balls)
	_set_ball_selection_locked(_choice_is_pending or _clear_was_requested)


func _refresh_target_state() -> void:
	if _target_reached or _target_score <= 0 or _get_total_score() < _target_score:
		return
	_target_reached = true
	target_score_reached.emit(_get_total_score(), _target_score)


func _request_wave_clear() -> void:
	if _clear_was_requested:
		return
	_choice_is_pending = false
	_clear_was_requested = true
	_set_ball_selection_locked(true)
	wave_clear_requested.emit(_get_total_score(), _target_score)


func _apply_stage_base_score() -> void:
	if _combo_system == null or _stage_settings == null:
		return
	_combo_system.set(
		&"stage_base_score",
		maxi(int(_stage_settings.get(&"stage_base_score")), 0)
	)


func _get_total_score() -> int:
	if _combo_system == null:
		return 0
	return int(_combo_system.get(&"total_score"))


func _reset_flow_state() -> void:
	_target_reached = false
	_ball_is_active = false
	_choice_is_pending = false
	_continue_until_balls_exhausted = false
	_clear_was_requested = false


func _set_ball_selection_locked(is_locked: bool) -> void:
	if _ball_flow != null and is_instance_valid(_ball_flow):
		_ball_flow.set_selection_locked(is_locked)
