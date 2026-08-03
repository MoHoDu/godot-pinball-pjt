extends SceneTree


const BASE_BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_right.tscn"
const START_ROTATION := -PI / 12.0
const END_ROTATION := PI / 6.0
const PHYSICS_DELTA := 1.0 / 60.0
const BALL_RADIUS := 57.6
const PERFECT_MAXIMUM_SPEED := 1700.0


var _failures: Array[String] = []
var _parry_signal_count := 0
var _sweep_signal_count := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	var flipper_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "회귀 테스트에 실제 Pinball 씬이 필요하다.")
	_expect(flipper_scene != null, "회귀 테스트에 실제 오른쪽 플리퍼 씬이 필요하다.")
	if ball_scene == null or flipper_scene == null:
		_finish()
		return

	var flipper := flipper_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	await process_frame
	_configure_perfect_parry(flipper)
	flipper.parry_resolved.connect(_on_parry_resolved)
	flipper.rotation_sweep_resolved.connect(_on_sweep_resolved)

	await _test_initial_overlap_is_owned_by_activation_sweep(
		flipper,
		ball_scene
	)
	await _test_tip_hit_uses_approaching_impact_normal(
		flipper,
		ball_scene
	)
	await _test_activation_owns_adjacent_frame_contact(
		flipper,
		ball_scene
	)

	flipper.queue_free()
	await process_frame
	_finish()


func _test_initial_overlap_is_owned_by_activation_sweep(
	flipper: PinballFlipper,
	ball_scene: PackedScene
) -> void:
	var ball := await _create_test_ball(
		ball_scene,
		flipper.global_position + Vector2(-50.0, -50.0)
	)
	_expect(flipper.is_circle_overlapping_at_rotation(
		ball.global_position,
		BALL_RADIUS,
		START_ROTATION
	), "첫 작동 프레임 회귀 공은 플리퍼 시작 자세에 닿아 있어야 한다.")

	_reset_signal_counts()
	var resolved_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		PHYSICS_DELTA,
		0.0
	)
	await physics_frame

	_expect(resolved_count == 1, \
		"작동 시작 자세에 이미 닿은 공도 첫 회전 충돌이 소유해야 한다.")
	_expect(_sweep_signal_count == 1 and _parry_signal_count == 1, \
		"첫 자세 접촉도 회전 충돌과 패링 결과를 각각 한 번 알려야 한다.")
	_expect(ball.linear_velocity.length() <= PERFECT_MAXIMUM_SPEED + 1.0, \
		"첫 자세 접촉의 실제 속력이 정확 패링 상한을 넘으면 안 된다. " \
		+ "(actual=%.1f)" % ball.linear_velocity.length())

	ball.queue_free()
	await process_frame


func _test_tip_hit_uses_approaching_impact_normal(
	flipper: PinballFlipper,
	ball_scene: PackedScene
) -> void:
	var ball_center := flipper.global_position + Vector2(-560.0, -90.0)
	var hit := flipper.find_rotation_sweep_hit(
		ball_center,
		BALL_RADIUS,
		START_ROTATION,
		END_ROTATION
	)
	_expect(not hit.is_empty(), \
		"끝부분 회귀 공은 플리퍼 회전 궤도 안에서 감지되어야 한다.")
	if hit.is_empty():
		return
	_expect(float(hit.get(&"contact_percent", 0.0)) >= 90.0, \
		"끝부분 회귀 공은 D 구역에서 충돌해야 한다.")

	var ball := await _create_test_ball(ball_scene, ball_center)
	_reset_signal_counts()
	var resolved_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		PHYSICS_DELTA,
		0.0
	)
	await physics_frame

	_expect(resolved_count == 1, \
		"플리퍼 끝부분의 회전 충돌을 한 번 해결해야 한다.")
	_expect(_parry_signal_count == 1, \
		"끝부분 정확 패링 결과는 한 번만 발생해야 한다.")
	_expect(ball.linear_velocity.y < 0.0, \
		"위로 움직이는 플리퍼 끝의 PERFECT 타격은 공을 아래로 통과시키면 안 된다. " \
		+ "(velocity=%s)" % ball.linear_velocity)
	_expect(ball.linear_velocity.length() <= PERFECT_MAXIMUM_SPEED + 1.0, \
		"끝부분 정확 패링의 실제 속력이 상한을 넘으면 안 된다. " \
		+ "(actual=%.1f)" % ball.linear_velocity.length())

	ball.queue_free()
	await process_frame


