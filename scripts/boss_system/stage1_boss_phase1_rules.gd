class_name Stage1BossPhase1Rules
extends Resource


@export var boss_max_hp: int = 12000
@export var phase2_hp_ratio: float = 0.50
@export var target_valid_hit_count: int = 30
@export var target_battle_time_sec: float = 150.0

@export var first_attack_delay_sec: float = 3.0
@export var new_ball_grace_sec: float = 2.5
@export var phase1_attack_delay_min_sec: float = 3.5
@export var phase1_attack_delay_max_sec: float = 4.5

@export var boss_launch_duration_sec: float = 2.5
@export var counter_ready_duration_sec: float = 3.0
@export var parry_counter_multiplier: float = 1.35


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if boss_max_hp <= 0:
		errors.append("boss_max_hp must be greater than 0.")
	if phase2_hp_ratio <= 0.0 or phase2_hp_ratio >= 1.0:
		errors.append(
			"phase2_hp_ratio must be greater than 0.0 and less than 1.0."
		)
	if target_valid_hit_count <= 0:
		errors.append("target_valid_hit_count must be greater than 0.")
	if target_battle_time_sec <= 0.0:
		errors.append("target_battle_time_sec must be greater than 0.0.")

	_validate_non_negative_time(errors, &"first_attack_delay_sec", first_attack_delay_sec)
	_validate_non_negative_time(errors, &"new_ball_grace_sec", new_ball_grace_sec)
	_validate_non_negative_time(
		errors,
		&"phase1_attack_delay_min_sec",
		phase1_attack_delay_min_sec
	)
	_validate_non_negative_time(
		errors,
		&"phase1_attack_delay_max_sec",
		phase1_attack_delay_max_sec
	)
	_validate_non_negative_time(
		errors,
		&"boss_launch_duration_sec",
		boss_launch_duration_sec
	)
	_validate_non_negative_time(
		errors,
		&"counter_ready_duration_sec",
		counter_ready_duration_sec
	)

	if phase1_attack_delay_min_sec > phase1_attack_delay_max_sec:
		errors.append(
			"phase1_attack_delay_min_sec must be less than or equal to "
			+ "phase1_attack_delay_max_sec."
		)
	if parry_counter_multiplier < 1.0:
		errors.append("parry_counter_multiplier must be at least 1.0.")

	return errors


func _validate_non_negative_time(
	errors: PackedStringArray,
	property_name: StringName,
	value: float
) -> void:
	if value < 0.0:
		errors.append("%s must be greater than or equal to 0.0." % property_name)
