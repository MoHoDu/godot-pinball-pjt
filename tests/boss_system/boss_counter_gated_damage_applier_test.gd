extends SceneTree


const BOSS_MAX_HEALTH: int = 12000
const TARGET_VALID_HIT_COUNT: int = 30
const COUNTER_MULTIPLIER: float = 1.35
const WINDOW_DURATION_SEC: float = 0.5
const ATTACK_STATE_DURATION_SEC: float = 0.08


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
	await _test_configuration_and_window_binding()
	await _test_no_ready_counter_uses_normal_damage()
	await _test_ready_counter_applies_and_consumes_once()
	await _test_active_gate_block_preserves_counter()
	await _test_gate_unavailable_preserves_counter()
	await _test_parent_rejections_preserve_counter()
	await _test_missing_and_freed_window_fall_back_to_normal()
	_test_forbidden_dependencies_and_formula_reuse()
	_finish()


func _test_configuration_and_window_binding() -> void:
	var applier := BossCounterGatedDamageApplier.new()
	var window := BossCounterWindow.new()
	root.add_child(applier)
	root.add_child(window)

	_expect(not applier.configure_counter_multiplier(0.0),
		"A zero Counter multiplier must be rejected.")
	_expect(not applier.configure_counter_multiplier(-1.0),
		"A negative Counter multiplier must be rejected.")
	_expect(not applier.configure_counter_multiplier(NAN),
		"A NAN Counter multiplier must be rejected.")
	_expect(not applier.configure_counter_multiplier(INF),
		"An infinite Counter multiplier must be rejected.")
	_expect(applier.configure_counter_multiplier(COUNTER_MULTIPLIER),
		"A finite positive Counter multiplier must configure successfully.")
	_expect(not applier.configure_counter_multiplier(0.0),
		"An invalid reconfiguration must preserve the valid multiplier.")

	_expect(not applier.bind_counter_window(null),
		"A null Counter Window must be rejected.")
	_expect(applier.bind_counter_window(window),
		"A live Counter Window must bind.")
	_expect(applier.is_counter_window_bound(),
		"A successful Counter Window binding must be observable.")
	_expect(applier.bind_counter_window(window),
		"Binding the same Counter Window must be idempotent.")
	_expect(not applier.bind_counter_window(null),
		"A failed replacement must be rejected.")
	_expect(applier.is_counter_window_bound(),
		"A failed replacement must preserve the valid Window binding.")

	applier.unbind_counter_window()
	_expect(not applier.is_counter_window_bound(),
		"Counter Window unbind must clear only its reference.")
	applier.unbind_counter_window()
	_expect(not applier.is_counter_window_bound(),
		"Repeated Counter Window unbind must be safe.")
	applier.queue_free()
	window.queue_free()
	await process_frame


func _test_no_ready_counter_uses_normal_damage() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossCounterGatedDamageApplier = fixture.applier
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var window: BossCounterWindow = fixture.window
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

	_expect(not window.is_ready(), "Fixture Window must begin inactive.")
	_expect(applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0,
		true,
		2.0
	) == 400, "Without a ready Window, the first hit must remain normal.")
	_expect(health.get_current_health() == 11600,
		"Normal fallback must reduce health by the existing 400 damage.")
	_expect(combo.combo_count == 1,
		"Normal fallback must register one Combo hit.")
	_expect(counter_flags == [false],
		"The Window must be the sole Counter authority.")
	await _destroy_fixture(fixture)


func _test_ready_counter_applies_and_consumes_once() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossCounterGatedDamageApplier = fixture.applier
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var window: BossCounterWindow = fixture.window
	var counter_flags: Array[bool] = []
	var consumed_count: Array[int] = [0]
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
	window.counter_consumed.connect(func() -> void:
		consumed_count[0] += 1
	)
	_expect(not applier.configure_counter_multiplier(0.0),
		"A failed multiplier reconfiguration must be rejected.")
	_expect(window.activate(), "The configured Counter Window must activate.")

	_expect(applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0
	) == 540, "The first ready Counter hit must apply 400 x 1.35 = 540.")
	_expect(health.get_current_health() == 11460,
		"Counter damage must reduce Boss health by 540.")
	_expect(combo.combo_count == 1,
		"A Counter hit must register Combo exactly once.")
	_expect(counter_flags == [true],
		"The inherited resolved signal must identify the Counter hit.")
	_expect(not window.is_ready() and consumed_count[0] == 1,
		"A resolved Counter hit must consume the Window exactly once.")

	var second_damage: int = applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0
	)
	_expect(second_damage > 0,
		"The hit after consumption must continue through normal damage.")
	_expect(counter_flags == [true, false],
		"The hit after consumption must be marked as normal.")
	_expect(consumed_count[0] == 1,
		"A normal follow-up hit must not consume the Window again.")
	_expect(combo.combo_count == 2,
		"Each successful Counter and normal hit must add one Combo.")
	await _destroy_fixture(fixture)


