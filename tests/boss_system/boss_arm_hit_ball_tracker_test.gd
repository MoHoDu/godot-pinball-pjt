extends SceneTree


const TRACKING_DURATION_SEC: float = 0.24


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_initial_state_and_configuration()
	await _test_attack_binding_contract()
	await _test_target_validation_and_tracking()
	await _test_refresh_and_independent_tracking()
	await _test_expiration_and_consumption()
	await _test_ball_loss_cleanup()
	await _test_clear_and_unbind()
	await _test_rebind_disconnects_previous_attack()
	_test_forbidden_dependencies()
	_finish()


func _test_initial_state_and_configuration() -> void:
	var tracker := BossArmHitBallTracker.new()
	var attack := TeddyArmSweepAttack.new()
	root.add_child(tracker)

	_expect(not tracker.is_bound(), "A new tracker must be unbound.")
	_expect(not tracker.configure(0.0), "A zero duration must be rejected.")
	_expect(not tracker.configure(-1.0), "A negative duration must be rejected.")
	_expect(not tracker.configure(NAN), "A NAN duration must be rejected.")
	_expect(not tracker.configure(INF), "An infinite duration must be rejected.")
	_expect(tracker.bind_attack(attack), "A live Teddy attack must bind.")

	var ball: Pinball = await _create_ball("UnconfiguredBall")
	attack.attack_hit.emit(ball)
	_expect(not tracker.is_ball_tracked(ball),
		"Hits must be ignored until configuration succeeds.")

	_expect(tracker.configure(TRACKING_DURATION_SEC),
		"A finite positive duration must configure the tracker.")
	_expect(not tracker.configure(0.0),
		"An invalid reconfiguration must be rejected.")
	attack.attack_hit.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"A failed reconfiguration must preserve the previous valid duration.")

	tracker.queue_free()
	ball.queue_free()
	attack.free()
	await process_frame


func _test_attack_binding_contract() -> void:
	var tracker := BossArmHitBallTracker.new()
	var first_attack := TeddyArmSweepAttack.new()
	var invalid_attack := TeddyArmSweepAttack.new()
	root.add_child(tracker)

	_expect(not tracker.bind_attack(null), "A null attack must be rejected.")
	_expect(tracker.bind_attack(first_attack), "A valid attack must bind.")
	_expect(tracker.is_bound(), "A successful binding must be observable.")
	var connection_count := first_attack.attack_hit.get_connections().size()
	_expect(tracker.bind_attack(first_attack),
		"Binding the same attack again must be idempotent.")
	_expect(first_attack.attack_hit.get_connections().size() == connection_count,
		"An idempotent rebind must not duplicate signal connections.")

	invalid_attack.free()
	_expect(not tracker.bind_attack(invalid_attack),
		"A freed replacement attack must be rejected.")
	_expect(tracker.is_bound(),
		"A failed replacement bind must preserve the existing binding.")
	_expect(first_attack.attack_hit.get_connections().size() == connection_count,
		"A failed replacement bind must preserve the existing connection.")

	tracker.queue_free()
	first_attack.free()
	await process_frame


func _test_target_validation_and_tracking() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	var tracked_ball: Pinball = await _create_ball("PreservedBall")
	attack.attack_hit.emit(tracked_ball)
	var remaining_before_invalid_targets := \
		tracker.get_remaining_time_sec(tracked_ball)

	var non_ball := Node.new()
	root.add_child(non_ball)
	attack.attack_hit.emit(non_ball)

	var ball: Pinball = await _create_ball("ValidatedBall")
	ball.remove_from_group(Pinball.PINBALL_GROUP)
	var remaining_before_group_rejection := \
		tracker.get_remaining_time_sec(tracked_ball)
	attack.attack_hit.emit(ball)
	_expect(not tracker.is_ball_tracked(ball),
		"A Pinball outside the pinball group must be ignored.")
	var remaining_after_invalid_targets := \
		tracker.get_remaining_time_sec(tracked_ball)
	_expect(tracker.is_ball_tracked(tracked_ball),
		"Invalid targets must not remove an existing tracked Ball.")
	_expect(
		remaining_after_invalid_targets <= remaining_before_group_rejection + 0.01
		and remaining_after_invalid_targets \
			>= remaining_before_group_rejection - 0.02,
		"Invalid targets must not reset or corrupt another Ball's timer. "
		+ "(before_non_ball=%.3f, before_group=%.3f, after=%.3f)" % [
			remaining_before_invalid_targets,
			remaining_before_group_rejection,
			remaining_after_invalid_targets,
		]
	)

	ball.add_to_group(Pinball.PINBALL_GROUP)
	attack.attack_hit.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"A live grouped Pinball must be tracked.")

	non_ball.queue_free()
	tracked_ball.queue_free()
	ball.queue_free()
	await _destroy_fixture(fixture)


