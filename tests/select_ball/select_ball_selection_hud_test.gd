extends SceneTree


const HUD_SCENE := preload(
	"res://scenes/select-ball/select_ball_selection_hud.tscn"
)
const FLOW_SCRIPT := preload(
	"res://scripts/select_ball/select_ball_flow_controller.gd"
)
const LIGHT_BALL := preload("res://Resources/balls/mass_var/light_ball.tscn")
const HEAVY_BALL := preload("res://Resources/balls/mass_var/heavy_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var inventory := SelectBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := FLOW_SCRIPT.new() as WaveBallFlowController
	var hud := HUD_SCENE.instantiate() as BallSelectionHud
	inventory.starting_stock = [
		_make_stock(&"light", "가벼운 공", LIGHT_BALL, "가볍고 빠르게 반응합니다."),
		_make_stock(&"heavy", "무거운 공", HEAVY_BALL, "무겁고 충돌 관성이 큽니다."),
	]
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	fixture_root.add_child(hud)
	launcher.spawn_parent_path = ^".."
	await process_frame
	_expect(flow.bind_inventory(inventory), "Flow should bind inventory.")
	_expect(flow.bind_launcher(launcher), "Flow should bind launcher.")
	_expect(hud.bind_ball_flow(flow), "Dummy HUD should bind the new flow.")
	_expect(flow.start_wave(), "Wave should open ball selection.")
	await process_frame

	_expect(hud.visible, "Selection HUD should be visible while selecting.")
	_expect(hud.ball_name_label.text == "가벼운 공",
		"First available ball should be displayed automatically.")
	_expect((hud.get_node("%MassLabel") as Label).text == "무게 0.5 kg",
		"HUD should display effective mass from Pinball physics data.")
	_expect((hud.get_node("%ElasticityLabel") as Label).text == "탄성 50%",
		"HUD should display effective elasticity from Pinball physics data.")
	_expect((hud.get_node("%FeatureLabel") as Label).text == "가볍고 빠르게 반응합니다.",
		"HUD should display the authored one-line feature summary.")
	_expect(not hud.stock_label.visible, "HUD must not display quantity information.")

	var slots := hud.get_node("%SlotsContainer") as HBoxContainer
	_expect(slots.get_child_count() == 2, "HUD should keep one slot per owned ball.")
	var heavy_button := _find_slot(slots, &"heavy")
	_expect(heavy_button != null, "Heavy ball slot should exist.")
	if heavy_button != null:
		heavy_button.emit_signal(&"pressed")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Choosing a slot must not confirm automatically.")
	_expect(inventory.selected_definition.ball_id == &"heavy",
		"Slot click should update only the current selection.")
	_expect(hud.ball_name_label.text == "무거운 공",
		"Information should update when selection changes.")

	(hud.get_node("%ConfirmButton") as Button).emit_signal(&"pressed")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING,
		"Separate confirmation should enter aiming.")
	_expect(not inventory.is_ball_used(&"heavy"),
		"Confirmed but unlaunched ball must remain unused.")
	var launched_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Prepared ball should launch.")
	_expect(inventory.is_ball_used(&"heavy"),
		"Successful launch should mark the ball used for the wave.")
	_expect(flow.on_ball_drained(launched_ball), "Launched ball should drain.")
	await process_frame
	_expect(hud.visible, "Selection HUD should reopen after drain.")
	var used_heavy_button := _find_slot(slots, &"heavy")
	_expect(used_heavy_button != null and used_heavy_button.disabled,
		"Used ball slot should remain visible but disabled.")
	_expect(inventory.selected_definition.ball_id == &"light",
		"The next unused ball should be preselected on reopen.")

	fixture_root.queue_free()
	await process_frame
	_finish()


func _find_slot(container: HBoxContainer, ball_id: StringName) -> Button:
	for child: Node in container.get_children():
		if child is Button and child.get_meta(&"ball_id", &"") == ball_id:
			return child as Button
	return null


func _make_stock(
	ball_id: StringName,
	display_name: String,
	ball_scene: PackedScene,
	feature_summary: String
) -> BallStock:
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = ball_scene
	definition.feature_summary = feature_summary
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
		print("PASS: select_ball_selection_hud_test")
		quit(0)
		return
	print("FAIL: select_ball_selection_hud_test (%d failures)" % _failures.size())
	quit(1)
