extends SceneTree


const DEMO_SCENE := preload(
	"res://scenes/boards/repair_part_placement_wave_demo.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred(&"_run")


func _run() -> void:
	var demo := DEMO_SCENE.instantiate() as Node2D
	root.add_child(demo)
	await process_frame
	await process_frame

	var wave := demo.get_node("Wave") as WaveRuntimeCoordinator
	var layout := wave.get_node("RepairBoardLayout") as BoardLayout
	var session := layout.get_node("PlacementSession") as BoardPlacementSession
	var inventory := wave.get_node("RepairPartInventory") as RepairPartInventory
	var hud := wave.get_node(
		"RepairPlacementHUD/RepairPartPlacementHud"
	) as RepairPartPlacementHud
	var bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	var controller := wave.get_node(
		"RepairPartPlacementController"
	) as RepairPartPlacementController
	var camera := wave.get_node("Camera2D") as Camera2D
	var gameplay_camera_position := camera.position
	var gameplay_camera_zoom := camera.zoom

	_test_initial_phase(wave, layout, session, hud)
	_test_board_authoring_contract(layout)
	_test_inventory_states(hud, controller)
	_test_place_remove_and_replace(session, inventory, hud, controller)
	await physics_frame
	await process_frame
	_test_placed_bumper_transform(session)
	_test_commit_flow(
		wave,
		session,
		hud,
		bridge,
		camera,
		gameplay_camera_position,
		gameplay_camera_zoom
	)

	demo.queue_free()
	await process_frame
	_finish()


func _test_initial_phase(
	wave: WaveRuntimeCoordinator,
	layout: BoardLayout,
	session: BoardPlacementSession,
	hud: RepairPartPlacementHud
) -> void:
	_expect(hud.get_design_size() == Vector2(1920.0, 1080.0),
		"Placement UI test viewport must use the 1920x1080 design target.")
	_expect(wave.wave_manager.current_state == WaveManager.State.INACTIVE \
		and wave.wave_manager.current_stage_phase \
			== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Wave entry must stop at repair placement before ball selection.")
	_expect(session.current_state == BoardPlacementSession.State.EDITING,
		"Repair placement session must be editable during the first stage phase.")
	_expect(hud.visible and hud.is_drawer_open(),
		"Placement drawer must start open while its tab remains available.")
	_expect(not wave.wave_hud.visible and not wave.ball_selection_hud.visible,
		"Gameplay HUD layers must be hidden only during repair placement.")
	_expect(layout.get_placeables().is_empty(),
		"The runtime wave layout must start without pre-consumed repair parts.")


func _test_board_authoring_contract(layout: BoardLayout) -> void:
	var result := layout.validate_layout()
	_expect(result.is_valid,
		"Wave repair layout must pass all board rules.\n%s" % result.summary())
	_expect(layout.get_zones().size() == 3,
		"Wave repair layout must expose three translucent placement zones.")
	_expect(layout.get_sockets().size() == 12,
		"Wave repair layout must provide twelve grid-aligned candidate sockets.")
	var board_polygon := layout.get_boundary().get_polygon_in(layout)
	for zone: BoardPlacementZone in layout.get_zones():
		_expect(BoardGeometry.contains_polygon(
			board_polygon,
			zone.get_polygon_in(layout)
		), "Every placement zone must remain inside the playable board wall.")
	for socket: BoardPlacementSocket in layout.get_sockets():
		var local_position := layout.to_local(socket.global_position)
		_expect(layout.is_grid_aligned(local_position),
			"Every socket must remain aligned to the 144px placement grid.")
		_expect(BoardGeometry.contains_circle(
			board_polygon,
			local_position,
			socket.reserve_radius
		), "A socket's complete occupied area must remain inside the board.")
	for first_index in range(layout.get_sockets().size()):
		for second_index in range(first_index + 1, layout.get_sockets().size()):
			var first := layout.get_sockets()[first_index]
			var second := layout.get_sockets()[second_index]
			_expect(first.global_position.distance_to(second.global_position) \
				>= first.reserve_radius + second.reserve_radius,
				"Candidate socket occupied areas must never overlap each other.")


func _test_inventory_states(
	hud: RepairPartPlacementHud,
	controller: RepairPartPlacementController
) -> void:
	var brooch := hud.get_card(&"starlight_brooch")
	var gears := hud.get_card(&"golden_gears")
	var bell := hud.get_card(&"forgotten_star_bell")
	_expect(brooch != null and gears != null and bell != null,
		"Placement drawer must render all three v0.3 repair-part entries.")
	_expect(hud.get_card(&"crescent_needle") == null,
		"Placement drawer must not render the removed Crescent Needle entry.")
	_expect(brooch.disabled and gears.disabled and bell.disabled,
		"No repair part may be selected until a board socket is selected.")
	_expect(gears.get_stack_text() == "×2" and gears.has_layered_stack(),
		"Duplicate repair parts must use a layered corner stack with exact count.")
	hud.toggle_drawer()
	_expect(not hud.is_drawer_open() and hud.visible,
		"Closing the drawer must keep the placement UI and fixed tab available.")
	hud.toggle_drawer()
	_expect(hud.is_drawer_open(),
		"The fixed tab must reopen the sliding inventory drawer.")

	var drag_started := [false]
	var part_dropped := [false]
	hud.part_drag_started.connect(func(_kind_id: StringName) -> void:
		drag_started[0] = true
	)
	hud.part_dropped.connect(func(
		_kind_id: StringName,
		_position: Vector2
	) -> void:
		part_dropped[0] = true
	)
	brooch.interaction_started.emit(&"starlight_brooch", Vector2(100.0, 100.0))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140.0, 140.0)
	hud._input(motion)
	_expect(drag_started[0] and hud.is_drag_ghost_visible(),
		"Dragging a card must show its icon at the pointer and activate sockets.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(140.0, 140.0)
	hud._input(release)
	_expect(part_dropped[0] and not hud.is_drag_ghost_visible(),
		"Dropping a card must clear the pointer icon after emitting its position.")

	_expect(controller.select_socket(&"middle_02"),
		"The controller must expose socket selection without scene-path coupling.")
	_expect(not brooch.disabled,
		"The middle zone must enable its remaining v0.3 repair part.")
	_expect(gears.disabled and bell.disabled,
		"Parts incompatible with the selected zone must remain disabled.")


func _test_place_remove_and_replace(
	session: BoardPlacementSession,
	inventory: RepairPartInventory,
	hud: RepairPartPlacementHud,
	controller: RepairPartPlacementController
) -> void:
	_expect(controller.place_kind_at_socket(
		&"starlight_brooch", &"middle_02"
	), "Click placement must mount a compatible repair part.")
	_expect(session.find_placeable_at_socket(&"middle_02") != null,
		"Placed repair part must occupy the selected socket.")
	_expect(inventory.get_available_count(&"starlight_brooch") == 0,
		"Mounted repair part must be reserved from the inventory immediately.")
	_expect(hud.get_card(&"starlight_brooch").disabled,
		"A zero-count inventory entry must become disabled.")
	_expect(controller.remove_at_socket(&"middle_02"),
		"The placement X action must remove the mounted repair part.")
	_expect(inventory.get_available_count(&"starlight_brooch") == 1,
		"Removed repair part must return to inventory before confirmation.")

	_expect(controller.place_kind_at_socket(
		&"golden_gears", &"lower_02"
	), "A lower-zone socket must accept golden gears.")
	_expect(inventory.get_available_count(&"golden_gears") == 1,
		"One of two stacked gears must remain after initial placement.")
	_expect(controller.place_kind_at_socket(
		&"starlight_brooch", &"upper_02"
	), "An upper-zone socket must accept the Starlight Brooch.")
	_expect(controller.place_kind_at_socket(
		&"forgotten_star_bell", &"upper_02"
	), "Dropping another v0.3 part must replace the socket content.")
	var replacement := session.find_placeable_at_socket(&"upper_02")
	_expect(replacement != null and replacement.get_kind_id() \
		== &"forgotten_star_bell",
		"Replacement must leave only the newly selected repair part on the socket.")
	_expect(inventory.get_available_count(&"starlight_brooch") == 1 \
		and inventory.get_available_count(&"forgotten_star_bell") == 0,
		"Replacement must return the old part and reserve the new part atomically.")


func _test_commit_flow(
	wave: WaveRuntimeCoordinator,
	session: BoardPlacementSession,
	hud: RepairPartPlacementHud,
	bridge: BoardWavePlacementBridge,
	camera: Camera2D,
	gameplay_camera_position: Vector2,
	gameplay_camera_zoom: Vector2
) -> void:
	var placement_ready := [false]
	bridge.placement_ready.connect(func(
		_wave_id: StringName,
		_consumed_counts: Dictionary
	) -> void:
		placement_ready[0] = true
	)
	hud.confirm_requested.emit()
	_expect(placement_ready[0],
		"The visible confirmation button signal must commit through the wave bridge.")
	_expect(session.current_state == BoardPlacementSession.State.COMMITTED,
		"Successful confirmation must lock inventory consumption for this wave.")
	_expect(wave.wave_manager.current_state == WaveManager.State.SELECTING_BALL \
		and wave.wave_manager.current_stage_phase \
			== WaveManager.StagePhase.BALL_SELECTION,
		"Confirmation must advance the current WaveManager to ball selection.")
	_expect(not hud.visible \
		and wave.wave_hud.visible \
		and wave.ball_selection_hud.visible,
		"Placement UI must close and phase-owned gameplay HUDs must return after confirmation.")
	_expect(camera.position.is_equal_approx(gameplay_camera_position) \
		and camera.zoom.is_equal_approx(gameplay_camera_zoom),
		"Placement must preserve the exact gameplay board camera layout.")
	wave.ball_selection_hud.visible = false
	wave.wave_manager.call(
		&"_set_stage_phase",
		WaveManager.StagePhase.WAVE_RESULT
	)
	_expect(not wave.ball_selection_hud.visible,
		"The board bridge must not re-show ball selection HUD in result phases.")


func _test_placed_bumper_transform(session: BoardPlacementSession) -> void:
	for placeable: BoardPlaceable in session.layout.get_placeables():
		var bumper := placeable.get_bumper()
		_expect(bumper != null, "Every placed repair part must contain a Bumper.")
		if bumper == null:
			continue
		_expect(not bumper.sync_to_physics,
			"A runtime-placed Bumper must inherit its placement wrapper transform.")
		_expect(bumper.global_position.is_equal_approx(placeable.global_position),
			"The repair-part Bumper must remain at its socket after physics sync.")
		var physics_transform: Transform2D = PhysicsServer2D.body_get_state(
			bumper.get_rid(),
			PhysicsServer2D.BODY_STATE_TRANSFORM
		)
		_expect(physics_transform.origin.is_equal_approx(placeable.global_position),
			"PhysicsServer2D must register the repair part at its socket, not origin.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: repair_part_placement_ui_test")
		quit(0)
		return
	print("FAIL: repair_part_placement_ui_test (%d failures)" % _failures.size())
	quit(1)
