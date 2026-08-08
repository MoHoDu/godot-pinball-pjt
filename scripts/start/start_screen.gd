class_name StartScreen
extends Control


@export var next_scene: PackedScene = null
@export_range(0.0, 10.0, 0.01) var intro_fade_duration: float = 0.6
@export_range(0.0, 10.0, 0.01) var logo_delay_sec: float = 1.3
@export_range(0.0, 10.0, 0.01) var dark_overlay_fade_duration: float = 0.5
@export_range(0.0, 10.0, 0.01) var logo_fade_duration: float = 0.5
@export_range(0.0, 10.0, 0.01) var exit_fade_duration: float = 0.35

@onready var _dark_overlay: ColorRect = $DarkOverlay
@onready var _logo: TextureRect = $Logo
@onready var _start_prompt: Label = %StartPrompt
@onready var _fade_rect: ColorRect = %FadeRect

var _transition_started: bool = false
var _input_enabled: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	var dark_overlay_target_alpha: float = _dark_overlay.color.a
	_fade_rect.color.a = 1.0
	_dark_overlay.color.a = 0.0
	_logo.modulate.a = 0.0
	_start_prompt.visible = false
	var intro_tween: Tween = create_tween()
	intro_tween.tween_property(
		_fade_rect,
		^"color:a",
		0.0,
		intro_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_interval(logo_delay_sec)
	intro_tween.tween_property(
		_dark_overlay,
		^"color:a",
		dark_overlay_target_alpha,
		dark_overlay_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_property(
		_logo,
		^"modulate:a",
		1.0,
		logo_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_callback(_show_start_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or _transition_started or not _is_start_input(event):
		return
	get_viewport().set_input_as_handled()
	_begin_transition()


func _show_start_prompt() -> void:
	_start_prompt.visible = true
	_start_prompt.modulate.a = 1.0
	_input_enabled = true
	_start_prompt_pulse()


func _is_start_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _begin_transition() -> void:
	_transition_started = true
	if next_scene == null:
		push_error("StartScreen requires next_scene to be assigned.")
		return
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(
		_fade_rect,
		^"color:a",
		1.0,
		exit_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	exit_tween.tween_callback(_change_to_next_scene)


func _start_prompt_pulse() -> void:
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(
		_start_prompt,
		^"modulate:a",
		0.45,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(
		_start_prompt,
		^"modulate:a",
		1.0,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _change_to_next_scene() -> void:
	var change_error: Error = get_tree().change_scene_to_packed(next_scene)
	if change_error != OK:
		push_error("StartScreen failed to change scene: %s" % error_string(change_error))
