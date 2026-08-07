extends SceneTree


const APPLIER_SCRIPT_PATH: String = (
	"res://scripts/boss_system/boss_damage_applier.gd"
)
const STAGE1_MAX_HEALTH: int = 12000
const TARGET_VALID_HIT_COUNT: int = 30


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_unbound_state()
	_test_valid_bind_and_idempotent_rebind()
	_test_null_bind_rejection()
	_test_freed_instance_bind_rejection()
	_test_unbound_adapter_rejection()
	_test_failed_bind_preserves_existing_binding()
	_test_unbind_and_duplicate_unbind()
	_test_unconfigured_health_rejects_hit()
	_test_defeated_health_rejects_hit()
	_test_invalid_hit_inputs_have_no_side_effects()
	_test_regular_damage_and_signal_data()
	_test_calculated_and_applied_damage_are_distinct()
	_test_counter_forwarding()
	_test_weight_tier_damage_values()
	_test_each_successful_hit_increases_combo_once()
	_test_defeated_health_does_not_increase_combo()
	_test_no_ball_or_physics_mass_dependency()
	_finish()


func _test_initial_unbound_state() -> void:
	var applier: BossDamageApplier = BossDamageApplier.new()
	_expect(not applier.is_bound(), "A new applier must be unbound.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"An unbound applier must reject hits.")
	applier.free()


func _test_valid_bind_and_idempotent_rebind() -> void:
	var fixture: Dictionary = _create_fixture(false)
	var applier: BossDamageApplier = fixture.applier
	var adapter: BossComboDamageAdapter = fixture.adapter
	var health: BossHealthComponent = fixture.health
	_expect(applier.bind(adapter, health), "Valid dependencies must bind.")
	_expect(applier.is_bound(), "A successful bind must be observable.")
	_expect(applier.bind(adapter, health),
		"Binding the same dependencies again must be idempotent.")
	_destroy_fixture(fixture)


func _test_null_bind_rejection() -> void:
	var fixture: Dictionary = _create_fixture(false)
	var applier: BossDamageApplier = fixture.applier
	var adapter: BossComboDamageAdapter = fixture.adapter
	var health: BossHealthComponent = fixture.health
	_expect(not applier.bind(null, health), "A null adapter must be rejected.")
	_expect(not applier.bind(adapter, null), "A null health component must be rejected.")
	_expect(not applier.is_bound(), "Rejected initial binds must preserve unbound state.")
	_destroy_fixture(fixture)


func _test_freed_instance_bind_rejection() -> void:
	var combo_system: ComboSystem = ComboSystem.new()
	var freed_adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var live_health: BossHealthComponent = BossHealthComponent.new()
	var applier: BossDamageApplier = BossDamageApplier.new()
	root.add_child(combo_system)
	root.add_child(freed_adapter)
	root.add_child(live_health)
	root.add_child(applier)
	freed_adapter.bind_combo_system(combo_system)
	_expect(applier.bind(freed_adapter, live_health),
		"The live adapter fixture must bind before lifecycle loss.")
	freed_adapter.free()
	_expect(not applier.is_bound(),
		"A freed adapter instance must invalidate the binding safely.")

	var live_adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var freed_health: BossHealthComponent = BossHealthComponent.new()
	root.add_child(live_adapter)
	root.add_child(freed_health)
	live_adapter.bind_combo_system(combo_system)
	_expect(applier.bind(live_adapter, freed_health),
		"The live Health fixture must bind before lifecycle loss.")
	freed_health.free()
	_expect(not applier.is_bound(),
		"A freed Health instance must invalidate the binding safely.")
	_free_nodes([applier, live_adapter, live_health, combo_system])


func _test_unbound_adapter_rejection() -> void:
	var combo_system: ComboSystem = ComboSystem.new()
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var health: BossHealthComponent = BossHealthComponent.new()
	var applier: BossDamageApplier = BossDamageApplier.new()
	root.add_child(combo_system)
	root.add_child(adapter)
	root.add_child(health)
	root.add_child(applier)
	_expect(not applier.bind(adapter, health),
		"An adapter without a ComboSystem binding must be rejected.")
	_expect(not applier.is_bound(), "A rejected adapter must not create a binding.")
	_free_nodes([applier, health, adapter, combo_system])


func _test_failed_bind_preserves_existing_binding() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
	var original_health: BossHealthComponent = fixture.health
	var invalid_adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var replacement_health: BossHealthComponent = BossHealthComponent.new()
	root.add_child(invalid_adapter)
	root.add_child(replacement_health)
	replacement_health.configure(STAGE1_MAX_HEALTH)

	_expect(not applier.bind(invalid_adapter, replacement_health),
		"A failed replacement bind must be rejected.")
	_expect(applier.is_bound(),
		"A failed replacement bind must preserve the original binding.")
	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 400,
		"The preserved binding must remain usable.")
	_expect(original_health.get_current_health() == 11600,
		"The preserved health component must receive damage.")
	_expect(replacement_health.get_current_health() == STAGE1_MAX_HEALTH,
		"A rejected replacement health component must remain unchanged.")
	_free_nodes([replacement_health, invalid_adapter])
	_destroy_fixture(fixture)


