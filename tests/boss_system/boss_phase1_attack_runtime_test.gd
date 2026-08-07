extends SceneTree

const RuntimeScript = preload(
	"res://scripts/boss_system/boss_phase1_attack_runtime.gd"
)
const FIRST_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1FirstPattern.tres"
const REPEAT_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1RepeatPattern.tres"


class TestAttackController extends BossAttackController:
	var start_result: bool = true
	var start_call_count: int = 0
	var cancel_call_count: int = 0
	var patterns_at_start: Array[BossAttackPattern] = []

	func start_attack() -> bool:
		start_call_count += 1
		patterns_at_start.append(pattern)
		if not start_result:
			return false
		_state = BossAttackController.State.TELEGRAPH
		return true

	func cancel_attack() -> bool:
		cancel_call_count += 1
		if _state == BossAttackController.State.IDLE:
			return false
		_state = BossAttackController.State.IDLE
		attack_cancelled.emit()
		return true

	func emit_finished() -> void:
		_state = BossAttackController.State.IDLE
		attack_finished.emit()

	func emit_cancelled() -> void:
		_state = BossAttackController.State.IDLE
		attack_cancelled.emit()

	func force_state(state: BossAttackController.State) -> void:
		_state = state


class RejectingCoordinator extends BossPhase1AttackCoordinator:
	var reject_bind: bool = false
	var reject_next_bind: bool = false

	func bind(
		scheduler: BossPhase1AttackScheduler,
		controller: BossAttackController
	) -> bool:
		if reject_bind:
			return false
		if reject_next_bind:
			reject_next_bind = false
			return false
		return super.bind(scheduler, controller)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_initial_and_setup_validation()
	await _test_setup_timing_and_idempotence()
	await _test_prebound_rejection_and_rollback()
	await _test_existing_setup_preservation_and_broken_cleanup()
	await _test_first_repeat_flow_and_dispatch_failure()
	await _test_stop_contracts()
	await _test_reset_contracts()
	await _test_grace_and_teardown()
	await _test_binding_loss()
	await _test_resource_and_getter_integrity()
	_finish()


func _test_initial_and_setup_validation() -> void:
	var fixture: Dictionary = _create_fixture()
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	_expect(not runtime.is_ready(), "A new runtime must not be ready.")
	_expect(not runtime.is_running(), "A new runtime must not be running.")
	_expect(not runtime.start(), "Start before setup must fail.")
	_expect(not runtime.stop(), "Stop before setup must fail.")
	_expect(not runtime.reset(), "Reset before setup must fail.")
	_expect(not runtime.begin_new_ball_grace(), "Grace before setup must fail.")

	var rules: Stage1BossPhase1Rules = fixture.rules
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern
	_expect(not runtime.setup(null, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern), "A null rules resource must be rejected.")
	_expect(not runtime.setup(rules, null, coordinator, selector, controller,
		first_pattern, repeat_pattern), "A null scheduler must be rejected.")
	_expect(not runtime.setup(rules, scheduler, null, selector, controller,
		first_pattern, repeat_pattern), "A null coordinator must be rejected.")
	_expect(not runtime.setup(rules, scheduler, coordinator, null, controller,
		first_pattern, repeat_pattern), "A null selector must be rejected.")
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, null,
		first_pattern, repeat_pattern), "A null controller must be rejected.")
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		null, repeat_pattern), "A null first pattern must be rejected.")
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, null), "A null repeat pattern must be rejected.")

	var invalid_rules: Stage1BossPhase1Rules = Stage1BossPhase1Rules.new()
	invalid_rules.first_attack_delay_sec = -1.0
	_expect(not runtime.setup(invalid_rules, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern), "Rules validation errors must be rejected.")
	var invalid_pattern: BossAttackPattern = BossAttackPattern.new()
	invalid_pattern.attack_id = &""
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		invalid_pattern, repeat_pattern), "An invalid first pattern must be rejected.")
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, invalid_pattern), "An invalid repeat pattern must be rejected.")

	_expect(scheduler.configure(1.0, 1.0, 1.0, 1.0),
		"The running-scheduler fixture must configure.")
	_expect(scheduler.start(), "The running-scheduler fixture must start.")
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern), "A running scheduler must be rejected.")
	scheduler.stop()
	controller.force_state(BossAttackController.State.ACTIVE)
	_expect(not runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern), "A non-IDLE controller must be rejected.")
	controller.force_state(BossAttackController.State.IDLE)

	await _destroy_fixture(fixture)


