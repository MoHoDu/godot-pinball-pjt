class_name Stage1GameOver
extends CanvasLayer


signal restart_requested
signal finished


@export var screen_fade_duration: float = 0.35
@export var logo_fade_in_duration: float = 0.25
@export var logo_hold_duration: float = 1.3
@export var logo_fade_out_duration: float = 0.4
@export var screen_fade_out_duration: float = 0.35

@onready var _black_background: ColorRect = %BlackBackground
@onready var _game_over_logo: Control = %GameOverLogo

var _playing: bool = false
var _restart_requested: bool = false


func play() -> void:
	if _playing:
		return
	_playing = true
	_black_background.color.a = 0.0
	_game_over_logo.modulate.a = 0.0
	var sequence: Tween = create_tween()
	sequence.tween_property(
		_black_background, ^"color:a", 1.0, screen_fade_duration
	)
	sequence.tween_property(
		_game_over_logo, ^"modulate:a", 1.0, logo_fade_in_duration
	)
	sequence.tween_interval(logo_hold_duration)
	sequence.tween_property(
		_game_over_logo, ^"modulate:a", 0.0, logo_fade_out_duration
	)
	sequence.tween_callback(_request_restart)


func reveal_restarted_stage() -> void:
	var sequence: Tween = create_tween()
	sequence.tween_property(
		_black_background, ^"color:a", 0.0, screen_fade_out_duration
	)
	sequence.tween_callback(_finish)


func _request_restart() -> void:
	if _restart_requested:
		return
	_restart_requested = true
	restart_requested.emit()


func _finish() -> void:
	finished.emit()
	queue_free()
