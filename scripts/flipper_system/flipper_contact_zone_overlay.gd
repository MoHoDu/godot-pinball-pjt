@tool
extends Node2D


func _init() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX


func _draw() -> void:
	var flipper := get_parent()
	if flipper == null \
		or not flipper.has_method(&"get_contact_zone_visualization_segments"):
		return

	var segments := flipper.call(
		&"get_contact_zone_visualization_segments"
	) as Array
	for segment: Dictionary in segments:
		draw_line(
			segment.get(&"start", Vector2.ZERO),
			segment.get(&"end", Vector2.ZERO),
			segment.get(&"color", Color.WHITE),
			float(segment.get(&"width", 8.0)),
			true
		)
