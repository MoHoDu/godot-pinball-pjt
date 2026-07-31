extends SceneTree


const LEFT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_left.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_right.tscn"
const RULES_SCRIPT_PATH := "res://scripts/flipper_system/flipper_parry_rules.gd"
const RULES_RESOURCE_PATH := "res://settings/flippers/FlipperParryRules.tres"
const OVERLAY_SCRIPT_PATH := \
	"res://scripts/flipper_system/flipper_contact_zone_overlay.gd"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var rules_script := load(RULES_SCRIPT_PATH) as Script
	var default_rules := load(RULES_RESOURCE_PATH) as Resource
	var left_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	var right_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script

	_expect(rules_script != null, "FlipperParryRules 스크립트가 필요하다.")
	_expect(default_rules != null, \
		"settings/flippers/FlipperParryRules.tres 공용 설정이 필요하다.")
	_expect(left_scene != null and right_scene != null, \
		"공용 패링 설정을 검증할 좌우 플리퍼 씬이 필요하다.")
	_expect(overlay_script != null, "접촉 구역 전면 시각화 스크립트가 필요하다.")
	if rules_script == null or default_rules == null \
		or left_scene == null or right_scene == null or overlay_script == null:
		_finish()
		return

	_test_editor_contract(default_rules)
	_test_overlay_draw_order(overlay_script)

	var left_flipper := left_scene.instantiate() as PinballFlipper
	var right_flipper := right_scene.instantiate() as PinballFlipper
	root.add_child(left_flipper)
	root.add_child(right_flipper)
	await process_frame

	_test_default_rules_are_shared(left_flipper, right_flipper, default_rules)
	_test_individual_speed_contract(left_flipper)
	_test_shared_rules_live_update(left_flipper, right_flipper, default_rules)
	_test_zone_angle_correction(
		left_flipper,
		right_flipper,
		rules_script,
		default_rules
	)
	_test_live_rules_application(left_flipper, rules_script)
	_test_null_initialization_fallback(left_flipper, default_rules)
	_test_visualization_segments(left_flipper)

	left_flipper.queue_free()
	right_flipper.queue_free()
	await process_frame
	_finish()


func _test_editor_contract(rules: Resource) -> void:
	var required_properties := [
		&"show_contact_zones_in_editor",
		&"zone_a_end_percent",
		&"zone_b_end_percent",
		&"zone_c_end_percent",
		&"zone_a_speed_multiplier",
		&"zone_b_speed_multiplier",
		&"zone_c_speed_multiplier",
		&"zone_d_speed_multiplier",
		&"zone_a_angle_correction_enabled",
		&"zone_b_angle_correction_enabled",
		&"zone_c_angle_correction_enabled",
		&"zone_d_angle_correction_enabled",
		&"zone_a_angle_correction_degrees",
		&"zone_b_angle_correction_degrees",
		&"zone_c_angle_correction_degrees",
		&"zone_d_angle_correction_degrees",
		&"left_angle_direction_sign",
		&"right_angle_direction_sign",
		&"normal_parry_window_time",
		&"perfect_parry_window_time",
		&"normal_parry_speed_multiplier",
		&"perfect_parry_speed_multiplier",
	]

	for property_name: StringName in required_properties:
		_expect(not _find_property(rules, property_name).is_empty(), \
			"공용 패링 설정의 %s 속성이 Inspector에 표시되어야 한다." % property_name)


func _test_overlay_draw_order(overlay_script: Script) -> void:
	var overlay := overlay_script.new() as Node2D
	_expect(overlay != null, "접촉 구역 시각화 노드를 생성할 수 있어야 한다.")
	if overlay == null:
		return
	_expect(not overlay.z_as_relative, \
		"접촉 구역 시각화는 플리퍼 자식의 상대 Z 순서에 가려지면 안 된다.")
	_expect(overlay.z_index == RenderingServer.CANVAS_ITEM_Z_MAX, \
		"접촉 구역 시각화는 CanvasItem의 최전면 Z 순서를 사용해야 한다.")
	overlay.free()


