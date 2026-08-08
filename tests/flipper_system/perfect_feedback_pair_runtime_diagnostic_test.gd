extends SceneTree


const BOARD_SCENE_PATH := \
	"res://scenes/tests/flippers/test_flipper_board.tscn"
const TEST_POSITION := Vector2(-736.0, -48.0)


var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "CASE_PAIR_RUNTIME: 실제 사각 보드 씬이 필요하다.")
	if packed_scene == null:
		_finish()
		return

	var board := packed_scene.instantiate() as Node2D
	root.add_child(board)
	await process_frame

	var controller := board.get_node_or_null(
		"FlipperSelector/LeftController"
	) as FlipperController
	var ball := board.get_node_or_null("PinballBall") as Pinball
	_expect(controller != null and controller.flippers.size() == 2, \
		"CASE_PAIR_RUNTIME: 왼쪽 플리퍼 한 쌍이 필요하다.")
	_expect(ball != null, "CASE_PAIR_RUNTIME: 실제 테스트 공이 필요하다.")
	if controller == null or controller.flippers.size() != 2 or ball == null:
		board.queue_free()
		await process_frame
		_finish()
		return

	for flipper: PinballFlipper in controller.flippers:
		flipper.parry_resolved.connect(_on_parry_resolved.bind(flipper))

	ball.freeze = false
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 0.9
	ball.global_position = TEST_POSITION
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.reset_physics_interpolation()

	controller.play_all_flippers()
	for _step in 5:
		await physics_frame
		await process_frame

	print("EVIDENCE CASE_PAIR_RUNTIME count=%d events=%s final_position=%s final_velocity=%s" % [
		_events.size(),
		_events,
		ball.global_position,
		ball.linear_velocity,
	])
	_expect(_events.size() == 1, \
		"CASE_PAIR_RUNTIME: 정지 공 한 점의 기하학적 순차 겹침만으로는 실제 물리 신호 " \
		+ "두 번을 재현하지 않아야 한다. (actual=%d)" % _events.size())

	board.queue_free()
	await process_frame
	_finish()


func _on_parry_resolved(
	_ball: RigidBody2D,
	grade: int,
	contact_point: Vector2,
	_contact_zone: int,
	elapsed_time: float,
	_speed_multiplier: float,
	flipper: PinballFlipper
) -> void:
	_events.append({
		&"frame": Engine.get_physics_frames(),
		&"flipper": flipper.name,
		&"grade": grade,
		&"elapsed_time": elapsed_time,
		&"contact_point": contact_point,
	})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: perfect_feedback_pair_runtime_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_pair_runtime_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
