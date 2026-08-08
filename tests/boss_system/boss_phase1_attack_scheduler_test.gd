extends SceneTree

const Scheduler = preload("res://scripts/boss_system/boss_phase1_attack_scheduler.gd")

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_state()
	_test_configure_validation_and_preservation()
	_test_start_and_first_attack()
	_test_repeat_wait_and_notifications()
	_test_seed_reproducibility()
	_test_fixed_repeat_delay()
	_test_new_ball_grace()
	_test_pause_and_resume()
	_test_stop_and_reset()
	_test_zero_delays()
	_test_large_delta_and_reentrant_request()
	_test_invalid_delta_and_getters()
	_test_grace_cancellation_signals()

	if _failures.is_empty():
		print("PASS: BossPhase1AttackScheduler")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_initial_state() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	_expect_false(scheduler.is_configured(), "initial state is unconfigured")
	_expect_false(scheduler.is_running(), "initial state is not running")
	_expect_false(scheduler.is_paused(), "initial state is not paused")
	_expect_false(scheduler.is_grace_active(), "initial state has no grace")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.STOPPED, "initial state is stopped")
	_expect_approx(scheduler.get_wait_time_remaining(), 0.0, "initial wait is zero")
	scheduler.free()


func _test_configure_validation_and_preservation() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	_expect_true(scheduler.configure(3.0, 2.5, 3.5, 4.5), "valid configure succeeds")
	_expect_true(scheduler.is_configured(), "valid configure marks configured")

	_expect_false(scheduler.configure(-1.0, 2.5, 3.5, 4.5), "negative first delay is rejected")
	_expect_false(scheduler.configure(3.0, -1.0, 3.5, 4.5), "negative grace is rejected")
	_expect_false(scheduler.configure(3.0, 2.5, -1.0, 4.5), "negative minimum repeat is rejected")
	_expect_false(scheduler.configure(3.0, 2.5, 3.5, -1.0), "negative maximum repeat is rejected")
	_expect_false(scheduler.configure(3.0, 2.5, 4.5, 3.5), "inverted repeat range is rejected")
	_expect_false(scheduler.configure(NAN, 2.5, 3.5, 4.5), "NAN is rejected")
	_expect_false(scheduler.configure(INF, 2.5, 3.5, 4.5), "positive infinity is rejected")
	_expect_false(scheduler.configure(3.0, -INF, 3.5, 4.5), "negative infinity is rejected")

	_expect_true(scheduler.start(), "preserved valid configuration can start")
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0, "invalid configure preserves first delay")
	_expect_false(scheduler.configure(1.0, 1.0, 1.0, 1.0), "configure while running is rejected")
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0, "running configure rejection preserves runtime")
	scheduler.free()


func _test_start_and_first_attack() -> void:
	var unconfigured: BossPhase1AttackScheduler = Scheduler.new()
	_expect_false(unconfigured.start(), "start before configure is rejected")
	unconfigured.free()

	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var request_count: Array[int] = [0]
	scheduler.attack_requested.connect(func() -> void: request_count[0] += 1)
	_expect_true(scheduler.configure(3.0, 2.5, 3.5, 4.5), "first attack fixture configures")
	_expect_true(scheduler.start(), "first start succeeds")
	_expect_false(scheduler.start(), "duplicate start is rejected")
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0, "duplicate start does not reset wait")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.WAITING_FIRST_ATTACK, "start enters first wait")

	scheduler.advance_time(2.99)
	_expect_equal_int(request_count[0], 0, "first attack is not early")
	scheduler.advance_time(0.01)
	_expect_equal_int(request_count[0], 1, "first attack fires at delay")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.WAITING_FOR_ATTACK_FINISH, "request waits for finish")
	scheduler.advance_time(100.0)
	_expect_equal_int(request_count[0], 1, "no additional request before attack finish")
	scheduler.free()


