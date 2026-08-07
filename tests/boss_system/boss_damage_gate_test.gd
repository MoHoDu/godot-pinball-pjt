extends SceneTree


const GATE_SCRIPT_PATH := "res://scripts/boss_system/boss_damage_gate.gd"
const TEST_DURATION := 0.08


class RecordingAttack extends TeddyArmSweepAttack:
	func _ready() -> void:
		pass

	func prepare_attack() -> void:
		pass

	func begin_telegraph(_duration: float) -> void:
		pass

	func begin_active(_duration: float) -> void:
		pass

	func begin_recovery(_duration: float) -> void:
		pass

	func begin_cooldown() -> void:
		pass

	func finish_attack() -> void:
		pass

	func cancel_attack() -> void:
		pass


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_unbound_state_and_null_rejection()
	await _test_freed_controller_bind_is_rejected()
	await _test_idle_bind_and_idempotent_rebind()
	await _test_failed_rebind_preserves_existing_binding()
	await _test_valid_rebind_switches_controller_connections()
	await _test_attack_sequence_and_signal_policy()
	await _test_active_cancellation_restores_damage()
	await _test_bind_synchronizes_an_active_controller()
	await _test_unbind_is_safe_and_ignores_old_controller()
	await _test_controller_loss_is_fail_closed()
	await _test_controller_tree_exit_is_fail_closed()
	await _test_tree_exit_cancel_signal_remains_fail_closed()
	_test_forbidden_dependencies()
	_finish()


func _test_initial_unbound_state_and_null_rejection() -> void:
	var gate: BossDamageGate = BossDamageGate.new()
	_expect(not gate.is_bound(), "A new gate must be unbound.")
	_expect(not gate.is_damage_allowed(),
		"An unbound gate must reject damage.")
	_expect(gate.is_invulnerable(),
		"An unbound gate must report fail-closed invulnerability.")
	_expect(not gate.bind_controller(null),
		"A null controller binding must be rejected.")
	_expect(not gate.is_bound() and gate.is_invulnerable(),
		"A rejected null binding must preserve the fail-closed state.")
	gate.free()


func _test_freed_controller_bind_is_rejected() -> void:
	var gate: BossDamageGate = BossDamageGate.new()
	var controller: BossAttackController = BossAttackController.new()
	root.add_child(gate)
	root.add_child(controller)
	await process_frame
	controller.queue_free()
	await process_frame

	_expect(not gate.bind_controller(controller),
		"A freed controller binding must be rejected.")
	_expect(not gate.is_bound() and not gate.is_damage_allowed(),
		"A freed binding request must leave the gate fail-closed.")
	gate.queue_free()
	await process_frame


