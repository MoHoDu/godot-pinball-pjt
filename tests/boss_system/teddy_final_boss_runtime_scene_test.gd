extends SceneTree


const FinalBossScene: PackedScene = preload(
	"res://scenes/wave/test_teddy_final_boss_runtime.tscn"
)
const NormalBallScene: PackedScene = preload(
	"res://Resources/balls/mass_var/normal_ball.tscn"
)
const PHASE_2_MAX_INTERVAL_SEC: float = 3.8


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(FinalBossScene != null and FinalBossScene.can_instantiate(),
		"The final Teddy Boss scene must load and instantiate.")
	if FinalBossScene == null or not FinalBossScene.can_instantiate():
		_finish()
		return

	var scene: Node2D = FinalBossScene.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var prototype := scene.get_node_or_null("CottonIntegration") \
		as TeddyFinalBossRuntimePrototype
	var cotton_parent := scene.get_node_or_null("CottonContainer") as Node2D
	var spawn_left := scene.get_node_or_null("CursedCottonSpawnLeft") as Marker2D
	var spawn_right := scene.get_node_or_null("CursedCottonSpawnRight") as Marker2D
	var cotton_label := scene.get_node_or_null(
		"CottonDebugCanvas/Panel/VBox/CottonLabel"
	) as Label
	var cotton_log := scene.get_node_or_null(
		"CottonDebugCanvas/Panel/VBox/EventLog"
	) as RichTextLabel
	var completion := scene.get_node_or_null(
		"BattleRuntime/CompletionIntegration/BossBattleCompletionController"
	) as BossBattleCompletionController
	var transition := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase2Integration/"
		+ "BossPhaseTransitionController"
	) as BossPhaseTransitionController
	var health := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Damage/BossHealthComponent"
	) as BossHealthComponent
	var runtime := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var scheduler := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Attack/Scheduler"
	) as BossPhase1AttackScheduler
	var controller := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "BossAttackController"
	) as BossAttackController
	var pattern_1 := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var pattern_2 := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/TeddyDoubleArmUpSweepAttack"
	) as TeddyDoubleArmUpSweepAttack
	var tracker := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Damage/BossArmHitBallTracker"
	) as BossArmHitBallTracker
	var reflector := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Damage/BossArmBallReflector"
	) as BossArmBallReflector
	var window := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/"
		+ "Phase1Damage/BossCounterWindow"
	) as BossCounterWindow
	var combo := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/ComboSystem"
	) as ComboSystem
	var hurtbox := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/BossHurtbox"
	) as Area2D
	var ball_flow := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/WaveBallFlowController"
	) as WaveBallFlowController
	var flipper := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/FlipperSelector/"
		+ "BottomController/LeftFlipper"
	) as PinballFlipper
	var reset_button := scene.get_node_or_null(
		"BattleRuntime/Phase2Runtime/Phase1Runtime/BossPrototype/DebugCanvas/"
		+ "DebugUI/Panel/VBox/ButtonRow/ResetButton"
	) as Button

	for check: Array in [
		[prototype, "Cotton integration Prototype must exist."],
		[cotton_parent, "Cotton container must exist."],
		[spawn_left, "Left Cotton spawn point must exist."],
		[spawn_right, "Right Cotton spawn point must exist."],
		[cotton_label, "Cotton status Label must exist."],
		[cotton_log, "Cotton Event Log must exist."],
		[completion, "Existing Battle Completion must be reused."],
		[transition, "Existing Phase Transition must be reused."],
		[health, "Existing Health must be reused."],
		[runtime, "Existing Attack Runtime must be reused."],
		[scheduler, "Existing Scheduler must be reused."],
		[controller, "Existing Controller must be reused."],
		[pattern_1, "Pattern 1 must be preserved."],
		[pattern_2, "Pattern 2 must be preserved."],
		[tracker, "Existing Tracker must be preserved."],
		[reflector, "Existing Reflector must be preserved."],
		[window, "Existing Counter Window must be preserved."],
		[combo, "Existing Combo System must be preserved."],
		[hurtbox, "Existing Boss Hurtbox must be preserved."],
		[ball_flow, "Existing Ball Flow must be preserved."],
		[flipper, "Existing Flipper must be preserved."],
		[reset_button, "Existing Reset button must be reused."],
	]:
		_expect(check[0] != null, String(check[1]))

	if prototype == null or cotton_parent == null or spawn_left == null \
			or spawn_right == null or cotton_label == null or cotton_log == null \
			or completion == null or transition == null or health == null \
			or runtime == null or scheduler == null or controller == null \
			or pattern_1 == null or pattern_2 == null or tracker == null \
			or reflector == null or window == null or combo == null \
			or hurtbox == null or ball_flow == null or flipper == null \
			or reset_button == null:
		scene.queue_free()
		await process_frame
		_finish()
		return

	_test_initial_phase(prototype, health, transition, cotton_parent, cotton_label)
	_test_phase_2_spawns_once(
		prototype, health, transition, cotton_parent,
		spawn_left, spawn_right, cotton_log
	)
	await _test_one_cotton_hit_is_independent(
		scene, prototype, cotton_parent, health, combo, window, cotton_log
	)
	await _test_phase_2_attack_counter_and_gate(
		scene, runtime, scheduler, controller, pattern_1, pattern_2,
		tracker, reflector, window, health, combo, hurtbox, ball_flow, flipper
	)
	await _test_defeat_clears_remaining_cotton(
		prototype, completion, health, scheduler, cotton_parent
	)
	await _test_reset_and_second_phase_2(
		scene, prototype, completion, transition, health,
		cotton_parent, reset_button
	)
	_test_teardown(prototype, transition, completion, cotton_parent)

	scene.queue_free()
	await process_frame
	_finish()


