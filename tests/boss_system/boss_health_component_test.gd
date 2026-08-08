extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_unconfigured_state()
	_test_valid_configuration()
	_test_invalid_configuration()
	_test_failed_configuration_preserves_state()
	_test_regular_damage()
	_test_damage_is_limited_to_remaining_health()
	_test_non_positive_damage_is_ignored()
	_test_damage_signal_data_and_order()
	_test_defeated_is_emitted_once()
	_test_damage_after_defeat_is_ignored()
	_test_reset_before_configuration_fails()
	_test_reset_after_defeat()
	_test_defeat_can_happen_again_after_reset()
	_test_health_ratios()
	_test_valid_reconfiguration()
	_test_getters_do_not_mutate_state()
	_finish()


func _test_initial_unconfigured_state() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	_expect(not component.is_configured(), "A new component must be unconfigured.")
	_expect(not component.is_defeated(), "An unconfigured component must not be defeated.")
	_expect(component.get_max_health() == 0, "Initial maximum health must be 0.")
	_expect(component.get_current_health() == 0, "Initial current health must be 0.")
	_expect(is_equal_approx(component.get_health_ratio(), 0.0),
		"An unconfigured component must report a 0.0 health ratio.")
	_expect(component.apply_damage(10) == 0,
		"An unconfigured component must ignore damage.")
	_expect(component.get_current_health() == 0,
		"Damage before configuration must preserve current health.")
	component.free()


func _test_valid_configuration() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	var health_events: Array[Vector2i] = []
	component.health_changed.connect(func(current: int, maximum: int) -> void:
		health_events.append(Vector2i(current, maximum))
	)

	_expect(component.configure(500), "A positive maximum health must be accepted.")
	_expect(component.is_configured(), "Successful configuration must mark the component configured.")
	_expect(component.get_max_health() == 500, "Configuration must store maximum health.")
	_expect(component.get_current_health() == 500, "Configuration must fill current health.")
	_expect(health_events == [Vector2i(500, 500)],
		"Successful initial configuration must emit the configured health once.")
	component.free()


func _test_invalid_configuration() -> void:
	for invalid_health: int in [0, -1]:
		var component: BossHealthComponent = BossHealthComponent.new()
		var signal_count: Array[int] = [0]
		component.health_changed.connect(func(_current: int, _maximum: int) -> void:
			signal_count[0] += 1
		)
		_expect(not component.configure(invalid_health),
			"A non-positive maximum health must be rejected.")
		_expect(not component.is_configured(),
			"Rejected initial configuration must leave the component unconfigured.")
		_expect(component.get_max_health() == 0 and component.get_current_health() == 0,
			"Rejected initial configuration must preserve the initial health state.")
		_expect(signal_count[0] == 0,
			"Rejected configuration must not emit health_changed.")
		component.free()


func _test_failed_configuration_preserves_state() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(300)
	component.apply_damage(125)
	var before: Dictionary = _snapshot(component)
	var signal_count: Array[int] = [0]
	component.health_changed.connect(func(_current: int, _maximum: int) -> void:
		signal_count[0] += 1
	)

	_expect(not component.configure(0), "Zero maximum health must be rejected after configuration.")
	_expect(not component.configure(-100), "Negative maximum health must be rejected after configuration.")
	_expect(_snapshot(component) == before,
		"Failed configuration must preserve every observable health value.")
	_expect(signal_count[0] == 0,
		"Failed reconfiguration must not emit health_changed.")
	component.free()


func _test_regular_damage() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(200)
	_expect(component.apply_damage(75) == 75, "Regular damage must return the applied amount.")
	_expect(component.get_current_health() == 125, "Regular damage must reduce current health.")
	_expect(not component.is_defeated(), "Remaining positive health must not be defeated.")
	component.free()


func _test_damage_is_limited_to_remaining_health() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(100)
	component.apply_damage(70)
	_expect(component.apply_damage(1000) == 30,
		"Damage above remaining health must return only the remaining health.")
	_expect(component.get_current_health() == 0,
		"Damage above remaining health must clamp current health to 0.")
	component.free()


func _test_non_positive_damage_is_ignored() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(100)
	var event_count: Array[int] = [0]
	component.damage_applied.connect(func(_damage: int, _current: int) -> void:
		event_count[0] += 1
	)
	component.health_changed.connect(func(_current: int, _maximum: int) -> void:
		event_count[0] += 1
	)
	component.defeated.connect(func() -> void:
		event_count[0] += 1
	)

	_expect(component.apply_damage(0) == 0, "Zero damage must be ignored.")
	_expect(component.apply_damage(-20) == 0, "Negative damage must be ignored.")
	_expect(component.get_current_health() == 100,
		"Non-positive damage must preserve current health.")
	_expect(event_count[0] == 0, "Non-positive damage must not emit signals.")
	component.free()


func _test_damage_signal_data_and_order() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(100)
	var events: Array[String] = []
	component.damage_applied.connect(func(applied: int, current: int) -> void:
		events.append("damage:%d:%d" % [applied, current])
	)
	component.health_changed.connect(func(current: int, maximum: int) -> void:
		events.append("health:%d:%d" % [current, maximum])
	)
	component.defeated.connect(func() -> void:
		events.append("defeated")
	)

	component.apply_damage(100)
	_expect(events == ["damage:100:0", "health:0:100", "defeated"],
		"Lethal damage signals must contain correct data and use the required order.")
	component.free()


