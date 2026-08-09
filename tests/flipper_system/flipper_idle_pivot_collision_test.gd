extends SceneTree


const BASE_BALL_SCENE_PATH := "res://Resources/Prefabs/balls/base/base_ball.tscn"
const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/Prefabs/flippers/variants/normal_flipper_left.tscn"
const TEST_FLIPPER_LENGTH := 328.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	var flipper_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "축 충돌 테스트에 기본 공 씬이 필요하다.")
	_expect(flipper_scene != null, "축 충돌 테스트에 플리퍼 씬이 필요하다.")
	if ball_scene == null or flipper_scene == null:
		_finish()
		return

	var flipper := flipper_scene.instantiate() as PinballFlipper
	flipper.flipper_length = TEST_FLIPPER_LENGTH
	root.add_child(flipper)
	var ball := ball_scene.instantiate() as Pinball
	ball.freeze = true
	ball.global_position = Vector2(0.0, -1000.0)
	root.add_child(ball)
	await physics_frame

	_test_pivot_safety_collider(flipper)
	_test_ball_uses_shape_ccd(ball)
	_test_pivot_is_registered_in_physics(flipper)
	await _test_idle_pivot_physical_bounce(flipper, ball)

	ball.queue_free()
	flipper.queue_free()
	await process_frame
	_finish()


func _test_pivot_safety_collider(flipper: PinballFlipper) -> void:
	var pivot_collision := flipper.get_node_or_null(
		"PivotCollisionShape2D"
	) as CollisionShape2D
	_expect(pivot_collision != null, \
		"플리퍼 축에는 별도의 원형 안전 충돌체가 필요하다.")
	_expect(
		pivot_collision != null and pivot_collision.shape is CircleShape2D,
		"플리퍼 축 안전 충돌체는 CircleShape2D여야 한다."
	)
	if pivot_collision != null and pivot_collision.shape is CircleShape2D:
		_expect((pivot_collision.shape as CircleShape2D).radius >= 30.0, \
			"328px 플리퍼의 축 안전 반지름은 최소 30px이어야 한다.")
		_expect(not pivot_collision.disabled, "플리퍼 축 안전 충돌체가 활성화되어야 한다.")
	_expect(flipper.collision_layer != 0, "플리퍼 충돌 레이어가 활성화되어야 한다.")


func _test_ball_uses_shape_ccd(ball: Pinball) -> void:
	_expect(
		ball.continuous_cd == RigidBody2D.CCD_MODE_CAST_SHAPE,
		"공은 스침 충돌의 원형 범위를 유지하도록 Shape CCD를 사용해야 한다."
	)
	_expect((ball.collision_mask & 1) != 0, "공이 플리퍼의 기본 충돌 레이어를 감지해야 한다.")


func _test_pivot_is_registered_in_physics(flipper: PinballFlipper) -> void:
	var query_shape := CircleShape2D.new()
	query_shape.radius = 2.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, flipper.global_position)
	query.collision_mask = flipper.collision_layer
	query.collide_with_bodies = true
	var hits := flipper.get_world_2d().direct_space_state.intersect_shape(query, 8)
	var found_flipper := false
	for hit: Dictionary in hits:
		if hit.get(&"collider") == flipper:
			found_flipper = true
			break
	_expect(found_flipper, "플리퍼 축 안전 충돌체가 PhysicsServer2D에 등록되어야 한다.")


func _test_idle_pivot_physical_bounce(
	flipper: PinballFlipper,
	ball: Pinball
) -> void:
	ball.ball_diameter = 44.0
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.freeze = true
	ball.global_position = flipper.global_position + Vector2(0.0, -150.0)
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = Vector2(0.0, 5000.0)
	ball.sleeping = false

	for _frame in 5:
		await physics_frame

	_expect(ball.global_position.y < flipper.global_position.y + 80.0, \
		"대기 플리퍼 축을 향한 공이 축 아래로 터널링하면 안 된다. " \
		+ "(position=%s)" % ball.global_position)
	_expect(ball.linear_velocity.y < 0.0, \
		"대기 플리퍼 축 충돌은 별도 방향 지시 없이 기본 물리로 반사되어야 한다. " \
		+ "(velocity=%s)" % ball.linear_velocity)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_idle_pivot_collision_test")
		quit(0)
		return
	print("FAIL: flipper_idle_pivot_collision_test (%d failures)" % _failures.size())
	quit(1)
