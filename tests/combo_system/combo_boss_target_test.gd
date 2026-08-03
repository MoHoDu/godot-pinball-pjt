extends SceneTree


const COMBO_RULES_PATH := "res://scripts/combo_system/combo_rules.gd"
const COMBO_SYSTEM_PATH := "res://scripts/combo_system/combo_system.gd"
const BALL_STATS_PATH := "res://scripts/ball_base_system/pinball_stats.gd"
const BOSS_SETTINGS_PATH := "res://scripts/combo_system/combo_boss_settings.gd"
const BOSS_TARGET_PATH := "res://scripts/combo_system/combo_boss_target.gd"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var rules_script := load(COMBO_RULES_PATH) as Script
	var combo_script := load(COMBO_SYSTEM_PATH) as Script
	var ball_stats_script := load(BALL_STATS_PATH) as Script
	var settings_script := load(BOSS_SETTINGS_PATH) as Script
	var target_script := load(BOSS_TARGET_PATH) as Script
	_expect(_can_instantiate(rules_script), "콤보 규칙을 인스턴스화할 수 있어야 한다.")
	_expect(_can_instantiate(combo_script), "콤보 시스템을 인스턴스화할 수 있어야 한다.")
	_expect(_can_instantiate(ball_stats_script), "공 설정을 인스턴스화할 수 있어야 한다.")
	_expect(_can_instantiate(settings_script), "보스 설정을 인스턴스화할 수 있어야 한다.")
	_expect(_can_instantiate(target_script), "보스 타격 수신기를 인스턴스화할 수 있어야 한다.")
	if not _can_instantiate(rules_script) \
			or not _can_instantiate(combo_script) \
			or not _can_instantiate(ball_stats_script) \
			or not _can_instantiate(settings_script) \
			or not _can_instantiate(target_script):
		_finish()
		return

	_test_settings_clamp(settings_script)
	await _test_hit_order_weight_and_deduplication(
		combo_script, ball_stats_script, settings_script, target_script
	)
	await _test_ultra_damage_and_cap(
		rules_script, combo_script, settings_script, target_script
	)
	await _test_defeat_and_reset(combo_script, settings_script, target_script)
	_finish()


func _test_settings_clamp(settings_script: Script) -> void:
	var settings := settings_script.new() as Resource
	settings.set(&"max_health", 0)
	settings.set(&"target_hit_count", 0)
	_expect(int(settings.get(&"max_health")) == 1, \
		"보스 최대 체력은 최소 1이어야 한다.")
	_expect(int(settings.get(&"target_hit_count")) == 1, \
		"목표 타격 횟수는 최소 1이어야 한다.")


func _test_hit_order_weight_and_deduplication(
	combo_script: Script,
	ball_stats_script: Script,
	settings_script: Script,
	target_script: Script
) -> void:
	var fixture := await _create_fixture(
		combo_script, settings_script, target_script, 1000, 10
	)
	var combo: Node = fixture.combo
	var target: Node = fixture.target
	var ball_stats := ball_stats_script.new() as Resource
	ball_stats.set(&"mass", 1.0)
	_expect(int(target.call(&"register_ball_contact", 10, ball_stats)) == 100, \
		"첫 타격은 증가된 1콤보 기준으로 기본 피해를 적용해야 한다.")
	_expect(int(combo.get(&"combo_count")) == 1, \
		"보스 유효 타격은 피해 계산 전에 콤보를 증가시켜야 한다.")
	_expect(float(combo.get(&"total_score_weight")) == 0.0, \
		"보스 타격은 일반 웨이브 점수 가중치를 주면 안 된다.")
	_expect(int(target.call(&"register_contact", 10, 1.0)) == 0, \
		"같은 보스 접촉은 중복 피해를 주면 안 된다.")
	_expect(int(combo.get(&"combo_count")) == 1, \
		"중복 보스 접촉은 콤보를 증가시키면 안 된다.")
	_expect(bool(target.call(&"release_contact", 10)), \
		"보스 접촉 분리를 기록할 수 있어야 한다.")
	ball_stats.set(&"mass", 2.0)
	_expect(int(target.call(&"register_ball_contact", 10, ball_stats)) == 205, \
		"재접촉은 PinballStats.mass와 증가된 2콤보 계수를 적용해야 한다.")
	_expect(int(target.get(&"current_health")) == 695, \
		"적용 피해만큼 보스 체력이 감소해야 한다.")
	_expect(int(combo.get(&"total_score")) == 0, \
		"보스 타격만으로 일반 웨이브 점수가 생기면 안 된다.")
	await _destroy_fixture(fixture)


