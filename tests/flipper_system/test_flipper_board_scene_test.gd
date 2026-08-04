extends SceneTree


const BOARD_SCENE_PATH := "res://scenes/test_flipper/test_flipper_board.tscn"
const BOARD_TEXTURE_PATH := "res://Resources/Art/board/octagonal_dark_wood_board.png"
const OUTSIDE_BACKGROUND_TEXTURE_PATH := (
	"res://Resources/Art/backgrounds/cursed_circus_outside_background.png"
)
const WALL_BODY_TEXTURE_PATH := (
	"res://Resources/Art/walls/cursed_toy_frame_v1/wall_body_256x40_cursed_toy_v1.png"
)
const WALL_LEFT_CAP_TEXTURE_PATH := (
	"res://Resources/Art/walls/cursed_toy_frame_v1/wall_end_cap_left_64x40_cursed_toy_v1.png"
)
const WALL_RIGHT_CAP_TEXTURE_PATH := (
	"res://Resources/Art/walls/cursed_toy_frame_v1/wall_end_cap_right_64x40_cursed_toy_v1.png"
)
const EXPECTED_BOARD_SIZE := Vector2(2240.0, 1260.0)
const EXPECTED_OUTSIDE_BACKGROUND_SOURCE_SIZE := Vector2(1672.0, 941.0)
const EXPECTED_WALL_BODY_REGION := Rect2(0.0, 0.0, 692.0, 40.0)
const EXPECTED_CONTROLLER_POSITIONS := {
	&"BottomController": Vector2(0.0, 550.0),
	&"TopController": Vector2(0.0, -550.0),
	&"LeftController": Vector2(-1040.0, 0.0),
	&"RightController": Vector2(1040.0, 0.0),
}
const EXPECTED_LAUNCHER_POSITION := Vector2(0.0, 400.0)
const EXPECTED_WALL_TRANSFORMS := {
	&"TopRightDiagonal": [Vector2(735.0, -490.0), 0.348772],
	&"BottomRightDiagonal": [Vector2(735.0, 490.0), 2.7928207],
	&"BottomLeftDiagonal": [Vector2(-735.0, 490.0), -2.7928207],
	&"TopLeftDiagonal": [Vector2(-735.0, -490.0), -0.348772],
}
const EXPECTED_WALL_LENGTH := 819.329
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
	_test_flipper_collision_geometry(board)
	_test_board_art(board)
	_test_octagonal_walls(board)
	await _test_idle_pivot_does_not_trap_ball(board)
	await _test_active_flipper_releases_adjacent_ball(board)
	await _test_active_flipper_reflects_toward_board(board)
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
	var launcher := board.get_node_or_null("PinballLauncher") as PinballLauncher

	_expect(selector != null, "보드에 4방향 플리퍼 선택 관리자가 필요하다.")
	_expect(walls != null and walls.get_child_count() == 4, \
		"팔각형 보드의 네 대각 변에 고정벽 4개가 있어야 한다.")
	_expect(bumpers != null and bumpers.get_child_count() == 3, \
		"자유 반사 시험을 위한 단순 범퍼 3개가 필요하다.")
	_expect(ball != null, "보드에 테스트 공이 필요하다.")
	_expect(launcher != null, "보드별 설정을 가진 PinballLauncher가 필요하다.")
	if launcher != null:
		_expect(launcher.global_position.is_equal_approx(EXPECTED_LAUNCHER_POSITION), \
			"팔각형 보드 발사대는 하단 중앙에 있어야 한다.")
		_expect(is_equal_approx(launcher.default_launch_speed, 940.0), \
			"사각 보드 기본 발사 속력은 Inspector에서 940px/s여야 한다.")
		_expect(launcher.get_effective_speed_range().is_equal_approx(
			Vector2(320.0, 1540.0)
		), "사각 보드 발사 파워 범위는 Inspector에서 320~1540px/s여야 한다.")
		_expect(is_equal_approx(launcher.minimum_launch_angle_degrees, -30.0) \
			and is_equal_approx(launcher.maximum_launch_angle_degrees, 30.0), \
			"사각 보드 발사 각도 범위는 중앙 방향 기준 ±30°여야 한다.")

	if selector != null:
		var controllers: Array[Node] = []
		for child: Node in selector.get_children():
			if child is FlipperController:
				controllers.append(child)
		_expect(controllers.size() == 4, \
			"사각형 보드는 상·하·좌·우 플리퍼 그룹 4개를 가져야 한다.")
		for controller: Node in controllers:
			var expected_controller_position: Vector2 = (
				EXPECTED_CONTROLLER_POSITIONS[controller.name]
			)
			_expect(
				(controller as Node2D).position.is_equal_approx(
					expected_controller_position
				),
				"%s 플리퍼 그룹이 팔각형 평면 변 중앙에 있어야 한다." % controller.name
			)
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
					700.0
				), "두 외곽 회전축은 328 + 44 + 328 = 700px 간격이어야 한다.")


