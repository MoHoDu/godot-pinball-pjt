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
	_test_life_connection(wave)
	_test_pause_connection(wave)
	_test_world_anchor(wave)

	wave.queue_free()
	await process_frame
	_finish()


func _test_scene_structure(wave: WaveRuntimeCoordinator) -> void:
	_expect(not wave.get_node("HUD/GuideLabel").visible,
		"Legacy guide HUD must be hidden in the Wave scene.")
	_expect(not wave.get_node("HUD/ComboHud").visible,
		"Legacy ComboHud must be hidden in the Wave scene.")
	var snapshot := wave.hud_state.get_snapshot()
	_expect(int(snapshot[&"target_score"]) == 250000,
		"Wave 1 target must come from ComboStageSettings through the controller.")
	_expect((snapshot[&"life_slots"] as Array).size() == 3,
		"Runtime session must expose its ordered three-ball roster.")


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
	wave.call(&"_on_wave_ball_launched")
	_expect(wave.combo_wave_controller.ball_is_active,
		"Launch event must enter ComboWaveController exactly once.")
	wave.call(&"_handle_wave_ball_drained")
	var slots: Array = wave.hud_state.get_snapshot()[&"life_slots"]
	_expect(int(slots[0][&"state"]) == WaveHudStateSource.LifeState.SPENT,
		"Actual drain must mark the current fixed slot spent.")
	_expect(int(slots[1][&"state"]) == WaveHudStateSource.LifeState.CURRENT,
		"Actual drain must advance current life without reordering slots.")
	_expect(wave.hud_state.get_remaining_life_count() == 2,
		"Actual drain must forward the correct remaining life count.")


func _test_pause_connection(wave: WaveRuntimeCoordinator) -> void:
	var settings := wave.get_node(
		"HUD/WaveHud/DesignSpace/SettingsButton"
	) as WaveSettingsButton
	settings.emit_signal(&"pressed")
	_expect(paused, "Settings button must pause the actual scene tree.")
	_expect(bool(wave.hud_state.get_snapshot()[&"paused"]),
		"Paused state must be reflected in the HUD snapshot.")
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
