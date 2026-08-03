extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const EPSILON := 0.001

const EXPECTED_DEFAULT_MASS := 1.0
const EXPECTED_DEFAULT_ELASTICITY := 0.8
const EXPECTED_DEFAULT_INITIAL_SPEED := 700.0
const EXPECTED_DEFAULT_MINIMUM_SPEED := 200.0
const EXPECTED_DEFAULT_MAXIMUM_SPEED := 2000.0
const EXPECTED_DEFAULT_GRAVITY_SCALE := 1.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BALL_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")

	if packed_scene == null:
		_finish()
		return

	var ball := packed_scene.instantiate() as Pinball
	_expect(ball != null, "기본 공 씬의 루트는 Pinball이어야 한다.")

	if ball == null:
		_finish()
		return

	root.add_child(ball)
	await process_frame

	_test_editor_property_contract(ball)
	_test_default_physics_values(ball)
	_test_property_clamps(ball)
	_test_speed_range_invariants(ball)
	_test_launch_uses_initial_speed(ball)
	_test_velocity_limit_rules(ball)
	await _test_temporary_collision_speed_limit(ball)
	await _test_runtime_velocity_limits(ball)
	await _test_gravity_reverses_upward_motion(ball)
	_test_physics_material_is_instance_local(packed_scene, ball)

	ball.queue_free()
	await process_frame
	_finish()


func _test_editor_property_contract(ball: Pinball) -> void:
	var stats_property := _find_property(ball, &"stats")
	_expect(not stats_property.is_empty(), \
		"공 개별 스탯 리소스가 Inspector에 표시되어야 한다.")

	if stats_property.is_empty() or ball.stats == null:
		return

	var expected_ranges := {
		&"mass": "0.1,100.0",
		&"elasticity": "0.0,1.0",
		&"initial_speed": "0.0,5000.0",
		&"minimum_speed": "0.0,5000.0",
		&"maximum_speed": "0.0,5000.0",
		&"gravity_scale": "0.0,5.0",
	}

	for property_name: StringName in expected_ranges:
		var property := _find_property(ball.stats, property_name)
		_expect(not property.is_empty(), \
			"PinballStats.%s 속성이 Inspector에 표시되어야 한다." % property_name)

		if property.is_empty():
			continue

		var usage := int(property.get("usage", 0))
		var hint_string := str(property.get("hint_string", ""))
		_expect((usage & PROPERTY_USAGE_EDITOR) != 0, \
			"%s 속성은 에디터에서 편집 가능해야 한다." % property_name)
		_expect(hint_string.begins_with(expected_ranges[property_name]), \
			"%s 속성의 Inspector 범위가 올바르지 않다: %s" \
			% [property_name, hint_string])


func _test_default_physics_values(ball: Pinball) -> void:
	if ball.stats == null:
		_expect(false, "공 개별 스탯 리소스가 필요하다.")
		return

	var required_properties := [
		&"mass",
		&"elasticity",
		&"initial_speed",
		&"minimum_speed",
		&"maximum_speed",
		&"gravity_scale",
	]
	if not _require_properties(ball.stats, required_properties):
		return

	_expect_float(ball.stats.mass, EXPECTED_DEFAULT_MASS, \
		"공의 기본 무게는 1kg이어야 한다.")
	_expect_float(ball.stats.elasticity, EXPECTED_DEFAULT_ELASTICITY, \
		"공의 기본 탄성은 0.8이어야 한다.")
	_expect_float(ball.stats.initial_speed, EXPECTED_DEFAULT_INITIAL_SPEED, \
		"공의 기본 초기 속력은 700px/s이어야 한다.")
	_expect_float(ball.stats.minimum_speed, EXPECTED_DEFAULT_MINIMUM_SPEED, \
		"공의 기본 최소 속력은 200px/s이어야 한다.")
	_expect_float(ball.stats.maximum_speed, EXPECTED_DEFAULT_MAXIMUM_SPEED, \
		"공의 기본 최대 속력은 2000px/s이어야 한다.")
	_expect_float(ball.stats.gravity_scale, EXPECTED_DEFAULT_GRAVITY_SCALE, \
		"공의 기본 중력 배율은 1배여야 한다.")

	_expect_float(ball.mass, EXPECTED_DEFAULT_MASS, \
		"설정한 공 무게가 RigidBody2D.mass에 적용되어야 한다.")
	_expect_float(ball.gravity_scale, EXPECTED_DEFAULT_GRAVITY_SCALE, \
		"설정한 중력 배율이 RigidBody2D.gravity_scale에 적용되어야 한다.")
	_expect(ball.physics_material_override != null, \
		"탄성 적용을 위한 PhysicsMaterial이 준비되어야 한다.")

	if ball.physics_material_override != null:
		_expect_float(ball.physics_material_override.bounce, EXPECTED_DEFAULT_ELASTICITY, \
			"설정한 탄성이 PhysicsMaterial.bounce에 적용되어야 한다.")


