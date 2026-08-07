extends SceneTree


const GATED_APPLIER_SCRIPT_PATH: String = (
	"res://scripts/boss_system/boss_gated_damage_applier.gd"
)
const BOSS_MAX_HEALTH: int = 12000
const TARGET_VALID_HIT_COUNT: int = 30
const TEST_DURATION: float = 0.08


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
	await _test_initial_gate_unavailable_is_fail_closed()
	await _test_gate_bind_contract()
	await _test_idle_damage_uses_parent_contract()
	await _test_attack_states_gate_parent_damage()
	await _test_controller_binding_loss_is_fail_closed()
	await _test_freed_gate_is_fail_closed()
	await _test_gate_unbind_preserves_parent_binding()
	await _test_counter_forwarding_when_allowed()
	await _test_parent_invalid_input_policy_is_preserved()
	_test_forbidden_dependencies()
	_finish()


func _test_initial_gate_unavailable_is_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var applier: BossGatedDamageApplier = fixture.applier
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	var resolved_count: Array[int] = [0]
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_count[0] += 1
	)

	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A Gated Applier without a Gate must return 0.")
	_expect(health.get_current_health() == BOSS_MAX_HEALTH,
		"A missing Gate must preserve Boss health.")
	_expect(combo.combo_count == 0,
		"A missing Gate must preserve Combo.")
	_expect(resolved_count[0] == 0,
		"A missing Gate must not emit the parent resolved signal.")
	_expect(blocked_reasons == [
		BossGatedDamageApplier.BLOCK_REASON_GATE_UNAVAILABLE,
	], "A missing Gate must emit gate_unavailable exactly once.")
	await _destroy_fixture(fixture)


func _test_gate_bind_contract() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var applier: BossGatedDamageApplier = fixture.applier
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var unbound_gate: BossDamageGate = BossDamageGate.new()
	root.add_child(unbound_gate)
	await process_frame

	_expect(not applier.bind_damage_gate(null),
		"A null Gate binding must be rejected.")
	_expect(not applier.bind_damage_gate(unbound_gate),
		"A Gate without a Controller binding must be rejected.")
	_expect(gate.bind_controller(controller),
		"The live fixture Gate must bind its Controller.")
	_expect(applier.bind_damage_gate(gate),
		"A live bound Gate must be accepted.")
	_expect(applier.is_damage_gate_bound(),
		"A successful Gate binding must be observable.")
	_expect(applier.bind_damage_gate(gate),
		"Binding the same Gate again must be idempotent.")

	var invalid_gate: BossDamageGate = BossDamageGate.new()
	root.add_child(invalid_gate)
	await process_frame
	invalid_gate.free()
	_expect(not applier.bind_damage_gate(invalid_gate),
		"A freed replacement Gate must be rejected.")
	_expect(applier.is_damage_gate_bound(),
		"A failed Gate rebind must preserve the existing binding.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 400,
		"The preserved Gate binding must remain usable.")

	unbound_gate.queue_free()
	await _destroy_fixture(fixture)


func _test_idle_damage_uses_parent_contract() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var gate: BossDamageGate = fixture.gate
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	var resolved_results: Array[Vector2i] = []
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.boss_hit_resolved.connect(func(
		calculated: int,
		applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_results.append(Vector2i(calculated, applied))
	)

	_expect(gate.is_damage_allowed(), "IDLE must allow damage.")
	_expect(applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0
	) == 400, "The first allowed Normal hit must apply 400 damage.")
	_expect(health.get_current_health() == 11600,
		"Allowed IDLE damage must reduce Boss health.")
	_expect(combo.combo_count == 1,
		"Allowed IDLE damage must register one Combo hit.")
	_expect(resolved_results == [Vector2i(400, 400)],
		"Allowed IDLE damage must preserve the parent resolved signal.")
	_expect(blocked_reasons.is_empty(),
		"Allowed IDLE damage must not emit damage_blocked.")
	await _destroy_fixture(fixture)


