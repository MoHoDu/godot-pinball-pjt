extends Node2D


signal ball_reset_completed
signal ball_launched


@export_category("사각 플리퍼 자유 테스트")

@export_node_path("RigidBody2D")
var ball_path: NodePath = ^"PinballBall"

@export var launcher_position := Vector2(0.0, 400.0)
@export var launcher_direction := Vector2(-0.65, -1.0)


@onready var ball: RigidBody2D = get_node_or_null(ball_path) as RigidBody2D
@onready var guide_label: Label = get_node_or_null(
	"HUD/GuideLabel"
) as Label
@onready var status_label: Label = get_node_or_null(
	"HUD/StatusLabel"
) as Label


var _reset_version := 0
var _status_text := "Enter로 공을 발사하세요"


func _ready() -> void:
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_R:
			reset_ball()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			launch_ball()
			get_viewport().set_input_as_handled()


## 떨어진 공을 오른쪽 아래 발사 위치로 되돌리고 모든 운동을 제거합니다.
func reset_ball() -> void:
	if not is_instance_valid(ball):
		push_warning("Ball Path에 유효한 RigidBody2D 공을 지정해야 합니다.")
		return

	_reset_version += 1
	var reset_version := _reset_version
	if ball.has_method(&"clear_temporary_maximum_speed"):
		ball.call(&"clear_temporary_maximum_speed")
	ball.freeze = true
	_place_ball_at_launcher()
	_status_text = "리셋 완료 — Enter로 다시 발사"
	_finish_ball_reset(reset_version)


func _finish_ball_reset(reset_version: int) -> void:
	await get_tree().physics_frame
	if reset_version != _reset_version or not is_instance_valid(ball):
		return

	_place_ball_at_launcher()
	# 발사형 테스트 보드이므로 Enter 입력 전까지 공을 발사대에 고정합니다.
	ball.freeze = true
	ball_reset_completed.emit()


## 기획 기준 초기 속력은 공 Stats(940px/s)가 담당하고 여기서는 방향만 제공합니다.
func launch_ball() -> bool:
	if not is_instance_valid(ball) or launcher_direction.is_zero_approx():
		return false

	_reset_version += 1
	if ball.has_method(&"clear_temporary_maximum_speed"):
		ball.call(&"clear_temporary_maximum_speed")
	ball.freeze = false
	_place_ball_at_launcher()
	ball.sleeping = false

	var launched := false
	if ball.has_method(&"launch"):
		launched = bool(ball.call(&"launch", launcher_direction))
	else:
		ball.linear_velocity = launcher_direction.normalized() * 940.0
		launched = true

	if launched:
		_status_text = "발사! 방향키/WASD 선택 · Space 작동"
		ball_launched.emit()
	return launched


func _place_ball_at_launcher() -> void:
	ball.global_position = launcher_position
	ball.rotation = 0.0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.reset_physics_interpolation()


func _refresh_hud() -> void:
	if is_instance_valid(guide_label):
		guide_label.text = (
			"[사각 플리퍼 자유 테스트]\n"
			+ "방향키/WASD: 플리퍼 선택   Space: 작동\n"
			+ "Enter: 공 발사   R: 공·속도 리셋"
		)
	if is_instance_valid(status_label):
		var speed := ball.linear_velocity.length() if is_instance_valid(ball) else 0.0
		status_label.text = "%s\n현재 공 속력: %.1f px/s" % [
			_status_text,
			speed,
		]
