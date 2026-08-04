class_name RepairComboAdapter
extends Node


## 기존 ComboSystem의 공개 API만 호출하는 어댑터입니다.
## 부품의 PRIMARY 기본 타격은 기존 ComboHitSource 바인딩이 처리하므로,
## 여기서는 브로치 완성·바늘 봉합·방울 여운 같은 2차 타격만 적립합니다.

const COMBO_SYSTEM_GROUP: StringName = &"combo_systems"


## 비워 두면 combo_systems 그룹에서 첫 번째 ComboSystem을 찾습니다.
@export var combo_system_path: NodePath = NodePath("")


var _combo_system: ComboSystem = null


func get_combo_system() -> ComboSystem:
	if is_instance_valid(_combo_system):
		return _combo_system
	if not combo_system_path.is_empty():
		_combo_system = get_node_or_null(combo_system_path) as ComboSystem
	if _combo_system == null and is_inside_tree():
		var found := get_tree().get_first_node_in_group(COMBO_SYSTEM_GROUP)
		_combo_system = found as ComboSystem
	return _combo_system


## 2차 효과 타격을 콤보에 한 번 적립합니다. PRIMARY 컨텍스트는 거부합니다.
func register_secondary_hit(
	context: RepairEffectContext,
	score_weight: float
) -> bool:
	if context == null \
			or context.trigger_kind == RepairEffectContext.TriggerKind.PRIMARY:
		return false
	assert(not context.can_trigger_parts)
	var combo_system := get_combo_system()
	if combo_system == null:
		return false
	combo_system.register_hit(maxf(score_weight, 0.0))
	return true
