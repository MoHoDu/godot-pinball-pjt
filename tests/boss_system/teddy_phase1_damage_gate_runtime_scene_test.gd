extends SceneTree


const DamageGateRuntimeScene: PackedScene = preload(
	"res://scenes/wave/test_teddy_phase1_damage_gate_runtime.tscn"
)
const INTEGRATION_PROTOTYPE_SCRIPT_PATH: String = (
	"res://scripts/boss_system/debug/"
	+ "teddy_phase1_damage_gate_runtime_prototype.gd"
)
const THRESHOLD_EVENT: String = "PHASE 2 THRESHOLD REACHED"
const BLOCKED_ACTIVE_EVENT: String = "DAMAGE BLOCKED: BOSS ACTIVE"
const TEST_DURATION: float = 0.12


var _failures: Array[String] = []
var _threshold_signal_count: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(
		DamageGateRuntimeScene != null \
			and DamageGateRuntimeScene.can_instantiate(),
		"The phase 1 Damage Gate scene must load and instantiate."
	)
	if DamageGateRuntimeScene == null \
			or not DamageGateRuntimeScene.can_instantiate():
		_finish()
		return

	var wave: Node2D = DamageGateRuntimeScene.instantiate() as Node2D
	_expect(wave != null, "The Damage Gate scene root must be a Node2D.")
	if wave == null:
		_finish()
		return
	root.add_child(wave)
	await process_frame
	await process_frame

	var attack_prototype: TeddyPhase1AttackRuntimePrototype = (
		wave.get_node_or_null("BossPrototype")
		as TeddyPhase1AttackRuntimePrototype
	)
	var prototype: TeddyPhase1DamageGateRuntimePrototype = (
		wave.get_node_or_null("BossPrototype/Phase1Damage")
		as TeddyPhase1DamageGateRuntimePrototype
	)
	var runtime: BossPhase1AttackRuntime = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
	var controller: BossAttackController = wave.get_node_or_null(
		"BossPrototype/BossAttackController"
	) as BossAttackController
	var teddy_attack: TeddyArmSweepAttack = wave.get_node_or_null(
		"BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var hurtbox: Area2D = wave.get_node_or_null(
		"BossPrototype/BossHurtbox"
	) as Area2D
	var health: BossHealthComponent = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossHealthComponent"
	) as BossHealthComponent
	var adapter: BossComboDamageAdapter = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossComboDamageAdapter"
	) as BossComboDamageAdapter
	var applier: BossGatedDamageApplier = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossDamageApplier"
	) as BossGatedDamageApplier
	var gate: BossDamageGate = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossDamageGate"
	) as BossDamageGate
	var combo: ComboSystem = wave.get_node_or_null("ComboSystem") as ComboSystem
	var ball_flow: WaveBallFlowController = wave.get_node_or_null(
		"WaveBallFlowController"
	) as WaveBallFlowController

	for check: Array in [
		[attack_prototype, "The existing Attack Prototype must remain present."],
		[prototype, "Phase1Damage must use the Gate integration Prototype."],
		[runtime, "The existing Attack Runtime must remain present."],
		[controller, "BossAttackController must remain present."],
		[teddy_attack, "TeddyArmSweepAttack must remain present."],
		[hurtbox, "BossHurtbox must remain present."],
		[health, "BossHealthComponent must remain present."],
		[adapter, "BossComboDamageAdapter must remain present."],
		[applier, "The Damage Applier must use BossGatedDamageApplier."],
		[gate, "BossDamageGate must exist in Phase1Damage."],
		[combo, "The existing ComboSystem must remain present."],
		[ball_flow, "The existing WaveBallFlowController must remain present."],
	]:
		_expect(check[0] != null, String(check[1]))

	if prototype == null \
			or attack_prototype == null \
			or runtime == null \
			or controller == null \
			or teddy_attack == null \
			or hurtbox == null \
			or health == null \
			or adapter == null \
			or applier == null \
			or gate == null \
			or combo == null \
			or ball_flow == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_check_bindings_and_initial_state(prototype, controller, applier, gate)
	await _test_gate_state_and_contact_flow(
		wave,
		prototype,
		controller,
		hurtbox,
		health,
		combo,
		ball_flow
	)
	_test_weight_rules(prototype.weight_rules)
	_test_weight_damage_profiles(
		wave, ball_flow, hurtbox, health, combo
	)
	_test_threshold_preserved(prototype, applier, health)
	_test_teddy_attack_hit_does_not_damage(
		wave, prototype, teddy_attack, health
	)
	_test_attack_controls_preserved(attack_prototype, runtime)
	_test_prototype_responsibility_boundaries()
	_test_teardown(
		wave,
		prototype,
		runtime,
		controller,
		hurtbox,
		health,
		applier,
		gate,
		ball_flow
	)

	wave.queue_free()
	await process_frame
	_finish()


