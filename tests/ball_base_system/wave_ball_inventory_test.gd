extends SceneTree


const INVENTORY_SCRIPT := preload(
	"res://scripts/ball_base_system/wave_ball_inventory.gd"
)
const BALL_DEFINITION_SCRIPT := preload(
	"res://scripts/ball_base_system/ball_definition.gd"
)
const BALL_STOCK_SCRIPT := preload(
	"res://scripts/ball_base_system/ball_stock.gd"
)
const LIGHT_BALL := preload("res://Resources/Prefabs/balls/variants/mass/light_ball.tscn")
const HEAVY_BALL := preload("res://Resources/Prefabs/balls/variants/mass/heavy_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var inventory := INVENTORY_SCRIPT.new() as WaveBallInventory
	root.add_child(inventory)
	await process_frame

	var light := _make_stock(&"light", "Light", LIGHT_BALL, 2)
	var heavy := _make_stock(&"heavy", "Heavy", HEAVY_BALL, 1)
	var duplicate_light := _make_stock(&"light", "Duplicate", HEAVY_BALL, 8)
	var invalid := BALL_STOCK_SCRIPT.new() as BallStock
	invalid.count = 3
	var configured: Array[BallStock] = [light, heavy, duplicate_light, invalid]

	_expect(inventory.reset_stock(configured), "A valid stock should configure the inventory.")
	_expect(inventory.total_remaining == 3, "Invalid and duplicate stock must be ignored.")
	_expect(inventory.begin_selection(&"heavy"), "A remaining preferred ball should be selectable.")
	_expect(inventory.selected_definition.ball_id == &"heavy", "Preferred selection should win.")
	_expect(inventory.select_next(), "Selection should cycle through remaining ball types.")
	_expect(inventory.selected_definition.ball_id == &"light", "Next selection should wrap.")
	_expect(inventory.select_previous(), "Previous selection should cycle backwards.")
	_expect(inventory.selected_definition.ball_id == &"heavy", "Previous selection should wrap.")
	_expect(inventory.select_next(), "Selection should return to light.")

	var first := inventory.consume_selected_ball()
	_expect(first == light.definition, "Consume should return the selected definition.")
	_expect(inventory.get_remaining_count(&"light") == 1, "Consume should decrement only its type.")
	_expect(inventory.total_remaining == 2, "Consume should decrement total stock.")

	var auto_selection_changes := {&"value": 0}
	inventory.selection_changed.connect(func(
		_definition: BallDefinition, _remaining: int
	) -> void:
		auto_selection_changes.value += 1
	)
	_expect(inventory.select_ball(&"heavy"), "A remaining ball should be directly selectable.")
	_expect(inventory.consume_selected_ball() == heavy.definition, "Selected heavy ball should consume.")
	_expect(not inventory.select_ball(&"heavy"), "An exhausted ball type must not be selectable.")
	_expect(inventory.selected_definition.ball_id == &"light", "Selection should advance off exhausted type.")
	_expect(auto_selection_changes.value == 2, "Direct and automatic selection changes should both emit.")
	_expect(inventory.consume_selected_ball() == light.definition, "Last ball should consume.")
	_expect(inventory.total_remaining == 0 and not inventory.has_selection(), "Inventory should end exhausted.")
	_expect(inventory.consume_selected_ball() == null, "Exhausted inventory must reject consumption.")
	_expect(not inventory.begin_selection(), "Exhausted inventory must reject selection.")

	_expect(inventory.reset_stock(configured), "Stock should be reusable after exhaustion.")
	_expect(inventory.begin_selection(&"missing"), "Unknown preferred id should fall back to an available ball.")
	_expect(inventory.selected_definition.ball_id == &"light", "Preferred id fallback should use first available.")

	inventory.queue_free()
	await process_frame
	_finish()


func _make_stock(
	ball_id: StringName,
	display_name: String,
	ball_scene: PackedScene,
	count: int
) -> BallStock:
	var definition := BALL_DEFINITION_SCRIPT.new() as BallDefinition
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = ball_scene
	var stock := BALL_STOCK_SCRIPT.new() as BallStock
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
		print("PASS: wave_ball_inventory_test")
		quit(0)
		return
	print("FAIL: wave_ball_inventory_test (%d failures)" % _failures.size())
	quit(1)
