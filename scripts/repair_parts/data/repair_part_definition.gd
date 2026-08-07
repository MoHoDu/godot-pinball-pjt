@tool
class_name RepairPartDefinition
extends Resource


## 수리 부품 하나의 정체성과 수치를 정의합니다.
## 부품은 별도 런타임 타입이 아니라 기존 Bumper 프리팹 위에 얹히는 정의 데이터입니다.
## 수리 부품 자격 자체는 BumperSettings.is_repair_part가 단일 출처입니다.
##
## v0.3: 랭크 시스템을 제거했습니다. 부품은 계열마다 고정 수치 한 벌만 가지며,
## 초승달 바늘(NEEDLE)은 구현 범위에서 삭제되어 세 계열만 존재합니다.

enum Family {
	BROOCH,
	GEAR,
	BELL,
}


@export_category("Identity")
## 보상·인벤토리·배치가 공유하는 안정적인 부품 ID입니다. 출시 후 변경 금지.
@export var part_id: StringName = &""
@export var family: Family = Family.BROOCH
@export var display_name: String = ""
## 이 부품이 사용하는 BumperSettings.bumper_kind_id와 일치해야 합니다.
@export var bumper_kind_id: StringName = &""
## 보상 카드에 쓰는 행동 중심 한 줄 설명입니다.
@export_multiline var action_line: String = ""

@export_category("Brooch")
## 마감 표식 제한 시간이자 완성 연출 애니메이션의 길이입니다.
@export_range(0.0, 30.0, 0.1, "suffix:s") var brooch_window_seconds: float = 6.0
## 완성 타격에 곱하는 배수입니다. 기본 타격 1.0 대비 x3.0으로 정산합니다.
@export_range(0.0, 20.0, 0.05, "suffix:x")
var brooch_finish_multiplier: float = 3.0
## 완성에 필요한 서로 다른 다른-부품 계열 수입니다.
@export_range(1, 4, 1) var brooch_required_visits: int = 2

@export_category("Gear")
## 회전 단계 유지 시간입니다.
@export_range(0.0, 30.0, 0.05, "suffix:s") var gear_window_seconds: float = 2.4
## 접촉 가속 배율입니다. 기존 범퍼의 speed_multiplier와 같은 방식으로 곱합니다.
@export_range(1.0, 4.0, 0.01, "suffix:x")
var gear_contact_multiplier: float = 1.15
## 과회전 추가 가속입니다. 배율이 아니라 절대 px/s 가산으로 유지합니다.
## (테스트 후 배율로 전환할 수 있도록 접촉 배율과 분리해 둡니다.)
@export_range(0.0, 2000.0, 1.0, "suffix:px/s")
var gear_overdrive_boost: float = 180.0
## 과회전이 터지는 누적 접촉 횟수입니다.
@export_range(1, 9, 1) var gear_max_stack: int = 3

@export_category("Bell")
## 접촉 후 여운이 울릴 때까지의 지연 시간입니다.
@export_range(0.0, 5.0, 0.01, "suffix:s") var bell_echo_delay: float = 0.6
## 여운 예약 사이의 내부 쿨다운입니다.
@export_range(0.0, 10.0, 0.01, "suffix:s")
var bell_cooldown_seconds: float = 1.0
## 지연 시간 동안 쌓인 콤보에 곱하는 가중치입니다.
## 결과는 반올림한 정수 콤보 횟수로 한 번에 추가됩니다.
@export_range(0.0, 4.0, 0.01, "suffix:x")
var bell_echo_combo_multiplier: float = 0.25
## 여운으로 추가되는 콤보 한 번이 가지는 점수 가중치입니다.
@export_range(0.0, 10.0, 0.05, "suffix:x")
var bell_echo_hit_weight: float = 1.0


func is_valid() -> bool:
	return not part_id.is_empty() and not bumper_kind_id.is_empty()
