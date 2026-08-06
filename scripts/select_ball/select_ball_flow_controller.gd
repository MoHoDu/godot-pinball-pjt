class_name SelectBallFlowController
extends WaveBallFlowController


var _confirmed_definition: BallDefinition


## 확정은 선택 정보를 검증하고 조준할 공을 준비할 뿐입니다.
## 웨이브 사용 완료 처리는 런처가 실제 발사에 성공한 뒤 수행합니다.
func confirm_selection() -> bool:
	if _state != State.SELECTING \
			or inventory == null \
			or launcher == null \
			or selection_locked \
			or _selection_confirmation_in_progress:
		return false
	var definition := inventory.selected_definition
	if definition == null or not definition.is_valid():
		return false

	launcher.ball_scene = definition.ball_scene
	_selection_confirmation_in_progress = true
	var prepared_ball := launcher.prepare_ball()
	_selection_confirmation_in_progress = false
	if prepared_ball == null:
		return false
	if inventory.selected_definition != definition:
		launcher.cancel_prepared_ball(true)
		return false

	_confirmed_definition = definition
	active_ball = prepared_ball
	_set_state(State.AIMING)
	ball_selection_confirmed.emit(definition, inventory.total_remaining)
	active_ball_changed.emit(active_ball)
	return true


func _on_ball_launched(
	launched_ball: Pinball,
	_direction: Vector2,
	_speed: float
) -> void:
	if _state != State.AIMING or launched_ball != active_ball:
		return

	var launched_definition := _confirmed_definition
	_confirmed_definition = null
	var select_inventory := inventory as SelectBallInventory
	var used_definition: BallDefinition
	if select_inventory != null and launched_definition != null:
		used_definition = select_inventory.mark_ball_used(
			launched_definition.ball_id
		)
	if used_definition != launched_definition:
		push_error("Launched ball could not be marked used for this wave.")

	_set_state(State.IN_PLAY)
	ball_launched.emit(launched_ball, inventory.total_remaining)
