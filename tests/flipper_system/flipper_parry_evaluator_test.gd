extends SceneTree


const EVALUATOR_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_parry_evaluator.gd"
const RULES_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_parry_rules.gd"
const EPSILON := 0.001
const GRADE_NONE := 0
const GRADE_NORMAL := 1
const GRADE_PERFECT := 2


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var evaluator_script := load(EVALUATOR_SCRIPT_PATH) as Script
	var rules_script := load(RULES_SCRIPT_PATH) as Script
	_expect(evaluator_script != null, "패링 타이밍 판정 전용 스크립트가 필요하다.")
	_expect(rules_script != null, "패링 판정용 공용 설정 스크립트가 필요하다.")
	if evaluator_script == null or rules_script == null:
		_finish()
		return

	var evaluator: RefCounted = evaluator_script.new() as RefCounted
	var rules := rules_script.new() as Resource
	rules.set(&"perfect_parry_window_time", 0.042)
	rules.set(&"normal_parry_window_time", 0.095)
	rules.set(&"perfect_parry_speed_multiplier", 1.18)
	rules.set(&"normal_parry_speed_multiplier", 1.08)

	_test_timing_boundaries(evaluator, rules)
	_test_speed_multipliers(evaluator, rules)
	_finish()


func _test_timing_boundaries(evaluator: RefCounted, rules: Resource) -> void:
	_expect(int(evaluator.call(&"evaluate", -0.001, rules)) == GRADE_NONE, \
		"입력 이전 시간은 패링으로 판정하면 안 된다.")
	_expect(int(evaluator.call(&"evaluate", 0.0, rules)) == GRADE_PERFECT, \
		"작동 직후 충돌은 정확 패링이어야 한다.")
	_expect(int(evaluator.call(&"evaluate", 0.042, rules)) == GRADE_PERFECT, \
		"정확 패링 경계값은 정확 패링에 포함되어야 한다.")
	_expect(int(evaluator.call(&"evaluate", 0.043, rules)) == GRADE_NORMAL, \
		"정확 패링 이후 일반 판정 시간 안의 충돌은 일반 패링이어야 한다.")
	_expect(int(evaluator.call(&"evaluate", 0.095, rules)) == GRADE_NORMAL, \
		"일반 패링 경계값은 일반 패링에 포함되어야 한다.")
	_expect(int(evaluator.call(&"evaluate", 0.096, rules)) == GRADE_NONE, \
		"일반 패링 판정 시간이 지난 충돌은 패링이 아니어야 한다.")


func _test_speed_multipliers(evaluator: RefCounted, rules: Resource) -> void:
	var reflected_velocity := Vector2(300.0, -400.0)

	_expect_float(float(evaluator.call(&"get_speed_multiplier", GRADE_NONE, rules)), \
		1.0, "패링이 아니면 속도 배율은 1배여야 한다.")
	_expect_float(float(evaluator.call(&"get_speed_multiplier", GRADE_NORMAL, rules)), \
		1.08, "일반 패링은 공용 일반 배율을 사용해야 한다.")
	_expect_float(float(evaluator.call(&"get_speed_multiplier", GRADE_PERFECT, rules)), \
		1.18, "정확 패링은 공용 정확 배율을 사용해야 한다.")

	for grade: int in [GRADE_NONE, GRADE_NORMAL, GRADE_PERFECT]:
		var result := evaluator.call(
			&"apply_speed_multiplier",
			reflected_velocity,
			grade,
			rules
		) as Vector2
		var multiplier := float(evaluator.call(
			&"get_speed_multiplier",
			grade,
			rules
		))
		_expect_float(result.length(), reflected_velocity.length() * multiplier, \
			"패링 배율은 반사된 공의 속력에 적용되어야 한다.")
		_expect(result.normalized().is_equal_approx(reflected_velocity.normalized()), \
			"패링 속도 배율은 이미 계산된 반사 방향을 바꾸면 안 된다.")


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
		print("PASS: flipper_parry_evaluator_test")
		quit(0)
		return
	print("FAIL: flipper_parry_evaluator_test (%d failures)" % _failures.size())
	quit(1)