func _test_attack_states_gate_parent_damage() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	var resolved_count: Array[int] = [0]
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_count[0] += 1
	)

	_expect(controller.start_attack(), "The state-policy attack must start.")
	_expect(controller.current_state == BossAttackController.State.TELEGRAPH,
		"start_attack must enter TELEGRAPH synchronously.")
	_expect(gate.is_damage_allowed(), "TELEGRAPH must allow damage.")
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) > 0,
		"TELEGRAPH must delegate damage to the parent Applier.")
	_expect(health.get_current_health() < previous_health,
		"TELEGRAPH damage must reduce health.")
	_expect(combo.combo_count == previous_combo + 1,
		"TELEGRAPH damage must increase Combo once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.ACTIVE
	), "The state-policy attack must reach ACTIVE.")
	_expect(gate.is_invulnerable(), "ACTIVE must make the Gate invulnerable.")
	previous_health = health.get_current_health()
	previous_combo = combo.combo_count
	var resolved_before_active: int = resolved_count[0]
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"ACTIVE damage must be blocked before the parent Applier.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"Each repeated direct ACTIVE request must also be blocked.")
	_expect(health.get_current_health() == previous_health,
		"ACTIVE requests must not change health.")
	_expect(combo.combo_count == previous_combo,
		"ACTIVE requests must not increase Combo.")
	_expect(resolved_count[0] == resolved_before_active,
		"ACTIVE requests must not emit boss_hit_resolved.")
	_expect(blocked_reasons == [
		BossGatedDamageApplier.BLOCK_REASON_BOSS_ACTIVE,
		BossGatedDamageApplier.BLOCK_REASON_BOSS_ACTIVE,
	], "Each direct ACTIVE request must emit boss_active exactly once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.RECOVERY
	), "The state-policy attack must reach RECOVERY.")
	previous_health = health.get_current_health()
	previous_combo = combo.combo_count
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) > 0,
		"RECOVERY must delegate damage to the parent Applier.")
	_expect(health.get_current_health() < previous_health,
		"RECOVERY damage must reduce health.")
	_expect(combo.combo_count == previous_combo + 1,
		"RECOVERY damage must increase Combo once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.COOLDOWN
	), "The state-policy attack must reach COOLDOWN.")
	previous_health = health.get_current_health()
	previous_combo = combo.combo_count
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) > 0,
		"COOLDOWN must delegate damage to the parent Applier.")
	_expect(health.get_current_health() < previous_health,
		"COOLDOWN damage must reduce health.")
	_expect(combo.combo_count == previous_combo + 1,
		"COOLDOWN damage must increase Combo once.")

	_expect(await _wait_until_state(
		controller, BossAttackController.State.IDLE
	), "The state-policy attack must return to IDLE.")
	previous_health = health.get_current_health()
	previous_combo = combo.combo_count
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) > 0,
		"Returned IDLE must delegate damage to the parent Applier.")
	_expect(health.get_current_health() < previous_health,
		"Returned IDLE damage must reduce health.")
	_expect(combo.combo_count == previous_combo + 1,
		"Returned IDLE damage must increase Combo once.")
	await _destroy_fixture(fixture)


func _test_controller_binding_loss_is_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	var resolved_count: Array[int] = [0]
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_count[0] += 1
	)
	root.remove_child(controller)
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count

	_expect(not gate.is_bound(),
		"Removing the Controller from Tree must invalidate the Gate binding.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A lost Controller binding must fail closed.")
	_expect(health.get_current_health() == previous_health,
		"A lost binding must preserve health.")
	_expect(combo.combo_count == previous_combo,
		"A lost binding must preserve Combo.")
	_expect(resolved_count[0] == 0,
		"A lost binding must not emit boss_hit_resolved.")
	_expect(blocked_reasons == [
		BossGatedDamageApplier.BLOCK_REASON_GATE_UNAVAILABLE,
	], "A lost Controller binding must emit gate_unavailable once.")
	await _destroy_fixture(fixture)


