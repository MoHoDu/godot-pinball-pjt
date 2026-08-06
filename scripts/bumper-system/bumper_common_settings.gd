@tool
class_name BumperCommonSettings
extends Resource


## 저장, 보상, 배치 시스템에서 범퍼 종류를 안정적으로 식별하는 고유 ID입니다.
@export var bumper_kind_id: StringName = &"bumper":
	set(value):
		bumper_kind_id = value
		emit_changed()
## 에디터와 HUD에서 표시할 범퍼 이름입니다.
@export var display_name := "Bumper":
	set(value):
		display_name = value
		emit_changed()
## 플레이어가 보상으로 획득하고 보유하여 직접 배치할 수 있는 범퍼입니다.
@export var is_repair_part := false:
	set(value):
		is_repair_part = value
		emit_changed()
## 이 범퍼의 고유 동작이 실제 구현되었는지 나타냅니다.
@export_enum("Concept Only", "Implemented") var mechanics_status := 1:
	set(value):
		mechanics_status = value
		emit_changed()
## 기획 중인 범퍼의 역할과 의도를 여러 줄로 기록합니다.
@export_multiline var concept_role := "":
	set(value):
		concept_role = value
		emit_changed()
## 테마, 검색, 분류에 사용할 키워드 목록입니다.
@export var theme_keywords := PackedStringArray():
	set(value):
		theme_keywords = value
		emit_changed()
## 유효 타격 한 번이 제공하는 기본 점수입니다.
@export_range(0, 999999, 1) var base_score := 100:
	set(value):
		base_score = value
		emit_changed()
## 콤보 계산에서 이 범퍼 점수에 적용할 가중치입니다.
@export_range(0.0, 100.0, 0.05, "suffix:x") var score_weight := 1.0:
	set(value):
		score_weight = value
		emit_changed()
## 파괴되기 전까지 견딜 수 있는 총 내구도입니다.
@export_range(1, 999, 1) var max_durability := 1:
	set(value):
		max_durability = value
		emit_changed()
## 유효 타격 한 번마다 감소하는 내구도입니다.
@export_range(1, 999, 1) var durability_damage_per_hit := 1:
	set(value):
		durability_damage_per_hit = value
		emit_changed()
## 파괴된 뒤 안전 복구 검사를 시작하기까지 기다리는 시간입니다.
@export_range(0.0, 60.0, 0.1, "suffix:s") var respawn_delay := 3.0:
	set(value):
		respawn_delay = value
		emit_changed()
## 실제 복구 직전에 범퍼가 깜빡이며 예고하는 시간입니다.
@export_range(0.0, 5.0, 0.05, "suffix:s") var respawn_telegraph_duration := 0.4:
	set(value):
		respawn_telegraph_duration = value
		emit_changed()


func is_valid() -> bool:
	return (
		not bumper_kind_id.is_empty()
		and max_durability > 0
		and durability_damage_per_hit > 0
	)