func _test_ultra_damage_and_cap(
	rules_script: Script,
	combo_script: Script,
	settings_script: Script,
	target_script: Script
) -> void:
	var fixture := await _create_fixture(
		combo_script, settings_script, target_script, 1000, 100
	)
	var combo: Node = fixture.combo
	var target: Node = fixture.target
	var rules := rules_script.new() as Resource
	rules.set(&"super_start_count", 2)
	rules.set(&"hyper_start_count", 3)
	rules.set(&"ultra_start_count", 4)
	rules.set(&"normal_damage_multiplier", 1.0)
	rules.set(&"super_damage_multiplier", 1.25)
	rules.set(&"hyper_damage_multiplier", 1.6)
	rules.set(&"ultra_damage_multiplier", 2.0)
	rules.set(&"damage_growth_per_hit", 0.1)
	rules.set(&"damage_combo_cap", 4)
	combo.set(&"rules", rules)

	var damages: Array[int] = []
	for contact_id in range(1, 7):
		damages.append(int(target.call(&"register_contact", contact_id, 1.0)))
	_expect(damages[3] == 26, \
		"Ultra 진입 타격은 증가된 4콤보 계수와 2배 단계 배율을 적용해야 한다.")
	_expect(damages[4] == 26 and damages[5] == 26, \
		"피해 횟수 계수는 설정한 4콤보에서 더 증가하면 안 된다.")
	_expect(int(combo.get(&"combo_count")) == 6, \
		"피해 계수 상한 이후에도 실제 콤보 횟수는 증가해야 한다.")
	await _destroy_fixture(fixture)


func _test_defeat_and_reset(
	combo_script: Script,
	settings_script: Script,
	target_script: Script
) -> void:
	var fixture := await _create_fixture(
		combo_script, settings_script, target_script, 100, 1
	)
	var combo: Node = fixture.combo
	var target: Node = fixture.target
	var defeated_count := {&"value": 0}
	target.defeated.connect(func() -> void:
		defeated_count.value += 1
	)
	_expect(int(target.call(&"register_contact", 1, 2.0)) == 100, \
		"남은 체력보다 큰 피해는 실제 남은 체력만 적용해야 한다.")
	_expect(bool(target.get(&"is_defeated")), \
		"체력이 0이면 처치 상태여야 한다.")
	_expect(int(defeated_count.value) == 1, \
		"처치 신호는 한 번만 보내야 한다.")
	_expect(int(target.call(&"register_contact", 2, 1.0)) == 0, \
		"처치된 보스는 추가 피해와 콤보를 받으면 안 된다.")
	_expect(int(combo.get(&"combo_count")) == 1, \
		"처치 후 접촉은 콤보를 증가시키면 안 된다.")
	target.call(&"reset_encounter")
	_expect(int(target.get(&"current_health")) == 100, \
		"보스 재시도는 체력을 최대로 복원해야 한다.")
	_expect(not bool(target.get(&"is_defeated")), \
		"보스 재시도는 처치 상태를 해제해야 한다.")
	_expect(int(target.call(&"register_contact", 1, 1.0)) > 0, \
		"재시도 후 기존 접촉 ID도 새 타격으로 받을 수 있어야 한다.")
	await _destroy_fixture(fixture)


func _create_fixture(
	combo_script: Script,
	settings_script: Script,
	target_script: Script,
	health: int,
	target_hits: int
) -> Dictionary:
	var combo := combo_script.new() as Node
	var target := target_script.new() as Node
	var settings := settings_script.new() as Resource
	settings.set(&"max_health", health)
	settings.set(&"target_hit_count", target_hits)
	root.add_child(combo)
	root.add_child(target)
	await process_frame
	_expect(bool(target.call(&"bind_combo_system", combo)), \
		"보스 타격 수신기가 콤보 시스템에 연결되어야 한다.")
	_expect(bool(target.call(&"configure_boss", settings)), \
		"보스 설정을 적용할 수 있어야 한다.")
	return {&"combo": combo, &"target": target, &"settings": settings}


func _destroy_fixture(fixture: Dictionary) -> void:
	(fixture.target as Node).queue_free()
	(fixture.combo as Node).queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _can_instantiate(script: Script) -> bool:
	return script != null and script.can_instantiate()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_boss_target_test")
		quit(0)
		return
	print("FAIL: combo_boss_target_test (%d failures)" % _failures.size())
	quit(1)
