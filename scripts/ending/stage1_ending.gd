class_name Stage1Ending
extends Control


@export_file("*.tscn") var return_scene_path: String = ""

@onready var _fade_rect: ColorRect = %FadeRect


func _ready() -> void:
	_fade_rect.color.a = 1.0
	var sequence: Tween = create_tween()
	sequence.tween_property(_fade_rect, ^"color:a", 0.0, 0.6)
	sequence.tween_interval(2.5)
	sequence.tween_property(_fade_rect, ^"color:a", 1.0, 1.0)
	sequence.tween_callback(_return_to_start)


func _return_to_start() -> void:
	if return_scene_path.is_empty() or not ResourceLoader.exists(return_scene_path):
		push_error("Stage1Ending requires a valid return_scene_path.")
		return
	var change_error: Error = get_tree().change_scene_to_file(return_scene_path)
	if change_error != OK:
		push_error("Stage1Ending failed to change scene: %s" % error_string(change_error))
