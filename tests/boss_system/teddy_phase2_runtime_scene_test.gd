extends SceneTree


const Phase2RuntimeScene: PackedScene = preload(
	"res://scenes/wave/test_teddy_phase2_runtime.tscn"
)
const NormalBallScene: PackedScene = preload(
	"res://Resources/balls/mass_var/normal_ball.tscn"
)
const PHASE_2_MIN_SEC: float = 2.8
const PHASE_2_MAX_SEC: float = 3.8


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(Phase2RuntimeScene != null and Phase2RuntimeScene.can_instantiate(),
		"The Phase 2 Runtime scene must load and instantiate.")
	if Phase2RuntimeScene == null or not Phase2RuntimeScene.can_instantiate():
		_finish()
		return

	var scene: Node2D = Phase2RuntimeScene.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var integration := scene.get_node_or_null("Phase2Integration") \
		as TeddyPhase2RuntimePrototype
	var transition := scene.get_node_or_null(
		"Phase2Integration/BossPhaseTransitionController"
	) as BossPhaseTransitionController
	var boss_root: Node = scene.get_node_or_null("Phase1Runtime/BossPrototype")
	var health := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Damage/BossHealthComponent"
	) as BossHealthComponent
	var scheduler := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Attack/Scheduler"
	) as BossPhase1AttackScheduler
	var runtime := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var controller := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/BossAttackController"
	) as BossAttackController
	var pattern_1 := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var pattern_2 := scene.get_node_or_null(
		"TeddyDoubleArmUpSweepAttack"
	) as TeddyDoubleArmUpSweepAttack
	var tracker := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Damage/BossArmHitBallTracker"
	) as BossArmHitBallTracker
	var reflector := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Damage/BossArmBallReflector"
	) as BossArmBallReflector
	var window := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Damage/BossCounterWindow"
	) as BossCounterWindow
	var applier := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/Phase1Damage/BossDamageApplier"
	) as BossCounterGatedDamageApplier
	var combo := scene.get_node_or_null(
		"Phase1Runtime/ComboSystem"
	) as ComboSystem
	var hurtbox := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/BossHurtbox"
	) as Area2D
	var ball_flow := scene.get_node_or_null(
		"Phase1Runtime/WaveBallFlowController"
	) as WaveBallFlowController
	var flipper := scene.get_node_or_null(
		"Phase1Runtime/FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	var reset_button := scene.get_node_or_null(
		"Phase1Runtime/BossPrototype/DebugCanvas/DebugUI/Panel/VBox/"
		+ "ButtonRow/ResetButton"
	) as Button

	for check: Array in [
		[integration, "Phase 2 integration Prototype must exist."],
		[transition, "Phase Transition Controller must exist."],
		[boss_root, "The inherited Phase 1 Boss root must exist."],
		[health, "Existing Boss Health must be reused."],
		[scheduler, "Existing Scheduler must be reused."],
		[runtime, "Existing Attack Runtime must be reused."],
		[controller, "Existing Controller must be reused."],
		[pattern_1, "Pattern 1 Attack must be preserved."],
		[pattern_2, "Pattern 2 Attack must exist."],
		[tracker, "Existing Ball Tracker must be reused."],
		[reflector, "Existing Reflector must be reused."],
		[window, "Existing Counter Window must be reused."],
		[applier, "Existing Counter Damage Applier must be reused."],
		[combo, "Existing Combo System must be reused."],
		[hurtbox, "Existing Boss Hurtbox must be reused."],
		[ball_flow, "Existing Ball Flow must be reused."],
		[flipper, "Existing Flipper must be reused."],
		[reset_button, "Existing Reset button must be reused."],
	]:
		_expect(check[0] != null, String(check[1]))

	if integration == null or transition == null or health == null \
			or scheduler == null or runtime == null or controller == null \
			or pattern_1 == null or pattern_2 == null or tracker == null \
			or reflector == null or window == null or applier == null \
			or combo == null or hurtbox == null or ball_flow == null \
			or flipper == null or reset_button == null:
		scene.queue_free()
		await process_frame
		_finish()
		return

	_test_initial_phase_and_threshold(
		integration, transition, health, scheduler, pattern_1, controller
	)
	await _reset_to_phase_1(reset_button, health, transition)
	_test_lethal_damage_does_not_enter_phase_2(health, transition)
	await _reset_to_phase_1(reset_button, health, transition)
	await _test_phase_1_pattern(
		runtime, scheduler, controller, pattern_1, integration
	)
	await _reset_to_phase_1(reset_button, health, transition)
	await _test_phase_2_pattern_rotation(
		integration, transition, health, runtime, scheduler,
		controller, pattern_1, pattern_2
	)
	await _test_pattern_2_counter_flow(
		scene, integration, pattern_2, tracker, reflector, window,
		applier, health, combo, hurtbox, ball_flow, flipper, controller
	)
	await _test_gate_preserves_counter(
		scene, window, health, combo, hurtbox, ball_flow, controller
	)
	_test_runtime_controls(runtime, scheduler)
	_test_teardown(integration, transition, scheduler, controller)

	scene.queue_free()
	await process_frame
	_finish()