func _test_property_clamps(ball: Pinball) -> void:
	if ball.stats == null or not _require_properties(ball.stats, [
		&"mass",
		&"elasticity",
		&"gravity_scale",
	]):
		return

	ball.stats.mass = -10.0
	_expect_float(ball.stats.mass, 0.1, \
		"공 무게는 0.1kg보다 작아질 수 없다.")
	ball.stats.mass = 1000.0
	_expect_float(ball.stats.mass, 100.0, \
		"공 무게는 100kg보다 커질 수 없다.")

	ball.stats.elasticity = -1.0
	_expect_float(ball.stats.elasticity, 0.0, \
		"공 탄성은 0보다 작아질 수 없다.")
	ball.stats.elasticity = 2.0
	_expect_float(ball.stats.elasticity, 1.0, \
		"공 탄성은 1보다 커질 수 없다.")

	ball.stats.gravity_scale = -1.0
	_expect_float(ball.stats.gravity_scale, 0.0, \
		"공 중력 배율은 0보다 작아질 수 없다.")
	ball.stats.gravity_scale = 10.0
	_expect_float(ball.stats.gravity_scale, 5.0, \
		"공 중력 배율은 5보다 커질 수 없다.")

	ball.stats.mass = EXPECTED_DEFAULT_MASS
	ball.stats.elasticity = EXPECTED_DEFAULT_ELASTICITY
	ball.stats.gravity_scale = EXPECTED_DEFAULT_GRAVITY_SCALE


func _test_speed_range_invariants(ball: Pinball) -> void:
	if ball.stats == null or not _require_properties(ball.stats, [
		&"initial_speed",
		&"minimum_speed",
		&"maximum_speed",
	]):
		return

	ball.stats.minimum_speed = 1000.0
	ball.stats.maximum_speed = 500.0
	_expect_float(ball.stats.maximum_speed, 1000.0, \
		"최대 속력은 최소 속력보다 작아질 수 없다.")

	ball.stats.initial_speed = 2000.0
	_expect_float(ball.stats.initial_speed, 1000.0, \
		"초기 속력은 최대 속력을 초과할 수 없다.")
	ball.stats.initial_speed = -10.0
	_expect_float(ball.stats.initial_speed, 0.0, \
		"초기 속력은 0보다 작아질 수 없다.")

	ball.stats.minimum_speed = EXPECTED_DEFAULT_MINIMUM_SPEED
	ball.stats.maximum_speed = EXPECTED_DEFAULT_MAXIMUM_SPEED
	ball.stats.initial_speed = EXPECTED_DEFAULT_INITIAL_SPEED


func _test_launch_uses_initial_speed(ball: Pinball) -> void:
	if not ball.has_method(&"launch"):
		_expect(false, "Pinball은 launch(direction) API를 제공해야 한다.")
		return

	ball.linear_velocity = Vector2.ZERO
	var launched := bool(ball.call(&"launch", Vector2(3.0, 4.0)))
	_expect(launched, "0이 아닌 방향으로 공을 발사할 수 있어야 한다.")
	_expect_float(ball.linear_velocity.length(), EXPECTED_DEFAULT_INITIAL_SPEED, \
		"launch()는 설정된 초기 속력을 사용해야 한다.")
	_expect_vector(ball.linear_velocity.normalized(), Vector2(0.6, 0.8), \
		"launch()는 입력 방향을 정규화해 사용해야 한다.")

	var overridden_launch := bool(ball.call(&"launch", Vector2.LEFT, 1200.0))
	_expect(overridden_launch, "런처가 선택한 속력으로 공을 발사할 수 있어야 한다.")
	_expect_float(ball.linear_velocity.length(), 1200.0, \
		"launch()는 유효한 요청 속력을 공 물리 범위 안에서 사용해야 한다.")
	_expect_vector(ball.linear_velocity.normalized(), Vector2.LEFT, \
		"속력 요청을 추가해도 입력 방향을 보존해야 한다.")

	var velocity_before_invalid_launch := ball.linear_velocity
	var invalid_launch := bool(ball.call(&"launch", Vector2.ZERO))
	_expect(not invalid_launch, "방향이 0인 발사는 거부해야 한다.")
	_expect_vector(ball.linear_velocity, velocity_before_invalid_launch, \
		"잘못된 발사는 기존 속도를 변경하지 않아야 한다.")
	var invalid_speed_launch := bool(ball.call(&"launch", Vector2.RIGHT, -0.5))
	_expect(not invalid_speed_launch, "-1 외의 음수 요청 속력은 거부해야 한다.")
	_expect_vector(ball.linear_velocity, velocity_before_invalid_launch, \
		"잘못된 요청 속력은 기존 속도를 변경하지 않아야 한다.")

	ball.linear_velocity = Vector2.ZERO


