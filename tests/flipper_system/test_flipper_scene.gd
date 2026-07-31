extends Node2D


@export_category("플리퍼 충돌 테스트")

## R 키를 눌렀을 때 공이 돌아올 전역 좌표입니다.
@export var ball_reset_position: Vector2 = Vector2.ZERO

## 이 테스트 씬에서 재배치할 공 노드입니다.
@export_node_path("RigidBody2D") var ball_path: NodePath = ^"PinballBall"


@onready var ball: RigidBody2D = get_node_or_null(ball_path) as RigidBody2D


func _unhandled_key_input(event: InputEvent) -> void:
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

	ball.freeze = true
	ball.global_position = ball_reset_position
	ball.rotation = 0.0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.reset_physics_interpolation()
	ball.freeze = false
