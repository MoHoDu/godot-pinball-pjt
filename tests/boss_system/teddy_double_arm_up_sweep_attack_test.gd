extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_initial_telegraph_active_and_recovery_contract()
	await _test_same_ball_is_deduplicated_across_both_arms()
	await _test_multiball_and_new_lifecycle_reset()
	await _test_invalid_targets_and_cancel()
	await _test_controller_contract()
	await _test_tracker_and_reflector_compatibility()
	_test_responsibility_boundaries()
	_finish()


func _test_initial_telegraph_active_and_recovery_contract() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var ball: Pinball = await _create_ball("LifecycleBall")
	var hits: Array[Pinball] = []
	attack.attack_hit.connect(func(target: Node) -> void:
		if target is Pinball:
			hits.append(target as Pinball)
	)

	_expect(not attack.is_detection_active(),
		"A new double-arm attack must initially be inactive.")
	attack.prepare_attack()
	attack.left_hit_area.body_entered.emit(ball)
	attack.right_hit_area.body_entered.emit(ball)
	_expect(hits.is_empty(), "prepare must not register arm hits.")

	attack.begin_telegraph(0.0)
	_expect(not attack.is_detection_active(),
		"TELEGRAPH must keep attack detection disabled.")
	attack.left_hit_area.body_entered.emit(ball)
	attack.right_hit_area.body_entered.emit(ball)
	_expect(hits.is_empty(), "TELEGRAPH must not emit attack_hit.")

	attack.begin_active(0.0)
	_expect(attack.is_detection_active(),
		"ACTIVE must enable the shared two-arm detection window.")
	attack.left_hit_area.body_entered.emit(ball)
	_expect(hits == [ball],
		"Either arm must emit the exact Pinball instance during ACTIVE.")

	attack.begin_recovery(0.0)
	_expect(not attack.is_detection_active(),
		"RECOVERY must disable both arm hit paths together.")
	var recovery_ball: Pinball = await _create_ball("RecoveryBall")
	attack.right_hit_area.body_entered.emit(recovery_ball)
	_expect(hits == [ball], "RECOVERY must not emit attack_hit.")

	ball.queue_free()
	recovery_ball.queue_free()
	attack.queue_free()
	await process_frame


func _test_same_ball_is_deduplicated_across_both_arms() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var ball: Pinball = await _create_ball("BothArmsBall")
	var hits: Array[Pinball] = []
	attack.attack_hit.connect(func(target: Node) -> void:
		if target is Pinball:
			hits.append(target as Pinball)
	)
	attack.prepare_attack()
	attack.begin_active(0.0)

	attack.left_hit_area.body_entered.emit(ball)
	attack.right_hit_area.body_entered.emit(ball)
	attack.left_hit_area.body_entered.emit(ball)
	_expect(hits == [ball],
		"One Ball touching both active arms must emit exactly once.")
	_expect(attack.get_registered_target_count() == 1,
		"Both arms must share one lifecycle deduplication registry.")

	ball.queue_free()
	attack.queue_free()
	await process_frame


func _test_multiball_and_new_lifecycle_reset() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var first_ball: Pinball = await _create_ball("MultiballA")
	var second_ball: Pinball = await _create_ball("MultiballB")
	var hits: Array[Pinball] = []
	attack.attack_hit.connect(func(target: Node) -> void:
		if target is Pinball:
			hits.append(target as Pinball)
	)
	attack.prepare_attack()
	attack.begin_active(0.0)

	attack.left_hit_area.body_entered.emit(first_ball)
	attack.right_hit_area.body_entered.emit(second_ball)
	attack.right_hit_area.body_entered.emit(first_ball)
	_expect(hits.size() == 2
		and hits.has(first_ball)
		and hits.has(second_ball),
		"Multiball must register each Ball independently exactly once.")
	_expect(attack.get_registered_target_count() == 2,
		"The active lifecycle must retain one entry per Ball.")

	attack.begin_recovery(0.0)
	attack.prepare_attack()
	_expect(attack.get_registered_target_count() == 0,
		"prepare must clear the previous lifecycle hit registry.")
	attack.begin_active(0.0)
	attack.left_hit_area.body_entered.emit(first_ball)
	_expect(hits.size() == 3 and hits[2] == first_ball,
		"A new lifecycle must allow the same Ball to hit once again.")

	first_ball.queue_free()
	second_ball.queue_free()
	attack.queue_free()
	await process_frame


