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
	_expect(loaded_resource is BossBallDamageWeightRules,
		"The configured Resource must use BossBallDamageWeightRules.")
	if not loaded_resource is BossBallDamageWeightRules:
		_finish()
		return

	var rules: BossBallDamageWeightRules = loaded_resource
	_test_configured_resource(rules)
	_test_mass_boundaries(rules)
	await _test_reward_ball_scene_masses(rules)
	_test_invalid_mass_contract(rules)
	_test_invalid_threshold_validation()
	_test_invalid_multiplier_validation()
	_test_multiple_validation_errors_are_collected()
	_test_lookup_does_not_mutate(rules)
	_test_validation_does_not_mutate(rules)
	_test_no_identity_or_scene_dependencies()
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
	_expect(is_equal_approx(rules.normal_minimum_mass, 1.0),
		"Normal must begin at mass 1.0.")
	_expect(is_equal_approx(rules.heavy_minimum_mass, 4.0),
		"Heavy must begin at mass 4.0.")
	_expect(is_equal_approx(rules.super_heavy_minimum_mass, 16.0),
		"Super Heavy must begin at mass 16.0.")


func _test_mass_boundaries(rules: BossBallDamageWeightRules) -> void:
	var cases: Array[Array] = [
		[0.5, BossBallDamageWeightRules.WeightClass.LIGHT, 0.90],
		[0.999, BossBallDamageWeightRules.WeightClass.LIGHT, 0.90],
		[1.0, BossBallDamageWeightRules.WeightClass.NORMAL, 1.00],
		[2.0, BossBallDamageWeightRules.WeightClass.NORMAL, 1.00],
		[3.999, BossBallDamageWeightRules.WeightClass.NORMAL, 1.00],
		[4.0, BossBallDamageWeightRules.WeightClass.HEAVY, 1.15],
		[8.0, BossBallDamageWeightRules.WeightClass.HEAVY, 1.15],
		[15.999, BossBallDamageWeightRules.WeightClass.HEAVY, 1.15],
		[16.0, BossBallDamageWeightRules.WeightClass.SUPER_HEAVY, 1.30],
		[32.0, BossBallDamageWeightRules.WeightClass.SUPER_HEAVY, 1.30],
	]
	for test_case: Array in cases:
		var ball_mass: float = test_case[0]
		var expected_class: int = test_case[1]
		var expected_multiplier: float = test_case[2]
		_expect(rules.has_profile(ball_mass),
			"Positive finite mass %.3f must have a profile." % ball_mass)
		_expect(rules.get_weight_class(ball_mass) == expected_class,
			"Mass %.3f must resolve to its half-open weight class." % ball_mass)
		_expect(is_equal_approx(
			rules.get_damage_multiplier(ball_mass), expected_multiplier
		), "Mass %.3f must resolve to multiplier %.2f." % [
			ball_mass, expected_multiplier,
		])


func _test_reward_ball_scene_masses(
	rules: BossBallDamageWeightRules
) -> void:
	var reward_map := ResourceLoader.load(
		REWARD_BALL_SCENE_MAP_PATH
	) as RewardBallSceneMap
	_expect(reward_map != null, "The Stage 1 reward ball map must load.")
	if reward_map == null:
		return

	var expected_classes: Dictionary[StringName, int] = {
		&"clockwork": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"rubber": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"gel": BossBallDamageWeightRules.WeightClass.NORMAL,
		&"lead": BossBallDamageWeightRules.WeightClass.HEAVY,
		&"hollow_bell": BossBallDamageWeightRules.WeightClass.LIGHT,
	}
	for ball_id: StringName in expected_classes:
		var ball_scene: PackedScene = reward_map.scene_of(ball_id)
		var ball: Pinball = ball_scene.instantiate() as Pinball \
			if ball_scene != null else null
		_expect(ball != null, "Reward ball %s must instantiate." % ball_id)
		if ball == null:
			continue
		root.add_child(ball)
		await process_frame
		_expect(rules.get_weight_class(ball.mass) == expected_classes[ball_id],
			"Reward ball %s must derive its class from effective mass %.2f."
				% [ball_id, ball.mass])
		_expect(rules.get_damage_multiplier(ball.mass) > 0.0,
			"Reward ball %s effective mass must deal Boss damage." % ball_id)
		ball.free()


func _test_invalid_mass_contract(rules: BossBallDamageWeightRules) -> void:
	for invalid_mass: float in [0.0, -1.0, NAN, INF, -INF]:
		_expect(not rules.has_profile(invalid_mass),
			"Non-positive or non-finite mass must not have a profile.")
		_expect(
			rules.get_weight_class(invalid_mass)
			== BossBallDamageWeightRules.INVALID_WEIGHT_CLASS,
			"Invalid mass must return the invalid class sentinel."
		)
		_expect(is_equal_approx(
			rules.get_damage_multiplier(invalid_mass), 0.0
		), "Invalid mass must return multiplier 0.0.")


