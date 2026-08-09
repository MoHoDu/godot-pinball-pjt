class_name PinballLauncher
extends Node2D


signal ball_prepared(ball: Pinball)
signal aim_changed(angle_degrees: float)
signal power_changed(speed: float)
signal ball_launched(ball: Pinball, direction: Vector2, speed: float)


const DEFAULT_LAUNCH_RULES: PinballLaunchRules = preload(
	"res://settings/balls/PinballLaunchRules.tres"
)
const SPEED_EPSILON := 0.001
const PREVIEW_MAXIMUM_DURATION := 2.0
const PREVIEW_COLLISION_EPSILON := 0.001


@export_category("공 발사대")

@export_group("공 생성")

## 준비할 공이 전달되지 않았을 때 생성하는 공 씬입니다.
@export var ball_scene: PackedScene

## 생성한 공을 추가할 부모입니다. 비어 있거나 잘못되면 발사대의 부모를 사용합니다.
@export_node_path("Node") var spawn_parent_path: NodePath = ^".."


@export_group("보드별 발사 설정")

## 조준을 시작할 때 선택되는 기본 발사 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var default_launch_speed := 940.0

## 플레이어가 선택할 수 있는 발사 속력 하한입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var minimum_launch_speed := 320.0

## 플레이어가 선택할 수 있는 발사 속력 상한입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var maximum_launch_speed := 1540.0

## 발사대의 Rotation을 중심으로 선택할 수 있는 최소 상대 각도입니다.
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var minimum_launch_angle_degrees := -30.0

## 발사대의 Rotation을 중심으로 선택할 수 있는 최대 상대 각도입니다.
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var maximum_launch_angle_degrees := 30.0


@export_group("발사 궤적 가이드")

## 조준 중 실제 초기 비행을 짧은 점선으로 미리 표시합니다.
@export var show_trajectory_preview := true:
	set(value):
		show_trajectory_preview = value
		queue_redraw()

## 최저 발사 속력에서 보여줄 가이드의 월드 길이입니다.
@export_range(40.0, 1000.0, 10.0, "suffix:px")
var minimum_preview_length := 160.0:
	set(value):
		minimum_preview_length = maxf(value, 40.0)
		maximum_preview_length = maxf(
			maximum_preview_length,
			minimum_preview_length
		)
		queue_redraw()

## 최고 발사 속력에서 보여줄 가이드의 월드 길이입니다.
@export_range(40.0, 1600.0, 10.0, "suffix:px")
var maximum_preview_length := 480.0:
	set(value):
		maximum_preview_length = maxf(value, minimum_preview_length)
		queue_redraw()

## 점 사이의 간격입니다. 전체 경로를 정답처럼 보이지 않게 점선으로 표현합니다.
@export_range(12.0, 80.0, 1.0, "suffix:px")
var preview_marker_spacing := 32.0:
	set(value):
		preview_marker_spacing = maxf(value, 12.0)
		queue_redraw()

@export var preview_color := Color(0.45, 1.0, 0.9, 0.9):
	set(value):
		preview_color = value
		queue_redraw()


@export_group("공통 조작 규칙")

## 모든 보드가 공유하는 각도 및 파워 변경 속도입니다.
@export var launch_rules: PinballLaunchRules = DEFAULT_LAUNCH_RULES


@export_group("입력 액션")

@export var aim_left_action: StringName = &"ball_launch_aim_left"
@export var aim_right_action: StringName = &"ball_launch_aim_right"
@export var power_up_action: StringName = &"ball_launch_power_up"
@export var power_down_action: StringName = &"ball_launch_power_down"
@export var confirm_action: StringName = &"ball_launch_confirm"


var prepared_ball: Pinball = null
var is_aiming := false
var current_angle_degrees := 0.0
var current_launch_speed := 0.0


func _ready() -> void:
	_normalize_board_settings()
	_reset_selection()
	queue_redraw()