func _test_invalid_targets_and_cancel() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var valid_ball: Pinball = await _create_ball("ValidBall")
	var outside_group_ball: Pinball = await _create_ball("OutsideGroupBall")
	outside_group_ball.remove_from_group(Pinball.PINBALL_GROUP)
	var non_ball := Node2D.new()
	root.add_child(non_ball)
	var hits: Array[Pinball] = []
	attack.attack_hit.connect(func(target: Node) -> void:
		if target is Pinball:
			hits.append(target as Pinball)
	)
	attack.prepare_attack()
	attack.begin_active(0.0)

	attack.left_hit_area.body_entered.emit(non_ball)
	attack.right_hit_area.body_entered.emit(outside_group_ball)
	_expect(hits.is_empty(),
		"ACTIVE must ignore non-Pinball and out-of-group Pinball targets.")

	attack.left_hit_area.body_entered.emit(valid_ball)
	_expect(hits == [valid_ball], "A valid grouped Pinball must still hit.")
	attack.cancel_attack()
	_expect(not attack.is_detection_active(),
		"Cancel must disable both arm hit paths.")
	var after_cancel_ball: Pinball = await _create_ball("AfterCancelBall")
	attack.right_hit_area.body_entered.emit(after_cancel_ball)
	_expect(hits == [valid_ball], "Cancel must prevent further attack_hit events.")

	valid_ball.queue_free()
	outside_group_ball.queue_free()
	after_cancel_ball.queue_free()
	non_ball.queue_free()
	attack.queue_free()
	await process_frame


func _test_controller_contract() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var controller := BossAttackController.new()
	root.add_child(controller)
	var pattern := BossAttackPattern.new()
	pattern.attack_id = &"teddy_double_arm_up_sweep"
	pattern.telegraph_duration = 0.0
	pattern.active_duration = 0.0
	pattern.recovery_duration = 0.0
	pattern.cooldown_duration = 0.0
	controller.attack = attack
	controller.pattern = pattern

	_expect(controller.attack == attack,
		"BossAttackController must accept the new Attack through its existing type.")
	_expect(controller.start_attack(),
		"The new Attack must satisfy the existing Controller lifecycle contract.")
	controller.cancel_attack()
	controller.queue_free()
	attack.queue_free()
	await process_frame


func _test_tracker_and_reflector_compatibility() -> void:
	var attack: TeddyDoubleArmUpSweepAttack = await _create_attack()
	var tracker := BossArmHitBallTracker.new()
	var reflector := BossArmBallReflector.new()
	var reflection_rules := BossArmBallReflectionRules.new()
	root.add_child(tracker)
	root.add_child(reflector)

	_expect(tracker.configure(0.2),
		"Tracker compatibility fixture must configure.")
	_expect(tracker.bind_attack(attack),
		"The existing Tracker must accept the Phase 2 Attack subtype.")
	_expect(reflector.configure(reflection_rules),
		"Reflector compatibility fixture must configure.")
	_expect(reflector.bind_attack(attack),
		"The existing Reflector must accept the Phase 2 Attack subtype.")
	_expect(tracker.is_bound() and reflector.is_bound(),
		"Tracker and Reflector must bind the same new Attack independently.")

	tracker.unbind_attack()
	reflector.unbind_attack()
	tracker.queue_free()
	reflector.queue_free()
	attack.queue_free()
	await process_frame


func _test_responsibility_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/attacks/"
		+ "teddy_double_arm_up_sweep_attack.gd"
	)
	_expect(source.contains("extends TeddyArmSweepAttack"),
		"The new Attack must reuse the existing attack contract.")
	for forbidden_name: String in [
		"BossHealthComponent",
		"BossPhaseTransitionController",
		"BossPhase1AttackScheduler",
		"BossDamageApplier",
		"BossCounterWindow",
		"BossArmHitBallTracker",
		"BossArmBallReflector",
		"ComboSystem",
		"PinballFlipper",
		"apply_central_impulse",
	]:
		_expect(not source.contains(forbidden_name),
			"Phase 2 Attack must not depend on: %s" % forbidden_name)


func _create_attack() -> TeddyDoubleArmUpSweepAttack:
	var attack := TeddyDoubleArmUpSweepAttack.new()
	var left_pivot := Node2D.new()
	var right_pivot := Node2D.new()
	var left_area := Area2D.new()
	var right_area := Area2D.new()
	var left_visual := Node2D.new()
	var right_visual := Node2D.new()
	left_pivot.name = "LeftShoulderPivot"
	right_pivot.name = "RightShoulderPivot"
	left_area.name = "LeftHitbox"
	right_area.name = "RightHitbox"
	left_visual.name = "LeftArmVisual"
	right_visual.name = "RightArmVisual"
	attack.add_child(left_pivot)
	attack.add_child(right_pivot)
	left_pivot.add_child(left_area)
	right_pivot.add_child(right_area)
	left_pivot.add_child(left_visual)
	right_pivot.add_child(right_visual)
	attack.left_shoulder_pivot = left_pivot
	attack.right_shoulder_pivot = right_pivot
	attack.left_hit_area = left_area
	attack.right_hit_area = right_area
	attack.left_arm_visual = left_visual
	attack.right_arm_visual = right_visual
	root.add_child(attack)
	await process_frame
	return attack


func _create_ball(ball_name: String) -> Pinball:
	var ball := Pinball.new()
	ball.name = ball_name
	root.add_child(ball)
	await process_frame
	return ball


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_double_arm_up_sweep_attack_test")
		quit(0)
		return
	print(
		"FAIL: teddy_double_arm_up_sweep_attack_test (%d failures)"
		% _failures.size()
	)
	quit(1)