func _test_active_gate_block_preserves_counter() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var applier: BossCounterGatedDamageApplier = fixture.applier
	var controller: BossAttackController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var window: BossCounterWindow = fixture.window
	var resolved_count: Array[int] = [0]
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
	_expect(window.activate(), "Counter must be ready before ACTIVE blocking.")
	_expect(controller.start_attack(), "The Gate test attack must start.")
	_expect(await _wait_until_state(
		controller,
		BossAttackController.State.ACTIVE
	), "The Gate test attack must reach ACTIVE.")

	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"ACTIVE must block Counter damage through the parent Gate.")
	_expect(health.get_current_health() == BOSS_MAX_HEALTH,
		"ACTIVE blocking must preserve health.")
	_expect(combo.combo_count == 0,
		"ACTIVE blocking must preserve Combo.")
	_expect(resolved_count[0] == 0,
		"ACTIVE blocking must not emit boss_hit_resolved.")
	_expect(window.is_ready(),
		"ACTIVE blocking must preserve the ready Counter Window.")
	controller.cancel_attack()
	await _destroy_fixture(fixture)


func _test_gate_unavailable_preserves_counter() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var applier: BossCounterGatedDamageApplier = fixture.applier
	var health: BossHealthComponent = fixture.health
	var combo: ComboSystem = fixture.combo
	var window: BossCounterWindow = fixture.window
	_expect(window.activate(), "Counter must be ready before Gate loss.")

	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A missing Gate must preserve the inherited fail-closed behavior.")
	_expect(health.get_current_health() == BOSS_MAX_HEALTH
		and combo.combo_count == 0,
		"A missing Gate must preserve health and Combo.")
	_expect(window.is_ready(),
		"A missing Gate must not consume the Counter Window.")
	await _destroy_fixture(fixture)


func _test_parent_rejections_preserve_counter() -> void:
	var invalid_fixture: Dictionary = await _create_fixture(true)
	var invalid_applier: BossCounterGatedDamageApplier = invalid_fixture.applier
	var invalid_window: BossCounterWindow = invalid_fixture.window
	var invalid_health: BossHealthComponent = invalid_fixture.health
	var invalid_combo: ComboSystem = invalid_fixture.combo
	_expect(invalid_window.activate(),
		"Counter must be ready before invalid-input rejection.")
	_expect(invalid_applier.resolve_and_apply_hit(0, 1.0) == 0,
		"Invalid target hit count must be rejected by the parent.")
	_expect(invalid_window.is_ready(),
		"Invalid Damage input must preserve the Counter Window.")
	_expect(invalid_health.get_current_health() == BOSS_MAX_HEALTH
		and invalid_combo.combo_count == 0,
		"Invalid Damage input must preserve health and Combo.")
	await _destroy_fixture(invalid_fixture)

	var unconfigured_fixture: Dictionary = await _create_fixture(
		true,
		true,
		false
	)
	var unconfigured_applier: BossCounterGatedDamageApplier = \
		unconfigured_fixture.applier
	var unconfigured_window: BossCounterWindow = unconfigured_fixture.window
	var unconfigured_health: BossHealthComponent = unconfigured_fixture.health
	var unconfigured_combo: ComboSystem = unconfigured_fixture.combo
	_expect(unconfigured_window.activate(),
		"Counter must be ready before unconfigured-Health rejection.")
	_expect(unconfigured_applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT
	) == 0, "An unconfigured Health component must reject Counter hits.")
	_expect(unconfigured_window.is_ready(),
		"An unconfigured Health rejection must preserve the Counter Window.")
	_expect(unconfigured_health.get_current_health() == 0
		and unconfigured_combo.combo_count == 0,
		"An unconfigured Health rejection must preserve Health and Combo.")
	await _destroy_fixture(unconfigured_fixture)

	var defeated_fixture: Dictionary = await _create_fixture(true)
	var defeated_applier: BossCounterGatedDamageApplier = defeated_fixture.applier
	var defeated_window: BossCounterWindow = defeated_fixture.window
	var defeated_health: BossHealthComponent = defeated_fixture.health
	var defeated_combo: ComboSystem = defeated_fixture.combo
	defeated_health.apply_damage(BOSS_MAX_HEALTH)
	_expect(defeated_window.activate(),
		"Counter must be ready before defeated-Health rejection.")
	_expect(defeated_applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT
	) == 0, "A defeated Boss must reject further Counter hits.")
	_expect(defeated_window.is_ready(),
		"A defeated Boss rejection must preserve the Counter Window.")
	_expect(defeated_combo.combo_count == 0,
		"A defeated Boss rejection must preserve Combo.")
	await _destroy_fixture(defeated_fixture)


