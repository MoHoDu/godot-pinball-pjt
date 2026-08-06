extends SceneTree

const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_left.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_right.tscn"
const RULES_SCRIPT_PATH := "res://scripts/flipper_system/flipper_state_rules.gd"
const RULES_RESOURCE_PATH := "res://settings/flippers/FlipperStateRules.tres"
const EPSILON := 0.001

const STATE_IDLE := 0
const STATE_ACTIVE := 1
const STATE_HOLD := 2
const STATE_RETURNING := 3
const STATE_COOLDOWN := 4

var _failures: Array[String] = []
var _observed_states: Array[int] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var left_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	var right_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	var rules_script := load(RULES_SCRIPT_PATH) as Script
	var default_rules := load(RULES_RESOURCE_PATH) as Resource

	_expect(left_scene != null, "왼쪽 플리퍼 씬을 불러올 수 있어야 한다.")
	_expect(right_scene != null, "오른쪽 플리퍼 씬을 불러올 수 있어야 한다.")
	_test_rules_contract(rules_script, default_rules)

	if left_scene == null or right_scene == null:
		_finish()
		return

	var flipper := left_scene.instantiate() as PinballFlipper
	var second_flipper := right_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	root.add_child(second_flipper)
	await process_frame

	_test_individual_editor_contract(flipper)
	_test_default_rules_are_shared(flipper, second_flipper, default_rules)
	await _test_state_sequence(flipper, rules_script)

	flipper.queue_free()
	second_flipper.queue_free()
	await process_frame
	_finish()


func _test_rules_contract(rules_script: Script, default_rules: Resource) -> void:
	_expect(rules_script != null, "FlipperStateRules 스크립트가 필요하다.")
	_expect(default_rules != null, \
		"settings/flippers/FlipperStateRules.tres 공용 설정이 필요하다.")

	if rules_script == null or default_rules == null:
		return

	var required_properties := [
		&"return_reflection_multiplier",
		&"minimum_active_hit_speed",
		&"activation_time",
		&"hold_time",
		&"return_time",
	]

	for property_name: StringName in required_properties:
		var property := _find_property(default_rules, property_name)
		_expect(not property.is_empty(), \
			"공용 플리퍼 설정의 %s 속성이 Inspector에 표시되어야 한다." % property_name)

	_expect_float(float(default_rules.get(&"return_reflection_multiplier")), 0.5, \
		"기본 복귀 반사 배율은 0.5여야 한다.")
	_expect_float(float(default_rules.get(&"minimum_active_hit_speed")), 320.0, \
		"능동 타격은 최소 출사 속력 320px/s를 사용해야 한다.")


func _test_individual_editor_contract(flipper: PinballFlipper) -> void:
	var expected_properties := [
		&"contact_zone_a_speed_multiplier",
		&"contact_zone_b_speed_multiplier",
		&"contact_zone_c_speed_multiplier",
		&"contact_zone_d_speed_multiplier",
		&"cooldown_time",
		&"initial_angle_degrees",
		&"maximum_angle_degrees",
	]

	for property_name: StringName in expected_properties:
		var property := _find_property(flipper, property_name)
		_expect(not property.is_empty(), \
			"개별 플리퍼의 %s 속성이 Inspector에 표시되어야 한다." % property_name)

	var rules_property := _find_property(flipper, &"state_rules")
	var rules_usage := int(rules_property.get("usage", 0))
	_expect((rules_usage & PROPERTY_USAGE_EDITOR) == 0, \
		"공용 State Rules는 개별 플리퍼 Inspector에서 교체할 수 없어야 한다.")


func _test_default_rules_are_shared(
	first_flipper: PinballFlipper,
	second_flipper: PinballFlipper,
	default_rules: Resource
) -> void:
	if default_rules == null:
		return

	_expect(first_flipper.get(&"state_rules") == default_rules, \
		"기본 플리퍼는 settings의 공용 State Rules를 사용해야 한다.")
	_expect(first_flipper.get(&"state_rules") == second_flipper.get(&"state_rules"), \
		"모든 기본 플리퍼는 같은 State Rules 리소스를 공유해야 한다.")


