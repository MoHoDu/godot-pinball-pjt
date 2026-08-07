extends SceneTree


const TEST_DURATION_SEC: float = 0.24


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_state_and_configuration()
	await _test_activation_and_expiration()
	await _test_ready_activation_refreshes_without_stacking()
	_test_consumption_contract()
	await _test_reset_contract()
	_test_forbidden_dependencies()
	_finish()


func _test_initial_state_and_configuration() -> void:
	var counter_window := BossCounterWindow.new()
	_expect(not counter_window.is_ready(), "A new Window must not be ready.")
	_expect(is_zero_approx(counter_window.get_remaining_time_sec()),
		"A new Window must have zero remaining time.")
	_expect(not counter_window.activate(),
		"Activation before configuration must fail.")
	_expect(not counter_window.configure(0.0),
		"A zero duration must be rejected.")
	_expect(not counter_window.configure(-1.0),
		"A negative duration must be rejected.")
	_expect(not counter_window.configure(NAN),
		"A NAN duration must be rejected.")
	_expect(not counter_window.configure(INF),
		"An infinite duration must be rejected.")

	_expect(counter_window.configure(TEST_DURATION_SEC),
		"A finite positive duration must configure the Window.")
	_expect(not counter_window.configure(0.0),
		"An invalid reconfiguration must be rejected.")
	_expect(counter_window.activate(),
		"A failed reconfiguration must preserve the valid duration.")
	_expect(is_equal_approx(
		counter_window.get_remaining_time_sec(),
		TEST_DURATION_SEC
	), "Activation must use the preserved configured duration.")
	counter_window.free()


func _test_activation_and_expiration() -> void:
	var counter_window := BossCounterWindow.new()
	root.add_child(counter_window)
	var activated_count: Array[int] = [0]
	var expired_count: Array[int] = [0]
	counter_window.counter_activated.connect(func() -> void:
		activated_count[0] += 1
	)
	counter_window.counter_expired.connect(func() -> void:
		expired_count[0] += 1
	)
	_expect(counter_window.configure(TEST_DURATION_SEC),
		"Expiration fixture configuration must succeed.")
	_expect(counter_window.activate(), "Configured activation must succeed.")
	_expect(counter_window.is_ready(), "Activation must make Counter ready.")
	_expect(activated_count[0] == 1,
		"Activation must emit counter_activated exactly once.")
	_expect(is_equal_approx(
		counter_window.get_remaining_time_sec(),
		TEST_DURATION_SEC
	), "Activation must load the full configured duration.")

	await create_timer(TEST_DURATION_SEC * 0.35).timeout
	var decreased_remaining := counter_window.get_remaining_time_sec()
	_expect(counter_window.is_ready(),
		"The Window must remain ready before expiration.")
	_expect(decreased_remaining > 0.0
		and decreased_remaining < TEST_DURATION_SEC,
		"Remaining time must decrease only while ready.")

	await create_timer(TEST_DURATION_SEC * 0.45).timeout
	_expect(counter_window.is_ready(),
		"The Window must still be ready shortly before its duration ends.")
	await create_timer(TEST_DURATION_SEC * 0.35).timeout
	_expect(not counter_window.is_ready(),
		"The Window must stop being ready after expiration.")
	_expect(is_zero_approx(counter_window.get_remaining_time_sec()),
		"Expiration must clamp remaining time to zero.")
	_expect(expired_count[0] == 1,
		"Expiration must emit counter_expired exactly once.")

	await create_timer(TEST_DURATION_SEC * 0.5).timeout
	_expect(expired_count[0] == 1,
		"Further processing after expiration must not repeat the signal.")
	counter_window.queue_free()
	await process_frame


