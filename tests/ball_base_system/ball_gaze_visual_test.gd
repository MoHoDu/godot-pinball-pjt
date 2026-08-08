extends SceneTree

const BALL_SCENE_PATH := "res://Resources/Prefabs/balls/base/base_ball.tscn"
const GAZE_RULES_PATH := "res://settings/balls/BallGazeRules.tres"
const ANGLE_EPSILON := 0.02
const FLOAT_EPSILON := 0.001


## 물리 바디와 시각 노드를 묶어 두는 테스트용 조립체입니다.
class GazeRig:
	var body: RigidBody2D
	var visual: BallGazeVisual


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource()
	_test_scene_wiring()
	await _test_instant_alignment_on_launch()
	await _test_gaze_follows_velocity_change()
	await _test_holds_last_angle_when_slow()
	await _test_ignores_body_spin()
	await _test_takes_shortest_rotation()
	await _test_weight_is_frame_rate_independent()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource() -> void:
	var rules := load(GAZE_RULES_PATH) as BallGazeRules
	_expect(rules != null, "BallGazeRules.tres를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect_float(rules.gaze_speed_threshold, 120.0,
		"기본 시선 갱신 임계 속력은 120px/s여야 한다.")
	_expect_float(rules.gaze_sharpness, 18.0,
		"기본 시선 반응 계수는 18이어야 한다.")
	_expect(rules.instant_on_spawn,
		"발사 순간 즉시 정렬이 기본값이어야 한다.")

	rules.gaze_sharpness = 1000.0
	_expect_float(rules.gaze_sharpness, BallGazeRules.MAX_GAZE_SHARPNESS,
		"시선 반응 계수는 상한으로 보정되어야 한다.")
	rules.gaze_sharpness = -5.0
	_expect_float(rules.gaze_sharpness, BallGazeRules.MIN_GAZE_SHARPNESS,
		"시선 반응 계수는 하한으로 보정되어야 한다.")
	rules.gaze_sharpness = 18.0

	rules.gaze_speed_threshold = 99999.0
	_expect_float(rules.gaze_speed_threshold, BallGazeRules.MAX_GAZE_SPEED_THRESHOLD,
		"임계 속력은 상한으로 보정되어야 한다.")
	rules.gaze_speed_threshold = 120.0


# ── 씬 연결 ─────────────────────────────────────────────────