func _test_repeat_wait_and_notifications() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var request_count: Array[int] = [0]
	scheduler.attack_requested.connect(func() -> void: request_count[0] += 1)
	scheduler.set_random_seed(42)
	_expect_true(scheduler.configure(0.0, 0.0, 3.5, 4.5), "repeat fixture configures")
	_expect_true(scheduler.start(), "repeat fixture starts")
	scheduler.advance_time(0.0)
	_expect_true(scheduler.notify_attack_finished(), "attack finish begins repeat wait")
	var delay: float = scheduler.get_last_selected_repeat_delay()
	_expect_true(delay >= 3.5 and delay <= 4.5, "repeat delay is inside configured range")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.WAITING_REPEAT_ATTACK, "finish enters repeat wait")
	_expect_false(scheduler.notify_attack_finished(), "duplicate attack finish is rejected")
	_expect_approx(scheduler.get_last_selected_repeat_delay(), delay, "duplicate finish does not resample")
	scheduler.advance_time(delay)
	_expect_equal_int(request_count[0], 2, "repeat request fires after selected delay")
	_expect_true(scheduler.notify_attack_aborted(), "attack abort recovers into repeat wait")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.WAITING_REPEAT_ATTACK, "abort enters repeat wait")
	_expect_false(scheduler.notify_attack_aborted(), "duplicate attack abort is rejected")
	scheduler.free()


func _test_seed_reproducibility() -> void:
	var first: BossPhase1AttackScheduler = _make_seeded_scheduler(8675309)
	var second: BossPhase1AttackScheduler = _make_seeded_scheduler(8675309)
	var first_values: Array[float] = _collect_repeat_delays(first, 4)
	var second_values: Array[float] = _collect_repeat_delays(second, 4)
	_expect_float_arrays_equal(first_values, second_values, "same seed and call order reproduce repeat delays")

	first.reset()
	var reset_values: Array[float] = _collect_repeat_delays(first, 4)
	_expect_float_arrays_equal(first_values, reset_values, "reset rewinds an explicit random seed")
	first.free()
	second.free()


func _test_fixed_repeat_delay() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	_expect_true(scheduler.configure(0.0, 0.0, 4.0, 4.0), "fixed repeat fixture configures")
	_expect_true(scheduler.start(), "fixed repeat fixture starts")
	scheduler.advance_time(0.0)
	_expect_true(scheduler.notify_attack_finished(), "fixed repeat wait begins")
	_expect_approx(scheduler.get_last_selected_repeat_delay(), 4.0, "equal repeat bounds select exact delay")
	scheduler.free()


func _test_new_ball_grace() -> void:
	var longer_grace: BossPhase1AttackScheduler = Scheduler.new()
	var longer_requests: Array[int] = [0]
	longer_grace.attack_requested.connect(func() -> void: longer_requests[0] += 1)
	_expect_true(longer_grace.configure(1.0, 2.5, 1.0, 1.0), "long grace fixture configures")
	_expect_true(longer_grace.start(), "long grace fixture starts")
	_expect_true(longer_grace.begin_new_ball_grace(), "grace begins while running")
	_expect_approx(longer_grace.get_grace_time_remaining(), 2.5, "grace uses configured duration")
	longer_grace.advance_time(1.0)
	_expect_equal_int(longer_requests[0], 0, "expired base wait is blocked by longer grace")
	_expect_approx(longer_grace.get_wait_time_remaining(), 0.0, "base wait advances during grace")
	longer_grace.advance_time(1.0)
	_expect_true(longer_grace.begin_new_ball_grace(), "repeated grace restarts full duration")
	_expect_approx(longer_grace.get_grace_time_remaining(), 2.5, "repeated grace resets remaining duration")
	longer_grace.advance_time(2.49)
	_expect_equal_int(longer_requests[0], 0, "request remains blocked until restarted grace expires")
	longer_grace.advance_time(0.01)
	_expect_equal_int(longer_requests[0], 1, "request fires when base wait and grace are complete")
	longer_grace.free()

	var shorter_grace: BossPhase1AttackScheduler = Scheduler.new()
	var shorter_requests: Array[int] = [0]
	shorter_grace.attack_requested.connect(func() -> void: shorter_requests[0] += 1)
	_expect_true(shorter_grace.configure(4.0, 2.5, 1.0, 1.0), "short grace fixture configures")
	_expect_true(shorter_grace.start(), "short grace fixture starts")
	_expect_true(shorter_grace.begin_new_ball_grace(), "short grace begins")
	shorter_grace.advance_time(2.5)
	_expect_false(shorter_grace.is_grace_active(), "shorter grace naturally finishes")
	_expect_equal_int(shorter_requests[0], 0, "base wait continues after shorter grace")
	_expect_approx(shorter_grace.get_wait_time_remaining(), 1.5, "concurrent base wait retains remainder")
	shorter_grace.advance_time(1.5)
	_expect_equal_int(shorter_requests[0], 1, "request fires after remaining base wait")
	shorter_grace.free()

	var ordered: BossPhase1AttackScheduler = Scheduler.new()
	var events: Array[String] = []
	ordered.grace_started.connect(func(_duration: float) -> void: events.append("grace_started"))
	ordered.grace_finished.connect(func() -> void: events.append("grace_finished"))
	ordered.attack_requested.connect(func() -> void: events.append("attack_requested"))
	_expect_true(ordered.configure(0.0, 0.0, 1.0, 1.0), "grace order fixture configures")
	_expect_true(ordered.start(), "grace order fixture starts")
	_expect_true(ordered.begin_new_ball_grace(), "zero grace begins without immediate completion")
	_expect_equal_int(events.size(), 1, "begin grace only emits grace_started")
	ordered.advance_time(0.0)
	_expect_string_array(events, ["grace_started", "grace_finished", "attack_requested"], "natural grace finish precedes attack request")
	ordered.free()


