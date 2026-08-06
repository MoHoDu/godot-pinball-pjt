class_name RepairBellEffect
extends RepairPartEffect


## 잊혀진 별방울 - 여운의 응답.
## 접촉 시 기본 타격은 즉시(기존 콤보 파이프라인) 발생하고,
## 지연 시간 뒤 여운 타격 한 번을 SECONDARY_ECHO로 콤보에 추가합니다.
## 공 하나·방울 하나당 예약 가능한 여운은 하나이며 물리 충돌은 만들지 않습니다.


## ball_instance_id → { fire_at: float, weight: float }
var _pending_echoes: Dictionary = {}
var _cooldown_until: float = -1.0


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
	if _pending_echoes.has(ball_id):
		# 여운 대기 중 추가 접촉은 기본 타격만 인정하고 새 여운은 예약하지 않습니다.
		return
	if now < _cooldown_until:
		return

	_pending_echoes[ball_id] = {
		&"fire_at": now + data.echo_delay,
		&"weight": data.score_weight,
	}
	_cooldown_until = now + data.cooldown_seconds
	router.notify_bell_echo_scheduled(runtime, ball, data.echo_delay)
	_push_bell_state(now)


func tick(now: float) -> void:
	if _pending_echoes.is_empty():
		return
	var fired_ids: Array = []
	for ball_id: int in _pending_echoes.keys():
		var pending: Dictionary = _pending_echoes[ball_id]
		if now < float(pending[&"fire_at"]):
			continue
		fired_ids.append(ball_id)
		var context := RepairEffectContext.make_secondary(
			RepairEffectContext.TriggerKind.SECONDARY_ECHO,
			runtime.get_part_id(),
			runtime.get_family(),
			ball_id
		)
		router.dispatch_secondary(context, float(pending[&"weight"]))
		router.notify_bell_echo_fired(
			runtime,
			ball_id,
			float(pending[&"weight"])
		)
	for ball_id: int in fired_ids:
		_pending_echoes.erase(ball_id)
	if not fired_ids.is_empty():
		_push_bell_state(now)


func reset_transient() -> void:
	_pending_echoes.clear()
	_cooldown_until = -1.0
	_push_bell_state(0.0)


func has_pending_echo(ball_id: int) -> bool:
	return _pending_echoes.has(ball_id)


func _push_bell_state(now: float) -> void:
	var next_fire := 0.0
	for pending: Dictionary in _pending_echoes.values():
		next_fire = maxf(next_fire, float(pending[&"fire_at"]) - now)
	_push_state({
		&"family": RepairPartDefinition.Family.BELL,
		&"pending_count": _pending_echoes.size(),
		&"echo_remaining": next_fire,
	})
