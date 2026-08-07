extends SceneTree


const WAVE_SCENE := "res://scenes/wave/wave.tscn"
const WAVE_NORMAL_BALL_SCENE := \
	"res://Resources/balls/mass_var/normal_ball.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(WAVE_SCENE) as PackedScene
	_expect(packed != null and packed.can_instantiate(),
		"Wave scene must load and instantiate.")
	if packed == null or not packed.can_instantiate():
		_finish()
		return

	var wave := packed.instantiate() as WaveRuntimeCoordinator
	root.add_child(wave)
	await process_frame
	await process_frame

	_test_standalone_scene_source()
	_test_repair_content_configuration(wave)
	_test_scene_structure(wave)
	_test_korean_selection_hud(wave)
	_test_bumper_loadout(wave)
	await _test_low_speed_wave_balls_release_from_flipper(wave)
	await _test_board_camera_safe_area(wave)
	_test_combo_and_score_connection(wave)
	await _test_life_connection(wave)
	await _test_pause_connection(wave)
	await _test_bumper_runtime_integration(wave)
	await _test_world_anchor_and_hit_fade(wave)

	wave.queue_free()
	await process_frame
	_finish()


func _test_standalone_scene_source() -> void:
	var scene_source := FileAccess.get_file_as_string(WAVE_SCENE)
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/wave_hud/wave_runtime_coordinator.gd"
	)
	var manager_source := FileAccess.get_file_as_string(
		"res://scripts/ball_base_system/wave_manager.gd"
	)
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/ball_base_system/wave_ball_flow_controller.gd"
	)
	_expect(scene_source.contains("[node name=\"Wave\" type=\"Node2D\""),
		"Wave scene root must be authored directly as Node2D.")
	_expect(not scene_source.contains("res://scenes/test_flipper/"),
		"Wave scene must not inherit or instance a test board.")
	_expect(not scene_source.contains("res://tests/"),
		"Wave scene resources must not depend on test code.")
	_expect(not coordinator_source.contains("res://tests/"),
		"Wave runtime coordinator must not inherit test code.")
	_expect(not coordinator_source.contains("get_node_or_null("),
		"Wave runtime coordinator must use typed Inspector references.")
	_expect(not manager_source.contains("@export_node_path") \
		and not manager_source.contains("get_node_or_null("),
		"Wave manager dependencies must not rely on string node paths.")
	_expect(not flow_source.contains("@export_node_path") \
		and not flow_source.contains("get_node_or_null("),
		"Ball flow dependencies must not rely on string node paths.")
	_expect(scene_source.contains(
		"res://scripts/select_ball/select_ball_inventory.gd"
	), "Wave scene must use the unique-owned-ball inventory.")
	_expect(scene_source.contains(
		"res://scripts/select_ball/select_ball_flow_controller.gd"
	), "Wave scene must mark balls used only after an actual launch.")
	_expect(scene_source.contains(
		"res://scenes/select-ball/select_ball_selection_hud.tscn"
	), "Wave scene must use the confirmed ball-selection HUD.")
	_expect(scene_source.contains(
		"res://Resources/boards/wave_repair_board_layout.tscn"
	), "Wave scene must own the repair-part board layout.")
	_expect(scene_source.contains(
		"res://scripts/board_system/board_wave_placement_bridge.gd"
	), "Wave scene must bridge repair placement to the active WaveManager.")
	_expect(scene_source.contains(
		"res://scripts/repair_parts/runtime/repair_effect_router.gd"
	), "Wave scene must route the latest repair-part effects.")


