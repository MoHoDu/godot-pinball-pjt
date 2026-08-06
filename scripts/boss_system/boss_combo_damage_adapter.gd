class_name BossComboDamageAdapter
extends Node


signal damage_resolved(damage: int, was_counter: bool)


var _combo_system: ComboSystem = null


func bind_combo_system(combo_system: ComboSystem) -> bool:
	if combo_system == null or not is_instance_valid(combo_system):
		return false
	_combo_system = combo_system
	return true


func unbind_combo_system() -> void:
	_combo_system = null


func is_bound() -> bool:
	return _combo_system != null and is_instance_valid(_combo_system)


func resolve_boss_hit(
	boss_max_health: int,
	target_valid_hit_count: int,
	ball_weight_multiplier: float = 1.0,
	is_counter: bool = false,
	counter_multiplier: float = 1.0
) -> int:
	if not is_bound() \
			or boss_max_health <= 0 \
			or target_valid_hit_count <= 0 \
			or ball_weight_multiplier <= 0.0 \
			or is_nan(ball_weight_multiplier) \
			or is_inf(ball_weight_multiplier):
		return 0
	if is_counter and (
		counter_multiplier < 1.0
		or is_nan(counter_multiplier)
		or is_inf(counter_multiplier)
	):
		return 0

	var base_damage: float = _combo_system.calculate_base_damage(
		float(boss_max_health),
		target_valid_hit_count,
		ball_weight_multiplier
	)
	if is_counter:
		base_damage *= counter_multiplier

	var final_damage: int = _combo_system.register_boss_hit(base_damage)
	damage_resolved.emit(final_damage, is_counter)
	return final_damage