func _test_setup_timing_and_idempotence() -> void:
	var fixture: Dictionary = _create_fixture()
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var selector: BossPhase1AttackPatternSelector = fixture.selector
	var controller: TestAttackController = fixture.controller
	var rules: Stage1BossPhase1Rules = fixture.rules
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern

	_expect(_setup_fixture(fixture), "Valid runtime setup must succeed.")
	_expect(runtime.is_ready(), "Successful setup must make the runtime ready.")
	_expect(scheduler.is_configured(), "Successful setup must configure the scheduler.")
	_expect(selector.is_bound(), "Successful setup must bind the selector.")
	_expect(coordinator.is_bound(), "Successful setup must bind the coordinator.")
	_expect(runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern), "The same complete setup must be idempotent.")
	_expect(runtime.start(), "The configured runtime must start.")
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0,
		"Rules must provide the 3.0 second first delay.")
	_expect(runtime.setup(rules, scheduler, coordinator, selector, controller,
		first_pattern, repeat_pattern),
		"The same intact setup may be repeated while running.")
	_expect(runtime.is_running(), "An idempotent setup must preserve running state.")
	_expect(runtime.begin_new_ball_grace(), "Grace must begin while running.")
	_expect_approx(scheduler.get_grace_time_remaining(), 2.5,
		"Rules must provide the 2.5 second grace.")
	scheduler.advance_time(3.0)
	scheduler.advance_time(0.0)
	controller.emit_finished()
	var repeat_delay: float = scheduler.get_last_selected_repeat_delay()
	_expect(repeat_delay >= 3.5 and repeat_delay <= 4.5,
		"Rules must provide the 3.5 to 4.5 repeat range.")
	await _destroy_fixture(fixture)


func _test_prebound_rejection_and_rollback() -> void:
	var selector_fixture: Dictionary = _create_fixture()
	var selector: BossPhase1AttackPatternSelector = selector_fixture.selector
	_expect(selector.bind(selector_fixture.scheduler, selector_fixture.controller,
		selector_fixture.first_pattern, selector_fixture.repeat_pattern),
		"The prebound selector fixture must bind.")
	_expect(not _setup_fixture(selector_fixture),
		"A prebound selector must make a new setup fail.")
	_expect(selector.is_bound(), "Rejected setup must preserve the prebound selector.")
	await _destroy_fixture(selector_fixture)

	var coordinator_fixture: Dictionary = _create_fixture()
	var coordinator: BossPhase1AttackCoordinator = coordinator_fixture.coordinator
	_expect(coordinator.bind(coordinator_fixture.scheduler,
		coordinator_fixture.controller), "The prebound coordinator fixture must bind.")
	_expect(not _setup_fixture(coordinator_fixture),
		"A prebound coordinator must make a new setup fail.")
	_expect(coordinator.is_bound(), "Rejected setup must preserve the prebound coordinator.")
	await _destroy_fixture(coordinator_fixture)

	var rejection_fixture: Dictionary = _create_fixture(true)
	var rejecting: RejectingCoordinator = rejection_fixture.coordinator
	rejecting.reject_bind = true
	_expect(not _setup_fixture(rejection_fixture),
		"Coordinator bind rejection must fail setup.")
	_expect(not rejection_fixture.selector.is_bound(),
		"Coordinator bind rejection must roll back selector binding.")
	_expect(not rejecting.is_bound(),
		"Coordinator bind rejection must leave no coordinator binding.")
	await _destroy_fixture(rejection_fixture)

	var configure_fixture: Dictionary = _create_fixture()
	var nan_rules: Stage1BossPhase1Rules = configure_fixture.rules
	nan_rules.first_attack_delay_sec = NAN
	_expect(nan_rules.validate().is_empty(),
		"The NAN rollback fixture must pass the current rules validator.")
	_expect(not _setup_fixture(configure_fixture),
		"Scheduler configure must reject a NAN duration.")
	_expect(not configure_fixture.selector.is_bound(),
		"Configure failure must roll back selector binding.")
	_expect(not configure_fixture.coordinator.is_bound(),
		"Configure failure must roll back coordinator binding.")
	_expect(not configure_fixture.scheduler.is_configured(),
		"Configure failure must not configure the scheduler.")
	await _destroy_fixture(configure_fixture)

	var infinite_fixture: Dictionary = _create_fixture()
	var infinite_rules: Stage1BossPhase1Rules = infinite_fixture.rules
	infinite_rules.new_ball_grace_sec = INF
	_expect(infinite_rules.validate().is_empty(),
		"The infinity fixture must pass the current rules validator.")
	_expect(not _setup_fixture(infinite_fixture),
		"Scheduler configure must reject an infinite duration.")
	_expect(not infinite_fixture.selector.is_bound()
		and not infinite_fixture.coordinator.is_bound(),
		"Infinite configure failure must roll back both bindings.")
	await _destroy_fixture(infinite_fixture)


