@tool
class_name ShotLaunchAnchor
extends Resource


## Inspector와 테스트 HUD에서 이 발사 방향을 구분할 이름입니다.
@export var display_name: String = "발사 방향":
	set(value):
		display_name = value
		emit_changed()
## 플레이어가 이 발사 방향을 선택할 때 사용하는 Input Map 액션입니다.
@export var input_action: StringName = &"flipper_select_up":
	set(value):
		input_action = value
		emit_changed()
## 입력이 없거나 선택 시간이 끝났을 때 자동으로 사용할 안전한 기본 방향입니다.
@export var is_safe_default := false:
	set(value):
		is_safe_default = value
		emit_changed()
## 범퍼 중심을 기준으로 공을 놓을 위치입니다. 이 좌표의 방향이 실제 발사 방향이 됩니다.
@export var release_position := Vector2(0.0, -82.0):
	set(value):
		release_position = value
		emit_changed()


func get_local_launch_direction() -> Vector2:
	if release_position.is_zero_approx():
		return Vector2.UP
	return release_position.normalized()


func get_local_release_position(default_distance: float) -> Vector2:
	if release_position.is_zero_approx():
		return Vector2.UP * default_distance
	return release_position
