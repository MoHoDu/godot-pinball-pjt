class_name RelicInventory
extends Node


## 플레이어가 세션 동안 획득한 수리 부품을 보관합니다.


signal relic_acquired(definition: RelicDefinition, stack_count: int)
signal inventory_cleared


var _order: Array[RelicDefinition] = []
var _stack_counts: Dictionary[StringName, int] = {}


var total_count: int:
	get:
		var total := 0
		for count: int in _stack_counts.values():
			total += count
		return total


func acquire(definition: RelicDefinition) -> int:
	if definition == null or not definition.is_valid():
		return 0
	var current := int(_stack_counts.get(definition.relic_id, 0))
	if current >= definition.max_stack:
		return current
	if current == 0:
		_order.append(definition)
	var next_count := current + 1
	_stack_counts[definition.relic_id] = next_count
	relic_acquired.emit(definition, next_count)
	return next_count


func get_stack_count(relic_id: StringName) -> int:
	return int(_stack_counts.get(relic_id, 0))


func is_full(definition: RelicDefinition) -> bool:
	if definition == null:
		return true
	return get_stack_count(definition.relic_id) >= definition.max_stack


func get_owned() -> Array[RelicDefinition]:
	return _order.duplicate()


func clear_all() -> void:
	_order.clear()
	_stack_counts.clear()
	inventory_cleared.emit()


func describe_all() -> String:
	if _order.is_empty():
		return "보유 부품 없음"
	var parts: PackedStringArray = []
	for definition: RelicDefinition in _order:
		parts.append("%s x%d" % [
			definition.display_name,
			get_stack_count(definition.relic_id),
		])
	return " · ".join(parts)
