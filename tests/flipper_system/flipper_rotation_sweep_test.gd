extends SceneTree


const EPSILON := 0.001
const BASE_BALL_SCENE_PATH := "res://resources/balls/base/base_ball.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_right.tscn"
const START_ROTATION := -PI / 4.0
const END_ROTATION := PI / 4.0
const BALL_CENTER := Vector2(80.0, 0.0)
const BALL_RADIUS := 6.0


var _failures: Array[String] = []
var _last_parry_event: Dictionary = {}
var _duplicate_parry_signal_count := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flipper := _create_test_flipper()
	root.add_child(flipper)
	await process_frame

	var required_methods := [
		&"get_rotation_sweep_step_count",
		&"is_circle_overlapping_at_rotation",
		&"find_rotation_sweep_hit",
		&"resolve_rotation_sweep",
		&"calculate_physical_sweep_velocity",
		&"calculate_contact_position_percent",
		&"get_contact_zone",
		&"get_contact_zone_speed_multiplier",
		&"apply_contact_zone_speed_multiplier",
		&"apply_contact_zone_angle_correction",
		&"get_parry_grade",
		&"get_parry_speed_multiplier",
		&"apply_parry_speed_multiplier",
		&"get_parry_maximum_speed",
		&"apply_parry_maximum_speed",
	]

	for method_name: StringName in required_methods:
		_expect(flipper.has_method(method_name), \
			"회전 구간 검사를 위한 %s API가 필요하다." % method_name)

	var interval_property := _find_property(flipper, &"rotation_sweep_interval")
	_expect(not interval_property.is_empty(), \
		"Rotation Sweep Interval은 Inspector에서 조정할 수 있어야 한다.")

	if _failures.is_empty():
		_test_physical_sweep_reflection(flipper)
		_test_contact_position_percent(flipper)
		_test_contact_zone_boundaries(flipper)
		_test_contact_zone_speed_multipliers(flipper)
		_test_step_count(flipper)
		_test_middle_angle_detection(flipper)
		_test_sweep_contact_geometry(flipper)
		_test_final_angle_detection(flipper)
		await _test_swept_ball_resolution(flipper)
		await _test_rotation_sweep_applies_timed_parry(flipper)
		await _test_same_frame_sweep_is_resolved_once(flipper)
		await _test_swept_ball_velocity_is_mass_independent(flipper)
		await _test_final_overlap_uses_sweep_impulse(flipper)
		await _test_active_state_runs_rotation_sweep(flipper)
		await _test_actual_right_flipper_catches_falling_ball()
		await _test_pinball_registration()

	flipper.queue_free()
	await process_frame
	_finish()


func _test_physical_sweep_reflection(flipper: PinballFlipper) -> void:
	var upward_normal := Vector2.UP
	var incoming_velocity := Vector2(200.0, 400.0)
	var stationary_result: Vector2 = flipper.call(
		&"calculate_physical_sweep_velocity",
		incoming_velocity,
		Vector2.ZERO,
		upward_normal,
		1.0
	)
	_expect_vector(stationary_result, Vector2(200.0, -400.0), \
		"정지한 표면에서는 입사 속도를 충돌 법선 기준으로 물리 반사해야 한다.")

	var upward_surface_velocity := Vector2(0.0, -100.0)
	var moving_result: Vector2 = flipper.call(
		&"calculate_physical_sweep_velocity",
		incoming_velocity,
		upward_surface_velocity,
		upward_normal,
		1.0
	)
	_expect_vector(moving_result, Vector2(200.0, -600.0), \
		"움직이는 플리퍼 표면은 상대 속도 반사를 통해 공에 추가 속도를 전달해야 한다.")
	_expect(absf(moving_result.x - incoming_velocity.x) <= EPSILON, \
		"플리퍼 타격이 공의 기존 횡방향 속도 성분을 임의의 고정 방향으로 덮어쓰면 안 된다.")


