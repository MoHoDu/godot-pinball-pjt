extends SceneTree


const CounterRuntimeScene: PackedScene = preload(
	"res://scenes/wave/test_teddy_phase1_parry_counter_runtime.tscn"
)
const PROTOTYPE_SCRIPT_PATH: String = (
	"res://scripts/boss_system/debug/"
	+ "teddy_phase1_parry_counter_runtime_prototype.gd"
)
const COUNTER_MULTIPLIER_EPSILON: float = 0.01
const EXPIRY_MARGIN_SEC: float = 0.12
const TEST_ATTACK_DURATION_SEC: float = 0.08


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(
		CounterRuntimeScene != null and CounterRuntimeScene.can_instantiate(),
		"The Phase 1 Parry Counter scene must load and instantiate."
	)
	if CounterRuntimeScene == null or not CounterRuntimeScene.can_instantiate():
		_finish()
		return

	var wave: Node2D = CounterRuntimeScene.instantiate() as Node2D
	root.add_child(wave)
	await process_frame
	await process_frame

	var prototype: TeddyPhase1ParryCounterRuntimePrototype = wave.get_node_or_null(
		"BossPrototype/Phase1Damage"
	) as TeddyPhase1ParryCounterRuntimePrototype
	var attack_prototype: TeddyPhase1AttackRuntimePrototype = wave.get_node_or_null(
		"BossPrototype"
	) as TeddyPhase1AttackRuntimePrototype
	var tracker: BossArmHitBallTracker = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossArmHitBallTracker"
	) as BossArmHitBallTracker
	var resolver: BossParryCounterResolver = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossParryCounterResolver"
	) as BossParryCounterResolver
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
	var runtime: BossPhase1AttackRuntime = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var ball_flow: WaveBallFlowController = wave.get_node_or_null(
		"WaveBallFlowController"
	) as WaveBallFlowController
	var flipper: PinballFlipper = wave.get_node_or_null(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper

	for check: Array in [
		[prototype, "The Counter integration Prototype must exist."],
		[attack_prototype, "The existing Attack Prototype must remain present."],
		[tracker, "BossArmHitBallTracker must exist."],
		[resolver, "BossParryCounterResolver must exist."],
		[window, "BossCounterWindow must exist."],
		[applier, "BossDamageApplier must use the Counter Gated subtype."],
		[gate, "The existing BossDamageGate must remain present."],
		[health, "The existing BossHealthComponent must remain present."],
		[combo, "The existing ComboSystem must remain present."],
		[hurtbox, "The existing BossHurtbox must remain present."],
		[attack, "The real TeddyArmSweepAttack must remain present."],
		[controller, "The existing BossAttackController must remain present."],
		[runtime, "The existing Attack Runtime must remain present."],
		[ball_flow, "The existing Ball Flow must remain present."],
		[flipper, "An explicitly bound real PinballFlipper must exist."],
	]:
		_expect(check[0] != null, String(check[1]))

	if prototype == null or attack_prototype == null or tracker == null \
			or resolver == null or window == null or applier == null \
			or gate == null or health == null or combo == null \
			or hurtbox == null or attack == null or controller == null \
			or runtime == null or ball_flow == null or flipper == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_test_scene_bindings(prototype, tracker, resolver, window, applier, gate)
	await _test_arm_parry_and_counter_damage(
		wave, prototype, tracker, window, applier, health, combo,
		hurtbox, attack, ball_flow, flipper
	)
	await _test_active_block_preserves_counter(
		wave, prototype, window, health, combo, hurtbox,
		controller, ball_flow
	)
	await _test_tracker_and_counter_expiry(
		wave, prototype, tracker, window, attack, ball_flow, flipper
	)
	_test_debug_ui_and_events(prototype)
	_test_weight_profiles(wave, prototype, window, health, combo, hurtbox, ball_flow)
	_test_threshold_preserved(wave, prototype, window, health, combo, hurtbox, ball_flow)
	_test_attack_controls(attack_prototype, runtime)
	_test_prototype_boundaries()

	prototype.teardown()
	_expect(not tracker.is_bound(), "Teardown must unbind the Teddy attack Tracker.")
	_expect(not applier.is_counter_window_bound(),
		"Teardown must unbind the Counter Window from Damage.")
	wave.queue_free()
	await process_frame
	_finish()


func _test_scene_bindings(
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
	tracker: BossArmHitBallTracker,
	resolver: BossParryCounterResolver,
	window: BossCounterWindow,
	applier: BossCounterGatedDamageApplier,
	gate: BossDamageGate
) -> void:
	_expect(prototype.damage_applier == applier,
		"The inherited Damage reference must use the Counter Gated Applier.")
	_expect(prototype.gated_damage_applier == applier,
		"The Gate reference must use the same Counter Gated Applier.")
	_expect(prototype.counter_damage_applier == applier,
		"The Counter reference must use the same Damage Applier instance.")
	_expect(tracker.is_bound(), "Tracker must bind the real Teddy attack.")
	_expect(gate.is_bound() and applier.is_damage_gate_bound(),
		"The existing Damage Gate chain must remain bound.")
	_expect(applier.is_counter_window_bound(),
		"Counter Damage must bind the Scene Counter Window.")
	_expect(not window.is_ready(), "Counter must initially be OFF.")
	var explicit_flippers: Array[PinballFlipper] = [
		prototype.bottom_left_flipper,
		prototype.bottom_right_flipper,
		prototype.top_left_flipper,
		prototype.top_right_flipper,
		prototype.left_left_flipper,
		prototype.left_right_flipper,
		prototype.right_left_flipper,
		prototype.right_right_flipper,
	]
	for flipper: PinballFlipper in explicit_flippers:
		_expect(is_instance_valid(flipper),
			"Every board Flipper must be explicitly assigned.")
		_expect(_count_connections_to(flipper, resolver) == 1,
			"Every explicit Flipper must connect to Resolver exactly once.")
	_expect(is_equal_approx(
		prototype.rules.boss_launch_duration_sec, 2.5
	), "Tracker duration must come from the Stage 1 Rules value.")
	_expect(is_equal_approx(
		prototype.rules.counter_ready_duration_sec, 3.0
	), "Counter duration must come from the Stage 1 Rules value.")
	_expect(is_equal_approx(
		prototype.rules.parry_counter_multiplier, 1.35
	), "Counter multiplier must come from the Stage 1 Rules value.")


func _test_arm_parry_and_counter_damage(
	wave: Node2D,
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
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
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var tracked_ball: Pinball = _create_ball(wave, definition)
	var other_ball: Pinball = _create_ball(wave, definition)
	if tracked_ball == null or other_ball == null:
		_expect(false, "Counter flow requires two Normal balls.")
		_free_ball(tracked_ball)
		_free_ball(other_ball)
		return

	attack.attack_hit.emit(tracked_ball)
	_expect(tracker.is_ball_tracked(tracked_ball),
		"Teddy attack_hit must track the same Ball instance.")
	_expect(absf(
		tracker.get_remaining_time_sec(tracked_ball)
		- prototype.rules.boss_launch_duration_sec
	) <= COUNTER_MULTIPLIER_EPSILON,
		"Tracker must start with the Rules launch duration.")
	_expect(prototype.tracked_ball_label.text == "Tracked Boss Ball: YES",
		"Tracked Ball UI must immediately display YES.")

	_emit_parry(flipper, other_ball, FlipperParryEvaluator.Grade.PERFECT)
	_expect(not window.is_ready() and tracker.is_ball_tracked(tracked_ball),
		"A different Ball PERFECT must not earn or consume Counter.")
	_emit_parry(flipper, tracked_ball, FlipperParryEvaluator.Grade.NORMAL)
	_expect(not window.is_ready() and tracker.is_ball_tracked(tracked_ball),
		"NORMAL must preserve the tracked Ball without earning Counter.")
	_emit_parry(flipper, tracked_ball, FlipperParryEvaluator.Grade.PERFECT)
	_expect(window.is_ready(), "The tracked Ball PERFECT must ready Counter.")
	_expect(not tracker.is_ball_tracked(tracked_ball),
		"PERFECT must consume the tracked Ball eligibility.")
	_expect(absf(
		window.get_remaining_time_sec()
		- prototype.rules.counter_ready_duration_sec
	) <= COUNTER_MULTIPLIER_EPSILON,
		"Counter Window must start with the Rules duration.")

	combo.reset_wave()
	health.configure(prototype.rules.boss_max_hp)
	_activate_profile(ball_flow, definition, tracked_ball)
	var counter_flags: Array[bool] = []
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		was_counter: bool
	) -> void:
		counter_flags.append(was_counter)
	)
	hurtbox.body_entered.emit(tracked_ball)
	_expect(health.get_current_health() == 11460,
		"The first Normal Counter hit must apply 400 x 1.35 = 540.")
	_expect(combo.combo_count == 1, "Counter hit must register one Combo.")
	_expect(not window.is_ready(), "A valid Counter hit must consume the Window.")
	_expect(counter_flags.size() == 1 and counter_flags[0],
		"The resolved Counter hit must be identified as Counter.")
	hurtbox.body_exited.emit(tracked_ball)
	var before_normal_hit: int = health.get_current_health()
	hurtbox.body_entered.emit(tracked_ball)
	_expect(health.get_current_health() == before_normal_hit - 410,
		"The next hit must return to normal second-combo damage.")
	_expect(combo.combo_count == 2,
		"The next normal hit must register exactly one more Combo.")
	_expect(counter_flags.size() == 2 and not counter_flags[1],
		"The hit after consumption must resolve as non-Counter.")
	hurtbox.body_exited.emit(tracked_ball)
	_deactivate_ball(ball_flow)
	_free_ball(tracked_ball)
	_free_ball(other_ball)


