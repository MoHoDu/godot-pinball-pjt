extends SceneTree


const BattleRuntimeScene: PackedScene = preload(
	"res://scenes/tests/boss/test_teddy_battle_completion_runtime.tscn"
)
const NormalBallScene: PackedScene = preload(
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(BattleRuntimeScene != null and BattleRuntimeScene.can_instantiate(),
		"The Battle Completion scene must load and instantiate.")
	if BattleRuntimeScene == null or not BattleRuntimeScene.can_instantiate():
		_finish()
		return

	var scene: Node2D = BattleRuntimeScene.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var prototype := scene.get_node_or_null("CompletionIntegration") \
		as TeddyBattleCompletionRuntimePrototype
	var completion := scene.get_node_or_null(
		"CompletionIntegration/BossBattleCompletionController"
	) as BossBattleCompletionController
	var health := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Damage/"
		+ "BossHealthComponent"
	) as BossHealthComponent
	var phase_transition := scene.get_node_or_null(
		"Phase2Runtime/Phase2Integration/BossPhaseTransitionController"
	) as BossPhaseTransitionController
	var runtime := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var scheduler := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Attack/Scheduler"
	) as BossPhase1AttackScheduler
	var controller := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/BossAttackController"
	) as BossAttackController
	var tracker := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Damage/"
		+ "BossArmHitBallTracker"
	) as BossArmHitBallTracker
	var reflector := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Damage/"
		+ "BossArmBallReflector"
	) as BossArmBallReflector
	var counter_window := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Damage/"
		+ "BossCounterWindow"
	) as BossCounterWindow
	var damage_applier := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/Phase1Damage/"
		+ "BossDamageApplier"
	) as BossCounterGatedDamageApplier
	var combo := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/ComboSystem"
	) as ComboSystem
	var pattern_1 := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var start_button := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/DebugCanvas/DebugUI/"
		+ "Panel/VBox/ButtonRow/StartButton"
	) as Button
	var reset_button := scene.get_node_or_null(
		"Phase2Runtime/Phase1Runtime/BossPrototype/DebugCanvas/DebugUI/"
		+ "Panel/VBox/ButtonRow/ResetButton"
	) as Button
	var battle_label := scene.get_node_or_null(
		"BattleDebugCanvas/Panel/VBox/BattleLabel"
	) as Label
	var battle_log := scene.get_node_or_null(
		"BattleDebugCanvas/Panel/VBox/EventLog"
	) as RichTextLabel

	for check: Array in [
		[prototype, "Completion integration Prototype must exist."],
		[completion, "Battle Completion Controller must exist."],
		[health, "Existing Boss Health must be reused."],
		[phase_transition, "Existing Phase Transition must be reused."],
		[runtime, "Existing Attack Runtime must be reused."],
		[scheduler, "Existing Scheduler must be reused."],
		[controller, "Existing Attack Controller must be reused."],
		[tracker, "Existing Tracker must be reused."],
		[reflector, "Existing Reflector must be reused."],
		[counter_window, "Existing Counter Window must be reused."],
		[damage_applier, "Existing Damage Applier must be reused."],
		[combo, "Existing Combo System must be reused."],
		[pattern_1, "Existing Pattern 1 must be reused."],
		[start_button, "Existing Start button must be reused."],
		[reset_button, "Existing Reset button must be reused."],
		[battle_label, "Battle status Label must exist."],
		[battle_log, "Battle Event Log must exist."],
	]:
		_expect(check[0] != null, String(check[1]))

	if prototype == null or completion == null or health == null \
			or phase_transition == null or runtime == null or scheduler == null \
			or controller == null or tracker == null or reflector == null \
			or counter_window == null or damage_applier == null or combo == null \
			or pattern_1 == null or start_button == null or reset_button == null \
			or battle_label == null or battle_log == null:
		scene.queue_free()
		await process_frame
		_finish()
		return

	var completions: Array[bool] = []
	completion.battle_completed.connect(func() -> void:
		completions.append(true)
	)
	_expect(not completion.is_completed() and completion.is_bound(),
		"The integrated battle must initially be active and bound.")

	await _test_phase_1_defeat_stops_combat(
		scene, completion, health, phase_transition, runtime, scheduler,
		controller, tracker, reflector, counter_window, damage_applier,
		combo, pattern_1, start_button, battle_label, battle_log, completions
	)
	await _test_reset_restores_battle(
		completion, health, runtime, tracker, reflector, reset_button,
		start_button, battle_label
	)
	_test_phase_2_defeat_once(
		completion, health, phase_transition, runtime, scheduler, completions
	)
	_test_teardown(prototype, completion)

	scene.queue_free()
	await process_frame
	_finish()


