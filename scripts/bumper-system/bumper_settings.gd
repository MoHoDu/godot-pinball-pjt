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


@export_category("Identity")
@export var bumper_kind_id: StringName = &"bumper"
@export var display_name: String = "Bumper"
@export var bumper_type: BumperType = BumperType.NORMAL

@export_category("Reward And Placement")
## 플레이어가 스테이지 보상으로 획득하고 보유하여 직접 배치할 수 있는 범퍼입니다.
## 충돌 타입과는 독립된 범퍼 정의 속성이며 인스턴스 오버라이드 대상이 아닙니다.
@export var is_repair_part: bool = false

@export_category("Design Status")
@export var mechanics_status: MechanicsStatus = MechanicsStatus.IMPLEMENTED
@export_multiline var concept_role: String = ""
@export var theme_keywords: PackedStringArray = PackedStringArray()

@export_category("Scoring")
@export_range(0, 999999, 1) var base_score: int = 100
@export_range(0.0, 100.0, 0.05, "suffix:x") var score_weight: float = 1.0

@export_category("Durability")
@export_range(1, 999, 1) var max_durability: int = 1
@export_range(1, 999, 1) var durability_damage_per_hit: int = 1
@export_range(0.0, 60.0, 0.1, "suffix:s") var respawn_delay: float = 3.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var respawn_telegraph_duration: float = 0.4

@export_category("Physics")
@export_range(0.1, 3.0, 0.01, "suffix:x") var speed_multiplier: float = 1.0
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var minimum_release_speed: float = 0.0
@export_range(1.0, 5000.0, 1.0, "suffix:px/s") var maximum_response_speed: float = 1540.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var selection_duration: float = 0.8
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var launch_speed: float = 1300.0

@export_category("Geometry")
@export_range(16.0, 256.0, 1.0, "suffix:px") var collision_diameter: float = 88.0
@export_range(16.0, 320.0, 1.0, "suffix:px") var visual_diameter: float = 92.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var respawn_safe_margin: float = 40.0
@export_range(0, 99, 1) var maximum_per_board: int = 0

@export_category("Presentation")
@export var presentation: BumperPresentationSettings


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
