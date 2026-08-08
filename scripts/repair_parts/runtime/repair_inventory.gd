class_name RepairInventory
extends RefCounted


## 플레이어의 수리함입니다. 런타임 Bumper 노드를 소유하지 않고
## 안정적인 part_id만 저장합니다 (보상 시스템 연동 계약).
##
## v0.3: 랭크 시스템을 제거했습니다. 부품은 보유 / 미보유 두 상태뿐이고
## 같은 부품을 다시 획득해도 수치가 오르지 않습니다.

signal part_added(part_id: StringName)


var _owned: Dictionary = {}
var _definitions: Dictionary = {}


func register_definition(definition: RepairPartDefinition) -> void:
	if definition != null and definition.is_valid():
		_definitions[definition.part_id] = definition


func get_definition(part_id: StringName) -> RepairPartDefinition:
	return _definitions.get(part_id) as RepairPartDefinition


func owns(part_id: StringName) -> bool:
	return _owned.has(part_id)


func get_owned_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for part_id: StringName in _owned.keys():
		ids.append(part_id)
	return ids


## 새 부품이면 수리함에 추가합니다. 이미 보유한 부품이면 아무 일도 없습니다.
func acquire(part_id: StringName) -> bool:
	if get_definition(part_id) == null or owns(part_id):
		return false
	_owned[part_id] = true
	part_added.emit(part_id)
	return true


func clear() -> void:
	_owned.clear()
