class_name RepairInventory
extends RefCounted


## 플레이어의 수리함입니다. 런타임 Bumper 노드를 소유하지 않고
## 안정적인 part_id와 랭크만 저장합니다 (보상 시스템 연동 계약).

signal part_added(part_id: StringName, rank: int)
signal part_ranked_up(part_id: StringName, rank: int)


## part_id → 현재 랭크
var _owned: Dictionary = {}
var _definitions: Dictionary = {}


func register_definition(definition: RepairPartDefinition) -> void:
	if definition != null and definition.is_valid():
		_definitions[definition.part_id] = definition


func get_definition(part_id: StringName) -> RepairPartDefinition:
	return _definitions.get(part_id) as RepairPartDefinition


func owns(part_id: StringName) -> bool:
	return _owned.has(part_id)


func get_rank(part_id: StringName) -> int:
	return int(_owned.get(part_id, 0))


func get_owned_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for part_id: StringName in _owned.keys():
		ids.append(part_id)
	return ids


func is_max_rank(part_id: StringName) -> bool:
	var definition := get_definition(part_id)
	if definition == null:
		return false
	return get_rank(part_id) >= definition.get_max_rank()


## 새 부품이면 랭크 1로 추가하고, 기존 부품이면 랭크가 상승합니다.
func acquire(part_id: StringName) -> int:
	var definition := get_definition(part_id)
	if definition == null:
		return 0
	if not owns(part_id):
		_owned[part_id] = RepairPartDefinition.MIN_RANK
		part_added.emit(part_id, RepairPartDefinition.MIN_RANK)
		return RepairPartDefinition.MIN_RANK
	var next_rank: int = mini(
		get_rank(part_id) + 1,
		definition.get_max_rank()
	)
	if next_rank != get_rank(part_id):
		_owned[part_id] = next_rank
		part_ranked_up.emit(part_id, next_rank)
	return next_rank


func clear() -> void:
	_owned.clear()
