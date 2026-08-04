class_name RepairNeedleEffect
extends RepairPartEffect


## 초승달 바늘 - 달실 봉합.
## 바늘에 닿으면 봉합 대기가 걸리고, 제한 시간 안에 바늘이 아닌 다른 부품의
## 실제 접촉(PRIMARY)이 오면 봉합 타격 한 번을 SECONDARY_STITCH로 추가합니다.
## 한 공에 봉합 대기는 하나만 유지하고, 2차 타격은 봉합 대상이 되지 않습니다.


## ball_instance_id → { expires_at: float }
var _pending_stitches: Dictionary = {}


func on_own_primary(
	_ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.trigger_kind == RepairEffectContext.TriggerKind.PRIMARY)
	var data := get_rank_data()
	if data == null:
		return
	# 바늘을 다시 맞히면 제한 시간만 처음부터 갱신합니다.
	_pending_stitches[context.ball_instance_id] = {
		&"expires_at": now + data.window_seconds,
	}
	_push_needle_state(now)


func on_other_primary(
	source: RepairPartRuntime,
	ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.can_trigger_parts)
	if source.get_family() == RepairPartDefinition.Family.NEEDLE:
		return
	var ball_id := ball.get_instance_id()
	if not _pending_stitches.has(ball_id):
		return
	var pending: Dictionary = _pending_stitches[ball_id]
	if now > float(pending[&"expires_at"]):
		_pending_stitches.erase(ball_id)
		_push_needle_state(now)
		return

	var data := get_rank_data()
	if data == null:
		return
	_pending_stitches.erase(ball_id)
	var stitch_context := RepairEffectContext.make_secondary(
		RepairEffectContext.TriggerKind.SECONDARY_STITCH,
		runtime.get_part_id(),
		runtime.get_family(),
		ball_id
	)
	router.dispatch_secondary(stitch_context, data.score_weight)
	router.notify_stitch_completed(runtime, ball, source, data.score_weight)
	_push_needle_state(now)


func tick(now: float) -> void:
	var expired_ids: Array = []
	for ball_id: int in _pending_stitches.keys():
		var pending: Dictionary = _pending_stitches[ball_id]
		if now > float(pending[&"expires_at"]):
			expired_ids.append(ball_id)
	for ball_id: int in expired_ids:
		_pending_stitches.erase(ball_id)
	if not expired_ids.is_empty():
		_push_needle_state(now)


func reset_transient() -> void:
	_pending_stitches.clear()
	_push_needle_state(0.0)


func has_pending_stitch(ball_id: int) -> bool:
	return _pending_stitches.has(ball_id)


func _push_needle_state(now: float) -> void:
	var remaining := 0.0
	for pending: Dictionary in _pending_stitches.values():
		remaining = maxf(remaining, float(pending[&"expires_at"]) - now)
	_push_state({
		&"family": RepairPartDefinition.Family.NEEDLE,
		&"pending_count": _pending_stitches.size(),
		&"stitch_remaining": remaining,
	})
