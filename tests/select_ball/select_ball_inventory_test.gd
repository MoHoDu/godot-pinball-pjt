extends SceneTree


const LIGHT_BALL := preload("res://Resources/balls/mass_var/light_ball.tscn")
const NORMAL_BALL := preload("res://Resources/balls/mass_var/normal_ball.tscn")
const HEAVY_BALL := preload("res://Resources/balls/mass_var/heavy_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var inventory := SelectBallInventory.new()
	var light := _make_stock(&"light", "가벼운 공", LIGHT_BALL, 9)
	var normal := _make_stock(&"normal", "보통 공", NORMAL_BALL, 1)
	var heavy := _make_stock(&"heavy", "무거운 공", HEAVY_BALL, 1)
	var duplicate_light := _make_stock(&"light", "중복 공", HEAVY_BALL, 4)
	inventory.starting_stock = [light, normal, heavy, duplicate_light]
	root.add_child(inventory)
	await process_frame

	_expect(inventory.total_remaining == 3,
		"Owned inventory should keep one entry per ball id regardless of stock count.")
	_expect(inventory.get_owned_definitions().size() == 3,
		"Duplicate ball ids should not create duplicate owned entries.")
	_expect(inventory.begin_selection(), "A configured inventory should begin selection.")
	_expect(inventory.selected_definition == light.definition,
		"The first available owned ball should be preselected.")
	_expect(inventory.select_ball(&"heavy"), "An unused owned ball should be selectable.")

	var used := inventory.mark_selected_ball_used()
	_expect(used == heavy.definition, "Launch usage should return the selected definition.")
	_expect(inventory.total_remaining == 2,
		"Wave availability should decrease once after an actual launch.")
	_expect(inventory.is_ball_used(&"heavy"),
		"Launched ball should be locked for the current wave.")
	_expect(not inventory.select_ball(&"heavy"),
		"A ball already launched this wave must not be selectable again.")
	_expect(inventory.get_owned_definitions().size() == 3,
		"Wave usage must not remove the ball from ownership.")
	_expect(inventory.get_used_ball_ids() == [&"heavy"],
		"Used id list should contain only launched balls.")

	_expect(inventory.reset_stock(), "Wave reset should restore owned ball availability.")
	_expect(inventory.total_remaining == 3 and not inventory.is_ball_used(&"heavy"),
		"A new or retried wave should clear wave-only usage locks.")
	_expect(inventory.begin_selection(), "Selection should restart after wave reset.")
	_expect(inventory.selected_definition == light.definition,
		"Wave reset should preselect the first available ball again.")

	inventory.queue_free()
	await process_frame
	await _test_reusable_owned_ball_mode()
	_finish()


func _test_reusable_owned_ball_mode() -> void:
	var inventory := SelectBallInventory.new()
	inventory.reusable_owned_balls = true
	inventory.launches_per_wave = 3
	var normal := _make_stock(&"normal", "보통 공", NORMAL_BALL, 3)
	inventory.starting_stock = [normal]
	root.add_child(inventory)
	await process_frame

	_expect(inventory.total_remaining == 3,
		"Reusable mode should expose the configured launch budget.")
	var reward_definition := SelectBallDefinition.new()
	reward_definition.ball_id = &"clockwork"
	reward_definition.display_name = "정속 태엽눈"
	reward_definition.ball_scene = NORMAL_BALL
	reward_definition.feature_summary = "속도를 일정하게 유지합니다."
	_expect(inventory.add_owned_definition(reward_definition),
		"A purchased reward ball should join the persistent owned list.")
	_expect(inventory.get_owned_definitions().size() == 2,
		"Purchased ownership should be independent from launch count.")
	_expect(inventory.begin_selection(&"clockwork") \
		and inventory.selected_definition == reward_definition,
		"A purchased ball should be selectable before launch.")
	_expect(inventory.mark_selected_ball_used() == reward_definition,
		"Launching a purchased ball should succeed.")
	_expect(inventory.total_remaining == 2 \
		and inventory.select_ball(&"clockwork"),
		"The same owned ball should remain selectable for the next launch.")
	_expect(inventory.mark_selected_ball_used() == reward_definition \
		and inventory.total_remaining == 1,
		"Repeated use should spend only the shared wave launch budget.")
	_expect(inventory.select_ball(&"normal") \
		and inventory.mark_selected_ball_used() == normal.definition,
		"The final launch may switch back to another owned ball.")
	_expect(inventory.total_remaining == 0,
		"Three successful launches should exhaust the wave budget.")
	_expect(inventory.reset_stock() and inventory.total_remaining == 3,
		"A new wave should restore three launches without removing purchases.")
	_expect(inventory.get_owned_definitions().size() == 2,
		"Wave reset must preserve purchased ball ownership.")

	inventory.queue_free()
	await process_frame


func _make_stock(
	ball_id: StringName,
	display_name: String,
	ball_scene: PackedScene,
	count: int
) -> BallStock:
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = ball_scene
	definition.feature_summary = "%s의 핵심 특징" % display_name
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
		print("PASS: select_ball_inventory_test")
		quit(0)
		return
	print("FAIL: select_ball_inventory_test (%d failures)" % _failures.size())
	quit(1)