func _draw() -> void:
	if not show_trajectory_preview or not is_aiming:
		return

	var points := get_trajectory_preview_points()
	if points.size() < 2:
		return

	var marker_positions := _resample_trajectory_markers(points)
	var marker_count := marker_positions.size()
	for index: int in marker_count:
		var progress := float(index + 1) / float(marker_count + 1)
		var marker_position := to_local(marker_positions[index])
		var radius := lerpf(6.0, 2.5, progress)
		var alpha := lerpf(preview_color.a, preview_color.a * 0.2, progress)
		draw_circle(
			marker_position,
			radius + 2.0,
			Color(0.025, 0.055, 0.075, alpha * 0.7)
		)
		draw_circle(
			marker_position,
			radius,
			Color(preview_color.r, preview_color.g, preview_color.b, alpha)
		)


func _process(delta: float) -> void:
	if not is_aiming or launch_rules == null:
		return

	var aim_axis := Input.get_axis(aim_left_action, aim_right_action)
	if not is_zero_approx(aim_axis):
		set_current_angle(
			current_angle_degrees
			+ aim_axis * launch_rules.angle_adjustment_speed * delta
		)

	var power_axis := Input.get_axis(power_down_action, power_up_action)
	if not is_zero_approx(power_axis):
		set_current_launch_speed(
			current_launch_speed
			+ power_axis * launch_rules.power_adjustment_speed * delta
		)


func _input(event: InputEvent) -> void:
	if not is_aiming:
		return

	if event.is_action_pressed(confirm_action):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		launch_prepared_ball()
		get_viewport().set_input_as_handled()
		return

	for action: StringName in [
		aim_left_action,
		aim_right_action,
		power_up_action,
		power_down_action,
	]:
		if event.is_action_pressed(action) or event.is_action_released(action):
			# 같은 물리 키를 사용하는 플리퍼 선택은 조준 중에 실행하지 않습니다.
			get_viewport().set_input_as_handled()
			return


## 지정한 공을 발사대에 준비합니다. 공을 생략하면 ball_scene에서 생성합니다.
func prepare_ball(ball: Pinball = null) -> Pinball:
	var next_ball := ball if is_instance_valid(ball) else spawn_ball()
	if not is_instance_valid(next_ball):
		return null

	prepared_ball = next_ball
	if prepared_ball.has_method(&"clear_temporary_maximum_speed"):
		prepared_ball.clear_temporary_maximum_speed()
	prepared_ball.freeze = true
	_place_prepared_ball()
	_reset_selection()
	is_aiming = true
	ball_prepared.emit(prepared_ball)
	queue_redraw()
	return prepared_ball


## ball_scene의 루트가 Pinball일 때만 지정한 부모에 생성합니다.
func spawn_ball() -> Pinball:
	if ball_scene == null:
		push_warning("Ball Scene에 생성할 Pinball 씬을 지정해야 합니다.")
		return null

	var instance := ball_scene.instantiate()
	if not instance is Pinball:
		push_warning("Ball Scene의 루트는 Pinball이어야 합니다.")
		if instance != null:
			instance.free()
		return null

	var spawn_parent := get_node_or_null(spawn_parent_path)
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		(instance as Pinball).free()
		push_warning("생성한 공을 추가할 부모 노드가 필요합니다.")
		return null

	spawn_parent.add_child(instance)
	return instance as Pinball


## 준비된 공을 현재 선택 각도와 속력으로 한 번 발사합니다.
func launch_prepared_ball() -> bool:
	if not is_aiming or not is_instance_valid(prepared_ball):
		return false

	var ball := prepared_ball
	var direction := get_launch_direction()
	ball.freeze = false
	ball.sleeping = false

	if not ball.launch(direction, current_launch_speed):
		ball.freeze = true
		return false

	is_aiming = false
	prepared_ball = null
	ball_launched.emit(ball, direction, current_launch_speed)
	queue_redraw()
	return true


