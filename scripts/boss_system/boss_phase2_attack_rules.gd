class_name BossPhase2AttackRules
extends Resource


@export var attack_interval_min_sec: float = 2.8
@export var attack_interval_max_sec: float = 3.8


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(attack_interval_min_sec) or attack_interval_min_sec < 0.0:
		errors.append("attack_interval_min_sec must be finite and non-negative.")
	if not is_finite(attack_interval_max_sec) or attack_interval_max_sec < 0.0:
		errors.append("attack_interval_max_sec must be finite and non-negative.")
	if attack_interval_min_sec > attack_interval_max_sec:
		errors.append(
			"attack_interval_min_sec must be less than or equal to "
			+ "attack_interval_max_sec."
		)
	return errors