func _test_unbind_and_duplicate_unbind() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
	var adapter: BossComboDamageAdapter = fixture.adapter
	var health: BossHealthComponent = fixture.health
	applier.unbind()
	_expect(not applier.is_bound(), "unbind must clear the applier binding.")
	_expect(adapter.is_bound(),
		"unbind must not clear the adapter's ComboSystem binding.")
	_expect(health.get_current_health() == STAGE1_MAX_HEALTH,
		"unbind must not reset or mutate health.")
	applier.unbind()
	_expect(not applier.is_bound(), "Duplicate unbind must be safe.")
	_destroy_fixture(fixture)


func _test_unconfigured_health_rejects_hit() -> void:
	var fixture: Dictionary = _create_fixture(true, false)
	var applier: BossDamageApplier = fixture.applier
	var combo_system: ComboSystem = fixture.combo_system
	var health: BossHealthComponent = fixture.health
	var signal_count: Array[int] = [0]
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_counter: bool
	) -> void:
		signal_count[0] += 1
	)

	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"An unconfigured health component must reject hits.")
	_expect(combo_system.combo_count == 0,
		"An unconfigured health component must not allow Combo registration.")
	_expect(health.get_current_health() == 0 and signal_count[0] == 0,
		"A rejected unconfigured hit must have no health or signal effects.")
	_destroy_fixture(fixture)


func _test_defeated_health_rejects_hit() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
	var combo_system: ComboSystem = fixture.combo_system
	var health: BossHealthComponent = fixture.health
	health.apply_damage(STAGE1_MAX_HEALTH)
	var signal_count: Array[int] = [0]
	applier.boss_hit_resolved.connect(func(
		_calculated: int,
		_applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_counter: bool
	) -> void:
		signal_count[0] += 1
	)

	_expect(applier.resolve_and_apply_hit(TARGET_VALID_HIT_COUNT) == 0,
		"A defeated health component must reject additional hits.")
	_expect(combo_system.combo_count == 0,
		"A hit after defeat must not increase Combo.")
	_expect(health.get_current_health() == 0 and signal_count[0] == 0,
		"A hit after defeat must not change health or emit a resolved signal.")
	_destroy_fixture(fixture)


