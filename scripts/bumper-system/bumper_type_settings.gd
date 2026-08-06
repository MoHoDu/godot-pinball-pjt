@tool
class_name BumperTypeSettings
extends Resource


## 충돌 시 사용할 동작 종류입니다. 타입을 바꾸면 해당 타입의 속성만 표시됩니다.
@export_enum("Normal", "Bounce", "Track", "Shot") var bumper_type := 0:
	set(value):
		bumper_type = value
		notify_property_list_changed()
		emit_changed()
## Normal과 Bounce 범퍼가 충돌 직전 속력에 곱하는 배율입니다.
@export_range(0.1, 3.0, 0.01, "suffix:x") var speed_multiplier := 1.0:
	set(value):
		speed_multiplier = value
		emit_changed()
## Normal과 Bounce 범퍼 반응으로 공이 도달할 수 있는 최대 속력입니다.
@export_range(1.0, 5000.0, 1.0, "suffix:px/s") var maximum_response_speed := 1540.0:
	set(value):
		maximum_response_speed = value
		emit_changed()
## Bounce 범퍼가 반사한 공이 반드시 유지할 최소 속력입니다.
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var minimum_release_speed := 0.0:
	set(value):
		minimum_release_speed = value
		emit_changed()
## Shot 범퍼가 공을 붙잡고 발사 방향 입력을 기다리는 시간입니다.
@export_range(0.0, 5.0, 0.05, "suffix:s") var selection_duration := 0.8:
	set(value):
		selection_duration = value
		emit_changed()
## Shot 범퍼가 공을 발사할 때 사용하는 고정 속력입니다.
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var launch_speed := 1300.0:
	set(value):
		launch_speed = value
		emit_changed()
## Shot 발사 방향 목록입니다. 배열에서 항목을 추가·삭제하고 펼쳐서 수정할 수 있습니다.
@export var shot_launch_directions: Array[ShotLaunchAnchor] = []:
	set(value):
		_disconnect_shot_directions()
		shot_launch_directions = value
		_connect_shot_directions()
		emit_changed()
## 별도 Resource 파일을 만들지 않고 새 발사 방향을 배열에 추가합니다. 추가 후 2D 화면의 핸들을 마우스로 드래그하세요.
@export_tool_button("발사 방향 추가", "Add") var add_shot_direction_button := add_shot_direction
## Track 범퍼가 현재 위치를 기준으로 이동할 목표 위치입니다.
@export var track_target_offset := Vector2.ZERO:
	set(value):
		track_target_offset = value
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.name)
	var hide := false
	match property_name:
		&"speed_multiplier", &"maximum_response_speed":
			hide = bumper_type not in [0, 1]
		&"minimum_release_speed":
			hide = bumper_type != 1
		&"selection_duration", &"launch_speed", &"shot_launch_directions", \
				&"add_shot_direction_button":
			hide = bumper_type != 3
		&"track_target_offset":
			hide = bumper_type != 2
	if hide:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func add_shot_direction() -> ShotLaunchAnchor:
	var direction := ShotLaunchAnchor.new()
	var direction_index := shot_launch_directions.size()
	var next_index := direction_index + 1
	direction.display_name = "발사 방향 %d" % next_index
	direction.is_safe_default = shot_launch_directions.is_empty()
	var angle := -PI * 0.5 + TAU * float(direction_index) / 4.0
	direction.release_position = Vector2.from_angle(angle) * 96.0
	var updated_directions := shot_launch_directions.duplicate()
	updated_directions.append(direction)
	shot_launch_directions = updated_directions
	return direction


func _connect_shot_directions() -> void:
	for direction: ShotLaunchAnchor in shot_launch_directions:
		if direction != null and not direction.changed.is_connected(_on_direction_changed):
			direction.changed.connect(_on_direction_changed)


func _disconnect_shot_directions() -> void:
	for direction: ShotLaunchAnchor in shot_launch_directions:
		if direction != null and direction.changed.is_connected(_on_direction_changed):
			direction.changed.disconnect(_on_direction_changed)


func _on_direction_changed() -> void:
	emit_changed()


func is_valid() -> bool:
	return maximum_response_speed > 0.0
