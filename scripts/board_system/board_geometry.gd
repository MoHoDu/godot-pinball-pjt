class_name BoardGeometry
extends RefCounted


const EPSILON := 0.05


static func signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for index in polygon.size():
		var next_index := (index + 1) % polygon.size()
		area += polygon[index].cross(polygon[next_index])
	return area * 0.5


static func area(polygon: PackedVector2Array) -> float:
	return absf(signed_area(polygon))


static func is_valid_polygon(polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 \
		and area(polygon) > EPSILON \
		and not Geometry2D.triangulate_polygon(polygon).is_empty()


static func contains_point(
	polygon: PackedVector2Array,
	point: Vector2
) -> bool:
	if not is_valid_polygon(polygon):
		return false
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	return distance_to_edges(polygon, point) <= EPSILON


static func distance_to_edges(
	polygon: PackedVector2Array,
	point: Vector2
) -> float:
	if polygon.size() < 2:
		return INF
	var minimum := INF
	for index in polygon.size():
		var next_index := (index + 1) % polygon.size()
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			polygon[index],
			polygon[next_index]
		)
		minimum = minf(minimum, point.distance_to(closest))
	return minimum


static func contains_circle(
	polygon: PackedVector2Array,
	center: Vector2,
	radius: float
) -> bool:
	return contains_point(polygon, center) \
		and distance_to_edges(polygon, center) + EPSILON >= maxf(radius, 0.0)


static func contains_polygon(
	outer: PackedVector2Array,
	inner: PackedVector2Array
) -> bool:
	if not is_valid_polygon(outer) or not is_valid_polygon(inner):
		return false
	var intersections := Geometry2D.intersect_polygons(inner, outer)
	var intersection_area := 0.0
	for intersection: PackedVector2Array in intersections:
		intersection_area += area(intersection)
	return intersection_area + EPSILON >= area(inner)


static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	return bounds


static func convert_polygon(
	polygon: PackedVector2Array,
	from_node: Node2D,
	to_node: Node2D
) -> PackedVector2Array:
	var converted := PackedVector2Array()
	for point: Vector2 in polygon:
		converted.append(to_node.to_local(from_node.to_global(point)))
	return converted
