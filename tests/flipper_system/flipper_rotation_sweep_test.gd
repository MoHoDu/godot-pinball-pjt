extends SceneTree


const EPSILON := 0.001
const BASE_BALL_SCENE_PATH := "res://resources/balls/base/base_ball.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_right.tscn"
const START_ROTATION := -PI / 4.0
const END_ROTATION := PI / 4.0
const BALL_CENTER := Vector2(80.0, 0.0)
const BALL_RADIUS := 6.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flipper := _create_test_flipper()
	root.add_child(flipper)
	await process_frame

	var required_methods := [
		&"get_rotation_sweep_step_count",
		&"is_circle_overlapping_at_rotation",
		&"find_rotation_sweep_hit",
		&"resolve_rotation_sweep",
	]

	for method_name: StringName in required_methods:
		_expect(flipper.has_method(method_name), \
			"회전 구간 검사를 위한 %s API가 필요하다." % method_name)

	var interval_property := _find_property(flipper, &"rotation_sweep_interval")
	_expect(not interval_property.is_empty(), \
		"Rotation Sweep Interval은 Inspector에서 조정할 수 있어야 한다.")

	if _failures.is_empty():
		_test_step_count(flipper)
		_test_middle_angle_detection(flipper)
		_test_final_angle_detection(flipper)
		await _test_swept_ball_resolution(flipper)
		await _test_active_state_runs_rotation_sweep(flipper)
		await _test_actual_right_flipper_catches_falling_ball()
		await _test_pinball_registration()

	flipper.queue_free()
	await process_frame
	_finish()


func _create_test_flipper() -> PinballFlipper:
	var flipper := PinballFlipper.new()
	flipper.name = "SweepTestFlipper"
	flipper.flipper_length = 100.0

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture := GradientTexture2D.new()
	texture.width = 100
	texture.height = 20
	sprite.texture = texture
	flipper.add_child(sprite)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = PackedVector2Array([
		Vector2(0.0, -5.0),
		Vector2(100.0, -5.0),
		Vector2(100.0, 5.0),
		Vector2(0.0, 5.0),
	])
	flipper.add_child(collision)
	return flipper


func _test_step_count(flipper: PinballFlipper) -> void:
	flipper.set(&"rotation_sweep_interval", 8.0)
	var step_count := int(flipper.call(
		&"get_rotation_sweep_step_count",
		START_ROTATION,
		END_ROTATION
	))
	_expect(step_count > 1, \
		"플리퍼 끝이 안전 간격보다 멀리 움직이면 회전 구간을 여러 번 검사해야 한다.")


func _test_middle_angle_detection(flipper: PinballFlipper) -> void:
	var overlaps_start := bool(flipper.call(
		&"is_circle_overlapping_at_rotation",
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION
	))
	var overlaps_end := bool(flipper.call(
		&"is_circle_overlapping_at_rotation",
		BALL_CENTER,
		BALL_RADIUS,
		END_ROTATION
	))
	var hit := flipper.call(
		&"find_rotation_sweep_hit",
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	) as Dictionary

	_expect(not overlaps_start and not overlaps_end, \
		"테스트 공은 시작 및 최종 각도의 콜라이더 밖에 있어야 한다.")
	_expect(not hit.is_empty(), \
		"시작과 최종 각도 사이에 있는 공을 회전 구간 검사로 발견해야 한다.")
	if not hit.is_empty():
		var hit_rotation := float(hit.get(&"rotation", START_ROTATION))
		_expect(hit_rotation > START_ROTATION and hit_rotation < END_ROTATION, \
			"충돌 각도는 시작과 최종 각도 사이여야 한다.")


func _test_final_angle_detection(flipper: PinballFlipper) -> void:
	var final_only_center := Vector2(70.0, 70.0)
	var small_radius := 1.0
	var overlaps_start := flipper.is_circle_overlapping_at_rotation(
		final_only_center,
		small_radius,
		START_ROTATION
	)
	var overlaps_end := flipper.is_circle_overlapping_at_rotation(
		final_only_center,
		small_radius,
		END_ROTATION
	)
	var hit := flipper.find_rotation_sweep_hit(
		final_only_center,
		small_radius,
		START_ROTATION,
		END_ROTATION
	)

	_expect(not overlaps_start and overlaps_end, \
		"테스트 원은 시작 각도 밖, 최종 각도 안에 있어야 한다.")
	_expect(not hit.is_empty(), \
		"빠른 회전은 최종 각도에서 처음 겹친 공도 회전 검사로 발견해야 한다.")
	if not hit.is_empty():
		_expect(absf(float(hit.get(&"progress", 0.0)) - 1.0) <= EPSILON, \
			"최종 각도 충돌의 진행도는 1이어야 한다.")


