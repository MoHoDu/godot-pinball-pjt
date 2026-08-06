extends SceneTree


const TEST_SCENE := preload("res://scenes/select-ball/select_ball_test.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := TEST_SCENE.instantiate()
	var pending_inventory := scene.get_node("WaveBallInventory") as WaveBallInventory
	for stock: BallStock in pending_inventory.starting_stock:
		stock.count = 7
	root.add_child(scene)
	await process_frame
	await process_frame

	var inventory := scene.get_node("WaveBallInventory") as WaveBallInventory
	var flow := scene.get_node("WaveBallFlowController") as WaveBallFlowController
	var launcher := scene.get_node("PinballLauncher") as PinballLauncher
	var hud := scene.get_node("HUD/BallSelectionHud") as BallSelectionHud
	_expect(inventory.get_script().resource_path \
		== "res://scripts/select_ball/select_ball_inventory.gd",
		"Test scene should use the new select-ball inventory.")
	_expect(flow.get_script().resource_path \
		== "res://scripts/select_ball/select_ball_flow_controller.gd",
		"Test scene should use the new select-ball flow.")
	_expect(hud.get_script().resource_path \
		== "res://scripts/select_ball/select_ball_selection_hud.gd",
		"Test scene should use the new dummy selection HUD.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Test scene should enter the new selection flow on startup.")
	_expect(inventory.selected_definition.ball_id == &"light",
		"The first available ball should be preselected in the test scene.")
	_expect(hud.visible and hud.ball_name_label.text == "가벼운 공",
		"Dummy HUD should show the first selected ball.")
	_expect(not hud.stock_label.visible,
		"Dummy HUD should not expose legacy quantity information.")

	_expect(flow.confirm_selection(),
		"Explicit confirmation should prepare the selected test-scene ball.")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING,
		"Confirmation should hand off to the existing aiming state.")
	_expect(inventory.total_remaining == 3,
		"Legacy stock counts must not duplicate unique owned balls.")
	var life_slots: Array = (
		(scene.get_node("WaveHudStateSource") as WaveHudStateSource)
		.get_snapshot()[&"life_slots"]
	)
	_expect(life_slots.size() == 3,
		"Wave HUD should also keep one life slot per unique owned ball.")
	var launched_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(),
		"Existing launcher input path should launch the confirmed ball.")
	_expect(inventory.total_remaining == 2 \
		and bool(inventory.call(&"is_ball_used", &"light")),
		"Actual launch should lock only that ball for the wave.")
	_expect(flow.on_ball_drained(launched_ball),
		"Launched test-scene ball should resolve through the existing drain flow.")
	await process_frame
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Drain should reopen the new selection UI while unused balls remain.")
	_expect(inventory.selected_definition.ball_id == &"normal",
		"The next unused ball should be selected after reopening.")
	_expect(not inventory.select_ball(&"light"),
		"The launched ball should not be selectable again this wave.")
	var light_slot := _find_slot(hud.get_node("%SlotsContainer"), &"light")
	_expect(light_slot != null and light_slot.disabled,
		"Used ball should stay visible as a disabled slot in the test scene.")

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _find_slot(container: Node, ball_id: StringName) -> Button:
	for child: Node in container.get_children():
		if child is Button and child.get_meta(&"ball_id", &"") == ball_id:
			return child as Button
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: select_ball_test_scene_integration_test")
		quit(0)
		return
	print("FAIL: select_ball_test_scene_integration_test (%d failures)" \
		% _failures.size())
	quit(1)
