@tool
class_name BoardLayout
extends Node2D


signal validation_completed(result: BoardValidationResult)
signal editing_changed(is_editing: bool)


const GRID_CELL_SIZE := 144.0
const MAXIMUM_SIMULTANEOUS_PLACEMENTS := 6


@export_category("Board Nodes")
@export_node_path("BoardBoundary") var boundary_path: NodePath = ^"Boundary"
@export_node_path("Node2D") var zones_path: NodePath = ^"Zones"
@export_node_path("Node2D") var sockets_path: NodePath = ^"Sockets"
@export_node_path("Node2D") var forbidden_areas_path: NodePath = ^"ForbiddenAreas"
@export_node_path("Node2D") var placeables_path: NodePath = ^"Placeables"

@export_category("Placement Rules")
@export var grid_origin := Vector2.ZERO:
	set(value):
		grid_origin = value
		queue_redraw()
## 레이아웃에 필요한 후보 소켓 수입니다. 추가·삭제 버튼이 자동으로 동기화합니다.
@export_range(0, 128, 1) var required_candidate_sockets := 12


var grid_cell_size: float:
	get:
		return GRID_CELL_SIZE

var maximum_simultaneous_placements: int:
	get:
		return MAXIMUM_SIMULTANEOUS_PLACEMENTS

@export_category("Editor Preflight")
@export var show_grid := true:
	set(value):
		show_grid = value
		queue_redraw()
## Toggle this in the inspector before saving. It immediately resets to false.
@export var run_validation_before_save := false:
	set(value):
		run_validation_before_save = false
		if value and is_inside_tree():
			call_deferred(&"validate_and_report")
@export_tool_button("Validate & Save") var validate_and_save_button = validate_and_save

@export_category("Editor Add Zone")
@export var new_zone_id: StringName = &"new_zone"
@export var new_zone_center := Vector2.ZERO
@export var new_zone_size := Vector2(576.0, 288.0)
@export var new_zone_allowed_kind_ids := PackedStringArray()
## Scene 트리의 영역을 이 슬롯으로 드래그한 뒤 삭제 버튼을 누릅니다.
@export var zone_to_delete: BoardPlacementZone
@export_tool_button("Add Zone", "Add") var add_zone_button = add_zone_from_inspector
@export_tool_button("Delete Selected Zone", "Remove")
var delete_zone_button = delete_selected_zone

@export_category("Editor Add Socket")
@export var new_socket_id: StringName = &"new_socket"
@export var new_socket_zone_id: StringName = &"new_zone"
@export var new_socket_position := Vector2.ZERO
@export_range(1.0, 512.0, 1.0, "suffix:px") var new_socket_reserve_radius := 72.0
## Scene 트리의 소켓을 이 슬롯으로 드래그한 뒤 삭제 버튼을 누릅니다.
@export var socket_to_delete: BoardPlacementSocket
@export_tool_button("Add Socket", "Add") var add_socket_button = add_socket_from_inspector
@export_tool_button("Delete Selected Socket", "Remove")
var delete_socket_button = delete_selected_socket
@export_tool_button("Sync Expected Socket Count", "Reload")
var sync_socket_count_button = sync_required_socket_count


var editing_enabled := true
var _validator := BoardPlacementValidator.new()
var _last_validation := BoardValidationResult.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
	else:
		# Runtime layouts start outside the repair-placement phase. The placement
		# session explicitly enables these visual guides when editing begins.
		set_editing_enabled(false)
	queue_redraw()
	update_configuration_warnings()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	queue_redraw()
	update_configuration_warnings()


func get_boundary() -> BoardBoundary:
	return get_node_or_null(boundary_path) as BoardBoundary


func get_zones() -> Array[BoardPlacementZone]:
	var result: Array[BoardPlacementZone] = []
	var root := get_node_or_null(zones_path)
	if root == null:
		return result
	for child: Node in root.get_children():
		if child is BoardPlacementZone:
			result.append(child as BoardPlacementZone)
	return result


func get_forbidden_areas() -> Array[BoardForbiddenArea]:
	var result: Array[BoardForbiddenArea] = []
	var root := get_node_or_null(forbidden_areas_path)
	if root == null:
		return result
	for child: Node in root.get_children():
		if child is BoardForbiddenArea:
			result.append(child as BoardForbiddenArea)
	return result


func get_sockets() -> Array[BoardPlacementSocket]:
	var result: Array[BoardPlacementSocket] = []
	var root := get_node_or_null(sockets_path)
	if root == null:
		return result
	for child: Node in root.get_children():
		if child is BoardPlacementSocket:
			result.append(child as BoardPlacementSocket)
	return result


