extends SceneTree


const ReflectionRuntimeScene: PackedScene = preload(
	"res://scenes/tests/boss/test_teddy_phase1_arm_reflection_runtime.tscn"
)
const ExistingCounterRuntimeScene: PackedScene = preload(
	"res://scenes/tests/boss/test_teddy_phase1_parry_counter_runtime.tscn"
)
const NORMAL_BALL_SCENE: PackedScene = preload(
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
)
const PROTOTYPE_SCRIPT_PATH: String = (
	"res://scripts/boss_system/debug/"
	+ "teddy_phase1_arm_reflection_runtime_prototype.gd"
)
const TEST_ATTACK_DURATION_SEC: float = 0.08
const VELOCITY_EPSILON: float = 6.0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(
		ReflectionRuntimeScene != null and ReflectionRuntimeScene.can_instantiate(),
		"The Phase 1 Arm Reflection scene must load and instantiate."
	)
	_expect(
		ExistingCounterRuntimeScene != null
		and ExistingCounterRuntimeScene.can_instantiate(),
		"The existing Parry Counter scene must remain independently loadable."
	)
	if ReflectionRuntimeScene == null \
			or not ReflectionRuntimeScene.can_instantiate():
		_finish()
		return

	var wave: Node2D = ReflectionRuntimeScene.instantiate() as Node2D
	root.add_child(wave)
	await process_frame
	await process_frame

	var prototype: TeddyPhase1ArmReflectionRuntimePrototype = (
		wave.get_node_or_null("BossPrototype/Phase1Damage")
		as TeddyPhase1ArmReflectionRuntimePrototype
	)
	var reflector: BossArmBallReflector = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossArmBallReflector"
	) as BossArmBallReflector
	var tracker: BossArmHitBallTracker = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossArmHitBallTracker"
	) as BossArmHitBallTracker
	var window: BossCounterWindow = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossCounterWindow"
	) as BossCounterWindow
	var applier: BossCounterGatedDamageApplier = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossDamageApplier"
	) as BossCounterGatedDamageApplier
	var gate: BossDamageGate = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossDamageGate"
	) as BossDamageGate
	var health: BossHealthComponent = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossHealthComponent"
	) as BossHealthComponent
	var combo: ComboSystem = wave.get_node_or_null("ComboSystem") as ComboSystem
	var hurtbox: Area2D = wave.get_node_or_null(
		"BossPrototype/BossHurtbox"
	) as Area2D
	var attack: TeddyArmSweepAttack = wave.get_node_or_null(
		"BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var controller: BossAttackController = wave.get_node_or_null(
		"BossPrototype/BossAttackController"
	) as BossAttackController
	var ball_flow: WaveBallFlowController = wave.get_node_or_null(
		"WaveBallFlowController"
	) as WaveBallFlowController
	var flipper: PinballFlipper = wave.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper

	for check: Array in [
		[prototype, "The Arm Reflection Prototype must exist."],
		[reflector, "BossArmBallReflector must exist."],
		[tracker, "The existing BossArmHitBallTracker must remain present."],
		[window, "The existing BossCounterWindow must remain present."],
		[applier, "The existing Counter Gated Damage Applier must remain present."],
		[gate, "The existing BossDamageGate must remain present."],
		[health, "The existing BossHealthComponent must remain present."],
		[combo, "The existing ComboSystem must remain present."],
		[hurtbox, "The existing BossHurtbox must remain present."],
		[attack, "The real TeddyArmSweepAttack must remain present."],
		[controller, "The existing BossAttackController must remain present."],
		[ball_flow, "The existing Ball Flow must remain present."],
		[flipper, "The existing real PinballFlipper must remain present."],
	]:
		_expect(check[0] != null, String(check[1]))

	if prototype == null or reflector == null or tracker == null \
			or window == null or applier == null or gate == null \
			or health == null or combo == null or hurtbox == null \
			or attack == null or controller == null or ball_flow == null \
			or flipper == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_test_bindings(prototype, reflector, tracker, attack)
	await _test_left_reflection_tracks_and_earns_counter(
		wave, prototype, reflector, tracker, window, applier,
		health, combo, hurtbox, attack, ball_flow, flipper
	)
	await _test_right_reflection(wave, prototype, tracker, attack)
	await _test_active_gate_preserves_counter(
		wave, prototype, window, health, combo, hurtbox,
		controller, ball_flow
	)
	_test_threshold_preserved(
		wave, prototype, window, health, combo, hurtbox, ball_flow
	)
	_test_prototype_boundaries()

	prototype.teardown()
	_expect(not reflector.is_bound(),
		"Teardown must unbind the Arm Ball Reflector.")
	_expect(not tracker.is_bound(),
		"Inherited teardown must still unbind the Tracker.")
	wave.queue_free()
	await process_frame
	_finish()


