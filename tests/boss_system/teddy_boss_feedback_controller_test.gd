extends SceneTree


const PRODUCTION_RUNTIME_SCENE: PackedScene = preload(
	"res://scenes/boss_system/stage1_teddy_boss_runtime.tscn"
)
const FeedbackControllerScript: Script = preload(
	"res://scripts/boss_system/feedback/teddy_boss_feedback_controller.gd"
)


class FeedbackRuntimeStub:
	extends Stage1TeddyBossRuntime

	var feedback_pattern_id: int = 1

	func get_current_pattern_number() -> int:
		return feedback_pattern_id


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_production_scene_composition()
	await _test_feedback_events_and_idempotent_setup()
	await _test_teardown_disconnects_sources()
	_finish()


func _test_production_scene_composition() -> void:
	var runtime: Stage1TeddyBossRuntime = PRODUCTION_RUNTIME_SCENE.instantiate()
	root.add_child(runtime)
	await process_frame
	var controller: Node = runtime.get_node(
		^"Feedback/TeddyBossFeedbackController"
	)
	var ports: Node = runtime.get_node(^"Feedback/TeddyBossFeedbackPorts")
	_expect(controller != null and controller.is_ready(),
		"The production Runtime must contain a ready Feedback Controller.")
	_expect(ports != null, "The production Runtime must contain Feedback ports.")
	for path: NodePath in [
		^"Visual/BossVisualRoot",
		^"Visual/TelegraphPattern1",
		^"Visual/TelegraphPattern2",
		^"Visual/ArmImpact",
		^"Visual/ArmReflection",
		^"Visual/BossNormalHit",
		^"Visual/BossCounterHit",
		^"Visual/CounterEarned",
		^"Visual/CounterExpired",
		^"Visual/Phase2Transition",
		^"Visual/CottonSpawn",
		^"Visual/CottonHit",
		^"Visual/BossDefeat",
		^"Audio/BattleStart",
		^"Audio/TelegraphPattern1",
		^"Audio/TelegraphPattern2",
		^"Audio/ArmSwing",
		^"Audio/ArmImpact",
		^"Audio/ArmReflection",
		^"Audio/BossNormalHit",
		^"Audio/BossCounterHit",
		^"Audio/CounterEarned",
		^"Audio/CounterExpired",
		^"Audio/Phase2Transition",
		^"Audio/CottonSpawn",
		^"Audio/CottonHit",
		^"Audio/BossDefeat",
	]:
		_expect(ports.has_node(path), "Missing Feedback slot: %s" % path)
	runtime.queue_free()
	await process_frame


