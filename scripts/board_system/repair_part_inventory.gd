class_name RepairPartInventory
extends Node


signal inventory_changed(snapshot: Array[Dictionary])
signal part_count_changed(part_id: StringName, count: int)


@export var entries: Array[RepairPartInventoryEntry] = []


var _owned_counts: Dictionary = {}
var _session_capacity: Dictionary = {}
var _reserved_counts: Dictionary = {}
var _session_active := false


var total_count: int:
	get:
		var result := 0
		for kind_id: StringName in _owned_counts:
			result += int(_owned_counts[kind_id])
		return result


func _ready() -> void:
	reset_to_starting_counts()


func reset_to_starting_counts() -> void:
	_owned_counts.clear()
	_session_capacity.clear()
	_reserved_counts.clear()
	_session_active = false
	for entry: RepairPartInventoryEntry in entries:
		if entry == null or not entry.is_valid():
			continue
		_owned_counts[entry.get_kind_id()] = entry.starting_count
	_emit_changed()


func begin_reservation(existing_counts: Dictionary = {}) -> bool:
	if _session_active:
		return false
	_session_capacity = _owned_counts.duplicate(true)
	_reserved_counts.clear()
	for kind_variant: Variant in existing_counts:
		var kind_id := StringName(kind_variant)
		var count := maxi(int(existing_counts[kind_variant]), 0)
		_session_capacity[kind_id] = int(
			_session_capacity.get(kind_id, 0)
		) + count
		_reserved_counts[kind_id] = count
	_session_active = true
	_emit_changed()
	return true


func sync_reservations(next_counts: Dictionary) -> bool:
	if not _session_active:
		return false
	for kind_variant: Variant in next_counts:
		var kind_id := StringName(kind_variant)
		var count := maxi(int(next_counts[kind_variant]), 0)
		if get_entry(kind_id) == null \
				or count > int(_session_capacity.get(kind_id, 0)):
			return false
	_reserved_counts.clear()
	for kind_variant: Variant in next_counts:
		var kind_id := StringName(kind_variant)
		var count := maxi(int(next_counts[kind_variant]), 0)
		if count > 0:
			_reserved_counts[kind_id] = count
	_emit_changed()
	return true


func commit_reservation() -> bool:
	if not _session_active:
		return false
	_owned_counts.clear()
	for entry: RepairPartInventoryEntry in entries:
		if entry == null or not entry.is_valid():
			continue
		var kind_id := entry.get_kind_id()
		_owned_counts[kind_id] = maxi(
			int(_session_capacity.get(kind_id, 0))
				- int(_reserved_counts.get(kind_id, 0)),
			0
		)
	_session_active = false
	_session_capacity.clear()
	_reserved_counts.clear()
	_emit_changed()
	return true


func cancel_reservation() -> void:
	_session_active = false
	_session_capacity.clear()
	_reserved_counts.clear()
	_emit_changed()


func get_entry(kind_id: StringName) -> RepairPartInventoryEntry:
	for entry: RepairPartInventoryEntry in entries:
		if entry != null and entry.get_kind_id() == kind_id:
			return entry
	return null


func get_available_count(kind_id: StringName) -> int:
	if _session_active:
		return maxi(
			int(_session_capacity.get(kind_id, 0))
				- int(_reserved_counts.get(kind_id, 0)),
			0
		)
	return maxi(int(_owned_counts.get(kind_id, 0)), 0)


func count_of(kind_id: StringName) -> int:
	return maxi(int(_owned_counts.get(kind_id, 0)), 0)


func add(kind_id: StringName, amount: int) -> int:
	if kind_id == &"" or amount <= 0:
		return count_of(kind_id)
	_owned_counts[kind_id] = count_of(kind_id) + amount
	part_count_changed.emit(kind_id, count_of(kind_id))
	_emit_changed()
	return count_of(kind_id)


func try_consume(kind_id: StringName, amount: int) -> bool:
	if amount <= 0 or count_of(kind_id) < amount:
		return false
	_owned_counts[kind_id] = count_of(kind_id) - amount
	if int(_owned_counts[kind_id]) <= 0:
		_owned_counts.erase(kind_id)
	part_count_changed.emit(kind_id, count_of(kind_id))
	_emit_changed()
	return true


func snapshot() -> Dictionary:
	return _owned_counts.duplicate(true)


func restore(counts: Dictionary) -> void:
	var previous_counts := _owned_counts.duplicate(true)
	_owned_counts.clear()
	for kind_variant: Variant in counts:
		var kind_id := StringName(kind_variant)
		var count := maxi(int(counts[kind_variant]), 0)
		if count > 0:
			_owned_counts[kind_id] = count
	for kind_variant: Variant in previous_counts:
		var kind_id := StringName(kind_variant)
		if not _owned_counts.has(kind_id):
			part_count_changed.emit(kind_id, 0)
	for kind_id: StringName in _owned_counts:
		part_count_changed.emit(kind_id, count_of(kind_id))
	_emit_changed()


func get_reserved_count(kind_id: StringName) -> int:
	return maxi(int(_reserved_counts.get(kind_id, 0)), 0) \
		if _session_active else 0


func can_reserve(kind_id: StringName, count := 1) -> bool:
	return count > 0 and get_available_count(kind_id) >= count


func get_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry: RepairPartInventoryEntry in entries:
		if entry == null or not entry.is_valid():
			continue
		var kind_id := entry.get_kind_id()
		snapshot.append({
			&"kind_id": kind_id,
			&"display_name": entry.settings.display_name,
			&"feature": entry.one_line_feature,
			&"placeholder_icon": entry.placeholder_icon,
			&"available_count": get_available_count(kind_id),
			&"reserved_count": get_reserved_count(kind_id),
			&"entry": entry,
		})
	return snapshot


func _emit_changed() -> void:
	inventory_changed.emit(get_snapshot())