func _test_invalid_hit_inputs_have_no_side_effects() -> void:
	var invalid_inputs: Array[Array] = [
		[0, 1.0, false, 1.0],
		[-1, 1.0, false, 1.0],
		[TARGET_VALID_HIT_COUNT, 0.0, false, 1.0],
		[TARGET_VALID_HIT_COUNT, -1.0, false, 1.0],
		[TARGET_VALID_HIT_COUNT, NAN, false, 1.0],
		[TARGET_VALID_HIT_COUNT, INF, false, 1.0],
		[TARGET_VALID_HIT_COUNT, -INF, false, 1.0],
		[TARGET_VALID_HIT_COUNT, 1.0, false, 0.0],
		[TARGET_VALID_HIT_COUNT, 1.0, false, -1.0],
		[TARGET_VALID_HIT_COUNT, 1.0, false, NAN],
		[TARGET_VALID_HIT_COUNT, 1.0, false, INF],
		[TARGET_VALID_HIT_COUNT, 1.0, false, -INF],
	]

	for input: Array in invalid_inputs:
		var fixture: Dictionary = _create_fixture(true)
		var applier: BossDamageApplier = fixture.applier
		var combo_system: ComboSystem = fixture.combo_system
		var health: BossHealthComponent = fixture.health
		var signal_count: Array[int] = [0]
		applier.boss_hit_resolved.connect(func(
			_calculated: int,
			_applied: int,
			_previous: int,
			_current: int,
			_maximum: int,
			_counter: bool
		) -> void:
			signal_count[0] += 1
		)
		var result: int = applier.resolve_and_apply_hit(
			int(input[0]),
			float(input[1]),
			bool(input[2]),
			float(input[3])
		)
		_expect(result == 0, "Invalid hit input must return 0.")
		_expect(combo_system.combo_count == 0,
			"Invalid hit input must not increase Combo.")
		_expect(health.get_current_health() == STAGE1_MAX_HEALTH,
			"Invalid hit input must not change health.")
		_expect(signal_count[0] == 0,
			"Invalid hit input must not emit boss_hit_resolved.")
		_destroy_fixture(fixture)


func _test_regular_damage_and_signal_data() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
	var combo_system: ComboSystem = fixture.combo_system
	var health: BossHealthComponent = fixture.health
	var events: Array[Dictionary] = []
	applier.boss_hit_resolved.connect(func(
		calculated: int,
		applied: int,
		previous: int,
		current: int,
		maximum: int,
		counter: bool
	) -> void:
		events.append({
			&"calculated": calculated,
			&"applied": applied,
			&"previous": previous,
			&"current": current,
			&"maximum": maximum,
			&"counter": counter,
		})
	)

	var returned_damage: int = applier.resolve_and_apply_hit(
		TARGET_VALID_HIT_COUNT,
		1.0
	)
	_expect(returned_damage == 400,
		"Normal weight must apply 400 damage on the first Stage 1 hit.")
	_expect(health.get_current_health() == 11600,
		"Regular damage must reduce current health.")
	_expect(combo_system.combo_count == 1,
		"A successful boss hit must increase Combo exactly once.")
	_expect(events == [{
		&"calculated": 400,
		&"applied": 400,
		&"previous": 12000,
		&"current": 11600,
		&"maximum": 12000,
		&"counter": false,
	}], "boss_hit_resolved must contain the complete hit result.")
	_destroy_fixture(fixture)


func _test_calculated_and_applied_damage_are_distinct() -> void:
	var fixture: Dictionary = _create_fixture(true, true, 100)
	var applier: BossDamageApplier = fixture.applier
	var health: BossHealthComponent = fixture.health
	var results: Array[Vector2i] = []
	applier.boss_hit_resolved.connect(func(
		calculated: int,
		applied: int,
		_previous: int,
		_current: int,
		_maximum: int,
		_counter: bool
	) -> void:
		results.append(Vector2i(calculated, applied))
	)

	var returned_damage: int = applier.resolve_and_apply_hit(1, 4.0)
	_expect(results == [Vector2i(400, 100)],
		"Calculated damage must remain distinct from health-clamped damage.")
	_expect(returned_damage == 100,
		"resolve_and_apply_hit must return applied damage, not calculated damage.")
	_expect(health.get_current_health() == 0,
		"Overkill damage must clamp health to zero.")
	_destroy_fixture(fixture)


func _test_counter_forwarding() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
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
	) == 540, "Counter inputs must be forwarded unchanged to the adapter.")
	_expect(counter_flags == [true],
		"boss_hit_resolved must preserve the counter flag.")
	_destroy_fixture(fixture)