func _test_feedback_events_and_idempotent_setup() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: Node = fixture.controller
	var runtime: FeedbackRuntimeStub = fixture.runtime
	var attack_controller: BossAttackController = fixture.attack_controller
	var pattern_1: TeddyArmSweepAttack = fixture.pattern_1
	var pattern_2: TeddyArmSweepAttack = fixture.pattern_2
	var reflector: BossArmBallReflector = fixture.reflector
	var damage_applier: BossDamageApplier = fixture.damage_applier
	var resolver: BossParryCounterResolver = fixture.resolver
	var counter_window: BossCounterWindow = fixture.counter_window
	var transition: BossPhaseTransitionController = fixture.transition
	var completion: BossBattleCompletionController = fixture.completion
	var cotton_parent: Node = fixture.cotton_parent
	var ball := Pinball.new()

	var battle_starts: Array[bool] = []
	var telegraphs: Array[int] = []
	var active_patterns: Array[int] = []
	var recovery_patterns: Array[int] = []
	var arm_hits: Array[Pinball] = []
	var reflections: Array[Pinball] = []
	var boss_hits: Array[Dictionary] = []
	var counter_earned: Array[bool] = []
	var counter_expired: Array[bool] = []
	var phase_2_events: Array[bool] = []
	var cotton_spawns: Array[bool] = []
	var cotton_hits: Array[bool] = []
	var defeats: Array[bool] = []

	controller.boss_battle_started.connect(func() -> void:
		battle_starts.append(true)
	)
	controller.attack_telegraph_started.connect(func(pattern_id: int) -> void:
		telegraphs.append(pattern_id)
	)
	controller.attack_active_started.connect(func(pattern_id: int) -> void:
		active_patterns.append(pattern_id)
	)
	controller.attack_recovery_started.connect(func(pattern_id: int) -> void:
		recovery_patterns.append(pattern_id)
	)
	controller.arm_ball_hit.connect(func(hit_ball: Pinball) -> void:
		arm_hits.append(hit_ball)
	)
	controller.arm_ball_reflected.connect(func(reflected_ball: Pinball) -> void:
		reflections.append(reflected_ball)
	)
	controller.boss_hit_feedback.connect(
		func(damage: int, was_counter: bool) -> void:
			boss_hits.append({&"damage": damage, &"counter": was_counter})
	)
	controller.counter_earned_feedback.connect(func() -> void:
		counter_earned.append(true)
	)
	controller.counter_expired_feedback.connect(func() -> void:
		counter_expired.append(true)
	)
	controller.phase_2_feedback.connect(func() -> void:
		phase_2_events.append(true)
	)
	controller.cotton_spawn_feedback.connect(func() -> void:
		cotton_spawns.append(true)
	)
	controller.cotton_hit_feedback.connect(func() -> void:
		cotton_hits.append(true)
	)
	controller.boss_defeated_feedback.connect(func() -> void:
		defeats.append(true)
	)

	_expect(controller.setup() and controller.setup(),
		"Repeated setup must be idempotent and preserve valid bindings.")
	runtime.visible = true
	runtime.visible = true
	runtime.feedback_pattern_id = FeedbackControllerScript.PATTERN_ARM_SWEEP
	attack_controller.telegraph_started.emit()
	runtime.feedback_pattern_id = (
		FeedbackControllerScript.PATTERN_DOUBLE_ARM_UP_SWEEP
	)
	attack_controller.telegraph_started.emit()
	attack_controller.active_started.emit()
	attack_controller.recovery_started.emit()
	pattern_1.attack_hit.emit(ball)
	pattern_2.attack_hit.emit(ball)
	reflector.ball_reflected.emit(ball)
	damage_applier.boss_hit_resolved.emit(400, 400, 12000, 11600, 12000, false)
	damage_applier.boss_hit_resolved.emit(540, 540, 11600, 11060, 12000, true)
	resolver.counter_earned.emit(ball)
	counter_window.counter_expired.emit()
	transition.phase_2_entered.emit(6000)
	transition.phase_2_entered.emit(5900)

	var cotton_1 := CursedCottonAdd.new()
	var cotton_2 := CursedCottonAdd.new()
	cotton_parent.add_child(cotton_1)
	cotton_parent.add_child(cotton_2)
	cotton_1.cotton_hit.emit(ball)
	completion.battle_completed.emit()
	completion.battle_completed.emit()

	_expect(battle_starts.size() == 1,
		"One visible battle lifecycle must report one start.")
	_expect(telegraphs == [1, 2],
		"Telegraph Feedback must distinguish Pattern 1 and Pattern 2.")
	_expect(active_patterns == [2] and recovery_patterns == [2],
		"ACTIVE and Recovery Feedback must include the current Pattern ID.")
	_expect(arm_hits.size() == 2 and arm_hits[0] == ball and arm_hits[1] == ball,
		"Both attacks must forward the exact Pinball instance.")
	_expect(reflections.size() == 1 and reflections[0] == ball,
		"The Reflector public signal must forward the exact reflected Ball once.")
	_expect(boss_hits.size() == 2 \
			and boss_hits[0].damage == 400 \
			and not boss_hits[0].counter \
			and boss_hits[1].damage == 540 \
			and boss_hits[1].counter,
		"Normal and Counter Boss hits must remain explicitly distinguishable.")
	_expect(counter_earned.size() == 1 and counter_expired.size() == 1,
		"Counter earned and expired events must each be forwarded once.")
	_expect(phase_2_events.size() == 1,
		"Phase 2 Feedback must be deduplicated within one battle lifecycle.")
	_expect(cotton_spawns.size() == 2 and cotton_hits.size() == 1,
		"Each spawned Cotton and each Cotton hit must be forwarded.")
	_expect(defeats.size() == 1,
		"Boss defeat Feedback must be deduplicated within one battle lifecycle.")

	cotton_parent.remove_child(cotton_1)
	cotton_parent.remove_child(cotton_2)
	cotton_1.free()
	cotton_2.free()
	ball.free()
	await _destroy_fixture(fixture)


