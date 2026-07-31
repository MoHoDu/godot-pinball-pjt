class_name FlipperParryFeedback
extends Node2D


const GRADE_NONE := 0
const GRADE_NORMAL := 1
const GRADE_PERFECT := 2
const NORMAL_COLOR := Color(0.2, 0.85, 1.0, 1.0)
const PERFECT_COLOR := Color(1.0, 0.78, 0.12, 1.0)


var _flipper: Node2D
var _flipper_sprite: Sprite2D
var _original_sprite_modulate := Color.WHITE
var _flash_tween: Tween


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX


func bind_to_flipper(flipper: Node2D) -> void:
	if _flipper == flipper:
		return

	if is_instance_valid(_flipper) \
		and _flipper.is_connected(&"parry_resolved", _on_parry_resolved):
		_flipper.disconnect(&"parry_resolved", _on_parry_resolved)

	_flipper = flipper
	_flipper_sprite = _flipper.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(_flipper_sprite):
		_original_sprite_modulate = _flipper_sprite.self_modulate

	if not _flipper.is_connected(&"parry_resolved", _on_parry_resolved):
		_flipper.connect(&"parry_resolved", _on_parry_resolved)


func get_feedback_text(grade: int) -> String:
	match grade:
		GRADE_NORMAL:
			return "PARRY!"
		GRADE_PERFECT:
			return "PERFECT!"
		_:
			return ""


func get_feedback_color(grade: int) -> Color:
	return PERFECT_COLOR if grade == GRADE_PERFECT else NORMAL_COLOR


func get_feedback_font_size(grade: int) -> int:
	return 40 if grade == GRADE_PERFECT else 28


func get_feedback_duration(grade: int) -> float:
	return 0.3 if grade == GRADE_PERFECT else 0.18


## 물리 노드의 위치·회전·크기는 바꾸지 않고 색과 문구만 재생합니다.
func play_feedback(grade: int, contact_point: Vector2) -> void:
	if grade == GRADE_NONE:
		return

	global_position = contact_point
	_flash_sprite(grade)

	var feedback_label := Label.new()
	feedback_label.text = get_feedback_text(grade)
	feedback_label.position = Vector2(-90.0, -54.0)
	feedback_label.size = Vector2(180.0, 48.0)
	feedback_label.pivot_offset = feedback_label.size * 0.5
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", get_feedback_color(grade))
	feedback_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08, 1.0))
	feedback_label.add_theme_constant_override("outline_size", 8)
	feedback_label.add_theme_font_size_override(
		"font_size",
		get_feedback_font_size(grade)
	)
	feedback_label.scale = Vector2.ONE * 0.82
	add_child(feedback_label)

	var duration := get_feedback_duration(grade)
	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(
		feedback_label,
		"position",
		feedback_label.position + Vector2(0.0, -34.0),
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(
		feedback_label,
		"scale",
		Vector2.ONE * (1.12 if grade == GRADE_PERFECT else 1.0),
		duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(
		feedback_label,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		duration * 0.65
	).set_delay(duration * 0.35)
	label_tween.finished.connect(feedback_label.queue_free)


func _flash_sprite(grade: int) -> void:
	if not is_instance_valid(_flipper_sprite):
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flipper_sprite.self_modulate = get_feedback_color(grade).lightened(0.25)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_flipper_sprite,
		"self_modulate",
		_original_sprite_modulate,
		get_feedback_duration(grade)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_parry_resolved(
	_ball: RigidBody2D,
	grade: int,
	contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_speed_multiplier: float
) -> void:
	play_feedback(grade, contact_point)
