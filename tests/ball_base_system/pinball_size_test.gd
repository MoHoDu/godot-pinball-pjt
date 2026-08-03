extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const EXPECTED_DEFAULT_DIAMETER := 64.0
const EXPECTED_MIN_DIAMETER := 16.0
const EXPECTED_MAX_DIAMETER := 256.0
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

	_test_required_node_contract(ball)
	_test_editor_property_contract(ball)
	_test_default_size(ball)
	_test_size_clamp(ball)
	_test_instances_keep_independent_sizes(packed_scene, ball)
	_test_texture_independent_size(ball)
	_test_missing_nodes_are_reported_safely()

	ball.queue_free()
	await process_frame
	_finish()


func _test_required_node_contract(ball: Pinball) -> void:
	_expect(ball.get_node_or_null("Visual/Sprite2D") is Sprite2D, \
		"Visual/Sprite2D 노드가 필요하다.")
	_expect(ball.get_node_or_null("CollisionShape2D") is CollisionShape2D, \
		"CollisionShape2D 노드가 필요하다.")

	var collision := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(collision != null and collision.shape is CircleShape2D, \
		"CollisionShape2D는 CircleShape2D를 사용해야 한다.")


func _test_editor_property_contract(ball: Pinball) -> void:
	var diameter_property := _find_property(ball, &"ball_diameter")
	_expect(not diameter_property.is_empty(), \
		"공 지름은 에디터에서 편집 가능한 속성이어야 한다.")

	if diameter_property.is_empty():
		return

	var usage := int(diameter_property.get("usage", 0))
	var hint_string := str(diameter_property.get("hint_string", ""))
	_expect((usage & PROPERTY_USAGE_EDITOR) != 0, \
		"공 지름은 Inspector에 표시되어야 한다.")
	_expect(hint_string.begins_with("16.0,256.0"), \
		"Inspector의 공 지름 범위는 16~256px이어야 한다.")


func _test_default_size(ball: Pinball) -> void:
	if not _has_property(ball, &"ball_diameter"):
		_expect(false, "Pinball은 ball_diameter 속성을 제공해야 한다.")
		return

	_expect_float(ball.ball_diameter, EXPECTED_DEFAULT_DIAMETER, \
		"공 기본 지름은 64px이어야 한다.")
	_expect_ball_geometry(ball, EXPECTED_DEFAULT_DIAMETER)


func _test_size_clamp(ball: Pinball) -> void:
	if not _has_property(ball, &"ball_diameter"):
		_expect(false, "Pinball은 크기 제한을 위한 ball_diameter 속성을 제공해야 한다.")
		return

	ball.ball_diameter = 1.0
	_expect_float(ball.ball_diameter, EXPECTED_MIN_DIAMETER, \
		"공 지름은 하한 16px보다 작아질 수 없다.")
	_expect_ball_geometry(ball, EXPECTED_MIN_DIAMETER)

	ball.ball_diameter = 1000.0
	_expect_float(ball.ball_diameter, EXPECTED_MAX_DIAMETER, \
		"공 지름은 상한 256px보다 커질 수 없다.")
	_expect_ball_geometry(ball, EXPECTED_MAX_DIAMETER)

	ball.ball_diameter = EXPECTED_DEFAULT_DIAMETER


func _test_texture_independent_size(ball: Pinball) -> void:
	if not _has_property(ball, &"ball_diameter") or not ball.has_method(&"refresh_ball_size"):
		_expect(false, "Pinball은 이미지 독립 크기 갱신 API를 제공해야 한다.")
		return


	var sprite := ball.get_node("Visual/Sprite2D") as Sprite2D
	var wide_texture := GradientTexture2D.new()
	wide_texture.width = 512
	wide_texture.height = 128
	sprite.texture = wide_texture

	ball.ball_diameter = EXPECTED_DEFAULT_DIAMETER
	ball.refresh_ball_size()

	var rendered_size := sprite.texture.get_size() * sprite.scale.abs()
	_expect_float(maxf(rendered_size.x, rendered_size.y), EXPECTED_DEFAULT_DIAMETER, \
		"텍스처 원본 해상도와 무관하게 가장 긴 변이 공 지름과 같아야 한다.")


func _test_instances_keep_independent_sizes(
	packed_scene: PackedScene,
	first_ball: Pinball
) -> void:
	if not _has_property(first_ball, &"ball_diameter"):
		return

	var second_ball := packed_scene.instantiate() as Pinball
	root.add_child(second_ball)

	first_ball.ball_diameter = 32.0
	second_ball.ball_diameter = 128.0

	_expect_ball_geometry(first_ball, 32.0)
	_expect_ball_geometry(second_ball, 128.0)

	first_ball.ball_diameter = EXPECTED_DEFAULT_DIAMETER
	second_ball.free()


func _test_missing_nodes_are_reported_safely() -> void:
	var incomplete_ball := Pinball.new()
	if not incomplete_ball.has_method(&"refresh_ball_size"):
		_expect(false, "Pinball은 필수 노드가 없어도 호출 가능한 크기 갱신 API를 제공해야 한다.")
		incomplete_ball.free()
		return


	incomplete_ball.refresh_ball_size()

	var warnings := incomplete_ball._get_configuration_warnings()
	_expect(warnings.size() >= 2, \
		"필수 시각/충돌 노드가 없으면 에디터 구성 경고를 제공해야 한다.")

	incomplete_ball.free()


func _expect_ball_geometry(ball: Pinball, expected_diameter: float) -> void:
	var sprite := ball.get_node("Visual/Sprite2D") as Sprite2D
	var collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D

	var effective_collision_diameter := (
		circle.radius
		* 2.0
		* maxf(absf(collision.scale.x), absf(collision.scale.y))
	)
	var expected_collision_diameter := (
		expected_diameter
		* ball.collision_radius_ratio
	)
	_expect_float(effective_collision_diameter, expected_collision_diameter, \
		"유효 충돌 지름은 공 지름에 Collision Radius Ratio를 적용해야 한다.")

	var rendered_size := sprite.texture.get_size() * sprite.scale.abs()
	_expect_float(maxf(rendered_size.x, rendered_size.y), expected_diameter, \
		"표시 크기는 공 지름과 일치해야 한다.")


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
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
		print("PASS: pinball_size_test")
		quit(0)
		return

	print("FAIL: pinball_size_test (%d failures)" % _failures.size())
	quit(1)
