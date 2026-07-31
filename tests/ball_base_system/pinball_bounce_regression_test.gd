extends SceneTree

const TEST_SCENE_PATH := "res://scenes/test_ball_physics.tscn"
const MAX_PHYSICS_STEPS := 180
const DIRECTION_EPSILON := 1.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "공 물리 테스트 씬을 불러올 수 있어야 한다.")

	if packed_scene == null:
		_finish()
		return

	var test_scene := packed_scene.instantiate()
	root.add_child(test_scene)
	await process_frame

	var ball := test_scene.get_node_or_null("PinballBall") as Pinball
	_expect(ball != null, "테스트 씬에 PinballBall 인스턴스가 있어야 한다.")

	if ball == null:
		test_scene.queue_free()
		await process_frame
		_finish()
		return

	var observed_initial_fall := false
	var observed_upward_bounce := false
	var observed_fall_after_apex := false

	for _physics_step: int in MAX_PHYSICS_STEPS:
		await physics_frame
		var vertical_velocity := ball.linear_velocity.y

		if vertical_velocity > DIRECTION_EPSILON:
			if observed_upward_bounce:
				observed_fall_after_apex = true
				break

			observed_initial_fall = true
		elif observed_initial_fall and vertical_velocity < -DIRECTION_EPSILON:
			observed_upward_bounce = true

	_expect(observed_initial_fall, "공이 중력 방향으로 낙하해야 한다.")
	_expect(observed_upward_bounce, "공이 더미 벽과 충돌한 뒤 위로 튀어야 한다.")
	_expect(observed_fall_after_apex, \
		"위로 튄 공이 정점을 지난 뒤 중력 방향으로 다시 낙하해야 한다.")

	test_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_bounce_regression_test")
		quit(0)
		return

	print("FAIL: pinball_bounce_regression_test (%d failures)" % _failures.size())
	quit(1)
