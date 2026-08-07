class_name BossDamageGate
extends Node


signal invulnerability_changed(is_invulnerable: bool)


var _controller: BossAttackController = null
var _controller_state_changed_callback: Callable = Callable()
var _is_invulnerable: bool = true


func _init() -> void:
	set_process(false)


func bind_controller(controller: BossAttackController) -> bool:
	if controller == null or not _is_controller_runtime_valid(controller):
		return false

	if _controller == controller:
		_connect_controller_signal(controller)
		_synchronize_with_controller(controller)
		set_process(true)
		return true

	_disconnect_controller_signal()
	_controller = controller
	_connect_controller_signal(controller)
	_synchronize_with_controller(controller)
	set_process(true)
	return true


func unbind_controller() -> void:
	_disconnect_controller_signal()
	_controller = null
	set_process(false)
	_set_invulnerable(true)


func is_bound() -> bool:
	return _is_controller_runtime_valid(_controller)


func is_damage_allowed() -> bool:
	return is_bound() and not _is_invulnerable


func is_invulnerable() -> bool:
	if not is_bound():
		return true
	return _is_invulnerable


func _process(_delta: float) -> void:
	if not _is_controller_runtime_valid(_controller):
		_handle_controller_loss()


func _on_controller_state_changed(
	_previous_state: BossAttackController.State,
	current_state: BossAttackController.State,
	source_controller: BossAttackController
) -> void:
	if source_controller != _controller:
		return
	if not _is_controller_runtime_valid(source_controller):
		_handle_controller_loss()
		return
	_set_invulnerable(current_state == BossAttackController.State.ACTIVE)


func _synchronize_with_controller(controller: BossAttackController) -> void:
	_set_invulnerable(
		controller.current_state == BossAttackController.State.ACTIVE
	)


func _set_invulnerable(value: bool) -> void:
	if value == _is_invulnerable:
		return
	_is_invulnerable = value
	invulnerability_changed.emit(_is_invulnerable)


func _connect_controller_signal(controller: BossAttackController) -> void:
	if _controller_state_changed_callback.is_null():
		_controller_state_changed_callback = \
			_on_controller_state_changed.bind(controller)
	if not controller.state_changed.is_connected(
		_controller_state_changed_callback
	):
		controller.state_changed.connect(_controller_state_changed_callback)


func _disconnect_controller_signal() -> void:
	if is_instance_valid(_controller) \
			and not _controller_state_changed_callback.is_null() \
			and _controller.state_changed.is_connected(
				_controller_state_changed_callback
			):
		_controller.state_changed.disconnect(
			_controller_state_changed_callback
		)
	_controller_state_changed_callback = Callable()


func _handle_controller_loss() -> void:
	_disconnect_controller_signal()
	_controller = null
	set_process(false)
	_set_invulnerable(true)


func _is_controller_runtime_valid(controller: BossAttackController) -> bool:
	return is_instance_valid(controller) and controller.is_inside_tree()
