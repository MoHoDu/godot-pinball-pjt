extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_initial_and_invalid_binding()
	_test_defeat_is_reported_once()
	_test_reset_allows_another_battle()
	_test_already_defeated_health_synchronizes()
	_test_unbind_ignores_health()
	_finish()


func _test_initial_and_invalid_binding() -> void:
	var controller := BossBattleCompletionController.new()
	var health := BossHealthComponent.new()
	_expect(not controller.is_completed() and not controller.is_bound(),
		"A new completion controller must be inactive and unbound.")
	_expect(not controller.bind_health(null), "Null Health must be rejected.")
	_expect(health.configure(100) and controller.bind_health(health),
		"Configured Health must bind successfully.")
	_expect(controller.is_bound() and not controller.is_completed(),
		"Healthy bound Health must remain an active battle.")
	controller.free()
	health.free()


func _test_defeat_is_reported_once() -> void:
	var controller := BossBattleCompletionController.new()
	var health := BossHealthComponent.new()
	var completions: Array[bool] = []
	health.configure(100)
	controller.battle_completed.connect(func() -> void:
		completions.append(true)
	)
	controller.bind_health(health)
	health.apply_damage(100)
	_expect(controller.is_completed(), "HP zero must complete the battle.")
	_expect(completions.size() == 1,
		"One defeat must emit battle_completed exactly once.")
	health.apply_damage(100)
	_expect(completions.size() == 1,
		"Damage after defeat must not repeat completion.")
	controller.free()
	health.free()


func _test_reset_allows_another_battle() -> void:
	var controller := BossBattleCompletionController.new()
	var health := BossHealthComponent.new()
	var completions: Array[bool] = []
	health.configure(80)
	controller.battle_completed.connect(func() -> void:
		completions.append(true)
	)
	controller.bind_health(health)
	health.apply_damage(80)
	controller.reset()
	_expect(not controller.is_completed(), "reset must restore active battle state.")
	_expect(health.reset_health(), "The fixture Health must reset independently.")
	health.apply_damage(80)
	_expect(controller.is_completed() and completions.size() == 2,
		"A reset lifecycle must be completable exactly once again.")
	controller.free()
	health.free()


func _test_already_defeated_health_synchronizes() -> void:
	var controller := BossBattleCompletionController.new()
	var health := BossHealthComponent.new()
	var completions: Array[bool] = []
	health.configure(20)
	health.apply_damage(20)
	controller.battle_completed.connect(func() -> void:
		completions.append(true)
	)
	_expect(controller.bind_health(health), "Defeated Health must still bind.")
	_expect(controller.is_completed() and completions.size() == 1,
		"Binding defeated Health must synchronize completion once.")
	controller.bind_health(health)
	_expect(completions.size() == 1, "Idempotent bind must not repeat completion.")
	controller.free()
	health.free()


func _test_unbind_ignores_health() -> void:
	var controller := BossBattleCompletionController.new()
	var health := BossHealthComponent.new()
	var completions: Array[bool] = []
	health.configure(40)
	controller.battle_completed.connect(func() -> void:
		completions.append(true)
	)
	controller.bind_health(health)
	controller.unbind_health()
	health.apply_damage(40)
	_expect(not controller.is_bound() and not controller.is_completed(),
		"Unbound Health defeat must be ignored.")
	_expect(completions.is_empty(), "Unbind must remove the defeated connection.")
	controller.free()
	health.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_battle_completion_controller_test")
		quit(0)
		return
	print(
		"FAIL: boss_battle_completion_controller_test (%d failures)"
		% _failures.size()
	)
	quit(1)
