extends SceneTree


const TEST_SCENE_PATH := "res://scenes/tests/flippers/test_flipper_parry.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "일반·정확 패링 전용 테스트 씬이 필요하다.")
	if packed_scene == null:
		_finish()
		return

	var test_scene := packed_scene.instantiate() as Node2D
	root.add_child(test_scene)
	await process_frame

	for method_name: StringName in [
		&"select_test_mode",
		&"get_test_parry_rules",
		&"reset_ball",
	]:
		_expect(test_scene.has_method(method_name), \
			"패링 테스트 씬에 %s 조작 API가 필요하다." % method_name)

	var guide := test_scene.get_node_or_null("ParryTestGuide/Panel/GuideLabel") as Label
	_expect(guide != null, "현재 판정과 결과를 표시할 패링 테스트 안내 Label이 필요하다.")

	if test_scene.has_method(&"select_test_mode"):
		test_scene.call(&"select_test_mode", 1)
		var actual_rules := test_scene.call(&"get_test_parry_rules") as Resource
		_expect(actual_rules != null, "테스트 씬은 원본을 보호하는 복제 패링 설정을 사용해야 한다.")
		if actual_rules != null:
			_expect_float(float(actual_rules.get(&"perfect_parry_window_time")), 0.042, \
				"실전 모드는 기획서 정확 패링 시간 0.042초를 사용해야 한다.")
			_expect_float(float(actual_rules.get(&"normal_parry_window_time")), 0.095, \
				"실전 모드는 기획서 일반 패링 시간 0.095초를 사용해야 한다.")
			_expect_float(float(actual_rules.get(&"normal_maximum_speed")), 1540.0, \
				"실전 모드는 일반 최대 속도 1540px/s를 표시해야 한다.")
			_expect_float(float(actual_rules.get(&"perfect_parry_maximum_speed")), 1700.0, \
				"실전 모드는 정확 패링 최대 속도 1700px/s를 표시해야 한다.")

		test_scene.call(&"select_test_mode", 2)
		var normal_rules := test_scene.call(&"get_test_parry_rules") as Resource
		if normal_rules != null:
			_expect_float(float(normal_rules.get(&"perfect_parry_window_time")), 0.0, \
				"일반 고정 모드는 정확 패링 구간을 제거해야 한다.")
			_expect(float(normal_rules.get(&"normal_parry_window_time")) > 1.0, \
				"일반 고정 모드는 작동 충돌을 충분히 긴 일반 구간으로 만들어야 한다.")

		test_scene.call(&"select_test_mode", 3)
		var perfect_rules := test_scene.call(&"get_test_parry_rules") as Resource
		if perfect_rules != null:
			_expect(float(perfect_rules.get(&"perfect_parry_window_time")) > 1.0, \
				"정확 고정 모드는 작동 충돌을 충분히 긴 정확 구간으로 만들어야 한다.")

	await _test_scene_actual_velocity_limit(test_scene)

	test_scene.queue_free()
	await process_frame
	_finish()


func _test_scene_actual_velocity_limit(test_scene: Node2D) -> void:
	var ball := test_scene.get_node_or_null("PinballBall") as Pinball
	var right_flipper := test_scene.get_node_or_null(
		"FlipperControllers/FlipperController/RightFlipper"
	) as PinballFlipper
	_expect(ball != null and right_flipper != null, \
		"테스트 씬 실제 속도 검증에는 공과 오른쪽 플리퍼가 필요하다.")
	if ball == null or right_flipper == null:
		return

	test_scene.call(&"select_test_mode", 3)
	await process_frame
	ball.freeze = false
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.global_position = right_flipper.global_position + Vector2(-400.0, 0.0)
	ball.linear_velocity = Vector2(0.0, 400.0)
	ball.sleeping = false
	ball.reset_physics_interpolation()

	_expect(right_flipper.request_activation(), \
		"테스트 씬 오른쪽 플리퍼를 정확 패링 고정 모드로 작동할 수 있어야 한다.")
	var maximum_observed_speed := 0.0
	for _physics_step: int in 6:
		await physics_frame
		await process_frame
		maximum_observed_speed = maxf(
			maximum_observed_speed,
			ball.linear_velocity.length()
		)

	_expect(maximum_observed_speed <= 1700.0 + 1.0, \
		"실제 패링 테스트 씬의 linear_velocity가 정확 패링 상한을 넘으면 안 된다. " \
		+ "(limit=1700, observed=%.1f)" % maximum_observed_speed)


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_parry_scene_test")
		quit(0)
		return
	print("FAIL: test_flipper_parry_scene_test (%d failures)" % _failures.size())
	quit(1)
