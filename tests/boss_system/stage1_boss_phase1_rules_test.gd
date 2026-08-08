extends SceneTree


const RULES_PATH := "res://settings/bosses/Stage1BossPhase1Rules.tres"

const TIME_PROPERTY_NAMES: Array[StringName] = [
	&"first_attack_delay_sec",
	&"new_ball_grace_sec",
	&"phase1_attack_delay_min_sec",
	&"phase1_attack_delay_max_sec",
	&"boss_launch_duration_sec",
	&"counter_ready_duration_sec",
]


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_script_defaults()
	_test_authored_resource()
	_test_default_validation()
	_test_invalid_health()
	_test_invalid_phase_ratio()
	_test_invalid_target_hit_count()
	_test_invalid_target_battle_time()
	_test_negative_times()
	_test_inverted_attack_delay_range()
	_test_invalid_counter_multiplier()
	_test_multiple_errors_are_collected()
	_test_validation_does_not_mutate_values()
	_finish()


func _test_script_defaults() -> void:
	_assert_expected_values(
		Stage1BossPhase1Rules.new(),
		"A newly created rules resource"
	)


func _test_authored_resource() -> void:
	var rules := load(RULES_PATH) as Stage1BossPhase1Rules
	_expect(rules != null, "The authored Stage 1 boss rules resource must load.")
	if rules != null:
		_assert_expected_values(rules, "The authored rules resource")


func _test_default_validation() -> void:
	var rules := Stage1BossPhase1Rules.new()
	_expect(
		rules.validate().is_empty(),
		"The default rules must pass validation without errors."
	)


func _test_invalid_health() -> void:
	for invalid_health: int in [0, -1]:
		var rules := Stage1BossPhase1Rules.new()
		rules.boss_max_hp = invalid_health
		_expect_has_error(
			rules.validate(),
			&"boss_max_hp",
			"Non-positive boss health must fail validation."
		)


func _test_invalid_phase_ratio() -> void:
	for invalid_ratio: float in [-0.1, 0.0, 1.0, 1.1]:
		var rules := Stage1BossPhase1Rules.new()
		rules.phase2_hp_ratio = invalid_ratio
		_expect_has_error(
			rules.validate(),
			&"phase2_hp_ratio",
			"A phase ratio outside the open 0.0 to 1.0 range must fail validation."
		)


func _test_invalid_target_hit_count() -> void:
	for invalid_count: int in [0, -1]:
		var rules := Stage1BossPhase1Rules.new()
		rules.target_valid_hit_count = invalid_count
		_expect_has_error(
			rules.validate(),
			&"target_valid_hit_count",
			"A non-positive target hit count must fail validation."
		)


func _test_invalid_target_battle_time() -> void:
	for invalid_time: float in [0.0, -0.1]:
		var rules := Stage1BossPhase1Rules.new()
		rules.target_battle_time_sec = invalid_time
		_expect_has_error(
			rules.validate(),
			&"target_battle_time_sec",
			"A non-positive target battle time must fail validation."
		)


func _test_negative_times() -> void:
	for property_name: StringName in TIME_PROPERTY_NAMES:
		var rules := Stage1BossPhase1Rules.new()
		rules.set(property_name, -0.1)
		_expect_has_error(
			rules.validate(),
			property_name,
			"A negative %s value must fail validation." % property_name
		)

	var zero_rules := Stage1BossPhase1Rules.new()
	for property_name: StringName in TIME_PROPERTY_NAMES:
		zero_rules.set(property_name, 0.0)
	_expect(
		zero_rules.validate().is_empty(),
		"Zero must be valid for every duration except target_battle_time_sec."
	)


func _test_inverted_attack_delay_range() -> void:
	var rules := Stage1BossPhase1Rules.new()
	rules.phase1_attack_delay_min_sec = 5.0
	rules.phase1_attack_delay_max_sec = 4.0
	var errors := rules.validate()
	_expect(
		_has_error_for(errors, &"phase1_attack_delay_min_sec")
		and _has_error_for(errors, &"phase1_attack_delay_max_sec"),
		"An inverted attack delay range must identify both range properties."
	)


func _test_invalid_counter_multiplier() -> void:
	var rules := Stage1BossPhase1Rules.new()
	rules.parry_counter_multiplier = 0.99
	_expect_has_error(
		rules.validate(),
		&"parry_counter_multiplier",
		"A counter multiplier below 1.0 must fail validation."
	)