func _check_bindings_and_initial_state(
	prototype: TeddyPhase1DamageGateRuntimePrototype,
	controller: BossAttackController,
	applier: BossGatedDamageApplier,
	gate: BossDamageGate
) -> void:
	_expect(prototype.damage_applier == applier,
		"The inherited Damage reference must point to the Gated Applier.")
	_expect(prototype.gated_damage_applier == applier,
		"The integration reference must point to the same Gated Applier.")
	_expect(prototype.damage_gate == gate,
		"The integration Prototype must reference the Scene Gate.")
	_expect(prototype.attack_controller == controller,
		"The integration Prototype must reference the real Controller.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"The initial Controller state must be IDLE.")
	_expect(gate.is_bound(), "The Gate must bind the real Controller at setup.")
	_expect(applier.is_damage_gate_bound(),
		"The Gated Applier must bind the Scene Gate at setup.")
	_expect(gate.is_damage_allowed(), "Initial IDLE must allow Boss damage.")
	_expect(prototype.invulnerability_label.text
		== "Boss Invulnerability: OFF",
		"Initial Gate UI must display OFF.")


func _test_gate_state_and_contact_flow(
	wave: Node2D,
	prototype: TeddyPhase1DamageGateRuntimePrototype,
	controller: BossAttackController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem,
	ball_flow: WaveBallFlowController
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "The Gate contact test requires a Normal ball.")
		_free_ball(ball)
		return
	_activate_profile(ball_flow, definition, ball)
	var resolved_count: Array[int] = [0]
	prototype.gated_damage_applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_count[0] += 1
	)

	var pattern: BossAttackPattern = BossAttackPattern.new()
	pattern.attack_id = &"damage_gate_scene_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	controller.pattern = pattern
	_expect(controller.start_attack(), "The Gate state attack must start.")
	_expect(controller.current_state == BossAttackController.State.TELEGRAPH,
		"The test attack must enter TELEGRAPH synchronously.")
	_expect(_gate_allows(prototype), "TELEGRAPH must show Gate OFF.")
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() < 12000,
		"A TELEGRAPH Boss contact must reduce HP.")
	_expect(combo.combo_count == 1,
		"A TELEGRAPH Boss contact must increase Combo.")
	hurtbox.body_exited.emit(ball)

	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The Gate test attack must reach ACTIVE.")
	_expect(prototype.damage_gate.is_invulnerable(),
		"The Gate must be invulnerable during ACTIVE.")
	_expect(prototype.invulnerability_label.text
		== "Boss Invulnerability: ACTIVE",
		"The Gate UI must display ACTIVE immediately.")
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	var previous_hits_text: String = prototype.total_boss_hits_label.text
	var resolved_before: int = resolved_count[0]
	var boss_hits_before: int = _count_occurrences(
		prototype.damage_event_log.text, "BOSS HIT"
	)
	var blocked_before: int = _count_occurrences(
		prototype.damage_event_log.text, BLOCKED_ACTIVE_EVENT
	)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"An ACTIVE Boss contact must preserve HP.")
	_expect(combo.combo_count == previous_combo,
		"An ACTIVE Boss contact must preserve Combo.")
	_expect(resolved_count[0] == resolved_before,
		"An ACTIVE Boss contact must not emit boss_hit_resolved.")
	_expect(prototype.total_boss_hits_label.text == previous_hits_text,
		"An ACTIVE Boss contact must not increase Total Boss Hits.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text, "BOSS HIT"
	) == boss_hits_before, "An ACTIVE contact must not add a BOSS HIT log.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text, BLOCKED_ACTIVE_EVENT
	) == blocked_before + 1,
		"An ACTIVE contact must add one blocked log.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.RECOVERY
	), "The Gate test attack must reach RECOVERY.")
	_expect(_gate_allows(prototype), "RECOVERY must show Gate OFF.")
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"A continuing blocked contact must not damage after state change.")
	_expect(combo.combo_count == previous_combo,
		"A continuing blocked contact must not increase Combo.")

	hurtbox.body_exited.emit(ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() < previous_health,
		"A real RECOVERY re-entry must apply Boss damage.")
	_expect(combo.combo_count == previous_combo + 1,
		"A real RECOVERY re-entry must increase Combo once.")
	_deactivate_ball(ball_flow)
	_free_ball(ball)
	_expect(await _wait_until_state(
		controller, BossAttackController.State.IDLE
	), "The direct Gate test attack must finish in IDLE.")