func _test_initial_phase_and_threshold(
	integration: TeddyPhase2RuntimePrototype,
	transition: BossPhaseTransitionController,
	health: BossHealthComponent,
	scheduler: BossPhase1AttackScheduler,
	pattern_1: TeddyArmSweepAttack,
	controller: BossAttackController
) -> void:
	var entered_health: Array[int] = []
	transition.phase_2_entered.connect(func(current_hp: int) -> void:
		entered_health.append(current_hp)
	)
	_expect(not transition.is_phase_2(), "The scene must start in Phase 1.")
	_expect(controller.attack == pattern_1,
		"Phase 1 must initially select Pattern 1 only.")
	health.apply_damage(5999)
	_expect(health.get_current_health() == 6001 and not transition.is_phase_2(),
		"HP above 6000 must remain in Phase 1.")
	health.apply_damage(1)
	_expect(transition.is_phase_2(), "HP exactly 6000 must enter Phase 2.")
	_expect(entered_health == [6000],
		"The threshold signal must report exactly one Phase 2 entry.")
	_expect(integration.is_phase_2_schedule_active(),
		"An idle transition must activate the Phase 2 schedule immediately.")
	_expect(is_equal_approx(
		scheduler.get_wait_time_remaining(), 0.0
	), "A stopped Runtime must remain stopped after schedule configuration.")
	health.apply_damage(100)
	_expect(entered_health.size() == 1,
		"Further Phase 2 damage must not emit another entry.")


func _test_lethal_damage_does_not_enter_phase_2(
	health: BossHealthComponent,
	transition: BossPhaseTransitionController
) -> void:
	health.apply_damage(health.get_current_health())
	_expect(health.is_defeated(), "The lethal fixture must defeat the Boss.")
	_expect(not transition.is_phase_2(),
		"Lethal damage must not create a new Phase 2 entry.")


func _reset_to_phase_1(
	reset_button: Button,
	health: BossHealthComponent,
	transition: BossPhaseTransitionController
) -> void:
	if health.is_defeated():
		health.configure(12000)
	reset_button.pressed.emit()
	await process_frame
	await process_frame
	health.configure(12000)
	_expect(not transition.is_phase_2(), "Reset must return to Phase 1.")


func _test_phase_1_pattern(
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController,
	pattern_1: TeddyArmSweepAttack,
	integration: TeddyPhase2RuntimePrototype
) -> void:
	_expect(runtime.start(), "Phase 1 Runtime must start.")
	scheduler.advance_time(3.0)
	_expect(controller.attack == pattern_1,
		"The Phase 1 request must use only Pattern 1.")
	_expect(integration.get_current_pattern_number() == 1,
		"Phase 1 debug state must report Pattern 1.")
	controller.cancel_attack()
	_expect(runtime.stop(false), "Phase 1 Runtime must stop after cancellation.")


func _test_phase_2_pattern_rotation(
	integration: TeddyPhase2RuntimePrototype,
	transition: BossPhaseTransitionController,
	health: BossHealthComponent,
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController,
	pattern_1: TeddyArmSweepAttack,
	pattern_2: TeddyDoubleArmUpSweepAttack
) -> void:
	health.apply_damage(6000)
	_expect(transition.is_phase_2(), "The rotation fixture must enter Phase 2.")
	_expect(runtime.start(), "The configured Phase 2 Runtime must start.")
	_expect(is_equal_approx(
		scheduler.get_wait_time_remaining(), PHASE_2_MIN_SEC
	), "The first Phase 2 wait must use the configured minimum interval.")
	scheduler.advance_time(PHASE_2_MAX_SEC)
	_expect(controller.attack == pattern_1,
		"The first Phase 2 request must select Pattern 1.")
	_expect(not pattern_2.is_detection_active(),
		"Pattern 2 must not be ACTIVE with Pattern 1.")
	controller.cancel_attack()
	var selected_delay: float = scheduler.get_last_selected_repeat_delay()
	_expect(selected_delay >= PHASE_2_MIN_SEC \
		and selected_delay <= PHASE_2_MAX_SEC,
		"Phase 2 repeat delay must remain within the configured range.")
	scheduler.advance_time(PHASE_2_MAX_SEC)
	_expect(controller.attack == pattern_2,
		"The next Phase 2 request must select Pattern 2.")
	_expect(integration.get_current_pattern_number() == 2,
		"Phase 2 debug state must report Pattern 2.")
	_expect(not pattern_1.is_detection_active(),
		"Only the selected Pattern 2 may become ACTIVE.")
	controller.cancel_attack()
	_expect(runtime.stop(false), "Phase 2 Runtime must stop cleanly.")