func _test_freed_gate_is_fail_closed() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var gate: BossDamageGate = fixture.gate
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	var resolved_count: Array[int] = [0]
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_was_counter: bool
	) -> void:
		resolved_count[0] += 1
	)
	gate.free()
	var previous_health: int = health.get_current_health()
	var previous_combo: int = combo.combo_count

	_expect(not applier.is_damage_gate_bound(),
		"A freed Gate must not remain bound.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A freed Gate must fail closed without invalid access.")
	_expect(health.get_current_health() == previous_health,
		"A freed Gate must preserve health.")
	_expect(combo.combo_count == previous_combo,
		"A freed Gate must preserve Combo.")
	_expect(resolved_count[0] == 0,
		"A freed Gate must not emit boss_hit_resolved.")
	_expect(blocked_reasons == [
		BossGatedDamageApplier.BLOCK_REASON_GATE_UNAVAILABLE,
	], "A freed Gate must emit gate_unavailable once.")
	await _destroy_fixture(fixture)


func _test_gate_unbind_preserves_parent_binding() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var adapter: BossComboDamageAdapter = fixture.adapter
	var gate: BossDamageGate = fixture.gate
	var controller: BossAttackController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var blocked_reasons: Array[StringName] = []
	applier.damage_blocked.connect(func(reason: StringName) -> void:
		blocked_reasons.append(reason)
	)
	applier.unbind_damage_gate()

	_expect(not applier.is_damage_gate_bound(),
		"unbind_damage_gate must clear only the Gate binding.")
	_expect(applier.is_bound(),
		"Gate unbind must preserve the parent Adapter/Health binding.")
	_expect(adapter.is_bound(),
		"Gate unbind must preserve the Adapter Combo binding.")
	_expect(gate.is_bound(),
		"Gate unbind must not alter the Gate Controller binding.")
	_expect(controller.current_state == BossAttackController.State.IDLE,
		"Gate unbind must not alter the Controller state.")
	_expect(health.is_configured(),
		"Gate unbind must preserve configured Health.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A Gate-unbound request must fail closed.")
	_expect(health.get_current_health() == BOSS_MAX_HEALTH,
		"Gate unbind must not change health.")
	_expect(combo.combo_count == 0,
		"Gate unbind must not change Combo.")
	_expect(blocked_reasons == [
		BossGatedDamageApplier.BLOCK_REASON_GATE_UNAVAILABLE,
	], "Gate unbind must emit gate_unavailable once per request.")
	applier.unbind_damage_gate()
	_expect(applier.is_bound(),
		"A duplicate Gate unbind must leave the parent binding intact.")
	await _destroy_fixture(fixture)


func _test_counter_forwarding_when_allowed() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossGatedDamageApplier = fixture.applier
	var counter_flags: Array[bool] = []
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		was_counter: bool
	) -> void:
		counter_flags.append(was_counter)
	)

	_expect(applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0,
		true,
		1.35
	) == 540, "An allowed Counter must preserve the parent 1.35 result.")
	_expect(counter_flags == [true],
		"An allowed Counter must preserve the parent signal flag.")
	await _destroy_fixture(fixture)


