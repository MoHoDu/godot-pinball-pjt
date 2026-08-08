extends SceneTree


const TeddyAttackScene: PackedScene = preload(
	"res://Resources/Prefabs/boss/attacks/teddy_arm_sweep_attack.tscn"
)
const NormalBallScene: PackedScene = preload(
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
)
const ReflectionRulesResource: BossArmBallReflectionRules = preload(
	"res://settings/bosses/TeddyArmBallReflectionRules.tres"
)
const VELOCITY_EPSILON: float = 6.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource_and_validation()
	await _test_configuration_and_binding()
	await _test_invalid_targets_are_ignored()
	await _test_left_hitbox_has_priority_over_position_fallback()
	await _test_right_hitbox_has_priority_over_position_fallback()
	await _test_position_and_velocity_fallbacks_are_deterministic()
	await _test_impulse_replaces_arbitrary_velocity_with_limited_target()
	await _test_sleeping_ball_and_single_connection()
	await _test_unbind_ignores_old_attack()
	_test_responsibility_boundaries()
	_finish()


func _test_rules_resource_and_validation() -> void:
	_expect(ReflectionRulesResource != null,
		"The Teddy reflection Rules Resource must load.")
	_expect(ReflectionRulesResource is BossArmBallReflectionRules,
		"The loaded Resource must use BossArmBallReflectionRules.")
	_expect(ReflectionRulesResource.validate().is_empty(),
		"The authored reflection Rules must be valid.")
	_expect(is_equal_approx(ReflectionRulesResource.reflection_speed, 900.0),
		"The initial reflection speed must be explicitly 900.0.")
	_expect(is_equal_approx(ReflectionRulesResource.outward_ratio, 0.65),
		"The initial outward ratio must be explicitly 0.65.")
	_expect(is_equal_approx(ReflectionRulesResource.downward_ratio, 1.0),
		"The initial downward ratio must be explicitly 1.0.")

	var rules := BossArmBallReflectionRules.new()
	rules.reflection_speed = NAN
	rules.outward_ratio = INF
	rules.downward_ratio = 0.0
	var errors: PackedStringArray = rules.validate()
	_expect(_contains_error(errors, "reflection_speed"),
		"Validation must reject a NAN reflection speed.")
	_expect(_contains_error(errors, "outward_ratio"),
		"Validation must reject an infinite outward ratio.")
	_expect(_contains_error(errors, "downward_ratio"),
		"Validation must reject a non-positive downward ratio.")
	rules.reflection_speed = -1.0
	rules.outward_ratio = -1.0
	rules.downward_ratio = -1.0
	_expect(rules.validate().size() == 3,
		"Validation must collect every non-positive field error.")


func _test_configuration_and_binding() -> void:
	var reflector := BossArmBallReflector.new()
	root.add_child(reflector)
	var invalid_rules := BossArmBallReflectionRules.new()
	invalid_rules.reflection_speed = 0.0
	var attack: TeddyArmSweepAttack = await _create_attack()

	_expect(not reflector.configure(null), "Null Rules must be rejected.")
	_expect(not reflector.configure(invalid_rules),
		"Invalid Rules must be rejected.")
	_expect(reflector.configure(ReflectionRulesResource),
		"Valid authored Rules must configure the Reflector.")
	_expect(not reflector.configure(invalid_rules),
		"A failed reconfiguration must preserve valid configuration.")
	_expect(not reflector.bind_attack(null), "A null Attack must be rejected.")
	_expect(reflector.bind_attack(attack), "A live Teddy Attack must bind.")
	_expect(reflector.is_bound(), "Successful binding must be observable.")
	var connection_count: int = _count_connections_to(attack, reflector)
	_expect(connection_count == 1,
		"Reflector must create exactly one attack_hit connection.")
	_expect(reflector.bind_attack(attack),
		"Binding the same Attack must be idempotent.")
	_expect(_count_connections_to(attack, reflector) == 1,
		"Idempotent binding must not duplicate the connection.")

	_expect(not reflector.bind_attack(null),
		"An invalid replacement Attack must be rejected.")
	_expect(reflector.is_bound() and _count_connections_to(attack, reflector) == 1,
		"Failed replacement must preserve the valid binding.")
	reflector.unbind_attack()
	_expect(not reflector.is_bound(), "Unbind must remove the binding.")
	reflector.unbind_attack()
	_expect(not reflector.is_bound(), "Repeated unbind must be safe.")

	reflector.queue_free()
	attack.queue_free()
	await process_frame