func _test_initial_phase(
	prototype: TeddyFinalBossRuntimePrototype,
	health: BossHealthComponent,
	transition: BossPhaseTransitionController,
	cotton_parent: Node2D,
	cotton_label: Label
) -> void:
	_expect(not transition.is_phase_2() and health.get_health_ratio() == 1.0,
		"The final Runtime must begin in Phase 1.")
	_expect(prototype.get_active_cotton_count() == 0 \
		and cotton_parent.get_child_count() == 0,
		"Phase 1 must begin with no Cotton.")
	_expect(cotton_label.text == "Cotton: 0 / 2",
		"The Cotton UI must report zero in Phase 1.")
	health.apply_damage(5999)
	_expect(health.get_current_health() == 6001 \
		and prototype.get_active_cotton_count() == 0,
		"HP above the threshold must not spawn Cotton.")


func _test_phase_2_spawns_once(
	prototype: TeddyFinalBossRuntimePrototype,
	health: BossHealthComponent,
	transition: BossPhaseTransitionController,
	cotton_parent: Node2D,
	spawn_left: Marker2D,
	spawn_right: Marker2D,
	cotton_log: RichTextLabel
) -> void:
	health.apply_damage(1)
	_expect(transition.is_phase_2(), "HP 6000 must enter Phase 2.")
	var cottons: Array[CursedCottonAdd] = _get_cottons(cotton_parent)
	_expect(cottons.size() == 2 and prototype.get_active_cotton_count() == 2,
		"Phase 2 entry must spawn exactly two Cotton instances.")
	var positions: Array[Vector2] = [
		cottons[0].global_position,
		cottons[1].global_position,
	]
	_expect(positions.has(spawn_left.global_position) \
		and positions.has(spawn_right.global_position),
		"Cotton instances must use the explicit left and right spawn points.")
	health.apply_damage(100)
	_expect(prototype.get_active_cotton_count() == 2,
		"Further Phase 2 damage must not spawn additional Cotton.")
	_expect(_count_occurrences(
		cotton_log.text, "CURSED COTTON SPAWNED: 2"
	) == 1, "The spawn event must be logged once per battle.")


