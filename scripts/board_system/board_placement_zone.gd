@tool
class_name BoardPlacementZone
extends Polygon2D


@export var zone_id: StringName = &"zone"
@export var repair_parts_only := true
@export var allowed_kind_ids := PackedStringArray()
@export var show_during_play := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = show_during_play


func accepts(placeable: BoardPlaceable) -> bool:
	if placeable == null:
		return false
	return accepts_kind(placeable.get_kind_id(), placeable.is_repair_part())


func accepts_kind(kind_id: StringName, is_repair_part: bool) -> bool:
	if repair_parts_only and not is_repair_part:
		return false
	if allowed_kind_ids.is_empty():
		return true
	return allowed_kind_ids.has(String(kind_id))


func get_polygon_in(layout: Node2D) -> PackedVector2Array:
	if layout == null:
		return PackedVector2Array()
	return BoardGeometry.convert_polygon(polygon, self, layout)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if zone_id.is_empty():
		warnings.append("Placement zone requires a non-empty zone_id.")
	if not BoardGeometry.is_valid_polygon(polygon):
		warnings.append("Placement zone requires a valid polygon.")
	return warnings
