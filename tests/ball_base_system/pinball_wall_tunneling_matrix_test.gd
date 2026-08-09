extends SceneTree


const WAVE_SCENE_PATH := \
	"res://scenes/game/stages/stage_01/waves/stage_01_wave_01.tscn"
const NORMAL_BALL_SCENE_PATH := \
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
const DEAD_BALL_SCENE_PATH := \
	"res://Resources/Prefabs/balls/variants/elastic/dead_ball.tscn"
const GEL_BALL_SCENE_PATH := \
	"res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn"
const BALL_CASES: Array[Dictionary] = [
	{
		&"name": &"dead_ball",
		&"scene_path": DEAD_BALL_SCENE_PATH,
		&"diameter": 34.0,
		&"authored_maximum_speed": 3000.0,
		&"configured_maximum_speed": 5000.0,
		&"expected_effective_maximum_speed": 3000.0,
		&"test_speed": 3000.0,
	},
	{
		&"name": &"gel_ball",
		&"scene_path": GEL_BALL_SCENE_PATH,
		&"diameter": 34.0,
		&"authored_maximum_speed": 3000.0,
		&"configured_maximum_speed": 5000.0,
		&"expected_effective_maximum_speed": 3000.0,
		&"test_speed": 3000.0,
	},
	{
		&"name": &"normal_ball",
		&"scene_path": NORMAL_BALL_SCENE_PATH,
		&"diameter": 64.0,
		&"authored_maximum_speed": 5000.0,
		&"configured_maximum_speed": 5000.0,
		&"expected_effective_maximum_speed": 5000.0,
		&"test_speed": 5000.0,
	},
]
const WALL_PATHS: Array[NodePath] = [
	^"Walls/Top/TopRightDiagonal",
	^"Walls/Top/TopLeftDiagonal",
	^"Walls/Top/TopRigthVertical",
	^"Walls/Top/TopLeftVertical",
	^"Walls/Top/TopLeftSide",
	^"Walls/Top/TopRightSide",
	^"Walls/Bottom/BottomRightDiagonal",
	^"Walls/Bottom/BottomLeftDiagonal",
	^"Walls/Bottom/BottomRightVertical",
	^"Walls/Bottom/BottomLeftVertical",
	^"Walls/Bottom/BottomLeftSide",
	^"Walls/Bottom/BottomRightSide",
]
const SAMPLE_LABELS := [&"inner_start", &"center", &"inner_end"]
const START_CLEARANCE := 1.0
const PASS_TOLERANCE := 1.0
const OBSERVATION_FRAMES := 3


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(Engine.physics_ticks_per_second >= 120,
		"최대 속도 공을 얇은 벽에서 안정적으로 검사하려면 물리 주기가 120Hz 이상이어야 한다.")
	var wave_scene := load(WAVE_SCENE_PATH) as PackedScene
	_expect(wave_scene != null and wave_scene.can_instantiate(), \
		"Stage 01 Wave 01 실제 씬을 불러올 수 있어야 한다.")
	if wave_scene == null:
		_finish()
		return

	var wave := wave_scene.instantiate() as Node2D
	root.add_child(wave)
	await process_frame
	await physics_frame

	var walls := _get_authored_walls(wave)
	_expect(walls.size() == WALL_PATHS.size(), \
		"Stage 01 Wave 01의 실제 외곽 벽 12개가 모두 필요하다. (actual=%d)" \
			% walls.size())
	if walls.size() != WALL_PATHS.size():
		wave.queue_free()
		await process_frame
		_finish()
		return

	# 배수구를 막거나 외곽 구조를 바꾸지 않고 실제 벽을 단독/조립 상태로 검증합니다.
	# 범퍼·플리퍼·Drain Area가 이탈 공을 대신 막거나 제거해 거짓 통과를 만들지 않게 합니다.
	_isolate_authored_walls(wave, walls)
	await physics_frame
	_test_drain_corridors_remain_open(wave)

	for ball_case: Dictionary in BALL_CASES:
		var ball_scene := load(String(ball_case[&"scene_path"])) as PackedScene
		_expect(ball_scene != null and ball_scene.can_instantiate(), \
			"고속 벽 검증에 실제 %s 씬이 필요하다." % ball_case[&"name"])
		if ball_scene == null:
			continue
		await _run_ball_matrix(wave, walls, ball_scene, ball_case)

	wave.queue_free()
	await process_frame
	_finish()