func _test_one_cotton_hit_is_independent(
	scene: Node2D,
	prototype: TeddyFinalBossRuntimePrototype,
	cotton_parent: Node2D,
	health: BossHealthComponent,
	combo: ComboSystem,
	window: BossCounterWindow,
	cotton_log: RichTextLabel
) -> void:
	var cottons: Array[CursedCottonAdd] = _get_cottons(cotton_parent)
	var hit_cotton: CursedCottonAdd = cottons[0]
	var untouched_cotton: CursedCottonAdd = cottons[1]
	var ball: Pinball = await _create_ball(
		scene, hit_cotton.global_position + Vector2(100.0, 0.0)
	)
	ball.linear_velocity = Vector2(0.0, 900.0)
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	var counter_was_ready: bool = window.is_ready()
	hit_cotton.body_entered.emit(ball)
	hit_cotton.body_entered.emit(ball)
	await physics_frame
	await physics_frame
	await process_frame
	_expect(ball.linear_velocity.x > 0.0,
		"Cotton A must reflect the Ball outward.")
	_expect(prototype.get_active_cotton_count() == 1 \
		and is_instance_valid(untouched_cotton),
		"Cotton A removal must leave Cotton B active.")
	_expect(health.get_current_health() == previous_health \
		and combo.combo_count == previous_combo \
		and window.is_ready() == counter_was_ready,
		"Cotton collision must not change HP, Combo, or Counter.")
	_expect(_count_occurrences(cotton_log.text, "CURSED COTTON HIT") == 1 \
		and _count_occurrences(cotton_log.text, "CURSED COTTON CLEARED") == 1,
		"One Cotton contact must log one hit and one clear.")
	ball.queue_free()
	await process_frame


func _test_phase_2_attack_counter_and_gate(
	scene: Node2D,
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController,
	pattern_1: TeddyArmSweepAttack,
	pattern_2: TeddyDoubleArmUpSweepAttack,
	tracker: BossArmHitBallTracker,
	reflector: BossArmBallReflector,
	window: BossCounterWindow,
	health: BossHealthComponent,
	combo: ComboSystem,
	hurtbox: Area2D,
	ball_flow: WaveBallFlowController,
	flipper: PinballFlipper
) -> void:
	_expect(runtime.start(), "The Phase 2 attack loop must start.")
	scheduler.advance_time(PHASE_2_MAX_INTERVAL_SEC)
	_expect(controller.attack == pattern_1,
		"The first Phase 2 request must preserve Pattern 1.")
	controller.cancel_attack()
	scheduler.advance_time(PHASE_2_MAX_INTERVAL_SEC)
	_expect(controller.attack == pattern_2,
		"The next Phase 2 request must select Pattern 2.")
	controller.cancel_attack()
	_expect(runtime.stop(false), "The Phase 2 fixture must stop cleanly.")
	_expect(tracker.is_bound() and reflector.is_bound(),
		"Pattern 2 must retain Tracker and Reflector bindings.")

	var ball: Pinball = await _create_ball(
		scene, pattern_2.global_position + Vector2(-100.0, 0.0)
	)
	ball.gravity_scale = 0.0
	pattern_2.prepare_attack()
	pattern_2.begin_active(0.0)
	pattern_2.left_hit_area.body_entered.emit(ball)
	await physics_frame
	await physics_frame
	_expect(tracker.is_ball_tracked(ball) \
		and ball.linear_velocity.x < 0.0 \
		and ball.linear_velocity.y > 0.0,
		"Pattern 2 must preserve Ball tracking and reflection.")
	_emit_perfect(flipper, ball)
	_expect(window.is_ready() and not tracker.is_ball_tracked(ball),
		"PERFECT on the reflected Ball must ready Counter.")

	combo.reset_wave()
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	_activate_profile(ball_flow, definition, ball)
	var previous_health: int = health.get_current_health()
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health - 540 \
		and combo.combo_count == 1 \
		and not window.is_ready(),
		"The final Runtime must preserve the existing 1.35 Counter hit.")
	hurtbox.body_exited.emit(ball)

	window.activate()
	controller.pattern = _create_fast_pattern()
	_expect(controller.start_attack(), "The ACTIVE Gate fixture must start.")
	_expect(await _wait_for_state(controller, BossAttackController.State.ACTIVE),
		"The ACTIVE Gate fixture must reach ACTIVE.")
	previous_health = health.get_current_health()
	var previous_combo: int = combo.combo_count
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health \
		and combo.combo_count == previous_combo \
		and window.is_ready(),
		"ACTIVE Boss contact must preserve HP, Combo, and Counter.")
	hurtbox.body_exited.emit(ball)
	controller.cancel_attack()
	window.reset()
	pattern_2.cancel_attack()
	_deactivate_ball(ball_flow)
	ball.queue_free()
	await process_frame