func _test_phase_1_defeat_stops_combat(
	scene: Node2D,
	completion: BossBattleCompletionController,
	health: BossHealthComponent,
	phase_transition: BossPhaseTransitionController,
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController,
	tracker: BossArmHitBallTracker,
	reflector: BossArmBallReflector,
	counter_window: BossCounterWindow,
	damage_applier: BossCounterGatedDamageApplier,
	combo: ComboSystem,
	pattern_1: TeddyArmSweepAttack,
	start_button: Button,
	battle_label: Label,
	battle_log: RichTextLabel,
	completions: Array[bool]
) -> void:
	_expect(runtime.start(), "The Phase 1 attack loop must start.")
	scheduler.advance_time(3.0)
	_expect(controller.current_state != BossAttackController.State.IDLE,
		"The fixture must have an in-flight attack before defeat.")
	counter_window.activate()
	var previous_phase_2: bool = phase_transition.is_phase_2()
	health.apply_damage(health.get_current_health())

	_expect(completion.is_completed() and completions.size() == 1,
		"Phase 1 defeat must complete exactly once.")
	_expect(not previous_phase_2 and not phase_transition.is_phase_2(),
		"Lethal Phase 1 damage must not enter Phase 2.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Defeat must fully stop the Scheduler.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"Defeat must safely cancel the current attack.")
	_expect(not runtime.is_ready() and not runtime.start(),
		"Teardown must prevent any new Pattern from starting.")
	_expect(not tracker.is_bound() and not reflector.is_bound(),
		"Defeat must unbind tracking and reflection.")
	_expect(not counter_window.is_ready(),
		"Defeat must reset Counter without consume/expire semantics.")
	_expect(start_button.disabled, "The completed battle must disable Start.")
	_expect(battle_label.text == "Battle: COMPLETED",
		"The Debug UI must report completion.")
	_expect(_count_occurrences(battle_log.text, "BOSS DEFEATED") == 1 \
		and _count_occurrences(battle_log.text, "BATTLE COMPLETED") == 1,
		"Both completion log entries must appear exactly once.")

	var previous_combo: int = combo.combo_count
	_expect(damage_applier.resolve_and_apply_hit(30, 1.0) == 0,
		"Damage after defeat must be rejected by the existing Health contract.")
	_expect(health.get_current_health() == 0 and combo.combo_count == previous_combo,
		"Post-defeat damage must preserve HP zero and Combo.")

	var ball: Pinball = NormalBallScene.instantiate() as Pinball
	scene.add_child(ball)
	ball.global_position = Vector2(-100.0, -260.0)
	var previous_velocity: Vector2 = ball.linear_velocity
	pattern_1.prepare_attack()
	pattern_1.begin_active(0.0)
	pattern_1.attack_hit.emit(ball)
	await physics_frame
	_expect(not tracker.is_ball_tracked(ball),
		"Attack hits after completion must not create tracking.")
	_expect(ball.linear_velocity.is_equal_approx(previous_velocity),
		"Attack hits after completion must not reflect the Ball.")
	pattern_1.cancel_attack()
	ball.queue_free()
	await process_frame
	health.apply_damage(1)
	_expect(completions.size() == 1,
		"Further damage after defeat must not repeat completion.")


func _test_reset_restores_battle(
	completion: BossBattleCompletionController,
	health: BossHealthComponent,
	runtime: BossPhase1AttackRuntime,
	tracker: BossArmHitBallTracker,
	reflector: BossArmBallReflector,
	reset_button: Button,
	start_button: Button,
	battle_label: Label
) -> void:
	reset_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	_expect(not completion.is_completed() and health.get_health_ratio() == 1.0,
		"Reset must restore a live Boss and active battle state.")
	_expect(runtime.is_ready(), "Reset must reassemble the Attack Runtime.")
	_expect(tracker.is_bound() and reflector.is_bound(),
		"Reset must restore Pattern tracking and reflection bindings.")
	_expect(not start_button.disabled and battle_label.text == "Battle: ACTIVE",
		"Reset must restore controls and active Battle UI.")


func _test_phase_2_defeat_once(
	completion: BossBattleCompletionController,
	health: BossHealthComponent,
	phase_transition: BossPhaseTransitionController,
	runtime: BossPhase1AttackRuntime,
	scheduler: BossPhase1AttackScheduler,
	completions: Array[bool]
) -> void:
	var phase_entries: Array[int] = []
	phase_transition.phase_2_entered.connect(func(current_hp: int) -> void:
		phase_entries.append(current_hp)
	)
	health.apply_damage(6000)
	_expect(phase_transition.is_phase_2() and phase_entries == [6000],
		"The reset battle must enter Phase 2 normally.")
	health.apply_damage(6000)
	_expect(completion.is_completed() and completions.size() == 2,
		"Phase 2 defeat must complete its lifecycle exactly once.")
	_expect(not runtime.is_ready() \
		and scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Phase 2 defeat must stop and teardown attacks identically.")
	health.apply_damage(1)
	_expect(completions.size() == 2 and phase_entries.size() == 1,
		"Post-defeat events must not repeat completion or Phase 2 entry.")


func _test_teardown(
	prototype: TeddyBattleCompletionRuntimePrototype,
	completion: BossBattleCompletionController
) -> void:
	prototype.teardown()
	_expect(not completion.is_bound(),
		"Prototype teardown must remove the Health defeat connection.")
	_expect(_count_connections_to(completion.battle_completed, prototype) == 0,
		"Prototype teardown must disconnect completion observation.")


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
		print("PASS: teddy_battle_completion_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_battle_completion_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