func _test_teardown_disconnects_sources() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: Node = fixture.controller
	var runtime: FeedbackRuntimeStub = fixture.runtime
	var attack_controller: BossAttackController = fixture.attack_controller
	var pattern_1: TeddyArmSweepAttack = fixture.pattern_1
	var reflector: BossArmBallReflector = fixture.reflector
	var damage_applier: BossDamageApplier = fixture.damage_applier
	var feedback_count: Array[bool] = []
	controller.boss_battle_started.connect(func() -> void:
		feedback_count.append(true)
	)
	controller.attack_telegraph_started.connect(func(_pattern_id: int) -> void:
		feedback_count.append(true)
	)
	controller.arm_ball_hit.connect(func(_ball: Pinball) -> void:
		feedback_count.append(true)
	)
	controller.arm_ball_reflected.connect(func(_ball: Pinball) -> void:
		feedback_count.append(true)
	)
	controller.boss_hit_feedback.connect(
		func(_damage: int, _was_counter: bool) -> void:
			feedback_count.append(true)
	)
	controller.teardown()
	runtime.visible = true
	attack_controller.telegraph_started.emit()
	var ball := Pinball.new()
	pattern_1.attack_hit.emit(ball)
	reflector.ball_reflected.emit(ball)
	damage_applier.boss_hit_resolved.emit(400, 400, 12000, 11600, 12000, false)
	_expect(feedback_count.is_empty(),
		"teardown must disconnect every observed Gameplay source.")
	_expect(not controller.is_ready(), "teardown must clear ready state.")
	ball.free()
	await _destroy_fixture(fixture)


func _create_fixture() -> Dictionary:
	var fixture_root := Node.new()
	root.add_child(fixture_root)
	var runtime := FeedbackRuntimeStub.new()
	runtime.visible = false
	fixture_root.add_child(runtime)
	var attack_controller := BossAttackController.new()
	var damage_applier := BossDamageApplier.new()
	var reflector := BossArmBallReflector.new()
	var resolver := BossParryCounterResolver.new()
	var counter_window := BossCounterWindow.new()
	var transition := BossPhaseTransitionController.new()
	var completion := BossBattleCompletionController.new()
	var cotton_parent := Node.new()
	fixture_root.add_child(attack_controller)
	fixture_root.add_child(damage_applier)
	fixture_root.add_child(reflector)
	fixture_root.add_child(resolver)
	fixture_root.add_child(counter_window)
	fixture_root.add_child(transition)
	fixture_root.add_child(completion)
	fixture_root.add_child(cotton_parent)
	var pattern_1 := TeddyArmSweepAttack.new()
	var pattern_2 := TeddyArmSweepAttack.new()
	var controller: Node = FeedbackControllerScript.new()
	controller.boss_runtime = runtime
	controller.attack_controller = attack_controller
	controller.pattern_1_attack = pattern_1
	controller.pattern_2_attack = pattern_2
	controller.arm_ball_reflector = reflector
	controller.damage_applier = damage_applier
	controller.counter_resolver = resolver
	controller.counter_window = counter_window
	controller.phase_transition = transition
	controller.completion_controller = completion
	controller.cotton_parent = cotton_parent
	fixture_root.add_child(controller)
	return {
		&"root": fixture_root,
		&"runtime": runtime,
		&"attack_controller": attack_controller,
		&"pattern_1": pattern_1,
		&"pattern_2": pattern_2,
		&"reflector": reflector,
		&"damage_applier": damage_applier,
		&"resolver": resolver,
		&"counter_window": counter_window,
		&"transition": transition,
		&"completion": completion,
		&"cotton_parent": cotton_parent,
		&"controller": controller,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	var controller: Node = fixture.controller
	controller.teardown()
	var pattern_1: TeddyArmSweepAttack = fixture.pattern_1
	var pattern_2: TeddyArmSweepAttack = fixture.pattern_2
	pattern_1.free()
	pattern_2.free()
	var fixture_root: Node = fixture.root
	fixture_root.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_boss_feedback_controller_test")
		quit(0)
		return
	for failure: String in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