func _test_pattern_2_counter_flow(
	scene: Node2D,
	integration: TeddyPhase2RuntimePrototype,
	pattern_2: TeddyDoubleArmUpSweepAttack,
	tracker: BossArmHitBallTracker,
	reflector: BossArmBallReflector,
	window: BossCounterWindow,
	applier: BossCounterGatedDamageApplier,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	ball_flow: WaveBallFlowController,
	flipper: PinballFlipper,
	controller: BossAttackController
) -> void:
	_expect(controller.attack == pattern_2,
		"Pattern 2 must remain selected for its integration check.")
	_expect(tracker.is_bound() and reflector.is_bound(),
		"Tracker and Reflector must both follow the selected Pattern 2.")
	var ball: Pinball = await _create_ball(scene, Vector2(-120.0, -260.0))
	ball.gravity_scale = 0.0
	pattern_2.prepare_attack()
	pattern_2.begin_active(0.0)
	pattern_2.left_hit_area.body_entered.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"Pattern 2 attack_hit must track the same Ball.")
	await physics_frame
	_expect(ball.linear_velocity.x < 0.0 and ball.linear_velocity.y > 0.0,
		"Pattern 2 must reuse the below-outward reflection.")
	_emit_perfect(flipper, ball)
	_expect(window.is_ready() and not tracker.is_ball_tracked(ball),
		"PERFECT on the Pattern 2 Ball must ready Counter and consume tracking.")

	combo.reset_wave()
	health.configure(integration.phase1_rules.boss_max_hp)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == 11460,
		"Pattern 2 PERFECT must preserve the existing 540 Counter damage.")
	_expect(combo.combo_count == 1 and not window.is_ready(),
		"A valid Counter hit must increment Combo once and consume Counter.")
	hurtbox.body_exited.emit(ball)
	_deactivate_ball(ball_flow)
	pattern_2.begin_recovery(0.0)
	ball.queue_free()
	await process_frame


func _test_gate_preserves_counter(
	scene: Node2D,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	ball_flow: WaveBallFlowController,
	controller: BossAttackController
) -> void:
	var ball: Pinball = await _create_ball(scene, Vector2.ZERO)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	_activate_profile(ball_flow, definition, ball)
	window.activate()
	controller.pattern = _create_fast_pattern()
	_expect(controller.start_attack(), "Gate regression attack must start.")
	_expect(await _wait_for_state(controller, BossAttackController.State.ACTIVE),
		"Gate regression attack must reach ACTIVE.")
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health \
		and combo.combo_count == previous_combo,
		"ACTIVE Boss contact must preserve HP and Combo.")
	_expect(window.is_ready(), "ACTIVE damage blocking must preserve Counter.")
	hurtbox.body_exited.emit(ball)
	controller.cancel_attack()
	window.reset()
	_deactivate_ball(ball_flow)
	ball.queue_free()
	await process_frame


func _test_runtime_controls(
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler
) -> void:
	_expect(runtime.start(), "Runtime must remain startable after Phase 2 tests.")
	_expect(runtime.begin_new_ball_grace() and scheduler.is_grace_active(),
		"New Ball Grace must remain delegated to the Scheduler.")
	_expect(runtime.stop(true), "Stop must remain functional.")
	_expect(runtime.reset(true), "Reset must remain functional.")


func _test_teardown(
	integration: TeddyPhase2RuntimePrototype,
	transition: BossPhaseTransitionController,
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController
) -> void:
	integration.teardown()
	_expect(_count_connections_to(transition.phase_2_entered, integration) == 0,
		"Teardown must disconnect Phase Transition observation.")
	_expect(_count_connections_to(scheduler.state_changed, integration) == 0,
		"Teardown must disconnect Scheduler observation.")
	_expect(_count_connections_to(controller.attack_started, integration) == 0,
		"Teardown must disconnect Controller observation.")
	_expect(_count_connections_to(controller.attack_cancelled, integration) == 0,
		"Teardown must disconnect Controller cancellation observation.")


func _create_fast_pattern() -> BossAttackPattern:
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"phase2_gate_regression"
	pattern.telegraph_duration = 0.01
	pattern.active_duration = 0.05
	pattern.recovery_duration = 0.01
	pattern.cooldown_duration = 0.0
	return pattern


func _wait_for_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames: int = 120
) -> bool:
	for _frame: int in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _create_ball(scene: Node2D, position: Vector2) -> Pinball:
	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	scene.add_child(ball)
	ball.global_position = position
	await process_frame
	return ball


func _emit_perfect(flipper: PinballFlipper, ball: Pinball) -> void:
	flipper.parry_resolved.emit(
		ball,
		FlipperParryEvaluator.Grade.PERFECT,
		Vector2.ZERO,
		PinballFlipper.ContactZone.B,
		0.0,
		1.0
	)


func _find_definition(
	ball_flow: WaveBallFlowController,
	ball_id: StringName
) -> BallDefinition:
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


func _count_connections_to(signal_value: Signal, target: Object) -> int:
	var count: int = 0
	for connection: Dictionary in signal_value.get_connections():
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
		print("PASS: teddy_phase2_runtime_scene_test")
		quit(0)
		return
	print("FAIL: teddy_phase2_runtime_scene_test (%d failures)" % _failures.size())
	quit(1)
