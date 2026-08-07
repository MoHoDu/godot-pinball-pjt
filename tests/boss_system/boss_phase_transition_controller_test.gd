extends SceneTree


const MAX_HEALTH: int = 12000
const PHASE_2_THRESHOLD: int = 6000


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_state_and_configuration()
	_test_exact_threshold_and_single_emission()
	_test_threshold_skip()
	_test_already_low_health_bind_policy()
	_test_lethal_damage_does_not_enter_phase_2()
	_test_reset_and_second_transition()
	_test_unbind_ignores_health_changes()
	_test_binding_contract()
	_test_responsibility_boundaries()
	_finish()


func _test_initial_state_and_configuration() -> void:
	var controller := BossPhaseTransitionController.new()
	var health := BossHealthComponent.new()
	_expect(not controller.is_phase_2(), "A new Controller must start in Phase 1.")
	_expect(not controller.configure_phase_2_threshold(0),
		"A zero threshold must be rejected.")
	_expect(not controller.configure_phase_2_threshold(-1),
		"A negative threshold must be rejected.")
	_expect(not controller.bind_health(null), "A null Health must be rejected.")
	_expect(controller.configure_phase_2_threshold(PHASE_2_THRESHOLD),
		"A positive threshold must configure the Controller.")
	_expect(health.configure(MAX_HEALTH), "Health fixture must configure.")
	_expect(controller.bind_health(health), "A live Health must bind.")
	_expect(not controller.is_phase_2(),
		"Full Health above threshold must remain in Phase 1.")
	controller.free()
	health.free()


func _test_exact_threshold_and_single_emission() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var events: Array[int] = []
	controller.phase_2_entered.connect(func(current_hp: int) -> void:
		events.append(current_hp)
	)
	_expect(not controller.configure_phase_2_threshold(0),
		"Invalid reconfiguration must be rejected.")

	health.apply_damage(5999)
	_expect(health.get_current_health() == 6001,
		"The first hit must stop above threshold.")
	_expect(not controller.is_phase_2() and events.is_empty(),
		"Damage above threshold must preserve Phase 1.")
	health.apply_damage(1)
	_expect(health.get_current_health() == PHASE_2_THRESHOLD,
		"The next hit must land exactly on threshold.")
	_expect(controller.is_phase_2(),
		"Health exactly at threshold must enter Phase 2.")
	_expect(events == [PHASE_2_THRESHOLD],
		"Exact threshold crossing must emit the current HP once.")

	health.apply_damage(500)
	health.apply_damage(500)
	_expect(events == [PHASE_2_THRESHOLD],
		"Further Phase 2 damage must not repeat the signal.")
	_destroy_fixture(fixture)


func _test_threshold_skip() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var events: Array[int] = []
	controller.phase_2_entered.connect(func(current_hp: int) -> void:
		events.append(current_hp)
	)

	health.apply_damage(5500)
	_expect(health.get_current_health() == 6500,
		"Skip fixture must begin immediately above threshold.")
	health.apply_damage(1000)
	_expect(controller.is_phase_2(),
		"A 6500 to 5500 skip must enter Phase 2.")
	_expect(events == [5500],
		"Threshold skip must emit the actual post-hit HP once.")
	_destroy_fixture(fixture)


func _test_already_low_health_bind_policy() -> void:
	var controller := BossPhaseTransitionController.new()
	var health := BossHealthComponent.new()
	health.configure(MAX_HEALTH)
	health.apply_damage(6500)
	var events: Array[int] = []
	controller.phase_2_entered.connect(func(current_hp: int) -> void:
		events.append(current_hp)
	)
	controller.configure_phase_2_threshold(PHASE_2_THRESHOLD)

	_expect(controller.bind_health(health),
		"An already-low live Health must bind.")
	_expect(controller.is_phase_2(),
		"Binding at 5500 HP must synchronize immediately to Phase 2.")
	_expect(events == [5500],
		"Immediate low-Health synchronization must emit exactly once.")
	_expect(controller.bind_health(health),
		"Binding the same Health again must be idempotent.")
	_expect(events == [5500],
		"Idempotent rebind must not repeat Phase 2 entry.")
	controller.free()
	health.free()


