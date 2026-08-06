class_name BoardPlacementInteraction
extends Node


signal catalog_changed(index: int, scene: PackedScene)
signal selection_changed(placeable: BoardPlaceable)


@export_node_path("BoardPlacementSession") var session_path: NodePath
@export var placeable_catalog: Array[PackedScene] = []
@export_range(8.0, 128.0, 1.0, "suffix:px") var pointer_pick_radius := 52.0


var session: BoardPlacementSession
var selected_placeable: BoardPlaceable
var selected_catalog_index := 0


func _ready() -> void:
	session = get_node_or_null(session_path) as BoardPlacementSession


func _unhandled_input(event: InputEvent) -> void:
	if session == null \
			or session.layout == null \
			or session.current_state != BoardPlacementSession.State.EDITING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			select_catalog(int(key_event.keycode - KEY_1))
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	var local_position := session.layout.get_global_transform_with_canvas() \
		.affine_inverse() * mouse_event.position
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var removable := _find_placeable(local_position)
		if removable != null and session.remove_placeable(removable):
			if removable == selected_placeable:
				_set_selected_placeable(null)
			get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var picked := _find_placeable(local_position)
	if picked != null:
		_set_selected_placeable(picked)
		get_viewport().set_input_as_handled()
		return
	var socket := _find_socket(local_position)
	if socket == null:
		return
	if selected_placeable != null:
		if session.move_placeable_to_socket(selected_placeable, socket.socket_id):
			get_viewport().set_input_as_handled()
		return
	var scene := get_selected_catalog_scene()
	if scene != null:
		var placed := session.place_scene_at_socket(scene, socket.socket_id)
		if placed != null:
			_set_selected_placeable(placed)
			get_viewport().set_input_as_handled()


func select_catalog(index: int) -> bool:
	if index < 0 or index >= placeable_catalog.size():
		return false
	selected_catalog_index = index
	_set_selected_placeable(null)
	catalog_changed.emit(selected_catalog_index, placeable_catalog[index])
	return true


func get_selected_catalog_scene() -> PackedScene:
	if selected_catalog_index < 0 or selected_catalog_index >= placeable_catalog.size():
		return null
	return placeable_catalog[selected_catalog_index]


func _find_placeable(local_position: Vector2) -> BoardPlaceable:
	var closest: BoardPlaceable
	var closest_distance := pointer_pick_radius
	for placeable: BoardPlaceable in session.layout.get_placeables():
		var distance := local_position.distance_to(
			session.layout.to_local(placeable.global_position)
		)
		if distance <= closest_distance:
			closest = placeable
			closest_distance = distance
	return closest


func _find_socket(local_position: Vector2) -> BoardPlacementSocket:
	var closest: BoardPlacementSocket
	var closest_distance := pointer_pick_radius
	for socket: BoardPlacementSocket in session.layout.get_sockets():
		if not socket.enabled:
			continue
		var distance := local_position.distance_to(
			session.layout.to_local(socket.global_position)
		)
		if distance <= closest_distance:
			closest = socket
			closest_distance = distance
	return closest


func _set_selected_placeable(placeable: BoardPlaceable) -> void:
	selected_placeable = placeable
	selection_changed.emit(selected_placeable)