func _test_weight_tier_damage_values() -> void:
	var expected_damage_by_weight: Dictionary = {
		0.90: 360,
		1.00: 400,
		1.15: 460,
		1.30: 520,
	}
	for weight: float in expected_damage_by_weight:
		var fixture: Dictionary = _create_fixture(true)
		var applier: BossDamageApplier = fixture.applier
		var combo_system: ComboSystem = fixture.combo_system
		var expected_damage: int = int(expected_damage_by_weight[weight])
		_expect(applier.resolve_and_apply_hit(
			TARGET_VALID_HIT_COUNT,
			weight
		) == expected_damage,
			"Weight %.2f must apply %d damage on the first hit." % [
				weight,
				expected_damage,
			]
		)
		_expect(combo_system.combo_count == 1,
			"Each isolated weight test must register exactly one Combo hit.")
		_destroy_fixture(fixture)


func _test_each_successful_hit_increases_combo_once() -> void:
	var fixture: Dictionary = _create_fixture(true)
	var applier: BossDamageApplier = fixture.applier
	var combo_system: ComboSystem = fixture.combo_system
	for expected_combo: int in range(1, 4):
		var applied: int = applier.resolve_and_apply_hit(
			TARGET_VALID_HIT_COUNT,
			0.80
		)
		_expect(applied > 0, "Each valid nonlethal hit must apply damage.")
		_expect(combo_system.combo_count == expected_combo,
			"Each successful hit must increase Combo exactly once.")
	_destroy_fixture(fixture)


func _test_defeated_health_does_not_increase_combo() -> void:
	var fixture: Dictionary = _create_fixture(true, true, 100)
	var applier: BossDamageApplier = fixture.applier
	var combo_system: ComboSystem = fixture.combo_system
	_expect(applier.resolve_and_apply_hit(1, 1.0) == 100,
		"The first lethal hit must apply the remaining health.")
	_expect(combo_system.combo_count == 1,
		"The lethal hit must register one Combo hit.")
	_expect(applier.resolve_and_apply_hit(1, 1.0) == 0,
		"A subsequent hit after defeat must be rejected.")
	_expect(combo_system.combo_count == 1,
		"A subsequent hit after defeat must not increase Combo.")
	_destroy_fixture(fixture)


func _test_no_ball_or_physics_mass_dependency() -> void:
	var source: String = FileAccess.get_file_as_string(APPLIER_SCRIPT_PATH)
	_expect(not source.is_empty(), "The applier source must be readable.")
	_expect(not source.contains("Pinball"),
		"BossDamageApplier must not reference Pinball or PinballStats.")
	_expect(not source.contains("mass"),
		"BossDamageApplier must not derive damage weight from physics mass.")


func _create_fixture(
	bind_applier: bool,
	configure_health: bool = true,
	max_health: int = STAGE1_MAX_HEALTH
) -> Dictionary:
	var combo_system: ComboSystem = ComboSystem.new()
	var adapter: BossComboDamageAdapter = BossComboDamageAdapter.new()
	var health: BossHealthComponent = BossHealthComponent.new()
	var applier: BossDamageApplier = BossDamageApplier.new()
	root.add_child(combo_system)
	root.add_child(adapter)
	root.add_child(health)
	root.add_child(applier)
	_expect(adapter.bind_combo_system(combo_system),
		"The fixture adapter must bind to the real ComboSystem.")
	if configure_health:
		_expect(health.configure(max_health),
			"The fixture health component must configure successfully.")
	if bind_applier:
		_expect(applier.bind(adapter, health),
			"The fixture applier must bind successfully.")
	return {
		&"combo_system": combo_system,
		&"adapter": adapter,
		&"health": health,
		&"applier": applier,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	_free_nodes([
		fixture.applier,
		fixture.health,
		fixture.adapter,
		fixture.combo_system,
	])


func _free_nodes(nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_damage_applier_test")
		quit(0)
		return
	print("FAIL: boss_damage_applier_test (%d failures)" % _failures.size())
	quit(1)