func _test_idle_bind_and_idempotent_rebind() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)

	_expect(gate.bind_controller(controller),
		"A live controller binding must succeed.")
	_expect(gate.is_bound(), "A successful binding must be observable.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"Binding an IDLE controller must allow damage immediately.")
	_expect(invulnerability_events == [false],
		"IDLE binding must expose the one fail-closed to allowed change.")

	invulnerability_events.clear()
	_expect(gate.bind_controller(controller),
		"Binding the same controller again must succeed.")
	_expect(invulnerability_events.is_empty(),
		"An equivalent same-controller rebind must not emit a state change.")
	_expect(controller.state_changed.get_connections().size() == 1,
		"A same-controller rebind must not duplicate the Gate connection.")
	await _destroy_fixture(fixture)


func _test_failed_rebind_preserves_existing_binding() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invalid_controller: BossAttackController = BossAttackController.new()
	root.add_child(invalid_controller)
	await process_frame
	_expect(gate.bind_controller(controller),
		"The original controller must bind before failed-rebind checks.")
	invalid_controller.queue_free()
	await process_frame

	_expect(not gate.bind_controller(invalid_controller),
		"A rebind to a freed controller must fail.")
	_expect(gate.is_bound() and gate.is_damage_allowed(),
		"A failed rebind must preserve the original IDLE binding.")
	_expect(controller.state_changed.get_connections().size() == 1,
		"A failed rebind must preserve the original signal connection.")

	_expect(controller.start_attack(),
		"The preserved controller must still start an attack.")
	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The preserved controller must still drive Gate state changes.")
	_expect(gate.is_invulnerable() and not gate.is_damage_allowed(),
		"The preserved connection must still block damage in ACTIVE.")
	controller.cancel_attack()
	await _destroy_fixture(fixture)


func _test_valid_rebind_switches_controller_connections() -> void:
	var first_fixture: Dictionary = await _create_fixture()
	var second_fixture: Dictionary = await _create_fixture(false)
	var gate: BossDamageGate = first_fixture.gate
	var first_controller: BossAttackController = first_fixture.controller
	var second_controller: BossAttackController = second_fixture.controller

	_expect(gate.bind_controller(second_controller),
		"Rebinding to a different live controller must succeed.")
	_expect(first_controller.state_changed.get_connections().is_empty(),
		"A valid rebind must disconnect the previous controller.")
	_expect(second_controller.state_changed.get_connections().size() == 1,
		"A valid rebind must connect the new controller exactly once.")
	_expect(gate.is_damage_allowed(),
		"Rebinding to an IDLE controller must synchronize an allowed state.")

	first_controller.start_attack()
	_expect(await _wait_until_state(
		first_controller, BossAttackController.State.ACTIVE
	), "The previous controller must remain independently operable.")
	_expect(gate.is_damage_allowed(),
		"Previous-controller transitions must not affect the rebound Gate.")
	first_controller.cancel_attack()

	second_controller.start_attack()
	_expect(await _wait_until_state(
		second_controller, BossAttackController.State.ACTIVE
	), "The replacement controller must reach ACTIVE.")
	_expect(gate.is_invulnerable() and not gate.is_damage_allowed(),
		"The replacement controller must drive the Gate after rebind.")
	second_controller.cancel_attack()
	await _destroy_fixture(first_fixture)
	await _destroy_fixture(second_fixture)


func _test_attack_sequence_and_signal_policy() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.bind_controller(controller)
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)

	_expect(controller.start_attack(), "The state-sequence attack must start.")
	_expect(controller.current_state == BossAttackController.State.TELEGRAPH,
		"start_attack must enter TELEGRAPH synchronously.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"TELEGRAPH must allow damage.")
	_expect(invulnerability_events.is_empty(),
		"IDLE to TELEGRAPH must not emit invulnerability_changed.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The attack must reach ACTIVE.")
	_expect(not gate.is_damage_allowed() and gate.is_invulnerable(),
		"ACTIVE must block damage.")
	_expect(invulnerability_events == [true],
		"TELEGRAPH to ACTIVE must emit true exactly once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.RECOVERY
	), "The attack must reach RECOVERY.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"RECOVERY must allow damage.")
	_expect(invulnerability_events == [true, false],
		"ACTIVE to RECOVERY must emit false exactly once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.COOLDOWN
	), "The attack must reach COOLDOWN.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"COOLDOWN must allow damage.")
	_expect(invulnerability_events == [true, false],
		"RECOVERY to COOLDOWN must not emit another Gate signal.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.IDLE
	), "The attack must return to IDLE.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"The returned IDLE state must allow damage.")
	_expect(invulnerability_events == [true, false],
		"COOLDOWN to IDLE must not emit another Gate signal.")
	await _destroy_fixture(fixture)


func _test_active_cancellation_restores_damage() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.bind_controller(controller)
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)
	controller.start_attack()
	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The cancellation attack must reach ACTIVE.")

	_expect(controller.cancel_attack(),
		"Cancelling an ACTIVE controller must succeed.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"ACTIVE cancellation must return the controller to IDLE.")
	_expect(gate.is_damage_allowed() and not gate.is_invulnerable(),
		"ACTIVE cancellation must allow damage immediately.")
	_expect(invulnerability_events == [true, false],
		"ACTIVE cancellation must produce one block and one restore event.")
	await _destroy_fixture(fixture)


func _test_bind_synchronizes_an_active_controller() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	controller.start_attack()
	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The pre-bind controller must reach ACTIVE.")

	_expect(gate.bind_controller(controller),
		"Binding an already ACTIVE controller must succeed.")
	_expect(gate.is_invulnerable() and not gate.is_damage_allowed(),
		"ACTIVE state must be synchronized during bind.")
	controller.cancel_attack()
	_expect(gate.is_damage_allowed(),
		"The newly bound Gate must observe later ACTIVE cancellation.")
	await _destroy_fixture(fixture)


func _test_unbind_is_safe_and_ignores_old_controller() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.bind_controller(controller)
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)

	gate.unbind_controller()
	_expect(not gate.is_bound(), "unbind_controller must clear the binding.")
	_expect(not gate.is_damage_allowed() and gate.is_invulnerable(),
		"Unbind must restore the fail-closed state.")
	_expect(invulnerability_events == [true],
		"Allowed to unbound must emit invulnerability true once.")
	gate.unbind_controller()
	_expect(invulnerability_events == [true],
		"A duplicate unbind must not emit another signal.")

	controller.start_attack()
	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The old controller must still operate after Gate unbind.")
	controller.cancel_attack()
	_expect(invulnerability_events == [true],
		"Old controller transitions must not affect an unbound Gate.")
	_expect(gate.is_invulnerable() and not gate.is_damage_allowed(),
		"The unbound Gate must remain fail-closed.")
	await _destroy_fixture(fixture)


