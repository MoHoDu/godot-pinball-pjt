extends SceneTree


const DamageRuntimeScene: PackedScene = preload(
	"res://scenes/wave/test_teddy_phase1_damage_runtime.tscn"
)
const WEIGHT_RULES_PATH: String = (
	"res://settings/bosses/BossBallDamageWeightRules.tres"
)
const THRESHOLD_EVENT: String = "PHASE 2 THRESHOLD REACHED"


var _failures: Array[String] = []
var _threshold_signal_count: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(
		DamageRuntimeScene != null and DamageRuntimeScene.can_instantiate(),
		"The phase 1 damage runtime scene must load and instantiate."
	)
	if DamageRuntimeScene == null or not DamageRuntimeScene.can_instantiate():
		_finish()
		return

	var wave: Node2D = DamageRuntimeScene.instantiate() as Node2D
	_expect(wave != null, "The damage runtime scene root must be a Node2D.")
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
	var damage_prototype: TeddyPhase1DamageRuntimePrototype = (
		wave.get_node_or_null("BossPrototype/Phase1Damage")
		as TeddyPhase1DamageRuntimePrototype
	)
	var attack_runtime: BossPhase1AttackRuntime = wave.get_node_or_null(
		"BossPrototype/Phase1Attack/Runtime"
	) as BossPhase1AttackRuntime
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
	var applier: BossDamageApplier = wave.get_node_or_null(
		"BossPrototype/Phase1Damage/BossDamageApplier"
	) as BossDamageApplier
	var combo: ComboSystem = wave.get_node_or_null("ComboSystem") as ComboSystem
	var ball_flow: WaveBallFlowController = wave.get_node_or_null(
		"WaveBallFlowController"
	) as WaveBallFlowController

	_expect(attack_prototype != null,
		"The existing Attack Prototype must remain on BossPrototype.")
	_expect(damage_prototype != null,
		"Phase1Damage must use TeddyPhase1DamageRuntimePrototype.")
	_expect(attack_runtime != null,
		"The existing Attack Runtime structure must remain present.")
	_expect(teddy_attack != null,
		"The existing TeddyArmSweepAttack must remain present.")
	_expect(hurtbox != null, "BossHurtbox must exist.")
	_expect(health != null, "BossHealthComponent must exist.")
	_expect(adapter != null, "BossComboDamageAdapter must exist.")
	_expect(applier != null, "BossDamageApplier must exist.")
	_expect(combo != null, "The existing ComboSystem must remain present.")
	_expect(ball_flow != null,
		"The existing WaveBallFlowController must remain present.")
	if damage_prototype == null \
			or attack_prototype == null \
			or attack_runtime == null \
			or teddy_attack == null \
			or hurtbox == null \
			or health == null \
			or adapter == null \
			or applier == null \
			or combo == null \
			or ball_flow == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_check_scene_structure(wave, hurtbox)
	_check_damage_bindings(
		damage_prototype,
		combo,
		ball_flow,
		hurtbox,
		health,
		adapter,
		applier
	)
	_check_initial_ui(damage_prototype)
	_check_weight_rules(damage_prototype.weight_rules)
	_check_attack_runtime_preserved(attack_prototype, attack_runtime)

	_test_non_pinball_is_ignored(wave, hurtbox, health, combo)
	_test_non_active_pinball_is_ignored(
		wave,
		damage_prototype,
		ball_flow,
		hurtbox,
		health,
		combo
	)
	_test_unknown_profile_is_ignored(
		wave,
		ball_flow,
		hurtbox,
		health,
		combo
	)
	_test_first_hit_damage(
		wave, damage_prototype, &"light", 320, ball_flow, hurtbox, health, combo
	)
	_test_first_hit_damage(
		wave, damage_prototype, &"normal", 400, ball_flow, hurtbox, health, combo
	)
	_test_first_hit_damage(
		wave, damage_prototype, &"heavy", 500, ball_flow, hurtbox, health, combo
	)
	_test_contact_lifecycle(
		wave,
		damage_prototype,
		ball_flow,
		hurtbox,
		health,
		combo
	)
	_test_active_ball_change_clears_contact(
		wave,
		damage_prototype,
		ball_flow,
		hurtbox,
		health,
		combo
	)
	_test_teddy_attack_hit_does_not_damage(
		wave,
		damage_prototype,
		teddy_attack,
		health
	)
	_test_threshold_once(damage_prototype, applier, health)
	_test_damage_teardown(
		wave,
		damage_prototype,
		attack_runtime,
		ball_flow,
		hurtbox,
		health,
		adapter,
		applier
	)

	wave.queue_free()
	await process_frame
	_finish()