func _test_repair_content_configuration(wave: WaveRuntimeCoordinator) -> void:
	var inventory := wave.get_node("RepairPartInventory") as RepairPartInventory
	var part_ids: Array[StringName] = []
	for item: Dictionary in inventory.get_snapshot():
		part_ids.append(StringName(item[&"kind_id"]))
	_expect(part_ids.size() == 3,
		"Wave repair inventory must expose the three v0.3 part families.")
	_expect(&"starlight_brooch" in part_ids \
		and &"golden_gears" in part_ids \
		and &"forgotten_star_bell" in part_ids,
		"Wave repair inventory must contain brooch, gears, and bell.")
	_expect(&"crescent_needle" not in part_ids,
		"Crescent Needle must not remain in the v0.3 repair inventory.")
	_expect(inventory.total_count == 0,
		"A fresh stage must begin without free repair parts.")
	inventory.add(&"starlight_brooch", 1)
	# 배치 세션은 씬 시작 시점의 0개 재고를 이미 예약했습니다. 이 테스트가
	# 주입한 부품을 반영하도록 동일 웨이브의 배치 세션만 다시 엽니다.
	var session := wave.get_node(
		"RepairBoardLayout/PlacementSession"
	) as BoardPlacementSession
	var placement_bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	inventory.cancel_reservation()
	session.end_wave()
	placement_bridge.call(&"_begin_placement", &"wave_0")

	var placement_controller := wave.get_node(
		"RepairPartPlacementController"
	) as RepairPartPlacementController
	_expect(placement_controller.place_kind_at_socket(
		&"starlight_brooch", &"middle_02"
	), "Wave placement must accept the latest Starlight Brooch scene.")
	var layout := wave.get_node("RepairBoardLayout") as BoardLayout
	session = layout.get_node("PlacementSession") as BoardPlacementSession
	var placeable := session.find_placeable_at_socket(&"middle_02")
	var bumper := placeable.get_bumper() if placeable != null else null
	var runtime := bumper.get_node_or_null(^"RepairPartRuntime") \
		as RepairPartRuntime if bumper != null else null
	_expect(runtime != null,
		"Placed Wave parts must include the v0.3 RepairPartRuntime.")
	_expect(bumper != null and bumper.get_node_or_null(^"_ArtSprite") != null,
		"Placed Wave parts must include their latest production art.")
	_expect(bumper != null and bumper.combo_hit_source is RepairPartHitSource,
		"Placed Wave parts must use the v0.3 contact gate.")


func _test_scene_structure(wave: WaveRuntimeCoordinator) -> void:
	_expect(String(ProjectSettings.get_setting(&"application/run/main_scene")) == WAVE_SCENE,
		"The project main scene must run the integrated Wave HUD scene.")
	_expect(wave.get_node_or_null("HUD/GuideLabel") == null,
		"Standalone Wave scene must not retain the legacy guide HUD.")
	_expect(wave.get_node_or_null("HUD/ComboHud") == null,
		"Standalone Wave scene must not retain the legacy ComboHud.")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"target_score"]) == 0,
		"Repair placement must begin before a wave target is configured.")
	_expect((snapshot[&"life_slots"] as Array).size() == 3,
		"Runtime session must expose the three launches available per wave.")
	_expect(wave.wave_ball_inventory.get_owned_definitions().size() == 1,
		"A fresh stage must begin with only the normal ball owned.")
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Integrated Wave scene must begin at repair placement.")
	var layout := wave.get_node("RepairBoardLayout") as BoardLayout
	var session := layout.get_node("PlacementSession") as BoardPlacementSession
	var placement_hud := wave.get_node(
		"RepairPlacementHUD/RepairPartPlacementHud"
	) as RepairPartPlacementHud
	var placement_bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(session.current_state == BoardPlacementSession.State.EDITING,
		"Integrated Wave scene must open its real repair placement session.")
	_expect(placement_hud.visible \
		and not wave.wave_hud.visible \
		and not wave.ball_selection_hud.visible,
		"Repair placement must exclusively own the HUD before confirmation.")
	_expect(placement_bridge.commit_placement(),
		"Wave integration must advance only through a valid placement commit.")
	var placed := session.find_placeable_at_socket(&"middle_02")
	var placed_bumper := placed.get_bumper() if placed != null else null
	var placed_runtime := placed_bumper.get_node_or_null(^"RepairPartRuntime") \
		as RepairPartRuntime if placed_bumper != null else null
	var repair_router := wave.get_node(
		"WaveRepairEffects/RepairEffectRouter"
	) as RepairEffectRouter
	_expect(placement_bridge.repair_effect_router == repair_router,
		"Wave placement bridge must target the live repair-effect router.")
	_expect(placed_runtime != null \
		and repair_router.get_effect_for(placed_runtime) != null,
		"Committed Wave parts must register their v0.3 gameplay effect.")
	_expect(wave.wave_manager.current_state == WaveManager.State.SELECTING_BALL,
		"Placement confirmation must advance into the implemented selection flow.")
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.BALL_SELECTION,
		"Wave manager must report the implemented ball-selection phase.")
	_expect(not placement_hud.visible \
		and wave.wave_hud.visible \
		and wave.ball_selection_hud.visible,
		"Placement HUD must yield to the wave and ball-selection HUDs.")
	snapshot = wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"target_score"]) == 250000,
		"Wave 1 target must come from ComboStageSettings through the controller.")
	_expect(wave.find_children("WaveManager", "", true, false).size() == 1,
		"Integrated Wave scene must contain one WaveManager.")
	_expect(wave.find_children("WaveBallFlowController", "", true, false).size() == 1,
		"Integrated Wave scene must contain one ball flow controller.")
	_expect(wave.find_children("ComboWaveController", "", true, false).size() == 1,
		"Integrated Wave scene must contain one combo wave policy.")


