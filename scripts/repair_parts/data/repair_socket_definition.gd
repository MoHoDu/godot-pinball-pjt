@tool
class_name RepairSocketDefinition
extends Resource


## 기획자가 충돌 안전성을 검증한 수리 소켓 하나의 정의입니다.
## 부품은 자유 좌표에 놓지 않고 이 소켓에만 장착합니다.

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
}


@export_category("Identity")
@export var socket_id: StringName = &""
@export var difficulty: Difficulty = Difficulty.EASY

@export_category("Placement")
## 프로토타입 권장 충돌 반경은 30~36 월드 유닛입니다.
@export_range(16.0, 128.0, 1.0, "suffix:px") var collision_radius: float = 33.0
## 보스 출현 영역과 겹치는 소켓은 보스전에서 비활성화합니다.
@export var disabled_during_boss: bool = false


func is_valid() -> bool:
	return not socket_id.is_empty() and collision_radius > 0.0
