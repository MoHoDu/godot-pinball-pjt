class_name BossBattleCompletionController
extends Node


signal battle_completed


var _health: BossHealthComponent = null
var _defeated_callback: Callable = Callable()
var _is_completed: bool = false


func _exit_tree() -> void:
	unbind_health()


func bind_health(health: BossHealthComponent) -> bool:
	if health == null or not is_instance_valid(health):
		return false
	if health == _health:
		_connect_health_signal()
		_synchronize_with_health()
		return true

	_disconnect_health_signal()
	_health = health
	_is_completed = false
	_connect_health_signal()
	_synchronize_with_health()
	return true


func unbind_health() -> void:
	_disconnect_health_signal()
	_health = null


func reset() -> void:
	_is_completed = false


func is_completed() -> bool:
	return _is_completed


func is_bound() -> bool:
	return _health != null \
		and is_instance_valid(_health) \
		and not _defeated_callback.is_null() \
		and _health.defeated.is_connected(_defeated_callback)


func _on_health_defeated(source_health: BossHealthComponent) -> void:
	if source_health != _health \
			or not is_instance_valid(source_health) \
			or not source_health.is_defeated():
		return
	_complete_battle()


func _synchronize_with_health() -> void:
	if is_instance_valid(_health) and _health.is_defeated():
		_complete_battle()


func _complete_battle() -> void:
	if _is_completed:
		return
	_is_completed = true
	battle_completed.emit()


func _connect_health_signal() -> void:
	if not is_instance_valid(_health):
		return
	if _defeated_callback.is_null():
		_defeated_callback = _on_health_defeated.bind(_health)
	if not _health.defeated.is_connected(_defeated_callback):
		_health.defeated.connect(_defeated_callback)


func _disconnect_health_signal() -> void:
	if is_instance_valid(_health) \
			and not _defeated_callback.is_null() \
			and _health.defeated.is_connected(_defeated_callback):
		_health.defeated.disconnect(_defeated_callback)
	_defeated_callback = Callable()