func _test_korean_selection_hud(wave: WaveRuntimeCoordinator) -> void:
	var hud := wave.ball_selection_hud as SelectBallSelectionHud
	_expect(hud != null,
		"Wave scene must use the detailed select-ball HUD implementation.")
	if hud == null:
		return
	_expect(hud.visible,
		"Ball selection HUD must be visible while choosing the first ball.")
	_expect(hud.title_label.text == "다음 공 선택",
		"Ball selection title must retain the authored Korean copy.")
	_expect(hud.ball_name_label.text == "보통 공",
		"A fresh stage must select the authored Korean normal-ball label.")
	_expect(not hud.stock_label.visible,
		"Unique owned balls must not expose legacy quantity information.")
	_expect(hud.mass_label.text.begins_with("무게 "),
		"Ball selection HUD must expose the selected ball mass.")
	_expect(hud.elasticity_label.text.begins_with("탄성 "),
		"Ball selection HUD must expose the selected ball elasticity.")
	_expect(not hud.feature_label.text.strip_edges().is_empty(),
		"Ball selection HUD must expose one concise feature summary.")
	_expect(hud.guide_label.text.contains("Space: 선택 확정") \
		and hud.guide_label.text.contains("기존 입력"),
		"Ball selection guide must separate confirmation from aiming and launch.")


func _test_bumper_loadout(wave: WaveRuntimeCoordinator) -> void:
	var bumpers := wave.get_bumpers()
	_expect(bumpers.size() == 6,
		"Standalone Wave 3 board must contain six production bumpers.")
	_expect(wave.is_current_bumper_loadout_valid(),
		"Authored bumpers must satisfy the Stage 01 Wave 3 loadout contract.")
	var normal_count := 0
	var bounce_count := 0
	var shot_count := 0
	var wave_cannon: ShotBumper
	var kind_counts: Dictionary = {}
	for bumper: Bumper in bumpers:
		_expect(bumper.get_script() != null,
			"Every authored bumper must use the production Bumper runtime.")
		_expect(bumper.combo_hit_source != null,
			"Every authored bumper must expose a ComboHitSource.")
		_expect(bumper.settings.object_settings != null \
			and bumper.settings.common_settings != null \
			and bumper.settings.type_settings != null,
			"Every Wave bumper must use the integrated three-part settings bundle.")
		var kind_id := bumper.settings.bumper_kind_id
		kind_counts[kind_id] = int(kind_counts.get(kind_id, 0)) + 1
		match bumper.settings.bumper_type:
			BumperSettings.BumperType.NORMAL:
				normal_count += 1
			BumperSettings.BumperType.BOUNCE:
				bounce_count += 1
			BumperSettings.BumperType.SHOT:
				shot_count += 1
				if bumper is ShotBumper:
					wave_cannon = bumper as ShotBumper
	_expect(normal_count == 3 and bounce_count == 2 and shot_count == 1,
		"Wave 3 must expose three Normal, two Bounce, and one Shot bumper.")
	_expect(kind_counts == {
		&"stage01_button": 2,
		&"stage01_cotton": 1,
		&"stage01_spring_doll": 1,
		&"stage01_toy_drum": 1,
		&"stage01_clockwork_cannon": 1,
	}, "Wave 3 must contain the exact authored Stage 01 bumper kinds.")
	_expect(wave_cannon != null,
		"Wave 3 Shot loadout must use the integrated clockwork cannon runtime.")
	if wave_cannon != null:
		_expect(wave_cannon.get_launch_anchors().size() == 7,
			"Wave clockwork cannon must expose all seven authored directions.")
		_expect(is_equal_approx(wave_cannon.get_selection_duration(), 2.0),
			"Wave clockwork cannon must keep the confirmed 2.0 second selection.")
		_expect(is_equal_approx(wave_cannon.get_launch_speed(), 1300.0),
			"Wave clockwork cannon must keep its authored launch speed.")


