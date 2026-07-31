extends SceneTree

const LEFT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_left.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_right.tscn"
const CONTROLLER_SCENE_PATH := \
	"res://resources/flippers/flipper/flipper_controller_sample.tscn"
const EXPECTED_DEFAULT_LENGTH := 1552.0
const EXPECTED_MINIMUM_LENGTH := 64.0
const EXPECTED_MAXIMUM_LENGTH := 4096.0
const EPSILON := 0.001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var left_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	var right_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(left_scene != null, "왼쪽 플리퍼 씬을 불러올 수 있어야 한다.")
	_expect(right_scene != null, "오른쪽 플리퍼 씬을 불러올 수 있어야 한다.")

	if left_scene == null or right_scene == null:
		_finish()
		return

	var left_flipper := left_scene.instantiate() as PinballFlipper
	var right_flipper := right_scene.instantiate() as PinballFlipper
	root.add_child(left_flipper)
	root.add_child(right_flipper)
	await process_frame

	_test_required_node_contract(left_flipper)
	_test_editor_property_contract(left_flipper)
	_test_default_length(left_flipper)
	_test_scaled_geometry(left_flipper, 776.0)
	_test_scaled_geometry(right_flipper, 776.0)
	_test_length_clamp(left_flipper)
	_test_instances_keep_independent_sizes(left_scene, left_flipper)
	await _test_export_value_applies_after_children_are_restored()
	await _test_controller_instance_overrides_are_applied()
	_test_missing_nodes_are_reported_safely()

	left_flipper.queue_free()
	right_flipper.queue_free()
	await process_frame
	_finish()


func _test_required_node_contract(flipper: PinballFlipper) -> void:
	_expect(flipper.get_node_or_null("Sprite2D") is Sprite2D, \
		"플리퍼에는 Sprite2D 자식 노드가 필요하다.")
	_expect(flipper.get_node_or_null("CollisionPolygon2D") is CollisionPolygon2D, \
		"플리퍼에는 CollisionPolygon2D 자식 노드가 필요하다.")


func _test_editor_property_contract(flipper: PinballFlipper) -> void:
	var length_property := _find_property(flipper, &"flipper_length")
	_expect(not length_property.is_empty(), \
		"플리퍼 길이는 에디터에서 편집 가능한 속성이어야 한다.")

	if length_property.is_empty():
		return

	var usage := int(length_property.get("usage", 0))
	var hint_string := str(length_property.get("hint_string", ""))
	_expect((usage & PROPERTY_USAGE_EDITOR) != 0, \
		"Flipper Length는 Inspector에 표시되어야 한다.")
	_expect(hint_string.begins_with("64.0,4096.0"), \
		"Inspector의 플리퍼 길이 범위는 64~4096px이어야 한다.")


func _test_default_length(flipper: PinballFlipper) -> void:
	if not _has_property(flipper, &"flipper_length"):
		_expect(false, "PinballFlipper는 flipper_length 속성을 제공해야 한다.")
		return

	_expect_float(float(flipper.get(&"flipper_length")), EXPECTED_DEFAULT_LENGTH, \
		"기본 플리퍼 길이는 원본 이미지 길이인 1552px이어야 한다.")
	_expect_geometry_scale(
		flipper,
		EXPECTED_DEFAULT_LENGTH / _get_source_length(flipper)
	)


func _test_scaled_geometry(flipper: PinballFlipper, target_length: float) -> void:
	if not _has_property(flipper, &"flipper_length"):
		return

	var sprite := flipper.get_node("Sprite2D") as Sprite2D
	var collision := flipper.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var source_polygon := collision.polygon.duplicate()
	var source_sprite_offset := sprite.offset
	var orientation := Vector2(
		_sign_or_one(collision.scale.x),
		_sign_or_one(collision.scale.y)
	)
	var scale_factor := target_length / _get_source_length(flipper)

	flipper.set(&"flipper_length", target_length)
	flipper.call(&"refresh_flipper_size")

	_expect_vector(sprite.scale, Vector2.ONE * scale_factor, \
		"Sprite2D 크기는 설정한 플리퍼 길이에 맞아야 한다.")
	_expect_vector(collision.scale, orientation * scale_factor, \
		"충돌 폴리곤 크기는 좌우 방향을 보존하며 같은 비율로 조절되어야 한다.")
	_expect_vector(collision.position, source_sprite_offset * scale_factor, \
		"충돌 폴리곤 위치는 피벗에서 같은 비율로 이동해야 한다.")
	_expect(collision.polygon == source_polygon, \
		"크기 변경은 원본 폴리곤 점 데이터를 훼손하지 않아야 한다.")

	var rendered_size := sprite.texture.get_size() * sprite.scale.abs()
	_expect_float(maxf(rendered_size.x, rendered_size.y), target_length, \
		"렌더링된 플리퍼의 긴 변은 설정 길이와 같아야 한다.")


func _test_length_clamp(flipper: PinballFlipper) -> void:
	if not _has_property(flipper, &"flipper_length"):
		return

	flipper.set(&"flipper_length", 1.0)
	_expect_float(float(flipper.get(&"flipper_length")), EXPECTED_MINIMUM_LENGTH, \
		"플리퍼 길이는 64px보다 작아질 수 없다.")
	_expect_geometry_scale(
		flipper,
		EXPECTED_MINIMUM_LENGTH / _get_source_length(flipper)
	)

	flipper.set(&"flipper_length", 10000.0)
	_expect_float(float(flipper.get(&"flipper_length")), EXPECTED_MAXIMUM_LENGTH, \
		"플리퍼 길이는 4096px보다 커질 수 없다.")
	_expect_geometry_scale(
		flipper,
		EXPECTED_MAXIMUM_LENGTH / _get_source_length(flipper)
	)

	flipper.set(&"flipper_length", EXPECTED_DEFAULT_LENGTH)


