extends SceneTree


const BOARD_SCENE := preload(
	"res://scenes/test_flipper/test_flipper_wave_board.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var board := BOARD_SCENE.instantiate()
	root.add_child(board)
	await process_frame
	var inventory := board.get_node_or_null("WaveBallInventory") as WaveBallInventory
	var flow := board.get_node_or_null("WaveBallFlowController") as WaveBallFlowController
	var combo_wave := board.get_node_or_null("ComboWaveController") as ComboWaveController
	var manager := board.get_node_or_null("WaveManager") as WaveManager
	var collision_bridge := board.get_node_or_null(
		"ComboCollisionBridge"
	) as ComboCollisionBridge
	var combo := board.get_node_or_null("ComboSystem") as ComboSystem
	var hud := board.get_node_or_null("HUD/BallSelectionHud") as BallSelectionHud
	var launcher := board.get_node_or_null("PinballLauncher") as PinballLauncher

	_expect(inventory != null and flow != null and combo_wave != null and manager != null, "Main board should contain the manager-led wave system.")
	_expect(hud != null and hud.visible, "Main board should show ball selection before aiming.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Main board should begin in selecting state.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Wave manager should own the initial selection state.")
	_expect(inventory.total_remaining == 3, "Main board should own three selectable balls.")
	_expect(not launcher.is_aiming, "Main board must not aim before ball confirmation.")

	var confirm := InputEventAction.new()
	confirm.action = &"ball_select_confirm"
	confirm.pressed = true
	flow._unhandled_input(confirm)
	_expect(flow.current_state == WaveBallFlowController.State.AIMING, "Main board confirm should enter aiming.")
	_expect(manager.current_state == WaveManager.State.AIMING, "Wave manager should mirror the aiming phase.")
	_expect(board.get(&"ball") == flow.active_ball, "Board collision and drain logic should track dynamic active ball.")
	_expect(collision_bridge.get(&"_ball") == flow.active_ball, "Collision bridge should bind the selected dynamic ball.")
	_expect(launcher.launch_prepared_ball(), "Main board selected ball should launch.")
	_expect(flow.current_state == WaveBallFlowController.State.IN_PLAY, "Main board launch should enter play.")
	_expect(manager.current_state == WaveManager.State.IN_PLAY, "Wave manager should enter pinball/combat play.")
	_expect(combo_wave.ball_is_active, "Main board launch should automatically notify combo wave.")
	var active := flow.active_ball
	var flipper := board.get_node("FlipperSelector/BottomController/LeftFlipper")
	var wall := board.get_node("Walls/TopRightDiagonal")
	active.body_entered.emit(flipper)
	_expect(combo.combo_count == 1, "Dynamic ball flipper contact should register through the rebound bridge.")
	combo.advance_time(1.0)
	active.body_entered.emit(wall)
	_expect(is_equal_approx(combo.time_remaining, 3.0), "Dynamic ball wall contact should refresh the combo timer.")
	board.call(&"_handle_ball_drained", "integration")
	_expect(active != flow.active_ball, "Main board drain should release the previous ball.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Main board drain should return to selection.")
	_expect(manager.current_state == WaveManager.State.SELECTING_BALL, "Manager should repeat from remaining-ball selection.")
	_expect(collision_bridge.get(&"_ball") == null, "Drain should disconnect the bridge from the previous ball.")

	flow._unhandled_input(confirm)
	var second_ball := flow.active_ball
	_expect(second_ball != active, "Next selection should create a different ball instance.")
	_expect(collision_bridge.get(&"_ball") == second_ball, "Collision bridge should rebind for every selected ball.")
	_expect(launcher.launch_prepared_ball(), "Second selected ball should launch.")
	second_ball.body_entered.emit(flipper)
	_expect(combo.combo_count == 1, "Second dynamic ball should start a new valid combat combo.")

	board.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_wave_board_scene_test")
		quit(0)
		return
	print("FAIL: test_flipper_wave_board_scene_test (%d failures)" % _failures.size())
	quit(1)
