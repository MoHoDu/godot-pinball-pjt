extends SceneTree


const PATTERN_PATH := "res://settings/bosses/TeddyArmSweepPattern.tres"
const ATTACK_SCENE_PATH := "res://scenes/boss_system/teddy_arm_sweep_attack.tscn"
const TEST_DURATION := 0.03


class RecordingAttack extends TeddyArmSweepAttack:
	var prepare_calls := 0
	var telegraph_calls := 0
	var active_calls := 0
	var recovery_calls := 0
	var cooldown_calls := 0
	var finish_calls := 0
	var cancel_calls := 0
	var detection_active := false

	func _ready() -> void:
		pass

	func prepare_attack() -> void:
		prepare_calls += 1
		detection_active = false

	func begin_telegraph(_duration: float) -> void:
		telegraph_calls += 1

	func begin_active(_duration: float) -> void:
		active_calls += 1
		detection_active = true

	func begin_recovery(_duration: float) -> void:
		recovery_calls += 1
		detection_active = false

	func begin_cooldown() -> void:
		cooldown_calls += 1
		detection_active = false

	func finish_attack() -> void:
		finish_calls += 1
		detection_active = false

	func cancel_attack() -> void:
		cancel_calls += 1
		detection_active = false

	func is_detection_active() -> bool:
		return detection_active

	func get_stage_call_count(state: BossAttackController.State) -> int:
		match state:
			BossAttackController.State.TELEGRAPH:
				return telegraph_calls
			BossAttackController.State.ACTIVE:
				return active_calls
			BossAttackController.State.RECOVERY:
				return recovery_calls
			BossAttackController.State.COOLDOWN:
				return cooldown_calls
		return 0


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_authored_pattern()
	await _test_single_attack_sequence()
	await _test_cancellation_from_each_running_state()
	await _test_attack_started_reentrant_start()
	await _test_attack_started_reentrant_cancel()
	await _test_state_changed_reentrant_cancellation()
	_finish()


func _test_authored_pattern() -> void:
	var pattern := load(PATTERN_PATH) as BossAttackPattern
	_expect(pattern != null, "The Teddy arm pattern resource must load.")
	if pattern == null:
		return
	_expect(pattern.attack_id == &"teddy_arm_sweep",
		"The authored attack id must be teddy_arm_sweep.")
	_expect(is_equal_approx(pattern.telegraph_duration, 0.9),
		"Telegraph duration must be 0.9 seconds.")
	_expect(is_equal_approx(pattern.active_duration, 0.25),
		"Active duration must be 0.25 seconds.")
	_expect(is_equal_approx(pattern.recovery_duration, 0.7),
		"Recovery duration must be 0.7 seconds.")
	_expect(is_equal_approx(pattern.cooldown_duration, 1.5),
		"Cooldown duration must be 1.5 seconds.")
	_expect(not _has_property(pattern, &"repeat_count"),
		"The first prototype must not expose repeat_count.")