func _test_scene_wiring() -> void:
	var packed_scene := load(BALL_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")

	if packed_scene == null:
		return

	var ball := packed_scene.instantiate() as Pinball
	_expect(ball != null, "기본 공 씬의 루트는 Pinball이어야 한다.")

	if ball == null:
		return

	_expect(ball.get_node_or_null("Visual") is BallGazeVisual,
		"기본 공 씬의 Visual 노드에 BallGazeVisual이 붙어 있어야 한다.")
	_expect(ball.get_node_or_null("Visual/Sprite2D") is Sprite2D,
		"BallGazeVisual을 붙여도 Visual/Sprite2D 경로가 유지되어야 한다.")

	ball.free()


# ── 시선 동작 ───────────────────────────────────────────────

func _test_instant_alignment_on_launch() -> void:
	var rig := _make_rig()
	rig.body.linear_velocity = Vector2(0.0, -600.0)
	await physics_frame
	await physics_frame

	_expect(rig.visual.has_locked_on(),
		"임계 속력을 넘으면 시선이 고정되어야 한다.")
	_expect_angle(rig.visual.global_rotation, -PI * 0.5,
		"발사 첫 프레임에는 보간 없이 진행방향과 정확히 일치해야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_gaze_follows_velocity_change() -> void:
	var rig := _make_rig()
	rig.body.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	await physics_frame

	var previous := rig.visual.global_rotation
	rig.body.linear_velocity = Vector2(0.0, 600.0)

	for _step in 40:
		await physics_frame

	_expect_angle(rig.visual.get_target_angle(), PI * 0.5,
		"목표 각도는 바뀐 속도 벡터를 따라가야 한다.")
	_expect_angle(rig.visual.global_rotation, PI * 0.5,
		"충분한 시간이 지나면 시선이 진행방향에 수렴해야 한다.")
	_expect(absf(angle_difference(previous, rig.visual.global_rotation)) > 0.1,
		"속도 방향이 바뀌면 시선도 실제로 움직여야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_holds_last_angle_when_slow() -> void:
	var rig := _make_rig()
	rig.body.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	await physics_frame

	var locked := rig.visual.global_rotation

	# 임계 속력 미만으로 떨어뜨리되 방향은 전혀 다른 쪽을 향하게 둔다.
	rig.body.linear_velocity = Vector2(0.0, -10.0)
	for _step in 20:
		await physics_frame

	_expect_angle(rig.visual.get_target_angle(), locked,
		"임계 속력 미만에서는 목표 각도를 갱신하지 않아야 한다.")
	_expect_angle(rig.visual.global_rotation, locked,
		"거의 멈춘 공의 시선은 떨리지 않고 마지막 방향을 유지해야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_ignores_body_spin() -> void:
	var rig := _make_rig()
	rig.body.linear_velocity = Vector2(600.0, 0.0)
	rig.body.angular_velocity = 3.0

	# 3rad/s로 20프레임(약 0.33초) = 약 1rad. 2PI를 넘지 않아 wrap 걱정이 없다.
	for _step in 20:
		await physics_frame

	_expect(absf(rig.body.rotation) > 0.5,
		"테스트 전제: 바디는 실제로 회전하고 있어야 한다.")
	_expect_angle(rig.visual.global_rotation, 0.0,
		"바디가 회전해도 시각 노드의 월드 각도는 진행방향을 유지해야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_takes_shortest_rotation() -> void:
	var rig := _make_rig()
	rig.body.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	await physics_frame

	# 0도에서 +170도로. 짧은 쪽은 양의 방향이다.
	var target := deg_to_rad(170.0)
	rig.body.linear_velocity = Vector2(cos(target), sin(target)) * 600.0
	await physics_frame
	await physics_frame

	_expect(rig.visual.global_rotation > 0.0,
		"170도 반전은 짧은 쪽(양의 방향)으로 돌아야 한다.")

	for _step in 60:
		await physics_frame

	_expect_angle(rig.visual.global_rotation, target,
		"반전 후에도 최종적으로 진행방향에 수렴해야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_weight_is_frame_rate_independent() -> void:
	var visual := BallGazeVisual.new()

	var slow_step := visual._interpolation_weight(1.0 / 30.0)
	var fast_step := visual._interpolation_weight(1.0 / 120.0)
	_expect(slow_step > fast_step,
		"델타가 크면 한 프레임에 더 많이 따라잡아야 한다.")

	# 30fps 한 걸음과 120fps 네 걸음이 같은 총량이어야 한다.
	var remaining := 1.0
	for _step in 4:
		remaining *= (1.0 - fast_step)
	_expect(absf((1.0 - remaining) - slow_step) < FLOAT_EPSILON,
		"지수 감쇠라 프레임레이트가 달라도 같은 시간에 같은 양을 따라잡아야 한다.")

	_expect_float(visual._interpolation_weight(10.0), 1.0,
		"델타가 비정상적으로 커도 가중치는 1을 넘지 않아야 한다.")

	visual.free()
	await process_frame


# ── 헬퍼 ────────────────────────────────────────────────────

func _make_rig() -> GazeRig:
	var rig := GazeRig.new()
	rig.body = RigidBody2D.new()
	rig.body.gravity_scale = 0.0
	# 프로젝트 기본 감쇠에 결과가 흔들리지 않도록 완전히 대체한다.
	rig.body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rig.body.linear_damp = 0.0
	rig.body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rig.body.angular_damp = 0.0
	rig.visual = BallGazeVisual.new()
	rig.body.add_child(rig.visual)
	root.add_child(rig.body)
	return rig


func _free_rig(rig: GazeRig) -> void:
	rig.body.queue_free()


func _expect_angle(actual: float, expected: float, message: String) -> void:
	var difference := absf(angle_difference(actual, expected))
	_expect(difference <= ANGLE_EPSILON,
		"%s (expected=%.4f, actual=%.4f, diff=%.4f)" % [
			message, expected, actual, difference
		])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= FLOAT_EPSILON,
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ball_gaze_visual_test")
		quit(0)
		return

	print("FAIL: ball_gaze_visual_test (%d failures)" % _failures.size())
	quit(1)