func _test_low_speed_wave_balls_release_from_flipper(
	wave: WaveRuntimeCoordinator
) -> void:
	var flipper := wave.get_node(
		"FlipperSelector/BottomController/RightFlipper"
	) as PinballFlipper
	_expect(flipper != null, "Wave board must expose the bottom-right flipper.")
	if flipper == null:
		return

	var registered_flippers := get_nodes_in_group(&"combo_flippers")
	for node: Node in registered_flippers:
		(node as PinballFlipper).set_physics_process(false)
	flipper.set_physics_process(true)

	var packed_ball := load(WAVE_NORMAL_BALL_SCENE) as PackedScene
	var ball := packed_ball.instantiate() as Pinball
	wave.add_child(ball)
	ball.freeze = true
	# 첨부 이미지처럼 우측 하단 플리퍼 끝의 둥근 면에 저속으로 붙은 위치입니다.
	#
	# 원래는 전역 오프셋 (-220, 60) 을 그대로 더했습니다. 그때 플리퍼는 회전 0 이라
	# 전역과 로컬이 같았기 때문입니다. wave01 보드를 들여오면서 플리퍼가 ±40도로
	# 눕고 길이도 328 -> 360 이 되어, 같은 전역 오프셋은 플리퍼 바깥 허공을 짚습니다.
	#
	# 그래서 **플리퍼 로컬 좌표**로 잡습니다. 날은 로컬 -X 로 뻗어 끝이 x=-245,
	# 윗면이 y=-18 근처입니다. (-200, -50) 은 끝의 둥근 면 바로 위로,
	# 실측에서 10 물리프레임 뒤 속도 8 안팎으로 안착합니다.
	ball.global_position = flipper.to_global(Vector2(-200.0, -50.0))
	ball.linear_velocity = Vector2.ZERO
	await physics_frame
	ball.freeze = false
	ball.sleeping = false
	for _settle_frame in 10:
		await physics_frame

	var stuck_position := ball.global_position
	_expect(ball.linear_velocity.length() < 80.0,
		"Wave regression ball must settle at low speed before activation. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	var activated := flipper.request_activation(
		PinballFlipper.issue_activation_token()
	)
	_expect(activated, "The Wave flipper must accept a low-speed release activation.")
	var peak_release_speed := 0.0
	for _active_frame in 15:
		await physics_frame
		peak_release_speed = maxf(peak_release_speed, ball.linear_velocity.length())

	var ball_collision := ball.get_node("CollisionShape2D") as CollisionShape2D
	var ball_circle := ball_collision.shape as CircleShape2D
	var ball_radius := ball_circle.radius * ball_collision.global_scale.abs().x
	_expect(ball.global_position.distance_to(stuck_position) >= 48.0,
		"A low-speed Wave ball must physically separate from the flipper. " \
		+ "(start=%s, end=%s)" % [stuck_position, ball.global_position])
	_expect(not flipper.is_circle_overlapping_at_rotation(
		ball_collision.global_position,
		ball_radius,
		flipper.rotation
	), "A released Wave ball must not remain overlapping the active flipper.")
	var minimum_active_hit_speed := float(
		flipper.state_rules.get(&"minimum_active_hit_speed")
	)
	_expect(peak_release_speed + 0.1 >= minimum_active_hit_speed,
		"A low-speed Wave flipper hit must reach the shared minimum active hit speed. " \
		+ "(minimum=%s, peak=%s)" % [
			minimum_active_hit_speed,
			peak_release_speed,
		])
	ball.queue_free()
	await process_frame

	for node: Node in registered_flippers:
		if is_instance_valid(node):
			(node as PinballFlipper).set_physics_process(true)


