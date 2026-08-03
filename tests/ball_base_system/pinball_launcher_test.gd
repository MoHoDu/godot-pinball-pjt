extends SceneTree


const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const LAUNCHER_SCRIPT := preload(
	"res://scripts/ball_base_system/pinball_launcher.gd"
)
const LAUNCH_RULES_PATH := "res://settings/balls/PinballLaunchRules.tres"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_input_actions()
	_test_common_launch_rules()

	var test_root := Node2D.new()
	root.add_child(test_root)

	var launcher := LAUNCHER_SCRIPT.new() as PinballLauncher
	launcher.position = Vector2(240.0, 360.0)
	launcher.rotation = -PI * 0.5
	launcher.default_launch_speed = 940.0
	launcher.minimum_launch_speed = 320.0
	launcher.maximum_launch_speed = 1540.0
	launcher.minimum_launch_angle_degrees = -30.0
	launcher.maximum_launch_angle_degrees = 30.0
	launcher.launch_rules = launcher.launch_rules.duplicate() as PinballLaunchRules
	launcher.launch_rules.angle_adjustment_speed = 90.0
	launcher.launch_rules.power_adjustment_speed = 600.0
	test_root.add_child(launcher)

	var packed_ball := load(BALL_SCENE_PATH) as PackedScene
	_expect(packed_ball != null, "런처 테스트에 기본 공 씬이 필요하다.")
	if packed_ball == null:
		test_root.queue_free()
		await process_frame
		_finish()
		return

	var ball := packed_ball.instantiate() as Pinball
	_expect(ball != null, "기본 공 씬의 루트는 Pinball이어야 한다.")
	if ball == null:
		test_root.queue_free()
		await process_frame
		_finish()
		return

	test_root.add_child(ball)
	await process_frame

	_test_prepare_contract(launcher, ball)
	_test_held_aim_and_power_input(launcher)
	_test_effective_speed_range(launcher, ball)
	_test_single_launch(launcher, ball)
	_test_scene_spawning(launcher, packed_ball, test_root)
	_test_confirm_input_action(launcher)
	_test_invalid_scene_rejection(launcher, test_root)

	_release_launch_actions()
	test_root.queue_free()
	await process_frame
	_finish()


func _test_input_actions() -> void:
	var expected_keys := {
		&"ball_launch_aim_left": [KEY_LEFT, KEY_A],
		&"ball_launch_aim_right": [KEY_RIGHT, KEY_D],
		&"ball_launch_power_up": [KEY_UP, KEY_W],
		&"ball_launch_power_down": [KEY_DOWN, KEY_S],
		&"ball_launch_confirm": [KEY_ENTER, KEY_KP_ENTER],
	}

	for action: StringName in expected_keys:
		_expect(InputMap.has_action(action), \
			"%s InputMap 액션이 필요하다." % action)
		for key: Key in expected_keys[action]:
			_expect(_action_has_physical_key(action, key), \
				"%s 액션에 %s 기본 키가 필요하다." % [action, key])


func _test_common_launch_rules() -> void:
	var rules := load(LAUNCH_RULES_PATH) as PinballLaunchRules
	_expect(rules != null, "공통 공 발사 조작 규칙 .tres가 필요하다.")
	if rules == null:
		return
	_expect(rules.angle_adjustment_speed > 0.0, \
		"공통 각도 변경 속도는 0보다 커야 한다.")
	_expect(rules.power_adjustment_speed > 0.0, \
		"공통 파워 변경 속도는 0보다 커야 한다.")


func _test_prepare_contract(launcher: PinballLauncher, ball: Pinball) -> void:
	ball.global_position = Vector2(999.0, 999.0)
	ball.linear_velocity = Vector2(123.0, 456.0)
	var prepared := launcher.prepare_ball(ball)

	_expect(prepared == ball, "기존 공을 런처에 준비할 수 있어야 한다.")
	_expect(launcher.is_aiming, "공을 준비하면 조준 상태가 시작되어야 한다.")
	_expect(ball.freeze, "준비된 공은 발사 전까지 고정되어야 한다.")
	_expect(ball.global_position.is_equal_approx(launcher.global_position), \
		"준비된 공은 보드 씬의 런처 위치로 이동해야 한다.")
	_expect(ball.linear_velocity.is_zero_approx(), \
		"공을 준비할 때 기존 선속도를 제거해야 한다.")
	_expect(is_equal_approx(launcher.current_angle_degrees, 0.0), \
		"조준은 보드 런처의 중앙 각도에서 시작해야 한다.")
	_expect_float(launcher.current_launch_speed, 940.0, \
		"사각 보드는 940px/s를 기본 발사 속력으로 사용해야 한다.")


func _test_held_aim_and_power_input(launcher: PinballLauncher) -> void:
	Input.action_press(&"ball_launch_aim_right")
	launcher._process(1.0)
	Input.action_release(&"ball_launch_aim_right")
	_expect_float(launcher.current_angle_degrees, 30.0, \
		"오른쪽 입력을 유지하면 보드의 최대 각도까지만 증가해야 한다.")

	Input.action_press(&"ball_launch_aim_left")
	launcher._process(1.0)
	Input.action_release(&"ball_launch_aim_left")
	_expect_float(launcher.current_angle_degrees, -30.0, \
		"왼쪽 입력을 유지하면 보드의 최소 각도까지만 감소해야 한다.")

	launcher.set_current_angle(0.0)
	Input.action_press(&"ball_launch_aim_left")
	Input.action_press(&"ball_launch_aim_right")
	launcher._process(1.0)
	Input.action_release(&"ball_launch_aim_left")
	Input.action_release(&"ball_launch_aim_right")
	_expect_float(launcher.current_angle_degrees, 0.0, \
		"좌우 입력을 동시에 유지하면 조준 각도가 변하지 않아야 한다.")

	Input.action_press(&"ball_launch_power_up")
	launcher._process(2.0)
	Input.action_release(&"ball_launch_power_up")
	_expect_float(launcher.current_launch_speed, 1540.0, \
		"위 입력을 유지하면 보드의 최대 속력까지만 증가해야 한다.")

	Input.action_press(&"ball_launch_power_down")
	launcher._process(3.0)
	Input.action_release(&"ball_launch_power_down")
	_expect_float(launcher.current_launch_speed, 320.0, \
		"아래 입력을 유지하면 보드의 최소 속력까지만 감소해야 한다.")


