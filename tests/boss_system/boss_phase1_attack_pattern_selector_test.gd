extends SceneTree

const SelectorScript = preload(
	"res://scripts/boss_system/boss_phase1_attack_pattern_selector.gd"
)
const FIRST_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1FirstPattern.tres"
const REPEAT_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1RepeatPattern.tres"

class TestAttackController extends BossAttackController:
	func force_state(state: BossAttackController.State) -> void:
		_state = state


class TogglePattern extends BossAttackPattern:
	var validation_enabled: bool = true

	func is_valid() -> bool:
		return validation_enabled and not attack_id.is_empty()


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_bind_validation_and_preservation()
	await _test_first_repeat_application_and_signal_order()
	await _test_restart_reset_and_reapplication()
	await _test_application_failures_and_resource_integrity()
	await _test_unbind_contract()
	await _test_binding_loss()
	_finish()


func _test_bind_validation_and_preservation() -> void:
	var fixture: Dictionary = _create_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern

	_expect(not selector.is_bound(), "A new selector must be unbound.")
	_expect(selector.get_current_pattern() == null,
		"An unbound selector must report no current pattern.")
	_expect(not selector.bind(null, controller, first_pattern, repeat_pattern),
		"A null scheduler must be rejected.")
	_expect(not selector.bind(scheduler, null, first_pattern, repeat_pattern),
		"A null controller must be rejected.")
	_expect(not selector.bind(scheduler, controller, null, repeat_pattern),
		"A null first pattern must be rejected.")
	_expect(not selector.bind(scheduler, controller, first_pattern, null),
		"A null repeat pattern must be rejected.")

	var invalid_pattern: BossAttackPattern = BossAttackPattern.new()
	invalid_pattern.attack_id = &""
	_expect(not selector.bind(scheduler, controller, invalid_pattern, repeat_pattern),
		"An empty first attack id must be rejected.")
	_expect(not selector.bind(scheduler, controller, first_pattern, invalid_pattern),
		"An empty repeat attack id must be rejected.")
	_expect(_configure_scheduler(scheduler), "The incoming scheduler must configure.")
	scheduler.start()
	_expect(not selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"An initially running scheduler must be rejected.")
	scheduler.stop()
	controller.force_state(BossAttackController.State.ACTIVE)
	_expect(not selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"An initially non-IDLE controller must be rejected.")
	controller.force_state(BossAttackController.State.IDLE)

	var application_count: Array[int] = [0]
	selector.pattern_applied.connect(func(
		_pattern: BossAttackPattern,
		_is_first: bool
	) -> void:
		application_count[0] += 1
	)
	_expect(selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"Valid objects must bind.")
	_expect(selector.is_bound(), "A valid binding must be reported.")
	_expect(controller.pattern == null, "Bind must not change the controller pattern.")
	_expect(application_count[0] == 0, "Bind must not emit pattern_applied.")
	_expect(selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"The same binding must be accepted.")
	_expect(_configure_scheduler(scheduler), "The bound scheduler must configure.")
	scheduler.start()
	controller.force_state(BossAttackController.State.ACTIVE)
	_expect(selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"The same binding must remain valid while its objects are running.")
	_expect(application_count[0] == 0,
		"Binding the same objects must not apply a pattern or emit a signal.")

	var replacement: Dictionary = _create_unbound_pair()
	var replacement_scheduler: BossPhase1AttackScheduler = replacement.scheduler
	var replacement_controller: TestAttackController = replacement.controller
	_expect(not selector.bind(
		replacement_scheduler,
		replacement_controller,
		first_pattern,
		repeat_pattern
	), "A different binding must be rejected while the current binding is unsafe.")
	_expect(selector.is_bound(), "A failed replacement must preserve the original binding.")
	controller.force_state(BossAttackController.State.IDLE)
	scheduler.stop()
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == first_pattern,
		"The original signal connection must survive a failed bind.")
	_expect(application_count[0] == 1,
		"Repeated same binding must not duplicate the state_changed connection.")

	selector.unbind()
	_expect(not selector.bind(null, controller, first_pattern, repeat_pattern),
		"An invalid scheduler must be rejected.")
	_expect(not selector.bind(scheduler, null, first_pattern, repeat_pattern),
		"An invalid controller must be rejected.")

	await _destroy_fixture(fixture)
	await _destroy_unbound_pair(replacement)


