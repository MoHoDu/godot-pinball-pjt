class_name WaveManager
extends Node


signal state_changed(previous_state: State, current_state: State)
signal wave_entered(stage_id: StringName, wave_index: int, target_score: int)
signal active_ball_changed(ball: Pinball)
signal ball_cycle_started(ball: Pinball, remaining_balls: int)
signal ball_cycle_resolved(ball: Pinball, remaining_balls: int, awarded_score: int)
signal clear_choice_requested(current_score: int, target_score: int, remaining_balls: int)
signal wave_won(current_score: int, target_score: int)
signal wave_lost(current_score: int, target_score: int)
signal wave_retried


enum State {
	INACTIVE,
	ENTERING,
	SELECTING_BALL,
	AIMING,
	IN_PLAY,
	RESOLVING_BALL,
	CLEAR_CHOICE,
	WON,
	LOST,
}


@export_node_path("WaveBallFlowController") var ball_flow_path: NodePath
@export_node_path("ComboWaveController") var combo_wave_path: NodePath
@export_node_path("Node") var combo_system_path: NodePath
@export_node_path("ComboCollisionBridge") var collision_bridge_path: NodePath
@export var clear_action: StringName = &"wave_choose_clear"
@export var continue_action: StringName = &"wave_choose_remaining_balls"


var ball_flow: WaveBallFlowController
var combo_wave: ComboWaveController
var combo_system: Node
var collision_bridge: ComboCollisionBridge
var active_ball: Pinball
var _state: State = State.INACTIVE
var _stage_settings: Resource
var _wave_index := 0
var _clear_after_drain := false
var _pending_terminal_state: State = State.INACTIVE
var _terminal_finalize_queued := false


var current_state: State:
	get:
		return _state

var target_score: int:
	get:
		return combo_wave.target_score if combo_wave != null else 0

var current_score: int:
	get:
		return combo_wave.current_score if combo_wave != null else 0

var current_wave_index: int:
	get:
		return _wave_index

var remaining_balls: int:
	get:
		if ball_flow == null or ball_flow.inventory == null:
			return 0
		return ball_flow.inventory.total_remaining


func _ready() -> void:
	if not ball_flow_path.is_empty():
		bind_ball_flow(get_node_or_null(ball_flow_path) as WaveBallFlowController)
	if not combo_wave_path.is_empty():
		bind_combo_wave(get_node_or_null(combo_wave_path) as ComboWaveController)
	if not combo_system_path.is_empty():
		bind_combo_system(get_node_or_null(combo_system_path))
	if not collision_bridge_path.is_empty():
		bind_collision_bridge(
			get_node_or_null(collision_bridge_path) as ComboCollisionBridge
		)


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.CLEAR_CHOICE:
		return
	if event.is_action_pressed(clear_action):
		if choose_clear():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(continue_action):
		if choose_remaining_balls():
			get_viewport().set_input_as_handled()


func bind_ball_flow(next_flow: WaveBallFlowController) -> bool:
	if next_flow == null:
		return false
	if ball_flow == next_flow:
		return true
	_unbind_ball_flow()
	ball_flow = next_flow
	ball_flow.state_changed.connect(_on_ball_flow_state_changed)
	ball_flow.active_ball_changed.connect(_on_flow_active_ball_changed)
	ball_flow.ball_launched.connect(_on_flow_ball_launched)
	ball_flow.ball_drained.connect(_on_flow_ball_drained)
	if combo_wave != null:
		combo_wave.bind_ball_flow(ball_flow, false)
	_set_active_ball(ball_flow.active_ball)
	return true


func bind_combo_wave(next_combo_wave: ComboWaveController) -> bool:
	if next_combo_wave == null:
		return false
	if combo_wave == next_combo_wave:
		return true
	_unbind_combo_wave()
	combo_wave = next_combo_wave
	combo_wave.set_process_unhandled_input(false)
	combo_wave.clear_choice_requested.connect(_on_clear_choice_requested)
	combo_wave.clear_choice_resolved.connect(_on_clear_choice_resolved)
	combo_wave.wave_clear_requested.connect(_on_wave_clear_requested)
	if combo_system != null:
		combo_wave.bind_combo_system(combo_system)
	if ball_flow != null:
		combo_wave.bind_ball_flow(ball_flow, false)
	return true