func _test_velocity_limit_rules(ball: Pinball) -> void:
	if not ball.has_method(&"get_limited_velocity"):
		_expect(false, "Pinball은 속도 제한 계산 API를 제공해야 한다.")
		return

	var stopped := ball.call(&"get_limited_velocity", Vector2.ZERO) as Vector2
	_expect_vector(stopped, Vector2.ZERO, "정지한 공은 최소 속력으로 강제 발사하지 않아야 한다.")

	var slow := ball.call(&"get_limited_velocity", Vector2(50.0, 0.0)) as Vector2
	_expect_vector(slow, Vector2(EXPECTED_DEFAULT_MINIMUM_SPEED, 0.0), \
		"움직이는 공이 최소 속력보다 느리면 방향을 유지한 채 보정해야 한다.")

	var normal := ball.call(&"get_limited_velocity", Vector2(600.0, 800.0)) as Vector2
	_expect_vector(normal, Vector2(600.0, 800.0), \
		"속력 범위 안의 공은 변경하지 않아야 한다.")

	var fast := ball.call(&"get_limited_velocity", Vector2(3000.0, 4000.0)) as Vector2
	_expect_vector(fast, Vector2(1200.0, 1600.0), \
		"최대 속력을 넘으면 방향을 유지한 채 2000px/s로 제한해야 한다.")


func _test_temporary_collision_speed_limit(ball: Pinball) -> void:
	for method_name: StringName in [
		&"request_temporary_maximum_speed",
		&"get_active_temporary_maximum_speed",
		&"clear_temporary_maximum_speed",
		&"enforce_active_temporary_speed_limit",
	]:
		_expect(ball.has_method(method_name), \
			"충돌 직후 실제 속도 상한을 위한 %s API가 필요하다." % method_name)
	if not ball.has_method(&"request_temporary_maximum_speed") \
		or not ball.has_method(&"get_active_temporary_maximum_speed") \
		or not ball.has_method(&"clear_temporary_maximum_speed") \
		or not ball.has_method(&"enforce_active_temporary_speed_limit"):
		return

	var original_minimum := ball.stats.minimum_speed
	var original_maximum := ball.stats.maximum_speed
	var original_gravity := ball.stats.gravity_scale
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.call(&"request_temporary_maximum_speed", 1540.0, 2)
	_expect_float(float(ball.call(&"get_active_temporary_maximum_speed")), 1540.0, \
		"공은 플리퍼가 요청한 임시 최대 속도를 현재 충돌 상한으로 보관해야 한다.")

	ball.linear_velocity = Vector2(4000.0, 0.0)
	ball.call(&"enforce_active_temporary_speed_limit")
	_expect_float(ball.linear_velocity.length(), 1540.0, \
		"공은 물리 프레임 사이에도 관찰 가능한 linear_velocity를 즉시 제한해야 한다.")
	ball.linear_velocity = Vector2(4000.0, 0.0)
	await physics_frame
	_expect_float(ball.linear_velocity.length(), 1540.0, \
		"실제 물리 프레임의 linear_velocity가 임시 충돌 상한을 넘으면 안 된다.")
	await physics_frame
	_expect(ball.linear_velocity.length() <= 1540.0 + EPSILON, \
		"충돌 정리 프레임 동안 임시 속도 상한이 유지되어야 한다.")
	await physics_frame
	_expect(is_inf(float(ball.call(&"get_active_temporary_maximum_speed"))), \
		"임시 충돌 상한은 지정한 물리 프레임 이후 자동으로 해제되어야 한다.")

	ball.stats.maximum_speed = 1200.0
	ball.call(&"request_temporary_maximum_speed", 1700.0, 2)
	ball.linear_velocity = Vector2(4000.0, 0.0)
	ball.call(&"enforce_active_temporary_speed_limit")
	_expect_float(ball.linear_velocity.length(), 1200.0, \
		"공 자체 최대 속도가 충돌 임시 상한보다 낮으면 공의 상한이 우선해야 한다.")
	ball.call(&"clear_temporary_maximum_speed")
	_expect(is_inf(float(ball.call(&"get_active_temporary_maximum_speed"))), \
		"공 재배치 등을 위해 임시 충돌 상한을 즉시 초기화할 수 있어야 한다.")

	ball.linear_velocity = Vector2.ZERO
	ball.stats.minimum_speed = original_minimum
	ball.stats.maximum_speed = original_maximum
	ball.stats.gravity_scale = original_gravity


