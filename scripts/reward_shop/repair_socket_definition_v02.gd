@tool
class_name RepairSocketDefinitionV02
extends RepairSocketDefinition


## 기획서 v0.2(9장)의 소켓 확장 정의입니다.
##
## 기존 RepairSocketDefinition은 수정하지 않고 상속으로 필드만 더합니다.
##   - zone_tag: 하단·중단·상단 위치 구역 (9-1 위치 분포)
##   - reserve_radius: 부품 반경 + 공 반지름 22px + 최소 여유 (9-3 예약 반경)


const ZONE_BOTTOM: StringName = &"bottom"
const ZONE_MIDDLE: StringName = &"middle"
const ZONE_TOP: StringName = &"top"


@export_category("Zone (v0.2)")

## 위치 구역입니다. &"bottom"(안전) / &"middle"(연결) / &"top"(고위험).
@export var zone_tag: StringName = ZONE_BOTTOM


@export_category("Spacing (v0.2)")

## 소켓 예약 반경입니다. 범퍼·보스·벽이 이 안으로 들어오면 안 됩니다(9-3).
@export_range(32.0, 256.0, 1.0, "suffix:px") var reserve_radius: float = 72.0