func _check_scene_structure(wave: Node2D, hurtbox: Area2D) -> void:
	_expect(hurtbox.position.is_equal_approx(Vector2(0.0, -335.0)),
		"BossHurtbox must use the authored position.")
	_expect(hurtbox.collision_layer == 0,
		"BossHurtbox must not create a physical collision layer.")
	_expect(hurtbox.collision_mask == 1,
		"BossHurtbox must monitor the Pinball collision layer.")
	_expect(hurtbox.monitoring, "BossHurtbox monitoring must be enabled.")
	_expect(not hurtbox.monitorable,
		"BossHurtbox must not be exposed as a monitored target.")

	var collision_shapes: Array[Node] = hurtbox.find_children(
		"*", "CollisionShape2D", false, false
	)
	_expect(collision_shapes.size() == 1,
		"BossHurtbox must contain exactly one CollisionShape2D.")
	if collision_shapes.size() == 1:
		var collision: CollisionShape2D = collision_shapes[0] as CollisionShape2D
		_expect(collision != null and collision.shape is RectangleShape2D,
			"BossHurtbox must use a RectangleShape2D.")
		if collision != null and collision.shape is RectangleShape2D:
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			_expect(rectangle.size.is_equal_approx(Vector2(300.0, 460.0)),
				"BossHurtbox rectangle must use the authored size.")

	_expect(wave.get_node_or_null(
		"BossPrototype/DebugCanvas/DebugUI/Panel/VBox/EventLog"
	) != null, "The existing Attack EventLog must remain present.")
	var damage_log: RichTextLabel = wave.get_node_or_null(
		"BossPrototype/DebugCanvas/DebugUI/DamagePanel/VBox/DamageEventLog"
	) as RichTextLabel
	_expect(damage_log != null, "The Damage EventLog must exist.")
	_expect(damage_log != wave.get_node_or_null(
		"BossPrototype/DebugCanvas/DebugUI/Panel/VBox/EventLog"
	), "Attack and Damage EventLogs must be different Nodes.")


func _check_damage_bindings(
	prototype: TeddyPhase1DamageRuntimePrototype,
	combo: ComboSystem,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	adapter: BossComboDamageAdapter,
	applier: BossDamageApplier
) -> void:
	_expect(prototype.rules != null,
		"Damage Prototype must reference Stage1BossPhase1Rules.")
	_expect(prototype.weight_rules != null,
		"Damage Prototype must reference BossBallDamageWeightRules.")
	_expect(
		prototype.weight_rules != null
		and prototype.weight_rules.resource_path == WEIGHT_RULES_PATH,
		"Damage Prototype must reference the configured Weight Rules Resource."
	)
	_expect(prototype.combo_system == combo,
		"Damage Prototype must reference the existing ComboSystem.")
	_expect(prototype.ball_flow == ball_flow,
		"Damage Prototype must reference the existing Ball Flow.")
	_expect(prototype.boss_hurtbox == hurtbox,
		"Damage Prototype must reference BossHurtbox.")
	_expect(prototype.health == health,
		"Damage Prototype must reference BossHealthComponent.")
	_expect(prototype.damage_adapter == adapter,
		"Damage Prototype must reference BossComboDamageAdapter.")
	_expect(prototype.damage_applier == applier,
		"Damage Prototype must reference BossDamageApplier.")
	_expect(health.is_configured(), "Health must be configured during setup.")
	_expect(health.get_max_health() == 12000,
		"Stage 1 maximum Boss HP must be 12000.")
	_expect(health.get_current_health() == 12000,
		"Stage 1 current Boss HP must begin at 12000.")
	_expect(adapter.is_bound(), "Damage Adapter must bind the real ComboSystem.")
	_expect(applier.is_bound(), "Damage Applier must bind Adapter and Health.")


func _check_initial_ui(prototype: TeddyPhase1DamageRuntimePrototype) -> void:
	_expect(prototype.boss_health_label.text == "Boss HP: 12000 / 12000",
		"Initial Boss HP UI must show 12000 / 12000.")
	_expect(prototype.health_ratio_label.text == "HP Ratio: 1.000",
		"Initial HP Ratio UI must show 1.000.")
	_expect(prototype.last_damage_label.text
		== "Last Damage: Calculated 0 / Applied 0",
		"Initial Last Damage UI must show zero values.")
	_expect(prototype.total_boss_hits_label.text == "Total Boss Hits: 0",
		"Initial Boss Hit count must be zero.")
	_expect(prototype.current_ball_weight_label.text
		== "Current Ball Damage Weight: None",
		"Initial ball weight UI must show None.")
	_expect(prototype.current_multiplier_label.text
		== "Current Ball Damage Multiplier: 0.00",
		"Initial multiplier UI must show 0.00.")
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: ABOVE_50",
		"Initial threshold UI must show ABOVE_50.")
	_expect(prototype.invulnerability_label.text
		== "INVULNERABILITY: NOT IMPLEMENTED",
		"Damage UI must state that ACTIVE invulnerability is not implemented.")


