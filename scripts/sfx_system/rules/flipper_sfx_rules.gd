@tool
class_name FlipperSfxRules
extends Resource
## 플리퍼 SFX 규칙입니다. 기획서 p.20 이 요구하는 6종을 각각 별도 큐로 둡니다.
##
## ★ 선택음과 작동음을 **한 큐의 변형으로 두지 않습니다.**
##   p.20 이 "선택음과 작동음은 분명히 달라야 한다"고 했고, p.5 검수 항목에도
##   "선택음·작동음·패링 성공음이 서로 다른가"가 있습니다. 별도 큐여야 그게 보장됩니다.
##
## 같은 Space 입력이 세 갈래로 갈립니다. 이 구분이 6종을 두는 이유입니다.
##   - 플리퍼만 올라감      → 작동음만
##   - 공을 침              → 작동음 + 타격음
##   - 타이밍이 정확했음    → 작동음 + 패링음


const MIN_STRONG_SPEED: float = 100.0
const MAX_STRONG_SPEED: float = 4000.0
## 이 속도 이상이면 강한 타격으로 봅니다. 기획서에 수치가 없어 우리가 잡았습니다.
## 공 기본 발사 속도 700px/s, 최대 2000px/s 사이입니다.
const DEFAULT_STRONG_SPEED: float = 1200.0


var _strong_hit_speed_threshold: float = DEFAULT_STRONG_SPEED


@export_category("플리퍼 SFX")

@export_group("조작")

## 방향키로 조작할 플리퍼 그룹을 바꿀 때.
@export var select_cue: SfxCue

## Space 를 눌러 플리퍼가 올라가는 순간. 공을 못 맞혀도 납니다.
@export var activate_cue: SfxCue

## 플리퍼가 제자리로 내려올 때. 있는 줄 모를 만큼 작아야 합니다.
@export var return_cue: SfxCue


@export_group("타격")

## 플리퍼가 공을 침. 기획서 MUST.
@export var hit_cue: SfxCue

## 세게 쳤을 때. 금속 쾅이 아니라 탄력 있는 쫙.
@export var strong_hit_cue: SfxCue

## 이 속도 이상이면 강한 타격으로 봅니다.
@export_range(100.0, 4000.0, 10.0, "suffix:px/s")
var strong_hit_speed_threshold: float:
	get:
		return _strong_hit_speed_threshold
	set(value):
		_strong_hit_speed_threshold = clampf(value, MIN_STRONG_SPEED, MAX_STRONG_SPEED)
		emit_changed()


@export_group("패링")

## 정확한 패링. 우선순위 1위입니다.
@export var parry_perfect_cue: SfxCue

## 일반 패링. 정확한 패링보다 작게 울립니다.
@export var parry_normal_cue: SfxCue


## 충돌 속도에 맞는 타격 큐입니다.
func get_hit_cue(speed: float) -> SfxCue:
	if speed >= _strong_hit_speed_threshold and strong_hit_cue != null:
		return strong_hit_cue

	return hit_cue


## 패링 등급에 맞는 큐입니다. 등급 값은 FlipperParryFeedback 과 맞춥니다.
func get_parry_cue(grade: int) -> SfxCue:
	const GRADE_PERFECT := 2
	if grade >= GRADE_PERFECT:
		return parry_perfect_cue

	return parry_normal_cue


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if hit_cue == null:
		warnings.append("플리퍼 타격 큐는 필수입니다 (기획서 MUST).")

	if select_cue != null and activate_cue != null \
			and select_cue.cue_id == activate_cue.cue_id:
		warnings.append("선택음과 작동음은 분명히 달라야 합니다 (p.20).")

	if parry_perfect_cue != null and parry_perfect_cue.priority != SfxPriority.PARRY:
		warnings.append("정확한 패링은 PARRY 우선순위여야 합니다.")

	return warnings
