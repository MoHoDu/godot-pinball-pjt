class_name WaveUniqueBallInventory
extends SelectBallInventory


## 보유 공은 스테이지 동안 유지하지만 한 웨이브에서는 공별 한 번만 사용합니다.


func is_ball_used(ball_id: StringName) -> bool:
	if not reusable_owned_balls:
		return super(ball_id)
	return _used_owned_ball_ids.has(ball_id) \
		or total_remaining <= 0 \
		or not _has_owned_ball(ball_id)


func begin_selection(preferred_ball_id: StringName = &"") -> bool:
	if not reusable_owned_balls:
		return super(preferred_ball_id)
	if total_remaining <= 0 or _definitions.is_empty():
		_selected_index = -1
		exhausted.emit()
		return false
	var next_index := _unused_index_of(preferred_ball_id)
	if next_index < 0 and has_selection():
		next_index = _selected_index
	if next_index < 0:
		next_index = _find_unused_index(0, 1)
	if next_index < 0:
		_selected_index = -1
		return false
	_move_launch_budget(next_index)
	selection_started.emit(selected_definition, selected_remaining)
	return true


func select_ball(ball_id: StringName) -> bool:
	if not reusable_owned_balls:
		return super(ball_id)
	if total_remaining <= 0 or _used_owned_ball_ids.has(ball_id):
		return false
	var next_index := _unused_index_of(ball_id)
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
		and _selected_index < _definitions.size() \
		and not _used_owned_ball_ids.has(_definitions[_selected_index].ball_id)


func get_remaining_count(ball_id: StringName) -> int:
	if not reusable_owned_balls:
		return super(ball_id)
	return total_remaining \
		if _has_owned_ball(ball_id) and not _used_owned_ball_ids.has(ball_id) \
		else 0


func get_available_definitions() -> Array[BallDefinition]:
	if not reusable_owned_balls:
		return super()
	var available: Array[BallDefinition] = []
	if total_remaining <= 0:
		return available
	for definition: BallDefinition in _definitions:
		if definition != null and not _used_owned_ball_ids.has(definition.ball_id):
			available.append(definition)
	return available


func _reset_reusable_stock(stock: Array[BallStock]) -> bool:
	var result := super(stock)
	var unique_launches := mini(launches_per_wave, _definitions.size())
	if _selected_index >= 0:
		_remaining_counts.fill(0)
		_remaining_counts[_selected_index] = unique_launches
	return result and unique_launches > 0


func _mark_reusable_ball_launched(ball_id: StringName) -> BallDefinition:
	if _used_owned_ball_ids.has(ball_id):
		return null
	var used_definition := super(ball_id)
	if used_definition == null or total_remaining <= 0:
		return used_definition
	var next_index := _find_unused_index(_selected_index + 1, 1)
	if next_index >= 0:
		_move_launch_budget(next_index)
		selection_changed.emit(selected_definition, selected_remaining)
	return used_definition


func _select_reusable_offset(direction: int) -> bool:
	if total_remaining <= 0 or _definitions.is_empty():
		return false
	var current := _selected_index if _selected_index >= 0 else 0
	var next_index := _find_unused_index(
		current + (1 if direction >= 0 else -1),
		direction
	)
	if next_index < 0:
		return false
	if next_index == _selected_index:
		return true
	_move_launch_budget(next_index)
	selection_changed.emit(selected_definition, selected_remaining)
	return true


func _unused_index_of(ball_id: StringName) -> int:
	var index := _owned_index_of(ball_id)
	if index < 0 or _used_owned_ball_ids.has(ball_id):
		return -1
	return index


func _find_unused_index(start_index: int, direction: int) -> int:
	if _definitions.is_empty():
		return -1
	var safe_direction := 1 if direction >= 0 else -1
	var index := posmod(start_index, _definitions.size())
	for _offset: int in _definitions.size():
		var definition := _definitions[index]
		if definition != null \
				and not _used_owned_ball_ids.has(definition.ball_id):
			return index
		index = posmod(index + safe_direction, _definitions.size())
	return -1