func _test_missing_and_freed_window_fall_back_to_normal() -> void:
	var missing_fixture: Dictionary = await _create_fixture(true, false)
	var missing_applier: BossCounterGatedDamageApplier = missing_fixture.applier
	_expect(missing_applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT
	) == 400, "A missing Window must fall back to normal Gated damage.")
	await _destroy_fixture(missing_fixture)

	var freed_fixture: Dictionary = await _create_fixture(true)
	var freed_applier: BossCounterGatedDamageApplier = freed_fixture.applier
	var freed_window: BossCounterWindow = freed_fixture.window
	freed_window.free()
	_expect(not freed_applier.is_counter_window_bound(),
		"A freed Window must not remain bound.")
	_expect(freed_applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT
	) == 400, "A freed Window must fall back without invalid access.")
	await _destroy_fixture(freed_fixture)


func _test_forbidden_dependencies_and_formula_reuse() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_counter_gated_damage_applier.gd"
	)
	for forbidden_name: String in [
		"TeddyArmSweepAttack",
		"BossArmHitBallTracker",
		"BossParryCounterResolver",
		"Pinball",
		"Flipper",
		"BossAttackController",
		"Control",
		"CanvasLayer",
		"calculate_base_damage",
		"resolve_boss_hit",
		"apply_damage",
	]:
		_expect(not source.contains(forbidden_name),
			"Counter Gated Applier must not implement or depend on %s." % forbidden_name)


func _create_fixture(
	bind_gate: bool,
	bind_window: bool = true,
	configure_health: bool = true
) -> Dictionary:
	var combo := ComboSystem.new()
	var adapter := BossComboDamageAdapter.new()
	var health := BossHealthComponent.new()
	var applier := BossCounterGatedDamageApplier.new()
	var gate := BossDamageGate.new()
	var controller := BossAttackController.new()
	var attack := RecordingAttack.new()
	var pattern := BossAttackPattern.new()
	var window := BossCounterWindow.new()
	pattern.attack_id = &"counter_gated_damage_test"
	pattern.telegraph_duration = ATTACK_STATE_DURATION_SEC
	pattern.active_duration = ATTACK_STATE_DURATION_SEC
	pattern.recovery_duration = ATTACK_STATE_DURATION_SEC
	pattern.cooldown_duration = ATTACK_STATE_DURATION_SEC
	controller.pattern = pattern
	controller.attack = attack
	for node: Node in [
		combo,
		adapter,
		health,
		applier,
		gate,
		attack,
		controller,
		window,
	]:
		root.add_child(node)
	await process_frame
	_expect(adapter.bind_combo_system(combo),
		"Fixture Adapter must bind the real ComboSystem.")
	if configure_health:
		_expect(health.configure(BOSS_MAX_HEALTH),
			"Fixture Health must configure.")
	_expect(applier.bind(adapter, health),
		"Fixture parent Damage binding must succeed.")
	_expect(applier.configure_counter_multiplier(COUNTER_MULTIPLIER),
		"Fixture Counter multiplier must configure.")
	_expect(window.configure(WINDOW_DURATION_SEC),
		"Fixture Counter Window must configure.")
	if bind_gate:
		_expect(gate.bind_controller(controller),
			"Fixture Gate must bind the Controller.")
		_expect(applier.bind_damage_gate(gate),
			"Fixture Applier must bind the Gate.")
	if bind_window:
		_expect(applier.bind_counter_window(window),
			"Fixture Applier must bind the Counter Window.")
	return {
		&"combo": combo,
		&"adapter": adapter,
		&"health": health,
		&"applier": applier,
		&"gate": gate,
		&"attack": attack,
		&"controller": controller,
		&"window": window,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	for key: StringName in [
		&"controller",
		&"attack",
		&"gate",
		&"applier",
		&"window",
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
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BossCounterGatedDamageApplier tests passed.")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)