func _test_bindings(
	prototype: TeddyPhase1ArmReflectionRuntimePrototype,
	reflector: BossArmBallReflector,
	tracker: BossArmHitBallTracker,
	attack: TeddyArmSweepAttack
) -> void:
	_expect(prototype.arm_ball_reflector == reflector,
		"Prototype must reference the Scene Reflector.")
	_expect(prototype.reflection_rules != null
		and prototype.reflection_rules.validate().is_empty(),
		"Prototype must use valid authored Reflection Rules.")
	_expect(reflector.is_bound(),
		"Reflector must bind the real Teddy Attack during setup.")
	_expect(tracker.is_bound(),
		"Tracker must remain bound to the same Teddy Attack.")
	_expect(_count_connections_to(attack, reflector) == 1,
		"Reflector must have one independent attack_hit connection.")
	_expect(_count_connections_to(attack, tracker) == 1,
		"Tracker must retain one independent attack_hit connection.")


func _test_left_reflection_tracks_and_earns_counter(
	wave: Node2D,
	prototype: TeddyPhase1ArmReflectionRuntimePrototype,
	_reflector: BossArmBallReflector,
	tracker: BossArmHitBallTracker,
	window: BossCounterWindow,
	applier: BossCounterGatedDamageApplier,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	attack: TeddyArmSweepAttack,
	ball_flow: WaveBallFlowController,
	flipper: PinballFlipper
) -> void:
	attack.left_hit_area.global_position = Vector2(260.0, 0.0)
	attack.right_hit_area.global_position = Vector2(-520.0, 0.0)
	var ball: Pinball = await _create_ball(wave, Vector2(260.0, 0.0))
	ball.gravity_scale = 0.0
	await physics_frame
	await physics_frame
	_expect(attack.left_hit_area.overlaps_body(ball)
		and not attack.right_hit_area.overlaps_body(ball),
		"The test Ball must overlap only the actual Left Hitbox.")
	var previous_velocity: Vector2 = ball.linear_velocity

	attack.attack_hit.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"One Teddy hit must register the same Ball in Tracker.")
	await physics_frame
	_expect(not ball.linear_velocity.is_equal_approx(previous_velocity),
		"The same Teddy hit must also change Ball velocity.")
	_expect(ball.linear_velocity.x < 0.0 and ball.linear_velocity.y > 0.0,
		"Left hit must reflect below-left.")
	_expect(_velocity_respects_ball_limit(ball),
		"Left reflection must respect the Pinball speed contract.")
	_expect(prototype.damage_event_log.text.contains(
		"BOSS ARM BALL REFLECTED"
	), "A valid reflection must add the development event log.")

	_emit_perfect(flipper, ball)
	_expect(window.is_ready(),
		"PERFECT on the reflected same Ball must ready Counter.")
	_expect(not tracker.is_ball_tracked(ball),
		"The reflected Ball eligibility must be consumed by PERFECT.")

	combo.reset_wave()
	health.configure(prototype.rules.boss_max_hp)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	_activate_profile(ball_flow, definition, ball)
	var resolved_counter: Array[bool] = []
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		was_counter: bool
	) -> void:
		resolved_counter.append(was_counter)
	)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == 11460,
		"Reflected-Ball Counter must preserve the existing 540 first damage.")
	_expect(combo.combo_count == 1,
		"Reflected-Ball Counter hit must register one Combo.")
	_expect(not window.is_ready(),
		"Successful reflected-Ball Counter damage must consume the Window.")
	_expect(resolved_counter.size() == 1 and resolved_counter[0],
		"The reflected-Ball Boss hit must resolve as Counter.")
	hurtbox.body_exited.emit(ball)
	_deactivate_ball(ball_flow)
	ball.queue_free()


func _test_right_reflection(
	wave: Node2D,
	prototype: TeddyPhase1ArmReflectionRuntimePrototype,
	tracker: BossArmHitBallTracker,
	attack: TeddyArmSweepAttack
) -> void:
	attack.left_hit_area.global_position = Vector2(520.0, 0.0)
	attack.right_hit_area.global_position = Vector2(-260.0, 0.0)
	var ball: Pinball = await _create_ball(wave, Vector2(-260.0, 0.0))
	ball.gravity_scale = 0.0
	await physics_frame
	await physics_frame
	_expect(not attack.left_hit_area.overlaps_body(ball)
		and attack.right_hit_area.overlaps_body(ball),
		"The test Ball must overlap only the actual Right Hitbox.")

	attack.attack_hit.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"Right reflection must not prevent Tracker registration.")
	await physics_frame
	_expect(ball.linear_velocity.x > 0.0 and ball.linear_velocity.y > 0.0,
		"Right hit must reflect below-right.")
	_expect(_velocity_respects_ball_limit(ball),
		"Right reflection must respect the Pinball speed contract.")
	_expect(prototype.damage_event_log.text.contains(
		"BOSS ARM BALL REFLECTED"
	), "Right reflection must preserve the development event log.")
	ball.queue_free()
	await process_frame