func _test_active_block_preserves_counter(
	wave: Node2D,
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	controller: BossAttackController,
	ball_flow: WaveBallFlowController
) -> void:
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if ball == null:
		_expect(false, "ACTIVE preservation requires a Normal ball.")
		return
	combo.reset_wave()
	health.configure(prototype.rules.boss_max_hp)
	window.activate()
	_activate_profile(ball_flow, definition, ball)
	controller.pattern = _create_test_pattern()
	_expect(controller.start_attack(), "The ACTIVE Gate test attack must start.")
	_expect(await _wait_until_state(controller, BossAttackController.State.ACTIVE),
		"The ACTIVE Gate test must reach ACTIVE.")
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"ACTIVE Boss contact must preserve HP.")
	_expect(combo.combo_count == previous_combo,
		"ACTIVE Boss contact must preserve Combo.")
	_expect(window.is_ready(),
		"ACTIVE damage blocking must preserve the ready Counter.")
	hurtbox.body_exited.emit(ball)
	controller.cancel_attack()
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_tracker_and_counter_expiry(
	wave: Node2D,
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
	tracker: BossArmHitBallTracker,
	window: BossCounterWindow,
	attack: TeddyArmSweepAttack,
	ball_flow: WaveBallFlowController,
	flipper: PinballFlipper
) -> void:
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if ball == null:
		_expect(false, "Expiry tests require a Normal ball.")
		return
	window.reset()
	attack.attack_hit.emit(ball)
	await create_timer(
		prototype.rules.boss_launch_duration_sec + EXPIRY_MARGIN_SEC
	).timeout
	_expect(not tracker.is_ball_tracked(ball),
		"Arm-hit tracking must expire after the Rules duration.")
	_emit_parry(flipper, ball, FlipperParryEvaluator.Grade.PERFECT)
	_expect(not window.is_ready(),
		"PERFECT after Tracker expiry must not activate Counter.")

	window.activate()
	await create_timer(
		prototype.rules.counter_ready_duration_sec + EXPIRY_MARGIN_SEC
	).timeout
	_expect(not window.is_ready(),
		"Counter must expire after the Rules duration.")
	_expect(prototype.last_counter_label.text == "Last Counter: EXPIRED",
		"Counter expiry must update the debug state.")
	_free_ball(ball)