func _test_existing_setup_preservation_and_broken_cleanup() -> void:
	var fixture: Dictionary = _create_fixture()
	var replacement: Dictionary = _create_fixture()
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	_expect(_setup_fixture(fixture), "The preserved setup fixture must configure.")
	_expect(not runtime.setup(replacement.rules, replacement.scheduler,
		replacement.coordinator, replacement.selector, replacement.controller,
		replacement.first_pattern, replacement.repeat_pattern),
		"A different setup must be rejected.")
	_expect(runtime.is_ready(), "A different failed setup must preserve the old setup.")
	_expect(fixture.selector.is_bound() and fixture.coordinator.is_bound(),
		"A different failed setup must preserve old connections.")
	_expect(not replacement.selector.is_bound() and not replacement.coordinator.is_bound(),
		"A rejected replacement must not bind new objects.")

	fixture.selector.unbind()
	_expect(not _setup_fixture(fixture),
		"The same references with a missing selector connection must not succeed.")
	_expect(not runtime.is_ready(), "A broken same setup must be cleaned up.")
	_expect(not fixture.coordinator.is_bound(),
		"Broken same-setup cleanup must unbind the coordinator.")
	await _destroy_fixture(fixture)
	await _destroy_fixture(replacement)

	var coordinator_broken: Dictionary = _create_fixture()
	_expect(_setup_fixture(coordinator_broken),
		"The coordinator-broken fixture must configure.")
	coordinator_broken.coordinator.unbind()
	_expect(not _setup_fixture(coordinator_broken),
		"The same references with a missing coordinator connection must not succeed.")
	_expect(not coordinator_broken.selector.is_bound(),
		"Broken same-setup cleanup must unbind the selector.")
	await _destroy_fixture(coordinator_broken)


func _test_first_repeat_flow_and_dispatch_failure() -> void:
	var fixture: Dictionary = _create_fixture()
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var first_pattern: BossAttackPattern = fixture.first_pattern
	var repeat_pattern: BossAttackPattern = fixture.repeat_pattern
	_expect(_setup_fixture(fixture), "The attack flow fixture must configure.")
	_expect(runtime.start(), "The attack flow runtime must start.")
	scheduler.advance_time(3.0)
	_expect(controller.start_call_count == 1,
		"The first request must call Controller start exactly once.")
	_expect(controller.patterns_at_start.size() == 1
		and controller.patterns_at_start[0] == first_pattern,
		"The first pattern must be applied before Controller start.")
	controller.emit_finished()
	_expect(scheduler.get_current_state()
		== BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"Attack completion must begin repeat wait.")
	var repeat_delay: float = scheduler.get_last_selected_repeat_delay()
	scheduler.advance_time(repeat_delay)
	_expect(controller.start_call_count == 2,
		"The repeat request must call Controller start once more.")
	_expect(controller.patterns_at_start.size() == 2
		and controller.patterns_at_start[1] == repeat_pattern,
		"The repeat pattern must be applied before Controller start.")
	await _destroy_fixture(fixture)

	var failure_fixture: Dictionary = _create_fixture()
	var failure_scheduler: BossPhase1AttackScheduler = failure_fixture.scheduler
	var failure_controller: TestAttackController = failure_fixture.controller
	failure_controller.start_result = false
	_expect(_setup_fixture(failure_fixture), "The dispatch failure fixture must configure.")
	_expect(failure_fixture.runtime.start(), "The dispatch failure fixture must start.")
	failure_scheduler.advance_time(3.0)
	_expect(failure_controller.start_call_count == 1,
		"A failed dispatch must attempt Controller start once.")
	_expect(failure_scheduler.get_current_state()
		== BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"A failed Controller start must recover into repeat wait.")
	await _destroy_fixture(failure_fixture)