func _test_invalid_targets_are_ignored() -> void:
	var fixture: Dictionary = await _create_fixture()
	var reflector: BossArmBallReflector = fixture.reflector
	var attack: TeddyArmSweepAttack = fixture.attack
	var ball: Pinball = await _create_ball(Vector2(220.0, 420.0))
	var non_ball := Node2D.new()
	root.add_child(non_ball)
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(360.0, -120.0)
	var original_velocity: Vector2 = ball.linear_velocity
	var reflected_balls: Array[Pinball] = []
	reflector.ball_reflected.connect(func(reflected_ball: Pinball) -> void:
		reflected_balls.append(reflected_ball)
	)

	attack.attack_hit.emit(non_ball)
	_expect(ball.linear_velocity.is_equal_approx(original_velocity),
		"A non-Pinball target must have no Ball side effect.")
	ball.remove_from_group(Pinball.PINBALL_GROUP)
	attack.attack_hit.emit(ball)
	_expect(ball.linear_velocity.is_equal_approx(original_velocity),
		"A Pinball outside pinball_balls must be ignored.")
	_expect(reflected_balls.is_empty(),
		"Invalid reflection targets must not emit ball_reflected.")

	non_ball.queue_free()
	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_left_hitbox_has_priority_over_position_fallback() -> void:
	var fixture: Dictionary = await _create_fixture()
	var attack: TeddyArmSweepAttack = fixture.attack
	attack.left_hit_area.global_position = Vector2(260.0, 0.0)
	attack.right_hit_area.global_position = Vector2(-520.0, 0.0)
	var ball: Pinball = await _create_ball(Vector2(260.0, 0.0))
	ball.gravity_scale = 0.0
	await physics_frame
	await physics_frame
	_expect(attack.left_hit_area.overlaps_body(ball),
		"The actual Left Hitbox must overlap the test Ball.")
	_expect(not attack.right_hit_area.overlaps_body(ball),
		"The actual Right Hitbox must not overlap the Left test Ball.")

	attack.attack_hit.emit(ball)
	await physics_frame
	_expect(ball.linear_velocity.x < 0.0,
		"Left-only overlap must reflect outward to negative X.")
	_expect(ball.linear_velocity.y > 0.0,
		"Left reflection must travel downward in positive Y.")

	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_right_hitbox_has_priority_over_position_fallback() -> void:
	var fixture: Dictionary = await _create_fixture()
	var attack: TeddyArmSweepAttack = fixture.attack
	attack.left_hit_area.global_position = Vector2(520.0, 0.0)
	attack.right_hit_area.global_position = Vector2(-260.0, 0.0)
	var ball: Pinball = await _create_ball(Vector2(-260.0, 0.0))
	ball.gravity_scale = 0.0
	await physics_frame
	await physics_frame
	_expect(not attack.left_hit_area.overlaps_body(ball),
		"The actual Left Hitbox must not overlap the Right test Ball.")
	_expect(attack.right_hit_area.overlaps_body(ball),
		"The actual Right Hitbox must overlap the test Ball.")

	attack.attack_hit.emit(ball)
	await physics_frame
	_expect(ball.linear_velocity.x > 0.0,
		"Right-only overlap must reflect outward to positive X.")
	_expect(ball.linear_velocity.y > 0.0,
		"Right reflection must travel downward in positive Y.")

	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_position_and_velocity_fallbacks_are_deterministic() -> void:
	var fixture: Dictionary = await _create_fixture()
	var attack: TeddyArmSweepAttack = fixture.attack
	attack.left_hit_area.global_position = Vector2(-800.0, -800.0)
	attack.right_hit_area.global_position = Vector2(800.0, -800.0)

	var left_ball: Pinball = await _create_ball(Vector2(-300.0, 500.0))
	var right_ball: Pinball = await _create_ball(Vector2(300.0, 500.0))
	left_ball.gravity_scale = 0.0
	right_ball.gravity_scale = 0.0
	left_ball.global_position = Vector2(-300.0, 500.0)
	right_ball.global_position = Vector2(300.0, 500.0)
	left_ball.linear_velocity = Vector2.ZERO
	right_ball.linear_velocity = Vector2.ZERO
	attack.attack_hit.emit(left_ball)
	attack.attack_hit.emit(right_ball)
	await physics_frame
	await physics_frame
	_expect(left_ball.linear_velocity.x < 0.0 and left_ball.linear_velocity.y > 0.0,
		"Negative Boss-relative X must deterministically choose LEFT.")
	_expect(right_ball.linear_velocity.x > 0.0 and right_ball.linear_velocity.y > 0.0,
		"Positive Boss-relative X must deterministically choose RIGHT.")

	var center_left: Pinball = await _create_ball(Vector2.ZERO)
	var center_right: Pinball = await _create_ball(Vector2.ZERO)
	center_left.gravity_scale = 0.0
	center_right.gravity_scale = 0.0
	center_left.linear_velocity = Vector2(-120.0, 0.0)
	center_right.linear_velocity = Vector2(120.0, 0.0)
	attack.attack_hit.emit(center_left)
	attack.attack_hit.emit(center_right)
	await physics_frame
	_expect(center_left.linear_velocity.x < 0.0,
		"Centered Ball with negative X velocity must choose LEFT.")
	_expect(center_right.linear_velocity.x > 0.0,
		"Centered Ball with positive X velocity must choose RIGHT.")

	left_ball.queue_free()
	right_ball.queue_free()
	center_left.queue_free()
	center_right.queue_free()
	await _destroy_fixture(fixture)


