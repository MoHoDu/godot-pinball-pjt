extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const STATS_SCRIPT_PATH := "res://scripts/ball_base_system/pinball_stats.gd"
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

	var ball := packed_scene.instantiate() as Pinball
	_expect(ball != null, "기본 공 씬의 루트는 Pinball이어야 한다.")

	if ball == null:
		_finish()
		return

	root.add_child(ball)
	await process_frame

	var stats_script := load(STATS_SCRIPT_PATH) as Script
	_test_stats_resource_contract(stats_script)
	_test_ball_stats_binding(ball, stats_script)
	_test_collision_editor_contract(ball)
	_test_collision_geometry(ball)
	await _test_variation_instances_are_isolated(packed_scene, ball)

	ball.queue_free()
	await process_frame
	_finish()


func _test_stats_resource_contract(stats_script: Script) -> void:
	_expect(stats_script != null, "PinballStats 리소스 스크립트가 필요하다.")

	if stats_script == null:
		return

	var stats := stats_script.new() as Resource
	_expect(stats != null, "PinballStats는 Resource로 생성할 수 있어야 한다.")

	if stats == null:
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
		var property := _find_property(stats, property_name)
		_expect(not property.is_empty(), \
			"PinballStats.%s 속성이 Inspector에 표시되어야 한다." % property_name)

		if property.is_empty():
			continue

		var usage := int(property.get("usage", 0))
		var hint_string := str(property.get("hint_string", ""))
		_expect((usage & PROPERTY_USAGE_EDITOR) != 0, \
			"PinballStats.%s 속성은 에디터에서 편집 가능해야 한다." % property_name)
		_expect(hint_string.begins_with(expected_ranges[property_name]), \
			"PinballStats.%s의 Inspector 범위가 올바르지 않다: %s" \
			% [property_name, hint_string])

	_expect_float(float(stats.get(&"mass")), 1.0, "기본 무게는 1kg이어야 한다.")
	_expect_float(float(stats.get(&"elasticity")), 0.8, "기본 탄성은 0.8이어야 한다.")
	_expect_float(float(stats.get(&"initial_speed")), 700.0, \
		"기본 초기 속력은 700px/s이어야 한다.")
	_expect_float(float(stats.get(&"minimum_speed")), 200.0, \
		"기본 최소 속력은 200px/s이어야 한다.")
	_expect_float(float(stats.get(&"maximum_speed")), 2500.0, \
		"기본 최대 속력은 2500px/s이어야 한다.")
	_expect_float(float(stats.get(&"gravity_scale")), 1.0, \
		"기본 중력 배율은 1배여야 한다.")

	stats.set(&"mass", -1.0)
	stats.set(&"elasticity", 2.0)
	stats.set(&"gravity_scale", 10.0)
	_expect_float(float(stats.get(&"mass")), 0.1, "무게 하한을 적용해야 한다.")
	_expect_float(float(stats.get(&"elasticity")), 1.0, "탄성 상한을 적용해야 한다.")
	_expect_float(float(stats.get(&"gravity_scale")), 5.0, "중력 배율 상한을 적용해야 한다.")

	stats.set(&"minimum_speed", 1000.0)
	stats.set(&"maximum_speed", 500.0)
	stats.set(&"initial_speed", 2000.0)
	_expect_float(float(stats.get(&"maximum_speed")), 1000.0, \
		"최대 속력은 최소 속력보다 작아질 수 없다.")
	_expect_float(float(stats.get(&"initial_speed")), 1000.0, \
		"초기 속력은 최대 속력을 초과할 수 없다.")


func _test_ball_stats_binding(ball: Pinball, stats_script: Script) -> void:
	var stats_property := _find_property(ball, &"stats")
	_expect(not stats_property.is_empty(), \
		"Pinball은 Inspector에서 편집할 PinballStats 속성을 제공해야 한다.")

	if stats_property.is_empty() or stats_script == null:
		return

	var stats := stats_script.new() as Resource
	stats.set(&"mass", 3.5)
	stats.set(&"elasticity", 0.35)
	stats.set(&"gravity_scale", 1.75)
	ball.set(&"stats", stats)

	_expect(ball.get(&"stats") == stats, "지정한 스탯 리소스를 공이 보관해야 한다.")
	_expect_float(ball.mass, 3.5, "스탯 무게를 RigidBody2D.mass에 반영해야 한다.")
	_expect_float(ball.gravity_scale, 1.75, \
		"스탯 중력 배율을 RigidBody2D.gravity_scale에 반영해야 한다.")
	_expect(ball.physics_material_override != null, \
		"스탯 탄성을 적용할 PhysicsMaterial이 필요하다.")

	if ball.physics_material_override != null:
		_expect_float(ball.physics_material_override.bounce, 0.35, \
			"스탯 탄성을 PhysicsMaterial.bounce에 반영해야 한다.")

	stats.set(&"mass", 4.0)
	stats.set(&"elasticity", 0.55)
	_expect_float(ball.mass, 4.0, \
		"Inspector에서 내부 스탯을 바꾸면 공 물성이 즉시 갱신되어야 한다.")
	_expect_float(ball.physics_material_override.bounce, 0.55, \
		"내부 스탯의 탄성 변경도 즉시 반영되어야 한다.")


