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
	&"combo_visible": false,
	&"combo_anchor_viewport": Vector2.ZERO,
	&"combo_anchor_visible": false,
	&"wave_index": 0,
	&"paused": false,
	&"stage_phase_title": "",
	&"stage_phase_button": "다음 단계",
	&"stage_phase_placeholder_visible": false,
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


func select_life(ball_type: StringName) -> bool:
	var slots: Array = _snapshot[&"life_slots"]
	var selected_index := -1
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if StringName(slot.get(&"type", &"")) != ball_type \
				or int(slot.get(&"state", LifeState.SPENT)) == LifeState.SPENT:
			continue
		selected_index = index
		if int(slot.get(&"state", LifeState.UPCOMING)) == LifeState.CURRENT:
			break
	if selected_index < 0:
		return false

	var changed := false
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var old_state := int(slot.get(&"state", LifeState.UPCOMING))
		if old_state == LifeState.SPENT:
			continue
		var next_state := LifeState.CURRENT \
			if index == selected_index else LifeState.UPCOMING
		if old_state == next_state:
			continue
		slot[&"state"] = next_state
		slots[index] = slot
		changed = true
	if changed:
		_snapshot[&"life_slots"] = slots
		_publish()
	return true


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
	for offset in range(1, slots.size() + 1):
		var next_index := posmod(current_index + offset, slots.size())
		var next_slot: Dictionary = slots[next_index]
		if int(next_slot.get(&"state", LifeState.SPENT)) == LifeState.SPENT:
			continue
		next_slot[&"state"] = LifeState.CURRENT
		slots[next_index] = next_slot
		break
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


func get_current_life_type() -> StringName:
	for slot: Dictionary in _snapshot[&"life_slots"]:
		if int(slot.get(&"state", LifeState.SPENT)) == LifeState.CURRENT:
			return StringName(slot.get(&"type", &""))
	return &""


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
	# ComboSystem clears its active counters before it emits score_changed and
	# combo_finished. Keep the last chain visible through score conversion; the
	# coordinator closes it explicitly from combo_finished afterwards.
	if safe_combo == 0:
		return
	var next_max := maxi(int(_snapshot[&"max_combo"]), safe_combo)
	if int(_snapshot[&"active_combo"]) == safe_combo \
			and int(_snapshot[&"max_combo"]) == next_max \
			and bool(_snapshot[&"combo_visible"]):
		return
	_snapshot[&"active_combo"] = safe_combo
	_snapshot[&"max_combo"] = next_max
	_snapshot[&"combo_visible"] = true
	_publish()


func finish_combo_display() -> void:
	if int(_snapshot[&"active_combo"]) == 0 \
			and not bool(_snapshot[&"combo_visible"]):
		return
	_snapshot[&"active_combo"] = 0
	_snapshot[&"combo_visible"] = false
	_publish()


func reset_combo() -> void:
	_snapshot[&"active_combo"] = 0
	_snapshot[&"max_combo"] = 0
	_snapshot[&"combo_visible"] = false
	_publish()


func set_wave_index(wave_index: int) -> void:
	var safe_index := maxi(wave_index, 0)
	if int(_snapshot[&"wave_index"]) == safe_index:
		return
	_snapshot[&"wave_index"] = safe_index
	_publish()


func set_stage_phase(title: String, button_text: String, is_visible: bool) -> void:
	if String(_snapshot[&"stage_phase_title"]) == title \
			and String(_snapshot[&"stage_phase_button"]) == button_text \
			and bool(_snapshot[&"stage_phase_placeholder_visible"]) == is_visible:
		return
	_snapshot[&"stage_phase_title"] = title
	_snapshot[&"stage_phase_button"] = button_text
	_snapshot[&"stage_phase_placeholder_visible"] = is_visible
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
