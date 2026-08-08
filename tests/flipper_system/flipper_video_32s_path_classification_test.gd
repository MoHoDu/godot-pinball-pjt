extends SceneTree


const BOARD_SCENE_PATH := "res://scenes/tests/flippers/test_flipper_board.tscn"
const VIDEO_FLIPPER_PATH := \
	"FlipperSelector/RightController/LeftFlipper"
const RIGHT_BOTTOM_WALL_PATH := "Walls/RightBottomWall"
# 32~33초 화면의 공 중심을 Camera2D zoom(0.56)으로 역산한 근삿값입니다.
const VIDEO_START_POSITION := Vector2(740.0, 243.0)
const VIDEO_START_VELOCITY := Vector2(466.5, 281.8)
const MAX_TEST_FRAMES := 24
const CONTACT_TOLERANCE := 10.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var board_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(board_scene != null, "32초 영상 경로 분류에 실제 사각 보드 씬이 필요하다.")
	if board_scene == null:
		_finish()
		return

	var board := board_scene.instantiate()
	root.add_child(board)
	await physics_frame

	var flipper := board.get_node_or_null(VIDEO_FLIPPER_PATH) as PinballFlipper
	var wall := board.get_node_or_null(RIGHT_BOTTOM_WALL_PATH) as StaticBody2D
	var ball := board.get_node_or_null("PinballBall") as Pinball
	_expect(flipper != null, "영상에서 공과 가까워 보이는 우측 세로 플리퍼가 필요하다.")
	_expect(wall != null, "영상 경로 끝의 우측 아래 벽이 필요하다.")
	_expect(ball != null, "영상과 같은 실제 Pinball 공이 필요하다.")
	if flipper == null or wall == null or ball == null:
		board.queue_free()
		await process_frame
		_finish()
		return

	_configure_video_ball(ball)
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = VIDEO_START_VELOCITY
	ball.sleeping = false

	var polygon: PackedVector2Array = flipper.call(
		&"_get_world_collision_polygon",
		flipper.rotation
	)
	var ball_radius := _get_ball_radius(ball)
	var minimum_flipper_clearance := INF
	var minimum_pivot_clearance := INF
	var minimum_wall_clearance := INF
	var reflected_from_right := false
	for _frame_index in MAX_TEST_FRAMES:
		await physics_frame
		minimum_flipper_clearance = minf(
			minimum_flipper_clearance,
			_get_circle_polygon_clearance(
				ball.global_position,
				ball_radius,
				polygon,
				flipper
			)
		)
		minimum_pivot_clearance = minf(
			minimum_pivot_clearance,
			_get_pivot_clearance(ball.global_position, ball_radius, flipper)
		)
		minimum_wall_clearance = minf(
			minimum_wall_clearance,
			_get_right_wall_clearance(ball.global_position, ball_radius, wall)
		)
		if ball.linear_velocity.x < 0.0:
			reflected_from_right = true

	print(
		(
			"VIDEO32_PATH: reflected=%s body_clearance=%.2f " \
			+ "pivot_clearance=%.2f " \
			+ "wall_clearance=%.2f"
		) % [
			reflected_from_right,
			minimum_flipper_clearance,
			minimum_pivot_clearance,
			minimum_wall_clearance,
		]
	)
	_expect(minimum_flipper_clearance > 0.0, \
		"32초 영상 경로의 공은 우측 세로 플리퍼 충돌 폴리곤과 겹치지 않아야 한다.")
	_expect(minimum_pivot_clearance > 0.0, \
		"32초 영상 경로의 공은 우측 세로 플리퍼 피벗과도 겹치지 않아야 한다.")
	_expect(minimum_wall_clearance <= CONTACT_TOLERANCE, \
		"32초 영상 경로의 방향 전환은 우측 아래 벽 접촉으로 분류되어야 한다.")
	_expect(reflected_from_right, \
		"32초 영상 경로의 공은 우측 벽 접촉 뒤 보드 안쪽으로 반사되어야 한다.")

	board.queue_free()
	await process_frame
	_finish()


func _get_circle_polygon_clearance(
	circle_center: Vector2,
	circle_radius: float,
	polygon: PackedVector2Array,
	flipper: PinballFlipper
) -> float:
	var contact: Dictionary = flipper.call(
		&"_get_circle_polygon_contact",
		circle_center,
		polygon
	)
	if contact.is_empty():
		return INF
	var contact_point: Vector2 = contact[&"point"]
	var distance := circle_center.distance_to(contact_point)
	if Geometry2D.is_point_in_polygon(circle_center, polygon):
		return -(circle_radius + distance)
	return distance - circle_radius


func _get_right_wall_clearance(
	circle_center: Vector2,
	circle_radius: float,
	wall: StaticBody2D
) -> float:
	var collision := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return INF
	var rectangle := collision.shape as RectangleShape2D
	var left_surface_x := collision.global_position.x \
		- rectangle.size.x * collision.global_scale.abs().x * 0.5
	return left_surface_x - (circle_center.x + circle_radius)


func _get_pivot_clearance(
	circle_center: Vector2,
	circle_radius: float,
	flipper: PinballFlipper
) -> float:
	var pivot := flipper.get_node_or_null(
		"PivotCollisionShape2D"
	) as CollisionShape2D
	if pivot == null or not pivot.shape is CircleShape2D:
		return INF
	var pivot_circle := pivot.shape as CircleShape2D
	var pivot_scale := pivot.global_scale.abs()
	var pivot_radius := pivot_circle.radius * maxf(
		pivot_scale.x,
		pivot_scale.y
	)
	return circle_center.distance_to(pivot.global_position) \
		- circle_radius - pivot_radius


func _get_ball_radius(ball: Pinball) -> float:
	var collision := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is CircleShape2D:
		return 0.0
	var circle := collision.shape as CircleShape2D
	var collision_scale := collision.global_scale.abs()
	return circle.radius * maxf(collision_scale.x, collision_scale.y)


func _configure_video_ball(ball: Pinball) -> void:
	ball.freeze = true
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 1540.0
	ball.stats.gravity_scale = 0.35
	ball.stats.elasticity = 0.9
	ball.global_position = VIDEO_START_POSITION
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
		print("PASS: flipper_video_32s_path_classification_test")
		quit(0)
		return
	print("FAIL: flipper_video_32s_path_classification_test (%d failures)" \
		% _failures.size())
	quit(1)
