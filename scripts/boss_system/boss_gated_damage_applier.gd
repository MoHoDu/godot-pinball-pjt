class_name BossGatedDamageApplier
extends BossDamageApplier


signal damage_blocked(reason: StringName)


const BLOCK_REASON_BOSS_ACTIVE: StringName = &"boss_active"
const BLOCK_REASON_GATE_UNAVAILABLE: StringName = &"gate_unavailable"


var _damage_gate: BossDamageGate = null


func bind_damage_gate(gate: BossDamageGate) -> bool:
	if gate == null or not is_instance_valid(gate) or not gate.is_bound():
		return false
	_damage_gate = gate
	return true


func unbind_damage_gate() -> void:
	_damage_gate = null


func is_damage_gate_bound() -> bool:
	return is_instance_valid(_damage_gate) and _damage_gate.is_bound()


func resolve_and_apply_hit(
	target_valid_hit_count: int,
	ball_weight_multiplier: float = 1.0,
	is_counter: bool = false,
	counter_multiplier: float = 1.0
) -> int:
	if not is_damage_gate_bound():
		damage_blocked.emit(BLOCK_REASON_GATE_UNAVAILABLE)
		return 0
	if not _damage_gate.is_damage_allowed():
		damage_blocked.emit(BLOCK_REASON_BOSS_ACTIVE)
		return 0
	return super.resolve_and_apply_hit(
		target_valid_hit_count,
		ball_weight_multiplier,
		is_counter,
		counter_multiplier
	)