func _test_defeat_clears_remaining_cotton(
	prototype: TeddyFinalBossRuntimePrototype,
	completion: BossBattleCompletionController,
	health: BossHealthComponent,
	scheduler: BossPhase1AttackScheduler,
	cotton_parent: Node2D
) -> void:
	_expect(prototype.get_active_cotton_count() == 1,
		"One Cotton must remain before the defeat cleanup test.")
	health.apply_damage(health.get_current_health())
	await process_frame
	_expect(completion.is_completed(), "HP zero must complete the Boss battle.")
	_expect(prototype.get_active_cotton_count() == 0 \
		and cotton_parent.get_child_count() == 0,
		"Boss defeat must remove every remaining Cotton safely.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Final Boss completion must preserve complete attack shutdown.")
	health.apply_damage(1)
	_expect(prototype.get_active_cotton_count() == 0,
		"No Cotton may spawn after Boss defeat.")


func _test_reset_and_second_phase_2(
	scene: Node2D,
	prototype: TeddyFinalBossRuntimePrototype,
	completion: BossBattleCompletionController,
	transition: BossPhaseTransitionController,
	health: BossHealthComponent,
	cotton_parent: Node2D,
	reset_button: Button
) -> void:
	reset_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	_expect(not completion.is_completed() \
		and not transition.is_phase_2() \
		and health.get_health_ratio() == 1.0,
		"Reset must restore a live Phase 1 battle.")
	_expect(prototype.get_active_cotton_count() == 0,
		"Reset must leave no Cotton or stale references.")
	health.apply_damage(6000)
	_expect(prototype.get_active_cotton_count() == 2,
		"The reset battle must spawn two fresh Cotton on Phase 2 entry.")

	var cottons: Array[CursedCottonAdd] = _get_cottons(cotton_parent)
	var balls: Array[Pinball] = []
	for index: int in cottons.size():
		var direction: float = -1.0 if index == 0 else 1.0
		var ball: Pinball = await _create_ball(
			scene,
			cottons[index].global_position + Vector2(direction * 80.0, 0.0)
		)
		ball.linear_velocity = Vector2(0.0, 800.0)
		balls.append(ball)
		cottons[index].body_entered.emit(ball)
	await physics_frame
	await process_frame
	_expect(prototype.get_active_cotton_count() == 0,
		"Both consumed Cotton instances must leave an empty list.")
	await process_frame
	_expect(prototype.get_active_cotton_count() == 0,
		"Consumed Cotton must never respawn automatically.")
	for ball: Pinball in balls:
		ball.queue_free()
	await process_frame


func _test_teardown(
	prototype: TeddyFinalBossRuntimePrototype,
	transition: BossPhaseTransitionController,
	completion: BossBattleCompletionController,
	cotton_parent: Node2D
) -> void:
	prototype.teardown()
	_expect(prototype.get_active_cotton_count() == 0 \
		and cotton_parent.get_child_count() == 0,
		"Cotton teardown must clear all managed instances.")
	_expect(_count_connections_to(transition.phase_2_entered, prototype) == 0,
		"Cotton teardown must disconnect Phase observation.")
	_expect(_count_connections_to(completion.battle_completed, prototype) == 0,
		"Cotton teardown must disconnect Completion observation.")


func _get_cottons(parent: Node) -> Array[CursedCottonAdd]:
	var cottons: Array[CursedCottonAdd] = []
	for child: Node in parent.get_children():
		if child is CursedCottonAdd:
			cottons.append(child as CursedCottonAdd)
	return cottons


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


func _create_fast_pattern() -> BossAttackPattern:
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"final_boss_gate_test"
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


func _count_occurrences(text: String, fragment: String) -> int:
	return text.count(fragment)


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
		print("PASS: teddy_final_boss_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_final_boss_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