func _test_instances_keep_independent_sizes(
	packed_scene: PackedScene,
	first_flipper: PinballFlipper
) -> void:
	if not _has_property(first_flipper, &"flipper_length"):
		return

	var second_flipper := packed_scene.instantiate() as PinballFlipper
	root.add_child(second_flipper)

	first_flipper.set(&"flipper_length", 776.0)
	second_flipper.set(&"flipper_length", 2328.0)

	_expect_geometry_scale(first_flipper, 776.0 / _get_source_length(first_flipper))
	_expect_geometry_scale(second_flipper, 2328.0 / _get_source_length(second_flipper))

	first_flipper.set(&"flipper_length", EXPECTED_DEFAULT_LENGTH)
	second_flipper.free()


func _test_export_value_applies_after_children_are_restored() -> void:
	var delayed_flipper := PinballFlipper.new()
	delayed_flipper.set(&"flipper_length", 776.0)

	var delayed_sprite := Sprite2D.new()
	delayed_sprite.name = "Sprite2D"
	delayed_sprite.offset = Vector2(565.0, 0.0)
	var texture := GradientTexture2D.new()
	texture.width = 1552
	texture.height = 442
	delayed_sprite.texture = texture
	delayed_flipper.add_child(delayed_sprite)

	var delayed_collision := CollisionPolygon2D.new()
	delayed_collision.name = "CollisionPolygon2D"
	delayed_collision.polygon = PackedVector2Array([
		Vector2(-100.0, -20.0),
		Vector2(100.0, -20.0),
		Vector2(100.0, 20.0),
		Vector2(-100.0, 20.0),
	])
	delayed_collision.position = Vector2(565.0, 0.0)
	delayed_flipper.add_child(delayed_collision)

	await process_frame
	_expect_vector(delayed_sprite.scale, Vector2(0.5, 0.5), \
		"export 값이 자식보다 먼저 복원돼도 Sprite2D 크기를 나중에 적용해야 한다.")
	_expect_vector(delayed_collision.scale, Vector2(0.5, 0.5), \
		"export 값이 자식보다 먼저 복원돼도 충돌 크기를 나중에 적용해야 한다.")
	_expect_vector(delayed_collision.position, Vector2(282.5, 0.0), \
		"export 값이 자식보다 먼저 복원돼도 충돌 위치를 나중에 적용해야 한다.")

	delayed_flipper.free()


func _test_controller_instance_overrides_are_applied() -> void:
	var controller_scene := load(CONTROLLER_SCENE_PATH) as PackedScene
	_expect(controller_scene != null, "플리퍼 컨트롤러 씬을 불러올 수 있어야 한다.")

	if controller_scene == null:
		return

	var controller := controller_scene.instantiate()
	root.add_child(controller)
	await process_frame

	for child: Node in controller.get_children():
		if not child is PinballFlipper:
			continue

		var flipper := child as PinballFlipper
		var expected_factor := (
			float(flipper.get(&"flipper_length"))
			/ _get_source_length(flipper)
		)
		_expect_geometry_scale(flipper, expected_factor)

	controller.free()


func _test_missing_nodes_are_reported_safely() -> void:
	var incomplete_flipper := PinballFlipper.new()
	if not incomplete_flipper.has_method(&"refresh_flipper_size"):
		_expect(false, \
			"PinballFlipper는 필수 노드가 없어도 호출 가능한 크기 갱신 API를 제공해야 한다.")
		incomplete_flipper.free()
		return

	incomplete_flipper.call(&"refresh_flipper_size")
	var warnings := incomplete_flipper._get_configuration_warnings()
	_expect(warnings.size() >= 2, \
		"필수 시각/충돌 노드가 없으면 에디터 구성 경고를 제공해야 한다.")
	incomplete_flipper.free()


func _expect_geometry_scale(flipper: PinballFlipper, expected_factor: float) -> void:
	var sprite := flipper.get_node("Sprite2D") as Sprite2D
	var collision := flipper.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var orientation := Vector2(
		_sign_or_one(collision.scale.x),
		_sign_or_one(collision.scale.y)
	)

	_expect_vector(sprite.scale, Vector2.ONE * expected_factor, \
		"플리퍼 Sprite2D 배율이 올바르지 않다.")
	_expect_vector(collision.scale, orientation * expected_factor, \
		"플리퍼 충돌 폴리곤 배율이 올바르지 않다.")
	_expect_vector(collision.position, sprite.offset * expected_factor, \
		"플리퍼 충돌 폴리곤 위치가 올바르지 않다.")


func _get_source_length(flipper: PinballFlipper) -> float:
	var sprite := flipper.get_node("Sprite2D") as Sprite2D
	var texture_size := sprite.texture.get_size()
	return maxf(absf(texture_size.x), absf(texture_size.y))


func _sign_or_one(value: float) -> float:
	return signf(value) if not is_zero_approx(value) else 1.0


func _has_property(object: Object, property_name: StringName) -> bool:
	return not _find_property(object, property_name).is_empty()


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
		print("PASS: flipper_size_test")
		quit(0)
		return

	print("FAIL: flipper_size_test (%d failures)" % _failures.size())
	quit(1)