func _run_ball_matrix(
	wave: Node2D,
	walls: Array[StaticBody2D],
	ball_scene: PackedScene,
	ball_case: Dictionary
) -> void:
	var ball_name := StringName(ball_case[&"name"])
	var ball_diameter := float(ball_case[&"diameter"])
	var authored_maximum_speed := float(
		ball_case[&"authored_maximum_speed"]
	)
	var configured_maximum_speed := float(
		ball_case[&"configured_maximum_speed"]
	)
	var expected_effective_maximum_speed := float(
		ball_case[&"expected_effective_maximum_speed"]
	)
	var test_speed := float(ball_case[&"test_speed"])
	var probe_ball := ball_scene.instantiate() as Pinball
	probe_ball.freeze = true
	probe_ball.global_position = Vector2(10000.0, 10000.0)
	root.add_child(probe_ball)
	await physics_frame
	_configure_ball(
		probe_ball,
		ball_diameter,
		authored_maximum_speed,
		configured_maximum_speed,
		expected_effective_maximum_speed
	)
	var ball_radius := _get_ball_radius(probe_ball)
	probe_ball.queue_free()
	await process_frame

	for wall: StaticBody2D in walls:
		_activate_only_wall(walls, wall)
		await physics_frame
		var collision := wall.get_node_or_null(^"CollisionShape2D") \
			as CollisionShape2D
		_expect(wall.scale.is_equal_approx(Vector2.ONE), \
			"%s 물리 벽은 Scale 대신 실제 Shape 크기를 사용해야 한다." % wall.name)
		_expect(collision != null and collision.shape is RectangleShape2D, \
			"%s는 실제 RectangleShape2D 벽 충돌체여야 한다." % wall.name)
		if collision == null or not collision.shape is RectangleShape2D:
			continue
		var visual := wall.get_node_or_null(^"Visual") as Node2D
		var rectangle := collision.shape as RectangleShape2D
		var original_thickness := 24.0 * (
			absf(visual.scale.y) if visual != null else 1.0
		)
		var local_y_points_inward := collision.global_transform.y.normalized().dot(
			(wave.global_position - wall.global_position).normalized()
		) >= 0.0
		var inward_sign := 1.0 if local_y_points_inward else -1.0
		var expected_inner_face := original_thickness \
			if local_y_points_inward else 0.0
		_expect(is_equal_approx(
			collision.position.y + inward_sign * rectangle.size.y * 0.5,
			expected_inner_face
		), "%s의 안쪽 충돌 면은 Scale 정규화 전 위치를 유지해야 한다." % wall.name)

		var geometry := _get_wall_geometry(wave, collision, ball_radius)
		_expect(not geometry.is_empty(), \
			"%s의 실제 벽 기하를 계산할 수 있어야 한다." % wall.name)
		if geometry.is_empty():
			continue

		var along_distance := float(geometry[&"near_end_distance"])
		var sample_offsets := [-along_distance, 0.0, along_distance]
		for sample_index in sample_offsets.size():
			await _run_wall_case(
				ball_scene,
				wall,
				geometry,
				float(sample_offsets[sample_index]),
				StringName("%s/isolated/%s" % [
					ball_name,
					SAMPLE_LABELS[sample_index],
				]),
				ball_diameter,
				authored_maximum_speed,
				configured_maximum_speed,
				expected_effective_maximum_speed,
				test_speed
			)

		_activate_all_walls(walls)
		await physics_frame
		for sample_index in sample_offsets.size():
			await _run_wall_case(
				ball_scene,
				wall,
				geometry,
				float(sample_offsets[sample_index]),
				StringName("%s/assembled/%s" % [
					ball_name,
					SAMPLE_LABELS[sample_index],
				]),
				ball_diameter,
				authored_maximum_speed,
				configured_maximum_speed,
				expected_effective_maximum_speed,
				test_speed
			)


