@tool
class_name BumperVisual
extends Node2D


const DISABLED_ALPHA := 0.28


func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func refresh_from_bumper() -> void:
	queue_redraw()


func _draw() -> void:
	var bumper := get_parent() as Bumper
	if bumper == null or bumper.settings == null:
		return
	var presentation := bumper.settings.presentation
	if presentation == null:
		return

	var alpha := 1.0
	if bumper.state != Bumper.BumperState.ACTIVE:
		alpha = DISABLED_ALPHA
	if bumper.state == Bumper.BumperState.RESPAWN_TELEGRAPH:
		alpha = 0.55 + sin(Time.get_ticks_msec() * 0.018) * 0.25

	var radius := bumper.settings.visual_diameter * 0.5
	var fill := Color(presentation.fill_color, presentation.fill_color.a * alpha)
	var rim := Color(presentation.rim_color, presentation.rim_color.a * alpha)
	var accent := Color(presentation.accent_color, presentation.accent_color.a * alpha)
	var curse := Color(presentation.curse_color, presentation.curse_color.a * alpha)

	match presentation.visual_style:
		BumperPresentationSettings.VisualStyle.BUTTON:
			_draw_button(radius, fill, rim, curse)
		BumperPresentationSettings.VisualStyle.COTTON:
			_draw_cotton(radius, fill, rim, curse)
		BumperPresentationSettings.VisualStyle.SPRING_DOLL:
			_draw_spring_doll(radius, fill, rim, accent, curse)
		BumperPresentationSettings.VisualStyle.DRUM:
			_draw_drum(radius, fill, rim, accent, curse)
		BumperPresentationSettings.VisualStyle.CANNON:
			_draw_cannon(bumper, radius, fill, rim, accent, curse)
		BumperPresentationSettings.VisualStyle.STARLIGHT_BROOCH:
			_draw_starlight_brooch(radius, fill, rim, accent)
		BumperPresentationSettings.VisualStyle.GOLDEN_GEARS:
			_draw_golden_gears(radius, fill, rim, accent)
		BumperPresentationSettings.VisualStyle.CRESCENT_NEEDLE:
			_draw_crescent_needle(radius, rim, accent)
		BumperPresentationSettings.VisualStyle.FORGOTTEN_STAR_BELL:
			_draw_forgotten_star_bell(radius, fill, rim, accent)

	_draw_durability(bumper, radius, curse)


func _draw_button(radius: float, fill: Color, rim: Color, curse: Color) -> void:
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 48, rim, 6.0, true)
	for point: Vector2 in [
		Vector2(-0.22, -0.22), Vector2(0.22, -0.22),
		Vector2(-0.22, 0.22), Vector2(0.22, 0.22),
	]:
		draw_circle(point * radius, radius * 0.09, Color(curse, curse.a * 0.7))


func _draw_cotton(radius: float, fill: Color, rim: Color, curse: Color) -> void:
	var tufts := [
		Vector2(-0.38, 0.08), Vector2(-0.2, -0.3), Vector2(0.16, -0.36),
		Vector2(0.42, -0.02), Vector2(0.22, 0.32), Vector2(-0.18, 0.34),
	]
	for tuft: Vector2 in tufts:
		draw_circle(tuft * radius, radius * 0.54, fill)
	draw_arc(Vector2.ZERO, radius * 0.92, 0.15, TAU - 0.1, 40, rim, 4.0, true)
	draw_line(Vector2(-0.3, 0.2) * radius, Vector2(0.3, -0.12) * radius, curse, 5.0)


func _draw_spring_doll(
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color,
	curse: Color
) -> void:
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 48, rim, 6.0, true)
	var spring := PackedVector2Array()
	for index in 7:
		var x := (-0.36 + index * 0.12) * radius
		var y := (-0.08 if index % 2 == 0 else 0.16) * radius
		spring.append(Vector2(x, y))
	draw_polyline(spring, accent, 7.0, true)
	draw_circle(Vector2(0.0, -0.34) * radius, radius * 0.19, rim)
	draw_line(Vector2(-0.5, 0.42) * radius, Vector2(0.5, 0.42) * radius, curse, 4.0)


func _draw_drum(
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color,
	curse: Color
) -> void:
	draw_circle(Vector2.ZERO, radius, accent)
	draw_circle(Vector2.ZERO, radius * 0.78, fill)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 48, rim, 7.0, true)
	draw_line(Vector2(-0.48, -0.48) * radius, Vector2(0.48, 0.48) * radius, curse, 4.0)
	draw_line(Vector2(0.48, -0.48) * radius, Vector2(-0.48, 0.48) * radius, curse, 4.0)


func _draw_cannon(
	bumper: Bumper,
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color,
	curse: Color
) -> void:
	draw_circle(Vector2.ZERO, radius * 0.72, fill)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 40, rim, 6.0, true)
	var direction := Vector2.UP
	if bumper.has_method(&"get_selected_launch_direction"):
		direction = bumper.call(&"get_selected_launch_direction")
		direction = direction.rotated(-bumper.global_rotation)
	var tangent := direction.orthogonal()
	var barrel := PackedVector2Array([
		tangent * radius * 0.22,
		direction * radius * 0.96 + tangent * radius * 0.3,
		direction * radius * 0.96 - tangent * radius * 0.3,
		-tangent * radius * 0.22,
	])
	draw_colored_polygon(barrel, accent)
	draw_polyline(PackedVector2Array([barrel[0], barrel[1], barrel[2], barrel[3], barrel[0]]), rim, 4.0)
	draw_circle(Vector2.ZERO, radius * 0.2, curse)


func _draw_starlight_brooch(
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color
) -> void:
	var points := PackedVector2Array()
	for index in 10:
		var point_radius := radius * (0.82 if index % 2 == 0 else 0.38)
		points.append(
			Vector2.from_angle(-PI * 0.5 + index * PI / 5.0) * point_radius
		)
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array(Array(points) + [points[0]]), rim, 5.0, true)
	draw_circle(Vector2.ZERO, radius * 0.16, accent)


func _draw_golden_gears(
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color
) -> void:
	draw_circle(Vector2.ZERO, radius * 0.76, fill)
	for index in 8:
		var angle := TAU * index / 8.0
		draw_circle(Vector2.from_angle(angle) * radius * 0.72, radius * 0.2, rim)
	draw_circle(Vector2.ZERO, radius * 0.24, accent)


func _draw_crescent_needle(radius: float, rim: Color, accent: Color) -> void:
	draw_arc(Vector2.ZERO, radius * 0.7, -2.2, 1.2, 32, rim, 8.0, true)
	draw_circle(Vector2(-0.4, -0.5) * radius, radius * 0.12, accent)


func _draw_forgotten_star_bell(
	radius: float,
	fill: Color,
	rim: Color,
	accent: Color
) -> void:
	draw_circle(Vector2.ZERO, radius * 0.62, fill)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 32, rim, 6.0, true)
	draw_circle(Vector2(0.0, 0.52) * radius, radius * 0.14, accent)


func _draw_durability(bumper: Bumper, radius: float, color: Color) -> void:
	var maximum := bumper.get_max_durability()
	if maximum <= 0:
		return
	for index in maximum:
		var active := index < bumper.current_durability
		var stitch_color := color if active else Color(color, color.a * 0.18)
		var x := (index - (maximum - 1) * 0.5) * 12.0
		draw_line(
			Vector2(x - 4.0, radius * 0.64),
			Vector2(x + 4.0, radius * 0.82),
			stitch_color,
			3.0
		)
