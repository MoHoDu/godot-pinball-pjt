extends SceneTree


const BOARD_SCENE_PATH := \
	"res://scenes/tests/flippers/test_flipper_board.tscn"
const CONTACT_CANDIDATE := Vector2(-736.0, -48.0)
const PHYSICS_DELTA := 1.0 / 60.0
const ACTIVE_TIME := 0.1
const LAST_PERFECT_STEP := 2
const GUARD_META: StringName = &"_flipper_last_resolved_physics_frame"


var _failures: Array[String] = []
var _trial_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "CASE_PAIR_MOTION: 실제 사각 보드 씬이 필요하다.")
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
		"CASE_PAIR_MOTION: 왼쪽 플리퍼 한 쌍이 필요하다.")
	_expect(ball != null, "CASE_PAIR_MOTION: 실제 테스트 공이 필요하다.")
	if controller == null or controller.flippers.size() != 2 or ball == null:
		board.queue_free()
		await process_frame
		_finish()
		return

	for node: Node in board.find_children("*", "PinballFlipper", true, false):
		(node as PinballFlipper).set_physics_process(false)
	for flipper: PinballFlipper in controller.flippers:
		flipper.parry_resolved.connect(_on_parry_resolved.bind(flipper))

	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 0.9
	var reproduced: Dictionary = {}
	for velocity_x in [-1600.0, -1200.0, -800.0]:
		for velocity_y in [-400.0, 0.0, 400.0]:
			var velocity := Vector2(float(velocity_x), float(velocity_y))
			for expected_contact_time in [0.025, 1.0 / 30.0, 0.041]:
				var contact_time := float(expected_contact_time)
				var start_position: Vector2 = CONTACT_CANDIDATE \
					- velocity * contact_time
				var events := await _run_manual_activation_trial(
					controller.flippers,
					ball,
					start_position,
					velocity
				)
				if events.size() < 2:
					continue
				reproduced = {
					&"start_position": start_position,
					&"start_velocity": velocity,
					&"events": events,
				}
				break
			if not reproduced.is_empty():
				break
		if not reproduced.is_empty():
			break

	print("EVIDENCE CASE_PAIR_MOTION reproduced=%s" % reproduced)
	_expect(reproduced.is_empty(), \
		"CASE_PAIR_MOTION: 제한된 27개 입사 조건에서는 실제 임펄스 뒤 두 번째 " \
		+ "패링 신호까지 재현되지 않아야 현재 반례 기록과 일치한다.")
	if not reproduced.is_empty():
		var events: Array = reproduced.get(&"events")
		_expect(int(events[0].get(&"frame")) != int(events[1].get(&"frame")), \
			"CASE_PAIR_MOTION: 재현된 두 신호는 같은 프레임이면 안 된다.")

	board.queue_free()
	await process_frame
	_finish()


func _run_manual_activation_trial(
	flippers: Array[PinballFlipper],
	ball: Pinball,
	start_position: Vector2,
	start_velocity: Vector2
) -> Array[Dictionary]:
	_trial_events.clear()
	ball.freeze = true
	ball.global_position = start_position
	ball.linear_velocity = start_velocity
	ball.angular_velocity = 0.0
	ball.remove_meta(GUARD_META)
	if ball.has_method(&"clear_temporary_maximum_speed"):
		ball.call(&"clear_temporary_maximum_speed")
	for flipper: PinballFlipper in flippers:
		flipper.rotation = deg_to_rad(flipper.initial_angle_degrees)
	ball.freeze = false
	ball.sleeping = false
	ball.reset_physics_interpolation()

	for frame_index in range(LAST_PERFECT_STEP + 1):
		var previous_time := float(frame_index) * PHYSICS_DELTA
		var target_time := previous_time + PHYSICS_DELTA
		for flipper: PinballFlipper in flippers:
			var previous_rotation := lerp_angle(
				deg_to_rad(flipper.initial_angle_degrees),
				deg_to_rad(flipper.maximum_angle_degrees),
				_get_active_eased_progress(previous_time)
			)
			var target_rotation := lerp_angle(
				deg_to_rad(flipper.initial_angle_degrees),
				deg_to_rad(flipper.maximum_angle_degrees),
				_get_active_eased_progress(target_time)
			)
			flipper.resolve_rotation_sweep(
				previous_rotation,
				target_rotation,
				PHYSICS_DELTA,
				previous_time
			)
			flipper.rotation = target_rotation
		await physics_frame
		await process_frame

	ball.freeze = true
	return _trial_events.duplicate(true)


func _get_active_eased_progress(elapsed_time: float) -> float:
	var progress := clampf(elapsed_time / ACTIVE_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - progress, 4.0)


func _on_parry_resolved(
	_ball: RigidBody2D,
	grade: int,
	contact_point: Vector2,
	_contact_zone: int,
	elapsed_time: float,
	_speed_multiplier: float,
	flipper: PinballFlipper
) -> void:
	_trial_events.append({
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
		print("PASS: perfect_feedback_pair_motion_scan_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_pair_motion_scan_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
