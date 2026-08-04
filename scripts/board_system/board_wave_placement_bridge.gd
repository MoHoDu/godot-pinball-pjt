class_name BoardWavePlacementBridge
extends Node


signal placement_requested(wave_id: StringName)
signal placement_ready(wave_id: StringName, consumed_counts: Dictionary)
signal placement_blocked(result: BoardValidationResult)


@export_node_path("WaveManager") var wave_manager_path: NodePath
@export_node_path("BoardPlacementSession") var placement_session_path: NodePath
@export_node_path("Node") var combo_system_path: NodePath
@export var commit_action: StringName = &"ui_accept"


var wave_manager: WaveManager
var placement_session: BoardPlacementSession
var combo_system: Node
var _placement_committed_for_wave := false


func _ready() -> void:
	wave_manager = get_node_or_null(wave_manager_path) as WaveManager
	placement_session = get_node_or_null(
		placement_session_path
	) as BoardPlacementSession
	combo_system = get_node_or_null(combo_system_path)
	assert(wave_manager != null, "Board bridge requires WaveManager.")
	assert(placement_session != null, "Board bridge requires BoardPlacementSession.")
	if wave_manager == null or placement_session == null:
		return
	wave_manager.wave_entered.connect(_on_wave_entered)
	wave_manager.wave_retried.connect(_on_wave_retried)
	wave_manager.state_changed.connect(_on_wave_state_changed)
	wave_manager.ball_cycle_started.connect(_on_ball_cycle_started)
	wave_manager.active_ball_changed.connect(_on_active_ball_changed)
	placement_session.placement_committed.connect(_on_placement_committed)
	placement_session.placement_rejected.connect(_on_placement_rejected)
	_sync_existing_wave_state()


func _unhandled_input(event: InputEvent) -> void:
	if placement_session == null \
			or placement_session.current_state != BoardPlacementSession.State.EDITING:
		return
	if event.is_action_pressed(commit_action):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if commit_placement():
			get_viewport().set_input_as_handled()


func commit_placement() -> bool:
	return placement_session != null and placement_session.commit()


func _sync_existing_wave_state() -> void:
	if wave_manager.current_state == WaveManager.State.SELECTING_BALL:
		_begin_placement(_make_wave_id())


func _on_wave_entered(
	stage_id: StringName,
	wave_index: int,
	_target_score: int
) -> void:
	_begin_placement(&"%s_wave_%d" % [stage_id, wave_index])


func _on_wave_retried() -> void:
	_begin_placement(_make_wave_id())


func _begin_placement(wave_id: StringName) -> void:
	_placement_committed_for_wave = false
	if wave_manager.ball_flow != null:
		wave_manager.ball_flow.set_selection_locked(true)
	if placement_session.current_state != BoardPlacementSession.State.IDLE:
		placement_session.end_wave()
	if placement_session.begin_placement(wave_id):
		placement_requested.emit(wave_id)


func _on_placement_committed(
	wave_id: StringName,
	_placements: Array[Dictionary],
	consumed_counts: Dictionary
) -> void:
	_placement_committed_for_wave = true
	_bind_committed_bumpers()
	if wave_manager.ball_flow != null:
		wave_manager.ball_flow.set_selection_locked(false)
	placement_ready.emit(wave_id, consumed_counts)


func _on_placement_rejected(result: BoardValidationResult) -> void:
	placement_blocked.emit(result)


func _on_ball_cycle_started(
	_ball: Pinball,
	_remaining_balls: int
) -> void:
	assert(
		_placement_committed_for_wave,
		"The first ball cannot launch before board placement is committed."
	)
	if placement_session.current_state == BoardPlacementSession.State.COMMITTED:
		placement_session.lock()


func _on_active_ball_changed(next_ball: Pinball) -> void:
	if next_ball == null or placement_session.layout == null:
		return
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var bumper := placeable.get_bumper()
		if bumper != null:
			bumper.reset_for_new_ball()


func _on_wave_state_changed(
	_previous_state: WaveManager.State,
	current_state: WaveManager.State
) -> void:
	if current_state in [WaveManager.State.WON, WaveManager.State.LOST]:
		placement_session.end_wave()
		_placement_committed_for_wave = false


func _bind_committed_bumpers() -> void:
	if combo_system == null or placement_session.layout == null:
		return
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var bumper := placeable.get_bumper()
		if bumper == null or not bumper.is_repair_part():
			continue
		if bumper.combo_hit_source != null \
				and combo_system.has_method(&"bind_hit_source"):
			combo_system.call(&"bind_hit_source", bumper.combo_hit_source)


func _make_wave_id() -> StringName:
	return &"wave_%d" % wave_manager.current_wave_index
