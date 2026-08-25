extends SceneTree


const BALL_CASES: Array[Dictionary] = [
	{
		&"name": &"dead_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/elastic/dead_ball.tscn",
		&"expected_diameter": 34.0,
		&"expected_safety_maximum": 3000.0,
	},
	{
		&"name": &"gel_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn",
		&"expected_diameter": 64.0,
		&"expected_safety_maximum": 5000.0,
	},
	{
		&"name": &"normal_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn",
		&"expected_diameter": 64.0,
		&"expected_safety_maximum": 5000.0,
	},
]
const OVERRIDE_SPEED := 5000.0
const OUT_OF_RANGE_SPEED := 6000.0
const EPSILON := 0.01


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for ball_case: Dictionary in BALL_CASES:
		await _test_ball_case(ball_case)
	await _test_collision_radius_reduces_safety_limit()
	_finish()


func _test_ball_case(ball_case: Dictionary) -> void:
	var ball_scene := load(String(ball_case[&"scene_path"])) as PackedScene
	_expect(ball_scene != null and ball_scene.can_instantiate(), \
		"%s 실제 씬을 불러올 수 있어야 한다." % ball_case[&"name"])
	if ball_scene == null:
		return

	var ball := ball_scene.instantiate() as Pinball
	root.add_child(ball)
	await process_frame
	ball.stats = ball.stats.duplicate(true) as PinballStats
	ball.physics_rules = ball.physics_rules.duplicate(true) as PinballPhysicsRules
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = OUT_OF_RANGE_SPEED
	ball.stats.initial_speed = OUT_OF_RANGE_SPEED
	ball.stats.gravity_scale = 0.0
	ball.physics_rules.maximum_speed = OUT_OF_RANGE_SPEED

	var expected_diameter := float(ball_case[&"expected_diameter"])
	var expected_safety_maximum := float(
		ball_case[&"expected_safety_maximum"]
	)
	_expect_float(ball.ball_diameter, expected_diameter,
		"%s 실제 지름이 안전 규칙 기준과 일치해야 한다." % ball_case[&"name"])
	_expect_float(ball.stats.maximum_speed, expected_safety_maximum,
		"%s 개별 Stats는 크기별 안전 상한을 넘겨 저장할 수 없어야 한다." % ball_case[&"name"])
	_expect_float(ball.stats.initial_speed, expected_safety_maximum,
		"%s 초기 속력도 보정된 개별 최대 속력을 넘으면 안 된다." % ball_case[&"name"])
	_expect_float(
		ball.physics_rules.maximum_speed,
		PinballPhysicsRules.FULL_SAFE_MAXIMUM_SPEED,
		"%s 공용 Rules는 프로젝트 절대 상한을 넘겨 저장할 수 없어야 한다." % ball_case[&"name"]
	)
	_expect_float(ball.get_safe_maximum_speed(), expected_safety_maximum,
		"%s 크기별 절대 안전 상한이 적용되어야 한다." % ball_case[&"name"])

	var limited := ball.get_limited_velocity(Vector2.RIGHT * OUT_OF_RANGE_SPEED)
	_expect_float(limited.length(), expected_safety_maximum,
		"%s는 개별·공용 설정을 높여도 안전 상한을 넘으면 안 된다." % ball_case[&"name"])
	ball.launch(Vector2.RIGHT, OUT_OF_RANGE_SPEED)
	_expect_float(ball.linear_velocity.length(), expected_safety_maximum,
		"%s 직접 발사 요청도 안전 상한을 우회하면 안 된다." % ball_case[&"name"])

	ball.linear_velocity = Vector2.RIGHT * OUT_OF_RANGE_SPEED
	await physics_frame
	# physics_frame은 물리 스텝 시작 전에 발생하므로, 다음 physics_frame까지
	# 기다려 그 사이에 한 번의 물리 적분이 완료되도록 합니다.
	await physics_frame
	_expect(ball.linear_velocity.length() <= expected_safety_maximum + EPSILON,
		"%s 물리 프레임 속도도 안전 상한을 넘으면 안 된다. (actual=%.2f)" % [
			ball_case[&"name"],
			ball.linear_velocity.length(),
		])

	ball.stats.maximum_speed = 2500.0
	_expect_float(
		ball.get_limited_velocity(Vector2.RIGHT * OVERRIDE_SPEED).length(),
		2500.0,
		"%s 개별 상한이 안전 상한보다 낮으면 개별 설정을 존중해야 한다." % ball_case[&"name"]
	)
	ball.stats.maximum_speed = OVERRIDE_SPEED
	_expect_float(ball.stats.maximum_speed, expected_safety_maximum,
		"%s 개별 상한 재입력도 즉시 안전 범위로 돌아와야 한다." % ball_case[&"name"])
	ball.physics_rules.maximum_speed = 2400.0
	_expect_float(
		ball.get_limited_velocity(Vector2.RIGHT * OVERRIDE_SPEED).length(),
		2400.0,
		"%s 공용 상한이 더 낮으면 공용 설정을 우선해야 한다." % ball_case[&"name"]
	)
	_expect_float(ball.stats.maximum_speed, expected_safety_maximum,
		"%s 낮은 공용 상한은 개별 설정 원본을 파괴하면 안 된다." % ball_case[&"name"])

	ball.queue_free()
	await process_frame


func _test_collision_radius_reduces_safety_limit() -> void:
	var ball_scene := load(
		"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
	) as PackedScene
	if ball_scene == null:
		return
	var ball := ball_scene.instantiate() as Pinball
	root.add_child(ball)
	await process_frame
	ball.stats = ball.stats.duplicate(true) as PinballStats
	ball.physics_rules = ball.physics_rules.duplicate(true) as PinballPhysicsRules
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = OVERRIDE_SPEED
	ball.collision_radius_ratio = 0.45

	var expected_collision_diameter := 64.0 * 0.45
	var expected_safety_maximum := (
		PinballPhysicsRules.COMPACT_SAFE_MAXIMUM_SPEED
		* expected_collision_diameter
		/ PinballPhysicsRules.COMPACT_COLLISION_DIAMETER
	)
	_expect_float(ball.get_collision_diameter(), expected_collision_diameter,
		"충돌 반지름 변경이 실제 안전 지름에 반영되어야 한다.")
	_expect_float(ball.get_safe_maximum_speed(), expected_safety_maximum,
		"충돌 범위를 줄이면 속도 안전 상한도 비례해 낮아져야 한다.")
	_expect_float(ball.stats.maximum_speed, expected_safety_maximum,
		"충돌 범위를 줄이면 개별 최대 속력도 즉시 새 안전 상한으로 보정되어야 한다.")
	_expect_float(
		ball.get_limited_velocity(Vector2.RIGHT * OVERRIDE_SPEED).length(),
		expected_safety_maximum,
		"작은 충돌 범위로 안전 상한을 우회하면 안 된다."
	)

	ball.queue_free()
	await process_frame


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON,
		"%s (expected=%.2f, actual=%.2f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_speed_safety_test")
		quit(0)
		return
	print("FAIL: pinball_speed_safety_test (%d failures)" % _failures.size())
	quit(1)
