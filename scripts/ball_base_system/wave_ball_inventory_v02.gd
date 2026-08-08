class_name WaveBallInventoryV02
extends WaveBallInventory


## 공 종류 선택과 발사 기회(생명)를 분리한 v0.2 인벤토리입니다. (기획서 7장)
##
## 기존 WaveBallInventory는 수정하지 않고 가용성 판정만 오버라이드합니다.
##   - starting_stock이 "생명 풀"입니다(기본 공 1종 × 생명 수).
##   - 해금 공은 재고 슬롯 없이 종류로만 등록되어, 생명이 남아 있는 한
##     몇 번이든 다시 선택할 수 있습니다(7-1: 보유 한도·발사 횟수 제한 없음).
##   - 어떤 종류를 쏘든 생명 풀에서 1씩 차감합니다.
##   - total_remaining(기존 getter)은 풀 잔량과 같습니다. 해금 종류의
##     내부 count는 항상 0으로 두어 합산에 섞이지 않습니다.


var _unlocked_definitions: Array[BallDefinition] = []


## 상점에서 해금한 공 종류 목록입니다. 다음 reset_stock()부터 반영됩니다.
func set_unlocked_definitions(definitions: Array[BallDefinition]) -> void:
	_unlocked_definitions = definitions.duplicate()


func reset_stock(stock: Array[BallStock] = starting_stock) -> bool:
	var has_stock := super(stock)
	var registered_ids: Array[StringName] = []
	for definition in _definitions:
		registered_ids.append(definition.ball_id)
	for definition in _unlocked_definitions:
		if definition == null or not definition.is_valid():
			continue
		if registered_ids.has(definition.ball_id):
			continue
		registered_ids.append(definition.ball_id)
		_definitions.append(definition)
		# 해금 종류는 생명을 소유하지 않습니다. 차감은 풀에서만 합니다.
		_remaining_counts.append(0)
	return has_stock


## 어떤 종류를 쏘든 생명 풀에서 1을 차감합니다. 종류는 소모되지 않습니다.
func consume_selected_ball() -> BallDefinition:
	if not has_selection():
		return null
	var consumed_definition := _definitions[_selected_index]
	var pool_index := _find_pool_index()
	if pool_index >= 0:
		_remaining_counts[pool_index] -= 1
	var remaining_total := total_remaining
	ball_consumed.emit(consumed_definition, remaining_total, remaining_total)
	if remaining_total <= 0:
		_selected_index = -1
		exhausted.emit()
	return consumed_definition


func has_selection() -> bool:
	return (
		_selected_index >= 0
		and _selected_index < _definitions.size()
		and total_remaining > 0
	)


func get_remaining_count(_ball_id: StringName) -> int:
	return total_remaining


func get_available_definitions() -> Array[BallDefinition]:
	if total_remaining <= 0:
		return []
	return _definitions.duplicate()


## 생명이 남아 있으면 등록된 모든 종류를 선택할 수 있습니다.
func _find_available_by_id(ball_id: StringName) -> int:
	if ball_id.is_empty() or total_remaining <= 0:
		return -1
	for index in _definitions.size():
		if _definitions[index].ball_id == ball_id:
			return index
	return -1


func _find_available_index(start_index: int, _direction: int) -> int:
	if _definitions.is_empty() or total_remaining <= 0:
		return -1
	# 종류 소진 개념이 없으므로 요청 위치를 순환 범위로만 보정합니다.
	return posmod(start_index, _definitions.size())


func _find_pool_index() -> int:
	for index in _remaining_counts.size():
		if _remaining_counts[index] > 0:
			return index
	return -1