func _test_activation_owns_adjacent_frame_contact(
	flipper: PinballFlipper,
	ball_scene: PackedScene
) -> void:
	var contact_position := flipper.global_position + Vector2(-560.0, -90.0)
	var ball := await _create_test_ball(ball_scene, contact_position)
	flipper.set_physics_process(false)
	_expect(flipper.request_activation(), \
		"인접 프레임 중복 검사 전에 플리퍼가 새 작동 토큰을 받아야 한다.")

	_reset_signal_counts()
	var first_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		PHYSICS_DELTA,
		0.0
	)
	await physics_frame

	# 첫 임펄스 이후에도 같은 접촉 조건을 다시 만들어 다음 물리 프레임 중복을 검증합니다.
	ball.global_position = contact_position
	ball.linear_velocity = Vector2(0.0, 600.0)
	ball.sleeping = false
	ball.reset_physics_interpolation()
	var second_count := flipper.resolve_rotation_sweep(
		START_ROTATION,
		END_ROTATION,
		PHYSICS_DELTA,
		PHYSICS_DELTA
	)

	_expect(first_count == 1, \
		"한 작동의 첫 회전 충돌은 정상적으로 해결해야 한다.")
	_expect(second_count == 1, \
		"같은 작동의 후속 접촉도 물리 보정과 속도 제한은 다시 적용해야 한다.")
	_expect(_parry_signal_count == 1, \
		"같은 작동의 인접 프레임 패링 피드백 신호는 한 번만 발생해야 한다.")

	ball.queue_free()
	await process_frame


func _create_test_ball(
	ball_scene: PackedScene,
	position: Vector2
) -> Pinball:
	var ball := ball_scene.instantiate() as Pinball
	ball.ball_diameter = 128.0
	root.add_child(ball)
	await physics_frame
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.global_position = position
	ball.linear_velocity = Vector2(0.0, 600.0)
	ball.sleeping = false
	ball.reset_physics_interpolation()
	return ball


func _configure_perfect_parry(flipper: PinballFlipper) -> void:
	var rules := FlipperParryRules.new()
	rules.normal_parry_window_time = 2.0
	rules.perfect_parry_window_time = 2.0
	rules.normal_maximum_speed = 1540.0
	rules.perfect_parry_maximum_speed = PERFECT_MAXIMUM_SPEED
	for zone_name: String in ["a", "b", "c", "d"]:
		rules.set(StringName("zone_%s_speed_multiplier" % zone_name), 1.0)
		rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			false
		)
	flipper.contact_zone_a_speed_multiplier = 1.0
	flipper.contact_zone_b_speed_multiplier = 1.0
	flipper.contact_zone_c_speed_multiplier = 1.0
	flipper.contact_zone_d_speed_multiplier = 1.0
	flipper.set_parry_rules(rules)


func _reset_signal_counts() -> void:
	_parry_signal_count = 0
	_sweep_signal_count = 0


func _on_parry_resolved(
	_ball: RigidBody2D,
	_grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_multiplier: float
) -> void:
	_parry_signal_count += 1


func _on_sweep_resolved(_ball: RigidBody2D) -> void:
	_sweep_signal_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_sweep_contact_regression_test")
		quit(0)
		return
	print("FAIL: flipper_sweep_contact_regression_test (%d failures)" % _failures.size())
	quit(1)
