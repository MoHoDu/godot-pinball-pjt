extends SceneTree


const BOARD_SCENE_PATH := "res://scenes/test_flipper/test_flipper_board.tscn"
const EXPECTED_LAUNCH_SPEED := 940.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "자유 테스트용 사각 플리퍼 보드 씬이 필요하다.")
	if packed_scene == null:
		_finish()
		return

	var board := packed_scene.instantiate()
	root.add_child(board)
	await process_frame

	_test_board_structure(board)
	_test_wall_extensions(board)
	await _test_reset_and_launcher(board)
	await _test_bumper_speed_only(board)

	board.queue_free()
	await process_frame
	_finish()


func _test_board_structure(board: Node) -> void:
	var selector := board.get_node_or_null("FlipperSelector")
	var walls := board.get_node_or_null("Walls")
	var bumpers := board.get_node_or_null("Bumpers")
	var ball := board.get_node_or_null("PinballBall") as RigidBody2D

	_expect(selector != null, "보드에 4방향 플리퍼 선택 관리자가 필요하다.")
	_expect(walls != null and walls.get_child_count() == 8, \
		"각 플리퍼 구역을 비우도록 외벽을 8개 구간으로 나눠야 한다.")
	_expect(bumpers != null and bumpers.get_child_count() == 3, \
		"자유 반사 시험을 위한 단순 범퍼 3개가 필요하다.")
	_expect(ball != null, "보드에 테스트 공이 필요하다.")

	if selector != null:
		var controllers: Array[Node] = []
		for child: Node in selector.get_children():
			if child is FlipperController:
				controllers.append(child)
		_expect(controllers.size() == 4, \
			"사각형 보드는 상·하·좌·우 플리퍼 그룹 4개를 가져야 한다.")
		for controller: Node in controllers:
			var flipper_count := 0
			var pivot_positions: Array[float] = []
			for child: Node in controller.get_children():
				if child is PinballFlipper:
					flipper_count += 1
					pivot_positions.append((child as Node2D).position.x)
					_expect(is_equal_approx(
						float(child.get(&"flipper_length")),
						328.0
					), "각 서브 플리퍼 길이는 기획 기준 328px이어야 한다.")
			_expect(flipper_count == 2, \
				"각 방향 그룹은 서브 플리퍼 2개로 구성되어야 한다.")
			pivot_positions.sort()
			if pivot_positions.size() == 2:
				_expect(is_equal_approx(
					pivot_positions[1] - pivot_positions[0],
					460.0
				), "두 회전축은 화면상 중앙 갭 44px이 보이는 간격이어야 한다.")


func _test_wall_extensions(board: Node) -> void:
	var horizontal_wall := board.get_node_or_null(
		"Walls/TopLeftWall/CollisionShape2D"
	) as CollisionShape2D
	var vertical_wall := board.get_node_or_null(
		"Walls/LeftTopWall/CollisionShape2D"
	) as CollisionShape2D
	_expect(
		horizontal_wall != null
		and horizontal_wall.shape is RectangleShape2D
		and is_equal_approx(
			(horizontal_wall.shape as RectangleShape2D).size.x,
			640.0
		),
		"가로 외벽은 플리퍼 바깥 축 옆까지 640px로 연장되어야 한다."
	)
	_expect(
		vertical_wall != null
		and vertical_wall.shape is RectangleShape2D
		and is_equal_approx(
			(vertical_wall.shape as RectangleShape2D).size.y,
			220.0
		),
		"세로 외벽은 플리퍼 바깥 축 옆까지 220px로 연장되어야 한다."
	)


func _test_reset_and_launcher(board: Node) -> void:
	var ball := board.get_node_or_null("PinballBall") as RigidBody2D
	if ball == null:
		return

	ball.global_position = Vector2(9999.0, 9999.0)
	ball.linear_velocity = Vector2(123.0, 456.0)
	board.call(&"reset_ball")
	await process_frame
	await process_frame

	var launcher_position: Vector2 = board.get(&"launcher_position")
	_expect(ball.global_position.is_equal_approx(launcher_position), \
		"R 리셋은 공을 발사 위치로 되돌려야 한다.")
	_expect(ball.linear_velocity.is_zero_approx(), \
		"R 리셋은 공의 속도를 제거해야 한다.")

	var launched: bool = bool(board.call(&"launch_ball"))
	_expect(launched, "Enter 발사 함수가 공을 발사해야 한다.")
	_expect(is_equal_approx(
		ball.linear_velocity.length(),
		EXPECTED_LAUNCH_SPEED
	), "발사 속력은 기획 기준 940px/s이어야 한다.")
	_expect(ball.linear_velocity.x < 0.0 and ball.linear_velocity.y < 0.0, \
		"오른쪽 아래 발사대는 공을 보드의 왼쪽 위 방향으로 보내야 한다.")


func _test_bumper_speed_only(board: Node) -> void:
	var bumper := board.get_node_or_null("Bumpers/BumperCenter")
	_expect(bumper != null, "범퍼가 필요하다.")
	if bumper == null:
		return
	_expect(not bumper.has_method(&"get_ball_impact"), \
		"범퍼는 방향 모드가 포함된 BallImpactResult를 전달하면 안 된다.")
	_expect(bumper.has_method(&"get_speed_multiplier"), \
		"범퍼는 속도 배율만 제공해야 한다.")
	_expect(bumper.has_method(&"apply_speed_multiplier"), \
		"Godot 반사 후 방향을 보존해 배율을 적용하는 함수가 필요하다.")
	if not bumper.has_method(&"get_speed_multiplier") \
		or not bumper.has_method(&"apply_speed_multiplier"):
		return

	var ball := board.get_node_or_null("PinballBall") as RigidBody2D
	if ball == null:
		return
	ball.freeze = false
	ball.linear_velocity = Vector2(300.0, -400.0)
	var direction_before := ball.linear_velocity.normalized()
	var speed_before := ball.linear_velocity.length()
	bumper.call(&"apply_speed_multiplier", ball)
	_expect(ball.linear_velocity.normalized().is_equal_approx(direction_before), \
		"범퍼 배율은 Godot가 정한 반사 방향을 바꾸면 안 된다.")
	_expect(ball.linear_velocity.length() > speed_before, \
		"범퍼 배율은 반사 후 속력을 증가시켜야 한다.")

	ball.freeze = true
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 1540.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.global_position = (bumper as Node2D).global_position + Vector2(0.0, -130.0)
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = Vector2(0.0, 600.0)
	ball.sleeping = false
	for _frame in 14:
		await physics_frame

	_expect(ball.linear_velocity.y < 0.0, \
		"범퍼 충돌 방향은 별도 지정 없이 Godot 기본 물리가 위쪽으로 반사해야 한다. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	_expect(ball.linear_velocity.length() > 600.0, \
		"Godot 기본 반사 후 범퍼 속도 배율이 적용되어야 한다. " \
		+ "(speed=%.1f)" % ball.linear_velocity.length())


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_board_scene_test")
		quit(0)
		return
	print("FAIL: test_flipper_board_scene_test (%d failures)" % _failures.size())
	quit(1)