func _test_board_camera_safe_area(wave: WaveRuntimeCoordinator) -> void:
	wave.call(&"_fit_board_camera", true)
	var camera := wave.board_camera
	_expect(camera != null, "Wave board must expose its responsive Camera2D.")
	if camera == null:
		return
	_expect(is_equal_approx(camera.zoom.x, camera.zoom.y),
		"Responsive board camera must preserve the board aspect ratio.")
	_expect(camera.zoom.x <= wave.maximum_board_zoom,
		"Responsive board camera must not enlarge past the authored maximum zoom.")

	var viewport_size := wave.get_viewport_rect().size
	var design_scale := wave.wave_hud.get_design_scale()
	var design_offset := wave.wave_hud.get_design_offset()
	var safe_top := design_offset.y + wave.hud_safe_top_design * design_scale
	var safe_bottom := viewport_size.y - design_offset.y \
		- wave.board_margin_design * design_scale
	var bounds: Rect2 = wave.board_world_bounds
	var projected_top := viewport_size.y * 0.5 \
		+ (bounds.position.y - camera.position.y) * camera.zoom.y
	var projected_bottom := viewport_size.y * 0.5 \
		+ (bounds.end.y - camera.position.y) * camera.zoom.y
	_expect(projected_top + 0.5 >= safe_top,
		"Board top must stay below the top HUD safe area.")
	_expect(projected_bottom - 0.5 <= safe_bottom,
		"Board bottom must remain inside the available viewport.")

	var original_size := root.size
	root.size = Vector2i(720, 1280)
	await process_frame
	viewport_size = wave.get_viewport_rect().size
	design_scale = minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	design_offset = (viewport_size - Vector2(1920.0, 1080.0) * design_scale) * 0.5
	safe_top = design_offset.y + wave.hud_safe_top_design * design_scale
	projected_top = viewport_size.y * 0.5 \
		+ (bounds.position.y - camera.position.y) * camera.zoom.y
	_expect(projected_top + 0.5 >= safe_top,
		"A live portrait resize must immediately keep the board below the HUD.")
	_expect(is_equal_approx(camera.zoom.x, camera.zoom.y),
		"A live resize must preserve uniform camera scaling.")
	root.size = original_size
	await process_frame


func _test_combo_and_score_connection(wave: WaveRuntimeCoordinator) -> void:
	var source := wave.get_node("Bumpers/BumperCenter/ComboHitSource") as ComboHitSource
	for contact_id in range(1, 6):
		source.register_contact(contact_id)
		source.release_contact(contact_id)
	_expect(wave.combo_system.combo_count == 5,
		"Bound real bumper source must register each released contact exactly once.")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"active_combo"]) == 5,
		"Active combo signal must reach the HUD state source.")
	_expect(int(snapshot[&"max_combo"]) == 5,
		"Wave max combo must accumulate from actual ComboSystem signals.")
	var combo_hud := wave.get_node(
		"HUD/WaveHud/DesignSpace/WorldComboHud"
	) as WaveWorldComboHud
	_expect(not combo_hud.visible,
		"A synthetic combo without an active ball must not show a stale world anchor.")

	var settlement_snapshots: Array[Dictionary] = []
	wave.hud_state.snapshot_changed.connect(func(next_snapshot: Dictionary) -> void:
		settlement_snapshots.append(next_snapshot)
	)
	var awarded := wave.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_expect(awarded > 0, "Combo settlement must award actual score.")
	snapshot = wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"current_score"]) == wave.combo_system.total_score,
		"Actual settled score must reach the HUD snapshot.")
	_expect(int(snapshot[&"max_combo"]) == 5,
		"Settlement must not erase the displayed wave max combo.")
	_expect(not combo_hud.visible,
		"World combo UI must hide after combo score conversion finishes.")
	_expect(settlement_snapshots.size() >= 2 \
		and int(settlement_snapshots[0][&"current_score"]) > 0 \
		and bool(settlement_snapshots[0][&"combo_visible"]) \
		and not bool(settlement_snapshots[-1][&"combo_visible"]),
		"Score must publish while combo UI remains visible, then combo_finished must hide it.")
	var score_label := wave.get_node(
		"HUD/WaveHud/DesignSpace/ScoreRepairHud/CurrentScore"
	) as Label
	_expect(score_label.text != "0",
		"Rendered current score label must update from the actual score signal.")

	source.register_contact(99)
	source.release_contact(99)
	_expect(not combo_hud.visible,
		"A synthetic chain without an active ball must keep the world UI hidden.")
	wave.reset_combo_test()
	snapshot = wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"active_combo"]) == 0 \
		and int(snapshot[&"max_combo"]) == 0 \
		and not bool(snapshot[&"combo_visible"]) \
		and not combo_hud.visible,
		"Direct combo reset must clear active/max state and hide the world UI.")