func _test_board_art(board: Node) -> void:
	var outside_background := board.get_node_or_null("OutsideBackground") as Sprite2D
	_expect(outside_background != null, "보드 뒤에 외부 배경 Sprite2D가 필요하다.")
	if outside_background != null:
		_expect(outside_background.texture != null, "외부 배경 텍스처가 필요하다.")
		if outside_background.texture != null:
			_expect(
				outside_background.texture.resource_path == OUTSIDE_BACKGROUND_TEXTURE_PATH,
				"외부 배경은 지정된 저주받은 서커스 PNG를 사용해야 한다."
			)
			_expect(
				outside_background.texture.get_size().is_equal_approx(
					EXPECTED_OUTSIDE_BACKGROUND_SOURCE_SIZE
				),
				"외부 배경 원본은 1672x941px이어야 한다."
			)
			var outside_rendered_size := (
				outside_background.texture.get_size()
				* outside_background.scale.abs()
			)
			_expect(
				outside_rendered_size.distance_to(EXPECTED_BOARD_SIZE) < 0.01,
				"외부 배경은 2240x1260 보드 캔버스를 빈틈없이 채워야 한다."
			)
		_expect(outside_background.position.is_zero_approx(), \
			"외부 배경 중심은 보드 중심과 일치해야 한다.")
		_expect(outside_background.z_index < -10, \
			"외부 배경은 보드 베이스보다 뒤에 그려져야 한다.")

	var background := board.get_node_or_null("BoardBackground") as Sprite2D
	_expect(background != null, "보드 배경은 이미지용 Sprite2D여야 한다.")
	if background == null:
		return

	_expect(background.texture != null, "보드 배경 텍스처가 필요하다.")
	if background.texture == null:
		return

	_expect(background.texture.resource_path == BOARD_TEXTURE_PATH, \
		"보드 배경은 지정된 어두운 목재 텍스처를 사용해야 한다.")
	var rendered_size := background.texture.get_size() * background.scale.abs()
	_expect(rendered_size.is_equal_approx(EXPECTED_BOARD_SIZE), \
		"보드 배경은 팔각형 기준 월드 크기 2240x1260이어야 한다.")