func _test_multiple_errors_are_collected() -> void:
	var rules := Stage1BossPhase1Rules.new()
	rules.boss_max_hp = 0
	rules.phase2_hp_ratio = 1.0
	rules.target_valid_hit_count = 0
	rules.target_battle_time_sec = 0.0
	rules.first_attack_delay_sec = -1.0
	rules.phase1_attack_delay_min_sec = 5.0
	rules.phase1_attack_delay_max_sec = 4.0
	rules.parry_counter_multiplier = 0.5

	var errors := rules.validate()
	var expected_properties: Array[StringName] = [
		&"boss_max_hp",
		&"phase2_hp_ratio",
		&"target_valid_hit_count",
		&"target_battle_time_sec",
		&"first_attack_delay_sec",
		&"phase1_attack_delay_min_sec",
		&"phase1_attack_delay_max_sec",
		&"parry_counter_multiplier",
	]
	for property_name: StringName in expected_properties:
		_expect_has_error(
			errors,
			property_name,
			"Combined validation must include an error for %s." % property_name
		)
	_expect(
		errors.size() == 7,
		"Combined validation must return all seven violated validation rules."
	)


func _test_validation_does_not_mutate_values() -> void:
	var rules := Stage1BossPhase1Rules.new()
	rules.boss_max_hp = -50
	rules.phase2_hp_ratio = 2.0
	rules.target_valid_hit_count = -3
	rules.target_battle_time_sec = -4.0
	rules.first_attack_delay_sec = -5.0
	rules.new_ball_grace_sec = -6.0
	rules.phase1_attack_delay_min_sec = 8.0
	rules.phase1_attack_delay_max_sec = 7.0
	rules.boss_launch_duration_sec = -9.0
	rules.counter_ready_duration_sec = -10.0
	rules.parry_counter_multiplier = 0.5
	var before := _snapshot(rules)

	rules.validate()

	_expect(
		_snapshot(rules) == before,
		"Validation must not mutate any rules resource value."
	)


func _assert_expected_values(
	rules: Stage1BossPhase1Rules,
	source_label: String
) -> void:
	_expect(rules.boss_max_hp == 12000, "%s must use boss_max_hp 12000." % source_label)
	_expect(is_equal_approx(rules.phase2_hp_ratio, 0.50),
		"%s must use phase2_hp_ratio 0.50." % source_label)
	_expect(rules.target_valid_hit_count == 30,
		"%s must use target_valid_hit_count 30." % source_label)
	_expect(is_equal_approx(rules.target_battle_time_sec, 150.0),
		"%s must use target_battle_time_sec 150.0." % source_label)
	_expect(is_equal_approx(rules.first_attack_delay_sec, 3.0),
		"%s must use first_attack_delay_sec 3.0." % source_label)
	_expect(is_equal_approx(rules.new_ball_grace_sec, 2.5),
		"%s must use new_ball_grace_sec 2.5." % source_label)
	_expect(is_equal_approx(rules.phase1_attack_delay_min_sec, 3.5),
		"%s must use phase1_attack_delay_min_sec 3.5." % source_label)
	_expect(is_equal_approx(rules.phase1_attack_delay_max_sec, 4.5),
		"%s must use phase1_attack_delay_max_sec 4.5." % source_label)
	_expect(is_equal_approx(rules.boss_launch_duration_sec, 2.5),
		"%s must use boss_launch_duration_sec 2.5." % source_label)
	_expect(is_equal_approx(rules.counter_ready_duration_sec, 3.0),
		"%s must use counter_ready_duration_sec 3.0." % source_label)
	_expect(is_equal_approx(rules.parry_counter_multiplier, 1.35),
		"%s must use parry_counter_multiplier 1.35." % source_label)


func _snapshot(rules: Stage1BossPhase1Rules) -> Dictionary:
	return {
		&"boss_max_hp": rules.boss_max_hp,
		&"phase2_hp_ratio": rules.phase2_hp_ratio,
		&"target_valid_hit_count": rules.target_valid_hit_count,
		&"target_battle_time_sec": rules.target_battle_time_sec,
		&"first_attack_delay_sec": rules.first_attack_delay_sec,
		&"new_ball_grace_sec": rules.new_ball_grace_sec,
		&"phase1_attack_delay_min_sec": rules.phase1_attack_delay_min_sec,
		&"phase1_attack_delay_max_sec": rules.phase1_attack_delay_max_sec,
		&"boss_launch_duration_sec": rules.boss_launch_duration_sec,
		&"counter_ready_duration_sec": rules.counter_ready_duration_sec,
		&"parry_counter_multiplier": rules.parry_counter_multiplier,
	}


func _expect_has_error(
	errors: PackedStringArray,
	property_name: StringName,
	message: String
) -> void:
	_expect(_has_error_for(errors, property_name), message)


func _has_error_for(
	errors: PackedStringArray,
	property_name: StringName
) -> bool:
	for error: String in errors:
		if error.contains(String(property_name)):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage1_boss_phase1_rules_test")
		quit(0)
		return
	print("FAIL: stage1_boss_phase1_rules_test (%d failures)" % _failures.size())
	quit(1)
