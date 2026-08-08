class_name BossAttackController
extends Node


signal state_changed(previous_state: State, current_state: State)
signal attack_started(attack_id: StringName)
signal telegraph_started
signal active_started
signal recovery_started
signal cooldown_started
signal attack_finished
signal attack_cancelled


enum State {
	IDLE,
	TELEGRAPH,
	ACTIVE,
	RECOVERY,
	COOLDOWN,
}


@export var pattern: BossAttackPattern
@export var attack: TeddyArmSweepAttack


var _state: State = State.IDLE
var _run_generation := 0


var current_state: State:
	get:
		return _state


func start_attack() -> bool:
	if _state != State.IDLE \
			or pattern == null \
			or not pattern.is_valid() \
			or not is_instance_valid(attack):
		return false

	_run_generation += 1
	var generation := _run_generation
	attack.prepare_attack()
	_set_state(State.TELEGRAPH)
	if not _is_run_valid(generation, State.TELEGRAPH):
		return true
	attack_started.emit(pattern.attack_id)
	if not _is_run_valid(generation, State.TELEGRAPH):
		return true
	telegraph_started.emit()
	if not _is_run_valid(generation, State.TELEGRAPH):
		return true
	attack.begin_telegraph(pattern.telegraph_duration)
	if not _is_run_valid(generation, State.TELEGRAPH):
		return true
	_run_attack_sequence(generation)
	return true


func cancel_attack() -> bool:
	if _state == State.IDLE:
		return false

	_run_generation += 1
	if is_instance_valid(attack):
		attack.cancel_attack()
	_set_state(State.IDLE)
	attack_cancelled.emit()
	return true


func get_state_name() -> StringName:
	return State.keys()[_state].to_snake_case()


func _run_attack_sequence(generation: int) -> void:
	await get_tree().create_timer(pattern.telegraph_duration).timeout
	if not _is_run_valid(generation, State.TELEGRAPH):
		return
	if not _enter_running_state(generation, State.ACTIVE):
		return

	await get_tree().create_timer(pattern.active_duration).timeout
	if not _is_run_valid(generation, State.ACTIVE):
		return
	if not _enter_running_state(generation, State.RECOVERY):
		return

	await get_tree().create_timer(pattern.recovery_duration).timeout
	if not _is_run_valid(generation, State.RECOVERY):
		return
	if not _enter_running_state(generation, State.COOLDOWN):
		return

	await get_tree().create_timer(pattern.cooldown_duration).timeout
	if not _is_run_valid(generation, State.COOLDOWN):
		return
	attack.finish_attack()
	if not _is_run_valid(generation, State.COOLDOWN):
		return
	_set_state(State.IDLE)
	if not _is_run_valid(generation, State.IDLE):
		return
	attack_finished.emit()


func _enter_running_state(generation: int, next_state: State) -> bool:
	_set_state(next_state)
	if not _is_run_valid(generation, next_state):
		return false
	match next_state:
		State.ACTIVE:
			active_started.emit()
			if not _is_run_valid(generation, next_state):
				return false
			attack.begin_active(pattern.active_duration)
		State.RECOVERY:
			recovery_started.emit()
			if not _is_run_valid(generation, next_state):
				return false
			attack.begin_recovery(pattern.recovery_duration)
		State.COOLDOWN:
			cooldown_started.emit()
			if not _is_run_valid(generation, next_state):
				return false
			attack.begin_cooldown()
	return _is_run_valid(generation, next_state)


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)


func _is_run_valid(generation: int, expected_state: State) -> bool:
	return generation == _run_generation \
		and _state == expected_state \
		and is_instance_valid(self) \
		and is_inside_tree() \
		and is_instance_valid(attack)


func _exit_tree() -> void:
	_run_generation += 1
	if is_instance_valid(attack):
		attack.cancel_attack()