func _get_authored_walls(wave: Node) -> Array[StaticBody2D]:
	var walls: Array[StaticBody2D] = []
	for wall_path: NodePath in WALL_PATHS:
		var wall := wave.get_node_or_null(wall_path) as StaticBody2D
		_expect(wall != null, "실제 벽 노드 %s가 유지되어야 한다." % wall_path)
		if wall != null:
			walls.append(wall)
	return walls


func _test_drain_corridors_remain_open(wave: Node2D) -> void:
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var query := PhysicsRayQueryParameters2D.create(
			wave.global_position,
			wave.global_position + direction * 2000.0,
			1
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := wave.get_world_2d().direct_space_state.intersect_ray(query)
		_expect(hit.is_empty(),
			"상·하·좌·우 정상 배수구의 중앙 통로는 벽 보강 뒤에도 열려 있어야 한다. " \
			+ "(direction=%s, collider=%s)" % [
				direction,
				hit.get(&"collider", null),
			])


func _isolate_authored_walls(
	wave: Node,
	walls: Array[StaticBody2D]
) -> void:
	var allowed_ids: Dictionary = {}
	for wall: StaticBody2D in walls:
		allowed_ids[wall.get_instance_id()] = true

	var pending: Array[Node] = [wave]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		if not node is CollisionObject2D:
			continue
		var collision_object := node as CollisionObject2D
		if allowed_ids.has(collision_object.get_instance_id()):
			continue
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		if collision_object is Area2D:
			(collision_object as Area2D).monitoring = false
			(collision_object as Area2D).monitorable = false


func _activate_only_wall(
	walls: Array[StaticBody2D],
	target_wall: StaticBody2D
) -> void:
	for wall: StaticBody2D in walls:
		wall.collision_layer = 1 if wall == target_wall else 0
		wall.collision_mask = 1 if wall == target_wall else 0


func _activate_all_walls(walls: Array[StaticBody2D]) -> void:
	for wall: StaticBody2D in walls:
		wall.collision_layer = 1
		wall.collision_mask = 1


func _get_wall_geometry(
	wave: Node2D,
	collision: CollisionShape2D,
	ball_radius: float
) -> Dictionary:
	var rectangle := collision.shape as RectangleShape2D
	var length_vector := collision.global_transform.x * rectangle.size.x
	var thickness_vector := collision.global_transform.y * rectangle.size.y
	var wall_length := length_vector.length()
	var wall_thickness := thickness_vector.length()
	var along_axis := length_vector.normalized()
	var normal_axis := thickness_vector.normalized()
	if wall_length <= 0.0 or wall_thickness <= 0.0 \
			or along_axis.is_zero_approx() or normal_axis.is_zero_approx():
		return {}

	var wall := collision.get_parent() as StaticBody2D
	var direction_to_board_center := (
		wave.global_position - wall.global_position
	).normalized()
	var inward_normal := normal_axis
	if inward_normal.dot(direction_to_board_center) < 0.0:
		inward_normal = -inward_normal
	var outward_normal := -inward_normal

	var collision_limit := wall_thickness * 0.5 + ball_radius
	var near_end_distance := wall_length * 0.1
	return {
		&"center": collision.global_position,
		&"along_axis": along_axis,
		&"outward_normal": outward_normal,
		&"collision_limit": collision_limit,
		&"near_end_distance": near_end_distance,
	}


func _run_wall_case(
	ball_scene: PackedScene,
	wall: StaticBody2D,
	geometry: Dictionary,
	along_offset: float,
	sample_label: StringName,
	ball_diameter: float,
	authored_maximum_speed: float,
	configured_maximum_speed: float,
	expected_effective_maximum_speed: float,
	test_speed: float
) -> void:
	var ball := ball_scene.instantiate() as Pinball
	ball.freeze = true
	ball.global_position = Vector2(10000.0, 10000.0)
	root.add_child(ball)
	await physics_frame
	_configure_ball(
		ball,
		ball_diameter,
		authored_maximum_speed,
		configured_maximum_speed,
		expected_effective_maximum_speed
	)
	var center: Vector2 = geometry[&"center"]
	var along_axis: Vector2 = geometry[&"along_axis"]
	var outward_normal: Vector2 = geometry[&"outward_normal"]
	var collision_limit := float(geometry[&"collision_limit"])
	var target_center := center + along_axis * along_offset

	ball.freeze = true
	ball.sleeping = false
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.global_position = target_center \
		- outward_normal * (collision_limit + START_CLEARANCE)
	ball.reset_physics_interpolation()
	await physics_frame

	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = outward_normal * test_speed

	var fully_crossed := false
	var maximum_outward_projection := -INF
	for _frame in OBSERVATION_FRAMES:
		await physics_frame
		if not is_instance_valid(ball):
			fully_crossed = true
			break
		var outward_projection := (
			ball.global_position - target_center
		).dot(outward_normal)
		maximum_outward_projection = maxf(
			maximum_outward_projection,
			outward_projection
		)
		if outward_projection > collision_limit + PASS_TOLERANCE:
			fully_crossed = true
			break

	_expect(not fully_crossed, (\
		"%s/%s에서 공이 %.0fpx/s로 실제 벽 외측을 완전히 통과하면 안 된다. " \
		+ "(limit=%.2f, max_projection=%.2f, position=%s, velocity=%s)"\
	) % [
		wall.name,
		sample_label,
		test_speed,
		collision_limit,
			maximum_outward_projection,
			ball.global_position if is_instance_valid(ball) else Vector2(INF, INF),
			ball.linear_velocity if is_instance_valid(ball) else Vector2(INF, INF),
		])
	if is_instance_valid(ball):
		ball.queue_free()
	await process_frame


func _configure_ball(
	ball: Pinball,
	expected_diameter: float,
	expected_authored_maximum_speed: float,
	configured_maximum_speed: float,
	expected_effective_maximum_speed: float
) -> void:
	ball.stats = ball.stats.duplicate(true) as PinballStats
	_expect(is_equal_approx(ball.ball_diameter, expected_diameter), \
		"%s 지름은 %.0fpx여야 한다." % [ball.name, expected_diameter])
	_expect(is_equal_approx(
		ball.stats.maximum_speed,
		expected_authored_maximum_speed
	), "%s 씬 최대 속력은 %.0fpx/s여야 한다." % [
		ball.name,
		expected_authored_maximum_speed,
	])
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = configured_maximum_speed
	_expect(is_equal_approx(
		ball.stats.maximum_speed,
		expected_effective_maximum_speed
	), "%s에 %.0fpx/s를 입력해도 안전 상한 %.0fpx/s로 즉시 보정되어야 한다." % [
		ball.name,
		configured_maximum_speed,
		expected_effective_maximum_speed,
	])
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.0


func _get_ball_radius(ball: Pinball) -> float:
	var collision := ball.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is CircleShape2D:
		return 0.0
	var circle := collision.shape as CircleShape2D
	var collision_scale := collision.global_scale.abs()
	return circle.radius * maxf(collision_scale.x, collision_scale.y)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_wall_tunneling_matrix_test")
		quit(0)
		return
	print("FAIL: pinball_wall_tunneling_matrix_test (%d failures)" \
		% _failures.size())
	quit(1)
