extends SceneTree


const LIGHT_BALL := preload("res://Resources/balls/mass_var/light_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_continue_to_victory_and_retry()
	await _test_choose_clear_victory()
	await _test_synchronous_choice_resolution()
	await _test_exhaustion_defeat()
	await _test_terminal_signal_reentrancy()
	await _test_dependency_rebinding_cleanup()
	_finish()


func _test_continue_to_victory_and_retry() -> void:
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
	_expect(manager.current_state == WaveManager.State.CLEAR_CHOICE, "Reached target with stock should request a clear choice.")
	_expect(flow.selection_locked, "Clear choice should lock the next ball selection.")
	_expect(manager.choose_remaining_balls(), "Player should be able to keep the remaining balls.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Continue choice should resume selection.")
	_expect(not flow.selection_locked, "Continue choice should unlock ball selection.")

	_expect(flow.confirm_selection(), "Second ball selection should be confirmed.")
	var second_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Second prepared ball should launch.")
	_expect(flow.on_ball_drained(second_ball), "Last active ball should drain.")
	await process_frame
	_expect(manager.current_state == WaveManager.State.WON, "Target reached and stock exhausted should win the wave.")
	_expect(flow.current_state == WaveBallFlowController.State.EXHAUSTED, "Winning with the last ball should exhaust ball flow.")
	_expect(visited_states.has(WaveManager.State.RESOLVING_BALL), "Drain should pass through the resolving state.")

	_expect(manager.retry_wave(), "A won wave should be retryable.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Retry should return to selection.")
	_expect(inventory.total_remaining == 2, "Retry should restore the starting inventory.")
	_expect(combo.total_score == 0, "Retry should reset accumulated combo score.")
	await _destroy_fixture(fixture)


func _test_choose_clear_victory() -> void:
	var fixture := await _create_fixture(2, 100)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var combo: ComboSystem = fixture.combo
	var won_count := {&"value": 0}
	manager.wave_won.connect(func(_score: int, _target: int) -> void:
		won_count.value += 1
	)

	_expect(manager.enter_wave(fixture.settings), "Clear-choice fixture should enter the wave.")
	flow.confirm_selection()
	var ball := flow.active_ball
	launcher.launch_prepared_ball()
	combo.register_hit(1.0)
	flow.on_ball_drained(ball)
	_expect(manager.current_state == WaveManager.State.CLEAR_CHOICE, "Target should offer clear before stock is exhausted.")
	_expect(manager.choose_clear(), "Clear choice should be accepted.")
	await process_frame
	_expect(manager.current_state == WaveManager.State.WON, "Clear choice should finish the wave as won.")
	_expect(flow.current_state == WaveBallFlowController.State.INACTIVE, "Explicit clear should close ball flow.")
	_expect(won_count.value == 1, "Victory should emit exactly once.")
	await _destroy_fixture(fixture)


func _test_exhaustion_defeat() -> void:
	var fixture := await _create_fixture(2, 300)
	var manager: WaveManager = fixture.manager
	var flow: WaveBallFlowController = fixture.flow
	var launcher: PinballLauncher = fixture.launcher
	var lost_count := {&"value": 0}
	manager.wave_lost.connect(func(_score: int, _target: int) -> void:
		lost_count.value += 1
	)

	_expect(manager.enter_wave(fixture.settings), "Defeat fixture should enter the wave.")
	for index in 2:
		_expect(flow.confirm_selection(), "Defeat cycle %d should select a ball." % index)
		var ball := flow.active_ball
		_expect(launcher.launch_prepared_ball(), "Defeat cycle %d should launch." % index)
		_expect(flow.on_ball_drained(ball), "Defeat cycle %d should drain." % index)
	await process_frame
	_expect(manager.current_state == WaveManager.State.LOST, "Missing the target with no balls should lose the wave.")
	_expect(manager.current_score == 0, "No-hit defeat should award no score.")
	_expect(lost_count.value == 1, "Defeat should emit exactly once.")
	await _destroy_fixture(fixture)


func _test_synchronous_choice_resolution() -> void:
	var continue_fixture := await _create_fixture(2, 100)
	var continue_manager: WaveManager = continue_fixture.manager
	var continue_flow: WaveBallFlowController = continue_fixture.flow
	var continue_launcher: PinballLauncher = continue_fixture.launcher
	var continue_combo: ComboSystem = continue_fixture.combo
	continue_manager.clear_choice_requested.connect(func(
		_score: int,
		_target: int,
		_remaining: int
	) -> void:
		continue_manager.choose_remaining_balls()
	)
	continue_manager.enter_wave(continue_fixture.settings)
	continue_flow.confirm_selection()
	var continue_ball := continue_flow.active_ball
	continue_launcher.launch_prepared_ball()
	continue_combo.register_hit(1.0)
	continue_flow.on_ball_drained(continue_ball)
	_expect(continue_manager.current_state == WaveManager.State.SELECTING_BALL, "Synchronous continue choice should reconcile after drain.")
	await _destroy_fixture(continue_fixture)

	var clear_fixture := await _create_fixture(2, 100)
	var clear_manager: WaveManager = clear_fixture.manager
	var clear_flow: WaveBallFlowController = clear_fixture.flow
	var clear_launcher: PinballLauncher = clear_fixture.launcher
	var clear_combo: ComboSystem = clear_fixture.combo
	clear_manager.clear_choice_requested.connect(func(
		_score: int,
		_target: int,
		_remaining: int
	) -> void:
		clear_manager.choose_clear()
	)
	clear_manager.enter_wave(clear_fixture.settings)
	clear_flow.confirm_selection()
	var clear_ball := clear_flow.active_ball
	clear_launcher.launch_prepared_ball()
	clear_combo.register_hit(1.0)
	clear_flow.on_ball_drained(clear_ball)
	await process_frame
	_expect(clear_manager.current_state == WaveManager.State.WON, "Synchronous clear choice should finish after the flow reaches selection.")
	_expect(clear_flow.current_state == WaveBallFlowController.State.INACTIVE, "Synchronous clear should leave manager and flow in matching terminal states.")
	await _destroy_fixture(clear_fixture)


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