func _test_default_rules_are_shared(
	left_flipper: PinballFlipper,
	right_flipper: PinballFlipper,
	default_rules: Resource
) -> void:
	_expect(left_flipper.get(&"parry_rules") == default_rules, \
		"왼쪽 플리퍼는 기본 공용 패링 설정을 사용해야 한다.")
	_expect(right_flipper.get(&"parry_rules") == default_rules, \
		"오른쪽 플리퍼는 기본 공용 패링 설정을 사용해야 한다.")


func _test_individual_speed_contract(flipper: PinballFlipper) -> void:
	for property_name: StringName in [
		&"contact_zone_a_speed_multiplier",
		&"contact_zone_b_speed_multiplier",
		&"contact_zone_c_speed_multiplier",
		&"contact_zone_d_speed_multiplier",
	]:
		_expect(not _find_property(flipper, property_name).is_empty(), \
			"개별 플리퍼의 %s 속성이 Inspector에 표시되어야 한다." % property_name)


func _test_shared_rules_live_update(
	left_flipper: PinballFlipper,
	right_flipper: PinballFlipper,
	default_rules: Resource
) -> void:
	var original_multiplier := float(default_rules.get(&"zone_b_speed_multiplier"))
	default_rules.set(&"zone_b_speed_multiplier", 1.37)
	_expect_float(
		float(left_flipper.call(
			&"get_contact_zone_speed_multiplier",
			PinballFlipper.ContactZone.B
		)),
		1.37,
		"공용 .tres 변경은 왼쪽 플리퍼에 즉시 적용되어야 한다."
	)
	_expect_float(
		float(right_flipper.call(
			&"get_contact_zone_speed_multiplier",
			PinballFlipper.ContactZone.B
		)),
		1.37,
		"공용 .tres 변경은 오른쪽 플리퍼에도 즉시 일괄 적용되어야 한다."
	)
	default_rules.set(&"zone_b_speed_multiplier", original_multiplier)


func _test_zone_angle_correction(
	left_flipper: PinballFlipper,
	right_flipper: PinballFlipper,
	rules_script: Script,
	default_rules: Resource
) -> void:
	var rules := rules_script.new() as Resource
	rules.set(&"zone_c_angle_correction_enabled", true)
	rules.set(&"zone_c_angle_correction_degrees", 12.0)
	rules.set(&"left_angle_direction_sign", -1.0)
	rules.set(&"right_angle_direction_sign", 1.0)
	left_flipper.call(&"set_parry_rules", rules)
	right_flipper.call(&"set_parry_rules", rules)

	var reflected_velocity := Vector2(300.0, -400.0)
	var left_result: Vector2 = left_flipper.call(
		&"apply_contact_zone_angle_correction",
		reflected_velocity,
		PinballFlipper.ContactZone.C
	)
	var right_result: Vector2 = right_flipper.call(
		&"apply_contact_zone_angle_correction",
		reflected_velocity,
		PinballFlipper.ContactZone.C
	)
	_expect_vector(
		left_result,
		reflected_velocity.rotated(deg_to_rad(-12.0)),
		"왼쪽 플리퍼는 공용 왼쪽 부호로 C 구역 각도를 보정해야 한다."
	)
	_expect_vector(
		right_result,
		reflected_velocity.rotated(deg_to_rad(12.0)),
		"오른쪽 플리퍼는 공용 오른쪽 부호로 C 구역 각도를 보정해야 한다."
	)
	_expect_float(left_result.length(), reflected_velocity.length(), \
		"각도 보정은 물리 반사 결과의 속력을 변경하면 안 된다.")

	rules.set(&"zone_c_angle_correction_enabled", false)
	_expect_vector(
		left_flipper.call(
			&"apply_contact_zone_angle_correction",
			reflected_velocity,
			PinballFlipper.ContactZone.C
		) as Vector2,
		reflected_velocity,
		"각도 보정을 끈 구역은 물리 반사 방향을 변경하면 안 된다."
	)

	left_flipper.call(&"set_parry_rules", default_rules)
	right_flipper.call(&"set_parry_rules", default_rules)