func _test_first_repeat_application_and_signal_order() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern
	var applied_patterns: Array[BossAttackPattern] = []
	var first_flags: Array[bool] = []
	var pattern_seen_at_request: Array[BossAttackPattern] = []
	selector.pattern_applied.connect(func(
		pattern: BossAttackPattern,
		is_first: bool
	) -> void:
		applied_patterns.append(pattern)
		first_flags.append(is_first)
	)
	scheduler.attack_requested.connect(func() -> void:
		pattern_seen_at_request.append(controller.pattern)
	)

	_expect(controller.pattern == null, "No pattern may be applied before scheduler start.")
	_expect(scheduler.start(), "The scheduler must start.")
	_expect(controller.pattern == null,
		"The transition into first wait must not apply a pattern.")
	scheduler.advance_time(0.0)
	_expect(controller.pattern == first_pattern,
		"The first request transition must apply the first pattern.")
	var first_pattern_before_getter: BossAttackPattern = controller.pattern
	_expect(selector.get_current_pattern() == first_pattern,
		"The getter must report the applied first pattern.")
	_expect(controller.pattern == first_pattern_before_getter,
		"Reading the current first pattern must not change controller state.")
	_expect(applied_patterns.size() == 1 and applied_patterns[0] == first_pattern,
		"The first pattern must emit pattern_applied exactly once.")
	_expect(first_flags == [true], "The first pattern signal must identify a first attack.")
	_expect(pattern_seen_at_request.size() == 1
		and pattern_seen_at_request[0] == first_pattern,
		"The first pattern must be applied before attack_requested.")

	_expect(scheduler.notify_attack_finished(), "The first attack must enter repeat wait.")
	_expect(controller.pattern == first_pattern,
		"Entering repeat wait alone must not change the pattern.")
	scheduler.advance_time(0.0)
	_expect(controller.pattern == repeat_pattern,
		"The repeat request transition must apply the repeat pattern.")
	var repeat_pattern_before_getter: BossAttackPattern = controller.pattern
	_expect(selector.get_current_pattern() == repeat_pattern,
		"The getter must report the applied repeat pattern.")
	_expect(controller.pattern == repeat_pattern_before_getter,
		"Reading the current repeat pattern must not change controller state.")
	_expect(applied_patterns.size() == 2 and applied_patterns[1] == repeat_pattern,
		"The repeat pattern must emit pattern_applied exactly once.")
	_expect(first_flags == [true, false],
		"The repeat pattern signal must identify a non-first attack.")
	_expect(pattern_seen_at_request.size() == 2
		and pattern_seen_at_request[1] == repeat_pattern,
		"The repeat pattern must be applied before attack_requested.")
	await _destroy_fixture(fixture)


func _test_restart_reset_and_reapplication() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var applied_count: Array[int] = [0]
	selector.pattern_applied.connect(func(
		_pattern: BossAttackPattern,
		_is_first: bool
	) -> void:
		applied_count[0] += 1
	)

	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(applied_count[0] == 1, "The initial first pattern must be applied once.")
	scheduler.stop()
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == first_pattern,
		"Stop and restart must reapply the first pattern.")
	_expect(applied_count[0] == 2,
		"An already assigned first pattern must emit again for a new valid request.")
	scheduler.reset()
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == first_pattern,
		"Reset and restart must reapply the first pattern.")
	_expect(applied_count[0] == 3,
		"Reset and restart must emit a new first pattern application.")
	await _destroy_fixture(fixture)


func _test_application_failures_and_resource_integrity() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern
	var first_before: Dictionary = _snapshot(first_pattern)
	var repeat_before: Dictionary = _snapshot(repeat_pattern)
	var sentinel_pattern: BossAttackPattern = BossAttackPattern.new()
	sentinel_pattern.attack_id = &"sentinel"
	controller.pattern = sentinel_pattern
	var failure_flags: Array[bool] = []
	selector.pattern_application_failed.connect(func(is_first: bool) -> void:
		failure_flags.append(is_first)
	)

	controller.force_state(BossAttackController.State.ACTIVE)
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == sentinel_pattern,
		"A non-IDLE controller must preserve its existing pattern.")
	_expect(failure_flags == [true],
		"A non-IDLE first application must fail exactly once.")

	controller.force_state(BossAttackController.State.IDLE)
	scheduler.stop()
	selector.unbind()
	var toggle_first: TogglePattern = TogglePattern.new()
	toggle_first.attack_id = &"toggle_first"
	var toggle_repeat: TogglePattern = TogglePattern.new()
	toggle_repeat.attack_id = &"toggle_repeat"
	_expect(selector.bind(scheduler, controller, toggle_first, toggle_repeat),
		"Initially valid toggle patterns must bind.")
	toggle_first.validation_enabled = false
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == sentinel_pattern,
		"An invalid selected pattern must preserve the existing controller pattern.")
	_expect(failure_flags == [true, true],
		"An invalid selected pattern must emit one application failure.")

	_expect(_snapshot(first_pattern) == first_before,
		"Selector operations must not modify the authored first resource.")
	_expect(_snapshot(repeat_pattern) == repeat_before,
		"Selector operations must not modify the authored repeat resource.")
	await _destroy_fixture(fixture)