func bind_combo_system(next_combo_system: Node) -> bool:
	if next_combo_system == null:
		return false
	combo_system = next_combo_system
	var combo_wave_bound := combo_wave == null \
		or combo_wave.bind_combo_system(combo_system)
	var bridge_bound := collision_bridge == null \
		or collision_bridge.bind_combo_system(combo_system)
	return combo_wave_bound and bridge_bound


func bind_collision_bridge(next_bridge: ComboCollisionBridge) -> bool:
	if next_bridge == null:
		return false
	if collision_bridge != null \
			and is_instance_valid(collision_bridge) \
			and collision_bridge != next_bridge:
		collision_bridge.bind_ball(null)
	collision_bridge = next_bridge
	if combo_system != null:
		collision_bridge.bind_combo_system(combo_system)
	collision_bridge.bind_ball(active_ball)
	return true


func enter_wave(
	stage_settings: Resource,
	wave_index := 0,
	reset_inventory := true
) -> bool:
	if stage_settings == null \
			or ball_flow == null \
			or combo_wave == null \
			or combo_system == null \
			or _state not in [State.INACTIVE, State.WON, State.LOST]:
		return false
	if not combo_wave.configure_wave(stage_settings, wave_index):
		return false

	_stage_settings = stage_settings
	_wave_index = maxi(wave_index, 0)
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	_set_state(State.ENTERING)
	if not ball_flow.start_wave(reset_inventory):
		if ball_flow.current_state == WaveBallFlowController.State.EXHAUSTED:
			_finish_lost()
		return false
	wave_entered.emit(
		StringName(stage_settings.get(&"stage_id")),
		_wave_index,
		target_score
	)
	return true


func choose_clear() -> bool:
	if _state != State.CLEAR_CHOICE or combo_wave == null:
		return false
	if ball_flow != null \
			and ball_flow.current_state == WaveBallFlowController.State.IN_PLAY:
		_clear_after_drain = true
		return true
	return combo_wave.choose_clear()


func choose_remaining_balls() -> bool:
	return _state == State.CLEAR_CHOICE \
		and combo_wave != null \
		and combo_wave.choose_remaining_balls()


func retry_wave() -> bool:
	if _state not in [State.WON, State.LOST] \
			or ball_flow == null \
			or combo_wave == null \
			or _stage_settings == null:
		return false
	combo_wave.on_wave_retried(false)
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	_set_state(State.ENTERING)
	var started := false
	if ball_flow.current_state == WaveBallFlowController.State.INACTIVE:
		started = ball_flow.start_wave(true)
	else:
		started = ball_flow.retry_wave()
	if not started:
		if ball_flow.current_state == WaveBallFlowController.State.EXHAUSTED:
			_finish_lost()
		return false
	wave_retried.emit()
	return true


func get_state_name() -> StringName:
	return State.keys()[_state].to_snake_case()


func _exit_tree() -> void:
	if collision_bridge != null and is_instance_valid(collision_bridge):
		collision_bridge.bind_ball(null)
	collision_bridge = null
	_unbind_combo_wave()
	_unbind_ball_flow()
	combo_system = null


func _unbind_ball_flow() -> void:
	if ball_flow == null or not is_instance_valid(ball_flow):
		ball_flow = null
		return
	if combo_wave != null and is_instance_valid(combo_wave):
		combo_wave.unbind_ball_flow()
	if ball_flow.state_changed.is_connected(_on_ball_flow_state_changed):
		ball_flow.state_changed.disconnect(_on_ball_flow_state_changed)
	if ball_flow.active_ball_changed.is_connected(_on_flow_active_ball_changed):
		ball_flow.active_ball_changed.disconnect(_on_flow_active_ball_changed)
	if ball_flow.ball_launched.is_connected(_on_flow_ball_launched):
		ball_flow.ball_launched.disconnect(_on_flow_ball_launched)
	if ball_flow.ball_drained.is_connected(_on_flow_ball_drained):
		ball_flow.ball_drained.disconnect(_on_flow_ball_drained)
	ball_flow = null


func _unbind_combo_wave() -> void:
	if combo_wave == null or not is_instance_valid(combo_wave):
		combo_wave = null
		return
	if combo_wave.clear_choice_requested.is_connected(_on_clear_choice_requested):
		combo_wave.clear_choice_requested.disconnect(_on_clear_choice_requested)
	if combo_wave.clear_choice_resolved.is_connected(_on_clear_choice_resolved):
		combo_wave.clear_choice_resolved.disconnect(_on_clear_choice_resolved)
	if combo_wave.wave_clear_requested.is_connected(_on_wave_clear_requested):
		combo_wave.wave_clear_requested.disconnect(_on_wave_clear_requested)
	combo_wave.unbind_ball_flow()
	combo_wave.unbind_combo_system()
	combo_wave.set_process_unhandled_input(true)
	combo_wave = null