func _test_stop_contracts() -> void:
	var cancel_fixture: Dictionary = _create_fixture()
	_expect(_setup_fixture(cancel_fixture), "The stop(true) fixture must configure.")
	_expect(cancel_fixture.runtime.start(), "The stop(true) fixture must start.")
	cancel_fixture.scheduler.advance_time(3.0)
	_expect(cancel_fixture.runtime.stop(true), "Stop(true) must succeed while running.")
	_expect(cancel_fixture.controller.cancel_call_count == 1,
		"Stop(true) must cancel the active attack.")
	_expect(cancel_fixture.runtime.is_ready() and not cancel_fixture.runtime.is_running(),
		"Stop(true) must preserve readiness and end running state.")
	_expect(not cancel_fixture.runtime.stop(true), "Duplicate stop must fail safely.")
	await _destroy_fixture(cancel_fixture)

	var preserve_fixture: Dictionary = _create_fixture()
	_expect(_setup_fixture(preserve_fixture), "The stop(false) fixture must configure.")
	_expect(preserve_fixture.runtime.start(), "The stop(false) fixture must start.")
	preserve_fixture.scheduler.advance_time(3.0)
	_expect(preserve_fixture.runtime.stop(false), "Stop(false) must succeed.")
	_expect(preserve_fixture.controller.cancel_call_count == 0,
		"Stop(false) must preserve the Controller attack.")
	_expect(not preserve_fixture.runtime.start(),
		"Restart must fail while the preserved attack remains active.")
	preserve_fixture.controller.emit_finished()
	_expect(preserve_fixture.runtime.start(),
		"Restart must succeed after the preserved attack finishes.")
	await _destroy_fixture(preserve_fixture)


