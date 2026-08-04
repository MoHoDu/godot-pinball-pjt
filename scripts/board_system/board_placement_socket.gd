@tool
class_name BoardPlacementSocket
extends Marker2D


@export var socket_id: StringName = &"socket"
@export var zone_id: StringName = &"zone"
@export_range(1.0, 512.0, 1.0, "suffix:px") var reserve_radius := 72.0:
	set(value):
		reserve_radius = maxf(value, 1.0)
		queue_redraw()
@export var enabled := true:
	set(value):
		enabled = value
		queue_redraw()
@export var show_during_play := false


func _ready() -> void:
	visible = Engine.is_editor_hint() or show_during_play
	queue_redraw()


func _draw() -> void:
	var socket_color := (
		Color(0.28, 0.9, 0.78, 0.65)
		if enabled
		else Color(0.42, 0.42, 0.42, 0.45)
	)
	draw_arc(Vector2.ZERO, reserve_radius, 0.0, TAU, 48, socket_color, 2.0)
	draw_circle(Vector2.ZERO, 7.0, socket_color)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if socket_id.is_empty():
		warnings.append("Placement socket requires a non-empty socket_id.")
	if zone_id.is_empty():
		warnings.append("Placement socket requires a target zone_id.")
	return warnings
