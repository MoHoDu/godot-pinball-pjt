extends SceneTree


const BALL_SCENE_PATH := \
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/Prefabs/flippers/variants/normal_flipper_left.tscn"

const WALL_POSITION := Vector2(-626.0001, 413.0)
const WALL_ROTATION := -2.7928207
const WALL_SIZE := Vector2(820.0, 24.0)
const FLIPPER_POSITION := Vector2(-258.99988, 571.0)
const START_WALL_LOCAL := Vector2(-250.0, 54.0)
const ROLL_SPEED := 70.0
const MAX_TEST_FRAMES := 180
const RELEASE_DISTANCE := 150.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var ball_scene := load(BALL_SCENE_PATH) as PackedScene
	var flipper_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "저속 벽면 회귀 테스트에 보통 공 씬이 필요하다.")
	_expect(flipper_scene != null, "저속 벽면 회귀 테스트에 왼쪽 플리퍼 씬이 필요하다.")
	if ball_scene == null or flipper_scene == null:
		_finish()
		return

	var fixture := Node2D.new()
	root.add_child(fixture)
	var wall := _create_wall()
	fixture.add_child(wall)
	var flipper := flipper_scene.instantiate() as PinballFlipper
	flipper.position = FLIPPER_POSITION
	flipper.flipper_length = 360.0
	flipper.initial_angle_degrees = 25.0
	flipper.maximum_angle_degrees = -80.0
	fixture.add_child(flipper)
	var ball := ball_scene.instantiate() as Pinball
	ball.freeze = true
	ball.stats.minimum_speed = 200.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 1.0
	ball.stats.elasticity = 0.5
	ball.global_position = wall.to_global(START_WALL_LOCAL)
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	fixture.add_child(ball)
	await physics_frame

	ball.freeze = false
	ball.linear_velocity = Vector2.LEFT.rotated(WALL_ROTATION) * ROLL_SPEED
	ball.sleeping = false
	var closest_distance := INF
	var final_distance := 0.0
	var maximum_distance_after_contact := 0.0
	var maximum_nearby_speed := 0.0
	var contacted_flipper := false
	for _frame_index: int in MAX_TEST_FRAMES:
		await physics_frame
		var distance := ball.global_position.distance_to(flipper.global_position)
		closest_distance = minf(closest_distance, distance)
		if distance < RELEASE_DISTANCE:
			contacted_flipper = true
		if contacted_flipper:
			maximum_distance_after_contact = maxf(
				maximum_distance_after_contact,
				distance
			)
			if distance < RELEASE_DISTANCE + 50.0:
				maximum_nearby_speed = maxf(
					maximum_nearby_speed,
					ball.linear_velocity.length()
				)
		final_distance = distance
	_expect(contacted_flipper,
		"저속 공이 실제 하단 벽-플리퍼 이음부까지 도달해야 한다.")
	_expect(maximum_distance_after_contact >= RELEASE_DISTANCE,
		"저속 공은 플리퍼 접촉 뒤 이음부에서 안정적으로 분리되어야 한다. " \
		+ "(closest=%.2f, max_after=%.2f, final=%.2f, velocity=%s)" % [
			closest_distance,
			maximum_distance_after_contact,
			final_distance,
			ball.linear_velocity,
		])
	_expect(maximum_nearby_speed < 600.0,
		"저속 분리는 과도한 상시 임펄스로 공을 발사하면 안 된다. " \
		+ "(maximum_nearby_speed=%.2f)" % maximum_nearby_speed)
	var collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D
	var final_contact := flipper.find_body_motion_sweep_hit(
		collision.global_position,
		circle.radius + 4.0,
		Vector2.ZERO,
		flipper.rotation,
		flipper.rotation,
		true
	)
	_expect(final_contact.is_empty(),
		"분리 보정 뒤 공이 플리퍼 표면에 저속으로 다시 붙어 있으면 안 된다. " \
		+ "(contact=%s, position=%s, velocity=%s)" % [
			final_contact,
			ball.global_position,
			ball.linear_velocity,
		])
	print((
		"LOW_SPEED_RELEASE_METRICS closest=%.2f max_after=%.2f "
		+ "final=%.2f max_nearby_speed=%.2f"
	) % [
			closest_distance,
			maximum_distance_after_contact,
			final_distance,
			maximum_nearby_speed,
		])

	fixture.queue_free()
	await process_frame
	_finish()


func _create_wall() -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = WALL_POSITION
	wall.rotation = WALL_ROTATION
	var collision := CollisionShape2D.new()
	collision.position = Vector2(0.0, 12.0)
	var rectangle := RectangleShape2D.new()
	rectangle.size = WALL_SIZE
	collision.shape = rectangle
	wall.add_child(collision)
	return wall


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_low_speed_wall_release_test")
		quit(0)
		return
	print("FAIL: flipper_low_speed_wall_release_test (%d failures)" \
		% _failures.size())
	quit(1)
