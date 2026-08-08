class_name BumperBounceFeedback
extends BumperHitFeedback
## Bounce 타입 타격 VFX. `BumperHitFeedback` 을 확장합니다.
##
## Normal 의 타격선·조각·실밥·파편·복구 예고를 그대로 물려받고
## **원형 파동**과 **방향성 방출선**을 얹습니다 (기획서 3-3 Bounce).
##
## 방출선 방향은 `response_resolved` 에서 얻습니다. 이 시그널이 오는 시점에는
## `ball.linear_velocity` 가 이미 반사 결과로 갱신돼 있어 실제 진행 방향과 맞습니다.
## `valid_hit_registered` 시점에는 아직 갱신 전이라 쓰면 안 됩니다.


var _rings: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []


func bind_to_bumper(bumper: Bumper) -> void:
	# 부모가 관리하는 `_bumper` 를 그대로 쓴다. 밑줄은 관례일 뿐 상속에는 막히지 않는다.
	if (
		is_instance_valid(_bumper)
		and _bumper.response_resolved.is_connected(_on_response_resolved)
	):
		_bumper.response_resolved.disconnect(_on_response_resolved)

	super.bind_to_bumper(bumper)

	if is_instance_valid(bumper):
		bumper.response_resolved.connect(_on_response_resolved)


func _process(delta: float) -> void:
	super._process(delta)
	var rings_alive := _expire(_rings)
	var bursts_alive := _expire(_bursts)
	if rings_alive or bursts_alive:
		queue_redraw()


func _on_response_resolved(
	_source_bumper: Bumper,
	ball: RigidBody2D,
	_response: BumperResponse
) -> void:
	if not is_instance_valid(ball):
		return
	spawn_bounce(ball.global_position, ball.linear_velocity)


## 원형 파동과 방출선을 띄웁니다. `exit_velocity` 는 반사 직후 공 속도입니다.
func spawn_bounce(ball_position: Vector2, exit_velocity: Vector2) -> void:
	var bounce_rules := rules as BumperBounceVfxRules
	if bounce_rules == null:
		return

	var center := _bumper_center()
	for index in bounce_rules.ring_count:
		_rings.append({
			"born": _time,
			"life": bounce_rules.ring_lifetime,
			# 파동이 둘 이상이면 뒤엣것을 살짝 늦춰 겹치지 않게 한다.
			"delay": float(index) * bounce_rules.ring_lifetime * 0.35,
		})

	var direction := exit_velocity
	if direction.length_squared() <= 0.0:
		direction = contact_normal_for(ball_position)
	direction = direction.normalized()

	var radius := _bumper_radius()
	var origin := center + direction * radius
	for index in bounce_rules.burst_count:
		var spread := deg_to_rad(bounce_rules.tick_spread_degrees) * 0.45
		var offset := 0.0
		if bounce_rules.burst_count > 1:
			offset = (
				float(index) / float(bounce_rules.burst_count - 1) - 0.5
			) * 2.0 * spread
		var wobble := 0.78 + 0.44 * float((index * 5) % 4) / 3.0
		_bursts.append({
			"born": _time,
			"life": bounce_rules.burst_lifetime,
			"origin": origin,
			"dir": direction.rotated(offset),
			"length": radius * bounce_rules.burst_length_ratio * wobble,
		})

	queue_redraw()


func live_ring_count() -> int:
	return _rings.size()


func live_burst_count() -> int:
	return _bursts.size()


func _draw() -> void:
	super._draw()

	var bounce_rules := rules as BumperBounceVfxRules
	if bounce_rules == null:
		return

	var radius := _bumper_radius()
	var center := _bumper_center()
	var now := _time

	for item in _rings:
		var elapsed := now - float(item["born"]) - float(item["delay"])
		if elapsed < 0.0:
			continue
		var life := float(item["life"])
		var t: float = clampf(elapsed / life, 0.0, 1.0)
		var ring_radius: float = radius * lerpf(
			bounce_rules.ring_start_ratio, bounce_rules.ring_end_ratio, t
		)
		var color := bounce_rules.ring_color
		color.a *= 1.0 - t
		draw_glow_arc(
			ring_radius, color, bounce_rules.ring_width * (1.0 - 0.55 * t)
		)

	for item in _bursts:
		var life := float(item["life"])
		var t: float = clampf((now - float(item["born"])) / life, 0.0, 1.0)
		var color := bounce_rules.burst_color
		color.a *= 1.0 - t
		var origin: Vector2 = item["origin"] - center
		var length: float = float(item["length"])
		var start: Vector2 = origin + item["dir"] * length * (0.10 + 0.35 * t)
		var end: Vector2 = origin + item["dir"] * length * (0.45 + 0.55 * t)
		draw_glow_line(
			start, end, color, bounce_rules.tick_width * (1.0 - 0.3 * t)
		)
