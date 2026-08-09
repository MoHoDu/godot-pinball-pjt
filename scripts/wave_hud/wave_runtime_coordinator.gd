class_name WaveRuntimeCoordinator
extends Node2D


const HUD_DESIGN_SIZE := Vector2(1920.0, 1080.0)
const COTTON_KIND_ID: StringName = &"stage01_cotton"
const TOY_DRUM_KIND_ID: StringName = &"stage01_toy_drum"
const SETTINGS_POPUP_SCENE := preload(
	"res://Resources/Prefabs/ui/settings/settings_popup.tscn"
)
const START_SCREEN_PATH := "res://scenes/game/start/start_screen.tscn"


@export_category("Wave Configuration")
@export var wave_stage_settings: ComboStageSettings
@export var bumper_stage_settings: BumperStageSettings
@export_range(0, 99, 1) var wave_stage_index := 0
@export_range(0, 99, 1) var authored_bumper_wave_index := 0
@export var expected_bumper_kind_ids: Array[StringName] = []
## false이면 이 씬의 Expected Bumper Kind Ids를 최종 로스터로 사용합니다.
## Inspector 편집 도구로 범퍼를 추가·삭제하면 자동으로 false가 됩니다.
@export var enforce_stage_bumper_limits := true
## 상속 씬에서 직접 지울 수 없는 기본 범퍼를 웨이브별로 제외합니다.
## 경로는 Bumpers 기준 상대 경로입니다.
@export var disabled_bumper_paths: Array[NodePath] = []

@export_category("Runtime Dependencies")
@export var launcher: PinballLauncher
@export var combo_system: ComboSystem
@export var combo_collision_bridge: ComboCollisionBridge
@export var wave_ball_inventory: WaveBallInventory
@export var wave_ball_flow: WaveBallFlowController
@export var combo_wave_controller: ComboWaveController
@export var wave_manager: WaveManager
@export var flipper_selector: FlipperSelector
@export var ball_selection_hud: BallSelectionHud
@export var ball_drain_area: Area2D
@export var hud_state: WaveHudStateSource
@export var wave_hud: WaveHud
@export var board_camera: Camera2D
@export var bumpers_root: Node

@export_category("Wave Board Camera")
@export var board_world_bounds := Rect2(-1180.0, -700.0, 2360.0, 1400.0)
@export_range(0.01, 4.0, 0.001) var maximum_board_zoom := 0.494
@export_range(0.0, 1080.0, 1.0) var hud_safe_top_design := 190.0
@export_range(0.0, 256.0, 1.0) var board_margin_design := 24.0


var ball: Pinball
var _wave_settings := ComboStageSettings.new()
var _selection_committed := false
var _camera_viewport_size := Vector2.ZERO
var _drain_pending := false
var _active_shot_controls := 0
var _settings_layer: CanvasLayer
var _settings_popup: Variant
var _paused_before_settings := false


func _ready() -> void:
	_apply_disabled_bumpers()
	_assert_required_nodes()
	_bind_bumper_runtime()
	_bind_wave_runtime()
	wave_hud.bind_state_source(hud_state)
	_setup_settings_popup()
	wave_hud.settings_requested.connect(_on_settings_requested)
	wave_hud.advance_stage_phase_requested.connect(_on_advance_stage_phase_requested)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_connect_hud_state_inputs()
	ball_selection_hud.bind_ball_flow(wave_ball_flow)
	_set_flipper_input_enabled(false)

	if wave_stage_settings == null:
		_wave_settings.stage_id = &"main_demo_stage"
		_wave_settings.stage_base_score = 100
		_wave_settings.wave_target_scores = PackedInt32Array([500])
	else:
		_wave_settings = wave_stage_settings

	assert(
		is_current_bumper_loadout_valid(),
		"Wave scene bumper instances must satisfy the configured stage loadout."
	)
	_enter_initial_stage(_wave_settings, wave_stage_index)
	_initialize_hud_state()
	_fit_board_camera(true)


func _enter_initial_stage(
	stage_settings: Resource,
	start_wave_index: int
) -> bool:
	return wave_manager.enter_stage(stage_settings, start_wave_index)


func _process(_delta: float) -> void:
	_fit_board_camera()


func _unhandled_input(_event: InputEvent) -> void:
	if get_tree().paused:
		return


func _exit_tree() -> void:
	if is_instance_valid(_settings_popup) and _settings_popup.visible:
		get_tree().paused = _paused_before_settings


func reset_combo_test() -> void:
	if is_instance_valid(combo_system):
		combo_system.reset_wave()
	if is_instance_valid(hud_state):
		hud_state.reset_combo()


