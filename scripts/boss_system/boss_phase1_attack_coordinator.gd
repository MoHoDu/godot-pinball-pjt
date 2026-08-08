class_name BossPhase1AttackCoordinator
extends Node

signal attack_dispatch_succeeded
signal attack_dispatch_failed
signal binding_lost

var _scheduler: BossPhase1AttackScheduler = null
var _controller: BossAttackController = null
var _is_running: bool = false
var _attack_in_flight: bool = false
var _owned_controller_attack: bool = false
var _binding_loss_reported: bool = false


func _process(_delta: float) -> void:
	if _is_running and not is_bound():
		_handle_binding_lost()


func bind(
	scheduler: BossPhase1AttackScheduler,
	controller: BossAttackController
) -> bool:
	if scheduler == null or controller == null:
		return false
	if not is_instance_valid(scheduler) or not is_instance_valid(controller):
		return false

	var is_same_binding: bool = scheduler == _scheduler and controller == _controller
	if _owned_controller_attack and not is_same_binding:
		return false
	if _is_running and not is_same_binding:
		return false
	if is_same_binding:
		_connect_bound_signals()
		return true

	_disconnect_bound_signals()
	_scheduler = scheduler
	_controller = controller
	_binding_loss_reported = false
	_connect_bound_signals()
	return true


func unbind(cancel_active_attack: bool = true) -> void:
	if _is_running:
		stop(cancel_active_attack)
	elif _owned_controller_attack:
		var should_cancel: bool = cancel_active_attack and is_instance_valid(_controller)
		_owned_controller_attack = false
		_attack_in_flight = false
		if should_cancel:
			_controller.cancel_attack()

	_disconnect_bound_signals()
	_scheduler = null
	_controller = null
	_is_running = false
	_attack_in_flight = false
	_owned_controller_attack = false
	_binding_loss_reported = false


func start() -> bool:
	if _is_running or not is_bound() or _owned_controller_attack:
		return false

	_is_running = true
	if not _scheduler.start():
		_is_running = false
		return false
	return true


func stop(cancel_active_attack: bool = true) -> bool:
	if not _is_running:
		return false

	_is_running = false
	var had_owned_attack: bool = _owned_controller_attack
	_attack_in_flight = false

	if cancel_active_attack and had_owned_attack:
		_owned_controller_attack = false
		if is_instance_valid(_controller):
			_controller.cancel_attack()

	if is_instance_valid(_scheduler):
		_scheduler.stop()
	return true


func is_bound() -> bool:
	return _scheduler != null \
		and is_instance_valid(_scheduler) \
		and _controller != null \
		and is_instance_valid(_controller)


func is_running() -> bool:
	return _is_running


func is_attack_in_flight() -> bool:
	return _attack_in_flight


func _on_attack_requested() -> void:
	if not _is_running:
		return
	if not is_bound():
		_handle_binding_lost()
		return
	if _attack_in_flight:
		return

	_attack_in_flight = true
	_owned_controller_attack = true
	var did_start: bool = _controller.start_attack()

	if did_start:
		if _attack_in_flight:
			attack_dispatch_succeeded.emit()
		return

	if _attack_in_flight:
		_attack_in_flight = false
		_owned_controller_attack = false
		if is_instance_valid(_scheduler):
			_scheduler.notify_attack_aborted()
		attack_dispatch_failed.emit()


func _on_attack_finished() -> void:
	var should_forward: bool = _is_running \
		and _attack_in_flight \
		and is_instance_valid(_scheduler)
	if _owned_controller_attack:
		_owned_controller_attack = false
	if not should_forward:
		return

	_attack_in_flight = false
	_scheduler.notify_attack_finished()


func _on_attack_cancelled() -> void:
	var should_forward: bool = _is_running \
		and _attack_in_flight \
		and is_instance_valid(_scheduler)
	if _owned_controller_attack:
		_owned_controller_attack = false
	if not should_forward:
		return

	_attack_in_flight = false
	_scheduler.notify_attack_aborted()


func _handle_binding_lost() -> void:
	if _binding_loss_reported:
		return

	_binding_loss_reported = true
	var should_cancel: bool = _owned_controller_attack and is_instance_valid(_controller)
	_is_running = false
	_attack_in_flight = false
	_owned_controller_attack = false

	if should_cancel:
		_controller.cancel_attack()
	if is_instance_valid(_scheduler):
		_scheduler.stop()

	_disconnect_bound_signals()
	_scheduler = null
	_controller = null
	binding_lost.emit()


func _connect_bound_signals() -> void:
	if is_instance_valid(_scheduler) \
		and not _scheduler.attack_requested.is_connected(_on_attack_requested):
		_scheduler.attack_requested.connect(_on_attack_requested)
	if is_instance_valid(_controller):
		if not _controller.attack_finished.is_connected(_on_attack_finished):
			_controller.attack_finished.connect(_on_attack_finished)
		if not _controller.attack_cancelled.is_connected(_on_attack_cancelled):
			_controller.attack_cancelled.connect(_on_attack_cancelled)


func _disconnect_bound_signals() -> void:
	if is_instance_valid(_scheduler) \
		and _scheduler.attack_requested.is_connected(_on_attack_requested):
		_scheduler.attack_requested.disconnect(_on_attack_requested)
	if is_instance_valid(_controller):
		if _controller.attack_finished.is_connected(_on_attack_finished):
			_controller.attack_finished.disconnect(_on_attack_finished)
		if _controller.attack_cancelled.is_connected(_on_attack_cancelled):
			_controller.attack_cancelled.disconnect(_on_attack_cancelled)