func _test_lethal_damage_does_not_enter_phase_2() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var signal_count: Array[int] = [0]
	controller.phase_2_entered.connect(func(_current_hp: int) -> void:
		signal_count[0] += 1
	)
	health.apply_damage(5500)
	health.apply_damage(6500)
	_expect(health.is_defeated(), "The lethal fixture must be defeated.")
	_expect(not controller.is_phase_2(),
		"Lethal damage must not enter Phase 2 before death.")
	_expect(signal_count[0] == 0,
		"Lethal threshold crossing must not emit Phase 2 entry.")
	_destroy_fixture(fixture)

	var defeated_health := BossHealthComponent.new()
	defeated_health.configure(MAX_HEALTH)
	defeated_health.apply_damage(MAX_HEALTH)
	var bind_controller := BossPhaseTransitionController.new()
	bind_controller.configure_phase_2_threshold(PHASE_2_THRESHOLD)
	var bind_signal_count: Array[int] = [0]
	bind_controller.phase_2_entered.connect(func(_current_hp: int) -> void:
		bind_signal_count[0] += 1
	)
	_expect(bind_controller.bind_health(defeated_health),
		"A defeated Health reference may bind safely.")
	_expect(not bind_controller.is_phase_2() and bind_signal_count[0] == 0,
		"Binding defeated Health must not enter Phase 2.")
	bind_controller.free()
	defeated_health.free()


func _test_reset_and_second_transition() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var events: Array[int] = []
	controller.phase_2_entered.connect(func(current_hp: int) -> void:
		events.append(current_hp)
	)
	health.apply_damage(PHASE_2_THRESHOLD)
	_expect(controller.is_phase_2() and events.size() == 1,
		"The first lifecycle must enter Phase 2.")
	var health_before_reset: int = health.get_current_health()
	controller.reset()
	_expect(not controller.is_phase_2(), "Reset must restore Phase 1.")
	_expect(health.get_current_health() == health_before_reset,
		"Controller reset must not change Health.")
	_expect(events.size() == 1, "Reset must not emit a Phase signal.")

	health.reset_health()
	health.apply_damage(PHASE_2_THRESHOLD)
	_expect(controller.is_phase_2(),
		"A reset Health lifecycle may enter Phase 2 again.")
	_expect(events == [PHASE_2_THRESHOLD, PHASE_2_THRESHOLD],
		"Reset must permit exactly one entry in the next lifecycle.")
	_destroy_fixture(fixture)


func _test_unbind_ignores_health_changes() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var signal_count: Array[int] = [0]
	controller.phase_2_entered.connect(func(_current_hp: int) -> void:
		signal_count[0] += 1
	)
	controller.unbind_health()
	health.apply_damage(PHASE_2_THRESHOLD)
	_expect(not controller.is_phase_2(),
		"Unbound Health changes must not change Phase state.")
	_expect(signal_count[0] == 0,
		"Unbound Health changes must not emit Phase entry.")
	controller.unbind_health()
	_destroy_fixture(fixture)


func _test_binding_contract() -> void:
	var fixture: Dictionary = _create_fixture()
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	var original_connection_count: int = _count_connections_to(
		health,
		controller
	)
	_expect(original_connection_count == 1,
		"A valid Health binding must create one connection.")
	_expect(controller.bind_health(health),
		"Same-Health rebind must succeed.")
	_expect(_count_connections_to(health, controller) == 1,
		"Same-Health rebind must not duplicate connections.")

	var invalid_health := BossHealthComponent.new()
	invalid_health.free()
	_expect(not controller.bind_health(invalid_health),
		"A freed replacement Health must be rejected.")
	_expect(_count_connections_to(health, controller) == 1,
		"Failed replacement must preserve the existing binding.")
	health.apply_damage(PHASE_2_THRESHOLD)
	_expect(controller.is_phase_2(),
		"The preserved Health binding must remain functional.")
	_destroy_fixture(fixture)


func _test_responsibility_boundaries() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_phase_transition_controller.gd"
	)
	for forbidden_name: String in [
		"BossDamageApplier",
		"BossAttackController",
		"BossPhase1AttackScheduler",
		"BossCounterWindow",
		"BossDamageGate",
		"ComboSystem",
		"Pinball",
		"CanvasItem",
		"Label",
		"6000",
		"12000",
	]:
		_expect(not source.contains(forbidden_name),
			"Phase Controller must not depend on or hardcode: %s" % forbidden_name)


func _create_fixture() -> Dictionary:
	var controller := BossPhaseTransitionController.new()
	var health := BossHealthComponent.new()
	health.configure(MAX_HEALTH)
	controller.configure_phase_2_threshold(PHASE_2_THRESHOLD)
	controller.bind_health(health)
	return {
		&"controller": controller,
		&"health": health,
	}


func _destroy_fixture(fixture: Dictionary) -> void:
	var controller: BossPhaseTransitionController = fixture.controller
	var health: BossHealthComponent = fixture.health
	if is_instance_valid(controller):
		controller.unbind_health()
		controller.free()
	if is_instance_valid(health):
		health.free()


func _count_connections_to(
	health: BossHealthComponent,
	target: Object
) -> int:
	var count: int = 0
	for connection: Dictionary in health.health_changed.get_connections():
		var callback: Callable = connection.get(&"callable", Callable())
		if callback.is_valid() and callback.get_object() == target:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_phase_transition_controller_test")
		quit(0)
		return
	print(
		"FAIL: boss_phase_transition_controller_test (%d failures)"
		% _failures.size()
	)
	quit(1)
