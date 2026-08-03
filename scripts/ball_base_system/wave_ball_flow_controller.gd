class_name WaveBallFlowController
extends Node


signal state_changed(previous_state: State, current_state: State)
signal wave_started(total_balls: int)
signal ball_selection_confirmed(definition: BallDefinition, remaining_balls: int)
signal active_ball_changed(ball: Pinball)
signal ball_launched(ball: Pinball, remaining_balls: int)
signal ball_drained(ball: Pinball, remaining_balls: int)
signal wave_balls_exhausted
signal selection_lock_changed(is_locked: bool)


enum State {
	INACTIVE,
	SELECTING,
	AIMING,
	IN_PLAY,
	EXHAUSTED,
}


@export_node_path("WaveBallInventory") var inventory_path: NodePath
@export_node_path("PinballLauncher") var launcher_path: NodePath
@export var previous_action: StringName = &"ball_select_previous"
@export var next_action: StringName = &"ball_select_next"
@export var confirm_action: StringName = &"ball_select_confirm"
@export var free_drained_ball := true


var inventory: WaveBallInventory
var launcher: PinballLauncher
var active_ball: Pinball
var selection_locked := false
var _state: State = State.INACTIVE
var _selection_confirmation_in_progress := false


var current_state: State:
	get:
		return _state


func _ready() -> void:
	if not inventory_path.is_empty():
		bind_inventory(get_node_or_null(inventory_path) as WaveBallInventory)
	if not launcher_path.is_empty():
		bind_launcher(get_node_or_null(launcher_path) as PinballLauncher)


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.SELECTING or selection_locked:
		return
	if event.is_action_pressed(previous_action):
		if inventory != null and inventory.select_previous():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(next_action):
		if inventory != null and inventory.select_next():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(confirm_action):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if confirm_selection():
			get_viewport().set_input_as_handled()


func bind_inventory(next_inventory: WaveBallInventory) -> bool:
	if next_inventory == null:
		return false
	inventory = next_inventory
	return true


func bind_launcher(next_launcher: PinballLauncher) -> bool:
	if next_launcher == null:
		return false
	if launcher != null and launcher.ball_launched.is_connected(_on_ball_launched):
		launcher.ball_launched.disconnect(_on_ball_launched)
	launcher = next_launcher
	if not launcher.ball_launched.is_connected(_on_ball_launched):
		launcher.ball_launched.connect(_on_ball_launched)
	return true


func start_wave(reset_inventory := true) -> bool:
	if inventory == null \
			or launcher == null \
			or _state not in [State.INACTIVE, State.EXHAUSTED]:
		return false
	if reset_inventory:
		inventory.reset_stock()
	if inventory.total_remaining <= 0:
		_set_state(State.EXHAUSTED)
		wave_balls_exhausted.emit()
		return false

	active_ball = null
	set_selection_locked(false)
	_set_state(State.SELECTING)
	if not inventory.begin_selection():
		_set_state(State.EXHAUSTED)
		wave_balls_exhausted.emit()
		return false
	wave_started.emit(inventory.total_remaining)
	return true


func end_wave() -> bool:
	if _state not in [State.SELECTING, State.EXHAUSTED]:
		return false
	active_ball = null
	set_selection_locked(false)
	_set_state(State.INACTIVE)
	return true


func retry_wave() -> bool:
	if _state not in [State.SELECTING, State.EXHAUSTED]:
		return false
	if not end_wave():
		return false
	return start_wave(true)


func confirm_selection() -> bool:
	if _state != State.SELECTING \
			or inventory == null \
			or launcher == null \
			or selection_locked \
			or _selection_confirmation_in_progress:
		return false
	var definition := inventory.selected_definition
	if definition == null or not definition.is_valid():
		return false

	launcher.ball_scene = definition.ball_scene
	_selection_confirmation_in_progress = true
	var prepared_ball := launcher.prepare_ball()
	_selection_confirmation_in_progress = false
	if prepared_ball == null:
		return false
	if inventory.selected_definition != definition:
		launcher.cancel_prepared_ball(true)
		return false

	var consumed_definition := inventory.consume_selected_ball()
	if consumed_definition != definition:
		launcher.cancel_prepared_ball(true)
		return false

	active_ball = prepared_ball
	_set_state(State.AIMING)
	ball_selection_confirmed.emit(definition, inventory.total_remaining)
	active_ball_changed.emit(active_ball)
	return true


func set_selection_locked(is_locked: bool) -> void:
	if selection_locked == is_locked:
		return
	selection_locked = is_locked
	selection_lock_changed.emit(selection_locked)


func on_ball_drained(drained_ball: Pinball = active_ball) -> bool:
	if _state != State.IN_PLAY \
			or not is_instance_valid(active_ball) \
			or drained_ball != active_ball:
		return false

	var finished_ball := active_ball
	active_ball = null
	if free_drained_ball and is_instance_valid(finished_ball):
		finished_ball.queue_free()
	ball_drained.emit(finished_ball, inventory.total_remaining)
	active_ball_changed.emit(null)

	if inventory.total_remaining <= 0:
		_set_state(State.EXHAUSTED)
		wave_balls_exhausted.emit()
		return true

	_set_state(State.SELECTING)
	if not inventory.begin_selection():
		_set_state(State.EXHAUSTED)
		wave_balls_exhausted.emit()
	return true


func get_state_name() -> StringName:
	return State.keys()[_state].to_snake_case()


func _on_ball_launched(
	launched_ball: Pinball,
	_direction: Vector2,
	_speed: float
) -> void:
	if _state != State.AIMING or launched_ball != active_ball:
		return
	_set_state(State.IN_PLAY)
	ball_launched.emit(launched_ball, inventory.total_remaining)


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)
