class_name BoardPlacementValidator
extends RefCounted


const GRID_TOLERANCE := 0.5


func validate(layout: BoardLayout) -> BoardValidationResult:
	var result := BoardValidationResult.new()
	if layout == null:
		result.add_error(&"layout_missing", "BoardLayout is required.")
		return result

	var boundary := layout.get_boundary()
	if boundary == null:
		result.add_error(&"boundary_missing", "BoardBoundary child is required.")
		return result
	var board_polygon := boundary.get_polygon_in(layout)
	if not BoardGeometry.is_valid_polygon(board_polygon):
		result.add_error(
			&"boundary_invalid",
			"Board boundary must be a valid polygon.",
			layout.get_path_to(boundary)
		)
		return result

	if layout.grid_cell_size <= 0.0:
		result.add_error(&"grid_invalid", "Grid cell size must be positive.")
	if layout.maximum_simultaneous_placements < 1:
		result.add_error(&"placement_limit_invalid", "Placement limit must be positive.")

	var zones := layout.get_zones()
	_validate_zones(layout, board_polygon, zones, result)
	_validate_forbidden_areas(layout, board_polygon, result)
	_validate_sockets(layout, board_polygon, zones, result)
	_validate_placeables(layout, board_polygon, zones, result)
	return result


func _validate_zones(
	layout: BoardLayout,
	board_polygon: PackedVector2Array,
	zones: Array[BoardPlacementZone],
	result: BoardValidationResult
) -> void:
	var ids: Dictionary = {}
	for zone: BoardPlacementZone in zones:
		var path := layout.get_path_to(zone)
		if zone.zone_id.is_empty():
			result.add_error(&"zone_id_missing", "Zone id cannot be empty.", path)
		elif ids.has(zone.zone_id):
			result.add_error(
				&"zone_id_duplicate",
				"Zone id '%s' is duplicated." % zone.zone_id,
				path
			)
		else:
			ids[zone.zone_id] = true
		var zone_polygon := zone.get_polygon_in(layout)
		if not BoardGeometry.is_valid_polygon(zone_polygon):
			result.add_error(&"zone_invalid", "Zone polygon is invalid.", path)
		elif not BoardGeometry.contains_polygon(board_polygon, zone_polygon):
			result.add_error(
				&"zone_outside_board",
				"Every placement zone must be fully contained by the board.",
				path
			)


func _validate_forbidden_areas(
	layout: BoardLayout,
	board_polygon: PackedVector2Array,
	result: BoardValidationResult
) -> void:
	var ids: Dictionary = {}
	for area: BoardForbiddenArea in layout.get_forbidden_areas():
		var path := layout.get_path_to(area)
		if area.area_id.is_empty():
			result.add_error(
				&"forbidden_id_missing",
				"Forbidden area id cannot be empty.",
				path
			)
		elif ids.has(area.area_id):
			result.add_error(
				&"forbidden_id_duplicate",
				"Forbidden area id '%s' is duplicated." % area.area_id,
				path
			)
		else:
			ids[area.area_id] = true
		var area_polygon := area.get_polygon_in(layout)
		if not BoardGeometry.is_valid_polygon(area_polygon):
			result.add_error(
				&"forbidden_area_invalid",
				"Forbidden area polygon is invalid.",
				path
			)
		elif not BoardGeometry.contains_polygon(board_polygon, area_polygon):
			result.add_error(
				&"forbidden_area_outside_board",
				"Forbidden areas must be fully contained by the board.",
				path
			)


func _validate_placeables(
	layout: BoardLayout,
	board_polygon: PackedVector2Array,
	zones: Array[BoardPlacementZone],
	result: BoardValidationResult
) -> void:
	var placeables := layout.get_placeables()
	if placeables.size() > layout.maximum_simultaneous_placements:
		result.add_error(
			&"placement_limit_exceeded",
			"At most %d objects may be placed; found %d." % [
				layout.maximum_simultaneous_placements,
				placeables.size(),
			]
		)

	var placement_ids: Dictionary = {}
	for placeable: BoardPlaceable in placeables:
		_validate_placeable(
			layout,
			board_polygon,
			zones,
			placeable,
			placement_ids,
			result
		)

	for first_index in placeables.size():
		var first := placeables[first_index]
		var first_position := layout.to_local(first.global_position)
		for second_index in range(first_index + 1, placeables.size()):
			var second := placeables[second_index]
			var second_position := layout.to_local(second.global_position)
			var minimum_distance := first.reserve_radius + second.reserve_radius
			if first_position.distance_to(second_position) + BoardGeometry.EPSILON \
					< minimum_distance:
				result.add_error(
					&"placement_overlap",
					"Reserved radii overlap '%s' (minimum %.1fpx)." % [
						second.placement_id,
						minimum_distance,
					],
					layout.get_path_to(first)
				)


