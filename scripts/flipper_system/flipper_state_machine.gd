class_name FlipperStateMachine
extends RefCounted


const FlipperStateClass := preload("res://scripts/flipper_system/flipper_state.gd")


signal state_changed(previous_state: int, current_state: int)


var flipper: AnimatableBody2D
var current_state: Variant
var _states: Dictionary = {}
var _target_rotation: float = 0.0


func _init(p_flipper: AnimatableBody2D) -> void:
	flipper = p_flipper

	for state_type: int in FlipperStateClass.Type.values():
		_states[state_type] = FlipperStateClass.new(state_type)

	current_state = _states[FlipperStateClass.Type.IDLE]
	current_state.enter()
	_apply_state_rotation()


func get_current_state_type() -> int:
	return current_state.type


func request_activation() -> bool:
	if current_state.type != FlipperStateClass.Type.IDLE:
		return false

	_transition_to(FlipperStateClass.Type.ACTIVE)
	return true


func physics_update(delta: float, rules: Resource) -> float:
	if rules == null:
		return _target_rotation

	match current_state.type:
		FlipperStateClass.Type.IDLE:
			_set_target_rotation(_get_initial_rotation())

		FlipperStateClass.Type.ACTIVE:
			_update_active(delta, float(rules.get(&"activation_time")))

		FlipperStateClass.Type.HOLD:
			_update_hold(delta, float(rules.get(&"hold_time")))

		FlipperStateClass.Type.RETURNING:
			_update_returning(delta, float(rules.get(&"return_time")))

		FlipperStateClass.Type.COOLDOWN:
			_update_cooldown(delta)

	return _target_rotation


func get_target_rotation() -> float:
	return _target_rotation


func get_current_state_elapsed_time() -> float:
	if current_state == null:
		return 0.0
	return float(current_state.elapsed_time)


func _update_active(delta: float, duration: float) -> void:
	current_state.advance(delta)
	var progress := _get_progress(current_state.elapsed_time, duration)
	var eased_progress := 1.0 - pow(1.0 - progress, 4.0)
	_set_target_rotation(lerp_angle(
		_get_initial_rotation(),
		_get_maximum_rotation(),
		eased_progress
	))

	if progress >= 1.0:
		_transition_to(FlipperStateClass.Type.HOLD)


func _update_hold(delta: float, duration: float) -> void:
	_set_target_rotation(_get_maximum_rotation())
	current_state.advance(delta)

	if _get_progress(current_state.elapsed_time, duration) >= 1.0:
		_transition_to(FlipperStateClass.Type.RETURNING)


func _update_returning(delta: float, duration: float) -> void:
	current_state.advance(delta)
	var progress := _get_progress(current_state.elapsed_time, duration)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	_set_target_rotation(lerp_angle(
		_get_maximum_rotation(),
		_get_initial_rotation(),
		eased_progress
	))

	if progress >= 1.0:
		_transition_to(FlipperStateClass.Type.COOLDOWN)


func _update_cooldown(delta: float) -> void:
	_set_target_rotation(_get_initial_rotation())
	current_state.advance(delta)
	var cooldown_time := float(flipper.get(&"cooldown_time"))

	if _get_progress(current_state.elapsed_time, cooldown_time) >= 1.0:
		_transition_to(FlipperStateClass.Type.IDLE)


func _transition_to(next_state_type: int) -> void:
	var previous_state_type: int = int(current_state.type)
	current_state = _states[next_state_type]
	current_state.enter()
	_apply_state_rotation()
	state_changed.emit(previous_state_type, next_state_type)


func _apply_state_rotation() -> void:
	match current_state.type:
		FlipperStateClass.Type.IDLE, FlipperStateClass.Type.COOLDOWN:
			_set_target_rotation(_get_initial_rotation())
		FlipperStateClass.Type.HOLD, FlipperStateClass.Type.RETURNING:
			_set_target_rotation(_get_maximum_rotation())


func _set_target_rotation(value: float) -> void:
	_target_rotation = value
	flipper.rotation = value


func _get_initial_rotation() -> float:
	return deg_to_rad(float(flipper.get(&"initial_angle_degrees")))


func _get_maximum_rotation() -> float:
	return deg_to_rad(float(flipper.get(&"maximum_angle_degrees")))


func _get_progress(elapsed_time: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0

	return clampf(elapsed_time / duration, 0.0, 1.0)