func reset_ball() -> void:
	if not is_instance_valid(wave_ball_flow) or not is_instance_valid(wave_manager):
		return
	if wave_manager.current_state == WaveManager.State.IN_PLAY:
		_handle_ball_drained("R manual drain")
		return
	if wave_manager.current_state in [
		WaveManager.State.WON,
		WaveManager.State.LOST,
	]:
		wave_manager.retry_wave()


func get_bumpers() -> Array[Bumper]:
	var result: Array[Bumper] = []
	if bumpers_root == null:
		return result
	for child: Node in bumpers_root.get_children():
		if child is Bumper and not _is_bumper_disabled(child):
			result.append(child as Bumper)
	return result


func is_current_bumper_loadout_valid() -> bool:
	var loadout: BumperWaveLoadout
	if enforce_stage_bumper_limits:
		if bumper_stage_settings == null:
			return false
		loadout = bumper_stage_settings.get_wave(
			authored_bumper_wave_index
		) as BumperWaveLoadout
		if loadout == null or not loadout.is_valid():
			return false

	var bumpers := get_bumpers()
	var normal_count := 0
	var bounce_count := 0
	var shot_count := 0
	var kind_counts: Dictionary = {}
	for bumper: Bumper in bumpers:
		if bumper.settings == null or not bumper.settings.is_valid():
			return false
		var kind_id := bumper.settings.bumper_kind_id
		kind_counts[kind_id] = int(kind_counts.get(kind_id, 0)) + 1
		if bumper.settings.maximum_per_board > 0 \
				and int(kind_counts[kind_id]) > bumper.settings.maximum_per_board:
			return false
		match bumper.settings.bumper_type:
			BumperSettings.BumperType.NORMAL:
				normal_count += 1
			BumperSettings.BumperType.BOUNCE:
				bounce_count += 1
			BumperSettings.BumperType.SHOT:
				shot_count += 1
	var expected_kind_counts: Dictionary = {}
	for kind_id: StringName in expected_bumper_kind_ids:
		expected_kind_counts[kind_id] = int(
			expected_kind_counts.get(kind_id, 0)
		) + 1

	var expected_roster_matches := (
		expected_kind_counts.is_empty() or kind_counts == expected_kind_counts
	)
	if not expected_roster_matches:
		return false
	if not enforce_stage_bumper_limits:
		return true

	return (
		_is_count_in_range(bumpers.size(), loadout.total_count_range)
		and _is_count_in_range(normal_count, loadout.normal_count_range)
		and _is_count_in_range(bounce_count, loadout.bounce_count_range)
		and _is_count_in_range(shot_count, loadout.shot_count_range)
		and int(kind_counts.get(COTTON_KIND_ID, 0)) <= loadout.maximum_cotton_count
		and int(kind_counts.get(TOY_DRUM_KIND_ID, 0))
			<= loadout.maximum_toy_drum_count
	)


func set_bumper_disabled(bumper: Bumper, disabled: bool) -> bool:
	if bumper == null or bumpers_root == null \
			or not bumpers_root.is_ancestor_of(bumper):
		return false
	var path := bumpers_root.get_path_to(bumper)
	if disabled:
		if path not in disabled_bumper_paths:
			disabled_bumper_paths.append(path)
	else:
		disabled_bumper_paths.erase(path)
	bumper.visible = not disabled
	return true


func restore_disabled_bumpers() -> void:
	if bumpers_root != null:
		for child: Node in bumpers_root.get_children():
			if child is Bumper and _is_bumper_disabled(child):
				(child as Bumper).visible = true
	disabled_bumper_paths.clear()


func sync_expected_bumper_roster() -> void:
	expected_bumper_kind_ids.clear()
	for bumper: Bumper in get_bumpers():
		if bumper.settings != null:
			expected_bumper_kind_ids.append(bumper.settings.bumper_kind_id)


func _is_bumper_disabled(bumper: Node) -> bool:
	if bumper == null or bumpers_root == null:
		return false
	return bumpers_root.get_path_to(bumper) in disabled_bumper_paths


func _apply_disabled_bumpers() -> void:
	if bumpers_root == null:
		return
	for child: Node in bumpers_root.get_children():
		if not (child is Bumper) or not _is_bumper_disabled(child):
			continue
		var bumper := child as Bumper
		bumper.visible = false
		bumper.process_mode = Node.PROCESS_MODE_DISABLED
		bumper.collision_layer = 0
		bumper.collision_mask = 0
		for collision_child: Node in bumper.find_children(
			"*", "CollisionShape2D", true, false
		):
			(collision_child as CollisionShape2D).disabled = true
		for area_child: Node in bumper.find_children("*", "Area2D", true, false):
			var area := area_child as Area2D
			area.monitoring = false
			area.monitorable = false
			area.collision_layer = 0
			area.collision_mask = 0