func _test_refresh_and_independent_tracking() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	var first_ball: Pinball = await _create_ball("RefreshBall")
	var second_ball: Pinball = await _create_ball("IndependentBall")

	attack.attack_hit.emit(first_ball)
	attack.attack_hit.emit(second_ball)
	await create_timer(TRACKING_DURATION_SEC * 0.55).timeout
	var remaining_before_refresh := tracker.get_remaining_time_sec(first_ball)
	attack.attack_hit.emit(first_ball)
	var remaining_after_refresh := tracker.get_remaining_time_sec(first_ball)
	_expect(remaining_after_refresh > remaining_before_refresh,
		"A repeated hit must refresh the same Ball's remaining duration.")
	_expect(tracker.is_ball_tracked(first_ball)
		and tracker.is_ball_tracked(second_ball),
		"Multiple Balls must be tracked independently.")

	await create_timer(TRACKING_DURATION_SEC * 0.55).timeout
	_expect(tracker.is_ball_tracked(first_ball),
		"The refreshed Ball must remain tracked for its renewed duration.")
	_expect(not tracker.is_ball_tracked(second_ball),
		"Refreshing one Ball must not extend another Ball's duration.")
	_expect(tracker.consume_ball(first_ball),
		"The refreshed Ball must have only one consumable tracking entry.")
	_expect(not tracker.consume_ball(first_ball),
		"Consuming the same Ball twice must fail the second time.")

	first_ball.queue_free()
	second_ball.queue_free()
	await _destroy_fixture(fixture)


func _test_expiration_and_consumption() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	var consumed_ball: Pinball = await _create_ball("ConsumedBall")
	var expired_ball: Pinball = await _create_ball("ExpiredBall")

	attack.attack_hit.emit(consumed_ball)
	attack.attack_hit.emit(expired_ball)
	_expect(tracker.consume_ball(consumed_ball),
		"Consuming a tracked Ball must succeed.")
	_expect(not tracker.is_ball_tracked(consumed_ball),
		"A consumed Ball must be removed immediately.")
	_expect(not tracker.consume_ball(consumed_ball),
		"Consuming an untracked Ball must return false.")
	_expect(not tracker.consume_ball(null),
		"Consuming a null Ball must return false.")
	_expect(tracker.is_ball_tracked(expired_ball),
		"Consuming one Ball must preserve another tracked Ball.")

	await create_timer(TRACKING_DURATION_SEC + 0.08).timeout
	_expect(not tracker.is_ball_tracked(expired_ball),
		"A Ball must be removed when its tracking duration expires.")
	_expect(is_zero_approx(tracker.get_remaining_time_sec(expired_ball)),
		"An expired Ball must report no remaining tracking time.")

	consumed_ball.queue_free()
	expired_ball.queue_free()
	await _destroy_fixture(fixture)


func _test_ball_loss_cleanup() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	var freed_ball: Pinball = await _create_ball("FreedBall")
	var exited_ball: Pinball = await _create_ball("ExitedBall")
	var survivor_ball: Pinball = await _create_ball("SurvivorBall")

	attack.attack_hit.emit(freed_ball)
	attack.attack_hit.emit(exited_ball)
	attack.attack_hit.emit(survivor_ball)
	_expect(_count_tree_exit_connections_to(exited_ball, tracker) == 1,
		"A tracked Ball must have exactly one Tracker tree-exit connection.")
	freed_ball.queue_free()
	await process_frame
	_expect(not tracker.is_ball_tracked(freed_ball),
		"A freed Ball must be removed without invalid-instance access.")
	_expect(tracker.is_ball_tracked(survivor_ball),
		"Freeing one Ball must not remove another Ball.")

	root.remove_child(exited_ball)
	_expect(not tracker.is_ball_tracked(exited_ball),
		"A Ball leaving the SceneTree must be removed immediately.")
	_expect(_count_tree_exit_connections_to(exited_ball, tracker) == 0,
		"Tree exit must disconnect the tracked Ball callback immediately.")
	attack.attack_hit.emit(exited_ball)
	_expect(not tracker.is_ball_tracked(exited_ball),
		"An out-of-tree Ball must not be registered again.")
	_expect(tracker.is_ball_tracked(survivor_ball),
		"A tree exit must only remove the exiting Ball.")

	root.add_child(exited_ball)
	attack.attack_hit.emit(exited_ball)
	_expect(tracker.is_ball_tracked(exited_ball),
		"A live Ball may be tracked again after re-entering the SceneTree.")
	_expect(_count_tree_exit_connections_to(exited_ball, tracker) == 1,
		"Re-tracking must create one fresh tree-exit connection.")
	root.remove_child(exited_ball)
	_expect(_count_tree_exit_connections_to(exited_ball, tracker) == 0,
		"Repeated tree exit must not leave a stale or duplicate callback.")
	_expect(tracker.is_ball_tracked(survivor_ball),
		"Repeated exit cleanup must preserve other tracked Balls.")

	exited_ball.free()
	survivor_ball.queue_free()
	await _destroy_fixture(fixture)


