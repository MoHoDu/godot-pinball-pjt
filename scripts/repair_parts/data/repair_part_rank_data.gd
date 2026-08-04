@tool
class_name RepairPartRankData
extends Resource


## 수리 부품의 랭크 하나가 사용하는 시간·가중치·속도·쿨다운 값입니다.
## 계열별로 사용하는 필드만 읽고 나머지는 무시합니다.
##  - 브로치: window_seconds(제한 시간), score_weight(완성 타격 가중치)
##  - 톱니:   window_seconds(단계 유지), contact_boost, overdrive_boost, max_stack
##  - 바늘:   window_seconds(봉합 제한 시간), score_weight(봉합 타격 가중치)
##  - 방울:   echo_delay(지연 시간), score_weight(여운 타격 가중치), cooldown_seconds

@export_category("Timing")
@export_range(0.0, 30.0, 0.05, "suffix:s") var window_seconds: float = 0.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var echo_delay: float = 0.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown_seconds: float = 0.0

@export_category("Scoring")
@export_range(0.0, 100.0, 0.05, "suffix:x") var score_weight: float = 0.0

@export_category("Gear Speed")
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var contact_boost: float = 0.0
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var overdrive_boost: float = 0.0
@export_range(1, 9, 1) var max_stack: int = 3
