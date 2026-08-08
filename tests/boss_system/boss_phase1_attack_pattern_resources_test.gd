extends SceneTree

const FIRST_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1FirstPattern.tres"
const REPEAT_PATTERN_PATH: String = \
	"res://settings/bosses/TeddyArmSweepPhase1RepeatPattern.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var first_loaded: Resource = load(FIRST_PATTERN_PATH)
	var repeat_loaded: Resource = load(REPEAT_PATTERN_PATH)

	_expect(first_loaded != null, "The first attack resource must load successfully.")
	_expect(repeat_loaded != null, "The repeat attack resource must load successfully.")
	_expect(first_loaded is BossAttackPattern,
		"The first attack resource must be a BossAttackPattern.")
	_expect(repeat_loaded is BossAttackPattern,
		"The repeat attack resource must be a BossAttackPattern.")

	var first_pattern: BossAttackPattern = first_loaded as BossAttackPattern
	var repeat_pattern: BossAttackPattern = repeat_loaded as BossAttackPattern
	if first_pattern == null or repeat_pattern == null:
		_finish()
		return

	var first_values_before: Dictionary = _snapshot(first_pattern)
	var repeat_values_before: Dictionary = _snapshot(repeat_pattern)

	_expect(first_pattern != repeat_pattern,
		"The first and repeat patterns must be independent resource instances.")
	_expect(first_pattern.is_valid(), "The first attack pattern must be valid.")
	_expect(repeat_pattern.is_valid(), "The repeat attack pattern must be valid.")

	_expect(first_pattern.attack_id == &"teddy_arm_sweep",
		"The first attack id must be teddy_arm_sweep.")
	_expect(repeat_pattern.attack_id == &"teddy_arm_sweep",
		"The repeat attack id must be teddy_arm_sweep.")
	_expect(is_equal_approx(first_pattern.telegraph_duration, 1.10),
		"The first telegraph duration must be 1.10 seconds.")
	_expect(is_equal_approx(repeat_pattern.telegraph_duration, 0.85),
		"The repeat telegraph duration must be 0.85 seconds.")
	_expect(is_equal_approx(first_pattern.active_duration, 0.22),
		"The first active duration must be 0.22 seconds.")
	_expect(is_equal_approx(repeat_pattern.active_duration, 0.22),
		"The repeat active duration must be 0.22 seconds.")
	_expect(is_equal_approx(first_pattern.recovery_duration, 1.35),
		"The first recovery duration must be 1.35 seconds.")
	_expect(is_equal_approx(repeat_pattern.recovery_duration, 1.35),
		"The repeat recovery duration must be 1.35 seconds.")
	_expect(is_equal_approx(first_pattern.cooldown_duration, 0.0),
		"The first cooldown duration must be exactly 0.0 seconds.")
	_expect(is_equal_approx(repeat_pattern.cooldown_duration, 0.0),
		"The repeat cooldown duration must be exactly 0.0 seconds.")

	_expect(first_pattern.attack_id == repeat_pattern.attack_id,
		"Both patterns must use the same attack id.")
	_expect(is_equal_approx(first_pattern.active_duration, repeat_pattern.active_duration),
		"Both patterns must use the same active duration.")
	_expect(is_equal_approx(first_pattern.recovery_duration, repeat_pattern.recovery_duration),
		"Both patterns must use the same recovery duration.")
	_expect(is_equal_approx(first_pattern.cooldown_duration, repeat_pattern.cooldown_duration),
		"Both patterns must use the same cooldown duration.")
	_expect(not is_equal_approx(
		first_pattern.telegraph_duration,
		repeat_pattern.telegraph_duration
	), "Only the telegraph durations must differ between the two patterns.")

	var first_values_after: Dictionary = _snapshot(first_pattern)
	var repeat_values_after: Dictionary = _snapshot(repeat_pattern)
	_expect(first_values_after == first_values_before,
		"Reading and validating the first pattern must not change its values.")
	_expect(repeat_values_after == repeat_values_before,
		"Reading and validating the repeat pattern must not change its values.")
	_finish()


func _snapshot(pattern: BossAttackPattern) -> Dictionary:
	return {
		&"attack_id": pattern.attack_id,
		&"telegraph_duration": pattern.telegraph_duration,
		&"active_duration": pattern.active_duration,
		&"recovery_duration": pattern.recovery_duration,
		&"cooldown_duration": pattern.cooldown_duration,
	}


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BossPhase1AttackPatternResources")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