func _test_unbind_contract() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var sentinel_pattern: BossAttackPattern = BossAttackPattern.new()
	sentinel_pattern.attack_id = &"sentinel"
	controller.pattern = sentinel_pattern
	var loss_count: Array[int] = [0]
	selector.binding_lost.connect(func() -> void: loss_count[0] += 1)

	selector.unbind()
	selector.unbind()
	_expect(not selector.is_bound(), "Unbind must clear the binding.")
	_expect(selector.get_current_pattern() == null,
		"An unbound selector must report no current pattern.")
	_expect(controller.pattern == sentinel_pattern,
		"Unbind must preserve the controller's existing pattern.")
	_expect(loss_count[0] == 0, "Explicit unbind must not emit binding_lost.")
	scheduler.start()
	scheduler.advance_time(0.0)
	_expect(controller.pattern == sentinel_pattern,
		"Scheduler transitions after unbind must be ignored.")
	await _destroy_fixture(fixture)


func _test_binding_loss() -> void:
	await _test_scheduler_loss()
	await _test_controller_loss()
	await _test_simultaneous_node_loss()


func _test_scheduler_loss() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var loss_count: Array[int] = [0]
	selector.binding_lost.connect(func() -> void: loss_count[0] += 1)
	scheduler.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "Scheduler loss must emit binding_lost once.")
	_expect(not selector.is_bound(), "Scheduler loss must clear the binding.")
	await process_frame
	_expect(loss_count[0] == 1, "Scheduler loss must not be reported again.")
	await _destroy_fixture(fixture)


func _test_controller_loss() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var controller: TestAttackController = fixture.controller
	var loss_count: Array[int] = [0]
	selector.binding_lost.connect(func() -> void: loss_count[0] += 1)
	controller.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "Controller loss must emit binding_lost once.")
	_expect(not selector.is_bound(), "Controller loss must clear the binding.")
	await process_frame
	_expect(loss_count[0] == 1, "Controller loss must not be reported again.")
	await _destroy_fixture(fixture)


func _test_simultaneous_node_loss() -> void:
	var fixture: Dictionary = _create_bound_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var loss_count: Array[int] = [0]
	selector.binding_lost.connect(func() -> void: loss_count[0] += 1)
	scheduler.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "Simultaneous node loss must emit binding_lost once.")
	_expect(not selector.is_bound(), "Simultaneous node loss must clear the binding.")
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "Additional processing must not repeat binding_lost.")
	await _destroy_fixture(fixture)


func _create_fixture() -> Dictionary:
	var selector: BossPhase1AttackPatternSelector = SelectorScript.new()
	var scheduler: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var controller: TestAttackController = TestAttackController.new()
	var first_pattern: BossAttackPattern = load(FIRST_PATTERN_PATH) as BossAttackPattern
	var repeat_pattern: BossAttackPattern = load(REPEAT_PATTERN_PATH) as BossAttackPattern
	scheduler.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scheduler)
	root.add_child(controller)
	root.add_child(selector)
	return {
		&"selector": selector,
		&"scheduler": scheduler,
		&"controller": controller,
		&"first_pattern": first_pattern,
		&"repeat_pattern": repeat_pattern,
	}


func _create_bound_fixture() -> Dictionary:
	var fixture: Dictionary = _create_fixture()
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern
	_expect(selector.bind(scheduler, controller, first_pattern, repeat_pattern),
		"The fixture must bind.")
	_expect(_configure_scheduler(scheduler), "The fixture scheduler must configure.")
	return fixture


func _create_unbound_pair() -> Dictionary:
	var scheduler: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var controller: TestAttackController = TestAttackController.new()
	scheduler.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scheduler)
	root.add_child(controller)
	return {
		&"scheduler": scheduler,
		&"controller": controller,
	}


func _destroy_unbound_pair(pair: Dictionary) -> void:
	var scheduler_value: Variant = pair.get(&"scheduler")
	var controller_value: Variant = pair.get(&"controller")
	if is_instance_valid(scheduler_value):
		var scheduler: BossPhase1AttackScheduler = scheduler_value
		scheduler.queue_free()
	if is_instance_valid(controller_value):
		var controller: TestAttackController = controller_value
		controller.queue_free()
	await process_frame


func _destroy_fixture(fixture: Dictionary) -> void:
	var selector_value: Variant = fixture.get(&"selector")
	var scheduler_value: Variant = fixture.get(&"scheduler")
	var controller_value: Variant = fixture.get(&"controller")
	if is_instance_valid(selector_value):
		var selector: BossPhase1AttackPatternSelector = selector_value
		selector.unbind()
		selector.queue_free()
	if is_instance_valid(scheduler_value):
		var scheduler: BossPhase1AttackScheduler = scheduler_value
		scheduler.queue_free()
	if is_instance_valid(controller_value):
		var controller: TestAttackController = controller_value
		controller.queue_free()
	await process_frame


func _configure_scheduler(scheduler: BossPhase1AttackScheduler) -> bool:
	return scheduler.configure(0.0, 0.0, 0.0, 0.0)


func _snapshot(pattern: BossAttackPattern) -> Dictionary:
	return {
		&"attack_id": pattern.attack_id,
		&"telegraph_duration": pattern.telegraph_duration,
		&"active_duration": pattern.active_duration,
		&"recovery_duration": pattern.recovery_duration,
		&"cooldown_duration": pattern.cooldown_duration,
	}


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BossPhase1AttackPatternSelector")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
