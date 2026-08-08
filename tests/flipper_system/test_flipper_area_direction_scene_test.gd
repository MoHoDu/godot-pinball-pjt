extends SceneTree


const TEST_SCENE_PATH := \
	"res://scenes/tests/flippers/test_flipper_area_direction.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "구역 속도·각도 테스트 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		_finish()
		return

	var test_scene := packed_scene.instantiate() as Node2D
	root.add_child(test_scene)
	await process_frame

	for method_name: StringName in [
		&"select_test_mode",
		&"select_contact_zone",
		&"toggle_target_flipper",
		&"release_ball_for_hit",
		&"get_test_parry_rules",
	]:
		_expect(test_scene.has_method(method_name), \
			"구역 테스트 씬에 %s 조작 API가 필요하다." % method_name)

	var ball := test_scene.get_node_or_null("PinballBall") as RigidBody2D
	var guide := test_scene.get_node_or_null("TestGuide/Panel/GuideLabel") as Label
	_expect(ball != null, "구역 테스트용 공이 필요하다.")
	_expect(guide != null, "현재 테스트 조건을 표시할 안내 Label이 필요하다.")
	if ball != null:
		_expect(ball.freeze, "테스트 공은 선택 구역에서 Space 입력 전까지 고정되어야 한다.")

	if test_scene.has_method(&"select_test_mode"):
		test_scene.call(&"select_test_mode", 0)
		var baseline_rules := test_scene.call(&"get_test_parry_rules") as Resource
		_expect(baseline_rules != null, "기준 비교용 복제 패링 설정이 필요하다.")
		if baseline_rules != null:
			_expect_float(float(baseline_rules.get(&"zone_d_speed_multiplier")), 1.0, \
				"기준 모드에서는 모든 구역 속도를 1배로 고정해야 한다.")
			_expect(not bool(baseline_rules.get(&"zone_d_angle_correction_enabled")), \
				"기준 모드에서는 각도 보정을 꺼야 한다.")

		test_scene.call(&"select_test_mode", 1)
		var speed_rules := test_scene.call(&"get_test_parry_rules") as Resource
		_expect(speed_rules != null, "속도 테스트용 복제 패링 설정이 필요하다.")
		if speed_rules != null:
			_expect(not bool(speed_rules.get(&"zone_c_angle_correction_enabled")), \
				"속도 모드에서는 각도 보정을 꺼야 한다.")
			_expect(absf(float(speed_rules.get(&"zone_a_speed_multiplier")) \
				- float(speed_rules.get(&"zone_d_speed_multiplier"))) > EPSILON, \
				"속도 모드에서는 A와 D 구역의 속도 배율이 달라야 한다.")

		test_scene.call(&"select_test_mode", 2)
		var angle_rules := test_scene.call(&"get_test_parry_rules") as Resource
		_expect(angle_rules != null, "각도 테스트용 복제 패링 설정이 필요하다.")
		if angle_rules != null:
			_expect(bool(angle_rules.get(&"zone_c_angle_correction_enabled")), \
				"각도 모드에서는 구역 각도 보정을 켜야 한다.")
			_expect_float(float(angle_rules.get(&"zone_c_speed_multiplier")), 1.0, \
				"각도 모드에서는 구역 속도 배율을 1배로 고정해야 한다.")

	if test_scene.has_method(&"select_contact_zone") and ball != null:
		test_scene.call(&"select_contact_zone", PinballFlipper.ContactZone.A)
		var zone_a_position := ball.global_position
		test_scene.call(&"select_contact_zone", PinballFlipper.ContactZone.D)
		_expect(not ball.global_position.is_equal_approx(zone_a_position), \
			"A와 D 구역 선택 시 공의 테스트 위치가 달라야 한다.")
		test_scene.call(&"release_ball_for_hit")
		_expect(not ball.freeze, "Space 동작은 고정된 공을 물리 시뮬레이션에 풀어야 한다.")

	test_scene.queue_free()
	await process_frame
	_finish()


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_area_direction_scene_test")
		quit(0)
		return
	print("FAIL: test_flipper_area_direction_scene_test (%d failures)" % _failures.size())
	quit(1)
