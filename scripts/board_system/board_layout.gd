@tool
class_name BoardLayout
extends Node2D


signal validation_completed(result: BoardValidationResult)
signal editing_changed(is_editing: bool)


const GRID_CELL_SIZE := 144.0
const MAXIMUM_SIMULTANEOUS_PLACEMENTS := 6
const REQUIRED_CANDIDATE_SOCKETS := 12


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


var grid_cell_size: float:
	get:
		return GRID_CELL_SIZE

var maximum_simultaneous_placements: int:
	get:
		return MAXIMUM_SIMULTANEOUS_PLACEMENTS

var required_candidate_sockets: int:
	get:
		return REQUIRED_CANDIDATE_SOCKETS

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