func _check_weight_rules(weight_rules: BossBallDamageWeightRules) -> void:
	if weight_rules == null:
		return
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"light"), 0.80),
		"Light damage profile must resolve to 0.80.")
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"normal"), 1.00),
		"Normal damage profile must resolve to 1.00.")
	_expect(is_equal_approx(weight_rules.get_damage_multiplier(&"heavy"), 1.25),
		"Heavy damage profile must resolve to 1.25.")
	_expect(not weight_rules.has_profile(&"unknown"),
		"Unknown ball IDs must not have a damage profile.")


func _check_attack_runtime_preserved(
	prototype: TeddyPhase1AttackRuntimePrototype,
	runtime: BossPhase1AttackRuntime
) -> void:
	_expect(runtime.is_ready(), "Existing Attack Runtime setup must still succeed.")
	_expect(not runtime.is_running(),
		"Existing Attack Runtime must initially remain stopped.")
	prototype.start_button.emit_signal(&"pressed")
	_expect(runtime.is_running(), "Existing Start button must still work.")
	prototype.stop_button.emit_signal(&"pressed")
	_expect(not runtime.is_running(), "Existing Stop button must still work.")


func _test_non_pinball_is_ignored(
	wave: Node2D,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var non_pinball: Node2D = Node2D.new()
	wave.add_child(non_pinball)
	hurtbox.body_entered.emit(non_pinball)
	_expect(health.get_current_health() == 12000,
		"A non-Pinball body must not damage the Boss.")
	_expect(combo.combo_count == 0,
		"A non-Pinball body must not increase Combo.")
	non_pinball.free()


func _test_non_active_pinball_is_ignored(
	wave: Node2D,
	prototype: TeddyPhase1DamageRuntimePrototype,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var active_ball: Pinball = _create_ball(wave, definition)
	var other_ball: Pinball = _create_ball(wave, definition)
	if definition == null or active_ball == null or other_ball == null:
		_expect(false, "Normal test balls must instantiate.")
		_free_ball(active_ball)
		_free_ball(other_ball)
		return
	_activate_profile(ball_flow, definition, active_ball)
	hurtbox.body_entered.emit(other_ball)
	_expect(health.get_current_health() == 12000,
		"A Pinball other than the active ball must be ignored.")
	_expect(combo.combo_count == 0,
		"A non-active Pinball must not increase Combo.")
	_expect(prototype.current_multiplier_label.text.ends_with("1.00"),
		"The active Normal profile must still be visible.")
	_deactivate_ball(ball_flow)
	_free_ball(active_ball)
	_free_ball(other_ball)


func _test_unknown_profile_is_ignored(
	wave: Node2D,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = BallDefinition.new()
	definition.ball_id = &"unknown"
	var ball: Pinball = Pinball.new()
	wave.add_child(ball)
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == 12000,
		"An unknown ball profile must not damage the Boss.")
	_expect(combo.combo_count == 0,
		"An unknown ball profile must not increase Combo.")
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_first_hit_damage(
	wave: Node2D,
	prototype: TeddyPhase1DamageRuntimePrototype,
	ball_id: StringName,
	expected_damage: int,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = _find_definition(ball_flow, ball_id)
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "%s test ball must instantiate." % ball_id)
		_free_ball(ball)
		return

	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == 12000 - expected_damage,
		"%s first Boss hit must apply %d damage." % [ball_id, expected_damage])
	_expect(combo.combo_count == 1,
		"Each first valid Boss hit must increase Combo exactly once.")
	_expect(prototype.last_damage_label.text == (
		"Last Damage: Calculated %d / Applied %d"
		% [expected_damage, expected_damage]
	), "Damage UI must show calculated and applied damage.")
	_expect(prototype.damage_event_log.text.contains("Ball: %s" % ball_id),
		"Damage Event Log must identify the active ball ID.")
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_contact_lifecycle(
	wave: Node2D,
	_prototype: TeddyPhase1DamageRuntimePrototype,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "Contact lifecycle test ball must instantiate.")
		_free_ball(ball)
		return
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	var health_after_first_hit: int = health.get_current_health()
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == health_after_first_hit,
		"A continuing contact must not apply duplicate damage.")
	_expect(combo.combo_count == 1,
		"A continuing contact must not increase Combo twice.")
	hurtbox.body_exited.emit(ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() < health_after_first_hit,
		"A real exit followed by re-entry must allow a new Boss hit.")
	_expect(combo.combo_count == 2,
		"Re-entry after exit must register exactly one additional Combo.")
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_active_ball_change_clears_contact(
	wave: Node2D,
	_prototype: TeddyPhase1DamageRuntimePrototype,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	combo: ComboSystem
) -> void:
	_reset_damage_state(health, combo)
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "Active-ball change test ball must instantiate.")
		_free_ball(ball)
		return
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_deactivate_ball(ball_flow)
	_activate_profile(ball_flow, definition, ball)
	hurtbox.body_entered.emit(ball)
	_expect(combo.combo_count == 2,
		"Changing the active ball must clear previous contact tracking.")
	_deactivate_ball(ball_flow)
	_free_ball(ball)


