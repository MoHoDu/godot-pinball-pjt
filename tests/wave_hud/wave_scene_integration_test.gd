extends SceneTree


const WAVE_SCENE := "res://scenes/wave/wave.tscn"

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

	_test_scene_structure(wave)
	_test_combo_and_score_connection(wave)
	await _test_life_connection(wave)
	_test_world_anchor(wave)
	await _test_pause_connection(wave)

	wave.queue_free()
	await process_frame
	_finish()


func _test_scene_structure(wave: WaveRuntimeCoordinator) -> void:
	_expect(String(ProjectSettings.get_setting(&"application/run/main_scene")) == WAVE_SCENE,
		"The project main scene must run the integrated Wave HUD scene.")
	_expect(not wave.get_node("HUD/GuideLabel").visible,
		"Legacy guide HUD must be hidden in the Wave scene.")
	_expect(not wave.get_node("HUD/ComboHud").visible,
		"Legacy ComboHud must be hidden in the Wave scene.")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"target_score"]) == 250000,
		"Wave 1 target must come from ComboStageSettings through the controller.")
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

	var awarded := wave.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_expect(awarded > 0, "Combo settlement must award actual score.")
	snapshot = wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"current_score"]) == wave.combo_system.total_score,
		"Actual settled score must reach the HUD snapshot.")
	_expect(int(snapshot[&"max_combo"]) == 5,
		"Settlement must not erase the displayed wave max combo.")
	var score_label := wave.get_node(
		"HUD/WaveHud/DesignSpace/ScoreRepairHud/CurrentScore"
	) as Label
	_expect(score_label.text != "0",
		"Rendered current score label must update from the actual score signal.")


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
	await process_frame
	await process_frame
	_expect(wave.wave_manager.current_state == WaveManager.State.IN_PLAY,
		"Paused gameplay must not run automatic board drain.")
	_expect(is_equal_approx(wave.combo_system.time_remaining, combo_time_before_pause),
		"Paused gameplay must not advance the combo timer.")
	active_ball.global_position = Vector2.ZERO
	settings.emit_signal(&"pressed")
	_expect(not paused, "Settings button must remain able to resume while paused.")


func _test_world_anchor(wave: WaveRuntimeCoordinator) -> void:
	wave.call(&"_update_combo_anchor")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(bool(snapshot[&"combo_anchor_visible"]),
		"Center bumper projection must publish a visible combo anchor.")
	var combo_hud := wave.get_node(
		"HUD/WaveHud/DesignSpace/WorldComboHud"
	) as WaveWorldComboHud
	_expect(combo_hud.position.x >= 28.0 and combo_hud.position.x <= 1672.0,
		"World combo must stay inside horizontal safe bounds.")
	_expect(combo_hud.position.y >= 150.0 and combo_hud.position.y <= 976.0,
		"World combo must stay inside vertical safe bounds.")


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
