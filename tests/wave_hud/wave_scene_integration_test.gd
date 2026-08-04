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
	_expect(scene_source.contains("[node name=\"Wave\" type=\"Node2D\""),
		"Wave scene root must be authored directly as Node2D.")
	_expect(not scene_source.contains("res://scenes/test_flipper/"),
		"Wave scene must not inherit or instance a test board.")
	_expect(not scene_source.contains("res://tests/"),
		"Wave scene resources must not depend on test code.")
	_expect(not coordinator_source.contains("res://tests/"),
		"Wave runtime coordinator must not inherit test code.")


func _test_scene_structure(wave: WaveRuntimeCoordinator) -> void:
	_expect(String(ProjectSettings.get_setting(&"application/run/main_scene")) == WAVE_SCENE,
		"The project main scene must run the integrated Wave HUD scene.")
	_expect(wave.get_node_or_null("HUD/GuideLabel") == null,
		"Standalone Wave scene must not retain the legacy guide HUD.")
	_expect(wave.get_node_or_null("HUD/ComboHud") == null,
		"Standalone Wave scene must not retain the legacy ComboHud.")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"target_score"]) == 650000,
		"Wave 3 target must come from ComboStageSettings through the controller.")
	_expect((snapshot[&"life_slots"] as Array).size() == 3,
		"Runtime session must expose the actual three-ball inventory.")
	_expect(wave.wave_manager.current_state == WaveManager.State.SELECTING_BALL,
		"Integrated Wave scene must enter through WaveManager.")
	_expect(wave.find_children("WaveManager", "", true, false).size() == 1,
		"Integrated Wave scene must contain one WaveManager.")
	_expect(wave.find_children("WaveBallFlowController", "", true, false).size() == 1,
		"Integrated Wave scene must contain one ball flow controller.")
	_expect(wave.find_children("ComboWaveController", "", true, false).size() == 1,
		"Integrated Wave scene must contain one combo wave policy.")


func _test_korean_selection_hud(wave: WaveRuntimeCoordinator) -> void:
	var hud := wave.ball_selection_hud
	_expect(hud.visible,
		"Ball selection HUD must be visible while choosing the first ball.")
	_expect(hud.title_label.text == "다음 공 선택",
		"Ball selection title must retain the authored Korean copy.")
	_expect(hud.ball_name_label.text in ["가벼운 공", "보통 공", "무거운 공"],
		"Selected ball name must use a Korean inventory label.")
	_expect(hud.stock_label.text.contains("이 공") \
		and hud.stock_label.text.contains("전체") \
		and hud.stock_label.text.contains("남음"),
		"Ball stock label must retain the complete Korean copy.")
	_expect(hud.guide_label.text == "A/D 또는 방향키: 선택    Space: 조준 시작",
		"Ball selection guide must retain the supported Korean instruction text.")


func _test_bumper_loadout(wave: WaveRuntimeCoordinator) -> void:
	var bumpers := wave.get_bumpers()
	_expect(bumpers.size() == 6,
		"Standalone Wave 3 board must contain six production bumpers.")
	_expect(wave.is_current_bumper_loadout_valid(),
		"Authored bumpers must satisfy the Stage 01 Wave 3 loadout contract.")
	var normal_count := 0
	var bounce_count := 0
	var shot_count := 0
	var kind_counts: Dictionary = {}
	for bumper: Bumper in bumpers:
		_expect(bumper.get_script() != null,
			"Every authored bumper must use the production Bumper runtime.")
		_expect(bumper.combo_hit_source != null,
			"Every authored bumper must expose a ComboHitSource.")
		var kind_id := bumper.settings.bumper_kind_id
		kind_counts[kind_id] = int(kind_counts.get(kind_id, 0)) + 1
		match bumper.settings.bumper_type:
			BumperSettings.BumperType.NORMAL:
				normal_count += 1
			BumperSettings.BumperType.BOUNCE:
				bounce_count += 1
			BumperSettings.BumperType.SHOT:
				shot_count += 1
	_expect(normal_count == 3 and bounce_count == 2 and shot_count == 1,
		"Wave 3 must expose three Normal, two Bounce, and one Shot bumper.")
	_expect(kind_counts == {
		&"stage01_button": 2,
		&"stage01_cotton": 1,
		&"stage01_spring_doll": 1,
		&"stage01_toy_drum": 1,
		&"stage01_clockwork_cannon": 1,
	}, "Wave 3 must contain the exact authored Stage 01 bumper kinds.")


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
	ball.global_position = flipper.global_position + Vector2(-220.0, 60.0)
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
	_expect(wave.wave_ball_inventory.select_ball(&"heavy"),
		"Player must be able to choose a non-sequential remaining ball.")
	_expect(wave.hud_state.get_current_life_type() == &"heavy",
		"HUD current slot must follow the selected inventory definition.")
	var heavy_scene := wave.wave_ball_inventory.selected_definition.ball_scene
	_expect(wave.wave_ball_flow.confirm_selection(),
		"Selected heavy ball must prepare through the real flow.")
	_expect(wave.launcher.ball_scene == heavy_scene,
		"Launcher scene must match the ball type highlighted by the HUD.")
	var first_ball := wave.wave_ball_flow.active_ball
	_expect(wave.launcher.launch_prepared_ball(),
		"Selected heavy ball must launch through the real launcher.")
	_expect(wave.combo_wave_controller.ball_is_active,
		"Launch must enter ComboWaveController through WaveManager.")
	_expect(manager_launches[0] == 1,
		"One physical launch must produce one manager cycle event.")
	var bridge := wave.get_node("ComboCollisionBridge") as ComboCollisionBridge
	_expect(bridge.get(&"_ball") == first_ball,
		"Collision bridge must follow the HUD-selected dynamic ball.")
	wave.call(&"_handle_ball_drained", "HUD integration")
	var slots: Array = wave.hud_state.get_snapshot()[&"life_slots"]
	var heavy_slot := _find_life_slot(slots, &"heavy")
	_expect(int(heavy_slot[&"state"]) == WaveHudStateSource.LifeState.SPENT,
		"Drain must spend the selected non-sequential HUD slot.")
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
	_expect(wave.wave_manager.retry_wave(),
		"Integrated HUD scene must retry through WaveManager.")
	_expect(wave.hud_state.get_remaining_life_count() == 3,
		"Retry must restore HUD lives from inventory stock reset.")
	_expect(wave.wave_ball_inventory.total_remaining == 3,
		"Retry must restore the actual selectable inventory.")
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