func _test_impulse_replaces_arbitrary_velocity_with_limited_target() -> void:
	var fixture: Dictionary = await _create_fixture()
	var attack: TeddyArmSweepAttack = fixture.attack
	var ball: Pinball = await _create_ball(Vector2(320.0, 500.0))
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(-740.0, -620.0)
	await physics_frame
	var expected_direction := Vector2(
		ReflectionRulesResource.outward_ratio,
		ReflectionRulesResource.downward_ratio
	).normalized()
	var expected_velocity: Vector2 = ball.get_limited_velocity(
		expected_direction * ReflectionRulesResource.reflection_speed
	)

	attack.attack_hit.emit(ball)
	await physics_frame
	await physics_frame
	_expect(ball.linear_velocity.distance_to(expected_velocity) <= VELOCITY_EPSILON,
		"Impulse must replace arbitrary velocity with the limited target velocity.")
	var allowed_velocity: Vector2 = ball.get_limited_velocity(ball.linear_velocity)
	_expect(ball.linear_velocity.distance_to(allowed_velocity) <= VELOCITY_EPSILON,
		"Final speed must remain within the Pinball speed contract.")

	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_sleeping_ball_and_single_connection() -> void:
	var fixture: Dictionary = await _create_fixture()
	var reflector: BossArmBallReflector = fixture.reflector
	var attack: TeddyArmSweepAttack = fixture.attack
	var ball: Pinball = await _create_ball(Vector2(-320.0, 500.0))
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2.ZERO
	await physics_frame
	ball.sleeping = true
	var reflected_balls: Array[Pinball] = []
	reflector.ball_reflected.connect(func(reflected_ball: Pinball) -> void:
		reflected_balls.append(reflected_ball)
	)
	_expect(_count_connections_to(attack, reflector) == 1,
		"One attack_hit must reach Reflector through one connection.")

	attack.attack_hit.emit(ball)
	_expect(not ball.sleeping, "Reflection must wake a sleeping Ball.")
	await physics_frame
	await physics_frame
	var expected_direction := Vector2(
		-ReflectionRulesResource.outward_ratio,
		ReflectionRulesResource.downward_ratio
	).normalized()
	var expected_velocity: Vector2 = ball.get_limited_velocity(
		expected_direction * ReflectionRulesResource.reflection_speed
	)
	_expect(ball.linear_velocity.distance_to(expected_velocity) <= VELOCITY_EPSILON,
		"A single attack_hit must apply one target-velocity impulse. actual=%s expected=%s" % [
			ball.linear_velocity, expected_velocity
		])
	_expect(reflected_balls.size() == 1 and reflected_balls[0] == ball,
		"One successful attack_hit must emit ball_reflected once with the same Ball.")

	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_unbind_ignores_old_attack() -> void:
	var fixture: Dictionary = await _create_fixture()
	var reflector: BossArmBallReflector = fixture.reflector
	var attack: TeddyArmSweepAttack = fixture.attack
	var ball: Pinball = await _create_ball(Vector2(300.0, 500.0))
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(420.0, -80.0)
	var original_velocity: Vector2 = ball.linear_velocity
	reflector.unbind_attack()

	attack.attack_hit.emit(ball)
	_expect(ball.linear_velocity.is_equal_approx(original_velocity),
		"The old Attack must be ignored after unbind.")
	_expect(_count_connections_to(attack, reflector) == 0,
		"Unbind must remove the attack_hit connection.")

	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_responsibility_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_arm_ball_reflector.gd"
	)
	for forbidden_name: String in [
		"BossArmHitBallTracker",
		"BossParryCounterResolver",
		"BossCounterWindow",
		"BossDamageApplier",
		"BossHealthComponent",
		"ComboSystem",
		"PinballFlipper",
		"Control",
		"linear_velocity =",
	]:
		_expect(not source.contains(forbidden_name),
			"Reflector must not depend on or directly perform: %s" % forbidden_name)
	_expect(source.contains("get_limited_velocity"),
		"Reflector must reuse the Pinball speed limiter.")
	_expect(source.contains("apply_central_impulse"),
		"Reflector must use the existing impulse pattern.")