func _test_contact_position_percent(flipper: PinballFlipper) -> void:
	_expect_float(
		flipper.calculate_contact_position_percent(Vector2.ZERO, 0.0),
		0.0,
		"회전축 접촉 위치는 0%여야 한다."
	)
	_expect_float(
		flipper.calculate_contact_position_percent(Vector2(50.0, 0.0), 0.0),
		50.0,
		"플리퍼 중앙 접촉 위치는 50%여야 한다."
	)
	_expect_float(
		flipper.calculate_contact_position_percent(Vector2(100.0, 0.0), 0.0),
		100.0,
		"중앙 갭 방향 끝 접촉 위치는 100%여야 한다."
	)
	_expect_float(
		flipper.calculate_contact_position_percent(Vector2(150.0, 0.0), 0.0),
		100.0,
		"플리퍼 끝을 벗어난 접촉 위치는 100%로 제한되어야 한다."
	)


func _test_contact_zone_boundaries(flipper: PinballFlipper) -> void:
	var cases := [
		[0.0, PinballFlipper.ContactZone.A],
		[34.99, PinballFlipper.ContactZone.A],
		[35.0, PinballFlipper.ContactZone.B],
		[69.99, PinballFlipper.ContactZone.B],
		[70.0, PinballFlipper.ContactZone.C],
		[89.99, PinballFlipper.ContactZone.C],
		[90.0, PinballFlipper.ContactZone.D],
		[100.0, PinballFlipper.ContactZone.D],
	]

	for test_case: Array in cases:
		var percent := float(test_case[0])
		var expected_zone := int(test_case[1])
		_expect(
			flipper.get_contact_zone(percent) == expected_zone,
			"접촉 위치 %.2f%%의 구역 판정이 기획서 경계와 일치해야 한다. " \
			+ "(expected=%s, actual=%s)" % [
				expected_zone,
				flipper.get_contact_zone(percent),
			]
		)


func _test_contact_zone_speed_multipliers(flipper: PinballFlipper) -> void:
	var cases := [
		[PinballFlipper.ContactZone.A, 0.94],
		[PinballFlipper.ContactZone.B, 1.0],
		[PinballFlipper.ContactZone.C, 1.08],
		[PinballFlipper.ContactZone.D, 0.84],
	]
	var physical_reflection := Vector2(300.0, -400.0)

	for test_case: Array in cases:
		var zone := int(test_case[0])
		var expected_multiplier := float(test_case[1])
		_expect_float(
			flipper.get_contact_zone_speed_multiplier(zone),
			expected_multiplier,
			"각 접촉 구역은 기획된 기본 속도 배율을 반환해야 한다."
		)
		var result: Vector2 = flipper.apply_contact_zone_speed_multiplier(
			physical_reflection,
			zone
		)
		_expect_float(
			result.length(),
			physical_reflection.length() * expected_multiplier,
			"구역 배율은 물리 반사 결과의 속력에 적용되어야 한다."
		)
		_expect_vector(
			result.normalized(),
			physical_reflection.normalized(),
			"구역 속도 배율은 반사 방향을 변경하면 안 된다."
		)


func _create_test_flipper() -> PinballFlipper:
	var flipper := PinballFlipper.new()
	flipper.name = "SweepTestFlipper"
	flipper.flipper_length = 100.0

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture := GradientTexture2D.new()
	texture.width = 100
	texture.height = 20
	sprite.texture = texture
	flipper.add_child(sprite)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = PackedVector2Array([
		Vector2(0.0, -5.0),
		Vector2(100.0, -5.0),
		Vector2(100.0, 5.0),
		Vector2(0.0, 5.0),
	])
	flipper.add_child(collision)
	return flipper


func _test_step_count(flipper: PinballFlipper) -> void:
	flipper.set(&"rotation_sweep_interval", 8.0)
	var step_count := int(flipper.call(
		&"get_rotation_sweep_step_count",
		START_ROTATION,
		END_ROTATION
	))
	_expect(step_count > 1, \
		"플리퍼 끝이 안전 간격보다 멀리 움직이면 회전 구간을 여러 번 검사해야 한다.")


