extends SceneTree

const CoordinatorScript = preload(
	"res://scripts/boss_system/boss_phase1_attack_coordinator.gd"
)

class TestAttackController extends BossAttackController:
	var start_result: bool = true
	var cancel_during_start: bool = false
	var start_call_count: int = 0
	var cancel_call_count: int = 0

	func start_attack() -> bool:
		start_call_count += 1
		if cancel_during_start:
			attack_cancelled.emit()
			return true
		return start_result

	func cancel_attack() -> bool:
		cancel_call_count += 1
		attack_cancelled.emit()
		return true

	func emit_finished() -> void:
		attack_finished.emit()

	func emit_cancelled() -> void:
		attack_cancelled.emit()


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_binding_contract()
	await _test_start_contract_and_stopped_requests()
	await _test_successful_attack_lifecycle()
	await _test_start_failure()
	await _test_controller_cancellation()
	await _test_unrelated_terminal_signals()
	await _test_synchronous_cancellation_reentrancy()
	await _test_stop_contract()
	await _test_stop_false_ownership_contract()
	await _test_unbind_contract()
	await _test_freed_scheduler_binding_loss()
	await _test_freed_controller_binding_loss()
	await _test_simultaneous_binding_loss()
	await _test_getters_do_not_mutate_state()
	_finish()


func _test_binding_contract() -> void:
	var fixture: Dictionary = _create_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var replacement_scheduler: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var replacement_controller: TestAttackController = TestAttackController.new()
	replacement_scheduler.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(replacement_scheduler)
	root.add_child(replacement_controller)

	_expect(not coordinator.is_bound(), "A new coordinator must be unbound.")
	_expect(not coordinator.bind(null, controller), "A null scheduler must be rejected.")
	_expect(not coordinator.bind(scheduler, null), "A null controller must be rejected.")
	_expect(coordinator.bind(scheduler, controller), "Valid objects must bind.")
	_expect(coordinator.is_bound(), "A valid binding must be reported.")
	_expect(not coordinator.bind(null, replacement_controller),
		"A failed bind must be rejected after a valid binding exists.")
	_expect(coordinator.is_bound(), "A failed bind must preserve the valid binding.")
	_expect(coordinator.bind(scheduler, controller), "Binding the same objects again must succeed.")

	_expect(_configure_scheduler(scheduler, 0.0, 1.0), "The bound scheduler must configure.")
	_expect(coordinator.start(), "The bound coordinator must start.")
	_expect(not coordinator.bind(replacement_scheduler, replacement_controller),
		"Rebinding to different objects while running must fail.")
	scheduler.advance_time(0.0)
	_expect(controller.start_call_count == 1,
		"Rebinding the same objects must not duplicate signal connections.")
	_expect(replacement_controller.start_call_count == 0,
		"A failed rebind must preserve the original binding.")

	coordinator.stop()
	coordinator.unbind()
	_expect(not coordinator.bind(null, controller),
		"An invalid scheduler must be rejected.")
	_expect(not coordinator.bind(scheduler, null),
		"An invalid controller must be rejected.")
	_expect(not coordinator.is_bound(), "Rejected invalid bindings must remain unbound.")
	await _destroy_fixture(fixture)
	replacement_scheduler.queue_free()
	replacement_controller.queue_free()
	await process_frame


func _test_start_contract_and_stopped_requests() -> void:
	var fixture: Dictionary = _create_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller

	_expect(not coordinator.start(), "An unbound coordinator must reject start.")
	_expect(coordinator.bind(scheduler, controller), "The start fixture must bind.")
	_expect(not coordinator.start(), "An unconfigured scheduler must make coordinator start fail.")
	_expect(not coordinator.is_running(), "A failed scheduler start must restore running state.")
	_expect(_configure_scheduler(scheduler, 0.0, 1.0), "The start fixture must configure.")
	_expect(scheduler.start(), "The scheduler can be advanced while the coordinator is stopped.")
	scheduler.advance_time(0.0)
	_expect(controller.start_call_count == 0,
		"Attack requests must be ignored while the coordinator is stopped.")
	scheduler.stop()

	_expect(coordinator.start(), "A valid coordinator start must succeed.")
	_expect(coordinator.is_running(), "A successful start must set the running state.")
	_expect(not coordinator.start(), "A duplicate start must be rejected.")
	await _destroy_fixture(fixture)


