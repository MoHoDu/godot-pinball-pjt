extends SceneTree


const BOSS_MAX_HEALTH: int = 12000
const TARGET_VALID_HIT_COUNT: int = 30
const COUNTER_MULTIPLIER: float = 1.35


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_unbound_state()
	_test_unbound_hit_is_ignored()
	_test_binding_and_failed_binding_preserves_reference()
	_test_unbind()
	_test_freed_combo_system_is_rejected()
	_test_first_hit_damage()
	_test_ball_weight_multiplier()
	_test_tier_damage(11, 625, "Super")
	_test_tier_damage(21, 960, "Hyper")
	_test_tier_damage(36, 1500, "Ultra")
	_test_tier_damage(40, 1580, "40 combo cap")
	_test_tier_damage(41, 1580, "post-cap")
	_test_counter_damage_and_combo_signal()
	_test_normal_hit_ignores_counter_multiplier()
	_test_counter_can_be_applied_repeatedly()
	_test_return_value_matches_adapter_signal()
	_test_invalid_integer_inputs()
	_test_invalid_ball_weight_multipliers()
	_test_invalid_counter_multipliers()
	_test_normal_hit_ignores_invalid_counter_multipliers()
	_test_invalid_input_has_no_side_effects()
	_test_boss_hit_keeps_score_weight_zero()
	_test_valid_zero_damage_still_resolves()
	_finish()


func _test_initial_unbound_state() -> void:
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	_expect(not adapter.is_bound(), "A new adapter must be unbound.")
	adapter.free()


func _test_unbound_hit_is_ignored() -> void:
	var combo_system: ComboSystem = ComboSystem.new()
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	root.add_child(combo_system)
	root.add_child(adapter)
	var combo_signal_count: Array[int] = [0]
	var adapter_signal_count: Array[int] = [0]
	combo_system.boss_damage_calculated.connect(func(
		_damage: int,
		_combo_count: int,
		_tier: int
	) -> void:
		combo_signal_count[0] += 1
	)
	adapter.damage_resolved.connect(func(_damage: int, _counter: bool) -> void:
		adapter_signal_count[0] += 1
	)

	var damage: int = adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT)
	_expect(damage == 0, "An unbound hit must return 0.")
	_expect(combo_system.combo_count == 0, "An unbound hit must not increase combo.")
	_expect(combo_signal_count[0] == 0 and adapter_signal_count[0] == 0,
		"An unbound hit must not emit damage signals.")
	_destroy_nodes(adapter, combo_system)


func _test_binding_and_failed_binding_preserves_reference() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	_expect(adapter.is_bound(), "A valid ComboSystem must bind successfully.")
	_expect(not adapter.bind_combo_system(null), "A null ComboSystem must be rejected.")
	_expect(adapter.is_bound(), "Failed binding must preserve the valid existing binding.")
	_expect(adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT) == 400,
		"The preserved binding must remain usable after a failed bind.")
	_expect(combo_system.combo_count == 1,
		"The preserved ComboSystem must receive the hit.")
	_destroy_fixture(fixture)


func _test_unbind() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	adapter.unbind_combo_system()
	_expect(not adapter.is_bound(), "unbind_combo_system must clear the binding.")
	_expect(adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT) == 0,
		"A hit after unbind must return 0.")
	_expect(combo_system.combo_count == 0,
		"A hit after unbind must not modify the former ComboSystem.")
	_destroy_fixture(fixture)


func _test_freed_combo_system_is_rejected() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	combo_system.free()
	_expect(not adapter.is_bound(), "A freed ComboSystem must not remain bound.")
	_expect(adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT) == 0,
		"A hit with a freed ComboSystem must be rejected safely.")
	adapter.free()


func _test_first_hit_damage() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH,
		TARGET_VALID_HIT_COUNT,
		1.0
	)
	_expect(damage == 400, "The first standard hit must deal 400 damage.")
	_expect(combo_system.combo_count == 1,
		"A valid boss hit must increase combo before damage calculation.")
	_destroy_fixture(fixture)


func _test_ball_weight_multiplier() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH,
		TARGET_VALID_HIT_COUNT,
		2.0
	)
	_expect(damage == 800, "A 2.0 ball weight multiplier must double first-hit damage.")
	_destroy_fixture(fixture)


func _test_tier_damage(
	hit_number: int,
	expected_damage: int,
	tier_label: String
) -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	_register_combo_hits(combo_system, hit_number - 1)
	var damage: int = adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT)
	_expect(damage == expected_damage,
		"The %s hit must deal %d damage." % [tier_label, expected_damage])
	_expect(combo_system.combo_count == hit_number,
		"The resolved hit must become combo %d." % hit_number)
	_destroy_fixture(fixture)


