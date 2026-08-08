extends SceneTree


const RulesScript = preload(
	"res://scripts/boss_system/boss_ball_damage_weight_rules.gd"
)
const RULES_RESOURCE_PATH: String = (
	"res://settings/bosses/BossBallDamageWeightRules.tres"
)
const REWARD_BALL_SCENE_MAP_PATH: String = (
	"res://settings/reward_shop/RewardBallSceneMap_Stage01.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var loaded_resource: Resource = ResourceLoader.load(RULES_RESOURCE_PATH)
	_expect(loaded_resource != null, "The configured rules Resource must load.")
	_expect(loaded_resource is BossBallDamageWeightRules,
		"The configured Resource must use BossBallDamageWeightRules.")
	if not loaded_resource is BossBallDamageWeightRules:
		_finish()
		return

	var rules: BossBallDamageWeightRules = (
		loaded_resource as BossBallDamageWeightRules
	)
	_test_configured_resource(rules)
	_test_reward_ball_profiles(rules)
	_test_unknown_id_contract(rules)
	_test_future_super_heavy_profile()
	_test_empty_id_validation()
	_test_duplicate_within_class_validation()
	_test_duplicate_across_classes_validation()
	_test_invalid_multiplier_validation()
	_test_multiple_validation_errors_are_collected()
	_test_lookup_does_not_mutate(rules)
	_test_validation_does_not_mutate(rules)
	_test_no_forbidden_dependencies()
	_finish()


func _test_configured_resource(rules: BossBallDamageWeightRules) -> void:
	_expect(rules.validate().is_empty(),
		"The configured rules Resource must validate without errors.")
	_expect(is_equal_approx(rules.light_multiplier, 0.90),
		"Light multiplier must be 0.90.")
	_expect(is_equal_approx(rules.normal_multiplier, 1.00),
		"Normal multiplier must be 1.00.")
	_expect(is_equal_approx(rules.heavy_multiplier, 1.15),
		"Heavy multiplier must be 1.15.")
	_expect(is_equal_approx(rules.super_heavy_multiplier, 1.30),
		"Super Heavy multiplier must be 1.30.")

	_expect(rules.light_ball_ids == [&"light", &"hollow_bell"],
		"Light profiles must include the matching reward ball ID.")
	_expect(
		rules.normal_ball_ids == [
			&"normal", &"clockwork", &"rubber", &"gel",
		],
		"Normal profiles must include normal-mass reward ball IDs."
	)
	_expect(rules.heavy_ball_ids == [&"heavy", &"lead"],
		"Heavy profiles must include the matching reward ball ID.")
	_expect(rules.super_heavy_ball_ids.is_empty(),
		"Super Heavy IDs must remain empty until a real definition exists.")
	_expect(rules.validate().is_empty(),
		"An empty Super Heavy ID array must be valid.")

	_expect(rules.has_profile(&"light"), "The light ID must have a profile.")
	_expect(rules.has_profile(&"normal"), "The normal ID must have a profile.")
	_expect(rules.has_profile(&"heavy"), "The heavy ID must have a profile.")
	_expect(
		rules.get_weight_class(&"light")
		== BossBallDamageWeightRules.WeightClass.LIGHT,
		"The light ID must resolve to the Light class."
	)
	_expect(
		rules.get_weight_class(&"normal")
		== BossBallDamageWeightRules.WeightClass.NORMAL,
		"The normal ID must resolve to the Normal class."
	)
	_expect(
		rules.get_weight_class(&"heavy")
		== BossBallDamageWeightRules.WeightClass.HEAVY,
		"The heavy ID must resolve to the Heavy class."
	)
	_expect(is_equal_approx(rules.get_damage_multiplier(&"light"), 0.90),
		"The light ID must resolve multiplier 0.90.")
	_expect(is_equal_approx(rules.get_damage_multiplier(&"normal"), 1.00),
		"The normal ID must resolve multiplier 1.00.")
	_expect(is_equal_approx(rules.get_damage_multiplier(&"heavy"), 1.15),
		"The heavy ID must resolve multiplier 1.15.")


func _test_reward_ball_profiles(rules: BossBallDamageWeightRules) -> void:
	var reward_map := ResourceLoader.load(
		REWARD_BALL_SCENE_MAP_PATH
	) as RewardBallSceneMap
	_expect(reward_map != null, "The Stage 1 reward ball map must load.")
	if reward_map == null:
		return

	for ball_id: StringName in reward_map.scenes:
		_expect(
			rules.has_profile(ball_id),
			"Every Stage 1 reward ball must have a Boss damage profile: %s"
				% ball_id
		)
		_expect(
			rules.get_damage_multiplier(ball_id) > 0.0,
			"Every Stage 1 reward ball must deal positive Boss damage: %s"
				% ball_id
		)

	var expected_profiles: Dictionary[StringName, int] = {
		&"clockwork": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"rubber": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"gel": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"lead": BossBallDamageWeightRules.WeightClass.HEAVY,
		&"hollow_bell": BossBallDamageWeightRules.WeightClass.LIGHT,
	}
	for ball_id: StringName in expected_profiles:
		_expect(
			rules.get_weight_class(ball_id) == expected_profiles[ball_id],
			"Reward ball %s must use its matching physical weight profile."
				% ball_id
		)


func _test_unknown_id_contract(rules: BossBallDamageWeightRules) -> void:
	for unknown_id: StringName in [&"", &"unknown"]:
		_expect(not rules.has_profile(unknown_id),
			"Empty and unknown IDs must not have a profile.")
		_expect(
			rules.get_weight_class(unknown_id)
			== BossBallDamageWeightRules.INVALID_WEIGHT_CLASS,
			"Empty and unknown IDs must return the invalid class sentinel."
		)
		_expect(is_equal_approx(rules.get_damage_multiplier(unknown_id), 0.0),
			"Empty and unknown IDs must return multiplier 0.0.")


func _test_future_super_heavy_profile() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.super_heavy_ball_ids = [&"future_super_heavy"]
	_expect(rules.has_profile(&"future_super_heavy"),
		"A future Super Heavy ID must be supported when explicitly registered.")
	_expect(
		rules.get_weight_class(&"future_super_heavy")
		== BossBallDamageWeightRules.WeightClass.SUPER_HEAVY,
		"A future ID must resolve to the Super Heavy class."
	)
	_expect(is_equal_approx(
		rules.get_damage_multiplier(&"future_super_heavy"),
		1.30
	), "A future Super Heavy ID must resolve multiplier 1.30.")


func _test_empty_id_validation() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.light_ball_ids = [&"light", &""]
	var errors: PackedStringArray = rules.validate()
	_expect(_contains_error(errors, "light_ball_ids"),
		"An empty ball ID must produce a validation error.")


func _test_duplicate_within_class_validation() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.normal_ball_ids = [&"normal", &"normal"]
	var errors: PackedStringArray = rules.validate()
	_expect(_contains_error(errors, "duplicated in normal_ball_ids"),
		"A duplicate inside one class must produce a validation error.")
	_expect(not rules.has_profile(&"normal"),
		"An internally duplicated ID must not resolve as a valid profile.")
	_expect(is_equal_approx(rules.get_damage_multiplier(&"normal"), 0.0),
		"An internally duplicated ID must return multiplier 0.0.")


func _test_duplicate_across_classes_validation() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.heavy_ball_ids.append(&"normal")
	var errors: PackedStringArray = rules.validate()
	_expect(_contains_error(errors, "multiple weight classes"),
		"An ID registered across classes must produce a validation error.")
	_expect(not rules.has_profile(&"normal"),
		"A cross-class duplicate must not resolve as a valid profile.")
	_expect(
		rules.get_weight_class(&"normal")
		== BossBallDamageWeightRules.INVALID_WEIGHT_CLASS,
		"A cross-class duplicate must return the invalid class sentinel."
	)
	_expect(is_equal_approx(rules.get_damage_multiplier(&"normal"), 0.0),
		"A cross-class duplicate must return multiplier 0.0.")


func _test_invalid_multiplier_validation() -> void:
	var invalid_cases: Array[Dictionary] = [
		{&"property": &"light_multiplier", &"value": NAN},
		{&"property": &"normal_multiplier", &"value": INF},
		{&"property": &"heavy_multiplier", &"value": 0.0},
		{&"property": &"super_heavy_multiplier", &"value": -1.0},
	]
	for invalid_case: Dictionary in invalid_cases:
		var rules: BossBallDamageWeightRules = RulesScript.new()
		var property_name: StringName = invalid_case.property
		if property_name == &"super_heavy_multiplier":
			rules.super_heavy_ball_ids = [&"future_super_heavy"]
		rules.set(property_name, float(invalid_case.value))
		var errors: PackedStringArray = rules.validate()
		_expect(_contains_error(errors, String(property_name)),
			"Each invalid multiplier must identify its property.")
		var affected_id: StringName = _id_for_multiplier(property_name)
		_expect(is_equal_approx(rules.get_damage_multiplier(affected_id), 0.0),
			"An invalid multiplier must be blocked by the lookup API.")


func _test_multiple_validation_errors_are_collected() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.light_multiplier = 0.0
	rules.normal_multiplier = -1.0
	rules.light_ball_ids = [&"light", &"", &"light"]
	rules.normal_ball_ids = [&"shared"]
	rules.heavy_ball_ids = [&"shared"]
	var before: Dictionary = _snapshot(rules)

	var errors: PackedStringArray = rules.validate()

	_expect(_contains_error(errors, "light_multiplier"),
		"Multiple-error validation must include the Light multiplier error.")
	_expect(_contains_error(errors, "normal_multiplier"),
		"Multiple-error validation must include the Normal multiplier error.")
	_expect(_contains_error(errors, "light_ball_ids[1]"),
		"Multiple-error validation must include the empty ball ID error.")
	_expect(_contains_error(errors, "duplicated in light_ball_ids"),
		"Multiple-error validation must include the within-class duplicate error.")
	_expect(_contains_error(errors, "multiple weight classes"),
		"Multiple-error validation must include the cross-class duplicate error.")
	_expect(_snapshot(rules) == before,
		"Multiple-error validation must not mutate the Resource.")


func _test_lookup_does_not_mutate(rules: BossBallDamageWeightRules) -> void:
	var before: Dictionary = _snapshot(rules)
	rules.has_profile(&"light")
	rules.has_profile(&"unknown")
	rules.get_weight_class(&"normal")
	rules.get_weight_class(&"")
	rules.get_damage_multiplier(&"heavy")
	rules.get_damage_multiplier(&"unknown")
	_expect(_snapshot(rules) == before,
		"Profile lookup APIs must not mutate the Resource.")


func _test_validation_does_not_mutate(rules: BossBallDamageWeightRules) -> void:
	var before: Dictionary = _snapshot(rules)
	rules.validate()
	_expect(_snapshot(rules) == before,
		"validate must not mutate the Resource.")


func _test_no_forbidden_dependencies() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_ball_damage_weight_rules.gd"
	)
	_expect(not source.is_empty(), "The rules source must be readable.")
	for forbidden_text: String in [
		"Pinball",
		"PinballStats",
		"mass",
		"display_name",
		"PackedScene",
		".tscn",
	]:
		_expect(not source.contains(forbidden_text),
			"The rules must not reference '%s'." % forbidden_text)


func _snapshot(rules: BossBallDamageWeightRules) -> Dictionary:
	return {
		&"light_multiplier": rules.light_multiplier,
		&"normal_multiplier": rules.normal_multiplier,
		&"heavy_multiplier": rules.heavy_multiplier,
		&"super_heavy_multiplier": rules.super_heavy_multiplier,
		&"light_ball_ids": rules.light_ball_ids.duplicate(),
		&"normal_ball_ids": rules.normal_ball_ids.duplicate(),
		&"heavy_ball_ids": rules.heavy_ball_ids.duplicate(),
		&"super_heavy_ball_ids": rules.super_heavy_ball_ids.duplicate(),
	}


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _id_for_multiplier(property_name: StringName) -> StringName:
	match property_name:
		&"light_multiplier":
			return &"light"
		&"normal_multiplier":
			return &"normal"
		&"heavy_multiplier":
			return &"heavy"
		&"super_heavy_multiplier":
			return &"future_super_heavy"
		_:
			return &""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_ball_damage_weight_rules_test")
		quit(0)
		return
	print(
		"FAIL: boss_ball_damage_weight_rules_test (%d failures)"
		% _failures.size()
	)
	quit(1)
