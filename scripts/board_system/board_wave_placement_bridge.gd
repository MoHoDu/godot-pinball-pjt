class_name BoardWavePlacementBridge
extends Node


signal placement_requested(wave_id: StringName)
signal placement_ready(wave_id: StringName, consumed_counts: Dictionary)
signal placement_blocked(result: BoardValidationResult)


@export var wave_manager: WaveManager
@export var placement_session: BoardPlacementSession
@export var combo_system: Node
@export var wave_hud: CanvasItem
@export var ball_selection_hud: CanvasItem
@export var placement_hud: RepairPartPlacementHud
@export var commit_action: StringName = &"ui_accept"


var _placement_committed_for_wave := false


func _ready() -> void:
	_assert_dependencies()
	if wave_manager == null or placement_session == null:
		return
	wave_manager.stage_phase_changed.connect(_on_stage_phase_changed)
	wave_manager.wave_retried.connect(_on_wave_retried)
	wave_manager.ball_cycle_started.connect(_on_ball_cycle_started)
	wave_manager.active_ball_changed.connect(_on_active_ball_changed)
	placement_session.placement_committed.connect(_on_placement_committed)
	placement_session.placement_rejected.connect(_on_placement_rejected)
	_sync_stage_phase(wave_manager.current_stage_phase)


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
	return placement_session != null \
		and placement_session.current_state == BoardPlacementSession.State.EDITING \
		and placement_session.commit()


func _on_stage_phase_changed(
	_previous_phase: WaveManager.StagePhase,
	current_phase: WaveManager.StagePhase
) -> void:
	_sync_stage_phase(current_phase)


func _sync_stage_phase(current_phase: WaveManager.StagePhase) -> void:
	var is_placement := current_phase == WaveManager.StagePhase.REPAIR_PLACEMENT
	_set_hud_visibility(is_placement)
	if is_placement:
		_begin_placement(_make_wave_id())
	elif placement_session.current_state == BoardPlacementSession.State.EDITING:
		placement_session.end_wave()


func _on_wave_retried() -> void:
	if wave_manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT:
		_begin_placement(_make_wave_id())


func _begin_placement(wave_id: StringName) -> void:
	_placement_committed_for_wave = false
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
	placement_ready.emit(wave_id, consumed_counts)
	if not wave_manager.advance_stage_phase():
		push_error("WaveManager rejected the committed repair placement phase.")


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


func _set_hud_visibility(is_placement: bool) -> void:
	if wave_hud != null:
		wave_hud.visible = not is_placement
	if is_placement and ball_selection_hud != null:
		ball_selection_hud.visible = false
	if placement_hud != null:
		placement_hud.set_placement_visible(is_placement)


func _make_wave_id() -> StringName:
	return &"wave_%d" % wave_manager.current_wave_index


func _assert_dependencies() -> void:
	assert(wave_manager != null, "Board bridge requires WaveManager.")
	assert(placement_session != null,
		"Board bridge requires BoardPlacementSession.")
	assert(placement_hud != null,
		"Board bridge requires RepairPartPlacementHud.")