func _assert_required_nodes() -> void:
	assert(is_instance_valid(launcher), "Wave scene requires PinballLauncher.")
	assert(is_instance_valid(combo_system), "Wave scene requires ComboSystem.")
	assert(is_instance_valid(combo_collision_bridge),
		"Wave scene requires ComboCollisionBridge.")
	assert(is_instance_valid(wave_ball_inventory),
		"Wave scene requires WaveBallInventory.")
	assert(is_instance_valid(wave_ball_flow),
		"Wave scene requires WaveBallFlowController.")
	assert(is_instance_valid(combo_wave_controller),
		"Wave scene requires ComboWaveController.")
	assert(is_instance_valid(wave_manager), "Wave scene requires WaveManager.")
	assert(is_instance_valid(flipper_selector), "Wave scene requires FlipperSelector.")
	assert(is_instance_valid(ball_selection_hud), "Wave scene requires BallSelectionHud.")
	assert(is_instance_valid(ball_drain_area), "Wave scene requires BallDrainArea.")
	assert(is_instance_valid(hud_state), "Wave scene requires WaveHudStateSource.")
	assert(is_instance_valid(wave_hud), "Wave scene requires WaveHud.")
	assert(is_instance_valid(board_camera), "Wave scene requires Camera2D.")
	assert(is_instance_valid(bumpers_root), "Wave scene requires a bumpers root.")


func _bind_wave_runtime() -> void:
	if not ball_drain_area.body_entered.is_connected(
		_on_ball_drain_area_body_entered
	):
		ball_drain_area.body_entered.connect(_on_ball_drain_area_body_entered)
	wave_manager.active_ball_changed.connect(_on_active_ball_changed)
	wave_manager.state_changed.connect(_on_wave_manager_state_changed)
	wave_manager.stage_phase_changed.connect(_on_stage_phase_changed)


func _bind_bumper_runtime() -> void:
	for bumper: Bumper in get_bumpers():
		var source := bumper.combo_hit_source
		if source != null:
			combo_system.bind_hit_source(source)
		if bumper is ShotBumper:
			var shot := bumper as ShotBumper
			shot.control_started.connect(_on_shot_control_started)
			shot.control_ended.connect(_on_shot_control_ended)


func _reset_bumpers_for_new_ball() -> void:
	for bumper: Bumper in get_bumpers():
		bumper.reset_for_new_ball()


func _on_ball_drain_area_body_entered(body: Node2D) -> void:
	if _drain_pending or body != ball or ball.freeze:
		return
	_drain_pending = true
	call_deferred(&"_handle_ball_drained", "custom drain area")


func _handle_ball_drained(_source_name: String) -> void:
	if not is_instance_valid(ball) or not is_instance_valid(wave_ball_flow):
		_drain_pending = false
		return
	var drained_ball := ball
	wave_ball_flow.on_ball_drained(drained_ball)
	_drain_pending = false


func _on_active_ball_changed(next_ball: Pinball) -> void:
	ball = next_ball
	combo_collision_bridge.bind_ball(next_ball)
	_reset_bumpers_for_new_ball()
	if not is_instance_valid(next_ball):
		# ShotBumper may lose its queued-for-deletion ball before it can emit
		# control_ended. The coordinator owns this aggregate count, so close the
		# finished-ball boundary explicitly instead of depending on node lifetime.
		_active_shot_controls = 0
		_set_flipper_input_enabled(false)


func _on_wave_manager_state_changed(
	_previous_state: WaveManager.State,
	current_state: WaveManager.State
) -> void:
	_set_flipper_input_enabled(
		current_state == WaveManager.State.IN_PLAY and _active_shot_controls == 0
	)


func _on_stage_phase_changed(
	_previous_phase: WaveManager.StagePhase,
	_current_phase: WaveManager.StagePhase
) -> void:
	_sync_stage_phase()


func _on_advance_stage_phase_requested() -> void:
	wave_manager.advance_stage_phase()


func _on_shot_control_started(
	_bumper: ShotBumper,
	_controlled_ball: RigidBody2D
) -> void:
	_active_shot_controls += 1
	_set_flipper_input_enabled(false)


func _on_shot_control_ended(
	_bumper: ShotBumper,
	_controlled_ball: RigidBody2D
) -> void:
	_active_shot_controls = maxi(_active_shot_controls - 1, 0)
	_set_flipper_input_enabled(
		wave_manager.current_state == WaveManager.State.IN_PLAY
		and _active_shot_controls == 0
	)


