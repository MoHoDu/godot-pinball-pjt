@tool
class_name WallSfxRules
extends Resource
## 벽 충돌 SFX 규칙입니다.
##
## 큐가 하나뿐입니다. 기획서 p.62 가 **사각형·삼각형 보드는 동일한 벽 충돌음을 쓴다**고
## 못 박았으므로 보드별 필드를 만들지 않습니다. 만들면 언젠가 갈라집니다.
##
## 음원 3종은 랜덤 변형이 아니라 **저·중·고속 대응**입니다 (p.73 MUST).
## 그래서 `hit_cue.selection_mode` 는 SPEED_TIER 여야 합니다.


@export_category("벽 SFX")

## 공이 벽에 부딪힐 때. 음원은 [저속, 중속, 고속] 순서.
@export var hit_cue: SfxCue


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if hit_cue == null:
		warnings.append("벽 충돌 큐를 지정해야 합니다.")
		return warnings

	if hit_cue.selection_mode != SfxCue.SelectionMode.SPEED_TIER:
		warnings.append("벽 충돌음 3종은 속도 구간별입니다. SPEED_TIER 로 두세요.")

	if hit_cue.priority != SfxPriority.WALL:
		warnings.append("벽 충돌은 WALL 우선순위여야 합니다.")

	return warnings