func get_placeables() -> Array[BoardPlaceable]:
	var result: Array[BoardPlaceable] = []
	var root := get_node_or_null(placeables_path)
	if root == null:
		return result
	for child: Node in root.get_children():
		if child is BoardPlaceable:
			result.append(child as BoardPlaceable)
	return result


func validate_layout() -> BoardValidationResult:
	_last_validation = _validator.validate(self)
	validation_completed.emit(_last_validation)
	return _last_validation


func validate_and_report() -> bool:
	var result := validate_layout()
	if result.is_valid:
		print("PASS: board layout pre-save validation")
		return true
	for message: String in result.to_messages():
		push_warning(message)
	return false


func validate_and_save() -> bool:
	if not Engine.is_editor_hint() or not validate_and_report():
		return false
	if not Engine.has_singleton(&"EditorInterface"):
		return false
	var editor_interface: Object = Engine.get_singleton(&"EditorInterface")
	var save_result: int = int(editor_interface.call(&"save_scene"))
	if save_result != OK:
		push_error("Board layout passed validation but the editor could not save the scene.")
		return false
	return true


func add_zone_from_inspector() -> BoardPlacementZone:
	return create_zone(
		new_zone_id,
		new_zone_center,
		new_zone_size,
		new_zone_allowed_kind_ids
	)


func create_zone(
	zone_id: StringName,
	center: Vector2,
	size: Vector2,
	allowed_kind_ids := PackedStringArray()
) -> BoardPlacementZone:
	var root := get_node_or_null(zones_path) as Node2D
	if root == null or zone_id.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		push_warning("Zone requires a target root, non-empty id, and positive size.")
		return null
	for existing: BoardPlacementZone in get_zones():
		if existing.zone_id == zone_id:
			push_warning("Zone id '%s' already exists." % zone_id)
			return null
	var zone := BoardPlacementZone.new()
	zone.name = _unique_child_name(root, _pascal_case(String(zone_id)))
	zone.zone_id = zone_id
	zone.allowed_kind_ids = allowed_kind_ids
	zone.position = center
	var half := size * 0.5
	zone.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	root.add_child(zone)
	_assign_editor_owner(zone)
	queue_redraw()
	update_configuration_warnings()
	return zone


func delete_selected_zone() -> bool:
	var zone := zone_to_delete
	if zone == null:
		zone = _get_editor_selected_node() as BoardPlacementZone
	if zone == null or zone not in get_zones():
		push_warning("Select a zone under Zones before pressing Delete Selected Zone.")
		return false
	for socket: BoardPlacementSocket in get_sockets():
		if socket.zone_id == zone.zone_id:
			push_warning(
				"Reassign or delete sockets that still reference zone '%s'." % zone.zone_id
			)
			return false
	zone.get_parent().remove_child(zone)
	zone.free()
	zone_to_delete = null
	queue_redraw()
	update_configuration_warnings()
	return true


func add_socket_from_inspector() -> BoardPlacementSocket:
	return create_socket(
		new_socket_id,
		new_socket_zone_id,
		new_socket_position,
		new_socket_reserve_radius
	)


func create_socket(
	socket_id: StringName,
	zone_id: StringName,
	position_value: Vector2,
	reserve_radius := 72.0
) -> BoardPlacementSocket:
	var root := get_node_or_null(sockets_path) as Node2D
	if root == null or socket_id.is_empty() or zone_id.is_empty():
		push_warning("Socket requires a target root, socket id, and zone id.")
		return null
	for existing: BoardPlacementSocket in get_sockets():
		if existing.socket_id == socket_id:
			push_warning("Socket id '%s' already exists." % socket_id)
			return null
	var has_zone := false
	for zone: BoardPlacementZone in get_zones():
		if zone.zone_id == zone_id:
			has_zone = true
			break
	if not has_zone:
		push_warning("Socket target zone '%s' does not exist." % zone_id)
		return null
	var socket := BoardPlacementSocket.new()
	socket.name = _unique_child_name(root, _pascal_case(String(socket_id)))
	socket.socket_id = socket_id
	socket.zone_id = zone_id
	socket.reserve_radius = reserve_radius
	socket.position = snap_point_to_grid(position_value)
	root.add_child(socket)
	_assign_editor_owner(socket)
	sync_required_socket_count()
	queue_redraw()
	update_configuration_warnings()
	return socket


func delete_selected_socket() -> bool:
	var socket := socket_to_delete
	if socket == null:
		socket = _get_editor_selected_node() as BoardPlacementSocket
	if socket == null or socket not in get_sockets():
		push_warning("Select a socket under Sockets before pressing Delete Selected Socket.")
		return false
	socket.get_parent().remove_child(socket)
	socket.free()
	socket_to_delete = null
	sync_required_socket_count()
	queue_redraw()
	update_configuration_warnings()
	return true


