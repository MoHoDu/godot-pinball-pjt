extends SceneTree


const TEST_SCENE_PATH := "res://scenes/tests/flippers/test_flipper.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "플리퍼 테스트 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		_finish()
		return

	var test_scene := packed_scene.instantiate()
	root.add_child(test_scene)
	await process_frame

	var ball := test_scene.get_node_or_null("PinballBall") as RigidBody2D
	_expect(ball != null, "플리퍼 테스트 씬에 PinballBall이 필요하다.")
	_expect(test_scene.has_method(&"_input"), \
		"R 입력은 다른 노드의 입력 처리 여부와 관계없이 받을 수 있어야 한다.")
	if ball == null or not test_scene.has_method(&"_input"):
		test_scene.queue_free()
		await process_frame
		_finish()
		return

	var authored_position := test_scene.get(&"ball_reset_position") as Vector2
	ball.global_position = Vector2(900.0, 900.0)
	ball.linear_velocity = Vector2(300.0, 400.0)
	ball.angular_velocity = 10.0
	var reset_snapshot := {
		&"completed": false,
		&"position": Vector2.ZERO,
		&"linear_velocity": Vector2.ZERO,
		&"angular_velocity": 0.0,
		&"freeze": true,
	}
	test_scene.ball_reset_completed.connect(func() -> void:
		reset_snapshot[&"completed"] = true
		reset_snapshot[&"position"] = ball.global_position
		reset_snapshot[&"linear_velocity"] = ball.linear_velocity
		reset_snapshot[&"angular_velocity"] = ball.angular_velocity
		reset_snapshot[&"freeze"] = ball.freeze
	, CONNECT_ONE_SHOT)

	var reset_event := InputEventKey.new()
	reset_event.pressed = true
	reset_event.physical_keycode = KEY_R
	test_scene.call(&"_input", reset_event)
	await process_frame

	_expect(bool(reset_snapshot[&"completed"]), \
		"R 입력 후 공 리셋 완료 신호가 발생해야 한다.")
	_expect_vector(reset_snapshot[&"position"], authored_position, \
		"R을 누르면 에디터에서 배치한 공 시작 위치로 돌아와야 한다.")
	_expect_vector(reset_snapshot[&"linear_velocity"], Vector2.ZERO, \
		"R 복귀 후 공의 선속도는 0이어야 한다.")
	_expect(absf(float(reset_snapshot[&"angular_velocity"])) <= EPSILON, \
		"R 복귀 후 공의 각속도는 0이어야 한다.")
	_expect(not bool(reset_snapshot[&"freeze"]), \
		"R 복귀가 끝나면 공 물리가 다시 활성화되어야 한다.")
	await _test_scene_right_flipper_catches_ball(test_scene, ball)

	test_scene.queue_free()
	await process_frame
	_finish()