func _on_ball_flow_state_changed(
	_previous_state: WaveBallFlowController.State,
	next_state: WaveBallFlowController.State
) -> void:
	match next_state:
		WaveBallFlowController.State.INACTIVE:
			if _state not in [State.CLEAR_CHOICE, State.WON, State.LOST]:
				_set_state(State.INACTIVE)
		WaveBallFlowController.State.SELECTING:
			if _state == State.CLEAR_CHOICE and _clear_after_drain:
				_clear_after_drain = false
				combo_wave.choose_clear()
			elif _state == State.CLEAR_CHOICE \
					and combo_wave != null \
					and not combo_wave.choice_is_pending:
				_set_state(State.SELECTING_BALL)
			elif _state not in [State.CLEAR_CHOICE, State.WON, State.LOST]:
				_set_state(State.SELECTING_BALL)
		WaveBallFlowController.State.AIMING:
			_set_state(State.AIMING)
		WaveBallFlowController.State.IN_PLAY:
			_set_state(State.IN_PLAY)
		WaveBallFlowController.State.EXHAUSTED:
			if _state in [State.WON, State.LOST]:
				return
			if combo_wave != null and combo_wave.clear_was_requested:
				_queue_terminal_state(State.WON)
			else:
				_queue_terminal_state(State.LOST)


func _on_flow_active_ball_changed(next_ball: Pinball) -> void:
	_set_active_ball(next_ball)


func _on_flow_ball_launched(ball: Pinball, balls_remaining: int) -> void:
	if combo_wave == null or not combo_wave.on_ball_launched():
		return
	_set_state(State.IN_PLAY)
	ball_cycle_started.emit(ball, balls_remaining)


func _on_flow_ball_drained(ball: Pinball, balls_remaining: int) -> void:
	if combo_wave == null:
		return
	_set_state(State.RESOLVING_BALL)
	var score_before := current_score
	combo_wave.on_ball_drained(balls_remaining)
	var awarded_score := current_score - score_before
	ball_cycle_resolved.emit(ball, balls_remaining, awarded_score)


func _on_clear_choice_requested(
	score: int,
	target: int,
	balls_remaining: int
) -> void:
	_set_state(State.CLEAR_CHOICE)
	clear_choice_requested.emit(score, target, balls_remaining)


func _on_clear_choice_resolved(use_remaining_balls: bool) -> void:
	if use_remaining_balls \
			and ball_flow != null \
			and ball_flow.current_state == WaveBallFlowController.State.SELECTING:
		_set_state(State.SELECTING_BALL)


func _on_wave_clear_requested(_score: int, _target: int) -> void:
	_queue_terminal_state(State.WON)


func _set_active_ball(next_ball: Pinball) -> void:
	active_ball = next_ball
	if collision_bridge != null and is_instance_valid(collision_bridge):
		collision_bridge.bind_ball(active_ball)
	active_ball_changed.emit(active_ball)


func _queue_terminal_state(terminal_state: State) -> void:
	if terminal_state not in [State.WON, State.LOST] \
			or _state in [State.WON, State.LOST]:
		return
	if _pending_terminal_state != State.WON:
		_pending_terminal_state = terminal_state
	if _terminal_finalize_queued:
		return
	_terminal_finalize_queued = true
	call_deferred(&"_finalize_pending_terminal_state")


func _finalize_pending_terminal_state() -> void:
	_terminal_finalize_queued = false
	var terminal_state := _pending_terminal_state
	_pending_terminal_state = State.INACTIVE
	if terminal_state == State.WON:
		_finish_won()
	elif terminal_state == State.LOST:
		_finish_lost()


func _finish_won() -> void:
	if _state == State.WON:
		return
	_clear_after_drain = false
	_set_state(State.WON)
	wave_won.emit(current_score, target_score)


func _finish_lost() -> void:
	if _state == State.LOST:
		return
	_clear_after_drain = false
	_set_state(State.LOST)
	wave_lost.emit(current_score, target_score)


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)
