class_name RepairBroochEffect
extends RepairPartEffect


## 별빛 브로치 - 마감의 별.
## 비활성 브로치에 닿으면 공에 마감 표식이 생기고, 제한 시간 안에
## 브로치가 아닌 서로 다른 부품 두 종류(계열 기준)를 맞히면 별 팔이 켜집니다.
## 준비된 상태로 브로치에 돌아오면 수리 완성 타격을 SECONDARY_FINISH로 정산합니다.


const REQUIRED_VISIT_FAMILIES := 2


## ball_instance_id → { expires_at: float, visited: Dictionary[family → true] }
var _marks: Dictionary = {}


func on_own_primary(
	ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.trigger_kind == RepairEffectContext.TriggerKind.PRIMARY)
	var data := get_rank_data()
	if data == null:
		return

	var ball_id := ball.get_instance_id()
	if not _marks.has(ball_id):
		# 한 공에 마감 표식은 하나만 존재합니다.
		_marks[ball_id] = {
			&"expires_at": now + data.window_seconds,
			&"visited": {},
		}
		_push_brooch_state(now)
		return

	var mark: Dictionary = _marks[ball_id]
	if now > float(mark[&"expires_at"]):
		# 만료된 표식은 새 표식으로 다시 시작합니다.
		_marks[ball_id] = {
			&"expires_at": now + data.window_seconds,
			&"visited": {},
		}
		_push_brooch_state(now)
		return

	var visited: Dictionary = mark[&"visited"]
	if visited.size() >= REQUIRED_VISIT_FAMILIES:
		# 수리 완성. 완성 타격 한 번을 큰 가중치로 정산하고 표식을 초기화합니다.
		_marks.erase(ball_id)
		var finish_context := RepairEffectContext.make_secondary(
			RepairEffectContext.TriggerKind.SECONDARY_FINISH,
			runtime.get_part_id(),
			runtime.get_family(),
			ball_id
		)
		router.dispatch_secondary(finish_context, data.score_weight)
		router.notify_finish_completed(runtime, ball, data.score_weight)
		_push_brooch_state(now)
		return

	# 준비가 끝나기 전에 다시 맞히면 제한 시간만 새로 시작하고 진행도는 초기화합니다.
	mark[&"expires_at"] = now + data.window_seconds
	visited.clear()
	_push_brooch_state(now)


func on_other_primary(
	source: RepairPartRuntime,
	ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.can_trigger_parts)
	var family := source.get_family()
	if family == RepairPartDefinition.Family.BROOCH:
		return
	var ball_id := ball.get_instance_id()
	if not _marks.has(ball_id):
		return
	var mark: Dictionary = _marks[ball_id]
	if now > float(mark[&"expires_at"]):
		_marks.erase(ball_id)
		_push_brooch_state(now)
		return
	var visited: Dictionary = mark[&"visited"]
	# 같은 부품(계열)을 두 번 맞혀도 별 팔은 하나만 켜집니다.
	visited[family] = true
	_push_brooch_state(now)


func tick(now: float) -> void:
	var expired_ids: Array = []
	for ball_id: int in _marks.keys():
		var mark: Dictionary = _marks[ball_id]
		if now > float(mark[&"expires_at"]):
			expired_ids.append(ball_id)
	for ball_id: int in expired_ids:
		_marks.erase(ball_id)
	if not expired_ids.is_empty():
		_push_brooch_state(now)


func reset_transient() -> void:
	_marks.clear()
	_push_brooch_state(0.0)


func has_mark(ball_id: int) -> bool:
	return _marks.has(ball_id)


func get_visited_family_count(ball_id: int) -> int:
	if not _marks.has(ball_id):
		return 0
	var mark: Dictionary = _marks[ball_id]
	return (mark[&"visited"] as Dictionary).size()


func _push_brooch_state(now: float) -> void:
	var lit_arms := 0
	var remaining := 0.0
	for mark: Dictionary in _marks.values():
		lit_arms = maxi(lit_arms, (mark[&"visited"] as Dictionary).size())
		remaining = maxf(remaining, float(mark[&"expires_at"]) - now)
	_push_state({
		&"family": RepairPartDefinition.Family.BROOCH,
		&"lit_arms": mini(lit_arms, REQUIRED_VISIT_FAMILIES),
		&"mark_count": _marks.size(),
		&"mark_remaining": remaining,
	})