func _test_life_connection(wave: WaveRuntimeCoordinator) -> void:
	var manager_launches := [0]
	var manager_drains := [0]
	wave.wave_manager.ball_cycle_started.connect(func(
		_ball: Pinball,
		_remaining: int
	) -> void:
		manager_launches[0] += 1
	)
	wave.wave_manager.ball_cycle_resolved.connect(func(
		_ball: Pinball,
		_remaining: int,
		_awarded: int
	) -> void:
		manager_drains[0] += 1
	)
	_expect(wave.wave_ball_inventory.select_ball(&"normal"),
		"The initially owned normal ball must be selectable.")
	_expect(wave.hud_state.get_current_life_type() == &"normal",
		"HUD current slot must follow the selected inventory definition.")
	var selected_scene := wave.wave_ball_inventory.selected_definition.ball_scene
	_expect(wave.wave_ball_flow.confirm_selection(),
		"Selected normal ball must prepare through the real flow.")
	_expect(wave.wave_ball_inventory.total_remaining == 3,
		"Confirmation alone must not mark the selected ball used.")
	_expect(wave.launcher.ball_scene == selected_scene,
		"Launcher scene must match the ball type highlighted by the HUD.")
	var first_ball := wave.wave_ball_flow.active_ball
	_expect(wave.launcher.launch_prepared_ball(),
		"Selected heavy ball must launch through the real launcher.")
	_expect(wave.wave_ball_inventory.total_remaining == 2,
		"An actual launch must spend exactly one shared wave launch.")
	_expect(wave.combo_wave_controller.ball_is_active,
		"Launch must enter ComboWaveController through WaveManager.")
	_expect(manager_launches[0] == 1,
		"One physical launch must produce one manager cycle event.")
	var bridge := wave.get_node("ComboCollisionBridge") as ComboCollisionBridge
	_expect(bridge.get(&"_ball") == first_ball,
		"Collision bridge must follow the HUD-selected dynamic ball.")
	wave.call(&"_handle_ball_drained", "HUD integration")
	var slots: Array = wave.hud_state.get_snapshot()[&"life_slots"]
	var spent_count := 0
	for slot: Dictionary in slots:
		if int(slot[&"state"]) == WaveHudStateSource.LifeState.SPENT:
			spent_count += 1
	_expect(spent_count == 1,
		"Drain must spend exactly one HUD launch slot.")
	_expect(wave.hud_state.get_current_life_type()
			== wave.wave_ball_inventory.selected_definition.ball_id,
		"After drain, HUD current slot must match the next inventory selection.")
	_expect(wave.hud_state.get_remaining_life_count() == 2,
		"HUD remaining lives must equal inventory remaining stock.")
	_expect(wave.wave_ball_inventory.total_remaining == 2,
		"Actual drain must leave two selectable balls.")
	_expect(manager_drains[0] == 1,
		"One physical drain must produce one manager settlement event.")
	_expect(bridge.get(&"_ball") == null,
		"Drain must disconnect the bridge from the previous dynamic ball.")

	for _cycle in 2:
		wave.wave_ball_flow.confirm_selection()
		wave.launcher.launch_prepared_ball()
		wave.call(&"_handle_ball_drained", "HUD exhaustion")
	await process_frame
	_expect(wave.wave_manager.current_state == WaveManager.State.LOST,
		"Exhausting stock below target must reach the manager defeat state.")
	await process_frame
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"A failed stage must roll back to wave-one repair placement.")
	var placement_bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(placement_bridge.commit_placement(),
		"Rollback placement must restart wave one through the normal bridge.")
	_expect(wave.hud_state.get_remaining_life_count() == 3,
		"Restarting wave one must restore all HUD launch slots.")
	_expect(wave.wave_ball_inventory.total_remaining == 3,
		"Restarting wave one must restore the shared launch budget.")
	_expect(int(wave.hud_state.get_snapshot()[&"current_score"]) == 0,
		"Retry must synchronize the reset combo score to the HUD.")