func _test_pause_and_resume() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var pause_events: Array[bool] = []
	scheduler.pause_changed.connect(func(value: bool) -> void: pause_events.append(value))
	_expect_true(scheduler.configure(3.0, 2.5, 1.0, 1.0), "pause fixture configures")
	_expect_true(scheduler.start(), "pause fixture starts")
	_expect_true(scheduler.begin_new_ball_grace(), "pause fixture grace begins")
	scheduler.advance_time(1.0)
	var wait_before_pause: float = scheduler.get_wait_time_remaining()
	var grace_before_pause: float = scheduler.get_grace_time_remaining()
	_expect_true(scheduler.pause(), "pause succeeds while running")
	_expect_false(scheduler.pause(), "duplicate pause is rejected")
	scheduler.advance_time(100.0)
	_expect_approx(scheduler.get_wait_time_remaining(), wait_before_pause, "pause freezes attack wait")
	_expect_approx(scheduler.get_grace_time_remaining(), grace_before_pause, "pause freezes grace wait")
	_expect_true(scheduler.resume(), "resume succeeds while paused")
	_expect_false(scheduler.resume(), "duplicate resume is rejected")
	scheduler.advance_time(0.5)
	_expect_approx(scheduler.get_wait_time_remaining(), wait_before_pause - 0.5, "resume continues attack wait")
	_expect_approx(scheduler.get_grace_time_remaining(), grace_before_pause - 0.5, "resume continues grace wait")
	_expect_bool_array(pause_events, [true, false], "pause signals report transitions")
	scheduler.free()


func _test_stop_and_reset() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var request_count: Array[int] = [0]
	scheduler.attack_requested.connect(func() -> void: request_count[0] += 1)
	scheduler.set_random_seed(7)
	_expect_true(scheduler.configure(1.0, 2.5, 2.0, 3.0), "stop fixture configures")
	_expect_true(scheduler.start(), "stop fixture starts")
	_expect_true(scheduler.stop(), "stop succeeds while running")
	_expect_false(scheduler.stop(), "duplicate stop is rejected")
	_expect_false(scheduler.is_running(), "stop ends running state")
	_expect_false(scheduler.is_paused(), "stop clears pause")
	_expect_false(scheduler.is_grace_active(), "stop clears grace")
	_expect_approx(scheduler.get_wait_time_remaining(), 0.0, "stop clears attack wait")
	scheduler.advance_time(100.0)
	_expect_equal_int(request_count[0], 0, "stop prevents future requests")

	_expect_true(scheduler.start(), "configuration survives stop")
	scheduler.advance_time(1.0)
	_expect_true(scheduler.notify_attack_finished(), "repeat delay exists before reset")
	_expect_true(scheduler.get_last_selected_repeat_delay() > 0.0, "repeat delay was selected")
	scheduler.reset()
	_expect_true(scheduler.is_configured(), "reset preserves configuration")
	_expect_equal_int(scheduler.get_current_state(), Scheduler.State.STOPPED, "reset restores stopped state")
	_expect_false(scheduler.is_running(), "reset restores non-running state")
	_expect_false(scheduler.is_paused(), "reset clears pause")
	_expect_false(scheduler.is_grace_active(), "reset clears grace")
	_expect_approx(scheduler.get_wait_time_remaining(), 0.0, "reset clears wait")
	_expect_approx(scheduler.get_last_selected_repeat_delay(), 0.0, "reset clears last repeat delay")
	scheduler.free()


