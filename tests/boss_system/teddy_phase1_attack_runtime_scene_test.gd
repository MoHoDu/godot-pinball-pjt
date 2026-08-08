extends SceneTree

const RuntimeScene: PackedScene = preload(
	"res://scenes/tests/boss/test_teddy_phase1_attack_runtime.tscn"
)
const RULES_PATH: String = \
	"res://settings/bosses/Stage1BossPhase1Rules.tres"
const FIRST_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1FirstPattern.tres"
const REPEAT_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1RepeatPattern.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(RuntimeScene != null and RuntimeScene.can_instantiate(),
		"The phase 1 runtime scene must load and instantiate.")
	if RuntimeScene == null or not RuntimeScene.can_instantiate():
		_finish()
		return

	var wave: Node2D = RuntimeScene.instantiate() as Node2D
	_expect(wave != null, "The phase 1 runtime scene root must be a Node2D.")
	if wave == null:
		_finish()
		return

	root.add_child(wave)
	await process_frame
	await process_frame

	var prototype: TeddyPhase1AttackRuntimePrototype = wave.get_node_or_null(
		"BossPrototype"
	) as TeddyPhase1AttackRuntimePrototype
	_expect(prototype != null,
		"BossPrototype must use TeddyPhase1AttackRuntimePrototype.")
	if prototype == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	var runtime: BossPhase1AttackRuntime = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var scheduler: BossPhase1AttackScheduler = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Scheduler"
	) as BossPhase1AttackScheduler
	var coordinator: BossPhase1AttackCoordinator = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Coordinator"
	) as BossPhase1AttackCoordinator
	var selector: BossPhase1AttackPatternSelector = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/PatternSelector"
	) as BossPhase1AttackPatternSelector
	var controller: BossAttackController = wave.get_node_or_null(
		"BossPrototype/BossAttackController"
	) as BossAttackController
	var teddy_attack: TeddyArmSweepAttack = wave.get_node_or_null(
		"BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack

	_expect(runtime != null, "The scene must contain the Runtime Node.")
	_expect(scheduler != null, "The scene must contain the Scheduler Node.")
	_expect(coordinator != null, "The scene must contain the Coordinator Node.")
	_expect(selector != null, "The scene must contain the PatternSelector Node.")
	_expect(controller != null, "The scene must contain BossAttackController.")
	_expect(teddy_attack != null, "The scene must contain TeddyArmSweepAttack.")
	if runtime == null \
			or scheduler == null \
			or coordinator == null \
			or selector == null \
			or controller == null \
			or teddy_attack == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_expect(prototype.runtime == runtime, "Prototype must reference the Runtime Node.")
	_expect(prototype.scheduler == scheduler, "Prototype must reference the Scheduler Node.")
	_expect(prototype.coordinator == coordinator,
		"Prototype must reference the Coordinator Node.")
	_expect(prototype.selector == selector,
		"Prototype must reference the PatternSelector Node.")
	_expect(prototype.controller == controller,
		"Prototype must reference BossAttackController.")
	_expect(prototype.teddy_attack == teddy_attack,
		"Prototype must reference TeddyArmSweepAttack.")

	_expect(prototype.rules != null and prototype.rules.resource_path == RULES_PATH,
		"Prototype must reference Stage1BossPhase1Rules.tres.")
	_expect(prototype.first_pattern != null
		and prototype.first_pattern.resource_path == FIRST_PATTERN_PATH,
		"Prototype must reference the First Pattern resource.")
	_expect(prototype.repeat_pattern != null
		and prototype.repeat_pattern.resource_path == REPEAT_PATTERN_PATH,
		"Prototype must reference the Repeat Pattern resource.")

	_expect(runtime.is_ready(), "Runtime setup must be ready after scene _ready.")
	_expect(not runtime.is_running(), "Runtime must initially be stopped.")
	_expect(scheduler.is_configured(), "Scheduler must be configured by Runtime setup.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Scheduler must initially be STOPPED.")
	_expect(selector.is_bound(), "PatternSelector must be bound after setup.")
	_expect(coordinator.is_bound(), "Coordinator must be bound after setup.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"Controller must initially be IDLE.")
	_expect(controller.attack == teddy_attack,
		"Controller attack must be the authored TeddyArmSweepAttack Node.")
	_expect(controller.pattern == null,
		"Controller Pattern must remain null before the first request.")

	_expect(prototype.start_button != null, "StartButton must be connected.")
	_expect(prototype.stop_button != null, "StopButton must be connected.")
	_expect(prototype.reset_button != null, "ResetButton must be connected.")
	_expect(prototype.new_ball_grace_button != null,
		"NewBallGraceButton must be connected.")
	_expect(prototype.runtime_state_label != null, "RuntimeStateLabel must exist.")
	_expect(prototype.scheduler_state_label != null, "SchedulerStateLabel must exist.")
	_expect(prototype.controller_state_label != null, "ControllerStateLabel must exist.")
	_expect(prototype.current_pattern_label != null, "CurrentPatternLabel must exist.")
	_expect(prototype.remaining_wait_label != null, "RemainingWaitLabel must exist.")
	_expect(prototype.remaining_grace_label != null, "RemainingGraceLabel must exist.")
	_expect(prototype.last_repeat_delay_label != null,
		"LastRepeatDelayLabel must exist.")
	_expect(prototype.event_log != null, "EventLog must exist.")
	_expect(wave.get_node_or_null(
		"BossPrototype/DebugUI/Panel/VBox/AttackButton"
	) == null, "The legacy direct AttackButton must not exist.")

	_check_rule_values(prototype.rules)
	_check_pattern_values(prototype.first_pattern, 1.10, "First")
	_check_pattern_values(prototype.repeat_pattern, 0.85, "Repeat")

	prototype.start_button.emit_signal(&"pressed")
	_expect(runtime.is_running(), "StartButton must start the Runtime only.")
	_expect(scheduler.get_current_state()
		== BossPhase1AttackScheduler.State.WAITING_FIRST_ATTACK,
		"StartButton must enter WAITING_FIRST_ATTACK.")
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0,
		"StartButton must use the authored first delay.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"StartButton must not directly start the Controller.")
	_expect(controller.pattern == null,
		"First Pattern must not apply before the first request.")

	prototype.stop_button.emit_signal(&"pressed")
	_expect(not runtime.is_running(), "StopButton must stop the Runtime.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"StopButton must restore Scheduler STOPPED.")
	_expect(prototype.event_log.text.contains("SETUP SUCCEEDED"),
		"EventLog must record successful setup.")
	_expect(prototype.event_log.text.contains("START: SUCCESS"),
		"EventLog must record the Start result.")
	_expect(prototype.event_log.text.contains("STOP: SUCCESS"),
		"EventLog must record the Stop result.")

	runtime.teardown(true)
	_expect(not runtime.is_ready(), "Explicit teardown must clear Runtime readiness.")
	_expect(not selector.is_bound(), "Explicit teardown must unbind PatternSelector.")
	_expect(not coordinator.is_bound(), "Explicit teardown must unbind Coordinator.")

	wave.queue_free()
	await process_frame
	_finish()


func _check_rule_values(rules: Stage1BossPhase1Rules) -> void:
	if rules == null:
		return
	_expect_approx(rules.first_attack_delay_sec, 3.0,
		"Rules must retain the first attack delay.")
	_expect_approx(rules.new_ball_grace_sec, 2.5,
		"Rules must retain the new ball grace.")
	_expect_approx(rules.phase1_attack_delay_min_sec, 3.5,
		"Rules must retain the minimum repeat delay.")
	_expect_approx(rules.phase1_attack_delay_max_sec, 4.5,
		"Rules must retain the maximum repeat delay.")


func _check_pattern_values(
	pattern: BossAttackPattern,
	expected_telegraph: float,
	label: String
) -> void:
	if pattern == null:
		return
	_expect(pattern.attack_id == &"teddy_arm_sweep",
		"%s Pattern must retain the Teddy attack id." % label)
	_expect_approx(pattern.telegraph_duration, expected_telegraph,
		"%s Pattern must retain its telegraph duration." % label)
	_expect_approx(pattern.active_duration, 0.22,
		"%s Pattern must retain its active duration." % label)
	_expect_approx(pattern.recovery_duration, 1.35,
		"%s Pattern must retain its recovery duration." % label)
	_expect_approx(pattern.cooldown_duration, 0.0,
		"%s Pattern must retain zero cooldown." % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %f, got %f" % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: TeddyPhase1AttackRuntimeScene")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
