extends SceneTree

const BALL_SCENE_PATH := "res://resources/balls/base/base_ball.tscn"
const RULES_SCRIPT_PATH := "res://scripts/ball_base_system/pinball_physics_rules.gd"
const RULES_RESOURCE_PATH := "res://settings/balls/PinballPhysicsRules.tres"
const EPSILON := 0.001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BALL_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")

	if packed_scene == null:
		_finish()
		return

	var rules_script := load(RULES_SCRIPT_PATH) as Script
	var default_rules := load(RULES_RESOURCE_PATH) as Resource
	_test_rules_resource_contract(rules_script, default_rules)

	var ball := packed_scene.instantiate() as Pinball
	root.add_child(ball)
	await process_frame

	_test_default_rules_binding(ball, default_rules)
	_test_rules_clamp_effective_values(ball, rules_script)
	_test_out_of_rules_editor_warning(ball)
	await _test_default_rules_are_shared(packed_scene, ball, default_rules)

	ball.queue_free()
	await process_frame
	_finish()


func _test_rules_resource_contract(
	rules_script: Script,
	default_rules: Resource
) -> void:
	_expect(rules_script != null, "PinballPhysicsRules 스크립트가 필요하다.")
	_expect(default_rules != null, \
		"settings/balls/PinballPhysicsRules.tres 공용 설정이 필요하다.")

	if rules_script == null or default_rules == null:
		return

	var required_properties := [
		&"minimum_mass",
		&"maximum_mass",
		&"minimum_elasticity",
		&"maximum_elasticity",
		&"minimum_speed",
		&"maximum_speed",
		&"minimum_gravity_scale",
		&"maximum_gravity_scale",
	]

	for property_name: StringName in required_properties:
		var property := _find_property(default_rules, property_name)
		_expect(not property.is_empty(), \
			"공용 규칙의 %s 속성이 Inspector에 표시되어야 한다." % property_name)

	_expect_float(float(default_rules.get(&"minimum_mass")), 0.1, \
		"기본 공용 무게 하한은 0.1kg이어야 한다.")
	_expect_float(float(default_rules.get(&"maximum_mass")), 100.0, \
		"기본 공용 무게 상한은 100kg이어야 한다.")
	_expect_float(float(default_rules.get(&"minimum_speed")), 0.0, \
		"기본 공용 속력 하한은 0px/s이어야 한다.")
	_expect_float(float(default_rules.get(&"maximum_speed")), 5000.0, \
		"기본 공용 속력 상한은 5000px/s이어야 한다.")


func _test_default_rules_binding(ball: Pinball, default_rules: Resource) -> void:
	if default_rules == null:
		return

	_expect(ball.get(&"physics_rules") == default_rules, \
		"기본 공은 settings의 공용 Rules 리소스를 참조해야 한다.")

	var rules_property := _find_property(ball, &"physics_rules")
	var usage := int(rules_property.get("usage", 0))
	_expect((usage & PROPERTY_USAGE_EDITOR) == 0, \
		"공용 Rules는 개별 공 Inspector에서 교체할 수 없어야 한다.")


func _test_rules_clamp_effective_values(ball: Pinball, rules_script: Script) -> void:
	if rules_script == null or ball.stats == null:
		return

	var rules := rules_script.new() as Resource
	rules.set(&"minimum_mass", 2.0)
	rules.set(&"maximum_mass", 4.0)
	rules.set(&"minimum_elasticity", 0.2)
	rules.set(&"maximum_elasticity", 0.6)
	rules.set(&"minimum_speed", 300.0)
	rules.set(&"maximum_speed", 900.0)
	rules.set(&"minimum_gravity_scale", 0.5)
	rules.set(&"maximum_gravity_scale", 1.5)

	ball.stats.mass = 10.0
	ball.stats.elasticity = 0.9
	ball.stats.minimum_speed = 100.0
	ball.stats.maximum_speed = 3000.0
	ball.stats.initial_speed = 1500.0
	ball.stats.gravity_scale = 3.0
	ball.set(&"physics_rules", rules)

	_expect_float(ball.stats.mass, 10.0, \
		"공용 규칙 적용은 개별 공의 작성값을 파괴하지 않아야 한다.")
	_expect_float(ball.stats.maximum_speed, 3000.0, \
		"공용 속도 범위 적용 후에도 개별 최대 속력 원본을 보존해야 한다.")
	_expect_float(ball.mass, 4.0, \
		"실제 RigidBody2D 무게는 공용 상한 4kg으로 보정되어야 한다.")
	_expect_float(ball.gravity_scale, 1.5, \
		"실제 중력 배율은 공용 상한 1.5배로 보정되어야 한다.")
	_expect_float(ball.physics_material_override.bounce, 0.6, \
		"실제 탄성은 공용 상한 0.6으로 보정되어야 한다.")

	var slow := ball.get_limited_velocity(Vector2(100.0, 0.0))
	var fast := ball.get_limited_velocity(Vector2(2000.0, 0.0))
	_expect_float(slow.length(), 300.0, \
		"개별 최소 속력보다 공용 하한이 크면 공용 하한을 사용해야 한다.")
	_expect_float(fast.length(), 900.0, \
		"개별 최대 속력보다 공용 상한이 작으면 공용 상한을 사용해야 한다.")

	ball.launch(Vector2.RIGHT)
	_expect_float(ball.linear_velocity.length(), 900.0, \
		"초기 속력도 공용 속력 범위와 개별 속력 범위 안으로 보정해야 한다.")
	ball.linear_velocity = Vector2.ZERO

	rules.set(&"maximum_mass", 3.0)
	_expect_float(ball.mass, 3.0, \
		"실행 중 공용 규칙을 변경하면 연결된 공에 즉시 다시 적용되어야 한다.")


func _test_out_of_rules_editor_warning(ball: Pinball) -> void:
	if ball.get(&"physics_rules") == null:
		return

	var warnings := ball._get_configuration_warnings()
	var found_rules_warning := false

	for warning: String in warnings:
		if warning.contains("공용 물리 규칙"):
			found_rules_warning = true
			break

	_expect(found_rules_warning, \
		"개별 스탯이 공용 범위를 벗어나면 에디터 구성 경고를 제공해야 한다.")


func _test_default_rules_are_shared(
	packed_scene: PackedScene,
	first_ball: Pinball,
	default_rules: Resource
) -> void:
	first_ball.set(&"physics_rules", default_rules)
	var second_ball := packed_scene.instantiate() as Pinball
	root.add_child(second_ball)
	await process_frame

	_expect(first_ball.get(&"physics_rules") == second_ball.get(&"physics_rules"), \
		"기본 공 인스턴스들은 하나의 공용 Rules 리소스를 공유해야 한다.")

	second_ball.free()


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
		print("PASS: pinball_physics_rules_test")
		quit(0)
		return

	print("FAIL: pinball_physics_rules_test (%d failures)" % _failures.size())
	quit(1)