func _test_swept_ball_resolution(flipper: PinballFlipper) -> void:
	var ball := RigidBody2D.new()
	ball.name = "SweepTestBall"
	ball.gravity_scale = 0.0
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")

	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await physics_frame

	ball.global_position = BALL_CENTER
	ball.linear_velocity = Vector2.ZERO
	flipper.rotation = END_ROTATION
	_expect(ball.is_in_group(&"pinball_balls"), \
		"테스트 공이 회전 구간 검사 그룹에 등록되어야 한다.")
	_expect(ball_collision.global_position.is_equal_approx(BALL_CENTER), \
		"테스트 공의 충돌 중심이 의도한 중간 각도 위치에 있어야 한다. " \
		+ "(expected=%s, actual=%s)" % [BALL_CENTER, ball_collision.global_position])
	var direct_hit := flipper.call(
		&"find_rotation_sweep_hit",
		ball_collision.global_position,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	) as Dictionary
	_expect(not direct_hit.is_empty(), \
		"실제 공의 전역 충돌 중심으로도 중간 회전 충돌을 찾을 수 있어야 한다.")
	var resolved_count := int(flipper.call(
		&"resolve_rotation_sweep",
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0
	))

	_expect(resolved_count == 1, \
		"회전 구간 안의 공 한 개를 감지하고 분리해야 한다.")
	_expect(not ball.global_position.is_equal_approx(BALL_CENTER), \
		"감지한 공을 최종 플리퍼 진행 방향 앞으로 이동시켜야 한다.")
	_expect(ball.linear_velocity.length() > EPSILON, \
		"감지한 공에 플리퍼 표면 이동 속도를 전달해야 한다.")

	ball.queue_free()
	await process_frame


func _test_pinball_registration() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")
	if ball_scene == null:
		return

	var ball := ball_scene.instantiate() as RigidBody2D
	root.add_child(ball)
	await process_frame
	_expect(ball.is_in_group(&"pinball_balls"), \
		"Pinball은 회전 구간 검사가 찾을 수 있도록 pinball_balls 그룹에 등록되어야 한다.")
	ball.queue_free()
	await process_frame


func _test_active_state_runs_rotation_sweep(flipper: PinballFlipper) -> void:
	var ball := RigidBody2D.new()
	ball.name = "ActiveSweepTestBall"
	ball.gravity_scale = 0.0
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")

	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await process_frame

	var rules := FlipperStateRules.new()
	rules.activation_time = 0.01
	flipper.initial_angle_degrees = rad_to_deg(START_ROTATION)
	flipper.maximum_angle_degrees = rad_to_deg(END_ROTATION)
	flipper.set_state_rules(rules)
	ball.global_position = BALL_CENTER
	ball.linear_velocity = Vector2.ZERO
	var direct_hit := flipper.find_rotation_sweep_hit(
		ball_collision.global_position,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	)
	_expect(not direct_hit.is_empty(), \
		"ACTIVE 상태 시작 직전에도 공이 중간 회전 구간 안에 있어야 한다.")

	var activated := flipper.request_activation()
	_expect(activated, "대기 상태 플리퍼가 자동 회전 구간 테스트를 시작할 수 있어야 한다.")
	await physics_frame
	# SceneTree.physics_frame 신호는 노드의 _physics_process보다 먼저 발생합니다.
	await physics_frame

	_expect(not ball.global_position.is_equal_approx(BALL_CENTER), \
		"ACTIVE 상태의 실제 물리 갱신이 회전 구간 안의 공을 자동으로 분리해야 한다.")
	_expect(ball.linear_velocity.length() > EPSILON, \
		"ACTIVE 상태의 실제 물리 갱신이 공에 표면 속도를 전달해야 한다.")

	ball.queue_free()
	await process_frame


func _test_actual_right_flipper_catches_falling_ball() -> void:
	var packed_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "실제 오른쪽 플리퍼 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		return

	var flipper := packed_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	await process_frame

	var start_rotation := deg_to_rad(-45.0)
	var end_rotation := deg_to_rad(45.0)
	var ball_radius := 57.6
	var falling_ball_center := flipper.global_position + Vector2(-400.0, 0.0)
	_expect(not flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		start_rotation
	), "실제 테스트 공은 오른쪽 플리퍼 초기 각도 밖에 있어야 한다.")
	_expect(not flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		end_rotation
	), "실제 테스트 공은 오른쪽 플리퍼 최대 각도 밖에 있어야 한다.")
	_expect(flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		0.0
	), "실제 테스트 공은 오른쪽 플리퍼의 중간 회전 궤도 안에 있어야 한다.")

	var ball := RigidBody2D.new()
	ball.name = "ActualRightFlipperTestBall"
	ball.gravity_scale = 0.0
	ball.global_position = falling_ball_center
	ball.linear_velocity = Vector2(0.0, 400.0)
	ball.add_to_group(&"pinball_balls")
	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = ball_radius
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await process_frame

	var rules := FlipperStateRules.new()
	rules.activation_time = 0.01
	flipper.initial_angle_degrees = -45.0
	flipper.maximum_angle_degrees = 45.0
	flipper.set_state_rules(rules)
	ball.global_position = falling_ball_center
	ball.linear_velocity = Vector2(0.0, 400.0)
	_expect(flipper.request_activation(), \
		"실제 오른쪽 플리퍼가 ACTIVE 상태로 진입할 수 있어야 한다.")
	await physics_frame
	await physics_frame

	_expect(ball.linear_velocity.y < 0.0, \
		"중간 궤도의 낙하 공은 오른쪽 플리퍼를 통과하지 않고 위로 타격되어야 한다.")

	ball.queue_free()
	flipper.queue_free()
	await process_frame


func _find_property(object: Object, property_name: StringName) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return property

	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_rotation_sweep_test")
		quit(0)
		return

	print("FAIL: flipper_rotation_sweep_test (%d failures)" % _failures.size())
	quit(1)