func _test_parent_invalid_input_policy_is_preserved() -> void:
	var invalid_inputs: Array[Array] = [
		[0, 1.0, false, 1.0],
		[-1, 1.0, false, 1.0],
		[TARGET_VALID_HIT_COUNT, 0.0, false, 1.0],
		[TARGET_VALID_HIT_COUNT, NAN, false, 1.0],
		[TARGET_VALID_HIT_COUNT, INF, false, 1.0],
	]
	for input: Array in invalid_inputs:
		var fixture: Dictionary = await _create_fixture(true)
		var applier: BossGatedDamageApplier = fixture.applier
		var health: BossHealthComponent = fixture.health
		var combo: ComboSystem = fixture.combo
		var blocked_count: Array[int] = [0]
		var resolved_count: Array[int] = [0]
		applier.damage_blocked.connect(func(_reason: StringName) -> void:
			blocked_count[0] += 1
		)
		applier.boss_hit_resolved.connect(func(
			_calculated: int,
			_applied: int,
			_previous: int,
			_current: int,
			_maximum: int,
			_was_counter: bool
		) -> void:
			resolved_count[0] += 1
		)

		_expect(applier.resolve_and_apply_hit(
			int(input[0]),
			float(input[1]),
			bool(input[2]),
			float(input[3])
		) == 0, "Allowed invalid input must preserve the parent rejection.")
		_expect(health.get_current_health() == BOSS_MAX_HEALTH,
			"Parent-rejected input must preserve health.")
		_expect(combo.combo_count == 0,
			"Parent-rejected input must preserve Combo.")
		_expect(resolved_count[0] == 0,
			"Parent-rejected input must not emit boss_hit_resolved.")
		_expect(blocked_count[0] == 0,
			"Parent input rejection must not be mislabeled as Gate blocking.")
		await _destroy_fixture(fixture)


func _test_forbidden_dependencies() -> void:
	var source: String = FileAccess.get_file_as_string(
		GATED_APPLIER_SCRIPT_PATH
	)
	_expect(not source.is_empty(), "The Gated Applier source must be readable.")
	for forbidden_name: String in [
		"BossAttackController",
		"Pinball",
		"PinballStats",
		"BossHurtbox",
		"Scheduler",
		"Runtime",
		"Control",
		"CanvasLayer",
	]:
		_expect(not source.contains(forbidden_name),
			"BossGatedDamageApplier must not reference %s." % forbidden_name)


func _create_fixture(bind_gate: bool) -> Dictionary:
	var combo: ComboSystem = ComboSystem.new()
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var health: BossHealthComponent = BossHealthComponent.new()
	var applier: BossGatedDamageApplier = BossGatedDamageApplier.new()
	var gate: BossDamageGate = BossDamageGate.new()
	var controller: BossAttackController = BossAttackController.new()
	var attack: RecordingAttack = RecordingAttack.new()
	var pattern: BossAttackPattern = BossAttackPattern.new()
	pattern.attack_id = &"gated_damage_applier_test"
	pattern.telegraph_duration = TEST_DURATION
	pattern.active_duration = TEST_DURATION
	pattern.recovery_duration = TEST_DURATION
	pattern.cooldown_duration = TEST_DURATION
	controller.pattern = pattern
	controller.attack = attack
	root.add_child(combo)
	root.add_child(adapter)
	root.add_child(health)
	root.add_child(applier)
	root.add_child(gate)
	root.add_child(attack)
	root.add_child(controller)
	await process_frame
	_expect(adapter.bind_combo_system(combo),
		"The fixture Adapter must bind the real ComboSystem.")
	_expect(health.configure(BOSS_MAX_HEALTH),
		"The fixture Health must configure successfully.")
	_expect(applier.bind(adapter, health),
		"The fixture parent Applier binding must succeed.")
	if bind_gate:
		_expect(gate.bind_controller(controller),
			"The fixture Gate must bind the live Controller.")
		_expect(applier.bind_damage_gate(gate),
			"The fixture Gated Applier must bind the Gate.")
	return {
		&"combo": combo,
		&"adapter": adapter,
		&"health": health,
		&"applier": applier,
		&"gate": gate,
		&"attack": attack,
		&"controller": controller,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	for key: StringName in [
		&"controller",
		&"attack",
		&"gate",
		&"applier",
		&"health",
		&"adapter",
		&"combo",
	]:
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
		print("PASS: boss_gated_damage_applier_test")
		quit(0)
		return
	print(
		"FAIL: boss_gated_damage_applier_test (%d failures)"
		% _failures.size()
	)
	quit(1)