func _test_middle_angle_detection(flipper: PinballFlipper) -> void:
	var overlaps_start := bool(flipper.call(
		&"is_circle_overlapping_at_rotation",
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION
	))
	var overlaps_end := bool(flipper.call(
		&"is_circle_overlapping_at_rotation",
		BALL_CENTER,
		BALL_RADIUS,
		END_ROTATION
	))
	var hit := flipper.call(
		&"find_rotation_sweep_hit",
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	) as Dictionary

	_expect(not overlaps_start and not overlaps_end, \
		"테스트 공은 시작 및 최종 각도의 콜라이더 밖에 있어야 한다.")
	_expect(not hit.is_empty(), \
		"시작과 최종 각도 사이에 있는 공을 회전 구간 검사로 발견해야 한다.")
	if not hit.is_empty():
		var hit_rotation := float(hit.get(&"rotation", START_ROTATION))
		_expect(hit_rotation > START_ROTATION and hit_rotation < END_ROTATION, \
			"충돌 각도는 시작과 최종 각도 사이여야 한다.")


func _test_sweep_contact_geometry(flipper: PinballFlipper) -> void:
	var hit := flipper.find_rotation_sweep_hit(
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	)
	_expect(hit.has(&"point"), \
		"회전 구간 충돌 결과에 플리퍼 표면 접촉점이 필요하다.")
	_expect(hit.has(&"normal"), \
		"회전 구간 충돌 결과에 물리 반사용 충돌 법선이 필요하다.")
	_expect(hit.has(&"contact_percent"), \
		"회전 구간 충돌 결과에 0~100% 접촉 위치가 필요하다.")
	_expect(hit.has(&"contact_zone"), \
		"회전 구간 충돌 결과에 A/B/C/D 접촉 구역이 필요하다.")
	if (
		not hit.has(&"point")
		or not hit.has(&"normal")
		or not hit.has(&"contact_percent")
		or not hit.has(&"contact_zone")
	):
		return

	var contact_point: Vector2 = hit.get(&"point")
	var contact_normal: Vector2 = hit.get(&"normal")
	_expect(absf(contact_normal.length() - 1.0) <= EPSILON, \
		"회전 구간 충돌 법선은 단위 벡터여야 한다.")
	_expect((BALL_CENTER - contact_point).dot(contact_normal) > 0.0, \
		"충돌 법선은 플리퍼 표면에서 공 중심을 향하는 바깥 방향이어야 한다.")
	var contact_percent := float(hit.get(&"contact_percent"))
	_expect(contact_percent >= 0.0 and contact_percent <= 100.0, \
		"회전 충돌의 접촉 위치는 0~100% 범위여야 한다.")
	_expect(
		int(hit.get(&"contact_zone")) == flipper.get_contact_zone(contact_percent),
		"회전 충돌의 A/B/C/D 구역은 접촉 위치 경계와 일치해야 한다."
	)


func _test_final_angle_detection(flipper: PinballFlipper) -> void:
	var final_only_center := Vector2(70.0, 70.0)
	var small_radius := 1.0
	var overlaps_start := flipper.is_circle_overlapping_at_rotation(
		final_only_center,
		small_radius,
		START_ROTATION
	)
	var overlaps_end := flipper.is_circle_overlapping_at_rotation(
		final_only_center,
		small_radius,
		END_ROTATION
	)
	var hit := flipper.find_rotation_sweep_hit(
		final_only_center,
		small_radius,
		START_ROTATION,
		END_ROTATION
	)

	_expect(not overlaps_start and overlaps_end, \
		"테스트 원은 시작 각도 밖, 최종 각도 안에 있어야 한다.")
	_expect(not hit.is_empty(), \
		"빠른 회전은 최종 각도에서 처음 겹친 공도 회전 검사로 발견해야 한다.")
	if not hit.is_empty():
		_expect(absf(float(hit.get(&"progress", 0.0)) - 1.0) <= EPSILON, \
			"최종 각도 충돌의 진행도는 1이어야 한다.")


