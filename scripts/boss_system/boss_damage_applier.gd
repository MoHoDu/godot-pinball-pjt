class_name BossDamageApplier
extends Node


signal boss_hit_resolved(
	calculated_damage: int,
	applied_damage: int,
	previous_health: int,
	current_health: int,
	max_health: int,
	was_counter: bool
)


var _damage_adapter: BossComboDamageAdapter = null
var _health: BossHealthComponent = null


func bind(
	damage_adapter: BossComboDamageAdapter,
	health: BossHealthComponent
) -> bool:
	if damage_adapter == null or health == null:
		return false
	if not is_instance_valid(damage_adapter) or not is_instance_valid(health):
		return false
	if not damage_adapter.is_bound():
		return false

	if damage_adapter == _damage_adapter and health == _health:
		return true

	_damage_adapter = damage_adapter
	_health = health
	return true


func unbind() -> void:
	_damage_adapter = null
	_health = null


func is_bound() -> bool:
	return _damage_adapter != null \
		and is_instance_valid(_damage_adapter) \
		and _health != null \
		and is_instance_valid(_health) \
		and _damage_adapter.is_bound()


func resolve_and_apply_hit(
	target_valid_hit_count: int,
	ball_weight_multiplier: float = 1.0,
	is_counter: bool = false,
	counter_multiplier: float = 1.0
) -> int:
	if not is_bound():
		return 0
	if not _health.is_configured() or _health.is_defeated():
		return 0
	if target_valid_hit_count <= 0:
		return 0
	if not is_finite(ball_weight_multiplier) or ball_weight_multiplier <= 0.0:
		return 0
	if not is_finite(counter_multiplier) or counter_multiplier <= 0.0:
		return 0

	var previous_health: int = _health.get_current_health()
	var max_health: int = _health.get_max_health()
	var calculated_damage: int = _damage_adapter.resolve_boss_hit(
		max_health,
		target_valid_hit_count,
		ball_weight_multiplier,
		is_counter,
		counter_multiplier
	)
	var applied_damage: int = _health.apply_damage(calculated_damage)
	var current_health: int = _health.get_current_health()

	boss_hit_resolved.emit(
		calculated_damage,
		applied_damage,
		previous_health,
		current_health,
		max_health,
		is_counter
	)
	return applied_damage
