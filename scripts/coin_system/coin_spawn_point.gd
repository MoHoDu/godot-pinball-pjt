@tool
class_name CoinSpawnPoint
extends Marker2D


## wave 씬의 2D 에디터에서 직접 옮길 수 있는 코인 배치 지점입니다.


enum RouteKind {
	MAIN,
	RISK,
}


@export var point_id: StringName = &"coin"
@export var route_kind := RouteKind.MAIN:
	set(value):
		route_kind = value
		queue_redraw()
@export_range(4.0, 64.0, 1.0, "suffix:px") var editor_radius := 14.0:
	set(value):
		editor_radius = value
		queue_redraw()


func _ready() -> void:
	visible = Engine.is_editor_hint()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.95, 0.78, 0.22, 0.9)
	if route_kind == RouteKind.RISK:
		color = Color(0.95, 0.42, 0.22, 0.9)
	draw_circle(Vector2.ZERO, editor_radius, Color(color, 0.24))
	draw_arc(Vector2.ZERO, editor_radius, 0.0, TAU, 24, color, 2.0, true)
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), color, 2.0)


func pickup_id_for_wave(wave_id: int) -> StringName:
	return &"coin_w%d_%s" % [wave_id, point_id]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if point_id.is_empty():
		warnings.append("Coin spawn point requires a non-empty point_id.")
	return warnings