func _test_ready_activation_refreshes_without_stacking() -> void:
	var counter_window := BossCounterWindow.new()
	root.add_child(counter_window)
	var activated_count: Array[int] = [0]
	counter_window.counter_activated.connect(func() -> void:
		activated_count[0] += 1
	)
	_expect(counter_window.configure(TEST_DURATION_SEC),
		"Refresh fixture configuration must succeed.")
	_expect(counter_window.activate(), "Initial activation must succeed.")
	await create_timer(TEST_DURATION_SEC * 0.55).timeout
	var remaining_before_refresh := counter_window.get_remaining_time_sec()

	_expect(counter_window.activate(),
		"Activation while ready must refresh the Window.")
	var remaining_after_refresh := counter_window.get_remaining_time_sec()
	_expect(counter_window.is_ready(),
		"Refreshing must keep the single Counter ready.")
	_expect(remaining_after_refresh > remaining_before_refresh,
		"Refreshing must restore the full configured duration.")
	_expect(is_equal_approx(remaining_after_refresh, TEST_DURATION_SEC),
		"Refreshing must restore exactly one full duration, not stack time.")
	_expect(activated_count[0] == 2,
		"Each Counter acquisition, including refresh, must emit once.")

	await create_timer(TEST_DURATION_SEC * 0.55).timeout
	_expect(counter_window.is_ready(),
		"A refreshed Window must remain ready beyond the original expiration.")
	counter_window.queue_free()
	await process_frame


func _test_consumption_contract() -> void:
	var counter_window := BossCounterWindow.new()
	var consumed_count: Array[int] = [0]
	var expired_count: Array[int] = [0]
	counter_window.counter_consumed.connect(func() -> void:
		consumed_count[0] += 1
	)
	counter_window.counter_expired.connect(func() -> void:
		expired_count[0] += 1
	)
	_expect(counter_window.configure(TEST_DURATION_SEC),
		"Consume fixture configuration must succeed.")
	_expect(not counter_window.consume(),
		"Consuming while not ready must fail silently.")
	_expect(counter_window.activate(), "Counter must activate before consumption.")
	_expect(counter_window.consume(), "A ready Counter must be consumable.")
	_expect(not counter_window.is_ready(),
		"Consumption must clear the ready state.")
	_expect(is_zero_approx(counter_window.get_remaining_time_sec()),
		"Consumption must clear remaining time.")
	_expect(consumed_count[0] == 1,
		"Successful consumption must emit exactly once.")
	_expect(expired_count[0] == 0,
		"Consumption must not be reported as expiration.")
	_expect(not counter_window.consume(),
		"Repeated consumption while not ready must return false.")
	_expect(consumed_count[0] == 1,
		"Failed repeated consumption must not emit another signal.")
	counter_window.free()


func _test_reset_contract() -> void:
	var counter_window := BossCounterWindow.new()
	root.add_child(counter_window)
	var consumed_count: Array[int] = [0]
	var expired_count: Array[int] = [0]
	counter_window.counter_consumed.connect(func() -> void:
		consumed_count[0] += 1
	)
	counter_window.counter_expired.connect(func() -> void:
		expired_count[0] += 1
	)
	_expect(counter_window.configure(TEST_DURATION_SEC),
		"Reset fixture configuration must succeed.")
	counter_window.reset()
	_expect(not counter_window.is_ready()
		and is_zero_approx(counter_window.get_remaining_time_sec()),
		"Reset while inactive must preserve the initial state.")
	_expect(counter_window.activate(), "Counter must activate before reset.")
	counter_window.reset()
	_expect(not counter_window.is_ready(), "Reset must clear the ready state.")
	_expect(is_zero_approx(counter_window.get_remaining_time_sec()),
		"Reset must clear remaining time.")
	_expect(consumed_count[0] == 0 and expired_count[0] == 0,
		"Reset must not emit consumed or expired signals.")

	await create_timer(TEST_DURATION_SEC + 0.08).timeout
	_expect(expired_count[0] == 0,
		"Time after reset must not produce a delayed expiration signal.")
	counter_window.queue_free()
	await process_frame


func _test_forbidden_dependencies() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_counter_window.gd"
	)
	for forbidden_name: String in [
		"TeddyArmSweepAttack",
		"BossArmHitBallTracker",
		"BossParryCounterResolver",
		"Pinball",
		"Flipper",
		"BossDamageApplier",
		"BossGatedDamageApplier",
		"BossHealthComponent",
		"ComboSystem",
		"Control",
		"Stage1BossPhase1Rules",
	]:
		_expect(not source.contains(forbidden_name),
			"Counter Window must not depend on %s." % forbidden_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BossCounterWindow tests passed.")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)
