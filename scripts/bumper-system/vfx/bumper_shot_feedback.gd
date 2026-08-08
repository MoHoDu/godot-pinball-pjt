class_name BumperShotFeedback
extends BumperHitFeedback
## Shot 타입 VFX. `BumperHitFeedback` 을 확장합니다.
##
## 기획서 5-7 절의 상태 3단계를 `ShotBumper` 시그널에 그대로 붙입니다.
## - `control_started`   → 포획. 받침대 눌림
## - `selection_changed` → 선택. 선택 경로만 밝게, 비선택은 낮은 강도
## - `control_ended`     → 발사. 짧은 반동 + 굵은 방향 잔상 + 제한된 연기
##
## 포신 회전은 그리지 않습니다. `bumper_visual.gd` 의 `_draw_cannon()` 이 이미
## `get_selected_launch_direction()` 을 읽어 포신을 돌립니다.
##
## **포획 동안 공을 숨깁니다.** 공이 대포 안으로 들어간 것처럼 보이게 하려는
## 연출입니다 (2026-08-07 지시). 물리는 건드리지 않고 `visible` 만 끄므로
## 피드백 노드가 물리 노드의 트랜스폼에 손대지 않는다는 원칙을 지킵니다.
## 발사·파괴·해제 어느 쪽으로 끝나든 반드시 되돌립니다.


var _shot_bumper: ShotBumper = null
var _capture_active := false
var _trails: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
## 포획해서 숨긴 공입니다. 되돌릴 책임이 있어 참조를 들고 있습니다.
var _hidden_ball: RigidBody2D = null
## 공이 빨려 들어가는 표시입니다. {born, life, dir}
var _swallow: Array[Dictionary] = []


func bind_to_bumper(bumper: Bumper) -> void:
	if is_instance_valid(_shot_bumper):
		if _shot_bumper.control_started.is_connected(_on_control_started):
			_shot_bumper.control_started.disconnect(_on_control_started)
		if _shot_bumper.control_ended.is_connected(_on_control_ended):
			_shot_bumper.control_ended.disconnect(_on_control_ended)

	super.bind_to_bumper(bumper)

	_shot_bumper = bumper as ShotBumper
	if not is_instance_valid(_shot_bumper):
		return
	_shot_bumper.control_started.connect(_on_control_started)
	_shot_bumper.control_ended.connect(_on_control_ended)


func _process(delta: float) -> void:
	super._process(delta)
	var trails_alive := _expire(_trails)
	var smoke_alive := _expire(_smoke)
	var swallow_alive := _expire(_swallow)
	# 포획이 어떤 이유로든 풀렸는데 공이 숨은 채로 남지 않게 지킨다.
	if _hidden_ball != null and (not _capture_active or not is_instance_valid(_hidden_ball)):
		_show_ball()
	if trails_alive or smoke_alive or swallow_alive or _capture_active:
		queue_redraw()


func _on_control_started(_source: ShotBumper, ball: RigidBody2D) -> void:
	_capture_active = true
	_hide_ball(ball)
	queue_redraw()


func _on_control_ended(_source: ShotBumper, _ball: RigidBody2D) -> void:
	_capture_active = false
	_show_ball()
	spawn_launch()


func _exit_tree() -> void:
	# 씬이 내려갈 때 공을 숨긴 채로 두면 다음 판에서 안 보이는 공이 굴러다닌다.
	_show_ball()


## 공을 대포 안으로 삼킨 것처럼 감춥니다. `visible` 만 끄고 물리는 그대로 둡니다.
func _hide_ball(ball: RigidBody2D) -> void:
	if not is_instance_valid(ball) or not ball.visible:
		return
	_hidden_ball = ball
	ball.visible = false
	var shot_rules := rules as BumperShotVfxRules
	var life: float = shot_rules.trail_lifetime if shot_rules != null else 0.16
	_swallow.append({
		"born": _time,
		"life": life * 1.2,
		"dir": _launch_direction(),
	})
	queue_redraw()


func _show_ball() -> void:
	if is_instance_valid(_hidden_ball):
		_hidden_ball.visible = true
	_hidden_ball = null


func is_ball_hidden() -> bool:
	return is_instance_valid(_hidden_ball) and not _hidden_ball.visible