func _test_reset_contracts() -> void:
	var idle_running: Dictionary = _create_fixture()
	_expect(_setup_fixture(idle_running), "The idle reset(false) fixture must configure.")
	_expect(idle_running.runtime.start(), "The idle reset(false) fixture must start.")
	_expect(idle_running.runtime.reset(false),
		"Reset(false) may safely stop a running loop without an active attack.")
	_expect(idle_running.runtime.is_ready() and not idle_running.runtime.is_running(),
		"Successful reset(false) must preserve stopped readiness.")
	await _destroy_fixture(idle_running)

	var active_false: Dictionary = _create_fixture()
	_expect(_setup_fixture(active_false), "The active reset(false) fixture must configure.")
	_expect(active_false.runtime.start(), "The active reset(false) fixture must start.")
	active_false.scheduler.advance_time(3.0)
	_expect(not active_false.runtime.reset(false),
		"Reset(false) must reject an in-flight attack.")
	_expect(active_false.runtime.is_running(),
		"Rejected reset(false) must not stop the loop.")
	_expect(active_false.controller.cancel_call_count == 0,
		"Rejected reset(false) must not cancel the attack.")
	await _destroy_fixture(active_false)

	var preserved_false: Dictionary = _create_fixture()
	_expect(_setup_fixture(preserved_false),
		"The preserved reset(false) fixture must configure.")
	_expect(preserved_false.runtime.start(),
		"The preserved reset(false) fixture must start.")
	preserved_false.scheduler.advance_time(3.0)
	_expect(preserved_false.runtime.stop(false),
		"The preserved reset(false) fixture must stop without cancellation.")
	_expect(not preserved_false.runtime.reset(false),
		"Reset(false) must reject an attack left by stop(false).")
	_expect(preserved_false.controller.cancel_call_count == 0
		and preserved_false.controller.current_state
		== BossAttackController.State.TELEGRAPH,
		"Rejected preserved reset(false) must not change Controller state.")
	preserved_false.controller.emit_finished()
	await _destroy_fixture(preserved_false)

	var non_idle: Dictionary = _create_fixture()
	_expect(_setup_fixture(non_idle), "The non-IDLE reset fixture must configure.")
	non_idle.controller.force_state(BossAttackController.State.ACTIVE)
	_expect(not non_idle.runtime.reset(false),
		"Reset(false) must reject a non-IDLE Controller.")
	_expect(non_idle.runtime.is_ready(),
		"Rejected non-IDLE reset must preserve readiness.")
	non_idle.controller.force_state(BossAttackController.State.IDLE)
	await _destroy_fixture(non_idle)

	var reset_true: Dictionary = _create_fixture()
	_expect(_setup_fixture(reset_true), "The reset(true) fixture must configure.")
	_expect(reset_true.runtime.start(), "The reset(true) fixture must start.")
	reset_true.scheduler.advance_time(3.0)
	reset_true.controller.emit_finished()
	reset_true.scheduler.advance_time(reset_true.scheduler.get_last_selected_repeat_delay())
	_expect(reset_true.controller.pattern == reset_true.repeat_pattern,
		"The repeat pattern must be active before reset.")
	_expect(reset_true.runtime.reset(true), "Reset(true) must safely rebind.")
	_expect(reset_true.controller.cancel_call_count == 1,
		"Reset(true) must cancel the active repeat attack.")
	_expect(reset_true.selector.is_bound() and reset_true.coordinator.is_bound(),
		"Reset must preserve selector binding and restore coordinator binding.")
	_expect(reset_true.runtime.start(), "Runtime must start after reset.")
	reset_true.scheduler.advance_time(3.0)
	_expect(reset_true.controller.pattern == reset_true.first_pattern,
		"The first pattern must be reapplied after reset.")
	await _destroy_fixture(reset_true)

	var failed_rebind: Dictionary = _create_fixture(true)
	var rejecting: RejectingCoordinator = failed_rebind.coordinator
	_expect(_setup_fixture(failed_rebind), "The reset rebind fixture must configure.")
	rejecting.reject_next_bind = true
	_expect(not failed_rebind.runtime.reset(true),
		"A failed coordinator rebind must fail reset.")
	_expect(not failed_rebind.runtime.is_ready(),
		"A failed reset rebind must clear Runtime readiness.")
	_expect(not failed_rebind.selector.is_bound() and not rejecting.is_bound(),
		"A failed reset rebind must leave no partial binding.")
	await _destroy_fixture(failed_rebind)


func _test_grace_and_teardown() -> void:
	var fixture: Dictionary = _create_fixture()
	var loss_count: Array[int] = [0]
	fixture.runtime.binding_lost.connect(func() -> void: loss_count[0] += 1)
	_expect(_setup_fixture(fixture), "The grace fixture must configure.")
	_expect(not fixture.runtime.begin_new_ball_grace(),
		"Grace while stopped must be rejected.")
	_expect(fixture.runtime.start(), "The grace fixture must start.")
	_expect(fixture.runtime.begin_new_ball_grace(), "Grace while running must succeed.")
	_expect_approx(fixture.scheduler.get_grace_time_remaining(), 2.5,
		"Grace delegation must use the configured Rules value.")
	fixture.scheduler.advance_time(3.0)
	fixture.runtime.teardown(true)
	fixture.runtime.teardown(true)
	_expect(not fixture.runtime.is_ready() and not fixture.runtime.is_running(),
		"Teardown must clear Runtime state.")
	_expect(not fixture.selector.is_bound() and not fixture.coordinator.is_bound(),
		"Teardown must unbind Selector and Coordinator.")
	_expect(fixture.controller.cancel_call_count == 1,
		"Teardown(true) must cancel the active owned attack.")
	_expect(loss_count[0] == 0, "Explicit teardown must not emit binding_lost.")
	var start_count: int = fixture.controller.start_call_count
	fixture.scheduler.start()
	fixture.scheduler.advance_time(100.0)
	_expect(fixture.controller.start_call_count == start_count,
		"Scheduler signals after teardown must be ignored.")
	await _destroy_fixture(fixture)

	var preserve: Dictionary = _create_fixture()
	_expect(_setup_fixture(preserve), "The teardown(false) fixture must configure.")
	_expect(preserve.runtime.start(), "The teardown(false) fixture must start.")
	preserve.scheduler.advance_time(3.0)
	preserve.runtime.teardown(false)
	_expect(preserve.controller.cancel_call_count == 0,
		"Teardown(false) must leave the Controller attack to the caller.")
	_expect(not preserve.selector.is_bound() and not preserve.coordinator.is_bound(),
		"Teardown(false) must still remove component bindings.")
	await _destroy_fixture(preserve)