func _test_pause_connection(wave: WaveRuntimeCoordinator) -> void:
	wave.wave_ball_flow.confirm_selection()
	wave.launcher.launch_prepared_ball()
	wave.combo_system.register_hit(1.0)
	var active_ball := wave.wave_ball_flow.active_ball
	active_ball.global_position = Vector2(2000.0, 900.0)
	var combo_time_before_pause := wave.combo_system.time_remaining
	var settings := wave.get_node(
		"HUD/WaveHud/DesignSpace/SettingsButton"
	) as WaveSettingsButton
	settings.emit_signal(&"pressed")
	_expect(paused, "Settings button must pause the actual scene tree.")
	_expect(bool(wave.hud_state.get_snapshot()[&"paused"]),
		"Paused state must be reflected in the HUD snapshot.")
	var original_size := root.size
	root.size = Vector2i(800, 1200)
	await process_frame
	await process_frame
	var viewport_size := wave.get_viewport_rect().size
	var design_scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	var design_offset := (viewport_size - Vector2(1920.0, 1080.0) * design_scale) * 0.5
	var safe_top := design_offset.y + wave.hud_safe_top_design * design_scale
	var bounds: Rect2 = wave.board_world_bounds
	var projected_top := viewport_size.y * 0.5 \
		+ (bounds.position.y - wave.board_camera.position.y) \
		* wave.board_camera.zoom.y
	_expect(projected_top + 0.5 >= safe_top,
		"Viewport size_changed must refit the board while gameplay is paused.")
	_expect(wave.wave_manager.current_state == WaveManager.State.IN_PLAY,
		"Paused gameplay must not run automatic board drain.")
	_expect(is_equal_approx(wave.combo_system.time_remaining, combo_time_before_pause),
		"Paused gameplay must not advance the combo timer.")
	active_ball.global_position = Vector2.ZERO
	root.size = original_size
	await process_frame
	settings.emit_signal(&"pressed")
	_expect(not paused, "Settings button must remain able to resume while paused.")


func _test_bumper_runtime_integration(wave: WaveRuntimeCoordinator) -> void:
	wave.reset_combo_test()
	_expect(is_instance_valid(wave.ball),
		"Bumper integration requires the active Wave ball.")
	if not is_instance_valid(wave.ball):
		return

	var bumper := wave.get_node("Bumpers/BumperCenter") as Bumper
	bumper.reset_for_new_ball()
	var starting_durability := bumper.current_durability
	wave.ball.linear_velocity = Vector2(0.0, 500.0)
	var context := BallImpactContext.new(
		wave.ball,
		wave.ball.linear_velocity,
		Vector2.ZERO,
		Vector2.UP,
		bumper.global_position
	)
	bumper.get_ball_impact(context)
	await process_frame
	_expect(wave.combo_system.combo_count == 1,
		"A production Wave bumper impact must register one combo hit.")
	_expect(bumper.current_durability == starting_durability - 1,
		"A production Wave bumper impact must reduce durability once.")
	bumper.get_ball_impact(context)
	await process_frame
	_expect(wave.combo_system.combo_count == 1,
		"Repeated contact with the same ball must not duplicate combo hits.")
	_expect(bumper.current_durability == starting_durability - 1,
		"Repeated contact with the same ball must not duplicate durability damage.")
	bumper.release_contact(wave.ball.get_instance_id())
	bumper.reset_for_new_ball()

	var cannon := wave.get_node("Bumpers/BumperCannon") as ShotBumper
	cannon.call(&"_begin_selection", wave.ball)
	await process_frame
	_expect(not wave.flipper_selector.input_enabled,
		"Shot bumper control must suspend flipper input.")
	cannon.reset_for_new_ball()
	await process_frame
	_expect(wave.flipper_selector.input_enabled,
		"Ending Shot bumper control must restore in-play flipper input.")

	cannon.call(&"_begin_selection", wave.ball)
	await process_frame
	wave.combo_system.stage_base_score = wave.wave_manager.target_score
	wave.combo_system.register_hit(1.0)
	wave.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	await process_frame
	var clear_delay := wave.get_node(
		^"CoinSystem/WaveClearDelayController"
	) as WaveClearDelayController
	var reward_bridge := wave.get_node(
		^"WaveRewardShopBridge"
	) as WaveRewardShopBridge
	_expect(clear_delay.is_delay_active \
		and reward_bridge.clear_delay == clear_delay \
		and wave.wave_manager.current_stage_phase == WaveManager.StagePhase.PINBALL,
		"Reaching the target must keep the active ball during the coin clear delay.")
	# 타임아웃을 직접 발생시켜 Shot 범퍼 제어 중인 공도 정상 종료되는지 확인한다.
	clear_delay.call(&"_on_timer_timeout")
	await process_frame
	await process_frame
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REWARD,
		"Clear-delay timeout during Shot bumper control must open rewards.")
	_expect(int(wave.get(&"_active_shot_controls")) == 0,
		"Clear-delay completion must release aggregate Shot bumper control.")
	_expect(not wave.flipper_selector.input_enabled,
		"Flipper input must stay disabled on the wave-result phase.")

	_expect(reward_bridge.shop_controller.is_open,
		"Automatic reward entry must open the real shop controller.")
	reward_bridge.shop_hud.proceed_requested.emit()
	await process_frame
	var next_session := wave.get_node(
		"RepairBoardLayout/PlacementSession"
	) as BoardPlacementSession
	var next_bridge := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REPAIR_PLACEMENT \
		and next_session.current_state == BoardPlacementSession.State.EDITING,
		"The next wave must reopen the repair placement session.")
	_expect(next_bridge.commit_placement(),
		"The next wave must also advance through a valid placement commit.")
	_expect(wave.wave_ball_flow.confirm_selection(),
		"The next wave must prepare a newly selected ball.")
	_expect(wave.launcher.launch_prepared_ball(),
		"The next wave must launch its selected ball.")
	await process_frame
	_expect(wave.flipper_selector.input_enabled,
		"The next wave must restore flipper input after clear-delay completion.")


