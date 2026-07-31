extends Node2D


signal ball_reset_completed


@export_category("플리퍼 충돌 테스트")

## 활성화하면 씬에서 공을 배치한 위치를 R 복귀 위치로 사용합니다.
@export var use_authored_ball_position: bool = true

## R 키를 눌렀을 때 공이 돌아올 전역 좌표입니다.
@export var ball_reset_position: Vector2 = Vector2.ZERO

## 이 테스트 씬에서 재배치할 공 노드입니다.
@export_node_path("RigidBody2D") var ball_path: NodePath = ^"PinballBall"


@onready var ball: RigidBody2D = get_node_or_null(ball_path) as RigidBody2D


func _ready() -> void:
	if use_authored_ball_position and is_instance_valid(ball):
		ball_reset_position = ball.global_position


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if (
		key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_R
	):
		reset_ball()
		get_viewport().set_input_as_handled()


## 공을 테스트 시작점으로 순간 이동시키고 이전 물리 운동을 모두 제거합니다.
func reset_ball() -> void:
	if not is_instance_valid(ball):
		push_warning("Ball Path에 유효한 RigidBody2D 공을 지정해야 합니다.")
		return

	if ball.has_method(&"clear_temporary_maximum_speed"):
		ball.call(&"clear_temporary_maximum_speed")
	ball.freeze = true
	ball.global_position = ball_reset_position
	ball.rotation = 0.0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.reset_physics_interpolation()
	call_deferred(&"_finish_ball_reset")


func _finish_ball_reset() -> void:
	if not is_instance_valid(ball):
		return

	# 동결된 한 프레임 동안 물리 서버에도 위치와 정지 상태가 반영되게 합니다.
	ball.global_position = ball_reset_position
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.reset_physics_interpolation()
	ball.freeze = false
	ball_reset_completed.emit()