func _test_weight_profiles(
	wave: Node2D,
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	ball_flow: WaveBallFlowController
) -> void:
	for profile: Array in [
		[&"light", 360],
		[&"normal", 400],
		[&"heavy", 460],
	]:
		window.reset()
		combo.reset_wave()
		health.configure(prototype.rules.boss_max_hp)
		var definition: BallDefinition = _find_definition(
			ball_flow, StringName(profile[0])
		)
		var ball: Pinball = _create_ball(wave, definition)
		if ball == null:
			_expect(false, "%s Ball must instantiate." % profile[0])
			continue
		_activate_profile(ball_flow, definition, ball)
		hurtbox.body_entered.emit(ball)
		_expect(
			health.get_current_health()
			== prototype.rules.boss_max_hp - int(profile[1]),
			"%s damage weight must remain unchanged." % profile[0]
		)
		hurtbox.body_exited.emit(ball)
		_deactivate_ball(ball_flow)
		_free_ball(ball)


func _test_threshold_preserved(
	wave: Node2D,
	prototype: TeddyPhase1ParryCounterRuntimePrototype,
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
	var ball: Pinball = _create_ball(wave, definition)
	if ball == null:
		_expect(false, "Threshold preservation requires a Normal ball.")
		return
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() <= 6000,
		"The test hit must cross the Phase 2 HP threshold.")
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: BELOW_50",
		"The existing threshold UI must remain functional.")
	_expect(prototype.damage_event_log.text.contains(
		"PHASE 2 THRESHOLD REACHED"
	), "The existing threshold event log must remain functional.")
	hurtbox.body_exited.emit(ball)
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_attack_controls(
	prototype: TeddyPhase1AttackRuntimePrototype,
	runtime: BossPhase1AttackRuntime
) -> void:
	_expect(runtime.is_ready(), "The existing Attack Runtime must remain ready.")
	prototype.start_button.emit_signal(&"pressed")
	_expect(runtime.is_running(), "The existing Start control must work.")
	prototype.new_ball_grace_button.emit_signal(&"pressed")
	_expect(prototype.scheduler.is_grace_active(),
		"The existing New Ball Grace control must work.")
	prototype.stop_button.emit_signal(&"pressed")
	_expect(not runtime.is_running(), "The existing Stop control must work.")
	prototype.reset_button.emit_signal(&"pressed")
	_expect(runtime.is_ready(), "The existing Reset control must work.")