func _test_scene_right_flipper_catches_ball(
	test_scene: Node,
	ball: RigidBody2D
) -> void:
	var controller := test_scene.get_node_or_null(
		"FlipperControllers/FlipperController"
	) as FlipperController
	var right_flipper := test_scene.get_node_or_null(
		"FlipperControllers/FlipperController/RightFlipper"
	) as PinballFlipper
	_expect(controller != null, \
		"test_flipper 씬의 실제 플리퍼 컨트롤러를 찾을 수 있어야 한다.")
	_expect(right_flipper != null, \
		"test_flipper 씬의 실제 오른쪽 플리퍼를 찾을 수 있어야 한다.")
	if controller == null or right_flipper == null:
		return

	var ball_collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var circle := ball_collision.shape as CircleShape2D
	var ball_radius := circle.radius
	var start_rotation := deg_to_rad(right_flipper.initial_angle_degrees)
	var end_rotation := deg_to_rad(right_flipper.maximum_angle_degrees)
	var middle_rotation := lerp_angle(start_rotation, end_rotation, 0.5)
	var sweep_position := right_flipper.global_position + Vector2(-400.0, 0.0)

	_expect(not right_flipper.is_circle_overlapping_at_rotation(
		sweep_position,
		ball_radius,
		start_rotation
	), "장면 테스트 공은 오른쪽 플리퍼 초기 각도 밖에 있어야 한다.")
	_expect(not right_flipper.is_circle_overlapping_at_rotation(
		sweep_position,
		ball_radius,
		end_rotation
	), "장면 테스트 공은 오른쪽 플리퍼 최대 각도 밖에 있어야 한다.")
	_expect(right_flipper.is_circle_overlapping_at_rotation(
		sweep_position,
		ball_radius,
		middle_rotation
	), "장면 테스트 공은 오른쪽 플리퍼의 중간 회전 궤도 안에 있어야 한다.")

	ball.freeze = false
	ball.global_position = sweep_position
	ball.linear_velocity = Vector2(0.0, 400.0)
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.reset_physics_interpolation()
	var position_before_activation := ball.global_position
	var rotation_before_activation := right_flipper.rotation
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 0.125

	Input.action_press(&"flipper")
	var observed_upward_hit := false
	var observed_active_state := false
	var observed_ball_displacement := false
	var sweep_snapshot := {
		&"resolved": false,
		&"position_before_step": ball.global_position,
		&"position_at_resolution": ball.global_position,
	}
	var frame_trace: Array[String] = []
	right_flipper.rotation_sweep_resolved.connect(func(resolved_ball: RigidBody2D) -> void:
		if resolved_ball == ball:
			sweep_snapshot[&"resolved"] = true
			sweep_snapshot[&"position_at_resolution"] = ball.global_position
	)
	for _step in 80:
		sweep_snapshot[&"position_before_step"] = ball.global_position
		await physics_frame
		var current_observed_rotation := right_flipper.rotation
		frame_trace.append("angle=%.2f position=%s velocity=%s" % [
			rad_to_deg(current_observed_rotation),
			ball_collision.global_position,
			ball.linear_velocity,
		])
		if right_flipper.get_current_state_type() != FlipperState.Type.IDLE:
			observed_active_state = true
		if not ball.global_position.is_equal_approx(position_before_activation):
			observed_ball_displacement = true
		if ball.linear_velocity.y < 0.0:
			observed_upward_hit = true
			break
	Input.action_release(&"flipper")
	Engine.time_scale = original_time_scale

	_expect(controller.is_active, \
		"test_flipper 씬의 단일 컨트롤러는 선택되어 활성 상태여야 한다.")
	_expect(observed_active_state, \
		"flipper 입력 후 오른쪽 플리퍼가 ACTIVE 상태로 진입해야 한다.")
	_expect(not is_equal_approx(right_flipper.rotation, rotation_before_activation), \
		"flipper 입력 후 오른쪽 플리퍼의 각도가 실제로 변해야 한다.")
	_expect(bool(sweep_snapshot[&"resolved"]), \
		"오른쪽 플리퍼의 회전 안전 검사가 실제 테스트 공을 처리해야 한다. " \
		+ "(ball_group=%s, trace=%s)" % [
			ball.is_in_group(&"pinball_balls"),
			frame_trace,
		])
	var position_at_resolution: Vector2 = sweep_snapshot[&"position_at_resolution"]
	var position_before_step: Vector2 = sweep_snapshot[&"position_before_step"]
	var resolution_step_distance := position_at_resolution.distance_to(
		position_before_step
	)
	_expect(resolution_step_distance <= 2.0, \
		"1/8 배속 회전 충돌은 한 틱의 자연 이동을 넘어 공 Transform을 순간이동시키면 안 된다. " \
		+ "(step_distance=%.3f)" % resolution_step_distance)
	_expect(observed_ball_displacement, \
		"회전 안전 검사가 공을 플리퍼 진행 방향 앞으로 분리해야 한다.")
	_expect(observed_upward_hit, \
		"test_flipper 씬에서 낙하 공은 오른쪽 플리퍼 중간 궤도를 통과하지 않아야 한다. " \
		+ "(ball_position=%s, ball_velocity=%s, flipper_rotation=%s, trace=%s)" % [
			ball.global_position,
			ball.linear_velocity,
			rad_to_deg(right_flipper.rotation),
			frame_trace,
		])


func _expect_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_scene_test")
		quit(0)
		return

	print("FAIL: test_flipper_scene_test (%d failures)" % _failures.size())
	quit(1)