func _gate_allows(
	prototype: TeddyPhase1DamageGateRuntimePrototype
) -> bool:
	return prototype.damage_gate.is_damage_allowed() \
		and prototype.invulnerability_label.text == "Boss Invulnerability: OFF"


func _test_weight_rules(weight_rules: BossBallDamageWeightRules) -> void:
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"light"), 0.90),
		"Light profile must be 0.90.")
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"normal"), 1.00),
		"Normal profile must remain 1.00.")
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"heavy"), 1.15),
		"Heavy profile must be 1.15.")


func _test_weight_damage_profiles(
	wave: Node2D,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	for profile: Array in [
		[&"light", 360],
		[&"normal", 400],
		[&"heavy", 460],
	]:
		_reset_damage_state(health, combo)
		var ball_id: StringName = StringName(profile[0])
		var expected_damage: int = int(profile[1])
		var definition: BallDefinition = _find_definition(ball_flow, ball_id)
		var ball: Pinball = _create_ball(wave, definition)
		if definition == null or ball == null:
			_expect(false, "%s profile ball must instantiate." % ball_id)
			_free_ball(ball)
			continue
		_activate_profile(ball_flow, definition, ball)
		hurtbox.body_entered.emit(ball)
		_expect(health.get_current_health() == 12000 - expected_damage,
			"%s first hit must preserve expected damage %d." % [
				ball_id,
				expected_damage,
			])
		_expect(combo.combo_count == 1,
			"Each isolated weight hit must register one Combo.")
		_deactivate_ball(ball_flow)
		_free_ball(ball)


func _test_threshold_preserved(
	prototype: TeddyPhase1DamageGateRuntimePrototype,
	applier: BossGatedDamageApplier,
	health: BossHealthComponent
) -> void:
	_threshold_signal_count = 0
	if not prototype.phase_threshold_reached.is_connected(
		_on_phase_threshold_reached
	):
		prototype.phase_threshold_reached.connect(_on_phase_threshold_reached)
	health.configure(12000)
	health.apply_damage(5799)
	applier.boss_hit_resolved.emit(5799, 5799, 12000, 6201, 12000, false)
	health.apply_damage(201)
	applier.boss_hit_resolved.emit(201, 201, 6201, 6000, 12000, false)
	_expect(_threshold_signal_count == 1,
		"The 50 percent threshold must still emit once.")
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: BELOW_50",
		"Exactly 6000 HP must still display BELOW_50.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text, THRESHOLD_EVENT
	) == 1, "The threshold event must remain in the Damage log once.")
	health.apply_damage(100)
	applier.boss_hit_resolved.emit(100, 100, 6000, 5900, 12000, false)
	_expect(_threshold_signal_count == 1,
		"Further below-threshold damage must not emit again.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text, THRESHOLD_EVENT
	) == 1, "The threshold log must remain unique.")


func _test_teddy_attack_hit_does_not_damage(
	wave: Node2D,
	prototype: TeddyPhase1DamageGateRuntimePrototype,
	teddy_attack: TeddyArmSweepAttack,
	health: BossHealthComponent
) -> void:
	var definition: BallDefinition = _find_definition(
		prototype.ball_flow, &"normal"
	)
	var ball: Pinball = _create_ball(wave, definition)
	if ball == null:
		_expect(false, "The Teddy attack signal test requires a ball.")
		return
	var previous_health: int = health.get_current_health()
	teddy_attack.attack_hit.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"Teddy arm attack_hit must not reduce Boss HP.")
	_free_ball(ball)


