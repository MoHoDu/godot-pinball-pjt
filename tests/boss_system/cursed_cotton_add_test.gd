extends SceneTree


const CottonScene: PackedScene = preload(
	"res://Resources/Prefabs/boss/adds/cursed_cotton_add.tscn"
)
const NormalBallScene: PackedScene = preload(
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
)
const RulesResource: CursedCottonAddRules = preload(
	"res://settings/bosses/CursedCottonAddRules.tres"
)
const VELOCITY_EPSILON: float = 6.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules()
	_test_configure_preserves_valid_rules()
	await _test_scene_and_invalid_targets()
	await _test_valid_hit_reflects_once_and_clears()
	await _test_sleeping_ball_is_woken()
	await _test_center_fallback_is_deterministic()
	_test_responsibility_boundaries()
	_finish()


func _test_rules() -> void:
	_expect(RulesResource != null, "The authored Cotton Rules must load.")
	_expect(RulesResource.validate().is_empty(),
		"The authored Cotton Rules must validate.")
	_expect(is_equal_approx(RulesResource.collision_radius_px, 32.0),
		"The authored collision radius must be 32 pixels.")
	_expect(is_equal_approx(RulesResource.speed_retention, 0.85),
		"The authored speed retention must be 0.85.")

	for invalid_radius: float in [0.0, -1.0, NAN, INF]:
		var rules := CursedCottonAddRules.new()
		rules.collision_radius_px = invalid_radius
		_expect(not rules.validate().is_empty(),
			"Invalid collision radius must be rejected: %s" % invalid_radius)
	for invalid_retention: float in [0.0, -1.0, 1.01, NAN, INF]:
		var rules := CursedCottonAddRules.new()
		rules.speed_retention = invalid_retention
		_expect(not rules.validate().is_empty(),
			"Invalid speed retention must be rejected: %s" % invalid_retention)


func _test_configure_preserves_valid_rules() -> void:
	var cotton := CursedCottonAdd.new()
	var valid_rules := CursedCottonAddRules.new()
	var invalid_rules := CursedCottonAddRules.new()
	invalid_rules.speed_retention = 0.0
	_expect(cotton.configure(valid_rules), "Valid Rules must configure.")
	_expect(not cotton.configure(invalid_rules), "Invalid Rules must be rejected.")
	_expect(cotton.rules == valid_rules,
		"Failed configure must preserve the existing valid Rules.")
	cotton.free()


func _test_scene_and_invalid_targets() -> void:
	_expect(CottonScene != null and CottonScene.can_instantiate(),
		"The Cotton scene must load and instantiate.")
	if CottonScene == null or not CottonScene.can_instantiate():
		return
	var cotton: CursedCottonAdd = CottonScene.instantiate() as CursedCottonAdd
	root.add_child(cotton)
	await process_frame
	_expect(cotton != null, "The scene root must be CursedCottonAdd.")
	_expect(cotton.collision_shape != null \
		and cotton.collision_shape.shape is CircleShape2D,
		"The scene must use an Area2D CircleShape collision.")
	var circle: CircleShape2D = cotton.collision_shape.shape as CircleShape2D
	_expect(is_equal_approx(circle.radius, RulesResource.collision_radius_px),
		"The collision radius must come from Rules.")

	var non_ball := Node2D.new()
	root.add_child(non_ball)
	var outside_group_ball: Pinball = NormalBallScene.instantiate() as Pinball
	root.add_child(outside_group_ball)
	await process_frame
	outside_group_ball.remove_from_group(Pinball.PINBALL_GROUP)
	var hit_events: Array[bool] = []
	cotton.cotton_hit.connect(func(_ball: Pinball) -> void:
		hit_events.append(true)
	)
	cotton.body_entered.emit(non_ball)
	cotton.body_entered.emit(outside_group_ball)
	_expect(hit_events.is_empty(),
		"Non-Pinball and out-of-group Pinball targets must be ignored.")
	_expect(is_instance_valid(cotton) and not cotton.is_queued_for_deletion(),
		"Invalid targets must not consume or remove the Cotton.")

	non_ball.queue_free()
	outside_group_ball.queue_free()
	cotton.queue_free()
	await process_frame