func _test_effective_speed_range(
	launcher: PinballLauncher,
	ball: Pinball
) -> void:
	ball.stats.minimum_speed = 500.0
	ball.stats.maximum_speed = 1000.0
	launcher.prepare_ball(ball)
	var effective_range := launcher.get_effective_speed_range()
	_expect_vector(effective_range, Vector2(500.0, 1000.0), \
		"플레이어 선택 범위는 보드와 공 물리 규칙의 교집합이어야 한다.")
	launcher.set_current_launch_speed(5000.0)
	_expect_float(launcher.current_launch_speed, 1000.0, \
		"보드 설정이 공 자체 최대 속력을 우회하면 안 된다.")

	ball.stats.minimum_speed = 320.0
	ball.stats.maximum_speed = 1540.0
	launcher.prepare_ball(ball)


func _test_single_launch(launcher: PinballLauncher, ball: Pinball) -> void:
	var launch_count := [0]
	launcher.ball_launched.connect(func(
		_launched_ball: Pinball,
		_direction: Vector2,
		_speed: float
	) -> void:
		launch_count[0] += 1
	)

	launcher.set_current_angle(30.0)
	launcher.set_current_launch_speed(1200.0)
	var expected_direction := Vector2.RIGHT.rotated(-PI / 3.0)
	var launched := launcher.launch_prepared_ball()

	_expect(launched, "준비된 공을 선택한 각도와 속력으로 발사할 수 있어야 한다.")
	_expect(not launcher.is_aiming, "발사 후에는 조준 입력을 종료해야 한다.")
	_expect(not ball.freeze, "발사한 공은 물리 고정이 해제되어야 한다.")
	_expect_float(ball.linear_velocity.length(), 1200.0, \
		"선택한 발사 파워가 공 속력에 적용되어야 한다.")
	_expect_vector(ball.linear_velocity.normalized(), expected_direction, \
		"발사대 회전과 상대 조준 각도가 월드 발사 방향에 적용되어야 한다.")
	_expect(launch_count[0] == 1, "성공한 발사는 ball_launched를 한 번 보내야 한다.")
	_expect(not launcher.launch_prepared_ball(), \
		"하나의 준비 상태에서 공을 중복 발사할 수 없어야 한다.")
	_expect(launch_count[0] == 1, "중복 발사 요청은 성공 신호를 추가로 보내면 안 된다.")


func _test_scene_spawning(
	launcher: PinballLauncher,
	packed_ball: PackedScene,
	test_root: Node
) -> void:
	launcher.ball_scene = packed_ball
	var child_count_before := test_root.get_child_count()
	var spawned_ball := launcher.prepare_ball()
	_expect(spawned_ball != null, "설정한 PackedScene에서 공을 생성할 수 있어야 한다.")
	if spawned_ball == null:
		return
	_expect(spawned_ball.get_parent() == test_root, \
		"생성한 공은 설정된 스폰 부모에 추가되어야 한다.")
	_expect(test_root.get_child_count() == child_count_before + 1, \
		"공 준비 한 번당 새 인스턴스 하나만 생성되어야 한다.")
	_expect(spawned_ball.global_position.is_equal_approx(launcher.global_position), \
		"생성한 공도 런처의 보드별 위치에 배치되어야 한다.")


func _test_confirm_input_action(launcher: PinballLauncher) -> void:
	var event := InputEventAction.new()
	event.action = &"ball_launch_confirm"
	event.pressed = true
	launcher._input(event)
	_expect(not launcher.is_aiming, \
		"발사 확정 InputMap 액션이 준비된 공을 발사해야 한다.")


func _test_invalid_scene_rejection(
	launcher: PinballLauncher,
	test_root: Node
) -> void:
	var invalid_scene := PackedScene.new()
	var invalid_root := Node2D.new()
	var pack_error := invalid_scene.pack(invalid_root)
	invalid_root.free()
	_expect(pack_error == OK, "잘못된 루트 타입 테스트 씬을 준비할 수 있어야 한다.")
	if pack_error != OK:
		return

	launcher.ball_scene = invalid_scene
	var child_count_before := test_root.get_child_count()
	var spawned_ball := launcher.spawn_ball()
	_expect(spawned_ball == null, "Pinball이 아닌 씬 루트는 생성 요청을 거부해야 한다.")
	_expect(test_root.get_child_count() == child_count_before, \
		"거부한 공 씬 인스턴스를 트리에 남기면 안 된다.")


func _action_has_physical_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false


func _release_launch_actions() -> void:
	for action: StringName in [
		&"ball_launch_aim_left",
		&"ball_launch_aim_right",
		&"ball_launch_power_up",
		&"ball_launch_power_down",
		&"ball_launch_confirm",
	]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%.3f, actual=%.3f)" % [message, expected, actual])


func _expect_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_launcher_test")
		quit(0)
		return
	print("FAIL: pinball_launcher_test (%d failures)" % _failures.size())
	quit(1)