func _test_successful_attack_lifecycle() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var success_count: Array[int] = [0]
	coordinator.attack_dispatch_succeeded.connect(func() -> void: success_count[0] += 1)

	scheduler.advance_time(0.0)
	_expect(controller.start_call_count == 1, "One scheduler request must dispatch one attack.")
	_expect(success_count[0] == 1, "A successful dispatch must emit once.")
	_expect(coordinator.is_attack_in_flight(), "A successful dispatch must be in flight.")
	scheduler.advance_time(100.0)
	_expect(controller.start_call_count == 1,
		"No additional attack may dispatch before completion.")

	controller.emit_finished()
	_expect(not coordinator.is_attack_in_flight(), "Completion must clear the in-flight state.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"Completion must move the scheduler to repeat wait.")
	var selected_delay: float = scheduler.get_last_selected_repeat_delay()
	scheduler.advance_time(selected_delay)
	_expect(controller.start_call_count == 2, "A repeat request must dispatch after its delay.")
	controller.emit_finished()
	controller.emit_cancelled()
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"Only one terminal result may be forwarded per attack lifecycle.")
	await _destroy_fixture(fixture)


func _test_start_failure() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var failed_count: Array[int] = [0]
	var success_count: Array[int] = [0]
	coordinator.attack_dispatch_failed.connect(func() -> void: failed_count[0] += 1)
	coordinator.attack_dispatch_succeeded.connect(func() -> void: success_count[0] += 1)
	controller.start_result = false

	scheduler.advance_time(0.0)
	_expect(controller.start_call_count == 1, "A failed dispatch must call start_attack once.")
	_expect(failed_count[0] == 1, "A failed dispatch must emit failure once.")
	_expect(success_count[0] == 0, "A failed dispatch must not emit success.")
	_expect(not coordinator.is_attack_in_flight(), "A failed dispatch must clear ownership.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"A failed dispatch must notify the scheduler of an abort.")
	await _destroy_fixture(fixture)


func _test_controller_cancellation() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	scheduler.advance_time(0.0)
	controller.emit_cancelled()

	_expect(not coordinator.is_attack_in_flight(), "Cancellation must clear the in-flight state.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"Cancellation must move the scheduler to repeat wait.")
	controller.emit_cancelled()
	controller.emit_finished()
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"Unrelated terminal signals must be ignored after cancellation.")
	await _destroy_fixture(fixture)


func _test_unrelated_terminal_signals() -> void:
	var fixture: Dictionary = _create_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	_expect(coordinator.bind(scheduler, controller), "The unrelated signal fixture must bind.")
	_expect(_configure_scheduler(scheduler, 10.0, 1.0), "The unrelated signal fixture must configure.")
	_expect(coordinator.start(), "The unrelated signal fixture must start.")
	controller.emit_finished()
	controller.emit_cancelled()
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_FIRST_ATTACK,
		"Terminal signals for an unowned attack must be ignored.")
	_expect(not coordinator.is_attack_in_flight(), "Unrelated signals must not create ownership.")
	await _destroy_fixture(fixture)


func _test_synchronous_cancellation_reentrancy() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var success_count: Array[int] = [0]
	var failed_count: Array[int] = [0]
	coordinator.attack_dispatch_succeeded.connect(func() -> void: success_count[0] += 1)
	coordinator.attack_dispatch_failed.connect(func() -> void: failed_count[0] += 1)
	controller.cancel_during_start = true

	scheduler.advance_time(0.0)
	_expect(controller.start_call_count == 1, "A reentrant cancellation must start once.")
	_expect(success_count[0] == 0,
		"A synchronously cancelled true result must not emit dispatch success.")
	_expect(failed_count[0] == 0,
		"A synchronously handled cancellation must not emit dispatch failure.")
	_expect(not coordinator.is_attack_in_flight(),
		"A synchronous cancellation must clear ownership before start returns.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"A synchronous cancellation must forward exactly one abort result.")
	controller.emit_finished()
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK,
		"A late finish after synchronous cancellation must be ignored.")
	await _destroy_fixture(fixture)