func _test_runtime_velocity_limits(ball: Pinball) -> void:
	# 에디터 전용 실행에서는 물리 서버 프레임이 진행되지 않는다.
	# 실제 속도 제한은 일반 헤드리스 런타임 테스트에서 검증한다.
	if Engine.is_editor_hint():
		return

	if ball.stats == null:
		return

	ball.stats.gravity_scale = 0.0
	ball.linear_velocity = Vector2(5000.0, 0.0)
	await physics_frame
	_expect_float(ball.linear_velocity.length(), EXPECTED_DEFAULT_MAXIMUM_SPEED, \
		"실제 물리 프레임에서 최대 속력 제한을 적용해야 한다.")

	ball.linear_velocity = Vector2(50.0, 0.0)
	await physics_frame
	_expect_float(ball.linear_velocity.length(), EXPECTED_DEFAULT_MINIMUM_SPEED, \
		"실제 물리 프레임에서 최소 속력 제한을 적용해야 한다.")

	ball.linear_velocity = Vector2.ZERO
	await physics_frame
	_expect_vector(ball.linear_velocity, Vector2.ZERO, \
		"실제 물리 프레임에서도 정지 상태는 유지해야 한다.")

	ball.stats.gravity_scale = EXPECTED_DEFAULT_GRAVITY_SCALE


func _test_gravity_reverses_upward_motion(ball: Pinball) -> void:
	if Engine.is_editor_hint():
		return

	ball.stats.gravity_scale = EXPECTED_DEFAULT_GRAVITY_SCALE
	ball.sleeping = false
	ball.linear_velocity = Vector2(0.0, -300.0)

	for _physics_step: int in 45:
		await physics_frame

	_expect(ball.linear_velocity.y > 0.0, \
		"위로 튄 공은 최소 속력 보정에 갇히지 않고 중력에 의해 다시 낙하해야 한다.")

	ball.linear_velocity = Vector2.ZERO


func _test_physics_material_is_instance_local(
	packed_scene: PackedScene,
	first_ball: Pinball
) -> void:
	if first_ball.stats == null:
		return

	var second_ball := packed_scene.instantiate() as Pinball
	root.add_child(second_ball)

	_expect(first_ball.physics_material_override != null, \
		"첫 번째 공의 PhysicsMaterial이 필요하다.")
	_expect(second_ball.physics_material_override != null, \
		"두 번째 공의 PhysicsMaterial이 필요하다.")
	_expect(first_ball.physics_material_override != second_ball.physics_material_override, \
		"공 인스턴스마다 독립된 PhysicsMaterial을 사용해야 한다.")

	first_ball.stats.elasticity = 0.25
	_expect_float(first_ball.physics_material_override.bounce, 0.25, \
		"첫 번째 공의 탄성 변경이 적용되어야 한다.")
	_expect_float(second_ball.physics_material_override.bounce, EXPECTED_DEFAULT_ELASTICITY, \
		"첫 번째 공의 탄성 변경이 두 번째 공에 영향을 주지 않아야 한다.")

	first_ball.stats.elasticity = EXPECTED_DEFAULT_ELASTICITY
	second_ball.free()


func _require_properties(object: Object, property_names: Array) -> bool:
	var has_all_properties := true

	for property_name: StringName in property_names:
		if _has_property(object, property_name):
			continue

		_expect(false, "%s 속성이 필요하다." % property_name)
		has_all_properties = false

	return has_all_properties


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


func _has_property(object: Object, property_name: StringName) -> bool:
	return not _find_property(object, property_name).is_empty()


func _find_property(object: Object, property_name: StringName) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return property

	return {}


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_physics_test")
		quit(0)
		return

	print("FAIL: pinball_physics_test (%d failures)" % _failures.size())
	quit(1)
