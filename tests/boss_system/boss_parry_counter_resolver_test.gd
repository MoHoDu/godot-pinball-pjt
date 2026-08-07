extends SceneTree


const TRACKING_DURATION_SEC: float = 0.16
const PERFECT_GRADE: int = FlipperParryEvaluator.Grade.PERFECT
const NORMAL_GRADE: int = FlipperParryEvaluator.Grade.NORMAL
const NONE_GRADE: int = FlipperParryEvaluator.Grade.NONE


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_tracker_binding_and_unbound_safety()
	await _test_multi_flipper_binding_and_duplicate_prevention()
	await _test_invalid_replacement_preserves_existing_flippers()
	await _test_grade_and_ball_qualification_policy()
	await _test_perfect_consumes_once()
	await _test_expired_and_freed_balls_are_ignored()
	await _test_unbind_ignores_previous_flippers()
	_test_forbidden_dependencies()
	_finish()


func _test_tracker_binding_and_unbound_safety() -> void:
	var resolver := BossParryCounterResolver.new()
	var flipper := PinballFlipper.new()
	var ball: Pinball = await _create_ball("UnboundTrackerBall")
	root.add_child(resolver)
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)

	_expect(not resolver.bind_tracker(null), "A null Tracker must be rejected.")
	_expect(resolver.bind_flippers(_typed_flippers([flipper])),
		"A valid Flipper must bind without a Tracker.")
	_emit_parry(flipper, ball, PERFECT_GRADE)
	_expect(events.is_empty(),
		"A PERFECT event without a Tracker binding must be ignored safely.")

	var fixture: Dictionary = _create_tracker_fixture()
	var tracker: BossArmHitBallTracker = fixture.tracker
	_expect(resolver.bind_tracker(tracker), "A live Tracker must bind.")
	_expect(not resolver.bind_tracker(null),
		"A failed Tracker replacement must be rejected.")
	_track_ball(fixture, ball)
	_emit_parry(flipper, ball, PERFECT_GRADE)
	_expect(events.size() == 1 and events[0] == ball,
		"A failed Tracker replacement must preserve the valid Tracker.")

	resolver.queue_free()
	ball.queue_free()
	flipper.free()
	await _destroy_tracker_fixture(fixture)


func _test_multi_flipper_binding_and_duplicate_prevention() -> void:
	var resolver := BossParryCounterResolver.new()
	var first_flipper := PinballFlipper.new()
	var second_flipper := PinballFlipper.new()
	root.add_child(resolver)

	_expect(resolver.bind_flippers(_typed_flippers([
		first_flipper,
		first_flipper,
		second_flipper,
	])), "Multiple Flippers with duplicate entries must bind.")
	_expect(_count_connections_to(first_flipper, resolver) == 1,
		"A duplicate Flipper entry must create exactly one connection.")
	_expect(_count_connections_to(second_flipper, resolver) == 1,
		"Each distinct Flipper must create exactly one connection.")

	_expect(resolver.bind_flippers(_typed_flippers([
		first_flipper,
		second_flipper,
		first_flipper,
	])), "Rebinding the same Flipper set must succeed.")
	_expect(_count_connections_to(first_flipper, resolver) == 1
		and _count_connections_to(second_flipper, resolver) == 1,
		"Repeated binding must not duplicate signal connections.")

	resolver.queue_free()
	first_flipper.free()
	second_flipper.free()
	await process_frame


func _test_invalid_replacement_preserves_existing_flippers() -> void:
	var fixture: Dictionary = _create_resolver_fixture()
	var resolver: BossParryCounterResolver = fixture.resolver
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	var first_flipper: PinballFlipper = fixture.flipper
	var invalid_flipper := PinballFlipper.new()
	var invalid_replacement: Array[PinballFlipper] = [
		first_flipper,
		invalid_flipper,
	]
	invalid_flipper.free()

	_expect(not resolver.bind_flippers(invalid_replacement),
		"A replacement containing a freed Flipper must be rejected.")
	_expect(_count_connections_to(first_flipper, resolver) == 1,
		"A failed replacement must preserve the original Flipper connection.")

	var ball: Pinball = await _create_ball("PreservedFlipperBall")
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)
	_track_ball(tracker_fixture, ball)
	_emit_parry(first_flipper, ball, PERFECT_GRADE)
	_expect(events.size() == 1,
		"The preserved Flipper binding must remain functional.")

	ball.queue_free()
	await _destroy_resolver_fixture(fixture)