func _test_stop_contract() -> void:
	var owned_fixture: Dictionary = _create_started_fixture()
	var owned_coordinator: BossPhase1AttackCoordinator = owned_fixture.coordinator
	var owned_scheduler: BossPhase1AttackScheduler = owned_fixture.scheduler
	var owned_controller: TestAttackController = owned_fixture.controller
	owned_scheduler.advance_time(0.0)
	_expect(owned_coordinator.stop(), "Stop must succeed while running.")
	_expect(owned_controller.cancel_call_count == 1, "Stop must cancel its owned attack.")
	_expect(not owned_coordinator.is_running(), "Stop must clear running state.")
	_expect(not owned_coordinator.is_attack_in_flight(), "Stop must clear in-flight state.")
	_expect(owned_coordinator.is_bound(), "Stop must preserve binding.")
	_expect(owned_scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Stop cancellation must not create repeat wait.")
	_expect(not owned_coordinator.stop(), "Duplicate stop must be rejected.")
	_expect(owned_coordinator.start(), "A stopped coordinator must be restartable.")
	await _destroy_fixture(owned_fixture)

	var idle_fixture: Dictionary = _create_fixture()
	var idle_coordinator: BossPhase1AttackCoordinator = idle_fixture.coordinator
	var idle_scheduler: BossPhase1AttackScheduler = idle_fixture.scheduler
	var idle_controller: TestAttackController = idle_fixture.controller
	_expect(idle_coordinator.bind(idle_scheduler, idle_controller), "The idle stop fixture must bind.")
	_expect(_configure_scheduler(idle_scheduler, 10.0, 1.0), "The idle stop fixture must configure.")
	_expect(idle_coordinator.start(), "The idle stop fixture must start.")
	_expect(idle_coordinator.stop(), "Stopping without an owned attack must succeed.")
	_expect(idle_controller.cancel_call_count == 0,
		"Stop must not cancel an attack it did not start.")
	await _destroy_fixture(idle_fixture)

	var keep_fixture: Dictionary = _create_started_fixture()
	var keep_coordinator: BossPhase1AttackCoordinator = keep_fixture.coordinator
	var keep_scheduler: BossPhase1AttackScheduler = keep_fixture.scheduler
	var keep_controller: TestAttackController = keep_fixture.controller
	keep_scheduler.advance_time(0.0)
	_expect(keep_coordinator.stop(false), "Stop(false) must succeed.")
	_expect(keep_controller.cancel_call_count == 0, "Stop(false) must preserve the controller attack.")
	_expect(not keep_coordinator.is_attack_in_flight(), "Stop(false) must clear coordination ownership.")
	keep_controller.emit_finished()
	_expect(keep_coordinator.start(),
		"The coordinator may restart after the preserved controller attack finishes.")
	await _destroy_fixture(keep_fixture)


func _test_stop_false_ownership_contract() -> void:
	var finish_fixture: Dictionary = _create_started_fixture()
	var coordinator_a: BossPhase1AttackCoordinator = finish_fixture.coordinator
	var scheduler_a: BossPhase1AttackScheduler = finish_fixture.scheduler
	var controller_a: TestAttackController = finish_fixture.controller
	var scheduler_b: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var controller_b: TestAttackController = TestAttackController.new()
	scheduler_b.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scheduler_b)
	root.add_child(controller_b)
	_expect(_configure_scheduler(scheduler_b, 0.0, 1.0),
		"The replacement scheduler must configure.")

	scheduler_a.advance_time(0.0)
	_expect(controller_a.start_call_count == 1, "Controller A must own the active attack.")
	_expect(coordinator_a.stop(false), "Stop(false) must leave attack A running.")
	_expect(controller_a.cancel_call_count == 0, "Stop(false) must not cancel attack A.")
	_expect(not coordinator_a.start(),
		"Start must fail while the preserved attack A is still active.")
	_expect(scheduler_a.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"A rejected restart must leave scheduler A stopped.")
	_expect(controller_a.start_call_count == 1,
		"A rejected restart must not dispatch another controller attack.")

	_expect(coordinator_a.bind(scheduler_a, controller_a),
		"The same binding may be refreshed while attack A remains owned.")
	_expect(not coordinator_a.bind(scheduler_b, controller_b),
		"A different binding must be rejected while attack A remains owned.")
	_expect(coordinator_a.is_bound(), "A failed replacement bind must preserve binding A.")
	_expect(controller_a.cancel_call_count == 0 and controller_b.cancel_call_count == 0,
		"A failed replacement bind must not cancel either controller.")
	_expect(not coordinator_a.start(),
		"A failed replacement bind must preserve attack A ownership.")

	controller_a.emit_finished()
	_expect(scheduler_a.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"A preserved finish must not be forwarded to the stopped scheduler.")
	_expect(coordinator_a.start(), "Coordinator A must restart after attack A finishes.")
	scheduler_a.advance_time(0.0)
	_expect(controller_a.start_call_count == 2,
		"The preserved binding must dispatch the next request to controller A.")
	_expect(controller_b.start_call_count == 0,
		"A rejected replacement controller must remain unused.")

	controller_b.emit_finished()
	_expect(coordinator_a.is_attack_in_flight(),
		"Rejected controller B must not retain an attack_finished connection.")
	_expect(scheduler_a.get_current_state() == BossPhase1AttackScheduler.State.WAITING_FOR_ATTACK_FINISH,
		"Controller B signals must not complete scheduler A's attack.")
	controller_a.emit_finished()
	_expect(scheduler_b.start(), "Scheduler B must start independently for connection testing.")
	scheduler_b.advance_time(0.0)
	_expect(controller_a.start_call_count == 2,
		"Rejected scheduler B must not retain an attack_requested connection.")
	_expect(not coordinator_a.is_attack_in_flight(),
		"Rejected scheduler B must not create a new owned attack.")
	await _destroy_fixture(finish_fixture)
	scheduler_b.queue_free()
	controller_b.queue_free()
	await process_frame

	var cancel_fixture: Dictionary = _create_started_fixture()
	var cancel_coordinator: BossPhase1AttackCoordinator = cancel_fixture.coordinator
	var cancel_scheduler: BossPhase1AttackScheduler = cancel_fixture.scheduler
	var cancel_controller: TestAttackController = cancel_fixture.controller
	cancel_scheduler.advance_time(0.0)
	_expect(cancel_coordinator.stop(false),
		"The cancellation fixture must preserve its controller attack.")
	cancel_controller.emit_cancelled()
	_expect(cancel_scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"A preserved cancellation must not be forwarded to the stopped scheduler.")
	_expect(cancel_coordinator.start(),
		"The coordinator must restart after the preserved attack is cancelled.")
	await _destroy_fixture(cancel_fixture)