func _test_swept_ball_resolution(flipper: PinballFlipper) -> void:
	var ball := RigidBody2D.new()
	ball.name = "SweepTestBall"
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")

	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = 1.0
	ball.physics_material_override = physics_material
	root.add_child(ball)
	await physics_frame

	ball.global_position = BALL_CENTER
	var incoming_velocity := Vector2(40.0, 80.0)
	ball.linear_velocity = incoming_velocity
	flipper.rotation = END_ROTATION
	_expect(ball.is_in_group(&"pinball_balls"), \
		"테스트 공이 회전 구간 검사 그룹에 등록되어야 한다.")
	_expect(ball_collision.global_position.is_equal_approx(BALL_CENTER), \
		"테스트 공의 충돌 중심이 의도한 중간 각도 위치에 있어야 한다. " \
		+ "(expected=%s, actual=%s)" % [BALL_CENTER, ball_collision.global_position])
	var direct_hit := flipper.call(
		&"find_rotation_sweep_hit",
		ball_collision.global_position,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	) as Dictionary
	_expect(not direct_hit.is_empty(), \
		"실제 공의 전역 충돌 중심으로도 중간 회전 충돌을 찾을 수 있어야 한다.")
	var contact_point: Vector2 = direct_hit.get(&"point", Vector2.ZERO)
	var contact_normal: Vector2 = direct_hit.get(&"normal", Vector2.ZERO)
	var original_parry_rules := flipper.parry_rules
	var angle_rules := FlipperParryRules.new()
	for zone_name: String in ["a", "b", "c", "d"]:
		angle_rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			true
		)
		angle_rules.set(
			StringName("zone_%s_angle_correction_degrees" % zone_name),
			10.0
		)
	flipper.set_parry_rules(angle_rules)
	var angular_velocity := (END_ROTATION - START_ROTATION) / (1.0 / 60.0)
	var radial_vector := contact_point - flipper.global_position
	var surface_velocity := Vector2(-radial_vector.y, radial_vector.x) \
		* angular_velocity
	var expected_velocity := flipper.calculate_physical_sweep_velocity(
		incoming_velocity,
		surface_velocity,
		contact_normal,
		physics_material.bounce
	)
	expected_velocity = flipper.apply_contact_zone_speed_multiplier(
		expected_velocity,
		int(direct_hit.get(&"contact_zone", PinballFlipper.ContactZone.B))
	)
	expected_velocity = flipper.apply_contact_zone_angle_correction(
		expected_velocity,
		int(direct_hit.get(&"contact_zone", PinballFlipper.ContactZone.B))
	)
	expected_velocity = flipper.apply_parry_maximum_speed(
		expected_velocity,
		0
	)
	var resolved_count := int(flipper.call(
		&"resolve_rotation_sweep",
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0
	))

	_expect(resolved_count == 1, \
		"회전 구간 안의 공 한 개를 감지해야 한다.")
	_expect(ball.global_position.is_equal_approx(BALL_CENTER), \
		"회전 구간 충돌은 RigidBody2D의 Transform을 직접 이동시키면 안 된다. " \
		+ "(expected=%s, actual=%s)" % [BALL_CENTER, ball.global_position])
	await physics_frame
	_expect_vector(ball.linear_velocity, expected_velocity, \
		"회전 안전 충돌은 속도 배율과 각도 보정까지 반영한 임펄스를 적용해야 한다.")

	flipper.set_parry_rules(original_parry_rules)
	ball.queue_free()
	await process_frame