func _test_live_rules_application(flipper: PinballFlipper, rules_script: Script) -> void:
	var rules := rules_script.new() as Resource
	rules.set(&"zone_a_end_percent", 20.0)
	rules.set(&"zone_b_end_percent", 60.0)
	rules.set(&"zone_c_end_percent", 85.0)
	rules.set(&"zone_c_speed_multiplier", 0.8)
	rules.set(&"show_contact_zones_in_editor", true)
	flipper.call(&"set_parry_rules", rules)

	_expect(int(flipper.call(&"get_contact_zone", 19.99)) == PinballFlipper.ContactZone.A, \
		"변경된 공용 A 구역 경계가 즉시 적용되어야 한다.")
	_expect(int(flipper.call(&"get_contact_zone", 20.0)) == PinballFlipper.ContactZone.B, \
		"변경된 공용 B 구역 시작점이 즉시 적용되어야 한다.")
	_expect(int(flipper.call(&"get_contact_zone", 60.0)) == PinballFlipper.ContactZone.C, \
		"변경된 공용 C 구역 시작점이 즉시 적용되어야 한다.")
	_expect(int(flipper.call(&"get_contact_zone", 85.0)) == PinballFlipper.ContactZone.D, \
		"변경된 공용 D 구역 시작점이 즉시 적용되어야 한다.")

	flipper.set(&"contact_zone_c_speed_multiplier", 1.5)
	_expect_float(
		float(flipper.call(
			&"get_contact_zone_speed_multiplier",
			PinballFlipper.ContactZone.C
		)),
		1.2,
		"공용 구역 속도와 개별 플리퍼 보정값을 곱해 적용해야 한다."
	)
	rules.set(&"zone_c_speed_multiplier", 1.2)
	_expect_float(
		float(flipper.call(
			&"get_contact_zone_speed_multiplier",
			PinballFlipper.ContactZone.C
		)),
		1.8,
		"실행 중 공용 .tres 변경도 별도 재할당 없이 즉시 적용되어야 한다."
	)
	_expect(bool(flipper.call(&"is_contact_zone_visualization_enabled")), \
		"공용 시각화 설정이 개별 플리퍼에 즉시 전달되어야 한다.")


func _test_null_initialization_fallback(
	flipper: PinballFlipper,
	default_rules: Resource
) -> void:
	flipper.set(&"_parry_rules", null)
	_expect(flipper.get(&"parry_rules") == default_rules, \
		"에디터 초기화 중 내부 값이 비어도 기본 패링 설정을 반환해야 한다.")
	_expect(bool(flipper.call(&"is_contact_zone_visualization_enabled")), \
		"에디터가 먼저 그리기를 요청해도 null 설정 오류가 발생하면 안 된다.")
	_expect(int(flipper.call(&"get_contact_zone", 50.0)) == PinballFlipper.ContactZone.B, \
		"초기화 중에도 기본 접촉 구역 판정을 사용할 수 있어야 한다.")
	flipper.call(&"set_parry_rules", default_rules)


func _test_visualization_segments(flipper: PinballFlipper) -> void:
	var segments := flipper.call(&"get_contact_zone_visualization_segments") as Array
	_expect(segments.size() == 4, \
		"에디터 전면 오버레이는 A/B/C/D 네 구역 선분을 받아야 한다.")


func _find_property(object: Object, property_name: StringName) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return property
	return {}


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_parry_rules_test")
		quit(0)
		return
	print("FAIL: flipper_parry_rules_test (%d failures)" % _failures.size())
	quit(1)