## 조준 중인 공을 발사하지 않고 취소합니다. 런처가 생성한 공은 필요하면 함께 제거합니다.
func cancel_prepared_ball(free_ball := false) -> Pinball:
	if not is_instance_valid(prepared_ball):
		return null
	var cancelled_ball := prepared_ball
	cancelled_ball.freeze = true
	is_aiming = false
	prepared_ball = null
	if free_ball:
		cancelled_ball.queue_free()
	queue_redraw()
	return cancelled_ball


## 발사대 위치에 준비된 공을 다시 고정하고 모든 운동을 제거합니다.
func replace_prepared_ball() -> bool:
	if not is_instance_valid(prepared_ball):
		return false
	prepared_ball.freeze = true
	_place_prepared_ball()
	queue_redraw()
	return true


func set_current_angle(value: float) -> void:
	var next_angle := clampf(
		value,
		minimum_launch_angle_degrees,
		maximum_launch_angle_degrees
	)
	if is_equal_approx(next_angle, current_angle_degrees):
		return
	current_angle_degrees = next_angle
	aim_changed.emit(current_angle_degrees)
	queue_redraw()


func set_current_launch_speed(value: float) -> void:
	var speed_range := get_effective_speed_range()
	var next_speed := clampf(value, speed_range.x, speed_range.y)
	if is_equal_approx(next_speed, current_launch_speed):
		return
	current_launch_speed = next_speed
	power_changed.emit(current_launch_speed)
	queue_redraw()


## 발사대의 Rotation과 현재 상대 각도를 반영한 월드 방향을 반환합니다.
func get_launch_direction() -> Vector2:
	return Vector2.RIGHT.rotated(
		global_rotation + deg_to_rad(current_angle_degrees)
	).normalized()


## 현재 파워에 맞춰 플레이어에게 보여줄 초기 궤적 길이를 반환합니다.
func get_trajectory_preview_length() -> float:
	var speed_range := get_effective_speed_range()
	if speed_range.is_equal_approx(Vector2(speed_range.x, speed_range.x)):
		return minimum_preview_length

	var power_ratio := inverse_lerp(
		speed_range.x,
		speed_range.y,
		current_launch_speed
	)
	return lerpf(minimum_preview_length, maximum_preview_length, power_ratio)


## 공의 실제 물리 주기와 현재 중력으로 적분한 초기 비행 경로입니다.
## 첫 충돌 이후의 정답 경로는 노출하지 않도록 충돌 직전에서 가이드를 끝냅니다.
func get_trajectory_preview_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if not is_aiming or not is_instance_valid(prepared_ball):
		return points

	var position := prepared_ball.global_position
	var velocity := get_launch_direction() * current_launch_speed
	var gravity := prepared_ball.get_gravity()
	var target_length := get_trajectory_preview_length()
	var traveled_length := 0.0
	var physics_step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	var maximum_steps := ceili(PREVIEW_MAXIMUM_DURATION / physics_step)
	points.append(position)

	for _step: int in maximum_steps:
		velocity += gravity * physics_step
		velocity = _apply_preview_linear_damping(
			velocity,
			physics_step
		)
		var next_position := position + velocity * physics_step
		var segment_length := position.distance_to(next_position)
		if segment_length <= PREVIEW_COLLISION_EPSILON:
			break

		var remaining_length := target_length - traveled_length
		if segment_length >= remaining_length:
			next_position = position.lerp(
				next_position,
				remaining_length / segment_length
			)

		var collision_fraction := _get_preview_collision_fraction(
			position,
			next_position
		)
		if collision_fraction < 1.0:
			points.append(position.lerp(next_position, collision_fraction))
			break

		points.append(next_position)
		traveled_length += position.distance_to(next_position)
		position = next_position
		if traveled_length + PREVIEW_COLLISION_EPSILON >= target_length:
			break

	return points


