class_name WaveHudStateSource
extends Node


signal snapshot_changed(snapshot: Dictionary)


enum LifeState {
	UPCOMING,
	CURRENT,
	SPENT,
}


var _snapshot: Dictionary = {
	&"life_slots": [],
	&"current_score": 0,
	&"target_score": 0,
	&"active_combo": 0,
	&"max_combo": 0,
	&"combo_anchor_viewport": Vector2.ZERO,
	&"combo_anchor_visible": false,
	&"wave_index": 0,
	&"paused": false,
}
var _batch_depth := 0
var _publish_pending := false


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func begin_batch() -> void:
	_batch_depth += 1


func end_batch() -> void:
	assert(_batch_depth > 0, "end_batch() requires a matching begin_batch().")
	_batch_depth -= 1
	if _batch_depth == 0 and _publish_pending:
		_publish_pending = false
		snapshot_changed.emit(get_snapshot())


func configure_lives(ball_types: Array[StringName], current_index: int = 0) -> void:
	assert(ball_types.size() >= 3 and ball_types.size() <= 5, \
		"Wave HUD supports three to five fixed life slots.")
	var slots: Array[Dictionary] = []
	var safe_current := clampi(current_index, 0, ball_types.size() - 1)
	for index in ball_types.size():
		var state := LifeState.UPCOMING
		if index < safe_current:
			state = LifeState.SPENT
		elif index == safe_current:
			state = LifeState.CURRENT
		slots.append({
			&"type": ball_types[index],
			&"state": state,
		})
	_snapshot[&"life_slots"] = slots
	_publish()


func consume_current_life() -> int:
	var slots: Array = _snapshot[&"life_slots"]
	var current_index := -1
	for index in slots.size():
		if int(slots[index].get(&"state", LifeState.UPCOMING)) == LifeState.CURRENT:
			current_index = index
			break
	if current_index < 0:
		return 0
	var spent: Dictionary = slots[current_index]
	spent[&"state"] = LifeState.SPENT
	slots[current_index] = spent
	if current_index + 1 < slots.size():
		var next_slot: Dictionary = slots[current_index + 1]
		next_slot[&"state"] = LifeState.CURRENT
		slots[current_index + 1] = next_slot
	_snapshot[&"life_slots"] = slots
	_publish()
	return get_remaining_life_count()


func reset_lives() -> void:
	var slots: Array = _snapshot[&"life_slots"]
	if slots.is_empty():
		return
	for index in slots.size():
		var slot: Dictionary = slots[index]
		slot[&"state"] = LifeState.CURRENT if index == 0 else LifeState.UPCOMING
		slots[index] = slot
	_snapshot[&"life_slots"] = slots
	_publish()


func get_remaining_life_count() -> int:
	var count := 0
	for slot: Dictionary in _snapshot[&"life_slots"]:
		if int(slot.get(&"state", LifeState.SPENT)) != LifeState.SPENT:
			count += 1
	return count


func set_score(current_score: int, target_score: int) -> void:
	var safe_current := maxi(current_score, 0)
	var safe_target := maxi(target_score, 0)
	if int(_snapshot[&"current_score"]) == safe_current \
			and int(_snapshot[&"target_score"]) == safe_target:
		return
	_snapshot[&"current_score"] = safe_current
	_snapshot[&"target_score"] = safe_target
	_publish()


func observe_combo(combo_count: int) -> void:
	var safe_combo := maxi(combo_count, 0)
	var next_max := maxi(int(_snapshot[&"max_combo"]), safe_combo)
	if int(_snapshot[&"active_combo"]) == safe_combo \
			and int(_snapshot[&"max_combo"]) == next_max:
		return
	_snapshot[&"active_combo"] = safe_combo
	_snapshot[&"max_combo"] = next_max
	_publish()


func reset_combo() -> void:
	_snapshot[&"active_combo"] = 0
	_snapshot[&"max_combo"] = 0
	_publish()


func set_wave_index(wave_index: int) -> void:
	var safe_index := maxi(wave_index, 0)
	if int(_snapshot[&"wave_index"]) == safe_index:
		return
	_snapshot[&"wave_index"] = safe_index
	_publish()


func set_combo_anchor(viewport_position: Vector2, is_visible: bool = true) -> void:
	var old_position: Vector2 = _snapshot[&"combo_anchor_viewport"]
	if old_position.distance_squared_to(viewport_position) < 0.25 \
			and bool(_snapshot[&"combo_anchor_visible"]) == is_visible:
		return
	_snapshot[&"combo_anchor_viewport"] = viewport_position
	_snapshot[&"combo_anchor_visible"] = is_visible
	_publish()


func set_paused(is_paused: bool) -> void:
	if bool(_snapshot[&"paused"]) == is_paused:
		return
	_snapshot[&"paused"] = is_paused
	_publish()


func _publish() -> void:
	if _batch_depth > 0:
		_publish_pending = true
		return
	snapshot_changed.emit(get_snapshot())