func _test_grade_and_ball_qualification_policy() -> void:
	var fixture: Dictionary = _create_resolver_fixture()
	var resolver: BossParryCounterResolver = fixture.resolver
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	var tracker: BossArmHitBallTracker = tracker_fixture.tracker
	var flipper: PinballFlipper = fixture.flipper
	var tracked_ball: Pinball = await _create_ball("QualifiedBall")
	var other_ball: Pinball = await _create_ball("OtherBall")
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)
	_track_ball(tracker_fixture, tracked_ball)

	_emit_parry(flipper, tracked_ball, NORMAL_GRADE)
	_expect(events.is_empty() and tracker.is_ball_tracked(tracked_ball),
		"NORMAL must not earn Counter or consume tracking eligibility.")
	_emit_parry(flipper, tracked_ball, NONE_GRADE)
	_expect(events.is_empty() and tracker.is_ball_tracked(tracked_ball),
		"NONE must not earn Counter or consume tracking eligibility.")
	_emit_parry(flipper, other_ball, PERFECT_GRADE)
	_expect(events.is_empty() and tracker.is_ball_tracked(tracked_ball),
		"A different untracked Ball's PERFECT must preserve the tracked Ball.")

	tracked_ball.queue_free()
	other_ball.queue_free()
	await _destroy_resolver_fixture(fixture)


func _test_perfect_consumes_once() -> void:
	var fixture: Dictionary = _create_resolver_fixture()
	var resolver: BossParryCounterResolver = fixture.resolver
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	var tracker: BossArmHitBallTracker = tracker_fixture.tracker
	var flipper: PinballFlipper = fixture.flipper
	var ball: Pinball = await _create_ball("PerfectBall")
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)
	_track_ball(tracker_fixture, ball)

	_emit_parry(flipper, ball, PERFECT_GRADE)
	_expect(events.size() == 1 and events[0] == ball,
		"A tracked Ball's PERFECT must emit counter_earned once.")
	_expect(not tracker.is_ball_tracked(ball),
		"A successful PERFECT must consume Tracker eligibility.")
	_emit_parry(flipper, ball, PERFECT_GRADE)
	_expect(events.size() == 1,
		"A second PERFECT without renewed tracking must not emit again.")

	ball.queue_free()
	await _destroy_resolver_fixture(fixture)


func _test_expired_and_freed_balls_are_ignored() -> void:
	var fixture: Dictionary = _create_resolver_fixture()
	var resolver: BossParryCounterResolver = fixture.resolver
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	var tracker: BossArmHitBallTracker = tracker_fixture.tracker
	var flipper: PinballFlipper = fixture.flipper
	var expired_ball: Pinball = await _create_ball("ExpiredBall")
	var freed_ball: Pinball = await _create_ball("FreedBall")
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)

	_track_ball(tracker_fixture, expired_ball)
	await create_timer(TRACKING_DURATION_SEC + 0.08).timeout
	_expect(not tracker.is_ball_tracked(expired_ball),
		"The Tracker must expire eligibility without Resolver timers.")
	_emit_parry(flipper, expired_ball, PERFECT_GRADE)
	_expect(events.is_empty(), "An expired Ball's PERFECT must be ignored.")

	_track_ball(tracker_fixture, freed_ball)
	freed_ball.queue_free()
	await process_frame
	_expect(not is_instance_valid(freed_ball),
		"The freed Ball fixture must actually leave the lifecycle.")
	_expect(events.is_empty(), "A freed Ball event must be ignored safely.")

	expired_ball.queue_free()
	await _destroy_resolver_fixture(fixture)