## 보드 발사 범위와 공의 실제 물리 속도 범위가 겹치는 구간을 반환합니다.
func get_effective_speed_range() -> Vector2:
	var board_minimum := minf(minimum_launch_speed, maximum_launch_speed)
	var board_maximum := maxf(minimum_launch_speed, maximum_launch_speed)
	if not is_instance_valid(prepared_ball):
		return Vector2(board_minimum, board_maximum)

	var ball_range := prepared_ball.physics_rules.get_effective_speed_range(
		prepared_ball.stats,
		prepared_ball.get_collision_diameter()
	)
	var effective_minimum := maxf(board_minimum, ball_range.x)
	var effective_maximum := minf(board_maximum, ball_range.y)

	if effective_maximum + SPEED_EPSILON >= effective_minimum:
		return Vector2(effective_minimum, effective_maximum)

	# 두 범위가 겹치지 않으면 공 자체 규칙에서 가장 가까운 한 점으로 고정합니다.
	var fallback := (
		ball_range.y
		if board_minimum > ball_range.y
		else ball_range.x
	)
	return Vector2(fallback, fallback)


func _place_prepared_ball() -> void:
	prepared_ball.global_position = global_position
	prepared_ball.rotation = 0.0
	prepared_ball.linear_velocity = Vector2.ZERO
	prepared_ball.angular_velocity = 0.0
	prepared_ball.reset_physics_interpolation()


func _apply_preview_linear_damping(
	velocity: Vector2,
	delta: float
) -> Vector2:
	if not is_instance_valid(prepared_ball):
		return velocity

	var damping := prepared_ball.linear_damp
	if prepared_ball.linear_damp_mode == RigidBody2D.DAMP_MODE_COMBINE:
		damping += float(ProjectSettings.get_setting(
			"physics/2d/default_linear_damp",
			0.1
		))
	return velocity * maxf(1.0 - damping * delta, 0.0)


func _get_preview_collision_fraction(
	from_position: Vector2,
	to_position: Vector2
) -> float:
	if not is_inside_tree() or not is_instance_valid(prepared_ball):
		return 1.0

	var collision := prepared_ball.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if collision == null or collision.shape == null or collision.disabled:
		return 1.0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin += from_position - prepared_ball.global_position
	query.motion = to_position - from_position
	query.collision_mask = prepared_ball.collision_mask
	query.exclude = [prepared_ball.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var motion_result := get_world_2d().direct_space_state.cast_motion(query)
	if motion_result.is_empty():
		return 1.0
	return clampf(motion_result[0], 0.0, 1.0)


func _resample_trajectory_markers(
	points: PackedVector2Array
) -> PackedVector2Array:
	var markers := PackedVector2Array()
	if points.size() < 2:
		return markers

	var distance_until_marker := preview_marker_spacing
	for index: int in range(1, points.size()):
		var segment_start := points[index - 1]
		var segment_end := points[index]
		var segment_length := segment_start.distance_to(segment_end)

		while segment_length + PREVIEW_COLLISION_EPSILON >= distance_until_marker:
			var ratio := distance_until_marker / segment_length
			var marker := segment_start.lerp(segment_end, ratio)
			markers.append(marker)
			segment_start = marker
			segment_length = segment_start.distance_to(segment_end)
			distance_until_marker = preview_marker_spacing

		distance_until_marker -= segment_length

	return markers


func _reset_selection() -> void:
	current_angle_degrees = clampf(
		0.0,
		minimum_launch_angle_degrees,
		maximum_launch_angle_degrees
	)
	var speed_range := get_effective_speed_range()
	current_launch_speed = clampf(
		default_launch_speed,
		speed_range.x,
		speed_range.y
	)
	aim_changed.emit(current_angle_degrees)
	power_changed.emit(current_launch_speed)


func _normalize_board_settings() -> void:
	if maximum_launch_speed < minimum_launch_speed:
		maximum_launch_speed = minimum_launch_speed
	if maximum_launch_angle_degrees < minimum_launch_angle_degrees:
		maximum_launch_angle_degrees = minimum_launch_angle_degrees