func _test_binding_loss() -> void:
	await _test_node_binding_loss(&"scheduler")
	await _test_node_binding_loss(&"coordinator")
	await _test_node_binding_loss(&"selector")
	await _test_node_binding_loss(&"controller")

	var external_selector: Dictionary = _create_fixture()
	var selector_losses: Array[int] = [0]
	external_selector.runtime.binding_lost.connect(func() -> void: selector_losses[0] += 1)
	_expect(_setup_fixture(external_selector), "The external selector loss fixture must configure.")
	external_selector.selector.unbind()
	await process_frame
	await process_frame
	_expect(selector_losses[0] == 1,
		"External selector unbind must be reported as one binding loss.")
	_expect(not external_selector.coordinator.is_bound(),
		"External selector loss must clean the surviving coordinator.")
	await process_frame
	_expect(selector_losses[0] == 1, "Binding loss must not repeat on later processing.")
	await _destroy_fixture(external_selector)

	var external_coordinator: Dictionary = _create_fixture()
	var coordinator_losses: Array[int] = [0]
	external_coordinator.runtime.binding_lost.connect(func() -> void: coordinator_losses[0] += 1)
	_expect(_setup_fixture(external_coordinator),
		"The external coordinator loss fixture must configure.")
	external_coordinator.coordinator.unbind()
	await process_frame
	await process_frame
	_expect(coordinator_losses[0] == 1,
		"External coordinator unbind must be reported as one binding loss.")
	_expect(not external_coordinator.selector.is_bound(),
		"External coordinator loss must clean the surviving selector.")
	await _destroy_fixture(external_coordinator)

	var simultaneous: Dictionary = _create_fixture()
	var simultaneous_losses: Array[int] = [0]
	simultaneous.runtime.binding_lost.connect(func() -> void: simultaneous_losses[0] += 1)
	_expect(_setup_fixture(simultaneous), "The simultaneous loss fixture must configure.")
	simultaneous.scheduler.queue_free()
	simultaneous.controller.queue_free()
	await process_frame
	await process_frame
	_expect(simultaneous_losses[0] == 1,
		"Simultaneous reference loss must emit binding_lost exactly once.")
	await process_frame
	await process_frame
	_expect(simultaneous_losses[0] == 1,
		"Additional processing must not repeat simultaneous binding loss.")
	await _destroy_fixture(simultaneous)


func _test_node_binding_loss(target: StringName) -> void:
	var fixture: Dictionary = _create_fixture()
	var losses: Array[int] = [0]
	fixture.runtime.binding_lost.connect(func() -> void: losses[0] += 1)
	_expect(_setup_fixture(fixture), "The node loss fixture must configure.")
	match target:
		&"scheduler":
			fixture.scheduler.queue_free()
		&"coordinator":
			fixture.coordinator.queue_free()
		&"selector":
			fixture.selector.queue_free()
		&"controller":
			fixture.controller.queue_free()
	await process_frame
	await process_frame
	_expect(losses[0] == 1, "%s loss must emit binding_lost once." % target)
	_expect(not fixture.runtime.is_ready(), "%s loss must clear readiness." % target)
	await process_frame
	_expect(losses[0] == 1, "%s loss must not be reported twice." % target)
	await _destroy_fixture(fixture)


