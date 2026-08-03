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
	var hud := board.get_node_or_null("HUD/BallSelectionHud") as BallSelectionHud
	var launcher := board.get_node_or_null("PinballLauncher") as PinballLauncher

	_expect(inventory != null and flow != null and combo_wave != null, "Main board should contain the complete wave ball system.")
	_expect(hud != null and hud.visible, "Main board should show ball selection before aiming.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Main board should begin in selecting state.")
	_expect(inventory.total_remaining == 3, "Main board should own three selectable balls.")
	_expect(not launcher.is_aiming, "Main board must not aim before ball confirmation.")

	var confirm := InputEventAction.new()
	confirm.action = &"ball_select_confirm"
	confirm.pressed = true
	flow._unhandled_input(confirm)
	_expect(flow.current_state == WaveBallFlowController.State.AIMING, "Main board confirm should enter aiming.")
	_expect(board.get(&"ball") == flow.active_ball, "Board collision and drain logic should track dynamic active ball.")
	_expect(launcher.launch_prepared_ball(), "Main board selected ball should launch.")
	_expect(flow.current_state == WaveBallFlowController.State.IN_PLAY, "Main board launch should enter play.")
	_expect(combo_wave.ball_is_active, "Main board launch should automatically notify combo wave.")
	var active := flow.active_ball
	board.call(&"_handle_ball_drained", "integration")
	_expect(active != flow.active_ball, "Main board drain should release the previous ball.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Main board drain should return to selection.")

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