func _test_world_anchor_and_hit_fade(wave: WaveRuntimeCoordinator) -> void:
	wave.reset_combo_test()
	_expect(is_instance_valid(wave.ball),
		"The anchor test requires the active ball launched by the pause test.")
	if not is_instance_valid(wave.ball):
		return
	var source := wave.get_node(
		"Bumpers/BumperCenter/ComboHitSource"
	) as ComboHitSource
	var first_world_position := Vector2(-620.0, -180.0)
	wave.ball.global_position = first_world_position
	source.register_contact(1001)
	source.release_contact(1001)
	var snapshot := wave.hud_state.get_snapshot()
	_expect(bool(snapshot[&"combo_anchor_visible"]),
		"A valid combo hit must publish a visible combo anchor.")
	var first_viewport_position: Vector2 = snapshot[&"combo_anchor_viewport"]
	var expected_first := wave.ball.get_global_transform_with_canvas().origin
	_expect(first_viewport_position.distance_to(expected_first) < 0.5,
		"The combo anchor must use the ball position at the accepted hit.")
	var combo_hud := wave.get_node(
		"HUD/WaveHud/DesignSpace/WorldComboHud"
	) as WaveWorldComboHud
	_expect(is_equal_approx(combo_hud.modulate.a, 1.0),
		"A new combo hit must display the floating UI at full opacity.")

	await create_timer(0.25).timeout
	_expect(combo_hud.modulate.a < 1.0 \
		and combo_hud.modulate.a > WaveWorldComboHud.RESTING_ALPHA,
		"The floating UI must fade gradually during the first 0.5 seconds.")

	wave.ball.global_position = Vector2(640.0, 220.0)
	source.register_contact(1002)
	source.release_contact(1002)
	snapshot = wave.hud_state.get_snapshot()
	var second_viewport_position: Vector2 = snapshot[&"combo_anchor_viewport"]
	var expected_second := wave.ball.get_global_transform_with_canvas().origin
	_expect(second_viewport_position.distance_to(expected_second) < 0.5,
		"Each new combo hit must replace the previous floating UI anchor.")
	_expect(second_viewport_position.distance_to(first_viewport_position) > 1.0,
		"Separated hits must not reuse a fixed combo anchor.")
	_expect(is_equal_approx(combo_hud.modulate.a, 1.0),
		"A hit during the fade must restart the UI at full opacity.")

	await create_timer(WaveWorldComboHud.HIT_FADE_DURATION + 0.1).timeout
	_expect(is_equal_approx(
		combo_hud.modulate.a,
		WaveWorldComboHud.RESTING_ALPHA
	), "The floating UI must settle at the configured resting opacity.")
	_expect(combo_hud.position.x >= 28.0 and combo_hud.position.x <= 1672.0,
		"World combo must stay inside horizontal safe bounds.")
	_expect(combo_hud.position.y >= 150.0 and combo_hud.position.y <= 976.0,
		"World combo must stay inside vertical safe bounds.")

	wave.combo_system.finish_combo(ComboSystem.EndReason.TIMEOUT)
	_expect(not combo_hud.visible,
		"A combo timeout must hide the floating UI immediately.")
	source.register_contact(1003)
	source.release_contact(1003)
	_expect(combo_hud.visible,
		"A new chain must show the floating UI after a timeout.")
	wave.combo_system.on_ball_drained()
	_expect(not combo_hud.visible,
		"A ball drain must hide the floating UI immediately.")


func _find_life_slot(slots: Array, ball_type: StringName) -> Dictionary:
	for slot: Dictionary in slots:
		if StringName(slot.get(&"type", &"")) == ball_type:
			return slot
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("PASS: wave_scene_integration_test")
		quit(0)
		return
	print("FAIL: wave_scene_integration_test (%d failures)" % _failures.size())
	quit(1)