func _test_unbind_contract() -> void:
	var cancel_fixture: Dictionary = _create_started_fixture()
	var cancel_coordinator: BossPhase1AttackCoordinator = cancel_fixture.coordinator
	var cancel_scheduler: BossPhase1AttackScheduler = cancel_fixture.scheduler
	var cancel_controller: TestAttackController = cancel_fixture.controller
	cancel_scheduler.advance_time(0.0)
	cancel_coordinator.unbind(true)
	_expect(cancel_controller.cancel_call_count == 1, "Unbind(true) must cancel an owned attack.")
	_expect(not cancel_coordinator.is_bound(), "Unbind must clear binding.")
	cancel_controller.emit_finished()
	cancel_controller.emit_cancelled()
	_expect(cancel_scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Signals after unbind must be ignored.")
	cancel_coordinator.unbind()
	await _destroy_fixture(cancel_fixture)

	var keep_fixture: Dictionary = _create_started_fixture()
	var keep_coordinator: BossPhase1AttackCoordinator = keep_fixture.coordinator
	var keep_scheduler: BossPhase1AttackScheduler = keep_fixture.scheduler
	var keep_controller: TestAttackController = keep_fixture.controller
	keep_scheduler.advance_time(0.0)
	keep_coordinator.unbind(false)
	_expect(keep_controller.cancel_call_count == 0, "Unbind(false) must preserve the controller attack.")
	_expect(not keep_coordinator.is_bound(), "Unbind(false) must clear binding.")
	keep_controller.emit_cancelled()
	keep_controller.emit_finished()
	_expect(keep_scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"A preserved attack must not affect an unbound scheduler.")
	await _destroy_fixture(keep_fixture)


func _test_freed_scheduler_binding_loss() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var loss_count: Array[int] = [0]
	coordinator.binding_lost.connect(func() -> void: loss_count[0] += 1)
	scheduler.advance_time(0.0)
	scheduler.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "A freed scheduler must emit binding_lost exactly once.")
	_expect(not coordinator.is_running(), "Scheduler loss must stop the coordinator.")
	_expect(not coordinator.is_bound(), "Scheduler loss must clear the binding.")
	_expect(controller.cancel_call_count == 1,
		"Scheduler loss must cancel an owned attack when the controller survives.")
	await _destroy_fixture(fixture)


