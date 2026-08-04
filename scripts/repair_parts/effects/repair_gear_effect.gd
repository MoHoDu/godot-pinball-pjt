class_name RepairGearEffect
extends RepairPartEffect


## 황금 톱니바퀴 - 되감는 심장.
## 접촉마다 현재 방향을 유지한 안전한 속도 보정을 받고,
## 제한 시간 안에 3회 유효 접촉이 쌓이면 과회전 추가 가속이 터집니다.
## 회전 단계는 부품 단위 상태이며 공 위치는 절대 변경하지 않습니다.
##
## 가속은 접촉 즉시가 아니라 범퍼의 최종 충돌 반응(response_resolved)이
## 공에 적용된 뒤에 합성합니다. 즉시 적용하면 같은 프레임의 지연 반응이
## 타격 전 속도로 되돌려 가속이 무효화됩니다.


## ball_instance_id → { ball, contact_boost, overdrive_boost, is_overdrive }
var _pending_boosts: Dictionary = {}
var _wind_stack: int = 0
var _stack_expires_at: float = -1.0


func on_own_primary(
	ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.trigger_kind == RepairEffectContext.TriggerKind.PRIMARY)
	var data := get_rank_data()
	if data == null:
		return

	if _wind_stack > 0 and now > _stack_expires_at:
		_wind_stack = 0

	_wind_stack += 1
	var is_overdrive := _wind_stack >= data.max_stack

	_pending_boosts[ball.get_instance_id()] = {
		&"ball": ball,
		&"contact_boost": data.contact_boost,
		&"overdrive_boost": data.overdrive_boost,
		&"is_overdrive": is_overdrive,
	}

	if is_overdrive:
		# 과회전은 같은 물리 접촉 안에서 두 번 발생하지 않고 단계가 0으로 돌아갑니다.
		_wind_stack = 0
		_stack_expires_at = -1.0
	else:
		_stack_expires_at = now + data.window_seconds

	_push_stack_state(now)


func on_own_response_resolved(ball: RigidBody2D, _now: float) -> void:
	_apply_pending_boost(ball.get_instance_id())


func tick(now: float) -> void:
	# 응답 전략이 없어 최종 반응이 오지 않은 접촉은 다음 틱에 안전하게 적용합니다.
	for ball_id: int in _pending_boosts.keys().duplicate():
		_apply_pending_boost(ball_id)
	if _wind_stack > 0 and now > _stack_expires_at:
		_wind_stack = 0
		_stack_expires_at = -1.0
		_push_stack_state(now)


func reset_transient() -> void:
	_pending_boosts.clear()
	_wind_stack = 0
	_stack_expires_at = -1.0
	_push_stack_state(0.0)


func get_wind_stack() -> int:
	return _wind_stack


func _apply_pending_boost(ball_id: int) -> void:
	if not _pending_boosts.has(ball_id):
		return
	var pending: Dictionary = _pending_boosts[ball_id]
	_pending_boosts.erase(ball_id)
	var ball := pending[&"ball"] as RigidBody2D
	if not is_instance_valid(ball):
		return
	var ball_adapter := router.get_ball_adapter()
	if ball_adapter == null:
		return
	var is_overdrive := bool(pending[&"is_overdrive"])
	var speed_before := ball.linear_velocity.length()
	# impulse는 다음 물리 동기화까지 노드 캐시에 반영되지 않으므로
	# 어댑터가 반환한 적용 목표 속력을 speed_after로 보고합니다.
	var applied_speed := ball_adapter.apply_gear_boost(
		ball,
		runtime.bumper.global_position,
		float(pending[&"contact_boost"]),
		float(pending[&"overdrive_boost"]),
		is_overdrive
	)
	if is_overdrive and applied_speed >= 0.0:
		router.notify_gear_overdrive(
			runtime,
			ball,
			speed_before,
			applied_speed
		)


func _push_stack_state(now: float) -> void:
	_push_state({
		&"family": RepairPartDefinition.Family.GEAR,
		&"wind_stack": _wind_stack,
		&"window_remaining": maxf(_stack_expires_at - now, 0.0),
	})