func _test_attack_controls_preserved(
	prototype: TeddyPhase1AttackRuntimePrototype,
	runtime: BossPhase1AttackRuntime
) -> void:
	_expect(runtime.is_ready(), "The existing Attack Runtime must remain ready.")
	prototype.start_button.emit_signal(&"pressed")
	_expect(runtime.is_running(), "The existing Start control must work.")
	prototype.new_ball_grace_button.emit_signal(&"pressed")
	_expect(prototype.scheduler.is_grace_active(),
		"The existing New Ball Grace control must work.")
	prototype.stop_button.emit_signal(&"pressed")
	_expect(not runtime.is_running(), "The existing Stop control must work.")
	prototype.reset_button.emit_signal(&"pressed")
	_expect(runtime.is_ready(), "The existing Reset control must preserve readiness.")


func _test_prototype_responsibility_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(
		INTEGRATION_PROTOTYPE_SCRIPT_PATH
	)
	_expect(not source.is_empty(),
		"The Gate integration Prototype source must be readable.")
	_expect(not source.contains("_on_boss_hurtbox_body_entered"),
		"The Gate integration Prototype must not override the Hurtbox handler.")
	_expect(not source.contains("resolve_and_apply_hit"),
		"The Gate integration Prototype must not duplicate Damage processing.")
	_expect(not source.contains("target_valid_hit_count"),
		"The Gate integration Prototype must not duplicate Damage rules.")


func _test_teardown(
	wave: Node2D,
	prototype: TeddyPhase1DamageGateRuntimePrototype,
	runtime: BossPhase1AttackRuntime,
	controller: BossAttackController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	applier: BossGatedDamageApplier,
	gate: BossDamageGate,
	ball_flow: WaveBallFlowController
) -> void:
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "The teardown test requires a Normal ball.")
		_free_ball(ball)
		return
	prototype.teardown()
	var previous_health: int = health.get_current_health()
	var previous_ui: String = prototype.invulnerability_label.text
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"Hurtbox events after teardown must be ignored.")
	_expect(not gate.is_bound(), "Teardown must unbind the Gate Controller.")
	_expect(not applier.is_damage_gate_bound(),
		"Teardown must unbind the Gated Applier from the Gate.")
	_expect(previous_ui == "Boss Invulnerability: UNAVAILABLE",
		"Teardown must display Gate unavailable.")
	controller.pattern = _create_test_pattern()
	_expect(controller.start_attack(),
		"The existing Controller must remain independently operable.")
	_expect(prototype.invulnerability_label.text == previous_ui,
		"Old Controller changes must not update UI after teardown.")
	controller.cancel_attack()
	_expect(runtime.is_ready(),
		"Damage teardown must not teardown the Attack Runtime.")
	prototype.teardown()
	_expect(not gate.is_bound() and not applier.is_damage_gate_bound(),
		"Duplicate teardown must remain safe.")
	_free_ball(ball)


func _create_test_pattern() -> BossAttackPattern:
	var pattern: BossAttackPattern = BossAttackPattern.new()
	pattern.attack_id = &"damage_gate_teardown_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	return pattern


func _reset_damage_state(
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	combo.reset_wave()
	health.configure(12000)


func _find_definition(
	ball_flow: WaveBallFlowController,
	ball_id: StringName
) -> BallDefinition:
	if ball_flow.inventory == null:
		return null
	for definition: BallDefinition in ball_flow.inventory.get_available_definitions():
		if definition.ball_id == ball_id:
			return definition
	return null


func _create_ball(wave: Node2D, definition: BallDefinition) -> Pinball:
	if definition == null or definition.ball_scene == null:
		return null
	var ball: Pinball = definition.ball_scene.instantiate() as Pinball
	if ball != null:
		wave.add_child(ball)
	return ball


func _activate_profile(
	ball_flow: WaveBallFlowController,
	definition: BallDefinition,
	ball: Pinball
) -> void:
	ball_flow.ball_selection_confirmed.emit(definition, 0)
	ball_flow.active_ball_changed.emit(ball)


func _deactivate_ball(ball_flow: WaveBallFlowController) -> void:
	ball_flow.active_ball_changed.emit(null)


func _free_ball(ball: Pinball) -> void:
	if ball != null and is_instance_valid(ball):
		ball.free()


func _wait_until_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames: int = 360
) -> bool:
	for _frame: int in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _on_phase_threshold_reached() -> void:
	_threshold_signal_count += 1


func _count_occurrences(text: String, fragment: String) -> int:
	if fragment.is_empty():
		return 0
	return text.split(fragment).size() - 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_phase1_damage_gate_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_phase1_damage_gate_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
