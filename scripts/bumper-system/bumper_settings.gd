@tool
class_name BumperSettings
extends Resource


enum BumperType {
	NORMAL,
	BOUNCE,
	TRACK,
	SHOT,
}

enum MechanicsStatus {
	CONCEPT_ONLY,
	IMPLEMENTED,
}


@export_category("오브젝트 설정")
## 실제 공과 부딪히는 물리 충돌 원의 지름입니다. 씬에서 주황색 실선으로 표시됩니다.
@export_range(16.0, 256.0, 1.0, "suffix:px") var collision_diameter: float = 88.0:
	set(value):
		collision_diameter = value
		emit_changed()
## 화면에 그려지는 범퍼 외형의 지름입니다. 씬에서 청록색 가이드로 표시됩니다.
@export_range(16.0, 320.0, 1.0, "suffix:px") var visual_diameter: float = 92.0:
	set(value):
		visual_diameter = value
		emit_changed()
## 복구할 때 공과 확보해야 하는 충돌 원 바깥쪽 추가 여유 거리입니다. 씬에서 보라색 점선으로 표시됩니다.
@export_range(0.0, 256.0, 1.0, "suffix:px") var respawn_safe_margin: float = 40.0:
	set(value):
		respawn_safe_margin = value
		emit_changed()
## 보드에 동시에 배치할 수 있는 최대 개수입니다. 0은 제한 없음입니다.
@export_range(0, 99, 1) var maximum_per_board: int = 0
## 범퍼의 색상, 모양, 라벨을 정의하는 외형 설정입니다.
@export var presentation: BumperPresentationSettings

@export_category("공용 범퍼 설정")
## 저장, 보상, 배치 시스템에서 범퍼 종류를 안정적으로 식별하는 고유 ID입니다.
@export var bumper_kind_id: StringName = &"bumper"
## 에디터와 HUD에서 표시할 범퍼 이름입니다.
@export var display_name: String = "Bumper"
## 플레이어가 스테이지 보상으로 획득하고 보유하여 직접 배치할 수 있는 범퍼입니다.
## 충돌 타입과는 독립된 범퍼 정의 속성이며 인스턴스 오버라이드 대상이 아닙니다.
@export var is_repair_part: bool = false

## 이 범퍼의 고유 동작이 실제 구현되었는지 나타냅니다.
@export var mechanics_status: MechanicsStatus = MechanicsStatus.IMPLEMENTED
## 기획 중인 범퍼의 역할과 의도를 여러 줄로 기록합니다.
@export_multiline var concept_role: String = ""
## 테마, 검색, 분류에 사용할 키워드 목록입니다.
@export var theme_keywords: PackedStringArray = PackedStringArray()

## 유효 타격 한 번이 제공하는 기본 점수입니다.
@export_range(0, 999999, 1) var base_score: int = 100
## 콤보 계산에서 이 범퍼 점수에 적용할 가중치입니다.
@export_range(0.0, 100.0, 0.05, "suffix:x") var score_weight: float = 1.0

## 파괴되기 전까지 견딜 수 있는 총 내구도입니다.
@export_range(1, 999, 1) var max_durability: int = 1
## 유효 타격 한 번마다 감소하는 내구도입니다.
@export_range(1, 999, 1) var durability_damage_per_hit: int = 1
## 파괴된 뒤 안전 복구 검사를 시작하기까지 기다리는 시간입니다.
@export_range(0.0, 60.0, 0.1, "suffix:s") var respawn_delay: float = 3.0
## 실제 복구 직전에 범퍼가 깜빡이며 예고하는 시간입니다.
@export_range(0.0, 5.0, 0.05, "suffix:s") var respawn_telegraph_duration: float = 0.4

@export_category("타입별 범퍼 설정")
## 충돌 시 사용할 동작 종류입니다. 타입을 바꾸면 아래에 해당 타입의 속성만 표시됩니다.
@export var bumper_type: BumperType = BumperType.NORMAL:
	set(value):
		bumper_type = value
		notify_property_list_changed()
		emit_changed()
## 충돌 직전 속력에 곱하는 배율입니다.
@export_range(0.1, 3.0, 0.01, "suffix:x") var speed_multiplier: float = 1.0
## 범퍼 반응으로 공이 도달할 수 있는 최대 속력입니다.
@export_range(1.0, 5000.0, 1.0, "suffix:px/s") var maximum_response_speed: float = 1540.0
## Bounce 범퍼가 반사한 공이 반드시 유지할 최소 속력입니다.
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var minimum_release_speed: float = 0.0
## Shot 범퍼가 공을 붙잡고 발사 방향 입력을 기다리는 시간입니다.
@export_range(0.0, 5.0, 0.05, "suffix:s") var selection_duration: float = 0.8
## Shot 범퍼가 공을 발사할 때 사용하는 고정 속력입니다.
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var launch_speed: float = 1300.0
## Shot 범퍼가 제공할 발사 방향 목록입니다. 배열에서 방향을 추가·삭제하고 각 항목을 펼쳐 수정할 수 있습니다.
@export var shot_launch_directions: Array[ShotLaunchAnchor] = []:
	set(value):
		_disconnect_shot_directions()
		shot_launch_directions = value
		_connect_shot_directions()
		emit_changed()
## Track 범퍼가 현재 위치를 기준으로 이동할 목표 위치입니다. 에디터에서 보라색 경로와 도착점으로 표시됩니다.
@export var track_target_offset := Vector2.ZERO:
	set(value):
		track_target_offset = value
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.name)
	var hide := false
	match property_name:
		&"speed_multiplier", &"maximum_response_speed":
			hide = bumper_type not in [BumperType.NORMAL, BumperType.BOUNCE]
		&"minimum_release_speed":
			hide = bumper_type != BumperType.BOUNCE
		&"selection_duration", &"launch_speed", &"shot_launch_directions":
			hide = bumper_type != BumperType.SHOT
		&"track_target_offset":
			hide = bumper_type != BumperType.TRACK
	if hide:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _connect_shot_directions() -> void:
	for direction: ShotLaunchAnchor in shot_launch_directions:
		if direction != null and not direction.changed.is_connected(_on_shot_direction_changed):
			direction.changed.connect(_on_shot_direction_changed)


func _disconnect_shot_directions() -> void:
	for direction: ShotLaunchAnchor in shot_launch_directions:
		if direction != null and direction.changed.is_connected(_on_shot_direction_changed):
			direction.changed.disconnect(_on_shot_direction_changed)


func _on_shot_direction_changed() -> void:
	emit_changed()


## 보상 시스템이 범퍼 설정을 인스턴스화하지 않고 후보 여부를 검사하는 계약입니다.
func is_reward_candidate() -> bool:
	return is_repair_part


func is_valid() -> bool:
	return (
		not bumper_kind_id.is_empty()
		and max_durability > 0
		and durability_damage_per_hit > 0
		and collision_diameter > 0.0
		and visual_diameter > 0.0
		and maximum_response_speed > 0.0
	)