func _validate_sockets(
	layout: BoardLayout,
	board_polygon: PackedVector2Array,
	zones: Array[BoardPlacementZone],
	result: BoardValidationResult
) -> void:
	var sockets := layout.get_sockets()
	if sockets.size() != layout.required_candidate_sockets:
		result.add_error(
			&"socket_count_invalid",
			"Board requires %d candidate sockets; found %d." % [
				layout.required_candidate_sockets,
				sockets.size(),
			]
		)
	var socket_ids: Dictionary = {}
	for socket: BoardPlacementSocket in sockets:
		var path := layout.get_path_to(socket)
		if socket.socket_id.is_empty():
			result.add_error(&"socket_id_missing", "Socket id cannot be empty.", path)
		elif socket_ids.has(socket.socket_id):
			result.add_error(
				&"socket_id_duplicate",
				"Socket id '%s' is duplicated." % socket.socket_id,
				path
			)
		else:
			socket_ids[socket.socket_id] = true
		var position := layout.to_local(socket.global_position)
		if not BoardGeometry.contains_circle(
			board_polygon,
			position,
			socket.reserve_radius
		):
			result.add_error(
				&"socket_outside_board",
				"The complete socket reserve radius must stay inside the board.",
				path
			)
		var zone := _find_zone(zones, socket.zone_id)
		if zone == null:
			result.add_error(
				&"socket_zone_missing",
				"Socket target zone '%s' does not exist." % socket.zone_id,
				path
			)
		elif not BoardGeometry.contains_circle(
			zone.get_polygon_in(layout),
			position,
			socket.reserve_radius
		):
			result.add_error(
				&"socket_outside_zone",
				"Socket reserve radius must stay inside zone '%s'." % socket.zone_id,
				path
			)
		if not layout.is_grid_aligned(position):
			result.add_error(
				&"socket_off_grid",
				"Socket must align to the %.1fpx board grid." % layout.grid_cell_size,
				path
			)
		_validate_reserved_position(
			layout,
			position,
			socket.reserve_radius,
			path,
			&"socket_in_forbidden_area",
			result
		)
	for first_index in sockets.size():
		var first := sockets[first_index]
		var first_position := layout.to_local(first.global_position)
		for second_index in range(first_index + 1, sockets.size()):
			var second := sockets[second_index]
			var second_position := layout.to_local(second.global_position)
			var minimum_distance := first.reserve_radius + second.reserve_radius
			if first_position.distance_to(second_position) + BoardGeometry.EPSILON \
					< minimum_distance:
				result.add_error(
					&"socket_overlap",
					"Socket reserve radii overlap '%s' (minimum %.1fpx)." % [
						second.socket_id,
						minimum_distance,
					],
					layout.get_path_to(first)
				)

func _validate_placeable(
	layout: BoardLayout,
	board_polygon: PackedVector2Array,
	zones: Array[BoardPlacementZone],
	placeable: BoardPlaceable,
	placement_ids: Dictionary,
	result: BoardValidationResult
) -> void:
	var path := layout.get_path_to(placeable)
	if placeable.placement_id.is_empty():
		result.add_error(&"placement_id_missing", "Placement id cannot be empty.", path)
	elif placement_ids.has(placeable.placement_id):
		result.add_error(
			&"placement_id_duplicate",
			"Placement id '%s' is duplicated." % placeable.placement_id,
			path
		)
	else:
		placement_ids[placeable.placement_id] = true

	if not placeable.is_repair_part():
		result.add_error(
			&"not_repair_part",
			"Placed bumper must have settings.is_repair_part enabled.",
			path
		)

	var position := layout.to_local(placeable.global_position)
	if not BoardGeometry.contains_circle(
		board_polygon,
		position,
		placeable.reserve_radius
	):
		result.add_error(
			&"placement_outside_board",
			"The complete reserved radius must stay inside the board.",
			path
		)

	var zone := _find_zone(zones, placeable.zone_id)
	if zone == null:
		result.add_error(
			&"placement_zone_missing",
			"Target zone '%s' does not exist." % placeable.zone_id,
			path
		)
	else:
		var zone_polygon := zone.get_polygon_in(layout)
		if not BoardGeometry.contains_circle(
			zone_polygon,
			position,
			placeable.reserve_radius
		):
			result.add_error(
				&"placement_outside_zone",
				"The complete reserved radius must stay inside zone '%s'." \
					% placeable.zone_id,
				path
			)
		if not zone.accepts(placeable):
			result.add_error(
				&"placement_kind_forbidden",
				"Zone '%s' does not allow repair part '%s'." % [
					placeable.zone_id,
					placeable.get_kind_id(),
				],
				path
			)

	if not layout.is_grid_aligned(position):
		result.add_error(
			&"placement_off_grid",
			"Placement must align to the %.1fpx board grid." % layout.grid_cell_size,
			path
		)
	var socket := _find_socket(layout.get_sockets(), placeable.socket_id)
	if placeable.socket_id.is_empty() or socket == null or not socket.enabled:
		result.add_error(
			&"placement_socket_missing",
			"Every placement must reference an enabled candidate socket.",
			path
		)
	elif socket.zone_id != placeable.zone_id \
			or layout.to_local(socket.global_position).distance_to(position) \
				> GRID_TOLERANCE:
		result.add_error(
			&"placement_socket_mismatch",
			"Placement must occupy its socket and use the same zone.",
			path
		)

	_validate_reserved_position(
		layout,
		position,
		placeable.reserve_radius,
		path,
		&"placement_in_forbidden_area",
		result
	)


func _validate_reserved_position(
	layout: BoardLayout,
	position: Vector2,
	reserve_radius: float,
	path: NodePath,
	error_code: StringName,
	result: BoardValidationResult
) -> void:
	for area: BoardForbiddenArea in layout.get_forbidden_areas():
		var area_polygon := area.get_polygon_in(layout)
		var blocked_distance := reserve_radius + area.extra_clearance
		if BoardGeometry.contains_point(area_polygon, position) \
				or BoardGeometry.distance_to_edges(area_polygon, position) \
					<= blocked_distance:
			result.add_error(
				error_code,
				"Reserved radius intersects '%s': %s" % [
					area.area_id,
					area.reason,
				],
				path
			)


func _find_zone(
	zones: Array[BoardPlacementZone],
	zone_id: StringName
) -> BoardPlacementZone:
	for zone: BoardPlacementZone in zones:
		if zone.zone_id == zone_id:
			return zone
	return null


func _find_socket(
	sockets: Array[BoardPlacementSocket],
	socket_id: StringName
) -> BoardPlacementSocket:
	for socket: BoardPlacementSocket in sockets:
		if socket.socket_id == socket_id:
			return socket
	return null