func _test_counter_damage_and_combo_signal() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var combo_damages: Array[int] = []
	var combo_counts: Array[int] = []
	var adapter_damages: Array[int] = []
	var adapter_counter_flags: Array[bool] = []
	combo_system.boss_damage_calculated.connect(func(
		damage: int,
		combo_count: int,
		_tier: int
	) -> void:
		combo_damages.append(damage)
		combo_counts.append(combo_count)
	)
	adapter.damage_resolved.connect(func(damage: int, was_counter: bool) -> void:
		adapter_damages.append(damage)
		adapter_counter_flags.append(was_counter)
	)

	var damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH,
		TARGET_VALID_HIT_COUNT,
		1.0,
		true,
		COUNTER_MULTIPLIER
	)
	_expect(damage == 540, "The first counter hit must deal 540 damage.")
	_expect(combo_damages == [540] and combo_counts == [1],
		"ComboSystem must emit counter-adjusted damage for the increased combo.")
	_expect(adapter_damages == [540] and adapter_counter_flags == [true],
		"The adapter must emit the returned counter damage with was_counter true.")
	_destroy_fixture(fixture)


func _test_normal_hit_ignores_counter_multiplier() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH,
		TARGET_VALID_HIT_COUNT,
		1.0,
		false,
		COUNTER_MULTIPLIER
	)
	_expect(damage == 400,
		"A normal hit must ignore the supplied counter multiplier.")
	_destroy_fixture(fixture)


func _test_counter_can_be_applied_repeatedly() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var counter_flags: Array[bool] = []
	adapter.damage_resolved.connect(func(_damage: int, was_counter: bool) -> void:
		counter_flags.append(was_counter)
	)

	var first_damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT, 1.0, true, COUNTER_MULTIPLIER
	)
	var second_damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT, 1.0, true, COUNTER_MULTIPLIER
	)
	_expect(first_damage > 0 and second_damage > 0,
		"Repeated counter inputs must both resolve damage.")
	_expect(combo_system.combo_count == 2 and counter_flags == [true, true],
		"The adapter must not consume counter state between calls.")
	_destroy_fixture(fixture)


func _test_return_value_matches_adapter_signal() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var signal_damages: Array[int] = []
	var signal_counters: Array[bool] = []
	adapter.damage_resolved.connect(func(damage: int, was_counter: bool) -> void:
		signal_damages.append(damage)
		signal_counters.append(was_counter)
	)

	var returned_damage: int = adapter.resolve_boss_hit(
		BOSS_MAX_HEALTH,
		TARGET_VALID_HIT_COUNT
	)
	_expect(signal_damages == [returned_damage],
		"damage_resolved must match the synchronous return value.")
	_expect(signal_counters == [false],
		"damage_resolved must report was_counter false for a normal hit.")
	_destroy_fixture(fixture)


func _test_invalid_integer_inputs() -> void:
	for invalid_health: int in [0, -1]:
		_assert_invalid_hit(invalid_health, TARGET_VALID_HIT_COUNT, 1.0, false, 1.0)
	for invalid_hit_count: int in [0, -1]:
		_assert_invalid_hit(BOSS_MAX_HEALTH, invalid_hit_count, 1.0, false, 1.0)


func _test_invalid_ball_weight_multipliers() -> void:
	var invalid_weights: Array[float] = [0.0, -1.0, NAN, INF, -INF]
	for invalid_weight: float in invalid_weights:
		_assert_invalid_hit(
			BOSS_MAX_HEALTH,
			TARGET_VALID_HIT_COUNT,
			invalid_weight,
			false,
			1.0
		)


func _test_invalid_counter_multipliers() -> void:
	var invalid_multipliers: Array[float] = [0.0, 0.99, -1.0, NAN, INF, -INF]
	for invalid_multiplier: float in invalid_multipliers:
		_assert_invalid_hit(
			BOSS_MAX_HEALTH,
			TARGET_VALID_HIT_COUNT,
			1.0,
			true,
			invalid_multiplier
		)


func _test_normal_hit_ignores_invalid_counter_multipliers() -> void:
	var ignored_multipliers: Array[float] = [0.0, -1.0, NAN, INF, -INF]
	for ignored_multiplier: float in ignored_multipliers:
		var fixture: Dictionary = _create_fixture()
		var adapter: BossComboDamageAdapter = fixture.adapter
		var damage: int = adapter.resolve_boss_hit(
			BOSS_MAX_HEALTH,
			TARGET_VALID_HIT_COUNT,
			1.0,
			false,
			ignored_multiplier
		)
		_expect(damage == 400,
			"A normal hit must ignore an invalid counter multiplier.")
		_destroy_fixture(fixture)