func _test_freed_controller_binding_loss() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var loss_count: Array[int] = [0]
	coordinator.binding_lost.connect(func() -> void: loss_count[0] += 1)
	scheduler.advance_time(0.0)
	controller.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1, "A freed controller must emit binding_lost exactly once.")
	_expect(not coordinator.is_running(), "Controller loss must stop the coordinator.")
	_expect(not coordinator.is_bound(), "Controller loss must clear the binding.")
	_expect(scheduler.get_current_state() == BossPhase1AttackScheduler.State.STOPPED,
		"Controller loss must stop a surviving scheduler.")
	await _destroy_fixture(fixture)


func _test_simultaneous_binding_loss() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	var loss_count: Array[int] = [0]
	coordinator.binding_lost.connect(func() -> void: loss_count[0] += 1)
	scheduler.advance_time(0.0)
	scheduler.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1,
		"Simultaneous scheduler and controller loss must emit binding_lost once.")
	_expect(not coordinator.is_running(),
		"Simultaneous binding loss must clear running state.")
	_expect(not coordinator.is_attack_in_flight(),
		"Simultaneous binding loss must clear attack ownership state.")
	_expect(not coordinator.is_bound(),
		"Simultaneous binding loss must clear both references.")
	await process_frame
	await process_frame
	_expect(loss_count[0] == 1,
		"Further processing must not emit binding_lost again.")
	await _destroy_fixture(fixture)


func _test_getters_do_not_mutate_state() -> void:
	var fixture: Dictionary = _create_started_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	scheduler.advance_time(0.0)
	var bound_before: bool = coordinator.is_bound()
	var running_before: bool = coordinator.is_running()
	var in_flight_before: bool = coordinator.is_attack_in_flight()
	_expect(coordinator.is_bound() == bound_before, "is_bound must not mutate state.")
	_expect(coordinator.is_running() == running_before, "is_running must not mutate state.")
	_expect(coordinator.is_attack_in_flight() == in_flight_before,
		"is_attack_in_flight must not mutate state.")
	await _destroy_fixture(fixture)


func _create_fixture() -> Dictionary:
	var coordinator: BossPhase1AttackCoordinator = CoordinatorScript.new()
	var scheduler: BossPhase1AttackScheduler = BossPhase1AttackScheduler.new()
	var controller: TestAttackController = TestAttackController.new()
	scheduler.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scheduler)
	root.add_child(controller)
	root.add_child(coordinator)
	return {
		&"coordinator": coordinator,
		&"scheduler": scheduler,
		&"controller": controller,
	}


func _create_started_fixture() -> Dictionary:
	var fixture: Dictionary = _create_fixture()
	var coordinator: BossPhase1AttackCoordinator = fixture.coordinator
	var scheduler: BossPhase1AttackScheduler = fixture.scheduler
	var controller: TestAttackController = fixture.controller
	_expect(coordinator.bind(scheduler, controller), "The fixture must bind.")
	_expect(_configure_scheduler(scheduler, 0.0, 1.0), "The fixture scheduler must configure.")
	_expect(coordinator.start(), "The fixture coordinator must start.")
	return fixture


func _configure_scheduler(
	scheduler: BossPhase1AttackScheduler,
	first_delay: float,
	repeat_delay: float
) -> bool:
	return scheduler.configure(first_delay, 0.0, repeat_delay, repeat_delay)


func _destroy_fixture(fixture: Dictionary) -> void:
	var coordinator_value: Variant = fixture.get(&"coordinator")
	var scheduler_value: Variant = fixture.get(&"scheduler")
	var controller_value: Variant = fixture.get(&"controller")
	if is_instance_valid(coordinator_value):
		var coordinator: BossPhase1AttackCoordinator = coordinator_value
		coordinator.unbind(true)
		coordinator.queue_free()
	if is_instance_valid(scheduler_value):
		var scheduler: BossPhase1AttackScheduler = scheduler_value
		scheduler.queue_free()
	if is_instance_valid(controller_value):
		var controller: TestAttackController = controller_value
		controller.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BossPhase1AttackCoordinator")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
