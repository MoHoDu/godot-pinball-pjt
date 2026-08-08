extends SceneTree


const LIGHT_BALL := preload("res://Resources/Prefabs/balls/variants/mass/light_ball.tscn")
const HEAVY_BALL := preload("res://Resources/Prefabs/balls/variants/mass/heavy_ball.tscn")
const FLOW_SCRIPT := preload(
	"res://scripts/select_ball/select_ball_flow_controller.gd"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var inventory := SelectBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := FLOW_SCRIPT.new() as WaveBallFlowController
	inventory.starting_stock = [
		_make_stock(&"light", "가벼운 공", LIGHT_BALL),
		_make_stock(&"heavy", "무거운 공", HEAVY_BALL),
	]
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	launcher.spawn_parent_path = ^".."
	await process_frame
	_expect(flow.bind_inventory(inventory), "Flow should bind the select-ball inventory.")
	_expect(flow.bind_launcher(launcher), "Flow should bind the existing launcher.")

	_expect(flow.start_wave(), "Wave should start with owned balls.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Wave should begin in selecting state.")
	_expect(inventory.selected_definition.ball_id == &"light",
		"The first available ball should be preselected.")
	_expect(flow.confirm_selection(), "Explicit confirmation should prepare the selected ball.")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING,
		"Confirmation should enter aiming.")
	_expect(inventory.total_remaining == 2 and not inventory.is_ball_used(&"light"),
		"Confirmation alone must not mark the ball used.")
	_expect(inventory.select_ball(&"heavy"),
		"External selection mutation should remain safe while aiming.")

	var first_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Existing launcher should launch the prepared ball.")
	_expect(flow.current_state == WaveBallFlowController.State.IN_PLAY,
		"A successful launcher signal should enter in-play.")
	_expect(inventory.total_remaining == 1 \
		and inventory.is_ball_used(&"light") \
		and not inventory.is_ball_used(&"heavy"),
		"Only the ball actually prepared and launched should lock for this wave.")
	_expect(not inventory.select_ball(&"light"),
		"A launched ball must not be reselected during the same wave.")
	_expect(flow.on_ball_drained(first_ball), "Active launched ball should drain normally.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"A drain with another available ball should reopen selection.")
	_expect(inventory.selected_definition.ball_id == &"heavy",
		"Selection should advance to the next unused ball.")

	_expect(flow.confirm_selection(), "The remaining unused ball should prepare.")
	_expect(inventory.total_remaining == 1 and not inventory.is_ball_used(&"heavy"),
		"The second confirmation should also preserve availability until launch.")
	var second_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "The second prepared ball should launch.")
	_expect(inventory.total_remaining == 0 and inventory.is_ball_used(&"heavy"),
		"The second successful launch should exhaust wave availability.")
	_expect(flow.on_ball_drained(second_ball), "The final active ball should drain.")
	_expect(flow.current_state == WaveBallFlowController.State.EXHAUSTED,
		"The flow should exhaust only after every owned ball has launched once.")
	_expect(flow.retry_wave(), "Retry should start a fresh wave from exhausted state.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING \
		and inventory.total_remaining == 2,
		"Retry should restore every owned ball's wave-only availability.")
	_expect(not inventory.is_ball_used(&"light") \
		and not inventory.is_ball_used(&"heavy") \
		and inventory.selected_definition.ball_id == &"light",
		"Retry should clear usage locks and preselect the first ball again.")

	fixture_root.queue_free()
	await process_frame
	_finish()


func _make_stock(
	ball_id: StringName,
	display_name: String,
	ball_scene: PackedScene
) -> BallStock:
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = ball_scene
	definition.feature_summary = "%s의 핵심 특징" % display_name
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 1
	return stock


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: select_ball_flow_controller_test")
		quit(0)
		return
	print("FAIL: select_ball_flow_controller_test (%d failures)" % _failures.size())
	quit(1)