func _test_clear_and_unbind() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	var first_ball: Pinball = await _create_ball("ClearBallA")
	var second_ball: Pinball = await _create_ball("ClearBallB")

	attack.attack_hit.emit(first_ball)
	attack.attack_hit.emit(second_ball)
	tracker.clear()
	_expect(not tracker.is_ball_tracked(first_ball)
		and not tracker.is_ball_tracked(second_ball),
		"Clear must remove every tracked Ball.")
	_expect(tracker.is_bound(), "Clear must preserve the attack binding.")

	attack.attack_hit.emit(first_ball)
	tracker.unbind_attack()
	_expect(not tracker.is_bound(), "Unbind must remove the attack binding.")
	_expect(not tracker.is_ball_tracked(first_ball),
		"Unbind must clear stale tracked eligibility.")
	attack.attack_hit.emit(second_ball)
	_expect(not tracker.is_ball_tracked(second_ball),
		"The old attack must be ignored after unbind.")
	tracker.unbind_attack()
	_expect(not tracker.is_bound(), "Repeated unbind must be safe.")

	first_ball.queue_free()
	second_ball.queue_free()
	await _destroy_fixture(fixture)


func _test_rebind_disconnects_previous_attack() -> void:
	var fixture: Dictionary = _create_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	var first_attack: TeddyArmSweepAttack = fixture.attack
	var second_attack := TeddyArmSweepAttack.new()
	var old_ball: Pinball = await _create_ball("OldAttackBall")
	var new_ball: Pinball = await _create_ball("NewAttackBall")

	first_attack.attack_hit.emit(old_ball)
	_expect(tracker.is_ball_tracked(old_ball),
		"The original attack must track its Ball before rebind.")
	_expect(tracker.bind_attack(second_attack),
		"A different valid attack must replace the binding.")
	_expect(not tracker.is_ball_tracked(old_ball),
		"A valid replacement bind must clear stale Ball eligibility.")
	_expect(first_attack.attack_hit.get_connections().is_empty(),
		"A replacement bind must disconnect the previous attack.")

	first_attack.attack_hit.emit(old_ball)
	_expect(not tracker.is_ball_tracked(old_ball),
		"The previous attack must be ignored after rebind.")
	second_attack.attack_hit.emit(new_ball)
	_expect(tracker.is_ball_tracked(new_ball),
		"The replacement attack must drive new tracking.")
	var connection_count := second_attack.attack_hit.get_connections().size()
	_expect(tracker.bind_attack(second_attack),
		"The replacement attack must also support idempotent rebind.")
	_expect(second_attack.attack_hit.get_connections().size() == connection_count,
		"The replacement attack must not gain duplicate connections.")

	old_ball.queue_free()
	new_ball.queue_free()
	second_attack.free()
	await _destroy_fixture(fixture)


func _test_forbidden_dependencies() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_arm_hit_ball_tracker.gd"
	)
	for forbidden_name: String in [
		"PinballFlipper",
		"FlipperParryEvaluator",
		"BossDamageApplier",
		"BossGatedDamageApplier",
		"BossDamageGate",
		"BossHealthComponent",
		"ComboSystem",
		"CounterWindow",
		"Control",
	]:
		_expect(not source.contains(forbidden_name),
			"Tracker must not depend on %s." % forbidden_name)


func _create_fixture() -> Dictionary:
	var tracker := BossArmHitBallTracker.new()
	var attack := TeddyArmSweepAttack.new()
	root.add_child(tracker)
	_expect(tracker.configure(TRACKING_DURATION_SEC),
		"Fixture tracker configuration must succeed.")
	_expect(tracker.bind_attack(attack),
		"Fixture attack binding must succeed.")
	return {
		&"tracker": tracker,
		&"attack": attack,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	if is_instance_valid(tracker):
		tracker.unbind_attack()
		tracker.queue_free()
	if is_instance_valid(attack):
		attack.free()
	await process_frame


func _create_ball(ball_name: String) -> Pinball:
	var ball := Pinball.new()
	ball.name = ball_name
	root.add_child(ball)
	await process_frame
	return ball


func _count_tree_exit_connections_to(
	ball: Pinball,
	target: Object
) -> int:
	var count: int = 0
	for connection: Dictionary in ball.tree_exited.get_connections():
		var callback: Callable = connection.get(&"callable", Callable())
		if callback.is_valid() and callback.get_object() == target:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BossArmHitBallTracker tests passed.")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)