func _test_rotation_sweep_applies_timed_parry(
	flipper: PinballFlipper
) -> void:
	var ball := _create_impulse_test_ball("TimedParryBall", 1.0)
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")
	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await physics_frame

	var rules := FlipperParryRules.new()
	for zone_name: String in ["a", "b", "c", "d"]:
		rules.set(StringName("zone_%s_speed_multiplier" % zone_name), 1.0)
		rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			false
		)
	rules.normal_parry_window_time = 0.095
	rules.perfect_parry_window_time = 0.042
	rules.normal_parry_speed_multiplier = 1.08
	rules.perfect_parry_speed_multiplier = 1.18
	rules.normal_maximum_speed = 1540.0
	rules.perfect_parry_maximum_speed = 1700.0
	var original_rules := flipper.parry_rules
	flipper.set_parry_rules(rules)

	var incoming_velocity := Vector2(40.0, 80.0)
	ball.global_position = BALL_CENTER
	ball.linear_velocity = incoming_velocity
	var hit := flipper.find_rotation_sweep_hit(
		BALL_CENTER,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	)
	_expect(not hit.is_empty(), "시간 패링 테스트 공은 회전 궤도 안에 있어야 한다.")
	if hit.is_empty():
		flipper.set_parry_rules(original_rules)
		ball.queue_free()
		await process_frame
		return

	var hit_point: Vector2 = hit.get(&"point", BALL_CENTER)
	var hit_normal: Vector2 = hit.get(&"normal", Vector2.UP)
	var angular_velocity := (END_ROTATION - START_ROTATION) / (1.0 / 60.0)
	var radial_vector := hit_point - flipper.global_position
	var surface_velocity := Vector2(-radial_vector.y, radial_vector.x) \
		* angular_velocity
	var unbounded_velocity := flipper.calculate_physical_sweep_velocity(
		incoming_velocity,
		surface_velocity,
		hit_normal,
		1.0
	) * 1.08
	var expected_velocity := unbounded_velocity.normalized() * minf(
		unbounded_velocity.length(),
		1540.0
	)

	_last_parry_event.clear()
	_expect(flipper.has_signal(&"parry_resolved"), \
		"플리퍼는 일반·정확 패링 결과를 연출과 UI에 전달하는 신호가 필요하다.")
	if flipper.has_signal(&"parry_resolved"):
		flipper.connect(&"parry_resolved", _on_test_parry_resolved, CONNECT_ONE_SHOT)

	var resolved_count := int(flipper.call(
		&"resolve_rotation_sweep",
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0,
		0.05
	))
	_expect(resolved_count == 1, "일반 패링 시간의 회전 충돌을 한 번 해결해야 한다.")
	await physics_frame
	_expect_vector(ball.linear_velocity, expected_velocity, \
		"일반 패링 1.08배는 물리 반사와 구역 계산 뒤 최종 속력에 적용되어야 한다.")
	_expect(int(_last_parry_event.get(&"grade", -1)) == 1, \
		"정확 판정 이후 일반 판정 안의 충돌은 NORMAL 등급을 알려야 한다.")
	_expect_float(float(_last_parry_event.get(&"multiplier", 0.0)), 1.08, \
		"패링 결과 신호에는 실제 적용한 속도 배율이 포함되어야 한다.")
	var elapsed := float(_last_parry_event.get(&"elapsed_time", -1.0))
	_expect(elapsed > 0.05 and elapsed <= 0.095, \
		"패링 판정은 물리 프레임 끝이 아니라 회전 구간 안 실제 접촉 시각을 사용해야 한다.")

	flipper.set_parry_rules(original_rules)
	ball.queue_free()
	await process_frame


func _test_same_frame_sweep_is_resolved_once(
	flipper: PinballFlipper
) -> void:
	var ball := _create_impulse_test_ball("DuplicateGuardBall", 1.0)
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")
	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await physics_frame

	ball.global_position = BALL_CENTER
	ball.linear_velocity = Vector2(40.0, 80.0)
	_duplicate_parry_signal_count = 0
	if not flipper.parry_resolved.is_connected(_count_duplicate_parry_signal):
		flipper.parry_resolved.connect(_count_duplicate_parry_signal)

	var first_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0,
		0.0
	)
	var second_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0,
		0.0
	)
	_expect(first_count == 1, \
		"동일 물리 프레임의 첫 회전 충돌은 정상적으로 해결해야 한다.")
	_expect(second_count == 0, \
		"같은 공의 동일 물리 프레임 충돌은 두 번째 임펄스를 적용하면 안 된다.")
	_expect(_duplicate_parry_signal_count == 1, \
		"동일 충돌의 패링 결과와 피드백 신호도 한 번만 발생해야 한다.")

	if flipper.parry_resolved.is_connected(_count_duplicate_parry_signal):
		flipper.parry_resolved.disconnect(_count_duplicate_parry_signal)
	ball.queue_free()
	await process_frame


