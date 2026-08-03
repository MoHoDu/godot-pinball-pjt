class_name WaveBallInventory
extends Node


signal stock_reset(total_remaining: int)
signal selection_started(definition: BallDefinition, remaining: int)
signal selection_changed(definition: BallDefinition, remaining: int)
signal ball_consumed(definition: BallDefinition, remaining: int, total_remaining: int)
signal exhausted


@export var starting_stock: Array[BallStock] = []


var _definitions: Array[BallDefinition] = []
var _remaining_counts: Array[int] = []
var _selected_index: int = -1


var selected_definition: BallDefinition:
	get:
		if not has_selection():
			return null
		return _definitions[_selected_index]

var selected_remaining: int:
	get:
		if not has_selection():
			return 0
		return _remaining_counts[_selected_index]

var total_remaining: int:
	get:
		var total := 0
		for remaining in _remaining_counts:
			total += remaining
		return total


func _ready() -> void:
	reset_stock()


func reset_stock(stock: Array[BallStock] = starting_stock) -> bool:
	_definitions.clear()
	_remaining_counts.clear()
	_selected_index = -1

	var registered_ids: Dictionary[StringName, bool] = {}
	for item in stock:
		if item == null or not item.is_valid():
			continue
		var ball_id := item.definition.ball_id
		if registered_ids.has(ball_id):
			push_warning("Duplicate ball stock id ignored: %s" % ball_id)
			continue
		registered_ids[ball_id] = true
		_definitions.append(item.definition)
		_remaining_counts.append(item.count)

	stock_reset.emit(total_remaining)
	return total_remaining > 0


func begin_selection(preferred_ball_id: StringName = &"") -> bool:
	if total_remaining <= 0:
		_selected_index = -1
		exhausted.emit()
		return false

	var next_index := _find_available_by_id(preferred_ball_id)
	if next_index < 0 and has_selection():
		next_index = _selected_index
	if next_index < 0:
		next_index = _find_available_index(0, 1)
	if next_index < 0:
		return false

	_selected_index = next_index
	selection_started.emit(selected_definition, selected_remaining)
	return true


func select_next() -> bool:
	return _move_selection(1)


func select_previous() -> bool:
	return _move_selection(-1)


func select_ball(ball_id: StringName) -> bool:
	var next_index := _find_available_by_id(ball_id)
	if next_index < 0:
		return false
	if next_index == _selected_index:
		return true
	_selected_index = next_index
	selection_changed.emit(selected_definition, selected_remaining)
	return true


func consume_selected_ball() -> BallDefinition:
	if not has_selection():
		return null

	var consumed_definition := _definitions[_selected_index]
	_remaining_counts[_selected_index] -= 1
	var remaining_for_type := _remaining_counts[_selected_index]
	var remaining_total := total_remaining
	ball_consumed.emit(
		consumed_definition,
		remaining_for_type,
		remaining_total
	)

	if remaining_total <= 0:
		_selected_index = -1
		exhausted.emit()
	elif remaining_for_type <= 0:
		_selected_index = _find_available_index(_selected_index + 1, 1)
		selection_changed.emit(selected_definition, selected_remaining)

	return consumed_definition


func has_selection() -> bool:
	return _selected_index >= 0 \
		and _selected_index < _definitions.size() \
		and _remaining_counts[_selected_index] > 0


func get_remaining_count(ball_id: StringName) -> int:
	for index in _definitions.size():
		if _definitions[index].ball_id == ball_id:
			return _remaining_counts[index]
	return 0


func get_available_definitions() -> Array[BallDefinition]:
	var available: Array[BallDefinition] = []
	for index in _definitions.size():
		if _remaining_counts[index] > 0:
			available.append(_definitions[index])
	return available


func _move_selection(direction: int) -> bool:
	if total_remaining <= 0:
		return false
	if not has_selection():
		return begin_selection()

	var next_index := _find_available_index(_selected_index + direction, direction)
	if next_index < 0:
		return false
	if next_index == _selected_index:
		return true
	_selected_index = next_index
	selection_changed.emit(selected_definition, selected_remaining)
	return true


func _find_available_by_id(ball_id: StringName) -> int:
	if ball_id.is_empty():
		return -1
	for index in _definitions.size():
		if _definitions[index].ball_id == ball_id \
				and _remaining_counts[index] > 0:
			return index
	return -1


func _find_available_index(start_index: int, direction: int) -> int:
	if _definitions.is_empty():
		return -1
	var safe_direction := 1 if direction >= 0 else -1
	var index := posmod(start_index, _definitions.size())
	for _offset in _definitions.size():
		if _remaining_counts[index] > 0:
			return index
		index = posmod(index + safe_direction, _definitions.size())
	return -1
