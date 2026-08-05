class_name BoardPlacementSession
extends Node


signal state_changed(previous_state: State, current_state: State)
signal placement_started(wave_id: StringName)
signal placement_committed(
	wave_id: StringName,
	placements: Array[Dictionary],
	consumed_counts: Dictionary
)
signal placement_rejected(result: BoardValidationResult)


enum State {
	IDLE,
	EDITING,
	COMMITTED,
	LOCKED,
}


@export_node_path("BoardLayout") var layout_path: NodePath = ^".."


var layout: BoardLayout
var current_wave_id: StringName
var _state := State.IDLE


var current_state: State:
	get:
		return _state


func _ready() -> void:
	layout = get_node_or_null(layout_path) as BoardLayout


func begin_placement(wave_id: StringName) -> bool:
	if layout == null:
		layout = get_node_or_null(layout_path) as BoardLayout
	if layout == null or _state != State.IDLE:
		return false
	current_wave_id = wave_id
	for placeable: BoardPlaceable in layout.get_placeables():
		placeable.set_committed(false)
		placeable.set_runtime_locked(false)
	layout.set_editing_enabled(true)
	_set_state(State.EDITING)
	placement_started.emit(current_wave_id)
	return true


func commit() -> bool:
	if _state != State.EDITING or layout == null:
		return false
	var result := layout.validate_layout()
	if not result.is_valid:
		placement_rejected.emit(result)
		return false
	var placements: Array[Dictionary] = []
	var consumed_counts: Dictionary = {}
	for placeable: BoardPlaceable in layout.get_placeables():
		var kind_id := placeable.get_kind_id()
		placements.append({
			&"placement_id": placeable.placement_id,
			&"kind_id": kind_id,
			&"zone_id": placeable.zone_id,
			&"socket_id": placeable.socket_id,
			&"position": layout.to_local(placeable.global_position),
			&"reserve_radius": placeable.reserve_radius,
		})
		consumed_counts[kind_id] = int(consumed_counts.get(kind_id, 0)) + 1
		placeable.set_committed(true)
		placeable.set_runtime_locked(true)
	layout.set_editing_enabled(false)
	_set_state(State.COMMITTED)
	placement_committed.emit(current_wave_id, placements, consumed_counts)
	return true


func lock() -> bool:
	if _state != State.COMMITTED:
		return false
	_set_state(State.LOCKED)
	return true


func end_wave() -> void:
	if layout != null:
		layout.set_editing_enabled(false)
		for placeable: BoardPlaceable in layout.get_placeables():
			placeable.set_runtime_locked(false)
	current_wave_id = &""
	_set_state(State.IDLE)


func place_scene_at_socket(
	placeable_scene: PackedScene,
	socket_id: StringName
) -> BoardPlaceable:
	if _state != State.EDITING or layout == null or placeable_scene == null:
		return null
	if layout.get_placeables().size() >= layout.maximum_simultaneous_placements:
		return null
	var socket := _find_socket(socket_id)
	if socket == null or not socket.enabled or _is_socket_occupied(socket_id):
		return null
	var instance := placeable_scene.instantiate()
	if not instance is BoardPlaceable:
		if instance != null:
			instance.free()
		return null
	var placeable := instance as BoardPlaceable
	placeable.zone_id = socket.zone_id
	placeable.socket_id = socket.socket_id
	placeable.placement_id = &"%s_%s" % [placeable.get_kind_id(), socket.socket_id]
	var root := layout.get_node_or_null(layout.placeables_path)
	if root == null:
		placeable.free()
		return null
	root.add_child(placeable)
	placeable.global_position = socket.global_position
	var result := layout.validate_layout()
	if not result.is_valid:
		root.remove_child(placeable)
		placeable.free()
		placement_rejected.emit(result)
		return null
	return placeable


func replace_scene_at_socket(
	placeable_scene: PackedScene,
	socket_id: StringName
) -> BoardPlaceable:
	if _state != State.EDITING or layout == null or placeable_scene == null:
		return null
	var socket := _find_socket(socket_id)
	var existing := find_placeable_at_socket(socket_id)
	if socket == null or not socket.enabled or existing == null:
		return null
	var root := layout.get_node_or_null(layout.placeables_path)
	if root == null:
		return null
	var instance := placeable_scene.instantiate()
	if not instance is BoardPlaceable:
		if instance != null:
			instance.free()
		return null
	var previous_index := existing.get_index()
	root.remove_child(existing)
	var replacement := instance as BoardPlaceable
	replacement.zone_id = socket.zone_id
	replacement.socket_id = socket.socket_id
	replacement.placement_id = &"%s_%s" % [
		replacement.get_kind_id(),
		socket.socket_id,
	]
	root.add_child(replacement)
	replacement.global_position = socket.global_position
	var result := layout.validate_layout()
	if not result.is_valid:
		root.remove_child(replacement)
		replacement.free()
		root.add_child(existing)
		root.move_child(existing, mini(previous_index, root.get_child_count() - 1))
		placement_rejected.emit(result)
		return null
	existing.queue_free()
	return replacement


func move_placeable_to_socket(
	placeable: BoardPlaceable,
	socket_id: StringName
) -> bool:
	if _state != State.EDITING \
			or layout == null \
			or placeable == null \
			or placeable not in layout.get_placeables():
		return false
	var socket := _find_socket(socket_id)
	if socket == null \
			or not socket.enabled \
			or (_is_socket_occupied(socket_id) and placeable.socket_id != socket_id):
		return false
	var previous_position := placeable.global_position
	var previous_zone := placeable.zone_id
	var previous_socket := placeable.socket_id
	placeable.global_position = socket.global_position
	placeable.zone_id = socket.zone_id
	placeable.socket_id = socket.socket_id
	var result := layout.validate_layout()
	if result.is_valid:
		return true
	placeable.global_position = previous_position
	placeable.zone_id = previous_zone
	placeable.socket_id = previous_socket
	placement_rejected.emit(result)
	return false


func remove_placeable(placeable: BoardPlaceable) -> bool:
	if _state != State.EDITING \
			or layout == null \
			or placeable == null \
			or placeable not in layout.get_placeables():
		return false
	var parent := placeable.get_parent()
	parent.remove_child(placeable)
	placeable.queue_free()
	return true


func find_placeable_at_socket(socket_id: StringName) -> BoardPlaceable:
	if layout == null:
		return null
	for placeable: BoardPlaceable in layout.get_placeables():
		if placeable.socket_id == socket_id:
			return placeable
	return null


func _find_socket(socket_id: StringName) -> BoardPlacementSocket:
	for socket: BoardPlacementSocket in layout.get_sockets():
		if socket.socket_id == socket_id:
			return socket
	return null


func _is_socket_occupied(socket_id: StringName) -> bool:
	return find_placeable_at_socket(socket_id) != null


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)
