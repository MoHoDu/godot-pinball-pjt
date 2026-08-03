extends SceneTree


const BOARD_SCENE_PATH := \
	"res://scenes/test_flipper/test_flipper_board.tscn"
const ACTIVE_TIME := 0.1
const PHYSICS_DELTA := 1.0 / 60.0
const PERFECT_WINDOW := 0.042
const BALL_RADIUS := 22.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "CASE_PAIR_GEOMETRY: 실제 사각 보드 씬이 필요하다.")
	if packed_scene == null:
		_finish()
		return

	var board := packed_scene.instantiate() as Node2D
	root.add_child(board)
	await process_frame

	var controller := board.get_node_or_null(
		"FlipperSelector/LeftController"
	) as FlipperController
	_expect(controller != null, "CASE_PAIR_GEOMETRY: 왼쪽 2개 플리퍼 컨트롤러가 필요하다.")
	if controller == null or controller.flippers.size() != 2:
		board.queue_free()
		await process_frame
		_finish()
		return

	var first := controller.flippers[0]
	var second := controller.flippers[1]
	first.set_physics_process(false)
	second.set_physics_process(false)
	var sequential_candidate := _find_sequential_pair_candidate(
		controller,
		first,
		second
	)

	_expect(not sequential_candidate.is_empty(), \
		"CASE_PAIR_GEOMETRY: 실제 좌우 한 쌍이 PERFECT 구간의 서로 다른 물리 프레임에서 " \
		+ "같은 크기 공을 순차 감지할 수 있는 위치가 있어야 한다.")
	if not sequential_candidate.is_empty():
		print("EVIDENCE CASE_PAIR_GEOMETRY position=%s first=%s second=%s" % [
			sequential_candidate.get(&"position"),
			sequential_candidate.get(&"first_hit"),
			sequential_candidate.get(&"second_hit"),
		])

	board.queue_free()
	await process_frame
	_finish()


func _find_sequential_pair_candidate(
	controller: FlipperController,
	first: PinballFlipper,
	second: PinballFlipper
) -> Dictionary:
	for local_y in range(-180, 181, 4):
		for local_x in range(-180, 181, 4):
			var world_position := controller.to_global(Vector2(local_x, local_y))
			var first_hit := _find_first_perfect_hit(first, world_position)
			var second_hit := _find_first_perfect_hit(second, world_position)
			if first_hit.is_empty() or second_hit.is_empty():
				continue
			var first_frame := int(first_hit.get(&"frame"))
			var second_frame := int(second_hit.get(&"frame"))
			if absi(first_frame - second_frame) != 1:
				continue
			return {
				&"position": world_position,
				&"first_hit": first_hit,
				&"second_hit": second_hit,
			}
	return {}


func _find_first_perfect_hit(
	flipper: PinballFlipper,
	ball_position: Vector2
) -> Dictionary:
	var initial_rotation := deg_to_rad(flipper.initial_angle_degrees)
	var maximum_rotation := deg_to_rad(flipper.maximum_angle_degrees)
	var frame_count := int(ceil(ACTIVE_TIME / PHYSICS_DELTA))

	for frame_index in frame_count:
		var previous_time := float(frame_index) * PHYSICS_DELTA
		var target_time := minf(previous_time + PHYSICS_DELTA, ACTIVE_TIME)
		var previous_rotation := lerp_angle(
			initial_rotation,
			maximum_rotation,
			_get_active_eased_progress(previous_time)
		)
		var target_rotation := lerp_angle(
			initial_rotation,
			maximum_rotation,
			_get_active_eased_progress(target_time)
		)
		var hit := flipper.find_rotation_sweep_hit(
			ball_position,
			BALL_RADIUS,
			previous_rotation,
			target_rotation,
			frame_index == 0
		)
		if hit.is_empty():
			continue

		var impact_time := previous_time + PHYSICS_DELTA * clampf(
			float(hit.get(&"progress", 1.0)),
			0.0,
			1.0
		)
		if impact_time <= PERFECT_WINDOW:
			return {
				&"frame": frame_index,
				&"impact_time": impact_time,
				&"point": hit.get(&"point", ball_position),
			}
		return {}
	return {}


## FlipperStateMachine._update_active와 같은 4차 ease-out 진행도를 사용합니다.
func _get_active_eased_progress(elapsed_time: float) -> float:
	var progress := clampf(elapsed_time / ACTIVE_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - progress, 4.0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: perfect_feedback_pair_geometry_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_pair_geometry_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
