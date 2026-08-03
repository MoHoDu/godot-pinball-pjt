extends Node2D


signal ball_reset_completed
signal ball_launched


@export_category("사각 플리퍼 자유 테스트")

@export_node_path("RigidBody2D")
var ball_path: NodePath = ^"PinballBall"

@export_node_path("Node2D")
var launcher_path: NodePath = ^"PinballLauncher"


@onready var ball: Pinball = get_node_or_null(ball_path) as Pinball
@onready var launcher: PinballLauncher = get_node_or_null(
	launcher_path
) as PinballLauncher
@onready var guide_label: Label = get_node_or_null(
	"HUD/GuideLabel"
) as Label
@onready var status_label: Label = get_node_or_null(
	"HUD/StatusLabel"
) as Label


var _reset_version := 0
var _status_text := "Space로 공을 발사하세요"


func _ready() -> void:
	if is_instance_valid(launcher):
		launcher.ball_launched.connect(_on_launcher_ball_launched)
		launcher.prepare_ball(ball)
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode == KEY_R:
		reset_ball()
		get_viewport().set_input_as_handled()


## 떨어진 공을 오른쪽 아래 발사 위치로 되돌리고 모든 운동을 제거합니다.
func reset_ball() -> void:
	if not is_instance_valid(ball) or not is_instance_valid(launcher):
		push_warning("Ball Path와 Launcher Path에 유효한 노드를 지정해야 합니다.")
		return

	_reset_version += 1
	var reset_version := _reset_version
	launcher.prepare_ball(ball)
	_status_text = "리셋 완료 — Space로 다시 발사"
	_finish_ball_reset(reset_version)


func _finish_ball_reset(reset_version: int) -> void:
	await get_tree().physics_frame
	if reset_version != _reset_version or not is_instance_valid(ball):
		return

	launcher.replace_prepared_ball()
	# 발사형 테스트 보드이므로 Space 입력 전까지 공을 발사대에 고정합니다.
	ball.freeze = true
	ball_reset_completed.emit()


## 테스트와 외부 게임 흐름에서 현재 선택값으로 발사를 요청하는 진입점입니다.
func launch_ball() -> bool:
	if not is_instance_valid(launcher):
		return false
	return launcher.launch_prepared_ball()


func _on_launcher_ball_launched(
	launched_ball: Pinball,
	_direction: Vector2,
	_speed: float
) -> void:
	if launched_ball != ball:
		return
	_reset_version += 1
	_status_text = "발사! 방향키/WASD 선택 · Space 작동"
	ball_launched.emit()


func _refresh_hud() -> void:
	if is_instance_valid(guide_label):
		if is_instance_valid(launcher) and launcher.is_aiming:
			guide_label.text = (
				"[공 발사 조준]\n"
				+ "좌우/A·D: 각도   상하/W·S: 파워\n"
				+ "Space: 공 발사   R: 공·조준 리셋"
			)
		else:
			guide_label.text = (
				"[사각 플리퍼 자유 테스트]\n"
				+ "방향키/WASD: 플리퍼 선택   Space: 작동\n"
				+ "R: 공·조준 리셋"
			)
	if is_instance_valid(status_label):
		var speed := ball.linear_velocity.length() if is_instance_valid(ball) else 0.0
		if is_instance_valid(launcher) and launcher.is_aiming:
			status_label.text = "%s\n각도: %.1f°   발사 속력: %.1f px/s" % [
				_status_text,
				launcher.current_angle_degrees,
				launcher.current_launch_speed,
			]
		else:
			status_label.text = "%s\n현재 공 속력: %.1f px/s" % [
				_status_text,
				speed,
			]