func _set_flipper_input_enabled(is_enabled: bool) -> void:
	if is_instance_valid(flipper_selector):
		flipper_selector.set_input_enabled(is_enabled)


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
	_sync_stage_phase()
	hud_state.end_batch()


func _configure_lives_from_inventory() -> void:
	var ball_types: Array[StringName] = []
	var select_inventory := wave_ball_inventory as SelectBallInventory
	if select_inventory != null and select_inventory.reusable_owned_balls:
		var current_type := &""
		if select_inventory.selected_definition != null:
			current_type = select_inventory.selected_definition.ball_id
		elif not select_inventory.get_owned_definitions().is_empty():
			current_type = select_inventory.get_owned_definitions()[0].ball_id
		if current_type.is_empty():
			return
		for _slot in select_inventory.launches_per_wave:
			ball_types.append(current_type)
		hud_state.configure_lives(ball_types)
		return
	for stock: BallStock in wave_ball_inventory.starting_stock:
		if stock == null or not stock.is_valid():
			continue
		for _copy in stock.count:
			ball_types.append(stock.definition.ball_id)
	assert(ball_types.size() == WaveManager.BALLS_PER_WAVE,
		"Confirmed wave flow requires exactly three inventory balls.")
	if ball_types.size() != WaveManager.BALLS_PER_WAVE:
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
	var select_inventory := wave_ball_inventory as SelectBallInventory
	if select_inventory != null and select_inventory.reusable_owned_balls:
		hud_state.set_current_life_type(definition.ball_id)
		return
	hud_state.select_life(definition.ball_id)


func _on_inventory_ball_consumed(
	_definition: BallDefinition,
	_remaining_for_type: int,
	_total_remaining: int
) -> void:
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
	_reset_bumpers_for_new_ball()
	hud_state.begin_batch()
	hud_state.reset_combo()
	hud_state.set_wave_index(wave_index)
	hud_state.set_score(wave_manager.current_score, target_score)
	hud_state.end_batch()


func _sync_stage_phase() -> void:
	hud_state.set_wave_index(wave_manager.current_wave_index)
	hud_state.set_stage_phase(
		wave_manager.get_stage_phase_title(),
		wave_manager.get_stage_phase_button_text(),
		wave_manager.is_placeholder_phase()
	)


func _on_manager_wave_retried() -> void:
	_reset_bumpers_for_new_ball()
	hud_state.begin_batch()
	hud_state.reset_combo()
	hud_state.set_score(wave_manager.current_score, wave_manager.target_score)
	hud_state.end_batch()


func _on_combo_changed(combo_count: int, _tier: int, _time_remaining: float) -> void:
	if combo_count > 0:
		_update_combo_anchor_from_ball()
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


func _update_combo_anchor_from_ball() -> void:
	if not is_instance_valid(ball):
		hud_state.set_combo_anchor(Vector2.ZERO, false)
		return
	var viewport_position := ball.get_global_transform_with_canvas().origin
	hud_state.set_combo_anchor(viewport_position, true)


func _fit_board_camera(force := false) -> void:
	if not is_instance_valid(board_camera) or not is_instance_valid(wave_hud):
		return
	var viewport_size := get_viewport_rect().size
	if not force and viewport_size.is_equal_approx(_camera_viewport_size):
		return
	_camera_viewport_size = viewport_size

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


func _setup_settings_popup() -> void:
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsOverlay"
	_settings_layer.layer = 100
	_settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_layer)

	_settings_popup = SETTINGS_POPUP_SCENE.instantiate()
	_settings_layer.add_child(_settings_popup)
	_settings_popup.close_requested.connect(_on_settings_closed)
	_settings_popup.game_exit_requested.connect(_on_game_exit_requested)


func _on_settings_requested() -> void:
	if _settings_popup.visible:
		_settings_popup.close_immediately()
		return
	_paused_before_settings = get_tree().paused
	get_tree().paused = true
	hud_state.set_paused(true)
	_settings_popup.open_popup()


func _on_settings_closed() -> void:
	get_tree().paused = _paused_before_settings
	hud_state.set_paused(_paused_before_settings)


func _on_game_exit_requested() -> void:
	if OS.has_feature("web"):
		# 방어 경로: 웹에서는 UI에서 종료 버튼을 숨기지만 외부 호출이 와도
		# 엔진을 정지시키지 않고 시작 화면으로 안전하게 복귀합니다.
		get_tree().paused = false
		get_tree().change_scene_to_file(START_SCREEN_PATH)
		return
	get_tree().quit()


func _is_count_in_range(value: int, range_value: Vector2i) -> bool:
	return value >= range_value.x and value <= range_value.y