func _test_state_sequence(flipper: PinballFlipper, rules_script: Script) -> void:
	if rules_script == null:
		return

	var rules := rules_script.new() as Resource
	rules.set(&"return_reflection_multiplier", 0.5)
	rules.set(&"activation_time", 0.05)
	rules.set(&"hold_time", 0.05)
	rules.set(&"return_time", 0.05)

	flipper.set(&"contact_zone_c_speed_multiplier", 1.4)
	flipper.set(&"cooldown_time", 0.05)
	flipper.set(&"initial_angle_degrees", 0.0)
	flipper.set(&"maximum_angle_degrees", 60.0)
	flipper.call(&"set_state_rules", rules)

	_expect_float(float(flipper.get(&"contact_zone_c_speed_multiplier")), 1.4, \
		"접촉 구역별 속도 배율은 개별 플리퍼에 보관되어야 한다.")
	_observed_states.clear()
	flipper.state_changed.connect(_on_flipper_state_changed)
	flipper.call(&"set_selected_visual", true)
	_expect(_is_outline_enabled(flipper), \
		"선택된 플리퍼는 대기 상태에서 강조 표시되어야 한다.")

	var activated := bool(flipper.call(&"request_activation"))
	_expect(activated, "대기 상태의 플리퍼는 작동 요청을 받아야 한다.")
	_expect(int(flipper.call(&"get_current_state_type")) == STATE_ACTIVE, \
		"작동 요청 직후 ACTIVE 상태여야 한다.")
	_expect(bool(flipper.call(&"is_parry_window")), \
		"ACTIVE 상태에서는 패링 가능 상태를 알려야 한다.")
	_expect(not _is_outline_enabled(flipper), \
		"작동 중에는 대기 상태 선택 강조를 숨겨야 한다.")

	var checked_hold_rotation := false
	var checked_return_impact := false
	var checked_cooldown_rejection := false

	for _physics_step: int in 90:
		await physics_frame
		var state_type := int(flipper.call(&"get_current_state_type"))

		if state_type == STATE_HOLD and not checked_hold_rotation:
			_expect_float(rad_to_deg(flipper.rotation), 60.0, \
				"HOLD 상태에서는 최대 각도를 유지해야 한다.")
			checked_hold_rotation = true

		if state_type == STATE_RETURNING and not checked_return_impact:
			var impact := flipper.call(&"get_ball_impact", null) as BallImpactResult
			_expect(impact != null, \
				"RETURNING 상태 충돌은 반사 배율 결과를 제공해야 한다.")
			if impact != null:
				_expect_float(impact.speed_multiplier, 0.5, \
					"RETURNING 상태에는 공용 복귀 반사 배율을 적용해야 한다.")
			checked_return_impact = true

		if state_type == STATE_COOLDOWN and not checked_cooldown_rejection:
			_expect(not bool(flipper.call(&"request_activation")), \
				"COOLDOWN 상태에서는 작동 요청을 거부해야 한다.")
			checked_cooldown_rejection = true

		if state_type == STATE_IDLE and _observed_states.has(STATE_COOLDOWN):
			break

	_expect(_observed_states == [
		STATE_ACTIVE,
		STATE_HOLD,
		STATE_RETURNING,
		STATE_COOLDOWN,
		STATE_IDLE,
	], "플리퍼 상태가 ACTIVE→HOLD→RETURNING→COOLDOWN→IDLE 순서로 전이되어야 한다.")
	_expect(checked_hold_rotation, "HOLD 상태를 관찰할 수 있어야 한다.")
	_expect(checked_return_impact, "RETURNING 상태를 관찰할 수 있어야 한다.")
	_expect(checked_cooldown_rejection, "COOLDOWN 상태를 관찰할 수 있어야 한다.")
	_expect_float(rad_to_deg(flipper.rotation), 0.0, \
		"IDLE 복귀 후에는 개별 초기 각도로 돌아와야 한다.")
	_expect(_is_outline_enabled(flipper), \
		"선택된 플리퍼는 IDLE 복귀 후 다시 강조되어야 한다.")

	if flipper.state_changed.is_connected(_on_flipper_state_changed):
		flipper.state_changed.disconnect(_on_flipper_state_changed)


func _on_flipper_state_changed(_previous_state: int, current_state: int) -> void:
	_observed_states.append(current_state)


func _is_outline_enabled(flipper: PinballFlipper) -> bool:
	var sprite := flipper.get_node("Sprite2D") as Sprite2D
	var shader_material := sprite.material as ShaderMaterial

	if shader_material == null:
		return false

	return bool(shader_material.get_shader_parameter("outline_enabled"))


func _find_property(object: Object, property_name: StringName) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return property

	return {}


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
		print("PASS: flipper_state_machine_test")
		quit(0)
		return

	print("FAIL: flipper_state_machine_test (%d failures)" % _failures.size())
	quit(1)