func _test_controller_loss_is_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.bind_controller(controller)
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)
	controller.queue_free()
	await process_frame
	await process_frame

	_expect(not gate.is_bound(),
		"A Gate must not report a freed controller as bound.")
	_expect(not gate.is_damage_allowed(),
		"Controller loss must reject damage.")
	_expect(gate.is_invulnerable(),
		"Controller loss must report fail-closed invulnerability.")
	_expect(invulnerability_events == [true],
		"Losing an allowed controller must expose one fail-closed change.")
	await _destroy_fixture(fixture)


func _test_controller_tree_exit_is_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.bind_controller(controller)
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)
	root.remove_child(controller)

	_expect(not gate.is_bound(),
		"A controller outside SceneTree must not remain a live binding.")
	_expect(not gate.is_damage_allowed() and gate.is_invulnerable(),
		"Tree exit must become fail-closed before deferred cleanup.")
	await process_frame
	_expect(invulnerability_events == [true],
		"Tree-exit cleanup must expose one fail-closed state change.")
	await _destroy_fixture(fixture)


func _test_tree_exit_cancel_signal_remains_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture()
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var invulnerability_events: Array[bool] = []
	gate.invulnerability_changed.connect(func(value: bool) -> void:
		invulnerability_events.append(value)
	)
	controller.start_attack()
	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The Tree-exit cancellation fixture must reach ACTIVE.")
	_expect(gate.is_invulnerable() and invulnerability_events == [true],
		"ACTIVE must establish one invulnerability event before Tree exit.")

	root.remove_child(controller)
	_expect(controller.cancel_attack(),
		"The live Controller must emit ACTIVE to IDLE while outside Tree.")
	_expect(invulnerability_events == [true],
		"A Tree-exited Controller must not emit a false Gate event.")
	_expect(not gate.is_bound(),
		"The invalid callback must clear the lost binding immediately.")
	_expect(not gate.is_damage_allowed() and gate.is_invulnerable(),
		"Tree-exit cancellation must remain fail-closed.")
	await _destroy_fixture(fixture)


func _test_forbidden_dependencies() -> void:
	var source: String = FileAccess.get_file_as_string(GATE_SCRIPT_PATH)
	_expect(not source.is_empty(), "The BossDamageGate source must be readable.")
	for forbidden_name: String in [
		"BossHealthComponent",
		"BossComboDamageAdapter",
		"BossDamageApplier",
		"Pinball",
		"ComboSystem",
	]:
		_expect(not source.contains(forbidden_name),
			"BossDamageGate must not reference %s." % forbidden_name)


func _create_fixture(bind_gate: bool = true) -> Dictionary:
	var attack: RecordingAttack = RecordingAttack.new()
	var controller: BossAttackController = BossAttackController.new()
	var gate: BossDamageGate = BossDamageGate.new()
	var pattern: BossAttackPattern = BossAttackPattern.new()
	pattern.attack_id = &"damage_gate_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	controller.pattern = pattern
	controller.attack = attack
	root.add_child(attack)
	root.add_child(controller)
	root.add_child(gate)
	await process_frame
	if bind_gate:
		_expect(gate.bind_controller(controller),
			"The test fixture Gate must bind its live controller.")
	return {
		&"attack": attack,
		&"controller": controller,
		&"gate": gate,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	for key: StringName in [&"gate", &"controller", &"attack"]:
		var node: Node = fixture.get(key) as Node
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.queue_free()
			else:
				node.free()
	await process_frame


func _wait_until_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames: int = 240
) -> bool:
	for _frame: int in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_damage_gate_test")
		quit(0)
		return
	print("FAIL: boss_damage_gate_test (%d failures)" % _failures.size())
	quit(1)