func _test_collision_editor_contract(ball: Pinball) -> void:
	var expected_ranges := {
		&"ball_diameter": "16.0,256.0",
		&"collision_radius_ratio": "0.25,1.5",
	}

	for property_name: StringName in expected_ranges:
		var property := _find_property(ball, property_name)
		_expect(not property.is_empty(), \
			"Pinball.%s 속성이 Inspector에 표시되어야 한다." % property_name)

		if property.is_empty():
			continue

		var hint_string := str(property.get("hint_string", ""))
		_expect(hint_string.begins_with(expected_ranges[property_name]), \
			"Pinball.%s의 Inspector 범위가 올바르지 않다: %s" \
			% [property_name, hint_string])

	var offset_property := _find_property(ball, &"collision_offset")
	_expect(not offset_property.is_empty(), \
		"충돌 중심을 조절할 collision_offset 속성이 Inspector에 표시되어야 한다.")


func _test_collision_geometry(ball: Pinball) -> void:
	if not _has_properties(ball, [
		&"ball_diameter",
		&"collision_radius_ratio",
		&"collision_offset",
	]):
		return

	ball.set(&"ball_diameter", 80.0)
	ball.set(&"collision_radius_ratio", 0.75)
	ball.set(&"collision_offset", Vector2(4.0, -6.0))
	ball.call(&"refresh_ball_size")

	var collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D
	_expect_float(circle.radius, 30.0, \
		"80px 공에 충돌 반지름 비율 0.75를 적용하면 반지름은 30px이어야 한다.")
	_expect_vector(collision.scale, Vector2.ONE, \
		"충돌체 크기는 노드 Scale이 아니라 CircleShape2D.radius로 설정해야 한다.")
	_expect_vector(collision.position, Vector2(4.0, -6.0), \
		"충돌 중심 오프셋을 CollisionShape2D 위치에 반영해야 한다.")


func _test_variation_instances_are_isolated(
	packed_scene: PackedScene,
	first_ball: Pinball
) -> void:
	if not _has_properties(first_ball, [
		&"stats",
		&"ball_diameter",
		&"collision_radius_ratio",
	]):
		return

	var second_ball := packed_scene.instantiate() as Pinball
	root.add_child(second_ball)
	await process_frame

	var first_stats := first_ball.get(&"stats") as Resource
	var second_stats := second_ball.get(&"stats") as Resource
	_expect(first_stats != null and second_stats != null, \
		"각 공 인스턴스에는 기본 스탯 리소스가 필요하다.")
	_expect(first_stats != second_stats, \
		"기본 공 인스턴스끼리는 스탯 리소스를 공유하지 않아야 한다.")

	var first_collision := first_ball.get_node("CollisionShape2D") as CollisionShape2D
	var second_collision := second_ball.get_node("CollisionShape2D") as CollisionShape2D
	_expect(first_collision.shape != second_collision.shape, \
		"공 인스턴스마다 독립된 CircleShape2D를 사용해야 한다.")

	first_ball.set(&"ball_diameter", 40.0)
	first_ball.set(&"collision_radius_ratio", 0.5)
	second_ball.set(&"ball_diameter", 120.0)
	second_ball.set(&"collision_radius_ratio", 1.25)

	var first_circle := first_collision.shape as CircleShape2D
	var second_circle := second_collision.shape as CircleShape2D
	_expect_float(first_circle.radius, 10.0, "첫 번째 공의 충돌 반지름이 독립적으로 적용되어야 한다.")
	_expect_float(second_circle.radius, 75.0, "두 번째 공의 충돌 반지름이 독립적으로 적용되어야 한다.")

	second_ball.free()


func _has_properties(object: Object, property_names: Array) -> bool:
	var has_all := true

	for property_name: StringName in property_names:
		if not _find_property(object, property_name).is_empty():
			continue

		_expect(false, "%s 속성이 필요하다." % property_name)
		has_all = false

	return has_all


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
		print("PASS: pinball_variation_test")
		quit(0)
		return

	print("FAIL: pinball_variation_test (%d failures)" % _failures.size())
	quit(1)
