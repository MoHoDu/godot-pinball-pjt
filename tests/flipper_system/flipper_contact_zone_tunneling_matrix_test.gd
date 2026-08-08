extends SceneTree


const BASE_BALL_SCENE_PATH := "res://Resources/Prefabs/balls/base/base_ball.tscn"
const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/Prefabs/flippers/variants/normal_flipper_left.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://Resources/Prefabs/flippers/variants/normal_flipper_right.tscn"
const TEST_FLIPPER_LENGTH := 328.0
const BALL_DIAMETER := 44.0
const START_CLEARANCE := 100.0
const MAX_ALLOWED_PENETRATION := 11.0
const MAX_TEST_FRAMES := 20
const ZONE_CASES := [
	{&"name": "A20", &"percent": 20.0},
	{&"name": "A30", &"percent": 30.0},
	{&"name": "A34", &"percent": 34.0},
	{&"name": "B", &"percent": 50.0},
	{&"name": "C", &"percent": 80.0},
	{&"name": "D", &"percent": 95.0},
]
const SPEED_CASES := [545.0, 1540.0]
const OBLIQUE_ANGLE_CASES := [-45.0, 0.0, 45.0]
const FLIPPER_CASES := [
	{&"name": "left", &"path": LEFT_FLIPPER_SCENE_PATH},
	{&"name": "right", &"path": RIGHT_FLIPPER_SCENE_PATH},
]


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "영역별 터널링 테스트에 실제 Pinball 씬이 필요하다.")
	if ball_scene == null:
		_finish()
		return

	for flipper_case: Dictionary in FLIPPER_CASES:
		var flipper_scene := load(String(flipper_case[&"path"])) as PackedScene
		_expect(flipper_scene != null, \
			"%s 플리퍼 씬을 불러올 수 있어야 한다." % flipper_case[&"name"])
		if flipper_scene == null:
			continue

		for zone_case: Dictionary in ZONE_CASES:
			for speed: float in SPEED_CASES:
				var angles: Array = (
					OBLIQUE_ANGLE_CASES
					if zone_case[&"name"] == "A30"
					else [0.0]
				)
				for angle_degrees: float in angles:
					var result := await _run_contact_case(
						flipper_scene,
						ball_scene,
						float(zone_case[&"percent"]),
						speed,
						angle_degrees
					)
					var case_name := "%s-%s-%.0f-%+.0fdeg" % [
						flipper_case[&"name"],
						zone_case[&"name"],
						speed,
						angle_degrees,
					]
					print("CASE: %s actual_zone=%.1f response=%s penetration=%.2f" % [
						case_name,
						float(result.get(&"actual_percent", -1.0)),
						bool(result.get(&"collision_response", false)),
						float(result.get(&"maximum_penetration", INF)),
					])
					_expect(bool(result.get(&"collision_response", false)), \
						"%s 공에 실제 충돌 반응이 발생해야 한다." % case_name)
					_expect(
						float(result.get(&"maximum_penetration", INF))
							<= MAX_ALLOWED_PENETRATION,
						"%s 공의 실제 고체 영역 침투 깊이가 %.2fpx이면 안 된다." % [
							case_name,
							float(result.get(&"maximum_penetration", INF)),
						]
					)
					_expect(not bool(result.get(&"center_entered_solid", true)), \
						"%s 공 중심이 플리퍼의 실제 고체 영역에 들어가면 안 된다." % case_name)

	_finish()