func _test_invalid_threshold_validation() -> void:
	var invalid_cases: Array[Dictionary] = [
		{&"property": &"normal_minimum_mass", &"value": 0.0},
		{&"property": &"heavy_minimum_mass", &"value": NAN},
		{&"property": &"super_heavy_minimum_mass", &"value": INF},
	]
	for invalid_case: Dictionary in invalid_cases:
		var rules: BossBallDamageWeightRules = RulesScript.new()
		var property_name: StringName = invalid_case.property
		rules.set(property_name, float(invalid_case.value))
		_expect(_contains_error(rules.validate(), String(property_name)),
			"Each invalid threshold must identify its property.")

	var unordered_rules: BossBallDamageWeightRules = RulesScript.new()
	unordered_rules.normal_minimum_mass = 4.0
	unordered_rules.heavy_minimum_mass = 4.0
	unordered_rules.super_heavy_minimum_mass = 3.0
	var unordered_errors: PackedStringArray = unordered_rules.validate()
	_expect(_contains_error(unordered_errors, "less than heavy_minimum_mass"),
		"Normal and Heavy thresholds must be strictly ordered.")
	_expect(_contains_error(
		unordered_errors, "less than super_heavy_minimum_mass"
	), "Heavy and Super Heavy thresholds must be strictly ordered.")


func _test_invalid_multiplier_validation() -> void:
	var invalid_cases: Array[Dictionary] = [
		{&"property": &"light_multiplier", &"value": NAN, &"mass": 0.5},
		{&"property": &"normal_multiplier", &"value": INF, &"mass": 2.0},
		{&"property": &"heavy_multiplier", &"value": 0.0, &"mass": 8.0},
		{&"property": &"super_heavy_multiplier", &"value": -1.0, &"mass": 16.0},
	]
	for invalid_case: Dictionary in invalid_cases:
		var rules: BossBallDamageWeightRules = RulesScript.new()
		var property_name: StringName = invalid_case.property
		rules.set(property_name, float(invalid_case.value))
		_expect(_contains_error(rules.validate(), String(property_name)),
			"Each invalid multiplier must identify its property.")
		_expect(is_equal_approx(
			rules.get_damage_multiplier(float(invalid_case.mass)), 0.0
		), "An invalid multiplier must be blocked by the lookup API.")


func _test_multiple_validation_errors_are_collected() -> void:
	var rules: BossBallDamageWeightRules = RulesScript.new()
	rules.light_multiplier = 0.0
	rules.normal_multiplier = -1.0
	rules.normal_minimum_mass = 4.0
	rules.heavy_minimum_mass = 4.0
	var before: Dictionary = _snapshot(rules)
	var errors: PackedStringArray = rules.validate()
	_expect(_contains_error(errors, "light_multiplier"),
		"Validation must include the Light multiplier error.")
	_expect(_contains_error(errors, "normal_multiplier"),
		"Validation must include the Normal multiplier error.")
	_expect(_contains_error(errors, "less than heavy_minimum_mass"),
		"Validation must include the threshold ordering error.")
	_expect(_snapshot(rules) == before,
		"Multiple-error validation must not mutate the Resource.")


func _test_lookup_does_not_mutate(rules: BossBallDamageWeightRules) -> void:
	var before: Dictionary = _snapshot(rules)
	for ball_mass: float in [0.0, 0.5, 1.0, 4.0, 16.0, INF]:
		rules.has_profile(ball_mass)
		rules.get_weight_class(ball_mass)
		rules.get_damage_multiplier(ball_mass)
	_expect(_snapshot(rules) == before,
		"Mass lookup APIs must not mutate the Resource.")


func _test_validation_does_not_mutate(rules: BossBallDamageWeightRules) -> void:
	var before: Dictionary = _snapshot(rules)
	rules.validate()
	_expect(_snapshot(rules) == before,
		"validate must not mutate the Resource.")


func _test_no_identity_or_scene_dependencies() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/boss_system/boss_ball_damage_weight_rules.gd"
	)
	_expect(not source.is_empty(), "The rules source must be readable.")
	for forbidden_text: String in [
		"ball_id",
		"BallDefinition",
		"Pinball",
		"PinballStats",
		"display_name",
		"PackedScene",
		".tscn",
	]:
		_expect(not source.contains(forbidden_text),
			"The mass rules must not reference '%s'." % forbidden_text)


func _snapshot(rules: BossBallDamageWeightRules) -> Dictionary:
	return {
		&"light_multiplier": rules.light_multiplier,
		&"normal_multiplier": rules.normal_multiplier,
		&"heavy_multiplier": rules.heavy_multiplier,
		&"super_heavy_multiplier": rules.super_heavy_multiplier,
		&"normal_minimum_mass": rules.normal_minimum_mass,
		&"heavy_minimum_mass": rules.heavy_minimum_mass,
		&"super_heavy_minimum_mass": rules.super_heavy_minimum_mass,
	}


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


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
