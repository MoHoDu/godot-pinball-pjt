extends SceneTree


const FLOW_SCRIPT := preload(
	"res://scripts/ball_base_system/wave_ball_flow_controller.gd"
)
const LIGHT_BALL := preload("res://Resources/balls/mass_var/light_ball.tscn")
const HEAVY_BALL := preload("res://Resources/balls/mass_var/heavy_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture := await _create_fixture()
	var inventory: WaveBallInventory = fixture.inventory
	var launcher: PinballLauncher = fixture.launcher
	var flow: WaveBallFlowController = fixture.flow
	var state_trace: Array[WaveBallFlowController.State] = []
	flow.state_changed.connect(func(
		_previous: WaveBallFlowController.State,
		current: WaveBallFlowController.State
	) -> void:
		state_trace.append(current)
	)

	_expect(flow.start_wave(), "A configured wave should start.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Wave must start in selection.")
	_expect(not flow.start_wave(), "A duplicate start while selecting must be rejected.")
	_expect(inventory.total_remaining == 3, "Rejected duplicate start must not reset stock.")
	_expect(not launcher.is_aiming and flow.active_ball == null, "Selection must precede aiming.")
	_expect(not flow.on_ball_drained(), "Drain must be rejected before a ball is in play.")
	_expect(inventory.select_ball(&"heavy"), "Heavy ball should be selectable.")
	_expect(flow.confirm_selection(), "Selected remaining ball should prepare.")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING, "Preparation should enter aiming.")
	_expect(not flow.start_wave(), "A restart while aiming must be rejected.")
	_expect(launcher.is_aiming and flow.active_ball == launcher.prepared_ball, "Aiming should own prepared ball.")
	_expect(inventory.total_remaining == 2, "Stock should consume only after preparation succeeds.")
	_expect(is_equal_approx(flow.active_ball.stats.mass, 8.0), "Selected heavy scene should be prepared.")
	_expect(not flow.confirm_selection(), "Selection cannot repeat while aiming.")

	var first_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Prepared ball should launch through existing launcher.")
	_expect(flow.current_state == WaveBallFlowController.State.IN_PLAY, "Launcher signal should enter in-play.")
	_expect(not inventory.select_ball(&"light") or inventory.selected_definition.ball_id == &"light", "Inventory API remains valid while flow blocks confirmation.")
	_expect(not flow.on_ball_drained(null), "A different drain target must be rejected.")
	_expect(flow.on_ball_drained(first_ball), "Active ball drain should be accepted.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Remaining stock should return to selection.")
	_expect(inventory.selected_definition.ball_id == &"light", "Exhausted heavy type should be skipped.")

	for expected_remaining in [1, 0]:
		_expect(flow.confirm_selection(), "Next light ball should prepare.")
		_expect(inventory.total_remaining == expected_remaining, "Each confirmation should consume one ball.")
		var active := flow.active_ball
		_expect(launcher.launch_prepared_ball(), "Each prepared ball should launch.")
		_expect(flow.on_ball_drained(active), "Each active ball should drain once.")

	_expect(flow.current_state == WaveBallFlowController.State.EXHAUSTED, "Last drain should exhaust wave stock.")
	_expect(not flow.confirm_selection(), "Exhausted state must block selection confirmation.")
	_expect(state_trace == [
		WaveBallFlowController.State.SELECTING,
		WaveBallFlowController.State.AIMING,
		WaveBallFlowController.State.IN_PLAY,
		WaveBallFlowController.State.SELECTING,
		WaveBallFlowController.State.AIMING,
		WaveBallFlowController.State.IN_PLAY,
		WaveBallFlowController.State.SELECTING,
		WaveBallFlowController.State.AIMING,
		WaveBallFlowController.State.IN_PLAY,
		WaveBallFlowController.State.EXHAUSTED,
	], "State trace must enforce selection -> aiming -> play after every drain.")

	await _test_prepare_failure_preserves_stock()

	(fixture.root as Node).queue_free()
	await process_frame
	_finish()


func _test_prepare_failure_preserves_stock() -> void:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var inventory := WaveBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := FLOW_SCRIPT.new() as WaveBallFlowController
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	launcher.spawn_parent_path = ^".."

	var invalid_node := Node2D.new()
	var invalid_scene := PackedScene.new()
	_expect(invalid_scene.pack(invalid_node) == OK, "Invalid fixture scene should pack.")
	invalid_node.free()
	var invalid_stock := _make_stock(&"invalid", invalid_scene, 1)
	inventory.starting_stock = [invalid_stock]
	await process_frame
	flow.bind_inventory(inventory)
	flow.bind_launcher(launcher)
	_expect(flow.start_wave(), "Invalid-scene stock is still selectable metadata.")
	_expect(not flow.confirm_selection(), "Non-Pinball scene must fail preparation.")
	_expect(inventory.total_remaining == 1, "Failed preparation must not consume stock.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Failed preparation must remain selecting.")
	_expect(not launcher.is_aiming and launcher.prepared_ball == null, "Failed preparation must not leave launcher aiming.")
	fixture_root.queue_free()
	await process_frame


func _create_fixture() -> Dictionary:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var inventory := WaveBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := FLOW_SCRIPT.new() as WaveBallFlowController
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	launcher.spawn_parent_path = ^".."

	var light := _make_stock(&"light", LIGHT_BALL, 2)
	var heavy := _make_stock(&"heavy", HEAVY_BALL, 1)
	inventory.starting_stock = [light, heavy]
	await process_frame
	flow.bind_inventory(inventory)
	flow.bind_launcher(launcher)
	return {&"root": fixture_root, &"inventory": inventory, &"launcher": launcher, &"flow": flow}


func _make_stock(ball_id: StringName, scene: PackedScene, count: int) -> BallStock:
	var definition := BallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = String(ball_id).capitalize()
	definition.ball_scene = scene
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = count
	return stock


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_ball_flow_controller_test")
		quit(0)
		return
	print("FAIL: wave_ball_flow_controller_test (%d failures)" % _failures.size())
	quit(1)
