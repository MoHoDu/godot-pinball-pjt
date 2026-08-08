class_name SelectBallInventory
extends WaveBallInventory


signal wave_usage_reset


## 보상 시스템에서는 보유 공 종류와 웨이브의 남은 발사 횟수를 분리합니다.
## false인 기존 씬은 각 공을 웨이브당 한 번 사용하는 main 규칙을 그대로 유지합니다.
@export var reusable_owned_balls := false
@export_range(1, 9, 1) var launches_per_wave := 3


var _persistent_owned_definitions: Array[BallDefinition] = []
var _used_owned_ball_ids: Array[StringName] = []


## 보유 공은 ball_id마다 하나만 등록합니다. BallStock.count는 보유 여부만
## 검증하는 데 사용하며, 같은 공을 여러 번 발사할 수 있는 수량으로 취급하지 않습니다.
func reset_stock(stock: Array[BallStock] = starting_stock) -> bool:
	if reusable_owned_balls:
		return _reset_reusable_stock(stock)
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
	if reusable_owned_balls:
		return _mark_reusable_ball_launched(ball_id)
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
	if reusable_owned_balls:
		return _persistent_owned_definitions.duplicate()
	return _definitions.duplicate()


func is_ball_used(ball_id: StringName) -> bool:
	if reusable_owned_balls:
		return total_remaining <= 0 or not _has_owned_ball(ball_id)
	for index: int in _definitions.size():
		if _definitions[index].ball_id == ball_id:
			return _remaining_counts[index] <= 0
	return false


func get_used_ball_ids() -> Array[StringName]:
	if reusable_owned_balls:
		return _used_owned_ball_ids.duplicate()
	var used_ids: Array[StringName] = []
	for index: int in _definitions.size():
		if _remaining_counts[index] <= 0:
			used_ids.append(_definitions[index].ball_id)
	return used_ids


func begin_selection(preferred_ball_id: StringName = &"") -> bool:
	if not reusable_owned_balls:
		return super(preferred_ball_id)
	if total_remaining <= 0 or _definitions.is_empty():
		_selected_index = -1
		exhausted.emit()
		return false
	var next_index := _owned_index_of(preferred_ball_id)
	if next_index < 0 and _selected_index >= 0:
		next_index = _selected_index
	if next_index < 0:
		next_index = 0
	_move_launch_budget(next_index)
	selection_started.emit(selected_definition, selected_remaining)
	return true


func select_next() -> bool:
	if not reusable_owned_balls:
		return super()
	return _select_reusable_offset(1)


func select_previous() -> bool:
	if not reusable_owned_balls:
		return super()
	return _select_reusable_offset(-1)


func select_ball(ball_id: StringName) -> bool:
	if not reusable_owned_balls:
		return super(ball_id)
	if total_remaining <= 0:
		return false
	var next_index := _owned_index_of(ball_id)
	if next_index < 0:
		return false
	if next_index == _selected_index:
		return true
	_move_launch_budget(next_index)
	selection_changed.emit(selected_definition, selected_remaining)
	return true


func has_selection() -> bool:
	if not reusable_owned_balls:
		return super()
	return total_remaining > 0 \
		and _selected_index >= 0 \
		and _selected_index < _definitions.size()


func get_remaining_count(ball_id: StringName) -> int:
	if not reusable_owned_balls:
		return super(ball_id)
	return total_remaining if _has_owned_ball(ball_id) else 0


func get_available_definitions() -> Array[BallDefinition]:
	if not reusable_owned_balls:
		return super()
	return _definitions.duplicate() if total_remaining > 0 else []


func add_owned_definition(definition: BallDefinition) -> bool:
	if not reusable_owned_balls or definition == null or not definition.is_valid():
		return false
	if _definition_index(_persistent_owned_definitions, definition.ball_id) >= 0:
		return false
	_persistent_owned_definitions.append(definition)
	_definitions.append(definition)
	_remaining_counts.append(0)
	return true


func restore_owned_definitions(definitions: Array[BallDefinition]) -> bool:
	if not reusable_owned_balls:
		return false
	_persistent_owned_definitions = _unique_definitions(definitions)
	return not _persistent_owned_definitions.is_empty()


func reset_owned_to_starting_stock() -> bool:
	if not reusable_owned_balls:
		return false
	_persistent_owned_definitions = _definitions_from_stock(starting_stock)
	return reset_stock()


func _reset_reusable_stock(stock: Array[BallStock]) -> bool:
	if _persistent_owned_definitions.is_empty():
		_persistent_owned_definitions = _definitions_from_stock(stock)
	else:
		for definition: BallDefinition in _definitions_from_stock(stock):
			if _definition_index(
				_persistent_owned_definitions, definition.ball_id
			) < 0:
				_persistent_owned_definitions.append(definition)
	_definitions = _persistent_owned_definitions.duplicate()
	_remaining_counts.clear()
	_remaining_counts.resize(_definitions.size())
	_remaining_counts.fill(0)
	_selected_index = 0 if not _definitions.is_empty() else -1
	if _selected_index >= 0:
		_remaining_counts[_selected_index] = launches_per_wave
	_used_owned_ball_ids.clear()
	stock_reset.emit(total_remaining)
	wave_usage_reset.emit()
	return total_remaining > 0


func _mark_reusable_ball_launched(ball_id: StringName) -> BallDefinition:
	var used_index := _owned_index_of(ball_id)
	if used_index < 0 or total_remaining <= 0:
		return null
	_move_launch_budget(used_index)
	var used_definition := _definitions[used_index]
	_remaining_counts[used_index] -= 1
	if not _used_owned_ball_ids.has(ball_id):
		_used_owned_ball_ids.append(ball_id)
	var remaining_total := total_remaining
	ball_consumed.emit(
		used_definition, remaining_total, remaining_total
	)
	if remaining_total <= 0:
		_selected_index = -1
		exhausted.emit()
	return used_definition


func _select_reusable_offset(direction: int) -> bool:
	if total_remaining <= 0 or _definitions.is_empty():
		return false
	var current := _selected_index if _selected_index >= 0 else 0
	var next_index := posmod(current + (1 if direction >= 0 else -1), _definitions.size())
	if next_index == _selected_index:
		return true
	_move_launch_budget(next_index)
	selection_changed.emit(selected_definition, selected_remaining)
	return true


func _move_launch_budget(next_index: int) -> void:
	var remaining_total := total_remaining
	_remaining_counts.fill(0)
	_selected_index = next_index
	_remaining_counts[_selected_index] = remaining_total


func _has_owned_ball(ball_id: StringName) -> bool:
	return _owned_index_of(ball_id) >= 0


func _owned_index_of(ball_id: StringName) -> int:
	return _definition_index(_definitions, ball_id)


func _definition_index(
	source: Array[BallDefinition],
	ball_id: StringName
) -> int:
	if ball_id.is_empty():
		return -1
	for index: int in source.size():
		if source[index] != null and source[index].ball_id == ball_id:
			return index
	return -1


func _definitions_from_stock(stock: Array[BallStock]) -> Array[BallDefinition]:
	var definitions: Array[BallDefinition] = []
	for item: BallStock in stock:
		if item != null and item.is_valid() \
				and _definition_index(definitions, item.definition.ball_id) < 0:
			definitions.append(item.definition)
	return definitions


func _unique_definitions(source: Array[BallDefinition]) -> Array[BallDefinition]:
	var definitions: Array[BallDefinition] = []
	for definition: BallDefinition in source:
		if definition != null and definition.is_valid() \
				and _definition_index(definitions, definition.ball_id) < 0:
			definitions.append(definition)
	return definitions
