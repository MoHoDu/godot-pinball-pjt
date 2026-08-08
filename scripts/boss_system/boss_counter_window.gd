class_name BossCounterWindow
extends Node


signal counter_activated
signal counter_consumed
signal counter_expired


var _duration_sec: float = 0.0
var _remaining_time_sec: float = 0.0
var _is_configured: bool = false
var _is_ready: bool = false


func configure(duration_sec: float) -> bool:
	if not is_finite(duration_sec) or duration_sec <= 0.0:
		return false

	_duration_sec = duration_sec
	_is_configured = true
	return true


func activate() -> bool:
	if not _is_configured:
		return false

	_is_ready = true
	_remaining_time_sec = _duration_sec
	counter_activated.emit()
	return true


func consume() -> bool:
	if not _is_ready:
		return false

	_is_ready = false
	_remaining_time_sec = 0.0
	counter_consumed.emit()
	return true


func reset() -> void:
	_is_ready = false
	_remaining_time_sec = 0.0


func is_ready() -> bool:
	return _is_ready


func get_remaining_time_sec() -> float:
	return _remaining_time_sec


func _process(delta: float) -> void:
	if not _is_ready:
		return

	_remaining_time_sec -= maxf(delta, 0.0)
	if _remaining_time_sec > 0.0:
		return

	_is_ready = false
	_remaining_time_sec = 0.0
	counter_expired.emit()