func _count_duplicate_parry_signal(
	_ball: RigidBody2D,
	_grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_multiplier: float
) -> void:
	_duplicate_parry_signal_count += 1


func _on_test_parry_resolved(
	_ball: RigidBody2D,
	grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	elapsed_time: float,
	multiplier: float
) -> void:
	_last_parry_event = {
		&"grade": grade,
		&"elapsed_time": elapsed_time,
		&"multiplier": multiplier,
	}


func _test_final_overlap_uses_sweep_impulse(
	flipper: PinballFlipper
) -> void:
	var final_only_center := Vector2(70.0, 70.0)
	var ball := RigidBody2D.new()
	ball.name = "FinalContactBall"
	ball.gravity_scale = 0.0
	ball.position = final_only_center
	ball.add_to_group(&"pinball_balls")

	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 1.0
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)

	_expect(flipper.is_circle_overlapping_at_rotation(
		final_only_center,
		circle.radius,
		END_ROTATION
	), "최종 각도의 일반 물리 접촉을 검증할 공이 플리퍼와 겹쳐야 한다.")
	var resolved_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0
	)
	_expect(resolved_count == 1, \
		"큰 회전으로 최종 각도까지 겹친 공도 회전 안전 임펄스로 놓치지 않아야 한다.")
	_expect(ball.global_position.is_equal_approx(final_only_center), \
		"최종 각도 접촉도 회전 검사에서 Transform을 직접 이동시키면 안 된다.")

	ball.queue_free()
	await process_frame


func _test_swept_ball_velocity_is_mass_independent(
	flipper: PinballFlipper
) -> void:
	var light_ball := _create_impulse_test_ball("LightBall", 1.0)
	var heavy_ball := _create_impulse_test_ball("HeavyBall", 4.0)
	root.add_child(light_ball)
	root.add_child(heavy_ball)
	await physics_frame

	var hit_point := Vector2(75.0, 0.0)
	var hit_normal := Vector2.UP
	var incoming_velocity := Vector2(100.0, 300.0)
	light_ball.linear_velocity = incoming_velocity
	heavy_ball.linear_velocity = incoming_velocity
	await physics_frame

	flipper.call(
		&"_resolve_swept_ball",
		light_ball,
		hit_point,
		hit_normal,
		PinballFlipper.ContactZone.C,
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0
	)
	flipper.call(
		&"_resolve_swept_ball",
		heavy_ball,
		hit_point,
		hit_normal,
		PinballFlipper.ContactZone.C,
		START_ROTATION,
		END_ROTATION,
		1.0 / 60.0
	)
	await physics_frame

	_expect_vector(
		heavy_ball.linear_velocity,
		light_ball.linear_velocity,
		"질량은 필요한 임펄스만 바꾸고 같은 충돌의 목표 반사 속도는 바꾸면 안 된다."
	)

	light_ball.queue_free()
	heavy_ball.queue_free()
	await process_frame


func _create_impulse_test_ball(ball_name: String, ball_mass: float) -> RigidBody2D:
	var ball := RigidBody2D.new()
	ball.name = ball_name
	ball.mass = ball_mass
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.collision_layer = 0
	ball.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = 1.0
	ball.physics_material_override = material
	return ball


func _test_pinball_registration() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")
	if ball_scene == null:
		return

	var ball := ball_scene.instantiate() as RigidBody2D
	root.add_child(ball)
	await process_frame
	_expect(ball.is_in_group(&"pinball_balls"), \
		"Pinball은 회전 구간 검사가 찾을 수 있도록 pinball_balls 그룹에 등록되어야 한다.")
	ball.queue_free()
	await process_frame


