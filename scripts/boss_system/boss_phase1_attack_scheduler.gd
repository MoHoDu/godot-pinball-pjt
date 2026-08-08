class_name BossPhase1AttackScheduler
extends Node

signal attack_requested
signal state_changed(previous_state: State, current_state: State)
signal pause_changed(is_paused: bool)
signal grace_started(duration_sec: float)
signal grace_finished

enum State {
	STOPPED,
	WAITING_FIRST_ATTACK,
	WAITING_REPEAT_ATTACK,
	WAITING_FOR_ATTACK_FINISH,
}

var _state: State = State.STOPPED
var _is_configured: bool = false
var _is_paused: bool = false
var _grace_active: bool = false
var _wait_time_remaining: float = 0.0
var _grace_time_remaining: float = 0.0
var _last_selected_repeat_delay: float = 0.0

var _first_attack_delay_sec: float = 0.0
var _new_ball_grace_sec: float = 0.0
var _repeat_delay_min_sec: float = 0.0
var _repeat_delay_max_sec: float = 0.0

var _random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _has_explicit_random_seed: bool = false
var _explicit_random_seed: int = 0


func _init() -> void:
	_random_number_generator.randomize()


func _process(delta: float) -> void:
	advance_time(delta)


func configure(
	first_attack_delay_sec: float,
	new_ball_grace_sec: float,
	repeat_delay_min_sec: float,
	repeat_delay_max_sec: float
) -> bool:
	if is_running():
		return false
	if not _is_valid_non_negative_time(first_attack_delay_sec):
		return false
	if not _is_valid_non_negative_time(new_ball_grace_sec):
		return false
	if not _is_valid_non_negative_time(repeat_delay_min_sec):
		return false
	if not _is_valid_non_negative_time(repeat_delay_max_sec):
		return false
	if repeat_delay_min_sec > repeat_delay_max_sec:
		return false

	_first_attack_delay_sec = first_attack_delay_sec
	_new_ball_grace_sec = new_ball_grace_sec
	_repeat_delay_min_sec = repeat_delay_min_sec
	_repeat_delay_max_sec = repeat_delay_max_sec
	_is_configured = true
	return true


func set_random_seed(rng_seed: int) -> void:
	_explicit_random_seed = rng_seed
	_has_explicit_random_seed = true
	_random_number_generator.seed = rng_seed


func start() -> bool:
	if not _is_configured or _state != State.STOPPED:
		return false

	_is_paused = false
	_grace_active = false
	_grace_time_remaining = 0.0
	_wait_time_remaining = _first_attack_delay_sec
	_set_state(State.WAITING_FIRST_ATTACK)
	return true


func pause() -> bool:
	if not is_running() or _is_paused:
		return false

	_is_paused = true
	pause_changed.emit(true)
	return true


func resume() -> bool:
	if not is_running() or not _is_paused:
		return false

	_is_paused = false
	pause_changed.emit(false)
	return true


func stop() -> bool:
	if _state == State.STOPPED:
		return false

	_clear_active_runtime()
	_set_state(State.STOPPED)
	return true


func reset() -> void:
	_clear_active_runtime()
	_last_selected_repeat_delay = 0.0
	if _has_explicit_random_seed:
		_random_number_generator.seed = _explicit_random_seed
	else:
		_random_number_generator.randomize()
	_set_state(State.STOPPED)


func notify_attack_finished() -> bool:
	return _begin_repeat_wait()


func notify_attack_aborted() -> bool:
	return _begin_repeat_wait()


func begin_new_ball_grace() -> bool:
	if not is_running():
		return false

	_grace_active = true
	_grace_time_remaining = _new_ball_grace_sec
	grace_started.emit(_new_ball_grace_sec)
	return true


func advance_time(delta: float) -> void:
	if not _is_valid_non_negative_time(delta):
		return
	if not is_running() or _is_paused:
		return

	if _state == State.WAITING_FIRST_ATTACK or _state == State.WAITING_REPEAT_ATTACK:
		_wait_time_remaining = maxf(_wait_time_remaining - delta, 0.0)

	if _grace_active:
		_grace_time_remaining = maxf(_grace_time_remaining - delta, 0.0)
		if _grace_time_remaining <= 0.0:
			_grace_active = false
			_grace_time_remaining = 0.0
			grace_finished.emit()

	_try_request_attack()


func is_configured() -> bool:
	return _is_configured


func is_running() -> bool:
	return _state != State.STOPPED


func is_paused() -> bool:
	return _is_paused


func is_grace_active() -> bool:
	return _grace_active


func get_current_state() -> State:
	return _state


func get_wait_time_remaining() -> float:
	return _wait_time_remaining


func get_grace_time_remaining() -> float:
	return _grace_time_remaining


func get_effective_time_remaining() -> float:
	if _state != State.WAITING_FIRST_ATTACK and _state != State.WAITING_REPEAT_ATTACK:
		return 0.0
	if _grace_active:
		return maxf(_wait_time_remaining, _grace_time_remaining)
	return _wait_time_remaining


func get_last_selected_repeat_delay() -> float:
	return _last_selected_repeat_delay


func _begin_repeat_wait() -> bool:
	if _state != State.WAITING_FOR_ATTACK_FINISH:
		return false

	_last_selected_repeat_delay = _random_number_generator.randf_range(
		_repeat_delay_min_sec,
		_repeat_delay_max_sec
	)
	_wait_time_remaining = _last_selected_repeat_delay
	_set_state(State.WAITING_REPEAT_ATTACK)
	return true


func _try_request_attack() -> void:
	if not is_running() or _is_paused or _grace_active:
		return
	if _state != State.WAITING_FIRST_ATTACK and _state != State.WAITING_REPEAT_ATTACK:
		return
	if _wait_time_remaining > 0.0:
		return

	_wait_time_remaining = 0.0
	_set_state(State.WAITING_FOR_ATTACK_FINISH)
	attack_requested.emit()


func _clear_active_runtime() -> void:
	if _is_paused:
		_is_paused = false
		pause_changed.emit(false)
	_wait_time_remaining = 0.0
	_grace_active = false
	_grace_time_remaining = 0.0


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return

	var previous_state: State = _state
	_state = new_state
	state_changed.emit(previous_state, _state)


func _is_valid_non_negative_time(value: float) -> bool:
	return is_finite(value) and value >= 0.0
