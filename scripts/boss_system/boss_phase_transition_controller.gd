class_name BossPhaseTransitionController
extends Node


signal phase_2_entered(current_hp: int)


var _phase_2_threshold_hp: int = 0
var _is_threshold_configured: bool = false
var _health: BossHealthComponent = null
var _health_changed_callback: Callable = Callable()
var _previous_health: int = 0
var _is_phase_2: bool = false


func _exit_tree() -> void:
	unbind_health()


func configure_phase_2_threshold(threshold_hp: int) -> bool:
	if threshold_hp <= 0:
		return false

	_phase_2_threshold_hp = threshold_hp
	_is_threshold_configured = true
	_synchronize_with_bound_health()
	return true


func bind_health(health: BossHealthComponent) -> bool:
	if health == null or not is_instance_valid(health):
		return false

	if health == _health:
		_connect_health_signal()
		_synchronize_with_bound_health()
		return true

	_disconnect_health_signal()
	_health = health
	_is_phase_2 = false
	_previous_health = health.get_current_health()
	_connect_health_signal()
	_synchronize_with_bound_health()
	return true


func unbind_health() -> void:
	_disconnect_health_signal()
	_health = null
	_previous_health = 0


func reset() -> void:
	_is_phase_2 = false
	_previous_health = (
		_health.get_current_health()
		if is_instance_valid(_health)
		else 0
	)


func is_phase_2() -> bool:
	return _is_phase_2


func _on_health_changed(
	current_health: int,
	_max_health: int,
	source_health: BossHealthComponent
) -> void:
	if source_health != _health or not is_instance_valid(source_health):
		return

	var previous_health: int = _previous_health
	_previous_health = current_health
	if _is_phase_2 \
			or not _is_threshold_configured \
			or not source_health.is_configured() \
			or current_health <= 0 \
			or source_health.is_defeated():
		return
	if previous_health > _phase_2_threshold_hp \
			and current_health <= _phase_2_threshold_hp:
		_enter_phase_2(current_health)


func _synchronize_with_bound_health() -> void:
	if _is_phase_2 \
			or not _is_threshold_configured \
			or not is_instance_valid(_health) \
			or not _health.is_configured():
		return

	var current_health: int = _health.get_current_health()
	_previous_health = current_health
	if current_health > 0 \
			and current_health <= _phase_2_threshold_hp \
			and not _health.is_defeated():
		_enter_phase_2(current_health)


func _enter_phase_2(current_health: int) -> void:
	if _is_phase_2:
		return
	_is_phase_2 = true
	phase_2_entered.emit(current_health)


func _connect_health_signal() -> void:
	if not is_instance_valid(_health):
		return
	if _health_changed_callback.is_null():
		_health_changed_callback = _on_health_changed.bind(_health)
	if not _health.health_changed.is_connected(_health_changed_callback):
		_health.health_changed.connect(_health_changed_callback)


func _disconnect_health_signal() -> void:
	if is_instance_valid(_health) \
			and not _health_changed_callback.is_null() \
			and _health.health_changed.is_connected(_health_changed_callback):
		_health.health_changed.disconnect(_health_changed_callback)
	_health_changed_callback = Callable()
