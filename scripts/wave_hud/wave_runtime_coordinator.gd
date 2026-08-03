class_name WaveRuntimeCoordinator
extends "res://tests/combo_system/test_flipper_wave_board.gd"


@onready var hud_state: WaveHudStateSource = get_node_or_null(
	"WaveHudStateSource"
) as WaveHudStateSource
@onready var wave_hud: WaveHud = get_node_or_null("HUD/WaveHud") as WaveHud
@onready var combo_anchor: Node2D = get_node_or_null(
	"Bumpers/BumperCenter"
) as Node2D


var _selection_committed := false


func _ready() -> void:
	super()
	assert(is_instance_valid(hud_state), "Wave scene requires WaveHudStateSource.")
	assert(is_instance_valid(wave_hud), "Wave scene requires WaveHud.")
	wave_hud.bind_state_source(hud_state)
	wave_hud.settings_requested.connect(_toggle_pause)
	_connect_hud_state_inputs()
	_initialize_hud_state()
	_update_combo_anchor()


func _process(delta: float) -> void:
	super(delta)
	_update_combo_anchor()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	super(event)


func _connect_hud_state_inputs() -> void:
	combo_system.combo_changed.connect(_on_combo_changed)
	combo_system.score_changed.connect(_on_score_changed)
	wave_ball_inventory.stock_reset.connect(_on_inventory_stock_reset)
	wave_ball_inventory.selection_started.connect(_on_inventory_selection)
	wave_ball_inventory.selection_changed.connect(_on_inventory_selection)
	wave_ball_inventory.ball_consumed.connect(_on_inventory_ball_consumed)
	wave_ball_flow.state_changed.connect(_on_ball_flow_state_changed)
	wave_ball_flow.ball_drained.connect(_on_flow_ball_drained)
	wave_manager.wave_entered.connect(_on_manager_wave_entered)
	wave_manager.wave_retried.connect(_on_manager_wave_retried)


func _initialize_hud_state() -> void:
	hud_state.begin_batch()
	_configure_lives_from_inventory()
	_select_inventory_life()
	hud_state.set_score(wave_manager.current_score, wave_manager.target_score)
	hud_state.observe_combo(combo_system.combo_count)
	hud_state.set_wave_index(wave_manager.current_wave_index)
	hud_state.set_paused(get_tree().paused)
	hud_state.end_batch()


func _configure_lives_from_inventory() -> void:
	var ball_types: Array[StringName] = []
	for stock: BallStock in wave_ball_inventory.starting_stock:
		if stock == null or not stock.is_valid():
			continue
		for _copy in stock.count:
			ball_types.append(stock.definition.ball_id)
	assert(ball_types.size() >= 3 and ball_types.size() <= 5,
		"Wave HUD requires the actual wave inventory to contain three to five balls.")
	if ball_types.size() < 3 or ball_types.size() > 5:
		return
	hud_state.configure_lives(ball_types)


func _select_inventory_life() -> void:
	if wave_ball_inventory.selected_definition == null:
		return
	hud_state.select_life(wave_ball_inventory.selected_definition.ball_id)


func _on_inventory_stock_reset(_total_remaining: int) -> void:
	_selection_committed = false
	hud_state.begin_batch()
	_configure_lives_from_inventory()
	_select_inventory_life()
	hud_state.end_batch()


func _on_inventory_selection(
	definition: BallDefinition,
	_remaining_for_type: int
) -> void:
	if _selection_committed or definition == null:
		return
	hud_state.select_life(definition.ball_id)


func _on_inventory_ball_consumed(
	_definition: BallDefinition,
	_remaining_for_type: int,
	_total_remaining: int
) -> void:
	# Inventory may preselect another type while confirm_selection() is still
	# committing the active ball. Keep the launched ball highlighted until drain.
	_selection_committed = true


func _on_ball_flow_state_changed(
	_previous_state: WaveBallFlowController.State,
	current_state: WaveBallFlowController.State
) -> void:
	if current_state == WaveBallFlowController.State.SELECTING:
		_selection_committed = false


func _on_flow_ball_drained(_ball: Pinball, remaining_balls: int) -> void:
	var hud_remaining := hud_state.consume_current_life()
	if hud_remaining != remaining_balls:
		push_warning(
			"Wave HUD life state diverged from inventory: hud=%d inventory=%d"
			% [hud_remaining, remaining_balls]
		)


func _on_manager_wave_entered(
	_wave_stage_id: StringName,
	wave_index: int,
	target_score: int
) -> void:
	hud_state.begin_batch()
	hud_state.reset_combo()
	hud_state.set_wave_index(wave_index)
	hud_state.set_score(wave_manager.current_score, target_score)
	hud_state.end_batch()


func _on_manager_wave_retried() -> void:
	hud_state.begin_batch()
	hud_state.reset_combo()
	hud_state.set_score(wave_manager.current_score, wave_manager.target_score)
	hud_state.end_batch()


func _on_combo_changed(combo_count: int, _tier: int, _time_remaining: float) -> void:
	hud_state.observe_combo(combo_count)


func _on_score_changed(total_score: int, _added_score: int) -> void:
	hud_state.set_score(total_score, wave_manager.target_score)


func _update_combo_anchor() -> void:
	if not is_instance_valid(combo_anchor):
		hud_state.set_combo_anchor(Vector2.ZERO, false)
		return
	var viewport_position := combo_anchor.get_global_transform_with_canvas().origin
	hud_state.set_combo_anchor(viewport_position, true)


func _toggle_pause() -> void:
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	hud_state.set_paused(next_paused)