func _test_zero_delays() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var request_count: Array[int] = [0]
	scheduler.attack_requested.connect(func() -> void: request_count[0] += 1)
	_expect_true(scheduler.configure(0.0, 0.0, 0.0, 0.0), "zero delays configure")
	_expect_true(scheduler.start(), "zero delay scheduler starts")
	_expect_equal_int(request_count[0], 0, "zero first delay does not request inside start")
	scheduler.advance_time(0.0)
	_expect_equal_int(request_count[0], 1, "zero first delay requests on advance")
	_expect_true(scheduler.notify_attack_finished(), "zero repeat wait begins")
	_expect_equal_int(request_count[0], 1, "zero repeat delay does not request inside finish notification")
	scheduler.advance_time(0.0)
	_expect_equal_int(request_count[0], 2, "zero repeat delay requests on next advance")
	scheduler.free()


func _test_large_delta_and_reentrant_request() -> void:
	var large_delta: BossPhase1AttackScheduler = Scheduler.new()
	var large_count: Array[int] = [0]
	large_delta.attack_requested.connect(func() -> void: large_count[0] += 1)
	_expect_true(large_delta.configure(3.0, 0.0, 0.0, 0.0), "large delta fixture configures")
	_expect_true(large_delta.start(), "large delta fixture starts")
	large_delta.advance_time(1000.0)
	_expect_equal_int(large_count[0], 1, "large delta emits at most one request")
	large_delta.free()

	var reentrant: BossPhase1AttackScheduler = Scheduler.new()
	var reentrant_count: Array[int] = [0]
	reentrant.attack_requested.connect(
		func() -> void:
			reentrant_count[0] += 1
			_expect_true(reentrant.notify_attack_finished(), "reentrant callback may finish attack")
	)
	_expect_true(reentrant.configure(0.0, 0.0, 0.0, 0.0), "reentrant fixture configures")
	_expect_true(reentrant.start(), "reentrant fixture starts")
	reentrant.advance_time(0.0)
	_expect_equal_int(reentrant_count[0], 1, "reentrant finish cannot cause a second request in one advance")
	_expect_equal_int(reentrant.get_current_state(), Scheduler.State.WAITING_REPEAT_ATTACK, "reentrant finish leaves repeat wait")
	reentrant.advance_time(0.0)
	_expect_equal_int(reentrant_count[0], 2, "next advance may request again")
	reentrant.free()


