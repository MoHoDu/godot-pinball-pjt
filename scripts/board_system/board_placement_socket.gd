@tool
class_name BoardPlacementSocket
extends Marker2D


enum VisualState {
	IDLE,
	SELECTED,
	COMPATIBLE,
	OCCUPIED,
	DISABLED,
}


const VISUAL_SIZE := 116.0


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


var visual_state := VisualState.IDLE


func _ready() -> void:
	visible = Engine.is_editor_hint() or show_during_play
	queue_redraw()


func _draw() -> void:
	var colors := _get_state_colors()
	var half_size := Vector2.ONE * VISUAL_SIZE * 0.5
	var bounds := Rect2(-half_size, Vector2.ONE * VISUAL_SIZE)
	draw_rect(bounds, colors.fill, true)
	draw_rect(bounds, colors.border, false, 4.0)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 40, colors.ring, 4.0)
	if visual_state == VisualState.OCCUPIED:
		draw_circle(Vector2.ZERO, 9.0, colors.ring)
	else:
		draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), colors.ring, 3.0)
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), colors.ring, 3.0)


func set_visual_state(value: VisualState) -> void:
	if visual_state == value:
		return
	visual_state = value
	queue_redraw()


func _get_state_colors() -> Dictionary:
	match visual_state:
		VisualState.SELECTED:
			return {
				&"fill": Color(0.09, 0.24, 0.27, 0.84),
				&"border": Color(0.95, 0.90, 0.77, 0.98),
				&"ring": Color(0.40, 0.86, 0.82, 1.0),
			}
		VisualState.COMPATIBLE:
			return {
				&"fill": Color(0.08, 0.34, 0.35, 0.72),
				&"border": Color(0.40, 0.86, 0.82, 1.0),
				&"ring": Color(0.95, 0.90, 0.77, 1.0),
			}
		VisualState.OCCUPIED:
			return {
				&"fill": Color(0.25, 0.18, 0.09, 0.62),
				&"border": Color(0.66, 0.51, 0.25, 0.94),
				&"ring": Color(0.95, 0.90, 0.77, 0.9),
			}
		VisualState.DISABLED:
			return {
				&"fill": Color(0.05, 0.11, 0.13, 0.45),
				&"border": Color(0.31, 0.42, 0.41, 0.46),
				&"ring": Color(0.45, 0.55, 0.54, 0.42),
			}
	return {
		&"fill": Color(0.05, 0.18, 0.21, 0.58),
		&"border": Color(0.34, 0.56, 0.55, 0.8),
		&"ring": Color(0.78, 0.74, 0.66, 0.8),
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if socket_id.is_empty():
		warnings.append("Placement socket requires a non-empty socket_id.")
	if zone_id.is_empty():
		warnings.append("Placement socket requires a target zone_id.")
	return warnings