## 발사 잔상과 연기를 띄웁니다.
func spawn_launch() -> void:
	var shot_rules := rules as BumperShotVfxRules
	if shot_rules == null:
		return

	var direction := _launch_direction()
	var radius := _bumper_radius()

	_trails.append({
		"born": _time,
		"life": shot_rules.trail_lifetime,
		"origin": _bumper_center() + direction * radius * 0.45,
		"dir": direction,
		"length": radius * shot_rules.path_length_ratio * 0.7,
	})

	# 연기는 포구에서 뭉게뭉게 퍼진다. 뒤쪽으로도 조금 새어 나와야 반동이 읽힌다.
	for index in shot_rules.smoke_count:
		var spread := deg_to_rad(shot_rules.tick_spread_degrees) * 0.9
		var offset := randf_range(-spread, spread)
		var backward := index % 4 == 3
		var puff_dir := direction.rotated(offset)
		if backward:
			puff_dir = -puff_dir.rotated(randf_range(-0.5, 0.5))
		_smoke.append({
			"born": _time,
			# 퍼프마다 수명을 흩어 둔다. 한꺼번에 사라지면 판때기처럼 보인다.
			"life": shot_rules.trail_lifetime * randf_range(1.6, 3.0),
			"origin": (
				_bumper_center() + direction * radius
				* (0.30 if backward else randf_range(0.55, 0.95))
			),
			"dir": puff_dir,
			"length": radius * randf_range(0.30, 0.85),
			"radius": (
				radius * shot_rules.smoke_radius_ratio
				* randf_range(0.7, 1.5) * (0.55 if backward else 1.0)
			),
		})

	# 총구 섬광. 부모의 섬광·반짝임 풀을 그대로 빌려 쓴다.
	spawn_hit(_bumper_center() + direction * radius * 2.0)

	queue_redraw()


func is_capture_active() -> bool:
	return _capture_active


func live_trail_count() -> int:
	return _trails.size()


func live_smoke_count() -> int:
	return _smoke.size()


func _launch_direction() -> Vector2:
	if is_instance_valid(_shot_bumper):
		var direction := _shot_bumper.get_selected_launch_direction()
		if direction.length_squared() > 0.0:
			return direction.normalized()
	return Vector2.UP


func _draw() -> void:
	super._draw()

	var shot_rules := rules as BumperShotVfxRules
	if shot_rules == null:
		return

	var radius := _bumper_radius()
	var center := _bumper_center()
	var now := _time

	# 선택 상태에서만 경로를 그린다. 상시 표시는 3-2 절의 "조용한 기본 상태" 에 어긋난다.
	if _capture_active and is_instance_valid(_shot_bumper):
		var selected := _launch_direction()
		var length := radius * shot_rules.path_length_ratio
		for anchor in _shot_bumper.get_launch_anchors():
			if anchor == null:
				continue
			var local := anchor.get_local_launch_direction()
			if local.length_squared() <= 0.0:
				continue
			var world: Vector2 = _shot_bumper.global_transform.basis_xform(
				local
			).normalized()
			var is_selected := world.dot(selected) > 0.999
			var color := shot_rules.selected_path_color
			var width := shot_rules.selected_path_width
			if not is_selected:
				color.a = shot_rules.unselected_path_alpha
				width = shot_rules.unselected_path_width
				if shot_rules.unselected_path_alpha <= 0.0:
					continue
			draw_glow_line(world * radius * 0.6, world * length, color, width)

		# 포획 시 받침대가 눌린 표시. 링을 안쪽으로 좁힌다.
		var pressed := radius * (1.0 - shot_rules.capture_press_ratio)
		draw_arc(
			Vector2.ZERO, pressed, 0.0, TAU, 48,
			shot_rules.selected_path_color * Color(1.0, 1.0, 1.0, 0.45), 2.0, true
		)

	for item in _trails:
		var life := float(item["life"])
		var t: float = clampf((now - float(item["born"])) / life, 0.0, 1.0)
		var color := shot_rules.selected_path_color
		color.a *= 1.0 - t
		var origin: Vector2 = item["origin"] - center
		var length_value: float = float(item["length"])
		var start: Vector2 = origin + item["dir"] * length_value * t * 0.5
		var end: Vector2 = origin + item["dir"] * length_value * (0.4 + 0.6 * t)
		draw_glow_line(start, end, color, shot_rules.selected_path_width * (1.4 - t))

	for item in _smoke:
		var life := float(item["life"])
		var t: float = clampf((now - float(item["born"])) / life, 0.0, 1.0)
		var color := shot_rules.smoke_color
		# 연기는 끝에서 급히 옅어진다. 선형이면 뿌옇게 남아 지저분하다.
		color.a *= (1.0 - t) * (1.0 - t * 0.6)
		var position: Vector2 = (
			item["origin"] - center + item["dir"] * float(item["length"]) * t
		)
		# 가장자리가 흐릿해야 연기로 읽힌다. 딱 떨어지는 원은 돌덩이처럼 보인다.
		_draw_glow_disc(
			position, float(item["radius"]) * (0.45 + 1.35 * t), color, 1.0
		)

	# 공이 포구로 빨려 들어가는 표시. 밖에서 안으로 좁혀 든다.
	for item in _swallow:
		var life := float(item["life"])
		var t: float = clampf((now - float(item["born"])) / life, 0.0, 1.0)
		var color := shot_rules.selected_path_color
		color.a *= 1.0 - t
		var ring := radius * lerpf(1.25, 0.12, t)
		draw_glow_arc(ring, color, 5.0 * (1.0 - 0.5 * t))