func sync_required_socket_count() -> void:
	required_candidate_sockets = get_sockets().size()
	update_configuration_warnings()


func _get_editor_selected_node() -> Node:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton(&"EditorInterface")
	var selection: Object = editor_interface.call(&"get_selection")
	if selection == null:
		return null
	var nodes: Array = selection.call(&"get_selected_nodes")
	return nodes[0] as Node if not nodes.is_empty() else null


func _assign_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint() or node == null:
		return
	var edited_root := get_tree().edited_scene_root
	if edited_root != null:
		node.owner = edited_root


func _unique_child_name(parent: Node, base_name: String) -> String:
	var candidate := base_name if not base_name.is_empty() else "Item"
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base_name, suffix]
		suffix += 1
	return candidate


func _pascal_case(value: String) -> String:
	var result := ""
	for part: String in value.split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


func set_editing_enabled(value: bool) -> void:
	var changed := editing_enabled != value
	editing_enabled = value
	show_grid = value
	for zone: BoardPlacementZone in get_zones():
		zone.visible = value or (Engine.is_editor_hint() and zone.visible)
	for socket: BoardPlacementSocket in get_sockets():
		socket.visible = value or (Engine.is_editor_hint() and socket.visible)
	for area: BoardForbiddenArea in get_forbidden_areas():
		area.visible = (value and area.show_during_editing) \
			or (Engine.is_editor_hint() and area.visible)
	for placeable: BoardPlaceable in get_placeables():
		placeable.set_committed(not value)
	if changed:
		editing_changed.emit(editing_enabled)


func is_grid_aligned(point: Vector2) -> bool:
	var relative := (point - grid_origin) / grid_cell_size
	return absf(relative.x - roundf(relative.x)) <= 0.5 / grid_cell_size \
		and absf(relative.y - roundf(relative.y)) <= 0.5 / grid_cell_size


func snap_point_to_grid(point: Vector2) -> Vector2:
	var relative := (point - grid_origin) / grid_cell_size
	return grid_origin + Vector2(roundf(relative.x), roundf(relative.y)) \
		* grid_cell_size


func get_grid_points(zone_id: StringName = &"") -> PackedVector2Array:
	var points := PackedVector2Array()
	var boundary := get_boundary()
	if boundary == null:
		return points
	var board_polygon := boundary.get_polygon_in(self)
	if not BoardGeometry.is_valid_polygon(board_polygon):
		return points
	var zone: BoardPlacementZone
	if not zone_id.is_empty():
		for candidate: BoardPlacementZone in get_zones():
			if candidate.zone_id == zone_id:
				zone = candidate
				break
		if zone == null:
			return points
	var zone_polygon := (
		zone.get_polygon_in(self)
		if zone != null
		else PackedVector2Array()
	)
	var bounds := BoardGeometry.polygon_bounds(board_polygon)
	var start_x := floorf((bounds.position.x - grid_origin.x) / grid_cell_size)
	var end_x := ceilf((bounds.end.x - grid_origin.x) / grid_cell_size)
	var start_y := floorf((bounds.position.y - grid_origin.y) / grid_cell_size)
	var end_y := ceilf((bounds.end.y - grid_origin.y) / grid_cell_size)
	for x_index in range(int(start_x), int(end_x) + 1):
		for y_index in range(int(start_y), int(end_y) + 1):
			var point := grid_origin + Vector2(x_index, y_index) * grid_cell_size
			if not BoardGeometry.contains_circle(
				board_polygon,
				point,
				grid_cell_size * 0.5
			):
				continue
			if zone != null and not BoardGeometry.contains_circle(
				zone_polygon,
				point,
				grid_cell_size * 0.5
			):
				continue
			points.append(point)
	return points


func _draw() -> void:
	if not show_grid:
		return
	var visual_size := grid_cell_size - 12.0
	var half_size := Vector2.ONE * visual_size * 0.5
	for zone: BoardPlacementZone in get_zones():
		for point: Vector2 in get_grid_points(zone.zone_id):
			var cell := Rect2(point - half_size, Vector2.ONE * visual_size)
			draw_rect(cell, Color(0.18, 0.58, 0.62, 0.08), true)
			draw_rect(cell, Color(0.40, 0.86, 0.82, 0.34), false, 2.0)


func _get_configuration_warnings() -> PackedStringArray:
	var result := _validator.validate(self)
	return result.to_messages()
