extends SceneTree


const LIGHT_BALL := preload("res://Resources/Prefabs/balls/variants/mass/light_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_live_target_reached_ends_immediately()
	await _test_target_reached_ends_immediately_and_retry()
	await _test_confirmed_stage_phase_sequence()
	await _test_direct_boss_stage_entry()
	await _test_boss_ball_cycle_preserves_phase()
	await _test_boss_ball_exhaustion_defeat()
	await _test_exhaustion_defeat()
	await _test_stage_rejects_non_three_ball_inventory()
	await _test_terminal_signal_reentrancy()
	await _test_dependency_rebinding_cleanup()
	_finish()


func _test_live_target_reached_ends_immediately() -> void:
	var fixture := await _create_fixture(3, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var combo: ComboSystem = fixture.combo
	var bridge: ComboCollisionBridge = fixture.bridge

	_expect(manager.enter_wave(fixture.settings), "Live-clear fixture should enter.")
	flow.confirm_selection()
	launcher.launch_prepared_ball()
	combo.register_hit(1.0)
	combo.finish_combo(ComboSystem.EndReason.MANUAL)
	await process_frame
	_expect(manager.current_state == WaveManager.State.WON,
		"A live target clear must not wait for the active ball to drain.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT,
		"A live target clear must open result judgement immediately.")
	_expect(flow.current_state == WaveBallFlowController.State.INACTIVE,
		"A live target clear must close the active ball flow.")
	_expect(manager.active_ball == null and bridge.get(&"_ball") == null,
		"A live target clear must release its active ball references.")
	await _destroy_fixture(fixture)


func _test_target_reached_ends_immediately_and_retry() -> void:
	var fixture := await _create_fixture(2, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var combo: ComboSystem = fixture.combo
	var inventory: WaveBallInventory = fixture.inventory
	var visited_states: Array[WaveManager.State] = []
	manager.state_changed.connect(func(
		_previous: WaveManager.State,
		current: WaveManager.State
	) -> void:
		visited_states.append(current)
	)

	_expect(manager.enter_wave(fixture.settings), "Manager should enter a configured wave.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Wave entry should open ball selection.")
	_expect(flow.confirm_selection(), "First ball selection should be confirmed.")
	_expect(manager.current_state == WaveManager.State.AIMING, "Prepared ball should move the manager to aiming.")
	var first_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "First prepared ball should launch.")
	_expect(manager.current_state == WaveManager.State.IN_PLAY, "Launch should enter pinball/combat play.")
	combo.register_hit(1.0)
	_expect(flow.on_ball_drained(first_ball), "First active ball should drain.")
	await process_frame
	_expect(manager.current_state == WaveManager.State.WON,
		"Reaching the target must immediately finish the wave.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT,
		"Immediate clear must open the result phase.")
	_expect(flow.current_state == WaveBallFlowController.State.INACTIVE,
		"Immediate clear must close ball flow without spending remaining balls.")
	_expect(inventory.total_remaining == 1,
		"Immediate clear must preserve the unused ball in the current result.")
	_expect(visited_states.has(WaveManager.State.RESOLVING_BALL), "Drain should pass through the resolving state.")

	_expect(manager.retry_wave(), "A won wave should be retryable.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Retry should return to selection.")
	_expect(inventory.total_remaining == 2, "Retry should restore the starting inventory.")
	_expect(combo.total_score == 0, "Retry should reset accumulated combo score.")
	await _destroy_fixture(fixture)


func _test_confirmed_stage_phase_sequence() -> void:
	var fixture := await _create_fixture(3, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var combo: ComboSystem = fixture.combo
	var settings: ComboStageSettings = fixture.settings
	settings.wave_target_scores = PackedInt32Array([100, 100, 100, 500])

	_expect(manager.enter_stage(settings), "Stage must begin at its first placeholder.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT,
		"A stage must begin with repair placement.")
	for wave_index in 3:
		_expect(manager.current_wave_index == wave_index,
			"Stage must expose the expected normal-wave index.")
		_expect(manager.advance_stage_phase(),
			"Repair placement placeholder must advance into ball selection.")
		_expect(manager.current_stage_phase == WaveManager.StagePhase.BALL_SELECTION,
			"Repair placement must lead to ball selection.")
		flow.confirm_selection()
		_expect(manager.current_stage_phase == WaveManager.StagePhase.BALL_LAUNCH,
			"Confirmed ball selection must lead to launch.")
		var ball := flow.active_ball
		launcher.launch_prepared_ball()
		_expect(manager.current_stage_phase == WaveManager.StagePhase.PINBALL,
			"Launch must lead to pinball play.")
		combo.register_hit(1.0)
		flow.on_ball_drained(ball)
		await process_frame
		_expect(manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT,
			"A cleared wave must lead to result judgement.")
		manager.advance_stage_phase()
		_expect(manager.current_stage_phase == WaveManager.StagePhase.REWARD,
			"A successful result must lead to reward.")
		manager.advance_stage_phase()
		var expected_phase := WaveManager.StagePhase.REPAIR_PLACEMENT \
			if wave_index < 2 else WaveManager.StagePhase.BOSS
		_expect(manager.current_stage_phase == expected_phase,
			"Reward must lead to the next wave or boss.")

	_expect(not manager.advance_stage_phase(),
		"Boss phase must not advance before its Ball cycle is completed.")
	_expect(manager.start_boss_ball_cycle(),
		"Boss phase must start its managed Ball cycle.")
	_expect(manager.finish_boss_ball_cycle(),
		"Boss phase must finish its managed Ball cycle.")
	_expect(manager.advance_stage_phase(),
		"Completed Boss Ball cycle must advance.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"Boss must lead to stage completion.")
	_expect(manager.advance_stage_phase(), "Stage completion must be restartable.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT \
		and manager.current_wave_index == 0,
		"Stage restart must return to Wave 1 repair placement.")
	await _destroy_fixture(fixture)


func _test_direct_boss_stage_entry() -> void:
	var fixture := await _create_fixture(3, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var settings: ComboStageSettings = fixture.settings
	var visited_phases: Array[WaveManager.StagePhase] = []
	var normal_wave_entries: Array[int] = []
	manager.stage_phase_changed.connect(func(
		_previous: WaveManager.StagePhase,
		current: WaveManager.StagePhase
	) -> void:
		visited_phases.append(current)
	)
	manager.wave_entered.connect(func(
		_stage_id: StringName,
		wave_index: int,
		_target_score: int
	) -> void:
		normal_wave_entries.append(wave_index)
	)

	_expect(manager.enter_boss_stage(settings),
		"Direct Boss entry must initialize an inactive stage.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Direct Boss entry must begin at BOSS.")
	_expect(visited_phases == [WaveManager.StagePhase.BOSS],
		"Direct Boss entry must not visit repair, normal Wave, or reward phases.")
	_expect(normal_wave_entries.is_empty(),
		"Direct Boss entry must not emit a normal wave_entered event.")
	_expect(manager.current_wave_index == WaveManager.NORMAL_WAVE_COUNT - 1,
		"Direct Boss entry must preserve the established Boss wave index.")
	_expect(not manager.advance_stage_phase(),
		"Direct Boss entry must still require Boss completion.")
	_expect(manager.start_boss_ball_cycle(),
		"Direct Boss entry must start the existing Ball cycle.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Direct Boss entry must reuse Ball selection.")
	_expect(flow.confirm_selection(),
		"Direct Boss selection must prepare a stocked Ball.")
	var boss_ball: Pinball = flow.active_ball
	_expect(launcher.launch_prepared_ball(),
		"Direct Boss entry must reuse the existing Launcher.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss Ball launch must preserve BOSS.")
	_expect(flow.on_ball_drained(boss_ball),
		"Direct Boss Ball must use the existing drain flow.")
	await process_frame
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss drain must not enter normal result or reward phases.")
	_expect(manager.finish_boss_ball_cycle(),
		"Direct Boss completion must close its Ball cycle.")
	_expect(manager.advance_stage_phase(),
		"Completed direct Boss must advance to stage completion.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"Direct Boss completion must enter STAGE_COMPLETE.")
	await _destroy_fixture(fixture)


func _test_boss_ball_cycle_preserves_phase() -> void:
	var fixture := await _create_fixture(3, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var combo: ComboSystem = fixture.combo
	var inventory: WaveBallInventory = fixture.inventory
	var settings: ComboStageSettings = fixture.settings
	settings.wave_target_scores = PackedInt32Array([100, 100, 100, 500])

	_expect(manager.enter_stage(settings), "Boss-cycle stage must enter.")
	_expect(not manager.start_boss_ball_cycle(),
		"Boss Ball cycle must reject every non-BOSS stage phase.")
	for wave_index in 3:
		_expect(manager.advance_stage_phase(),
			"Each repair phase must start its normal Wave.")
		_expect(flow.confirm_selection(), "Normal Wave must select a Ball.")
		var normal_ball: Pinball = flow.active_ball
		_expect(launcher.launch_prepared_ball(), "Normal Wave Ball must launch.")
		combo.register_hit(1.0)
		_expect(flow.on_ball_drained(normal_ball),
			"Normal Wave Ball must drain through the existing flow.")
		await process_frame
		_expect(
			manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT,
			"Normal Wave completion must remain unchanged."
		)
		_expect(manager.advance_stage_phase(),
			"Normal result must advance to reward.")
		_expect(manager.advance_stage_phase(),
			"Normal reward must advance to the next phase.")

	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Third reward must enter BOSS.")
	var boss_wave_index: int = manager.current_wave_index
	_expect(not manager.advance_stage_phase(),
		"BOSS cannot reach stage completion before Boss completion.")
	_expect(manager.start_boss_ball_cycle(),
		"BOSS must start the existing Ball selection flow.")
	_expect(combo.total_score == 0,
		"Boss Ball cycle must reset the prior normal Wave Combo score.")
	_expect(manager.is_boss_ball_cycle_active(),
		"Boss Ball cycle must report active.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Boss cycle must begin with existing Ball selection.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss selection must preserve the BOSS phase.")
	_expect(manager.current_wave_index == boss_wave_index,
		"Boss Ball cycle must not increment normal Wave index.")
	_expect(not manager.start_boss_ball_cycle(),
		"The same BOSS phase must not reset Ball stock twice.")

	_expect(flow.confirm_selection(), "Boss cycle must prepare a stocked Ball.")
	var boss_ball: Pinball = flow.active_ball
	_expect(is_instance_valid(boss_ball), "Boss cycle must expose active Ball.")
	_expect(launcher.launch_prepared_ball(), "Boss cycle Ball must launch.")
	_expect(manager.current_state == WaveManager.State.IN_PLAY,
		"Boss launch must use the existing in-play state.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss launch must preserve the BOSS phase.")
	_expect(flow.on_ball_drained(boss_ball),
		"Boss Ball must drain through the existing flow.")
	await process_frame
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Boss drain must select another Ball while stock remains.")
	_expect(inventory.total_remaining == 2,
		"Boss drain must preserve existing BallStock accounting.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss drain must not enter WAVE_RESULT or REWARD.")
	_expect(not manager.advance_stage_phase(),
		"Active Boss cycle must still block stage completion.")

	_expect(manager.finish_boss_ball_cycle(),
		"Boss completion must close its Ball cycle safely.")
	_expect(not manager.is_boss_ball_cycle_active(),
		"Finished Boss Ball cycle must report inactive.")
	_expect(flow.current_state == WaveBallFlowController.State.INACTIVE,
		"Finished Boss cycle must close BallFlow.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Finishing Ball cycle alone must retain BOSS until phase advance.")
	_expect(manager.advance_stage_phase(),
		"Completed Boss cycle must allow BOSS to advance.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"Boss completion must enter STAGE_COMPLETE.")
	_expect(manager.advance_stage_phase(),
		"Stage completion must restart the normal stage.")
	_expect(
		manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Stage restart must restore normal Wave flow."
	)
	await _destroy_fixture(fixture)


func _test_boss_ball_exhaustion_defeat() -> void:
	var fixture := await _create_fixture(3, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var boss_lost_count := {&"value": 0}
	var wave_lost_count := {&"value": 0}
	manager.boss_lost.connect(func() -> void:
		boss_lost_count.value += 1
	)
	manager.wave_lost.connect(func(_score: int, _target: int) -> void:
		wave_lost_count.value += 1
	)

	_expect(manager.enter_boss_stage(fixture.settings),
		"Boss exhaustion fixture should enter BOSS directly.")
	_expect(manager.start_boss_ball_cycle(),
		"Boss exhaustion fixture should start its Ball cycle.")
	for index in WaveManager.BALLS_PER_WAVE:
		_expect(flow.confirm_selection(),
			"Boss exhaustion cycle %d should select a Ball." % index)
		var ball := flow.active_ball
		_expect(launcher.launch_prepared_ball(),
			"Boss exhaustion cycle %d should launch." % index)
		_expect(flow.on_ball_drained(ball),
			"Boss exhaustion cycle %d should drain." % index)
	await process_frame

	_expect(boss_lost_count.value == 1,
		"Exhausting all Boss lives must emit boss_lost exactly once.")
	_expect(wave_lost_count.value == 0,
		"Boss exhaustion must not emit the normal Wave loss signal.")
	_expect(manager.current_state == WaveManager.State.LOST,
		"Boss exhaustion must expose the LOST runtime state.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss exhaustion must stay in BOSS until StageFlowManager rolls back.")
	_expect(not manager.is_boss_ball_cycle_active(),
		"Boss exhaustion must close the active Boss Ball cycle.")
	_expect(not manager.advance_stage_phase(),
		"A defeated Boss attempt must not advance to STAGE_COMPLETE.")
	await _destroy_fixture(fixture)


func _test_exhaustion_defeat() -> void:
	var fixture := await _create_fixture(3, 300)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var lost_count := {&"value": 0}
	manager.wave_lost.connect(func(_score: int, _target: int) -> void:
		lost_count.value += 1
	)

	_expect(manager.enter_stage(fixture.settings), "Defeat fixture should enter the stage.")
	_expect(manager.advance_stage_phase(), "Repair placeholder should start the wave.")
	for index in 3:
		_expect(flow.confirm_selection(), "Defeat cycle %d should select a ball." % index)
		var ball := flow.active_ball
		_expect(launcher.launch_prepared_ball(), "Defeat cycle %d should launch." % index)
		_expect(flow.on_ball_drained(ball), "Defeat cycle %d should drain." % index)
	await process_frame
	_expect(manager.current_state == WaveManager.State.LOST, "Missing the target with no balls should lose the wave.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT,
		"Three-ball failure must still open result judgement.")
	_expect(manager.advance_stage_phase(), "Failure result must remain navigable.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Failure result must return to the same wave's repair placement.")
	_expect(manager.current_wave_index == 0,
		"Failure must not skip to the next wave.")
	_expect(manager.advance_stage_phase(),
		"Repair placement must restart the failed wave.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BALL_SELECTION \
		and flow.current_state == WaveBallFlowController.State.SELECTING,
		"Failed-wave retry must restore three-ball selection.")
	_expect((fixture.inventory as WaveBallInventory).total_remaining == 3,
		"Failed-wave retry must restore exactly three balls.")
	_expect(manager.current_score == 0, "No-hit defeat should award no score.")
	_expect(lost_count.value == 1, "Defeat should emit exactly once.")
	await _destroy_fixture(fixture)


func _test_stage_rejects_non_three_ball_inventory() -> void:
	var fixture := await _create_fixture(4, 100)
	var manager: WaveManager = fixture.manager
	_expect(not manager.enter_stage(fixture.settings),
		"Confirmed stage flow must reject more than three wave balls.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.INACTIVE,
		"Rejected stage inventory must not begin a partial stage.")
	await _destroy_fixture(fixture)


func _test_terminal_signal_reentrancy() -> void:
	var win_fixture := await _create_fixture(1, 100)
	var win_manager: WaveManager = win_fixture.manager
	var win_flow: WaveBallFlowController = win_fixture.flow
	var win_launcher: PinballLauncher = win_fixture.launcher
	var win_combo: ComboSystem = win_fixture.combo
	var win_bridge: ComboCollisionBridge = win_fixture.bridge
	var win_snapshot := {
		&"flow_state": WaveBallFlowController.State.INACTIVE,
		&"active_ball": null,
		&"bridge_ball": null,
		&"entered_again": false,
	}
	win_manager.wave_won.connect(func(_score: int, _target: int) -> void:
		win_snapshot.flow_state = win_flow.current_state
		win_snapshot.active_ball = win_manager.active_ball
		win_snapshot.bridge_ball = win_bridge.get(&"_ball")
		win_snapshot.entered_again = win_manager.enter_wave(win_fixture.settings)
	)
	win_manager.enter_wave(win_fixture.settings)
	win_flow.confirm_selection()
	var winning_ball := win_flow.active_ball
	win_launcher.launch_prepared_ball()
	win_combo.register_hit(1.0)
	win_flow.on_ball_drained(winning_ball)
	await process_frame
	_expect(win_snapshot.flow_state == WaveBallFlowController.State.EXHAUSTED, "Victory signal should run after flow exhausts.")
	_expect(win_snapshot.active_ball == null and win_snapshot.bridge_ball == null, "Victory signal should run after active-ball cleanup.")
	_expect(win_snapshot.entered_again, "Victory listener should enter the next wave synchronously.")
	_expect(win_manager.current_state == WaveManager.State.SELECTING_BALL, "Next wave entry should not be polluted by the previous drain.")
	await _destroy_fixture(win_fixture)

	var loss_fixture := await _create_fixture(1, 300)
	var loss_manager: WaveManager = loss_fixture.manager
	var loss_flow: WaveBallFlowController = loss_fixture.flow
	var loss_launcher: PinballLauncher = loss_fixture.launcher
	var loss_bridge: ComboCollisionBridge = loss_fixture.bridge
	var loss_snapshot := {
		&"flow_state": WaveBallFlowController.State.INACTIVE,
		&"active_ball": null,
		&"bridge_ball": null,
		&"retried": false,
	}
	loss_manager.wave_lost.connect(func(_score: int, _target: int) -> void:
		loss_snapshot.flow_state = loss_flow.current_state
		loss_snapshot.active_ball = loss_manager.active_ball
		loss_snapshot.bridge_ball = loss_bridge.get(&"_ball")
		loss_snapshot.retried = loss_manager.retry_wave()
	)
	loss_manager.enter_wave(loss_fixture.settings)
	loss_flow.confirm_selection()
	var losing_ball := loss_flow.active_ball
	loss_launcher.launch_prepared_ball()
	loss_flow.on_ball_drained(losing_ball)
	await process_frame
	_expect(loss_snapshot.flow_state == WaveBallFlowController.State.EXHAUSTED, "Defeat signal should run after flow exhausts.")
	_expect(loss_snapshot.active_ball == null and loss_snapshot.bridge_ball == null, "Defeat signal should run after active-ball cleanup.")
	_expect(loss_snapshot.retried, "Defeat listener should retry synchronously.")
	_expect(loss_manager.current_state == WaveManager.State.SELECTING_BALL, "Retry should not be polluted by the previous drain.")
	await _destroy_fixture(loss_fixture)


func _test_dependency_rebinding_cleanup() -> void:
	var fixture := await _create_fixture(1, 100)
	var manager: WaveManager = fixture.manager
	var combo: ComboSystem = fixture.combo
	var flow: WaveBallFlowController = fixture.flow
	var first_bridge := ComboCollisionBridge.new()
	var second_bridge := ComboCollisionBridge.new()
	var replacement_combo := ComboSystem.new()
	var replacement_policy := ComboWaveController.new()
	(fixture.root as Node).add_child(first_bridge)
	(fixture.root as Node).add_child(second_bridge)
	(fixture.root as Node).add_child(replacement_combo)
	(fixture.root as Node).add_child(replacement_policy)
	_expect(manager.bind_collision_bridge(first_bridge), "Manager should bind the first collision bridge.")
	_expect(first_bridge.get(&"_combo_system") == combo, "Bridge should receive combo system regardless of binding order.")
	manager.bind_collision_bridge(second_bridge)
	_expect(first_bridge.get(&"_ball") == null, "Replacing a bridge should release its active ball.")
	manager.bind_combo_system(replacement_combo)
	_expect(second_bridge.get(&"_combo_system") == replacement_combo, "Combo rebinding should update the active bridge.")
	manager.bind_combo_wave(replacement_policy)
	_expect((fixture.combo_wave as ComboWaveController).get(&"_ball_flow") == null, "Replacing combo policy should detach the old flow.")
	_expect((fixture.combo_wave as ComboWaveController).is_processing_unhandled_input(), "Replacing combo policy should restore old input ownership.")
	_expect(replacement_policy.get(&"_ball_flow") == flow, "Replacement policy should bind without duplicate flow listeners.")
	await _destroy_fixture(fixture)


func _create_fixture(ball_count: int, target: int) -> Dictionary:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var combo := ComboSystem.new()
	var combo_wave := ComboWaveController.new()
	var inventory := WaveBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := WaveBallFlowController.new()
	var manager := WaveManager.new()
	var bridge := ComboCollisionBridge.new()
	var stock := _make_stock(ball_count)
	inventory.starting_stock = [stock]
	launcher.spawn_parent_path = ^".."
	fixture_root.add_child(combo)
	fixture_root.add_child(combo_wave)
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	fixture_root.add_child(manager)
	fixture_root.add_child(bridge)
	await process_frame

	_expect(flow.bind_inventory(inventory), "Fixture flow should bind its inventory.")
	_expect(flow.bind_launcher(launcher), "Fixture flow should bind its launcher.")
	_expect(manager.bind_ball_flow(flow), "Manager should bind ball flow.")
	_expect(manager.bind_combo_wave(combo_wave), "Manager should bind combo wave policy.")
	_expect(manager.bind_combo_system(combo), "Manager should bind combo scoring.")
	_expect(manager.bind_collision_bridge(bridge), "Manager should bind collision bridge.")
	var settings := ComboStageSettings.new()
	settings.stage_id = &"wave_manager_test"
	settings.stage_base_score = 100
	settings.wave_target_scores = PackedInt32Array([target])
	return {
		&"root": fixture_root,
		&"combo": combo,
		&"combo_wave": combo_wave,
		&"inventory": inventory,
		&"launcher": launcher,
		&"flow": flow,
		&"manager": manager,
		&"bridge": bridge,
		&"settings": settings,
	}


func _make_stock(count: int) -> BallStock:
	var definition := BallDefinition.new()
	definition.ball_id = &"light"
	definition.display_name = "Light Ball"
	definition.ball_scene = LIGHT_BALL
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = count
	return stock


func _destroy_fixture(fixture: Dictionary) -> void:
	(fixture.root as Node).queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_manager_test")
		quit(0)
		return
	print("FAIL: wave_manager_test (%d failures)" % _failures.size())
	quit(1)
