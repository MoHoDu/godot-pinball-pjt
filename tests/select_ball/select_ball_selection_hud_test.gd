extends SceneTree


const HUD_SCENE := preload(
	"res://Resources/Prefabs/ui/ball_selection/current/select_ball_selection_hud_responsive.tscn"
)
const FLOW_SCRIPT := preload(
	"res://scripts/select_ball/select_ball_flow_controller.gd"
)
const LIGHT_BALL := preload("res://Resources/Prefabs/balls/variants/mass/light_ball.tscn")
const NORMAL_BALL := preload("res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn")
const HEAVY_BALL := preload("res://Resources/Prefabs/balls/variants/mass/heavy_ball.tscn")
const CLOCKWORK_BALL := preload("res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn")
const RUBBER_BALL := preload("res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn")
const GEL_BALL := preload("res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var inventory := WaveUniqueBallInventory.new()
	inventory.reusable_owned_balls = true
	inventory.launches_per_wave = 3
	var launcher := PinballLauncher.new()
	var flow := FLOW_SCRIPT.new() as WaveBallFlowController
	var hud := HUD_SCENE.instantiate() as BallSelectionHud
	inventory.starting_stock = [
		_make_stock(&"light", "가벼운 공", LIGHT_BALL, "가볍고 빠르게 반응합니다."),
		_make_stock(&"normal", "보통 공", NORMAL_BALL, "균형 잡힌 공입니다."),
		_make_stock(&"heavy", "무거운 공", HEAVY_BALL, "무겁고 충돌 관성이 큽니다."),
		_make_stock(&"clockwork", "정속 태엽눈", CLOCKWORK_BALL, "속도를 유지합니다."),
		_make_stock(&"rubber", "고무막 유리눈", RUBBER_BALL, "탄성이 높습니다."),
		_make_stock(&"gel", "완충 젤 유리눈", GEL_BALL, "충격을 흡수합니다."),
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

	var all_stock: Array[BallStock] = inventory.starting_stock.duplicate()
	var five_stock: Array[BallStock] = []
	var five_definitions: Array[BallDefinition] = []
	for index: int in range(5):
		five_stock.append(all_stock[index])
		five_definitions.append(all_stock[index].definition)
	_expect(inventory.restore_owned_definitions(five_definitions),
		"Five-ball owned inventory fixture should restore successfully.")
	_expect(inventory.reset_stock(five_stock),
		"Five-ball layout fixture should reset successfully.")
	_expect(inventory.begin_selection(),
		"Five-ball layout fixture should expose a selected ball.")
	await process_frame
	var five_slots := (hud as SelectBallSelectionHudResponsive).slots_container
	_expect(five_slots.get_child_count() == 5 \
		and five_slots.alignment == BoxContainer.ALIGNMENT_CENTER,
		"One to five owned balls should remain centered in the selection row.")

	var all_definitions: Array[BallDefinition] = []
	for stock: BallStock in all_stock:
		all_definitions.append(stock.definition)
	_expect(inventory.restore_owned_definitions(all_definitions),
		"Six-ball owned inventory fixture should restore successfully.")
	_expect(inventory.reset_stock(all_stock),
		"Six-ball overflow fixture should reset successfully.")
	_expect(inventory.begin_selection(),
		"Six-ball overflow fixture should expose a selected ball.")
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

	var slots := (hud as SelectBallSelectionHudResponsive).slots_container
	_expect(slots.get_child_count() == 6, "HUD should keep one slot per owned ball.")
	var slots_scroll := hud.get_node("Center/Panel/Margin/VBox/SlotsScroll") \
		as ScrollContainer
	_expect(slots_scroll != null,
		"Six or more owned balls should be presented in a horizontal scroll row.")
	var clockwork_button := _find_slot(slots, &"clockwork")
	var light_button := _find_slot(slots, &"light")
	if clockwork_button != null and light_button != null:
		var clockwork_icon := clockwork_button.get_node("%BallIcon") as TextureRect
		var light_icon := light_button.get_node("%BallIcon") as TextureRect
		_expect(clockwork_icon.texture != light_icon.texture,
			"Selection slots must use the ball-specific presentation image.")
	var gel_button := _find_slot(slots, &"gel")
	if gel_button != null:
		gel_button.emit_signal(&"pressed")
		await process_frame
		_expect(slots_scroll.scroll_horizontal > 0,
			"Selecting an overflow slot should reveal it automatically.")
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
	_expect(inventory.selected_definition.ball_id == &"clockwork",
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
