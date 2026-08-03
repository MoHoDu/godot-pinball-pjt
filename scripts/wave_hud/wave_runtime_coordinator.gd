class_name WaveRuntimeCoordinator
extends "res://tests/combo_system/test_flipper_wave_board.gd"


const HUD_DESIGN_SIZE := Vector2(1920.0, 1080.0)


@onready var hud_state: WaveHudStateSource = get_node_or_null(
	"WaveHudStateSource"
) as WaveHudStateSource
@onready var wave_hud: WaveHud = get_node_or_null("HUD/WaveHud") as WaveHud
@onready var combo_anchor: Node2D = get_node_or_null(
	"Bumpers/BumperCenter"
) as Node2D
@onready var board_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D


@export_category("Wave Board Camera")
@export var board_world_bounds := Rect2(-1180.0, -700.0, 2360.0, 1400.0)
@export_range(0.01, 4.0, 0.001) var maximum_board_zoom := 0.494
@export_range(0.0, 1080.0, 1.0) var hud_safe_top_design := 190.0
@export_range(0.0, 256.0, 1.0) var board_margin_design := 24.0


var _selection_committed := false
var _camera_viewport_size := Vector2.ZERO


func _ready() -> void:
	super()
	assert(is_instance_valid(hud_state), "Wave scene requires WaveHudStateSource.")
	assert(is_instance_valid(wave_hud), "Wave scene requires WaveHud.")
	wave_hud.bind_state_source(hud_state)
	wave_hud.settings_requested.connect(_toggle_pause)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_connect_hud_state_inputs()
	_initialize_hud_state()
	_fit_board_camera(true)
	_update_combo_anchor()


func _process(delta: float) -> void:
	super(delta)
	_fit_board_camera()
	_update_combo_anchor()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	super(event)


func reset_combo_test() -> void:
	super()
	if is_instance_valid(hud_state):
		hud_state.reset_combo()


func _connect_hud_state_inputs() -> void:
	combo_system.combo_changed.connect(_on_combo_changed)
	combo_system.combo_finished.connect(_on_combo_display_finished)
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


func _on_combo_display_finished(
	_combo_count: int,
	_tier: int,
	_awarded_score: int,
	_reason: int
) -> void:
	hud_state.finish_combo_display()


func _on_score_changed(total_score: int, _added_score: int) -> void:
	hud_state.set_score(total_score, wave_manager.target_score)


func _update_combo_anchor() -> void:
	if not is_instance_valid(combo_anchor):
		hud_state.set_combo_anchor(Vector2.ZERO, false)
		return
	var viewport_position := combo_anchor.get_global_transform_with_canvas().origin
	hud_state.set_combo_anchor(viewport_position, true)


func _fit_board_camera(force := false) -> void:
	if not is_instance_valid(board_camera) or not is_instance_valid(wave_hud):
		return
	var viewport_size := get_viewport_rect().size
	if not force and viewport_size.is_equal_approx(_camera_viewport_size):
		return
	_camera_viewport_size = viewport_size

	# Calculate from the current viewport directly. The coordinator processes
	# before the child HUD, so reading the HUD's cached transform would use the
	# previous frame's scale during a live window resize.
	var design_scale := maxf(minf(
		viewport_size.x / HUD_DESIGN_SIZE.x,
		viewport_size.y / HUD_DESIGN_SIZE.y
	), 0.001)
	var design_offset := (viewport_size - HUD_DESIGN_SIZE * design_scale) * 0.5
	var scaled_margin := board_margin_design * design_scale
	var safe_left := design_offset.x + scaled_margin
	var safe_top := design_offset.y + hud_safe_top_design * design_scale
	var safe_right := viewport_size.x - design_offset.x - scaled_margin
	var safe_bottom := viewport_size.y - design_offset.y - scaled_margin
	var safe_size := Vector2(
		maxf(safe_right - safe_left, 1.0),
		maxf(safe_bottom - safe_top, 1.0)
	)
	var fitted_zoom := minf(
		safe_size.x / maxf(board_world_bounds.size.x, 1.0),
		safe_size.y / maxf(board_world_bounds.size.y, 1.0)
	)
	fitted_zoom = minf(fitted_zoom, maximum_board_zoom)
	fitted_zoom = maxf(fitted_zoom, 0.01)
	board_camera.zoom = Vector2.ONE * fitted_zoom

	var safe_center := Vector2(
		(safe_left + safe_right) * 0.5,
		(safe_top + safe_bottom) * 0.5
	)
	var viewport_center := viewport_size * 0.5
	board_camera.position = board_world_bounds.get_center() \
		- (safe_center - viewport_center) / fitted_zoom


func _on_viewport_size_changed() -> void:
	_fit_board_camera(true)


func _toggle_pause() -> void:
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	hud_state.set_paused(next_paused)
