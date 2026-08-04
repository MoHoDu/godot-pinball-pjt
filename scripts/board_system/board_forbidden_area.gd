@tool
class_name BoardForbiddenArea
extends Polygon2D


@export var area_id: StringName = &"forbidden"
@export_multiline var reason := "Reserved gameplay space"
@export_range(0.0, 512.0, 1.0, "suffix:px") var extra_clearance := 0.0
@export var show_during_play := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = show_during_play


func get_polygon_in(layout: Node2D) -> PackedVector2Array:
	if layout == null:
		return PackedVector2Array()
	return BoardGeometry.convert_polygon(polygon, self, layout)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if area_id.is_empty():
		warnings.append("Forbidden area requires a non-empty area_id.")
	if not BoardGeometry.is_valid_polygon(polygon):
		warnings.append("Forbidden area requires a valid polygon.")
	return warnings