func _test_valid_hit_reflects_once_and_clears() -> void:
	var cotton: CursedCottonAdd = CottonScene.instantiate() as CursedCottonAdd
	root.add_child(cotton)
	cotton.global_position = Vector2.ZERO
	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	ball.global_position = Vector2(1000.0, 1000.0)
	root.add_child(ball)
	await process_frame
	await physics_frame
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.linear_velocity = Vector2(0.0, 1000.0)
	await physics_frame
	ball.global_position = Vector2(100.0, 0.0)

	var initial_speed: float = ball.linear_velocity.length()
	var expected_velocity: Vector2 = ball.get_limited_velocity(
		Vector2.RIGHT * initial_speed * RulesResource.speed_retention
	)
	var hit_balls: Array[Pinball] = []
	var cleared_events: Array[bool] = []
	cotton.cotton_hit.connect(func(hit_ball: Pinball) -> void:
		hit_balls.append(hit_ball)
	)
	cotton.cotton_cleared.connect(func() -> void:
		cleared_events.append(true)
	)

	cotton.body_entered.emit(ball)
	var velocity_after_first_hit: Vector2 = ball.linear_velocity
	cotton.body_entered.emit(ball)
	_expect(hit_balls == [ball],
		"Duplicate body_entered events must emit one Cotton hit only.")
	_expect(ball.linear_velocity.is_equal_approx(velocity_after_first_hit),
		"Duplicate overlap must not apply a second impulse.")
	_expect(not ball.sleeping, "A valid Cotton hit must leave the Ball awake.")
	await physics_frame
	await physics_frame
	_expect(ball.linear_velocity.x > 0.0,
		"The Ball must move outward from the Cotton center.")
	_expect(ball.linear_velocity.distance_to(expected_velocity) <= VELOCITY_EPSILON,
		"The reflected speed must apply speed_retention and Pinball limits. actual=%s expected=%s" % [
			ball.linear_velocity, expected_velocity
		])
	_expect(_respects_pinball_speed_contract(ball),
		"The final velocity must satisfy Pinball.get_limited_velocity().")
	await process_frame
	_expect(cleared_events.size() == 1,
		"A consumed Cotton must emit cotton_cleared exactly once.")
	_expect(not is_instance_valid(cotton) or cotton.is_queued_for_deletion(),
		"A consumed Cotton must be removed safely after the callback.")

	ball.queue_free()
	await process_frame


func _test_center_fallback_is_deterministic() -> void:
	var cotton: CursedCottonAdd = CottonScene.instantiate() as CursedCottonAdd
	root.add_child(cotton)
	cotton.global_position = Vector2(250.0, 100.0)
	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	ball.global_position = Vector2(1000.0, 1000.0)
	root.add_child(ball)
	await process_frame
	await physics_frame
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	ball.global_position = cotton.global_position
	cotton.body_entered.emit(ball)
	await physics_frame
	await physics_frame
	_expect(ball.linear_velocity.x < 0.0 \
		and is_zero_approx(ball.linear_velocity.y),
		"Coincident centers must deterministically use opposite Ball velocity.")
	_expect(_respects_pinball_speed_contract(ball),
		"The center fallback must still use the Pinball speed contract.")
	ball.queue_free()
	await process_frame


func _test_sleeping_ball_is_woken() -> void:
	var cotton: CursedCottonAdd = CottonScene.instantiate() as CursedCottonAdd
	root.add_child(cotton)
	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	ball.global_position = Vector2(1000.0, 1000.0)
	root.add_child(ball)
	await process_frame
	await physics_frame
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2.ZERO
	await physics_frame
	ball.global_position = Vector2(100.0, 0.0)
	ball.sleeping = true

	cotton.body_entered.emit(ball)
	_expect(not ball.sleeping, "A valid Cotton hit must wake a sleeping Ball.")

	await process_frame
	ball.queue_free()
	await process_frame


func _respects_pinball_speed_contract(ball: Pinball) -> bool:
	var limited: Vector2 = ball.get_limited_velocity(ball.linear_velocity)
	return ball.linear_velocity.distance_to(limited) <= VELOCITY_EPSILON


func _test_responsibility_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/adds/cursed_cotton_add.gd"
	)
	for forbidden_name: String in [
		"BossHealthComponent",
		"BossDamageApplier",
		"ComboSystem",
		"BossCounterWindow",
		"BossPhaseTransitionController",
		"BossAttackController",
		"score",
	]:
		_expect(not source.contains(forbidden_name),
			"Cotton must not depend on: %s" % forbidden_name)
	_expect(source.contains("get_limited_velocity") \
		and source.contains("apply_central_impulse"),
		"Cotton must reuse the Pinball velocity and impulse contracts.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: cursed_cotton_add_test")
		quit(0)
		return
	print("FAIL: cursed_cotton_add_test (%d failures)" % _failures.size())
	quit(1)