func _test_defeated_is_emitted_once() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(50)
	var defeated_count: Array[int] = [0]
	component.defeated.connect(func() -> void:
		defeated_count[0] += 1
	)

	component.apply_damage(50)
	component.apply_damage(1)
	component.apply_damage(100)
	_expect(defeated_count[0] == 1,
		"Defeated must be emitted exactly once during one health lifecycle.")
	component.free()


func _test_damage_after_defeat_is_ignored() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(40)
	component.apply_damage(40)
	var events_after_defeat: Array[int] = [0]
	component.damage_applied.connect(func(_damage: int, _current: int) -> void:
		events_after_defeat[0] += 1
	)
	component.health_changed.connect(func(_current: int, _maximum: int) -> void:
		events_after_defeat[0] += 1
	)
	component.defeated.connect(func() -> void:
		events_after_defeat[0] += 1
	)

	_expect(component.apply_damage(10) == 0,
		"Damage after defeat must return 0.")
	_expect(component.get_current_health() == 0,
		"Damage after defeat must preserve zero current health.")
	_expect(events_after_defeat[0] == 0,
		"Damage after defeat must not emit any signal.")
	component.free()


func _test_reset_before_configuration_fails() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	var signal_count: Array[int] = [0]
	component.health_changed.connect(func(_current: int, _maximum: int) -> void:
		signal_count[0] += 1
	)
	_expect(not component.reset_health(), "Reset before configuration must fail.")
	_expect(not component.is_configured() and not component.is_defeated(),
		"Failed reset must preserve the initial state.")
	_expect(signal_count[0] == 0, "Failed reset must not emit health_changed.")
	component.free()


func _test_reset_after_defeat() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(80)
	component.apply_damage(80)
	var health_events: Array[Vector2i] = []
	component.health_changed.connect(func(current: int, maximum: int) -> void:
		health_events.append(Vector2i(current, maximum))
	)

	_expect(component.reset_health(), "Reset after defeat must succeed.")
	_expect(component.get_current_health() == 80,
		"Reset must restore maximum health.")
	_expect(not component.is_defeated(), "Reset must clear the defeated state.")
	_expect(health_events == [Vector2i(80, 80)],
		"Reset must emit health_changed when health is restored.")
	component.free()


func _test_defeat_can_happen_again_after_reset() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(25)
	var defeated_count: Array[int] = [0]
	component.defeated.connect(func() -> void:
		defeated_count[0] += 1
	)

	component.apply_damage(25)
	component.reset_health()
	component.apply_damage(25)
	_expect(defeated_count[0] == 2,
		"Reset must allow defeated to be emitted in the next health lifecycle.")
	component.free()


func _test_health_ratios() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(200)
	_expect(is_equal_approx(component.get_health_ratio(), 1.0),
		"Full health must report a 1.0 ratio.")
	component.apply_damage(50)
	_expect(is_equal_approx(component.get_health_ratio(), 0.75),
		"Partial health must report the current-to-maximum ratio.")
	component.apply_damage(150)
	_expect(is_equal_approx(component.get_health_ratio(), 0.0),
		"Zero health must report a 0.0 ratio.")
	component.free()


func _test_valid_reconfiguration() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(100)
	component.apply_damage(100)
	var health_events: Array[Vector2i] = []
	component.health_changed.connect(func(current: int, maximum: int) -> void:
		health_events.append(Vector2i(current, maximum))
	)

	_expect(component.configure(250), "A valid reconfiguration must succeed.")
	_expect(component.get_max_health() == 250 and component.get_current_health() == 250,
		"Reconfiguration must replace maximum health and refill current health.")
	_expect(not component.is_defeated(), "Reconfiguration must clear the defeated state.")
	_expect(health_events == [Vector2i(250, 250)],
		"Changed reconfiguration must emit health_changed once.")
	health_events.clear()
	_expect(component.configure(250), "Equivalent valid reconfiguration must succeed.")
	_expect(health_events.is_empty(),
		"Equivalent full-health reconfiguration must not emit health_changed.")
	component.free()


func _test_getters_do_not_mutate_state() -> void:
	var component: BossHealthComponent = BossHealthComponent.new()
	component.configure(300)
	component.apply_damage(125)
	var before: Dictionary = _snapshot(component)

	component.get_current_health()
	component.get_max_health()
	component.get_health_ratio()
	component.is_defeated()
	component.is_configured()

	_expect(_snapshot(component) == before,
		"Getters and ratio calculation must not mutate health state.")
	component.free()


func _snapshot(component: BossHealthComponent) -> Dictionary:
	return {
		&"configured": component.is_configured(),
		&"defeated": component.is_defeated(),
		&"maximum": component.get_max_health(),
		&"current": component.get_current_health(),
		&"ratio": component.get_health_ratio(),
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_health_component_test")
		quit(0)
		return
	print("FAIL: boss_health_component_test (%d failures)" % _failures.size())
	quit(1)