func _test_unbind_ignores_previous_flippers() -> void:
	var fixture: Dictionary = _create_resolver_fixture()
	var resolver: BossParryCounterResolver = fixture.resolver
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	var tracker: BossArmHitBallTracker = tracker_fixture.tracker
	var flipper: PinballFlipper = fixture.flipper
	var ball: Pinball = await _create_ball("UnboundFlipperBall")
	var events: Array[Pinball] = []
	resolver.counter_earned.connect(func(hit_ball: Pinball) -> void:
		events.append(hit_ball)
	)
	_track_ball(tracker_fixture, ball)

	resolver.unbind_flippers()
	_expect(_count_connections_to(flipper, resolver) == 0,
		"Unbind must disconnect the previous Flipper.")
	_emit_parry(flipper, ball, PERFECT_GRADE)
	_expect(events.is_empty() and tracker.is_ball_tracked(ball),
		"An old Flipper signal after unbind must be ignored without consumption.")
	resolver.unbind_flippers()
	_expect(_count_connections_to(flipper, resolver) == 0,
		"Repeated Flipper unbind must be safe.")

	ball.queue_free()
	await _destroy_resolver_fixture(fixture)


func _test_forbidden_dependencies() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_parry_counter_resolver.gd"
	)
	for forbidden_name: String in [
		"BossDamageApplier",
		"BossGatedDamageApplier",
		"BossDamageGate",
		"BossHealthComponent",
		"ComboSystem",
		"CounterWindow",
		"Control",
		"Timer",
	]:
		_expect(not source.contains(forbidden_name),
			"Resolver must not depend on %s." % forbidden_name)


func _create_tracker_fixture() -> Dictionary:
	var tracker := BossArmHitBallTracker.new()
	var attack := TeddyArmSweepAttack.new()
	root.add_child(tracker)
	_expect(tracker.configure(TRACKING_DURATION_SEC),
		"Tracker fixture configuration must succeed.")
	_expect(tracker.bind_attack(attack),
		"Tracker fixture attack binding must succeed.")
	return {
		&"tracker": tracker,
		&"attack": attack,
	}


func _create_resolver_fixture() -> Dictionary:
	var tracker_fixture: Dictionary = _create_tracker_fixture()
	var resolver := BossParryCounterResolver.new()
	var flipper := PinballFlipper.new()
	root.add_child(resolver)
	_expect(resolver.bind_tracker(tracker_fixture.tracker),
		"Resolver fixture Tracker binding must succeed.")
	_expect(resolver.bind_flippers(_typed_flippers([flipper])),
		"Resolver fixture Flipper binding must succeed.")
	return {
		&"resolver": resolver,
		&"flipper": flipper,
		&"tracker_fixture": tracker_fixture,
	}


func _destroy_tracker_fixture(fixture: Dictionary) -> void:
	var tracker: BossArmHitBallTracker = fixture.tracker
	var attack: TeddyArmSweepAttack = fixture.attack
	if is_instance_valid(tracker):
		tracker.unbind_attack()
		tracker.queue_free()
	if is_instance_valid(attack):
		attack.free()
	await process_frame


func _destroy_resolver_fixture(fixture: Dictionary) -> void:
	var resolver: BossParryCounterResolver = fixture.resolver
	var flipper: PinballFlipper = fixture.flipper
	var tracker_fixture: Dictionary = fixture.tracker_fixture
	if is_instance_valid(resolver):
		resolver.unbind_flippers()
		resolver.queue_free()
	if is_instance_valid(flipper):
		flipper.free()
	await _destroy_tracker_fixture(tracker_fixture)


func _track_ball(fixture: Dictionary, ball: Pinball) -> void:
	var attack: TeddyArmSweepAttack = fixture.attack
	attack.attack_hit.emit(ball)


func _emit_parry(
	flipper: PinballFlipper,
	ball: RigidBody2D,
	grade: int
) -> void:
	flipper.parry_resolved.emit(
		ball,
		grade,
		Vector2.ZERO,
		PinballFlipper.ContactZone.B,
		0.0,
		1.0
	)


func _typed_flippers(values: Array) -> Array[PinballFlipper]:
	var result: Array[PinballFlipper] = []
	for value: Variant in values:
		result.append(value as PinballFlipper)
	return result


func _count_connections_to(
	flipper: PinballFlipper,
	target: Object
) -> int:
	var count: int = 0
	for connection: Dictionary in flipper.parry_resolved.get_connections():
		var callback: Callable = connection.get(&"callable", Callable())
		if callback.is_valid() and callback.get_object() == target:
			count += 1
	return count


func _create_ball(ball_name: String) -> Pinball:
	var ball := Pinball.new()
	ball.name = ball_name
	root.add_child(ball)
	await process_frame
	return ball


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BossParryCounterResolver tests passed.")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)
