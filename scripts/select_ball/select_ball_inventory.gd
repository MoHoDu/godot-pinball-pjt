class_name SelectBallInventory
extends WaveBallInventory


signal wave_usage_reset


## 보유 공은 ball_id마다 하나만 등록합니다. BallStock.count는 보유 여부만
## 검증하는 데 사용하며, 같은 공을 여러 번 발사할 수 있는 수량으로 취급하지 않습니다.
func reset_stock(stock: Array[BallStock] = starting_stock) -> bool:
	_definitions.clear()
	_remaining_counts.clear()
	_selected_index = -1

	var registered_ids: Dictionary[StringName, bool] = {}
	for item: BallStock in stock:
		if item == null or not item.is_valid():
			continue
		var ball_id := item.definition.ball_id
		if registered_ids.has(ball_id):
			push_warning("Duplicate owned ball id ignored: %s" % ball_id)
			continue
		registered_ids[ball_id] = true
		_definitions.append(item.definition)
		_remaining_counts.append(1)

	stock_reset.emit(total_remaining)
	wave_usage_reset.emit()
	return total_remaining > 0


## 선택 확정이 아니라 실제 발사 성공 시에만 호출합니다.
## 기존 연동부와의 신호 호환을 위해 ball_consumed 신호는 유지하지만,
## 의미는 영구 소모가 아니라 현재 웨이브의 사용 완료입니다.
func mark_selected_ball_used() -> BallDefinition:
	if not has_selection():
		return null
	return mark_ball_used(selected_definition.ball_id)


## 확정 뒤 선택 포인터가 외부 호출로 바뀌더라도 실제로 준비했던 공만
## 사용 완료 처리할 수 있도록 ball_id를 명시적으로 받습니다.
func mark_ball_used(ball_id: StringName) -> BallDefinition:
	var used_index := -1
	for index: int in _definitions.size():
		if _definitions[index].ball_id == ball_id:
			used_index = index
			break
	if used_index < 0 or _remaining_counts[used_index] <= 0:
		return null

	var used_definition := _definitions[used_index]
	_remaining_counts[used_index] = 0
	var available_total := total_remaining
	ball_consumed.emit(used_definition, 0, available_total)

	if available_total <= 0:
		_selected_index = -1
		exhausted.emit()
	elif _selected_index == used_index:
		_selected_index = _find_available_index(used_index + 1, 1)
		selection_changed.emit(selected_definition, selected_remaining)

	return used_definition


func consume_selected_ball() -> BallDefinition:
	return mark_selected_ball_used()


func get_owned_definitions() -> Array[BallDefinition]:
	return _definitions.duplicate()


func is_ball_used(ball_id: StringName) -> bool:
	for index: int in _definitions.size():
		if _definitions[index].ball_id == ball_id:
			return _remaining_counts[index] <= 0
	return false


func get_used_ball_ids() -> Array[StringName]:
	var used_ids: Array[StringName] = []
	for index: int in _definitions.size():
		if _remaining_counts[index] <= 0:
			used_ids.append(_definitions[index].ball_id)
	return used_ids