func _test_octagonal_walls(board: Node) -> void:
	var walls := board.get_node_or_null("Walls")
	if walls == null:
		return

	for wall_name: StringName in EXPECTED_WALL_TRANSFORMS:
		var wall := walls.get_node_or_null(NodePath(String(wall_name))) as StaticBody2D
		_expect(wall != null, "%s 고정벽이 필요하다." % wall_name)
		if wall == null:
			continue

		var expected_transform: Array = EXPECTED_WALL_TRANSFORMS[wall_name]
		var expected_position: Vector2 = expected_transform[0]
		var expected_rotation: float = float(expected_transform[1])
		_expect(wall.position.is_equal_approx(expected_position), \
			"%s 고정벽 중심이 보드 대각 변 중앙과 일치해야 한다." % wall_name)
		_expect(is_equal_approx(wall.rotation, expected_rotation), \
			"%s 고정벽 각도가 보드 대각 변과 일치해야 한다." % wall_name)

		var collision := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(
			collision != null
			and collision.shape is RectangleShape2D
			and is_equal_approx(
				(collision.shape as RectangleShape2D).size.x,
				EXPECTED_WALL_LENGTH
			)
			and is_equal_approx(
				(collision.shape as RectangleShape2D).size.y,
				24.0
			),
			"%s 고정벽은 819.33x24px 충돌체여야 한다." % wall_name
		)
		if collision != null:
			_expect(collision.position.is_equal_approx(Vector2(0.0, 12.0)), \
				"%s 충돌 두께는 보드 외곽에서 안쪽으로만 들어와야 한다." % wall_name)

		var visual := wall.get_node_or_null("Visual") as Node2D
		_expect(visual != null, "%s 고정벽은 모듈형 아트 씬을 사용해야 한다." % wall_name)
		if visual == null:
			continue
		_expect(visual.position.is_zero_approx(), \
			"%s 고정벽 아트 중심은 도면 경계 중심과 일치해야 한다." % wall_name)

		var body := visual.get_node_or_null("Body") as Sprite2D
		var left_cap := visual.get_node_or_null("LeftCap") as Sprite2D
		var right_cap := visual.get_node_or_null("RightCap") as Sprite2D
		_expect(body != null, "%s 고정벽에 반복 몸통이 필요하다." % wall_name)
		_expect(left_cap != null and right_cap != null, \
			"%s 고정벽에 좌우 끝 캡이 필요하다." % wall_name)
		if body == null or left_cap == null or right_cap == null:
			continue

		_expect(body.texture != null and body.texture.resource_path == WALL_BODY_TEXTURE_PATH, \
			"%s 고정벽 몸통은 256x40px 마스터 타일을 사용해야 한다." % wall_name)
		_expect(body.region_enabled and body.region_rect == EXPECTED_WALL_BODY_REGION, \
			"%s 고정벽 몸통은 좌우 캡 사이 692x40px를 반복해야 한다." % wall_name)
		_expect(body.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED, \
			"%s 고정벽 몸통 텍스처 반복이 활성화되어야 한다." % wall_name)
		_expect(
			left_cap.texture != null
			and left_cap.texture.resource_path == WALL_LEFT_CAP_TEXTURE_PATH
			and left_cap.position.is_equal_approx(Vector2(-378.0, 0.0)),
			"%s 왼쪽 캡은 벽의 -410~-346px 구간에 있어야 한다." % wall_name
		)
		_expect(
			right_cap.texture != null
			and right_cap.texture.resource_path == WALL_RIGHT_CAP_TEXTURE_PATH
			and right_cap.position.is_equal_approx(Vector2(378.0, 0.0)),
			"%s 오른쪽 캡은 벽의 346~410px 구간에 있어야 한다." % wall_name
		)


func _test_flipper_collision_geometry(board: Node) -> void:
	var left := board.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	var right := board.get_node_or_null(
		"FlipperSelector/BottomController/RightFlipper"
	) as PinballFlipper
	var ball := board.get_node_or_null("PinballBall") as Pinball
	_expect(left != null and right != null and ball != null, \
		"QA 충돌 형상 검사에는 하단 플리퍼 쌍과 실제 공이 필요하다.")
	if left == null or right == null or ball == null:
		return

	for flipper: PinballFlipper in [left, right]:
		var collision := flipper.get_node("CollisionPolygon2D") as CollisionPolygon2D
		var maximum_radius := 0.0
		for point: Vector2 in collision.transform * collision.polygon:
			maximum_radius = maxf(maximum_radius, point.length())
		_expect(
			maximum_radius <= flipper.flipper_length * 0.8,
			"플리퍼 콜라이더가 스프라이트 길이보다 중앙 갭 쪽으로 돌출되면 안 된다. " \
			+ "(flipper=%s, radius=%.2f)" % [flipper.name, maximum_radius]
		)

	var ball_radius := _get_ball_radius(ball)
	var gap_center := Vector2(
		(left.global_position.x + right.global_position.x) * 0.5,
		maxf(left.global_position.y, right.global_position.y) + ball_radius
	)
	for flipper: PinballFlipper in [left, right]:
		var gap_hit := flipper.find_rotation_sweep_hit(
			gap_center,
			ball_radius,
			deg_to_rad(flipper.initial_angle_degrees),
			deg_to_rad(flipper.maximum_angle_degrees),
			true
		)
		_expect(gap_hit.is_empty(), \
			"중앙 갭을 통과하는 공을 플리퍼 스윕 충돌로 판정하면 안 된다. " \
			+ "(flipper=%s, hit=%s)" % [flipper.name, gap_hit])