func _test_teddy_attack_hit_does_not_damage(
	wave: Node2D,
	prototype: TeddyPhase1DamageRuntimePrototype,
	teddy_attack: TeddyArmSweepAttack,
	health: BossHealthComponent
) -> void:
	var definition: BallDefinition = _find_definition(
		prototype.ball_flow, &"normal"
	)
	var ball: Pinball = _create_ball(wave, definition)
	if ball == null:
		_expect(false, "Teddy attack signal test ball must instantiate.")
		return
	var previous_health: int = health.get_current_health()
	teddy_attack.attack_hit.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"Teddy arm attack_hit must not be treated as a Boss damage hit.")
	_free_ball(ball)


func _test_threshold_once(
	prototype: TeddyPhase1DamageRuntimePrototype,
	applier: BossDamageApplier,
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
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: ABOVE_50",
		"HP above 6000 must keep the threshold state ABOVE_50.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text,
		THRESHOLD_EVENT
	) == 0, "A hit above 6000 HP must not append the threshold event.")

	health.apply_damage(201)
	applier.boss_hit_resolved.emit(201, 201, 6201, 6000, 12000, false)
	_expect(_threshold_signal_count == 1,
		"The 50 percent downward crossing must emit exactly once.")
	_expect(prototype.phase_threshold_label.text
		== "Phase Threshold: BELOW_50",
		"Exactly 6000 HP must display BELOW_50.")
	_expect(prototype.damage_event_log.text.contains("BOSS HIT"),
		"The crossing hit must retain its normal Boss Hit log.")
	_expect(prototype.damage_event_log.text.contains("HP: 6201 -> 6000"),
		"The crossing hit must retain its normal HP transition log.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text,
		THRESHOLD_EVENT
	) == 1, "The first downward crossing must append one threshold event.")

	for next_health: int in [5900, 5800, 5700, 5600, 5500]:
		var previous_health: int = health.get_current_health()
		var damage: int = previous_health - next_health
		health.apply_damage(damage)
		applier.boss_hit_resolved.emit(
			damage,
			damage,
			previous_health,
			next_health,
			12000,
			false
		)
	_expect(_threshold_signal_count == 1,
		"Further damage below the threshold must not emit again.")
	_expect(_count_occurrences(
		prototype.damage_event_log.text,
		THRESHOLD_EVENT
	) == 1, "The rolling log must retain exactly one threshold event.")


func _test_damage_teardown(
	wave: Node2D,
	prototype: TeddyPhase1DamageRuntimePrototype,
	attack_runtime: BossPhase1AttackRuntime,
	ball_flow: WaveBallFlowController,
	hurtbox: Area2D,
	health: BossHealthComponent,
	adapter: BossComboDamageAdapter,
	applier: BossDamageApplier
) -> void:
	var definition: BallDefinition = _find_definition(ball_flow, &"normal")
	var ball: Pinball = _create_ball(wave, definition)
	if definition == null or ball == null:
		_expect(false, "Teardown test ball must instantiate.")
		_free_ball(ball)
		return
	prototype.teardown()
	var previous_health: int = health.get_current_health()
	ball_flow.ball_selection_confirmed.emit(definition, 0)
	ball_flow.active_ball_changed.emit(ball)
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == previous_health,
		"Hurtbox events after Damage teardown must be ignored.")
	_expect(not adapter.is_bound(),
		"Damage teardown must release the Adapter Combo binding.")
	_expect(not applier.is_bound(),
		"Damage teardown must unbind the Damage Applier.")
	_expect(attack_runtime.is_ready(),
		"Damage teardown must not teardown the existing Attack Runtime.")
	_free_ball(ball)


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
		print("PASS: teddy_phase1_damage_runtime_scene_test")
		quit(0)
		return
	print(
		"FAIL: teddy_phase1_damage_runtime_scene_test (%d failures)"
		% _failures.size()
	)
	quit(1)
