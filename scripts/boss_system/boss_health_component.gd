class_name BossHealthComponent
extends Node


signal health_changed(current_health: int, max_health: int)
signal damage_applied(applied_damage: int, current_health: int)
signal defeated


var _max_health: int = 0
var _current_health: int = 0
var _is_configured: bool = false
var _defeat_reported: bool = false


func configure(max_health: int) -> bool:
	if max_health <= 0:
		return false

	var health_was_changed: bool = (
		not _is_configured
		or _max_health != max_health
		or _current_health != max_health
	)
	_max_health = max_health
	_current_health = max_health
	_is_configured = true
	_defeat_reported = false

	if health_was_changed:
		health_changed.emit(_current_health, _max_health)
	return true


func apply_damage(damage: int) -> int:
	if not _is_configured or damage <= 0 or is_defeated():
		return 0

	var applied_damage: int = mini(damage, _current_health)
	_current_health = maxi(_current_health - applied_damage, 0)
	damage_applied.emit(applied_damage, _current_health)
	health_changed.emit(_current_health, _max_health)

	if _current_health == 0 and not _defeat_reported:
		_defeat_reported = true
		defeated.emit()
	return applied_damage


func reset_health() -> bool:
	if not _is_configured:
		return false

	var health_was_changed: bool = _current_health != _max_health
	_current_health = _max_health
	_defeat_reported = false
	if health_was_changed:
		health_changed.emit(_current_health, _max_health)
	return true


func get_current_health() -> int:
	return _current_health


func get_max_health() -> int:
	return _max_health


func get_health_ratio() -> float:
	if not _is_configured:
		return 0.0
	var ratio: float = float(_current_health) / float(_max_health)
	return clampf(ratio, 0.0, 1.0)


func is_defeated() -> bool:
	return _is_configured and _current_health == 0


func is_configured() -> bool:
	return _is_configured
