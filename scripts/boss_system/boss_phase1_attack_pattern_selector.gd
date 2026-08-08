class_name BossPhase1AttackPatternSelector
extends Node

signal pattern_applied(pattern: BossAttackPattern, is_first_attack: bool)
signal pattern_application_failed(is_first_attack: bool)
signal binding_lost

var _scheduler: BossPhase1AttackScheduler = null
var _controller: BossAttackController = null
var _first_pattern: BossAttackPattern = null
var _repeat_pattern: BossAttackPattern = null
var _has_binding: bool = false
var _binding_loss_reported: bool = false


func _process(_delta: float) -> void:
	if _has_binding and not is_bound():
		_handle_binding_lost()


func bind(
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController,
	first_pattern: BossAttackPattern,
	repeat_pattern: BossAttackPattern
) -> bool:
	if scheduler == null \
			or controller == null \
			or first_pattern == null \
			or repeat_pattern == null:
		return false
	if not is_instance_valid(scheduler) \
			or not is_instance_valid(controller) \
			or not is_instance_valid(first_pattern) \
			or not is_instance_valid(repeat_pattern):
		return false
	if not first_pattern.is_valid() or not repeat_pattern.is_valid():
		return false

	var is_same_binding: bool = _has_binding \
		and scheduler == _scheduler \
		and controller == _controller \
		and first_pattern == _first_pattern \
		and repeat_pattern == _repeat_pattern
	if is_same_binding:
		_connect_scheduler_signal()
		return true

	if scheduler.get_current_state() != BossPhase1AttackScheduler.State.STOPPED:
		return false
	if controller.current_state != BossAttackController.State.IDLE:
		return false
	if _has_binding:
		if not is_bound():
			return false
		if _scheduler.get_current_state() != BossPhase1AttackScheduler.State.STOPPED:
			return false
		if _controller.current_state != BossAttackController.State.IDLE:
			return false

	_disconnect_scheduler_signal()
	_scheduler = scheduler
	_controller = controller
	_first_pattern = first_pattern
	_repeat_pattern = repeat_pattern
	_has_binding = true
	_binding_loss_reported = false
	_connect_scheduler_signal()
	return true


func unbind() -> void:
	_disconnect_scheduler_signal()
	_clear_binding()
	_binding_loss_reported = false


func is_bound() -> bool:
	return _has_binding \
		and _scheduler != null \
		and is_instance_valid(_scheduler) \
		and _controller != null \
		and is_instance_valid(_controller) \
		and _first_pattern != null \
		and is_instance_valid(_first_pattern) \
		and _repeat_pattern != null \
		and is_instance_valid(_repeat_pattern)


func get_current_pattern() -> BossAttackPattern:
	if not is_bound():
		return null
	return _controller.pattern


func _on_scheduler_state_changed(
	previous_state: BossPhase1AttackScheduler.State,
	current_state: BossPhase1AttackScheduler.State
) -> void:
	var selected_pattern: BossAttackPattern = null
	var is_first_attack: bool = false
	if previous_state == BossPhase1AttackScheduler.State.WAITING_FIRST_ATTACK \
			and current_state == BossPhase1AttackScheduler.State.WAITING_FOR_ATTACK_FINISH:
		selected_pattern = _first_pattern
		is_first_attack = true
	elif previous_state == BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK \
			and current_state == BossPhase1AttackScheduler.State.WAITING_FOR_ATTACK_FINISH:
		selected_pattern = _repeat_pattern
	else:
		return

	if not is_bound():
		_handle_binding_lost()
		return
	if not is_instance_valid(selected_pattern) \
			or not selected_pattern.is_valid() \
			or _controller.current_state != BossAttackController.State.IDLE:
		pattern_application_failed.emit(is_first_attack)
		return

	_controller.pattern = selected_pattern
	if _controller.pattern != selected_pattern:
		pattern_application_failed.emit(is_first_attack)
		return
	pattern_applied.emit(selected_pattern, is_first_attack)


func _handle_binding_lost() -> void:
	if not _has_binding or _binding_loss_reported:
		return

	_has_binding = false
	_binding_loss_reported = true
	_disconnect_scheduler_signal()
	_scheduler = null
	_controller = null
	_first_pattern = null
	_repeat_pattern = null
	binding_lost.emit()


func _connect_scheduler_signal() -> void:
	if is_instance_valid(_scheduler) \
			and not _scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		_scheduler.state_changed.connect(_on_scheduler_state_changed)


func _disconnect_scheduler_signal() -> void:
	if is_instance_valid(_scheduler) \
			and _scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		_scheduler.state_changed.disconnect(_on_scheduler_state_changed)


func _clear_binding() -> void:
	_scheduler = null
	_controller = null
	_first_pattern = null
	_repeat_pattern = null
	_has_binding = false
