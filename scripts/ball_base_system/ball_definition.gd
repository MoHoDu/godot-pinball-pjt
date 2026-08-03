class_name BallDefinition
extends Resource


@export var ball_id: StringName = &"ball"
@export var display_name: String = "Ball"
@export var ball_scene: PackedScene


func is_valid() -> bool:
	return not ball_id.is_empty() and ball_scene != null
