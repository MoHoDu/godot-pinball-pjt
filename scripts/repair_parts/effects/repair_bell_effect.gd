class_name RepairBellEffect
extends RepairPartEffect


## 잊혀진 별방울 - 여운의 응답.
## 접촉 시 기본 타격은 즉시(기존 콤보 파이프라인) 발생하고,
## 지연 시간 뒤 여운이 울리며 콤보를 한 번에 여러 개 추가합니다.
##
## v0.3 여운 계산 (기획 의도: 여운은 '내가 방금 쌓은 흐름'에 비례해 되울린다)
##   1. 방울에 닿는 순간의 콤보 횟수를 기준선으로 기억한다.
##   2. 지연 시간 동안 실제로 추가된 콤보 수만 센다.
##   3. 그 수에 가중치를 곱하고 반올림한 정수만큼 콤보를 한 번에 추가한다.
##      1 + round(1 x 0.25) = 1,  2 + round(2 x 0.25) = 3
## 결과가 실수 가중치가 아니라 정수 콤보 횟수이므로 HUD와 정산이 어긋나지 않고,
## 지연 동안 아무것도 못 쳤으면 여운도 울리지 않아 '여운'의 인과가 유지됩니다.
##
## 공 하나·방울 하나당 예약 가능한 여운은 하나이며 물리 충돌은 만들지 않습니다.


## ball_instance_id → { fire_at: float, combo_baseline: int,
##                      multiplier: float, hit_weight: float }
var _pending_echoes: Dictionary = {}
var _cooldown_until: float = -1.0
var _last_echo_combo_count: int = 0


func on_own_primary(
	ball: RigidBody2D,
	context: RepairEffectContext,
	now: float
) -> void:
	assert(context.trigger_kind == RepairEffectContext.TriggerKind.PRIMARY)
	var data := get_definition()
	if data == null:
		return

	var ball_id := ball.get_instance_id()
	if _pending_echoes.has(ball_id):
		# 여운 대기 중 추가 접촉은 기본 타격만 인정하고 새 여운은 예약하지 않습니다.
		return
	if now < _cooldown_until:
		return

	_pending_echoes[ball_id] = {
		&"fire_at": now + data.bell_echo_delay,
		&"combo_baseline": _get_combo_count(),
		&"multiplier": data.bell_echo_combo_multiplier,
		&"hit_weight": data.bell_echo_hit_weight,
	}
	_cooldown_until = now + data.bell_cooldown_seconds
	router.notify_bell_echo_scheduled(runtime, ball, data.bell_echo_delay)
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
		_fire_echo(ball_id, pending)
	for ball_id: int in fired_ids:
		_pending_echoes.erase(ball_id)
	if not fired_ids.is_empty():
		_push_bell_state(now)


func reset_transient() -> void:
	_pending_echoes.clear()
	_cooldown_until = -1.0
	_last_echo_combo_count = 0
	_push_bell_state(0.0)


func has_pending_echo(ball_id: int) -> bool:
	return _pending_echoes.has(ball_id)


## 직전 여운이 실제로 추가한 콤보 횟수입니다(정수).
func get_last_echo_combo_count() -> int:
	return _last_echo_combo_count


## 지연 시간 동안 추가된 콤보 수에서 여운이 추가할 콤보 횟수를 계산합니다.
static func calculate_echo_combo_count(
	added_combos: int,
	multiplier: float
) -> int:
	if added_combos <= 0 or multiplier <= 0.0:
		return 0
	return int(roundf(float(added_combos) * multiplier))


func _fire_echo(ball_id: int, pending: Dictionary) -> void:
	var baseline := int(pending[&"combo_baseline"])
	var current := _get_combo_count()
	# 지연 도중 콤보가 끊겨 정산되면 기준선보다 낮아집니다.
	# 이때는 끊긴 뒤 새로 쌓인 만큼만 여운의 근거로 인정합니다.
	var added := current - baseline if current >= baseline else current
	var echo_count := calculate_echo_combo_count(
		added,
		float(pending[&"multiplier"])
	)
	_last_echo_combo_count = echo_count
	if echo_count <= 0:
		# 근거가 될 콤보가 없으면 콤보를 올리지 않고 연출만 끝냅니다.
		router.notify_bell_echo_fired(runtime, ball_id, 0)
		return
	var context := RepairEffectContext.make_secondary(
		RepairEffectContext.TriggerKind.SECONDARY_ECHO,
		runtime.get_part_id(),
		runtime.get_family(),
		ball_id
	)
	router.dispatch_secondary_combo_hits(
		context,
		echo_count,
		float(pending[&"hit_weight"])
	)
	router.notify_bell_echo_fired(runtime, ball_id, echo_count)


func _get_combo_count() -> int:
	if router == null:
		return 0
	var combo_adapter := router.get_combo_adapter()
	if combo_adapter == null:
		return 0
	return combo_adapter.get_combo_count()


func _push_bell_state(now: float) -> void:
	var next_fire := 0.0
	for pending: Dictionary in _pending_echoes.values():
		next_fire = maxf(float(pending[&"fire_at"]) - now, next_fire)
	_push_state({
		&"family": RepairPartDefinition.Family.BELL,
		&"pending_count": _pending_echoes.size(),
		&"echo_remaining": next_fire,
		&"last_echo_combo_count": _last_echo_combo_count,
	})