func _test_single_attack_sequence() -> void:
	var fixture := await _create_fixture()
	var controller: BossAttackController = fixture.controller
	var states: Array[int] = []
	var signal_counts := {
		&"attack_started": 0,
		&"telegraph_started": 0,
		&"active_started": 0,
		&"recovery_started": 0,
		&"cooldown_started": 0,
		&"attack_finished": 0,
	}
	controller.state_changed.connect(func(
		_previous_state: BossAttackController.State,
		current_state: BossAttackController.State
	) -> void:
		states.append(current_state)
	)
	controller.attack_started.connect(func(_attack_id: StringName) -> void:
		signal_counts[&"attack_started"] += 1
	)
	controller.telegraph_started.connect(func() -> void:
		signal_counts[&"telegraph_started"] += 1
	)
	controller.active_started.connect(func() -> void:
		signal_counts[&"active_started"] += 1
	)
	controller.recovery_started.connect(func() -> void:
		signal_counts[&"recovery_started"] += 1
	)
	controller.cooldown_started.connect(func() -> void:
		signal_counts[&"cooldown_started"] += 1
	)
	controller.attack_finished.connect(func() -> void:
		signal_counts[&"attack_finished"] += 1
	)

	_expect(controller.current_state == BossAttackController.State.IDLE,
		"A controller must begin in IDLE.")
	_expect(not controller.cancel_attack(),
		"Cancelling from IDLE must return false.")
	_expect(controller.start_attack(), "The first start_attack call must succeed.")
	_expect(not controller.start_attack(),
		"A second start_attack call while running must be rejected.")
	var completed := await _wait_until_state(
		controller,
		BossAttackController.State.IDLE
	)
	_expect(completed, "A single attack must return to IDLE.")
	_expect(states == [
		BossAttackController.State.TELEGRAPH,
		BossAttackController.State.ACTIVE,
		BossAttackController.State.RECOVERY,
		BossAttackController.State.COOLDOWN,
		BossAttackController.State.IDLE,
	], "Attack states must advance once in the required order.")
	for signal_name: StringName in signal_counts:
		_expect(int(signal_counts[signal_name]) == 1,
			"%s must be emitted exactly once." % signal_name)

	var state_count_after_finish := states.size()
	await create_timer(TEST_DURATION * 3.0).timeout
	_expect(states.size() == state_count_after_finish,
		"A finished attack must not restart automatically.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"A finished attack must remain in IDLE.")
	_expect(controller.start_attack(),
		"A new attack must be startable after returning to IDLE.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The second explicitly started attack must finish.")
	await _destroy_fixture(fixture)


func _test_cancellation_from_each_running_state() -> void:
	for cancellation_state: BossAttackController.State in [
		BossAttackController.State.TELEGRAPH,
		BossAttackController.State.ACTIVE,
		BossAttackController.State.RECOVERY,
		BossAttackController.State.COOLDOWN,
	]:
		await _test_cancellation_from_state(cancellation_state)


func _test_cancellation_from_state(
	cancellation_state: BossAttackController.State
) -> void:
	var fixture := await _create_fixture()
	var controller: BossAttackController = fixture.controller
	var attack: TeddyArmSweepAttack = fixture.attack
	var cancelled_count := {&"value": 0}
	var finished_count := {&"value": 0}
	var state_change_count := {&"value": 0}
	controller.attack_cancelled.connect(func() -> void:
		cancelled_count.value += 1
	)
	controller.attack_finished.connect(func() -> void:
		finished_count.value += 1
	)
	controller.state_changed.connect(func(
		_previous_state: BossAttackController.State,
		_current_state: BossAttackController.State
	) -> void:
		state_change_count.value += 1
	)

	_expect(controller.start_attack(),
		"The cancellation fixture must start an attack.")
	_expect(await _wait_until_state(controller, cancellation_state),
		"The attack must reach %s before cancellation."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(controller.cancel_attack(),
		"Cancelling from %s must return true."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"Cancellation must return the controller to IDLE.")
	_expect(not attack.is_detection_active(),
		"Cancellation must disable attack detection immediately.")
	_expect(attack.get_registered_target_count() == 0,
		"Cancellation must clear the attack hit registry.")
	_expect(is_equal_approx(
		attack.arm_pivot.rotation,
		deg_to_rad(attack.idle_angle_degrees)
	), "Cancellation must restore the arm to its idle angle.")
	_expect(int(cancelled_count.value) == 1,
		"attack_cancelled must be emitted exactly once.")

	var changes_after_cancel := int(state_change_count.value)
	await create_timer(TEST_DURATION * 7.0).timeout
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"A cancelled run must remain in IDLE after old timers wake.")
	_expect(int(state_change_count.value) == changes_after_cancel,
		"Old timer results must not transition a cancelled run.")
	_expect(int(finished_count.value) == 0,
		"A cancelled run must not emit attack_finished.")
	_expect(int(cancelled_count.value) == 1,
		"A cancelled run must not emit attack_cancelled again later.")

	_expect(controller.start_attack(),
		"A new attack must be startable after cancellation.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The post-cancellation attack must complete normally.")
	_expect(int(finished_count.value) == 1,
		"The post-cancellation attack must emit attack_finished once.")
	await _destroy_fixture(fixture)


func _test_attack_started_reentrant_start() -> void:
	var fixture := await _create_recording_fixture()
	var controller: BossAttackController = fixture.controller
	var attack: RecordingAttack = fixture.attack
	var nested_start_result := {&"value": true}
	var attack_started_count := {&"value": 0}
	var states: Array[int] = []
	var event_order: Array[StringName] = []
	controller.state_changed.connect(func(
		_previous_state: BossAttackController.State,
		current_state: BossAttackController.State
	) -> void:
		states.append(current_state)
		if current_state == BossAttackController.State.TELEGRAPH:
			event_order.append(&"state_changed_telegraph")
	)
	controller.attack_started.connect(func(_attack_id: StringName) -> void:
		attack_started_count.value += 1
		event_order.append(&"attack_started")
		nested_start_result.value = controller.start_attack()
	)
	controller.telegraph_started.connect(func() -> void:
		event_order.append(&"telegraph_started")
	)

	_expect(controller.start_attack(),
		"The outer reentrant-start attack must begin.")
	_expect(not bool(nested_start_result.value),
		"start_attack inside attack_started must return false.")
	_expect(event_order.slice(0, 3) == [
		&"state_changed_telegraph",
		&"attack_started",
		&"telegraph_started",
	], "TELEGRAPH state, attack_started, and telegraph_started order must be fixed.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The reentrant-start fixture must finish normally.")
	_expect(int(attack_started_count.value) == 1,
		"A rejected reentrant start must not emit a second attack_started.")
	_expect(attack.prepare_calls == 1 and attack.telegraph_calls == 1,
		"A rejected reentrant start must create exactly one attack run.")
	_expect(states == [
		BossAttackController.State.TELEGRAPH,
		BossAttackController.State.ACTIVE,
		BossAttackController.State.RECOVERY,
		BossAttackController.State.COOLDOWN,
		BossAttackController.State.IDLE,
	], "A rejected reentrant start must not duplicate state transitions.")
	await _destroy_fixture(fixture)


func _test_attack_started_reentrant_cancel() -> void:
	var fixture := await _create_recording_fixture()
	var controller: BossAttackController = fixture.controller
	var attack: RecordingAttack = fixture.attack
	var cancel_on_started := {&"value": true}
	var cancel_result := {&"value": false}
	var cancelled_count := {&"value": 0}
	var telegraph_started_count := {&"value": 0}
	var finished_count := {&"value": 0}
	var states: Array[int] = []
	controller.state_changed.connect(func(
		_previous_state: BossAttackController.State,
		current_state: BossAttackController.State
	) -> void:
		states.append(current_state)
	)
	controller.attack_started.connect(func(_attack_id: StringName) -> void:
		if bool(cancel_on_started.value):
			cancel_on_started.value = false
			cancel_result.value = controller.cancel_attack()
	)
	controller.telegraph_started.connect(func() -> void:
		telegraph_started_count.value += 1
	)
	controller.attack_cancelled.connect(func() -> void:
		cancelled_count.value += 1
	)
	controller.attack_finished.connect(func() -> void:
		finished_count.value += 1
	)

	_expect(controller.start_attack(),
		"The attack_started cancellation fixture must begin.")
	_expect(bool(cancel_result.value),
		"cancel_attack inside attack_started must return true.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"attack_started cancellation must return to IDLE immediately.")
	_expect(int(cancelled_count.value) == 1,
		"attack_started cancellation must emit attack_cancelled once.")
	_expect(int(telegraph_started_count.value) == 0 and attack.telegraph_calls == 0,
		"attack_started cancellation must prevent TELEGRAPH behavior.")
	var changes_after_cancel := states.size()
	await create_timer(TEST_DURATION * 7.0).timeout
	_expect(states.size() == changes_after_cancel \
			and controller.current_state == BossAttackController.State.IDLE,
		"A run cancelled in attack_started must not wake later.")
	_expect(int(finished_count.value) == 0,
		"A run cancelled in attack_started must not emit attack_finished.")

	_expect(controller.start_attack(),
		"A new attack must start after attack_started cancellation.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The post-attack_started-cancellation run must finish.")
	_expect(int(finished_count.value) == 1,
		"The new run must finish exactly once.")
	await _destroy_fixture(fixture)


func _test_state_changed_reentrant_cancellation() -> void:
	for cancellation_state: BossAttackController.State in [
		BossAttackController.State.TELEGRAPH,
		BossAttackController.State.ACTIVE,
		BossAttackController.State.RECOVERY,
		BossAttackController.State.COOLDOWN,
	]:
		await _test_state_changed_cancel_from_state(cancellation_state)


func _test_state_changed_cancel_from_state(
	cancellation_state: BossAttackController.State
) -> void:
	var fixture := await _create_recording_fixture()
	var controller: BossAttackController = fixture.controller
	var attack: RecordingAttack = fixture.attack
	var cancel_result := {&"called": false, &"value": false}
	var cancelled_count := {&"value": 0}
	var finished_count := {&"value": 0}
	var stage_signal_counts := {
		BossAttackController.State.TELEGRAPH: 0,
		BossAttackController.State.ACTIVE: 0,
		BossAttackController.State.RECOVERY: 0,
		BossAttackController.State.COOLDOWN: 0,
	}
	var state_change_count := {&"value": 0}
	controller.state_changed.connect(func(
		_previous_state: BossAttackController.State,
		current_state: BossAttackController.State
	) -> void:
		state_change_count.value += 1
		if current_state == cancellation_state \
				and not bool(cancel_result.called):
			cancel_result.called = true
			cancel_result.value = controller.cancel_attack()
	)
	controller.telegraph_started.connect(func() -> void:
		stage_signal_counts[BossAttackController.State.TELEGRAPH] += 1
	)
	controller.active_started.connect(func() -> void:
		stage_signal_counts[BossAttackController.State.ACTIVE] += 1
	)
	controller.recovery_started.connect(func() -> void:
		stage_signal_counts[BossAttackController.State.RECOVERY] += 1
	)
	controller.cooldown_started.connect(func() -> void:
		stage_signal_counts[BossAttackController.State.COOLDOWN] += 1
	)
	controller.attack_cancelled.connect(func() -> void:
		cancelled_count.value += 1
	)
	controller.attack_finished.connect(func() -> void:
		finished_count.value += 1
	)

	_expect(controller.start_attack(),
		"The state_changed cancellation fixture must begin.")
	_expect(await _wait_until_flag(cancel_result, &"called"),
		"The fixture must reach %s and cancel from state_changed."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(bool(cancel_result.value),
		"state_changed cancellation from %s must return true."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"state_changed cancellation must leave the controller in IDLE.")
	_expect(attack.get_stage_call_count(cancellation_state) == 0,
		"The cancelled %s stage function must not execute."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(int(stage_signal_counts[cancellation_state]) == 0,
		"The cancelled %s stage signal must not emit."
		% BossAttackController.State.keys()[cancellation_state])
	_expect(not attack.is_detection_active(),
		"state_changed cancellation must keep detection disabled.")
	_expect(int(cancelled_count.value) == 1,
		"state_changed cancellation must emit attack_cancelled once.")

	var changes_after_cancel := int(state_change_count.value)
	await create_timer(TEST_DURATION * 7.0).timeout
	_expect(int(state_change_count.value) == changes_after_cancel \
			and controller.current_state == BossAttackController.State.IDLE,
		"The cancelled state's delayed result must not transition later.")
	_expect(int(finished_count.value) == 0,
		"A state_changed-cancelled run must not finish automatically.")

	_expect(controller.start_attack(),
		"A new attack must start after state_changed cancellation.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The new attack after state_changed cancellation must finish.")
	_expect(int(finished_count.value) == 1,
		"Only the new post-cancellation run must emit attack_finished.")
	await _destroy_fixture(fixture)


func _create_fixture() -> Dictionary:
	var packed_attack := load(ATTACK_SCENE_PATH) as PackedScene
	var attack := packed_attack.instantiate() as TeddyArmSweepAttack
	var controller := BossAttackController.new()
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"controller_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	controller.pattern = pattern
	controller.attack = attack
	root.add_child(attack)
	root.add_child(controller)
	await process_frame
	return {
		&"attack": attack,
		&"controller": controller,
	}


func _create_recording_fixture() -> Dictionary:
	var attack := RecordingAttack.new()
	var controller := BossAttackController.new()
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"reentrancy_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	controller.pattern = pattern
	controller.attack = attack
	root.add_child(attack)
	root.add_child(controller)
	await process_frame
	return {
		&"attack": attack,
		&"controller": controller,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	(fixture.controller as Node).queue_free()
	(fixture.attack as Node).queue_free()
	await process_frame


func _wait_until_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames := 240
) -> bool:
	for _frame in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _wait_until_flag(
	container: Dictionary,
	key: StringName,
	maximum_frames := 240
) -> bool:
	for _frame in maximum_frames:
		if bool(container.get(key, false)):
			return true
		await process_frame
	return false


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get(&"name", &"")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_attack_controller_test")
		quit(0)
		return
	print("FAIL: boss_attack_controller_test (%d failures)" % _failures.size())
	quit(1)