func _test_active_state_runs_rotation_sweep(flipper: PinballFlipper) -> void:
	var ball := RigidBody2D.new()
	ball.name = "ActiveSweepTestBall"
	ball.gravity_scale = 0.0
	ball.position = BALL_CENTER
	ball.add_to_group(&"pinball_balls")

	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await process_frame

	var rules := FlipperStateRules.new()
	rules.activation_time = 0.01
	flipper.initial_angle_degrees = rad_to_deg(START_ROTATION)
	flipper.maximum_angle_degrees = rad_to_deg(END_ROTATION)
	flipper.set_state_rules(rules)
	ball.global_position = BALL_CENTER
	ball.linear_velocity = Vector2.ZERO
	var direct_hit := flipper.find_rotation_sweep_hit(
		ball_collision.global_position,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	)
	_expect(not direct_hit.is_empty(), \
		"ACTIVE 상태 시작 직전에도 공이 중간 회전 구간 안에 있어야 한다.")

	var activated := flipper.request_activation()
	_expect(activated, "대기 상태 플리퍼가 자동 회전 구간 테스트를 시작할 수 있어야 한다.")
	await physics_frame
	# SceneTree.physics_frame 신호는 노드의 _physics_process보다 먼저 발생합니다.
	await physics_frame

	_expect(not ball.global_position.is_equal_approx(BALL_CENTER), \
		"ACTIVE 상태의 실제 물리 갱신이 회전 구간 안의 공을 자동으로 분리해야 한다.")
	_expect(ball.linear_velocity.length() > EPSILON, \
		"ACTIVE 상태의 실제 물리 갱신이 공에 표면 속도를 전달해야 한다.")

	ball.queue_free()
	await process_frame


func _test_actual_right_flipper_catches_falling_ball() -> void:
	var packed_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "실제 오른쪽 플리퍼 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		return

	var flipper := packed_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	await process_frame

	var start_rotation := deg_to_rad(-45.0)
	var end_rotation := deg_to_rad(45.0)
	var ball_radius := 57.6
	var falling_ball_center := flipper.global_position + Vector2(-400.0, 0.0)
	_expect(not flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		start_rotation
	), "실제 테스트 공은 오른쪽 플리퍼 초기 각도 밖에 있어야 한다.")
	_expect(not flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		end_rotation
	), "실제 테스트 공은 오른쪽 플리퍼 최대 각도 밖에 있어야 한다.")
	_expect(flipper.is_circle_overlapping_at_rotation(
		falling_ball_center,
		ball_radius,
		0.0
	), "실제 테스트 공은 오른쪽 플리퍼의 중간 회전 궤도 안에 있어야 한다.")

	var ball := RigidBody2D.new()
	ball.name = "ActualRightFlipperTestBall"
	ball.gravity_scale = 0.0
	ball.global_position = falling_ball_center
	ball.linear_velocity = Vector2(0.0, 400.0)
	ball.add_to_group(&"pinball_balls")
	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = ball_radius
	ball_collision.shape = circle
	ball.add_child(ball_collision)
	root.add_child(ball)
	await process_frame

	var rules := FlipperStateRules.new()
	rules.activation_time = 0.01
	flipper.initial_angle_degrees = -45.0
	flipper.maximum_angle_degrees = 45.0
	flipper.set_state_rules(rules)
	ball.global_position = falling_ball_center
	ball.linear_velocity = Vector2(0.0, 400.0)
	_expect(flipper.request_activation(), \
		"실제 오른쪽 플리퍼가 ACTIVE 상태로 진입할 수 있어야 한다.")
	await physics_frame
	await physics_frame

	_expect(ball.linear_velocity.y < 0.0, \
		"중간 궤도의 낙하 공은 오른쪽 플리퍼를 통과하지 않고 위로 타격되어야 한다.")

	ball.queue_free()
	flipper.queue_free()
	await process_frame


func _find_property(object: Object, property_name: StringName) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return property

	return {}


func _expect_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_rotation_sweep_test")
		quit(0)
		return

	print("FAIL: flipper_rotation_sweep_test (%d failures)" % _failures.size())
	quit(1)
