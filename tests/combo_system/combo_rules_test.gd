extends SceneTree


const RULES_SCRIPT_PATH := "res://scripts/combo_system/combo_rules.gd"
const RULES_RESOURCE_PATH := "res://settings/combo/ComboRules.tres"
const EPSILON := 0.001

const TIER_NONE := 0
const TIER_NORMAL := 1
const TIER_SUPER := 2
const TIER_HYPER := 3
const TIER_ULTRA := 4


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var rules_script := load(RULES_SCRIPT_PATH) as Script
	var default_rules := load(RULES_RESOURCE_PATH) as Resource
	_expect(rules_script != null, "콤보 계산 규칙 스크립트가 필요하다.")
	_expect(default_rules != null, "콤보 공용 설정 리소스가 필요하다.")
	if rules_script == null or default_rules == null:
		_finish()
		return

	_test_default_contract(default_rules)
	_test_tier_boundaries(default_rules)
	_test_score_calculation(default_rules)
	_test_damage_calculation(default_rules)
	_test_base_damage_calculation(default_rules)
	_finish()


func _test_default_contract(rules: Resource) -> void:
	_expect_float(float(rules.get(&"hold_time")), 3.0, \
		"기본 콤보 유지 시간은 3초여야 한다.")
	_expect(int(rules.get(&"super_start_count")) == 11, \
		"Super 단계는 11콤보부터 시작해야 한다.")
	_expect(int(rules.get(&"hyper_start_count")) == 21, \
		"Hyper 단계는 21콤보부터 시작해야 한다.")
	_expect(int(rules.get(&"ultra_start_count")) == 36, \
		"Ultra 단계는 36콤보부터 시작해야 한다.")


func _test_tier_boundaries(rules: Resource) -> void:
	var cases := {
		0: TIER_NONE,
		1: TIER_NORMAL,
		10: TIER_NORMAL,
		11: TIER_SUPER,
		20: TIER_SUPER,
		21: TIER_HYPER,
		35: TIER_HYPER,
		36: TIER_ULTRA,
		100: TIER_ULTRA,
	}
	for combo_count: int in cases:
		_expect(int(rules.call(&"get_tier", combo_count)) == cases[combo_count], \
			"%d콤보의 단계가 설계 경계값과 일치해야 한다." % combo_count)


func _test_score_calculation(rules: Resource) -> void:
	var cases := {
		0: 0,
		1: 100,
		10: 1000,
		11: 5500,
		20: 10000,
		21: 21000,
		35: 35000,
		36: 72000,
	}
	for combo_count: int in cases:
		var actual := int(rules.call(
			&"calculate_score",
			100,
			float(combo_count),
			combo_count
		))
		_expect(actual == cases[combo_count], \
			"%d콤보 종료 점수는 단계별 배율을 적용해야 한다." % combo_count)

	_expect(int(rules.call(&"calculate_score", 100, 2.5, 11)) == 1250, \
		"유효 타격 가중치 합계와 종료 등급 배율을 함께 적용해야 한다.")


func _test_damage_calculation(rules: Resource) -> void:
	var cases := {
		1: 100,
		10: 123,
		11: 156,
		20: 184,
		21: 240,
		35: 296,
		36: 375,
		40: 395,
		80: 395,
	}
	for combo_count: int in cases:
		var actual := int(rules.call(&"calculate_damage", 100.0, combo_count))
		_expect(actual == cases[combo_count], \
			"%d콤보 피해는 횟수·단계 배율과 40회 상한을 적용해야 한다." \
			% combo_count)


func _test_base_damage_calculation(rules: Resource) -> void:
	_expect_float(float(rules.call(
		&"calculate_base_damage",
		10000.0,
		100,
		1.25
	)), 125.0, "기본 피해는 보스 체력/목표 타격 횟수에 공 무게 계수를 곱해야 한다.")
	_expect_float(float(rules.call(
		&"calculate_base_damage",
		10000.0,
		0,
		1.0
	)), 0.0, "목표 타격 횟수가 0이면 기본 피해도 0이어야 한다.")


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_rules_test")
		quit(0)
		return
	print("FAIL: combo_rules_test (%d failures)" % _failures.size())
	quit(1)