func _test_resource_and_getter_integrity() -> void:
	var fixture: Dictionary = _create_fixture()
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	var first_before: Dictionary = _snapshot_pattern(fixture.first_pattern)
	var repeat_before: Dictionary = _snapshot_pattern(fixture.repeat_pattern)
	_expect(_setup_fixture(fixture), "The getter integrity fixture must configure.")
	var ready_before: bool = runtime.is_ready()
	var running_before: bool = runtime.is_running()
	_expect(runtime.is_ready() == ready_before,
		"The ready getter must not change state.")
	_expect(runtime.is_running() == running_before,
		"The running getter must not change state.")
	_expect(runtime.start(), "The integrity fixture must start.")
	fixture.scheduler.advance_time(3.0)
	fixture.controller.emit_finished()
	fixture.scheduler.advance_time(fixture.scheduler.get_last_selected_repeat_delay())
	_expect(_snapshot_pattern(fixture.first_pattern) == first_before,
		"Runtime setup and execution must not modify the first Pattern resource.")
	_expect(_snapshot_pattern(fixture.repeat_pattern) == repeat_before,
		"Runtime setup and execution must not modify the repeat Pattern resource.")
	await _destroy_fixture(fixture)


func _create_fixture(
	use_rejecting_coordinator: bool = false,
	first_override: BossAttackPattern = null,
	repeat_override: BossAttackPattern = null
) -> Dictionary:
	var runtime: BossPhase1AttackRuntime = RuntimeScript.new()
	var rules: Stage1BossPhase1Rules = Stage1BossPhase1Rules.new()
	var scheduler: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var coordinator: BossPhase1AttackCoordinator
	if use_rejecting_coordinator:
		coordinator = RejectingCoordinator.new()
	else:
		coordinator = BossPhase1AttackCoordinator.new()
	var selector: BossPhase1AttackPatternSelector = BossPhase1AttackPatternSelector.new()
	var controller: TestAttackController = TestAttackController.new()
	var first_pattern: BossAttackPattern = first_override
	if first_pattern == null:
		first_pattern = load(FIRST_PATTERN_PATH) as BossAttackPattern
	var repeat_pattern: BossAttackPattern = repeat_override
	if repeat_pattern == null:
		repeat_pattern = load(REPEAT_PATTERN_PATH) as BossAttackPattern
	scheduler.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scheduler)
	root.add_child(controller)
	root.add_child(selector)
	root.add_child(coordinator)
	root.add_child(runtime)
	return {
		&"runtime": runtime,
		&"rules": rules,
		&"scheduler": scheduler,
		&"coordinator": coordinator,
		&"selector": selector,
		&"controller": controller,
		&"first_pattern": first_pattern,
		&"repeat_pattern": repeat_pattern,
	}


func _setup_fixture(fixture: Dictionary) -> bool:
	var runtime: BossPhase1AttackRuntime = fixture.runtime
	return runtime.setup(
		fixture.rules,
		fixture.scheduler,
		fixture.coordinator,
		fixture.selector,
		fixture.controller,
		fixture.first_pattern,
		fixture.repeat_pattern
	)


func _destroy_fixture(fixture: Dictionary) -> void:
	var runtime_value: Variant = fixture.get(&"runtime")
	var coordinator_value: Variant = fixture.get(&"coordinator")
	var selector_value: Variant = fixture.get(&"selector")
	var scheduler_value: Variant = fixture.get(&"scheduler")
	var controller_value: Variant = fixture.get(&"controller")
	if is_instance_valid(runtime_value):
		var runtime: BossPhase1AttackRuntime = runtime_value
		runtime.teardown(true)
		runtime.queue_free()
	if is_instance_valid(coordinator_value):
		var coordinator: BossPhase1AttackCoordinator = coordinator_value
		coordinator.unbind(true)
		coordinator.queue_free()
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


func _snapshot_pattern(pattern: BossAttackPattern) -> Dictionary:
	return {
		&"attack_id": pattern.attack_id,
		&"telegraph_duration": pattern.telegraph_duration,
		&"active_duration": pattern.active_duration,
		&"recovery_duration": pattern.recovery_duration,
		&"cooldown_duration": pattern.cooldown_duration,
	}


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BossPhase1AttackRuntime")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %f, got %f" % [message, expected, actual])
