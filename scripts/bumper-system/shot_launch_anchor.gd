@tool
class_name ShotLaunchAnchor
extends Marker2D


@export var input_action: StringName = &"flipper_select_up"
@export var is_safe_default := false


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_line(Vector2.ZERO, Vector2(72.0, 0.0), Color(0.5, 0.95, 0.8, 0.8), 3.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(72.0, 0.0),
			Vector2(58.0, -8.0),
			Vector2(58.0, 8.0),
		]),
		Color(0.5, 0.95, 0.8, 0.8)
	)

