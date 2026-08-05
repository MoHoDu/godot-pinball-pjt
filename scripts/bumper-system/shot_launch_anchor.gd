@tool
class_name ShotLaunchAnchor
extends Marker2D


## 플레이어가 이 발사 방향을 선택할 때 사용하는 Input Map 액션입니다.
@export var input_action: StringName = &"flipper_select_up"
## 입력이 없거나 선택 시간이 끝났을 때 자동으로 사용할 안전한 기본 방향입니다.
@export var is_safe_default := false:
	set(value):
		is_safe_default = value
		queue_redraw()
## 범퍼 중심을 기준으로 공을 놓을 위치입니다. 값을 바꾸거나 2D 화면에서 마커를 드래그하면 발사 방향도 함께 정해집니다. (0, 0)이면 마커 회전을 사용합니다.
@export var release_position: Vector2:
	get:
		return position
	set(value):
		position = value
		queue_redraw()


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	var bumper := get_parent().get_parent() as ShotBumper if get_parent() != null else null
	if bumper != null:
		bumper.queue_redraw()


func get_local_launch_direction() -> Vector2:
	if not position.is_zero_approx():
		return position.normalized()
	return Vector2.RIGHT.rotated(rotation)


func get_local_release_position(default_distance: float) -> Vector2:
	if not position.is_zero_approx():
		return position
	return get_local_launch_direction() * default_distance


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.3, 1.0, 0.55, 0.95) if is_safe_default else Color(0.5, 0.95, 0.8, 0.8)
	draw_line(Vector2.ZERO, Vector2(72.0, 0.0), color, 3.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(72.0, 0.0),
			Vector2(58.0, -8.0),
			Vector2(58.0, 8.0),
		]),
		color
	)