func _create_fixture() -> Dictionary:
	var reflector := BossArmBallReflector.new()
	root.add_child(reflector)
	var attack: TeddyArmSweepAttack = await _create_attack()
	_expect(reflector.configure(ReflectionRulesResource),
		"Fixture Rules configuration must succeed.")
	_expect(reflector.bind_attack(attack),
		"Fixture Teddy Attack binding must succeed.")
	return {
		&"reflector": reflector,
		&"attack": attack,
	}


func _create_attack() -> TeddyArmSweepAttack:
	var attack: TeddyArmSweepAttack = TeddyAttackScene.instantiate() \
		as TeddyArmSweepAttack
	root.add_child(attack)
	await process_frame
	return attack


func _create_ball(global_position: Vector2) -> Pinball:
	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	root.add_child(ball)
	ball.global_position = global_position
	await process_frame
	await physics_frame
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.linear_velocity = Vector2.ZERO
	await physics_frame
	return ball


func _destroy_fixture(fixture: Dictionary) -> void:
	var reflector: BossArmBallReflector = fixture.reflector
	var attack: TeddyArmSweepAttack = fixture.attack
	if is_instance_valid(reflector):
		reflector.unbind_attack()
		reflector.queue_free()
	if is_instance_valid(attack):
		attack.queue_free()
	await process_frame


func _count_connections_to(
	attack: TeddyArmSweepAttack,
	target: Object
) -> int:
	var count: int = 0
	for connection: Dictionary in attack.attack_hit.get_connections():
		var callback: Callable = connection.get(&"callable", Callable())
		if callback.is_valid() and callback.get_object() == target:
			count += 1
	return count


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_arm_ball_reflector_test")
		quit(0)
		return
	print("FAIL: boss_arm_ball_reflector_test (%d failures)" % _failures.size())
	quit(1)