func _test_invalid_input_has_no_side_effects() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var combo_changed_count: Array[int] = [0]
	var combo_damage_count: Array[int] = [0]
	var adapter_signal_count: Array[int] = [0]
	combo_system.combo_changed.connect(func(
		_combo_count: int,
		_tier: int,
		_time_remaining: float
	) -> void:
		combo_changed_count[0] += 1
	)
	combo_system.boss_damage_calculated.connect(func(
		_damage: int,
		_combo_count: int,
		_tier: int
	) -> void:
		combo_damage_count[0] += 1
	)
	adapter.damage_resolved.connect(func(_damage: int, _counter: bool) -> void:
		adapter_signal_count[0] += 1
	)

	adapter.resolve_boss_hit(0, TARGET_VALID_HIT_COUNT)
	adapter.resolve_boss_hit(BOSS_MAX_HEALTH, 0)
	adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT, NAN)
	adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT, 1.0, true, 0.5)
	_expect(combo_system.combo_count == 0,
		"Invalid inputs must not increase combo.")
	_expect(
		combo_changed_count[0] == 0
		and combo_damage_count[0] == 0
		and adapter_signal_count[0] == 0,
		"Invalid inputs must not emit ComboSystem or adapter damage signals."
	)
	_destroy_fixture(fixture)


func _test_boss_hit_keeps_score_weight_zero() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT)
	_expect(is_equal_approx(combo_system.total_score_weight, 0.0),
		"A boss hit must not add normal score weight.")
	_destroy_fixture(fixture)


func _test_valid_zero_damage_still_resolves() -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var zero_damage_rules: ComboRules = ComboRules.new()
	zero_damage_rules.normal_damage_multiplier = 0.0
	combo_system.rules = zero_damage_rules
	var signal_damages: Array[int] = []
	var signal_counters: Array[bool] = []
	adapter.damage_resolved.connect(func(damage: int, was_counter: bool) -> void:
		signal_damages.append(damage)
		signal_counters.append(was_counter)
	)

	var damage: int = adapter.resolve_boss_hit(BOSS_MAX_HEALTH, TARGET_VALID_HIT_COUNT)
	_expect(damage == 0, "A valid hit may resolve to 0 damage under custom rules.")
	_expect(combo_system.combo_count == 1,
		"A valid zero-damage hit must still increase combo.")
	_expect(signal_damages == [0] and signal_counters == [false],
		"A valid zero-damage hit must still emit damage_resolved.")
	_destroy_fixture(fixture)


func _assert_invalid_hit(
	boss_max_health: int,
	target_valid_hit_count: int,
	ball_weight_multiplier: float,
	is_counter: bool,
	counter_multiplier: float
) -> void:
	var fixture: Dictionary = _create_fixture()
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	var combo_signal_count: Array[int] = [0]
	var adapter_signal_count: Array[int] = [0]
	combo_system.boss_damage_calculated.connect(func(
		_damage: int,
		_combo_count: int,
		_tier: int
	) -> void:
		combo_signal_count[0] += 1
	)
	adapter.damage_resolved.connect(func(_damage: int, _counter: bool) -> void:
		adapter_signal_count[0] += 1
	)

	var damage: int = adapter.resolve_boss_hit(
		boss_max_health,
		target_valid_hit_count,
		ball_weight_multiplier,
		is_counter,
		counter_multiplier
	)
	_expect(damage == 0, "Invalid boss hit input must return 0.")
	_expect(combo_system.combo_count == 0,
		"Invalid boss hit input must not increase combo.")
	_expect(combo_signal_count[0] == 0 and adapter_signal_count[0] == 0,
		"Invalid boss hit input must not emit damage signals.")
	_destroy_fixture(fixture)


func _register_combo_hits(combo_system: ComboSystem, hit_count: int) -> void:
	for _hit_index: int in hit_count:
		combo_system.register_hit(0.0)


func _create_fixture() -> Dictionary:
	var combo_system: ComboSystem = ComboSystem.new()
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	root.add_child(combo_system)
	root.add_child(adapter)
	_expect(adapter.bind_combo_system(combo_system),
		"A valid ComboSystem fixture must bind successfully.")
	return {
		&"adapter": adapter,
		&"combo_system": combo_system,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	var adapter: BossComboDamageAdapter = fixture.adapter
	var combo_system: ComboSystem = fixture.combo_system
	_destroy_nodes(adapter, combo_system)


func _destroy_nodes(
	adapter: BossComboDamageAdapter,
	combo_system: ComboSystem
) -> void:
	if is_instance_valid(adapter):
		adapter.free()
	if is_instance_valid(combo_system):
		combo_system.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_combo_damage_adapter_test")
		quit(0)
		return
	print("FAIL: boss_combo_damage_adapter_test (%d failures)" % _failures.size())
	quit(1)
