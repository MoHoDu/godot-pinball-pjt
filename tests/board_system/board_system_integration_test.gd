extends SceneTree


const LAYOUT_SCENE := preload("res://Resources/Prefabs/boards/square_board_layout.tscn")
const WAVE_INTEGRATION_SCENE := preload(
	"res://scenes/tests/boards/board_system_wave_integration.tscn"
)
const BROOCH_SCENE := preload(
	"res://Resources/Prefabs/repair_parts/placeables/starlight_brooch_placeable.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_layout_contract()
	await _test_invalid_authoring_preflight()
	await _test_placement_session()
	await _test_wave_bridge()
	_finish()


func _test_layout_contract() -> void:
	var layout := LAYOUT_SCENE.instantiate() as BoardLayout
	root.add_child(layout)
	await process_frame

	var result := layout.validate_layout()
	_expect(result.is_valid, "Authored square board layout must pass pre-save validation.\n%s" \
		% result.summary())
	var boundary := layout.get_boundary()
	_expect(boundary != null and boundary.polygon.size() == 8,
		"Square board must use the planned eight-edge boundary.")
	_expect(layout.get_zones().size() == 3,
		"Board must expose upper, middle, and lower authoring zones.")
	_expect(layout.get_sockets().size() == 12,
		"Board must expose twelve candidate repair sockets.")
	_expect(layout.get_placeables().size() == 6,
		"Demo layout must exercise the simultaneous placement cap of six.")

	var board_polygon := boundary.get_polygon_in(layout)
	for zone: BoardPlacementZone in layout.get_zones():
		_expect(BoardGeometry.contains_polygon(
			board_polygon,
			zone.get_polygon_in(layout)
		), "Every authored zone must be contained by the board.")
		for point: Vector2 in layout.get_grid_points(zone.zone_id):
			_expect(BoardGeometry.contains_point(board_polygon, point),
				"Every generated grid point must stay inside the board.")
	for socket: BoardPlacementSocket in layout.get_sockets():
		var position := layout.to_local(socket.global_position)
		_expect(BoardGeometry.contains_circle(
			board_polygon,
			position,
			socket.reserve_radius
		), "Every complete socket reserve radius must stay inside the board.")
	for placeable: BoardPlaceable in layout.get_placeables():
		_expect(placeable.is_repair_part(),
			"Every board placeable must wrap a Bumper with is_repair_part=true.")

	layout.queue_free()
	await process_frame


func _test_invalid_authoring_preflight() -> void:
	var layout := LAYOUT_SCENE.instantiate() as BoardLayout
	root.add_child(layout)
	await process_frame

	var upper := layout.get_zones()[0]
	var original_polygon := upper.polygon
	upper.polygon = PackedVector2Array([
		Vector2(-1400.0, -450.0),
		Vector2(700.0, -450.0),
		Vector2(700.0, -120.0),
		Vector2(-700.0, -120.0),
	])
	var result := layout.validate_layout()
	_expect(_has_issue(result, &"zone_outside_board"),
		"Pre-save validation must reject zones extending outside the board.")
	upper.polygon = original_polygon

	var first_socket := layout.get_sockets()[0]
	var original_socket_position := first_socket.position
	first_socket.position = Vector2(-1200.0, -288.0)
	result = layout.validate_layout()
	_expect(_has_issue(result, &"socket_outside_board"),
		"Pre-save validation must reject socket reserve radii outside the board.")
	first_socket.position = original_socket_position
	var sockets_root := first_socket.get_parent()
	sockets_root.remove_child(first_socket)
	result = layout.validate_layout()
	_expect(_has_issue(result, &"socket_count_invalid"),
		"Pre-save validation must require the configured twelve sockets.")
	sockets_root.add_child(first_socket)
	first_socket.position = original_socket_position

	var first := layout.get_placeables()[0]
	var second := layout.get_placeables()[1]
	var original_second_position := second.position
	second.position = first.position
	result = layout.validate_layout()
	_expect(_has_issue(result, &"placement_overlap"),
		"Pre-save validation must reject overlapping placement reservations.")
	second.position = original_second_position

	var original_first_position := first.position
	first.position += Vector2(1.0, 0.0)
	result = layout.validate_layout()
	_expect(_has_issue(result, &"placement_off_grid"),
		"Placement grid alignment must not be bypassable.")
	first.position = original_first_position

	var original_socket_id := first.socket_id
	first.socket_id = &""
	result = layout.validate_layout()
	_expect(_has_issue(result, &"placement_socket_missing"),
		"Every placement must reference one of the candidate sockets.")
	first.socket_id = original_socket_id

	first.position = Vector2.ZERO
	result = layout.validate_layout()
	_expect(_has_issue(result, &"placement_in_forbidden_area"),
		"Reserved gameplay areas must reject runtime placements.")
	first.position = original_first_position

	var bumper := first.get_bumper()
	var original_settings := bumper.settings
	bumper.settings = bumper.settings.duplicate(true) as BumperSettings
	bumper.settings.is_repair_part = false
	result = layout.validate_layout()
	_expect(_has_issue(result, &"not_repair_part"),
		"Only Bumpers whose settings.is_repair_part is true may be placed.")
	bumper.settings = original_settings

	var seventh := BROOCH_SCENE.instantiate() as BoardPlaceable
	seventh.name = "SeventhPlacement"
	seventh.placement_id = &"seventh_placement"
	seventh.zone_id = &"upper"
	seventh.socket_id = &"upper_02"
	seventh.position = Vector2(-144.0, -288.0)
	layout.get_node("Placeables").add_child(seventh)
	result = layout.validate_layout()
	_expect(_has_issue(result, &"placement_limit_exceeded"),
		"Pre-save validation must enforce the simultaneous cap of six.")
	seventh.queue_free()
	await process_frame

	result = layout.validate_layout()
	_expect(result.is_valid,
		"Restored authored layout must become valid again.\n%s" % result.summary())
	layout.queue_free()
	await process_frame


func _test_placement_session() -> void:
	var layout := LAYOUT_SCENE.instantiate() as BoardLayout
	root.add_child(layout)
	await process_frame
	var session := layout.get_node("PlacementSession") as BoardPlacementSession
	var committed_counts := [{}]
	session.placement_committed.connect(func(
		_wave_id: StringName,
		_placements: Array[Dictionary],
		consumed_counts: Dictionary
	) -> void:
		committed_counts[0] = consumed_counts
	)
	_expect(session.begin_placement(&"test_wave"),
		"Placement session must enter the first-launch editing state.")
	_expect(session.current_state == BoardPlacementSession.State.EDITING,
		"Placement session must expose EDITING before the first launch.")
	var removed := layout.get_placeables()[0]
	var reclaimed_socket := removed.socket_id
	_expect(session.remove_placeable(removed),
		"Editing session must allow a placed repair part to return to inventory.")
	await process_frame
	var replacement := session.place_scene_at_socket(BROOCH_SCENE, reclaimed_socket)
	_expect(replacement != null,
		"Editing session must place a selected repair-part prefab in an empty socket.")
	_expect(session.move_placeable_to_socket(replacement, &"upper_02"),
		"Editing session must move a selected repair part to an empty socket.")
	_expect(session.commit(),
		"Valid placement session must commit successfully.")
	_expect(session.current_state == BoardPlacementSession.State.COMMITTED,
		"Successful preflight must transition the session to COMMITTED.")
	var counts: Dictionary = committed_counts[0]
	_expect(int(counts.get(&"golden_gears", 0)) == 2 \
		and int(counts.get(&"crescent_needle", 0)) == 2 \
		and int(counts.get(&"starlight_brooch", 0)) == 1 \
		and int(counts.get(&"forgotten_star_bell", 0)) == 1,
		"Commit snapshot must report exact repair-part consumption counts.")
	_expect(session.lock(),
		"First launch must be able to lock a committed placement session.")
	_expect(not session.begin_placement(&"lock_bypass"),
		"A committed or locked session must not re-enter editing without end_wave().")
	var committed_transform := replacement.transform
	replacement.position += Vector2(144.0, 0.0)
	await process_frame
	_expect(replacement.transform.is_equal_approx(committed_transform),
		"Committed placement transforms must be restored while locked.")
	_expect(not session.move_placeable_to_socket(replacement, &"upper_03") \
		and not session.remove_placeable(replacement) \
		and session.place_scene_at_socket(BROOCH_SCENE, &"upper_03") == null,
		"Move, remove, and add APIs must all reject changes after commit.")
	layout.queue_free()
	await process_frame


func _test_wave_bridge() -> void:
	var integration := WAVE_INTEGRATION_SCENE.instantiate() as Node2D
	root.add_child(integration)
	await process_frame
	await process_frame
	var wave := integration.get_node("Wave") as WaveRuntimeCoordinator
	var layout := wave.get_node("RepairBoardLayout") as BoardLayout
	var session := layout.get_node("PlacementSession") as BoardPlacementSession
	var bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge

	_expect(wave.wave_manager.current_state == WaveManager.State.INACTIVE,
		"Repair placement must keep ball flow inactive before confirmation.")
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Composed board scene must enter the latest repair-placement phase.")
	_expect(session.current_state == BoardPlacementSession.State.EDITING,
		"Wave entry must open board placement before the first ball.")
	_expect(layout.get_zones()[0].visible and layout.get_sockets()[0].visible,
		"Placement zones and sockets must be visible only while editing.")
	_expect(not wave.wave_hud.visible \
		and wave.get_node(
			"RepairPlacementHUD/RepairPartPlacementHud"
		).visible,
		"Repair placement must hide gameplay HUD and show placement UI.")
	_expect(bridge.commit_placement(),
		"Valid composed board layout must commit through the wave bridge.")
	_expect(wave.wave_manager.current_state == WaveManager.State.SELECTING_BALL \
		and wave.wave_manager.current_stage_phase \
			== WaveManager.StagePhase.BALL_SELECTION,
		"Board commit must advance the latest WaveManager into ball selection.")
	_expect(session.current_state == BoardPlacementSession.State.COMMITTED,
		"Wave bridge must preserve committed state until first launch.")
	_expect(_placement_guides_hidden(layout),
		"Committed layouts must hide every placement guide before gameplay.")
	_expect(wave.wave_hud.visible \
		and wave.ball_selection_hud.visible \
		and not wave.get_node(
			"RepairPlacementHUD/RepairPartPlacementHud"
		).visible,
		"Gameplay HUD must return without changing the board layout.")
	_expect(wave.wave_ball_flow.confirm_selection(),
		"Existing ball selection must resume after board commit.")
	_expect(wave.launcher.launch_prepared_ball(),
		"The composed scene must launch the prepared first ball.")
	_expect(session.current_state == BoardPlacementSession.State.LOCKED,
		"Actual first-ball launch must transition board placement to LOCKED.")
	_expect(_placement_guides_hidden(layout),
		"Locked in-play layouts must keep every placement guide hidden.")

	integration.queue_free()
	await process_frame


func _has_issue(result: BoardValidationResult, code: StringName) -> bool:
	for issue: Dictionary in result.issues:
		if StringName(issue.get(&"code", &"")) == code:
			return true
	return false


func _placement_guides_hidden(layout: BoardLayout) -> bool:
	if layout.show_grid:
		return false
	for zone: BoardPlacementZone in layout.get_zones():
		if zone.visible:
			return false
	for socket: BoardPlacementSocket in layout.get_sockets():
		if socket.visible:
			return false
	for area: BoardForbiddenArea in layout.get_forbidden_areas():
		if area.visible:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: board_system_integration_test")
		quit(0)
		return
	print("FAIL: board_system_integration_test (%d failures)" % _failures.size())
	quit(1)