func _test_invalid_delta_and_getters() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	_expect_true(scheduler.configure(3.0, 2.5, 1.0, 1.0), "getter fixture configures")
	_expect_true(scheduler.start(), "getter fixture starts")
	scheduler.advance_time(-1.0)
	scheduler.advance_time(NAN)
	scheduler.advance_time(INF)
	scheduler.advance_time(-INF)
	_expect_approx(scheduler.get_wait_time_remaining(), 3.0, "invalid deltas do not change wait")
	_expect_approx(scheduler.get_effective_time_remaining(), 3.0, "effective wait equals base wait without grace")
	_expect_true(scheduler.begin_new_ball_grace(), "getter fixture grace begins")
	_expect_approx(scheduler.get_effective_time_remaining(), 3.0, "effective wait is maximum of concurrent clocks")
	scheduler.advance_time(1.0)
	var state_before: BossPhase1AttackScheduler.State = scheduler.get_current_state()
	var wait_before: float = scheduler.get_wait_time_remaining()
	var grace_before: float = scheduler.get_grace_time_remaining()
	var effective_before: float = scheduler.get_effective_time_remaining()
	var last_delay_before: float = scheduler.get_last_selected_repeat_delay()
	var configured_before: bool = scheduler.is_configured()
	var running_before: bool = scheduler.is_running()
	var paused_before: bool = scheduler.is_paused()
	var grace_active_before: bool = scheduler.is_grace_active()
	_expect_equal_int(scheduler.get_current_state(), state_before, "state getter does not mutate state")
	_expect_approx(scheduler.get_wait_time_remaining(), wait_before, "wait getter does not mutate state")
	_expect_approx(scheduler.get_grace_time_remaining(), grace_before, "grace getter does not mutate state")
	_expect_approx(scheduler.get_effective_time_remaining(), effective_before, "effective getter does not mutate state")
	_expect_approx(scheduler.get_last_selected_repeat_delay(), last_delay_before, "last delay getter does not mutate state")
	_expect_equal_bool(scheduler.is_configured(), configured_before, "configured getter does not mutate state")
	_expect_equal_bool(scheduler.is_running(), running_before, "running getter does not mutate state")
	_expect_equal_bool(scheduler.is_paused(), paused_before, "paused getter does not mutate state")
	_expect_equal_bool(scheduler.is_grace_active(), grace_active_before, "grace getter does not mutate state")
	scheduler.stop()
	_expect_approx(scheduler.get_effective_time_remaining(), 0.0, "effective wait is zero while stopped")
	scheduler.free()


func _test_grace_cancellation_signals() -> void:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	var finish_count: Array[int] = [0]
	scheduler.grace_finished.connect(func() -> void: finish_count[0] += 1)
	_expect_true(scheduler.configure(3.0, 2.5, 1.0, 1.0), "grace cancellation fixture configures")
	_expect_true(scheduler.start(), "grace cancellation fixture starts")
	_expect_true(scheduler.begin_new_ball_grace(), "grace begins before stop")
	_expect_true(scheduler.stop(), "stop cancels grace")
	_expect_equal_int(finish_count[0], 0, "stop cancellation does not emit grace_finished")
	_expect_true(scheduler.start(), "scheduler restarts after stop")
	_expect_true(scheduler.begin_new_ball_grace(), "grace begins before reset")
	scheduler.reset()
	_expect_equal_int(finish_count[0], 0, "reset cancellation does not emit grace_finished")
	scheduler.free()


func _make_seeded_scheduler(seed: int) -> BossPhase1AttackScheduler:
	var scheduler: BossPhase1AttackScheduler = Scheduler.new()
	scheduler.set_random_seed(seed)
	_expect_true(scheduler.configure(0.0, 0.0, 3.5, 4.5), "seeded fixture configures")
	return scheduler


func _collect_repeat_delays(scheduler: BossPhase1AttackScheduler, count: int) -> Array[float]:
	var values: Array[float] = []
	_expect_true(scheduler.start(), "delay collection starts")
	scheduler.advance_time(0.0)
	for _index: int in range(count):
		_expect_true(scheduler.notify_attack_finished(), "delay collection accepts attack finish")
		var selected_delay: float = scheduler.get_last_selected_repeat_delay()
		values.append(selected_delay)
		scheduler.advance_time(selected_delay)
	return values


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_false(value: bool, message: String) -> void:
	if value:
		_failures.append(message)


func _expect_equal_int(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %d, got %d" % [message, expected, actual])


func _expect_equal_bool(actual: bool, expected: bool, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %f, got %f" % [message, expected, actual])


func _expect_float_arrays_equal(actual: Array[float], expected: Array[float], message: String) -> void:
	if actual.size() != expected.size():
		_failures.append("%s: array sizes differ" % message)
		return
	for index: int in range(actual.size()):
		if not is_equal_approx(actual[index], expected[index]):
			_failures.append("%s: value %d differs" % [message, index])
			return


func _expect_string_array(actual: Array[String], expected: Array[String], message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect_bool_array(actual: Array[bool], expected: Array[bool], message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
