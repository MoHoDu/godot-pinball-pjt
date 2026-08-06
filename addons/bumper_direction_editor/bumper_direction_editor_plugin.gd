@tool
extends EditorPlugin


const HANDLE_RADIUS := 9.0
const HANDLE_HIT_RADIUS := 16.0
const MINIMUM_HANDLE_DISTANCE := 36.0


var _edited_bumper: ShotBumper
var _dragged_index := -1
var _drag_start_position := Vector2.ZERO


func _handles(object: Object) -> bool:
	return object is ShotBumper


func _edit(object: Object) -> void:
	_disconnect_settings()
	_edited_bumper = object as ShotBumper
	_connect_settings()
	update_overlays()


func _make_visible(visible: bool) -> void:
	if visible:
		update_overlays()
		return
	_disconnect_settings()
	_edited_bumper = null
	_dragged_index = -1
	update_overlays()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _can_edit_directions():
		return
	var canvas_transform := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var center := canvas_transform * _edited_bumper.global_position
	var directions := _edited_bumper.get_launch_anchors()
	for index in directions.size():
		var direction := directions[index]
		var world_target := _edited_bumper.to_global(direction.release_position)
		var target := canvas_transform * world_target
		var color := (
			Color(0.25, 1.0, 0.5, 1.0)
			if direction.is_safe_default
			else Color(0.25, 0.85, 1.0, 1.0)
		)
		overlay.draw_line(center, target, Color(color, 0.8), 3.0, true)
		overlay.draw_circle(target, HANDLE_RADIUS + (3.0 if index == _dragged_index else 0.0), color)
		overlay.draw_circle(target, HANDLE_RADIUS - 3.0, Color(0.08, 0.1, 0.14, 1.0))
		overlay.draw_string(
			ThemeDB.fallback_font,
			target + Vector2(14.0, -10.0),
			direction.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			color
		)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _can_edit_directions():
		return false
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button_event.pressed:
			_dragged_index = _find_handle_at(button_event.position)
			if _dragged_index < 0:
				return false
			_drag_start_position = _get_direction(_dragged_index).release_position
			update_overlays()
			return true
		if _dragged_index >= 0:
			_commit_drag()
			return true
	if event is InputEventMouseMotion and _dragged_index >= 0:
		var motion_event := event as InputEventMouseMotion
		_set_dragged_position(_viewport_to_bumper_local(motion_event.position))
		return true
	return false


func _find_handle_at(viewport_position: Vector2) -> int:
	var canvas_transform := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var directions := _edited_bumper.get_launch_anchors()
	for index in directions.size():
		var world_target := _edited_bumper.to_global(directions[index].release_position)
		if viewport_position.distance_to(canvas_transform * world_target) <= HANDLE_HIT_RADIUS:
			return index
	return -1


func _viewport_to_bumper_local(viewport_position: Vector2) -> Vector2:
	var canvas_transform := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var world_position := canvas_transform.affine_inverse() * viewport_position
	return _edited_bumper.to_local(world_position)


func _set_dragged_position(local_position: Vector2) -> void:
	var direction := _get_direction(_dragged_index)
	if direction == null:
		return
	var minimum_distance := maxf(
		MINIMUM_HANDLE_DISTANCE,
		_edited_bumper.get_collision_radius() + 12.0
	)
	if local_position.length() < minimum_distance:
		var fallback_direction := local_position.normalized()
		if fallback_direction.is_zero_approx():
			fallback_direction = direction.get_local_launch_direction()
		local_position = fallback_direction * minimum_distance
	direction.release_position = local_position
	_edited_bumper.queue_redraw()
	update_overlays()


func _commit_drag() -> void:
	var direction := _get_direction(_dragged_index)
	var final_position := direction.release_position if direction != null else _drag_start_position
	var changed := not final_position.is_equal_approx(_drag_start_position)
	if changed and direction != null:
		var undo_redo := get_undo_redo()
		undo_redo.create_action("Shot 범퍼 발사 방향 이동")
		undo_redo.add_do_property(direction, &"release_position", final_position)
		undo_redo.add_undo_property(direction, &"release_position", _drag_start_position)
		undo_redo.commit_action(false)
	_dragged_index = -1
	update_overlays()


func _get_direction(index: int) -> ShotLaunchAnchor:
	var directions := _edited_bumper.get_launch_anchors()
	if index < 0 or index >= directions.size():
		return null
	return directions[index]


func _can_edit_directions() -> bool:
	return (
		is_instance_valid(_edited_bumper)
		and _edited_bumper.type_settings != null
		and _edited_bumper.type_settings.bumper_type == BumperSettings.BumperType.SHOT
	)


func _connect_settings() -> void:
	if _can_edit_directions() \
			and not _edited_bumper.type_settings.changed.is_connected(_on_settings_changed):
		_edited_bumper.type_settings.changed.connect(_on_settings_changed)


func _disconnect_settings() -> void:
	if is_instance_valid(_edited_bumper) and _edited_bumper.type_settings != null \
			and _edited_bumper.type_settings.changed.is_connected(_on_settings_changed):
		_edited_bumper.type_settings.changed.disconnect(_on_settings_changed)


func _on_settings_changed() -> void:
	update_overlays()