func _test_debug_ui_and_events(
	prototype: TeddyPhase1ParryCounterRuntimePrototype
) -> void:
	_expect(is_instance_valid(prototype.tracked_ball_label),
		"Tracked Ball debug UI must exist.")
	_expect(is_instance_valid(prototype.counter_state_label),
		"Counter state debug UI must exist.")
	_expect(is_instance_valid(prototype.counter_time_label),
		"Counter time debug UI must exist.")
	_expect(is_instance_valid(prototype.last_counter_label),
		"Last Counter debug UI must exist.")
	for event_text: String in [
		"BOSS ARM BALL TRACKED",
		"COUNTER EARNED: PERFECT",
		"COUNTER CONSUMED",
		"COUNTER EXPIRED",
	]:
		_expect(prototype.damage_event_log.text.contains(event_text),
			"Counter debug log must contain: %s" % event_text)


func _test_prototype_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(PROTOTYPE_SCRIPT_PATH)
	_expect(not source.is_empty(), "Counter Prototype source must be readable.")
	for forbidden_text: String in [
		"get_nodes_in_group",
		"get_tree().get_nodes",
		"2.5",
		"3.0",
		"1.35",
		"calculate_base_damage",
		"apply_damage",
	]:
		_expect(not source.contains(forbidden_text),
			"Counter Prototype must not contain: %s" % forbidden_text)


func _emit_parry(
	flipper: PinballFlipper,
	ball: RigidBody2D,
	grade: int
) -> void:
	flipper.parry_resolved.emit(
		ball,
		grade,
		Vector2.ZERO,
		PinballFlipper.ContactZone.B,
		0.0,
		1.0
	)


func _count_connections_to(
	flipper: PinballFlipper,
	target: Object
) -> int:
	if not is_instance_valid(flipper):
		return 0
	var count: int = 0
	for connection: Dictionary in flipper.parry_resolved.get_connections():
		var callback: Callable = connection.get(&"callable", Callable())
		if callback.is_valid() and callback.get_object() == target:
			count += 1
	return count


func _create_test_pattern() -> BossAttackPattern:
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"parry_counter_scene_test"
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


func _create_ball(wave: Node2D, definition: BallDefinition) -> Pinball:
	if definition == null or definition.ball_scene == null:
		return null
	var ball: Pinball = definition.ball_scene.instantiate() as Pinball
	if ball != null:
		wave.add_child(ball)
	return ball


func _activate_profile(
	ball_flow: WaveBallFlowController,
	definition: BallDefinition,
	ball: Pinball
) -> void:
	ball_flow.ball_selection_confirmed.emit(definition, 0)
	ball_flow.active_ball_changed.emit(ball)


func _deactivate_ball(ball_flow: WaveBallFlowController) -> void:
	ball_flow.active_ball_changed.emit(null)


func _free_ball(ball: Pinball) -> void:
	if ball != null and is_instance_valid(ball):
		ball.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_phase1_parry_counter_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_phase1_parry_counter_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
