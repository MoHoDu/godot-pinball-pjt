extends SceneTree


const BOARD_SCENE_PATH := "res://scenes/tests/flippers/test_flipper_board.tscn"
const TEST_SPEED := 1540.0
const START_OFFSET := Vector2(62.0, -150.0)
const ESCAPE_OFFSET_Y := 35.0
const MAX_TEST_FRAMES := 12


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var board_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(board_scene != null, "고속 대기 충돌 테스트에 실제 사각 보드 씬이 필요하다.")
	if board_scene == null:
		_finish()
		return

	var board := board_scene.instantiate()
	root.add_child(board)
	await physics_frame

	var flipper := board.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	var ball := board.get_node_or_null("PinballBall") as Pinball
	_expect(flipper != null, "영상과 같은 하단 왼쪽 플리퍼가 필요하다.")
	_expect(ball != null, "영상과 같은 실제 Pinball 공이 필요하다.")
	if flipper == null or ball == null:
		board.queue_free()
		await process_frame
		_finish()
		return

	_configure_ball(ball, flipper.global_position + START_OFFSET)
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = Vector2(0.0, TEST_SPEED)
	ball.sleeping = false

	var reflected_upward := false
	var escaped_below_flipper := false
	var deepest_position := ball.global_position
	for _frame in MAX_TEST_FRAMES:
		await physics_frame
		deepest_position.y = maxf(deepest_position.y, ball.global_position.y)
		if ball.linear_velocity.y < 0.0:
			reflected_upward = true
		if ball.global_position.y > flipper.global_position.y + ESCAPE_OFFSET_Y:
			escaped_below_flipper = true

	_expect(reflected_upward, \
		"1540px/s 공은 대기 중인 하단 플리퍼 몸통에서 위로 반사되어야 한다. " \
		+ "(position=%s, velocity=%s)" % [
			ball.global_position,
			ball.linear_velocity,
		])
	_expect(not escaped_below_flipper, \
		"1540px/s 공이 하단 플리퍼의 축-몸통 경계를 지나 보드 밖으로 터널링하면 안 된다. " \
		+ "(deepest_y=%.2f, flipper_y=%.2f)" % [
			deepest_position.y,
			flipper.global_position.y,
		])

	board.queue_free()
	await process_frame
	_finish()


func _configure_ball(ball: Pinball, start_position: Vector2) -> void:
	ball.freeze = true
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.global_position = start_position
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.reset_physics_interpolation()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_high_speed_idle_body_tunneling_test")
		quit(0)
		return
	print("FAIL: flipper_high_speed_idle_body_tunneling_test (%d failures)" \
		% _failures.size())
	quit(1)
