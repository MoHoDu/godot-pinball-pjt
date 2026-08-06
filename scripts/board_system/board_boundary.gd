@tool
class_name BoardBoundary
extends Polygon2D


@export var board_id: StringName = &"board"


func get_polygon_in(layout: Node2D) -> PackedVector2Array:
	if layout == null:
		return PackedVector2Array()
	return BoardGeometry.convert_polygon(polygon, self, layout)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if board_id.is_empty():
		warnings.append("Board boundary requires a non-empty board_id.")
	if not BoardGeometry.is_valid_polygon(polygon):
		warnings.append("Board boundary requires a valid, non-self-intersecting polygon.")
	return warnings
