extends SceneTree


const BASE_BALL_SCENE_PATH := "res://resources/balls/base/base_ball.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://resources/flippers/sub_flipper/normal_flipper_right.tscn"
const EPSILON := 1.0
const PERFECT_MAXIMUM_SPEED := 1700.0


var _failures: Array[String] = []
var _parry_signal_count := 0
var _deferred_observed_speed := -1.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var ball_scene := load(BASE_BALL_SCENE_PATH) as PackedScene
	var flipper_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(ball_scene != null, "실제 속도 제한을 검증할 Pinball 씬이 필요하다.")
	_expect(flipper_scene != null, "실제 속도 제한을 검증할 오른쪽 플리퍼 씬이 필요하다.")
	if ball_scene == null or flipper_scene == null:
		_finish()
		return

	var flipper := flipper_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	await process_frame

	var state_rules := FlipperStateRules.new()
	state_rules.activation_time = 0.01
	state_rules.hold_time = 0.01
	state_rules.return_time = 0.05
	flipper.initial_angle_degrees = -45.0
	flipper.maximum_angle_degrees = 45.0
	flipper.set_state_rules(state_rules)

	var parry_rules := FlipperParryRules.new()
	parry_rules.normal_parry_window_time = 2.0
	parry_rules.perfect_parry_window_time = 2.0
	parry_rules.normal_maximum_speed = 1540.0
	parry_rules.perfect_parry_maximum_speed = PERFECT_MAXIMUM_SPEED
	for zone_name: String in ["a", "b", "c", "d"]:
		parry_rules.set(StringName("zone_%s_speed_multiplier" % zone_name), 1.0)
		parry_rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			false
		)
	flipper.set_parry_rules(parry_rules)
	flipper.parry_resolved.connect(_on_parry_resolved)

	var ball := ball_scene.instantiate() as Pinball
	root.add_child(ball)
	await physics_frame
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 5000.0
	ball.stats.gravity_scale = 0.0
	ball.stats.elasticity = 1.0
	ball.global_position = flipper.global_position + Vector2(-400.0, 0.0)
	ball.linear_velocity = Vector2(0.0, 400.0)
	ball.sleeping = false

	_expect(flipper.request_activation(), \
		"실제 Pinball 충돌 테스트에서 플리퍼를 작동할 수 있어야 한다.")
	var maximum_observed_speed := 0.0
	for _physics_step: int in 5:
		await physics_frame
		maximum_observed_speed = maxf(
			maximum_observed_speed,
			ball.linear_velocity.length()
		)

	_expect(_parry_signal_count == 1, \
		"실제 Pinball과 플리퍼 충돌은 정확 패링을 한 번 발생시켜야 한다.")
	_expect(_deferred_observed_speed <= PERFECT_MAXIMUM_SPEED + EPSILON, \
		"패링 신호 직후 HUD가 관찰하는 linear_velocity도 정확 패링 상한을 넘으면 안 된다. " \
		+ "(limit=%.1f, observed=%.1f)" % [
			PERFECT_MAXIMUM_SPEED,
			_deferred_observed_speed,
		])
	_expect(maximum_observed_speed <= PERFECT_MAXIMUM_SPEED + EPSILON, \
		"Godot 기본 충돌까지 반영한 실제 linear_velocity가 정확 패링 상한을 넘으면 안 된다. " \
		+ "(limit=%.1f, observed=%.1f)" % [
			PERFECT_MAXIMUM_SPEED,
			maximum_observed_speed,
		])

	ball.queue_free()
	flipper.queue_free()
	await process_frame
	_finish()


func _on_parry_resolved(
	_ball: RigidBody2D,
	_grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_multiplier: float
) -> void:
	_parry_signal_count += 1
	call_deferred(&"_capture_deferred_speed", _ball)


func _capture_deferred_speed(ball: RigidBody2D) -> void:
	if is_instance_valid(ball):
		_deferred_observed_speed = ball.linear_velocity.length()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: pinball_flipper_velocity_limit_test")
		quit(0)
		return
	print("FAIL: pinball_flipper_velocity_limit_test (%d failures)" % _failures.size())
	quit(1)