func _run_contact_case(
	flipper_scene: PackedScene,
	ball_scene: PackedScene,
	target_percent: float,
	speed: float,
	angle_degrees: float
) -> Dictionary:
	var flipper := flipper_scene.instantiate() as PinballFlipper
	flipper.flipper_length = TEST_FLIPPER_LENGTH
	root.add_child(flipper)
	var ball := ball_scene.instantiate() as Pinball
	ball.freeze = true
	ball.global_position = Vector2(0.0, -1000.0)
	root.add_child(ball)
	await physics_frame

	_configure_ball(ball)
	var polygon: PackedVector2Array = flipper.call(
		&"_get_world_collision_polygon",
		flipper.rotation
	)
	var axis_data := _get_axis_data(flipper.global_position, polygon)
	if axis_data.is_empty():
		ball.queue_free()
		flipper.queue_free()
		await process_frame
		return {}

	var axis: Vector2 = axis_data[&"axis"]
	var tip_distance: float = axis_data[&"tip_distance"]
	var target_point := flipper.global_position \
		+ axis * tip_distance * target_percent / 100.0
	var contact: Dictionary = flipper.call(
		&"_get_circle_polygon_contact",
		target_point,
		polygon
	)
	if contact.is_empty():
		ball.queue_free()
		flipper.queue_free()
		await process_frame
		return {}

	var contact_point: Vector2 = contact[&"point"]
	var contact_normal: Vector2 = contact[&"normal"]
	var ball_radius := _get_ball_radius(ball)
	var actual_percent := flipper.calculate_contact_position_percent(
		contact_point,
		flipper.rotation
	)
	var incoming_direction := (-contact_normal).rotated(
		deg_to_rad(angle_degrees)
	).normalized()
	var approach_normal_ratio := -incoming_direction.dot(contact_normal)
	if approach_normal_ratio <= 0.0:
		ball.queue_free()
		flipper.queue_free()
		await process_frame
		return {}
	var travel_distance := START_CLEARANCE / approach_normal_ratio
	ball.global_position = (
		contact_point
		+ contact_normal * ball_radius
		- incoming_direction * travel_distance
	)
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.reset_physics_interpolation()
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = incoming_direction * speed
	ball.sleeping = false

	var initial_velocity := ball.linear_velocity
	var collision_response := false
	var maximum_penetration := 0.0
	var center_entered_solid := false
	for _frame in MAX_TEST_FRAMES:
		await physics_frame
		var current_polygon: PackedVector2Array = flipper.call(
			&"_get_world_collision_polygon",
			flipper.rotation
		)
		var polygon_penetration := _get_polygon_penetration(
			ball.global_position,
			ball_radius,
			current_polygon,
			flipper
		)
		var pivot_penetration := _get_pivot_penetration(
			ball.global_position,
			ball_radius,
			flipper
		)
		maximum_penetration = maxf(
			maximum_penetration,
			maxf(
				float(polygon_penetration.get(&"depth", 0.0)),
				float(pivot_penetration.get(&"depth", 0.0))
			)
		)
		center_entered_solid = center_entered_solid \
			or bool(polygon_penetration.get(&"center_inside", false)) \
			or bool(pivot_penetration.get(&"center_inside", false))
		if ball.linear_velocity.distance_to(initial_velocity) > speed * 0.2:
			collision_response = true

	ball.queue_free()
	flipper.queue_free()
	await process_frame
	return {
		&"actual_percent": actual_percent,
		&"collision_response": collision_response,
		&"maximum_penetration": maximum_penetration,
		&"center_entered_solid": center_entered_solid,
	}


func _get_polygon_penetration(
	circle_center: Vector2,
	circle_radius: float,
	polygon: PackedVector2Array,
	flipper: PinballFlipper
) -> Dictionary:
	var contact: Dictionary = flipper.call(
		&"_get_circle_polygon_contact",
		circle_center,
		polygon
	)
	if contact.is_empty():
		return {}
	var contact_point: Vector2 = contact[&"point"]
	var distance := circle_center.distance_to(contact_point)
	var center_inside := Geometry2D.is_point_in_polygon(circle_center, polygon)
	return {
		&"depth": (
			circle_radius + distance
			if center_inside
			else maxf(circle_radius - distance, 0.0)
		),
		&"center_inside": center_inside,
	}


func _get_pivot_penetration(
	circle_center: Vector2,
	circle_radius: float,
	flipper: PinballFlipper
) -> Dictionary:
	var pivot := flipper.get_node_or_null(
		"PivotCollisionShape2D"
	) as CollisionShape2D
	if pivot == null or not pivot.shape is CircleShape2D:
		return {}
	var pivot_circle := pivot.shape as CircleShape2D
	var pivot_scale := pivot.global_scale.abs()
	var pivot_radius := pivot_circle.radius * maxf(
		pivot_scale.x,
		pivot_scale.y
	)
	var center_distance := circle_center.distance_to(pivot.global_position)
	return {
		&"depth": maxf(
			pivot_radius + circle_radius - center_distance,
			0.0
		),
		&"center_inside": center_distance < pivot_radius,
	}


func _get_axis_data(
	pivot: Vector2,
	polygon: PackedVector2Array
) -> Dictionary:
	if polygon.size() < 3:
		return {}
	var polygon_center := Vector2.ZERO
	for point: Vector2 in polygon:
		polygon_center += point
	polygon_center /= float(polygon.size())
	var axis := (polygon_center - pivot).normalized()
	if axis.is_zero_approx():
		return {}
	var tip_distance := 0.0
	for point: Vector2 in polygon:
		tip_distance = maxf(tip_distance, (point - pivot).dot(axis))
	if tip_distance <= 0.0:
		return {}
	return {
		&"axis": axis,
		&"tip_distance": tip_distance,
	}


func _get_ball_radius(ball: Pinball) -> float:
	var collision := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is CircleShape2D:
		return 0.0
	var circle := collision.shape as CircleShape2D
	var collision_scale := collision.global_scale.abs()
	return circle.radius * maxf(collision_scale.x, collision_scale.y)


func _configure_ball(ball: Pinball) -> void:
	ball.ball_diameter = BALL_DIAMETER
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_contact_zone_tunneling_matrix_test")
		quit(0)
		return
	print("FAIL: flipper_contact_zone_tunneling_matrix_test (%d failures)" \
		% _failures.size())
	quit(1)