func _test_active_gate_preserves_counter(
	wave: Node2D,
	prototype: TeddyPhase1ArmReflectionRuntimePrototype,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	controller: BossAttackController,
	ball_flow: WaveBallFlowController
) -> void:
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = await _create_ball(wave, Vector2(0.0, 500.0))
	combo.reset_wave()
	health.configure(prototype.rules.boss_max_hp)
	window.activate()
	_activate_profile(ball_flow, definition, ball)
	controller.pattern = _create_test_pattern()
	_expect(controller.start_attack(), "The Gate regression attack must start.")
	_expect(await _wait_until_state(controller, BossAttackController.State.ACTIVE),
		"The Gate regression attack must reach ACTIVE.")
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"ACTIVE Boss contact must still preserve HP.")
	_expect(combo.combo_count == previous_combo,
		"ACTIVE Boss contact must still preserve Combo.")
	_expect(window.is_ready(),
		"ACTIVE Boss contact must still preserve ready Counter.")
	hurtbox.body_exited.emit(ball)
	controller.cancel_attack()
	window.reset()
	_deactivate_ball(ball_flow)
	ball.queue_free()


func _test_threshold_preserved(
	wave: Node2D,
	prototype: TeddyPhase1ArmReflectionRuntimePrototype,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	ball_flow: WaveBallFlowController
) -> void:
	window.reset()
	combo.reset_wave()
	health.configure(prototype.rules.boss_max_hp)
	health.apply_damage(5799)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = NORMAL_BALL_SCENE.instantiate() as Pinball
	wave.add_child(ball)
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() <= 6000,
		"The regression hit must cross the 50 percent threshold.")
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: BELOW_50",
		"The existing Threshold UI must remain functional.")
	_expect(prototype.damage_event_log.text.contains(
		"PHASE 2 THRESHOLD REACHED"
	), "The existing Threshold event must remain functional.")
	hurtbox.body_exited.emit(ball)
	_deactivate_ball(ball_flow)
	ball.queue_free()


func _test_prototype_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(PROTOTYPE_SCRIPT_PATH)
	_expect(not source.is_empty(), "Reflection Prototype source must be readable.")
	_expect(source.contains(
		"extends TeddyPhase1ParryCounterRuntimePrototype"
	), "Reflection Prototype must extend the existing Counter integration.")
	for forbidden_text: String in [
		"resolve_and_apply_hit",
		"apply_damage",
		"target_valid_hit_count",
		"FlipperParryEvaluator",
		"phase2_hp_ratio",
		"get_nodes_in_group",
	]:
		_expect(not source.contains(forbidden_text),
			"Reflection Prototype must not duplicate: %s" % forbidden_text)


func _emit_perfect(flipper: PinballFlipper, ball: Pinball) -> void:
	flipper.parry_resolved.emit(
		ball,
		FlipperParryEvaluator.Grade.PERFECT,
		Vector2.ZERO,
		PinballFlipper.ContactZone.B,
		0.0,
		1.0
	)


func _velocity_respects_ball_limit(ball: Pinball) -> bool:
	var limited: Vector2 = ball.get_limited_velocity(ball.linear_velocity)
	return ball.linear_velocity.distance_to(limited) <= VELOCITY_EPSILON


func _create_test_pattern() -> BossAttackPattern:
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"arm_reflection_gate_test"
	pattern.telegraph_duration = TEST_ATTACK_DURATION_SEC
	pattern.active_duration = TEST_ATTACK_DURATION_SEC
	pattern.recovery_duration = TEST_ATTACK_DURATION_SEC
	pattern.cooldown_duration = TEST_ATTACK_DURATION_SEC
	return pattern


func _wait_until_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames: int = 360
) -> bool:
	for _frame: int in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _create_ball(wave: Node2D, position: Vector2) -> Pinball:
	var ball: Pinball = NORMAL_BALL_SCENE.instantiate() as Pinball
	wave.add_child(ball)
	ball.global_position = position
	await process_frame
	return ball


func _find_definition(
	ball_flow: WaveBallFlowController,
	ball_id: StringName
) -> BallDefinition:
	if ball_flow.inventory == null:
		return null
	for definition: BallDefinition in ball_flow.inventory.get_available_definitions():
		if definition.ball_id == ball_id:
			return definition
	return null


func _activate_profile(
	ball_flow: WaveBallFlowController,
	definition: BallDefinition,
	ball: Pinball
) -> void:
	ball_flow.ball_selection_confirmed.emit(definition, 0)
	ball_flow.active_ball_changed.emit(ball)


func _deactivate_ball(ball_flow: WaveBallFlowController) -> void:
	ball_flow.active_ball_changed.emit(null)


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_phase1_arm_reflection_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_phase1_arm_reflection_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
