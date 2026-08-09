extends SceneTree


const WAVE_SCENE_PATH := "res://Resources/Prefabs/wave/base/wave.tscn"
const NORMAL_BALL_SCENE_PATH := \
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
const TEST_SPEED := 1540.0
const TEST_BALL_DIAMETER := 94.0
const START_CLEARANCE := 100.0
const TEST_PHYSICS_FRAMES := 16


var _failures: Array[String] = []
var _target_wall: StaticBody2D
var _wall_contact_detected := false
var _drain_contact_detected := false
var _inward_reflection_detected := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var wave_scene := load(WAVE_SCENE_PATH) as PackedScene
	var ball_scene := load(NORMAL_BALL_SCENE_PATH) as PackedScene
	_expect(wave_scene != null, "상단 벽 회귀 테스트에 실제 웨이브 씬이 필요하다.")
	_expect(ball_scene != null, "상단 벽 회귀 테스트에 일반 공 씬이 필요하다.")
	if wave_scene == null or ball_scene == null:
		_finish()
		return

	var wave := wave_scene.instantiate() as WaveRuntimeCoordinator
	root.add_child(wave)
	await process_frame
	await physics_frame

	_target_wall = wave.get_node(
		^"Walls/Top/TopRigthVertical"
	) as StaticBody2D
	var wall_collision := _target_wall.get_node(
		^"CollisionShape2D"
	) as CollisionShape2D
	var drain_area := wave.get_node(^"BallDrainArea") as Area2D
	_expect(_target_wall != null and wall_collision != null,
		"실제 웨이브의 상단 오른쪽 세로 벽이 필요하다.")
	_expect(drain_area != null, "실제 웨이브의 낙하 영역이 필요하다.")
	if _target_wall == null or wall_collision == null or drain_area == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	var ball := ball_scene.instantiate() as Pinball
	ball.freeze = true
	wave.add_child(ball)
	await physics_frame
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = TEST_SPEED
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.ball_diameter = TEST_BALL_DIAMETER

	var circle_collision := ball.get_node(^"CollisionShape2D") as CollisionShape2D
	var circle := circle_collision.shape as CircleShape2D
	var ball_radius := circle.radius * circle_collision.global_scale.abs().x
	var rectangle := wall_collision.shape as RectangleShape2D
	var half_thickness := rectangle.size.y \
		* wall_collision.global_scale.abs().y * 0.5
	var inward_normal := wall_collision.global_transform \
		.basis_xform(Vector2.DOWN).normalized()
	var direction_to_board_center := (
		wave.global_position - wall_collision.global_position
	).normalized()
	if inward_normal.dot(direction_to_board_center) < 0.0:
		inward_normal = -inward_normal

	ball.global_position = wall_collision.global_position \
		+ inward_normal * (half_thickness + ball_radius + START_CLEARANCE)
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	ball.body_entered.connect(_on_ball_body_entered)
	drain_area.body_entered.connect(_on_drain_body_entered.bind(ball))
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = -inward_normal * TEST_SPEED
	ball.sleeping = false

	for _frame in TEST_PHYSICS_FRAMES:
		await physics_frame
		if _wall_contact_detected \
				and ball.linear_velocity.dot(inward_normal) > 0.0:
			_inward_reflection_detected = true

	_expect(_wall_contact_detected,
		"최대 속도 공은 실제 상단 벽과 충돌해야 한다.")
	_expect(not _drain_contact_detected,
		"상단 벽에 반사되는 공이 겹친 낙하 영역에 먼저 잡히면 안 된다.")
	_expect(_inward_reflection_detected,
		"상단 벽 충돌 뒤 공은 보드 안쪽으로 반사되어야 한다. " \
		+ "(velocity=%s)" % ball.linear_velocity)

	ball.queue_free()
	wave.queue_free()
	await process_frame
	await process_frame
	_finish()


func _on_ball_body_entered(body: Node) -> void:
	if body == _target_wall:
		_wall_contact_detected = true


func _on_drain_body_entered(body: Node, ball: Pinball) -> void:
	if body == ball:
		_drain_contact_detected = true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_top_wall_drain_regression_test")
		quit(0)
		return
	print("FAIL: pinball_top_wall_drain_regression_test (%d failures)" \
		% _failures.size())
	quit(1)