func _test_idle_pivot_does_not_trap_ball(board: Node) -> void:
	var flipper := board.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	var ball := board.get_node_or_null("PinballBall") as Pinball
	if flipper == null or ball == null:
		return

	_configure_qa_ball(ball, 0.35, true)
	ball.global_position = flipper.global_position + Vector2(70.0, -24.0)
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	var start_position := ball.global_position
	await physics_frame
	ball.freeze = false
	ball.sleeping = false

	for _frame in 90:
		await physics_frame

	_expect(
		ball.global_position.distance_to(start_position) >= 24.0,
		"대기 플리퍼 축 옆에 놓인 공이 포켓에 안착해 정지하면 안 된다. " \
		+ "(start=%s, end=%s, velocity=%s)" % [
			start_position,
			ball.global_position,
			ball.linear_velocity,
		]
	)
	ball.freeze = true


func _test_active_flipper_releases_adjacent_ball(board: Node) -> void:
	var flipper := board.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	var ball := board.get_node_or_null("PinballBall") as Pinball
	if flipper == null or ball == null:
		return

	flipper.set_physics_process(false)
	_configure_qa_ball(ball, 0.0, false)
	var start_rotation := deg_to_rad(flipper.initial_angle_degrees)
	var end_rotation := deg_to_rad(flipper.maximum_angle_degrees)
	var adjacent_position := _find_sweep_test_position(
		flipper,
		_get_ball_radius(ball),
		start_rotation,
		end_rotation,
		true,
		100.0
	)
	_expect(not adjacent_position.is_zero_approx(), \
		"축 인접 저속 공을 배치할 실제 충돌 위치를 찾아야 한다.")
	if adjacent_position.is_zero_approx():
		flipper.set_physics_process(true)
		return

	ball.global_position = adjacent_position
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	ball.freeze = false
	ball.sleeping = false
	var resolved := flipper.resolve_rotation_sweep(
		start_rotation,
		end_rotation,
		1.0 / 60.0,
		0.0
	)
	await physics_frame

	_expect(resolved == 1, \
		"축 인접 저속 공은 작동 첫 스윕이 한 번 소유해야 한다.")
	_expect(ball.linear_velocity.length() >= 100.0, \
		"축 인접 저속 공은 플리퍼 타격 뒤 정지 상태를 벗어나야 한다. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	_expect(ball.linear_velocity.y < 0.0, \
		"하단 플리퍼는 축 인접 공도 보드 안쪽으로 타격해야 한다. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	ball.freeze = true
	ball.collision_layer = 1
	ball.collision_mask = 1
	flipper.set_physics_process(true)


func _test_active_flipper_reflects_toward_board(board: Node) -> void:
	var flipper := board.get_node_or_null(
		"FlipperSelector/BottomController/RightFlipper"
	) as PinballFlipper
	var ball := board.get_node_or_null("PinballBall") as Pinball
	if flipper == null or ball == null:
		return

	flipper.set_physics_process(false)
	_configure_qa_ball(ball, 0.0, false)
	var start_rotation := deg_to_rad(flipper.initial_angle_degrees)
	var end_rotation := deg_to_rad(flipper.maximum_angle_degrees)
	var sweep_position := _find_sweep_test_position(
		flipper,
		_get_ball_radius(ball),
		start_rotation,
		end_rotation,
		false,
		INF
	)
	_expect(not sweep_position.is_zero_approx(), \
		"우측 플리퍼의 실제 회전 궤도 안에서 방향 검사 위치를 찾아야 한다.")
	if sweep_position.is_zero_approx():
		flipper.set_physics_process(true)
		return

	ball.global_position = sweep_position
	ball.linear_velocity = Vector2(0.0, 120.0)
	ball.reset_physics_interpolation()
	ball.freeze = false
	ball.sleeping = false
	var resolved := flipper.resolve_rotation_sweep(
		start_rotation,
		end_rotation,
		1.0 / 60.0,
		0.0
	)
	await physics_frame

	_expect(resolved == 1, "우측 플리퍼 회전 궤도의 공을 한 번 타격해야 한다.")
	_expect(ball.linear_velocity.y < 0.0, \
		"우측 하단 플리퍼 타격은 공을 보드 바깥쪽으로 꺾으면 안 된다. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	ball.freeze = true
	ball.collision_layer = 1
	ball.collision_mask = 1
	flipper.set_physics_process(true)


func _find_sweep_test_position(
	flipper: PinballFlipper,
	ball_radius: float,
	start_rotation: float,
	end_rotation: float,
	include_initial_overlap: bool,
	maximum_pivot_distance: float
) -> Vector2:
	for y_offset in range(-150, 21, 10):
		for x_distance in range(50, 251, 10):
			var direction := 1.0 if flipper.name == &"LeftFlipper" else -1.0
			var candidate := flipper.global_position + Vector2(
				direction * float(x_distance),
				float(y_offset)
			)
			if candidate.distance_to(flipper.global_position) > maximum_pivot_distance:
				continue
			var hit := flipper.find_rotation_sweep_hit(
				candidate,
				ball_radius,
				start_rotation,
				end_rotation,
				include_initial_overlap
			)
			if not hit.is_empty():
				return candidate
	return Vector2.ZERO


func _configure_qa_ball(
	ball: Pinball,
	gravity_scale: float,
	use_physics_collision: bool
) -> void:
	ball.freeze = true
	ball.collision_layer = 1 if use_physics_collision else 0
	ball.collision_mask = 1 if use_physics_collision else 0
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = gravity_scale
	ball.stats.elasticity = 0.9
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false


func _get_ball_radius(ball: Pinball) -> float:
	var collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D
	return circle.radius * collision.global_scale.abs().x

func _test_reset_and_launcher(board: Node) -> void:
	var ball := board.get_node_or_null("PinballBall") as RigidBody2D
	if ball == null:
		return

	ball.global_position = Vector2(9999.0, 9999.0)
	ball.linear_velocity = Vector2(123.0, 456.0)
	board.call(&"reset_ball")
	await process_frame
	await process_frame

	var launcher := board.get_node_or_null("PinballLauncher") as PinballLauncher
	_expect(launcher != null, "리셋과 발사를 담당할 PinballLauncher가 필요하다.")
	if launcher == null:
		return
	_expect(ball.global_position.is_equal_approx(launcher.global_position), \
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
		"하단 중앙 발사대는 공을 보드의 왼쪽 위 방향으로 보내야 한다.")

	# reset_ball()의 비동기 정리보다 입력 액션 발사가 먼저 와도 공을 다시 얼리지 않아야 한다.
	board.call(&"reset_ball")
	var confirm_event := InputEventAction.new()
	confirm_event.action = &"ball_launch_confirm"
	confirm_event.pressed = true
	launcher._input(confirm_event)
	await process_frame
	await physics_frame
	_expect(not ball.freeze, \
		"발사 확정 액션 직후 비동기 리셋 정리가 발사한 공을 다시 고정하면 안 된다.")
	_expect(absf(ball.linear_velocity.length() - EXPECTED_LAUNCH_SPEED) < 10.0, \
		"발사 확정 InputMap 액션도 중력 오차 범위에서 기본 속력을 적용해야 한다.")


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
