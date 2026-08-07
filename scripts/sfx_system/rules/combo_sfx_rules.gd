@tool
class_name ComboSfxRules
extends Resource
## 콤보·웨이브 SFX 규칙입니다.
##
## ★ 이 규칙의 핵심은 **상승음의 피치 사다리**입니다.
##   콤보 상승음은 한 파일입니다. 콤보가 오를수록 **재생 피치를 올려서**
##   "쌓이고 있다"를 만듭니다. 파일을 여러 개 굽지 않는 이유는
##   경계에서 음색이 튀고, 콤보 상한이 바뀌면 전부 다시 만들어야 해서입니다.
##
## ★ 상승음은 전체에서 가장 작습니다(-15dBFS).
##   한 콤보에 수십 번 납니다. 크면 몇 초 만에 귀가 지칩니다.


## 피치 사다리의 한 계단 크기입니다. 반음이 약 1.059 배입니다.
const DEFAULT_PITCH_STEP: float = 0.06

## 사다리 꼭대기. 이 위로는 안 올라갑니다 — 삑삑거리기 시작합니다.
const DEFAULT_MAX_PITCH: float = 2.0


@export_category("콤보 SFX")

@export_group("콤보")

## 유효 타격마다. 콤보가 오를수록 피치가 올라갑니다.
@export var rise_cue: SfxCue

## 콤보 단계가 오를 때. 상승음보다 크고 밝습니다.
@export var tier_cue: SfxCue

## 시간이 끊겨 콤보가 실패로 끝날 때.
@export var timeout_cue: SfxCue

## 웨이브 목표 점수에 도달했을 때.
@export var target_reached_cue: SfxCue


@export_group("피치 사다리")

## 콤보 1당 오르는 피치입니다.
@export_range(0.0, 0.3, 0.005) var pitch_step: float = DEFAULT_PITCH_STEP

## 사다리 꼭대기입니다.
@export_range(1.0, 4.0, 0.05, "suffix:x") var maximum_pitch: float = DEFAULT_MAX_PITCH


@export_group("웨이브")

## 웨이브를 이겼을 때. 저주가 풀립니다.
@export var wave_won_cue: SfxCue

## 공을 다 써서 웨이브를 놓쳤을 때.
@export var wave_lost_cue: SfxCue


## 콤보 수에 맞는 재생 피치입니다.
##
## 콤보 1이 기준(1.0)입니다. 0이나 음수가 들어와도 1.0 아래로 내려가지 않습니다 —
## 내려가면 첫 타격이 둔탁하게 들립니다.
func get_rise_pitch(combo_count: int) -> float:
	var steps := maxi(combo_count - 1, 0)
	return minf(1.0 + steps * pitch_step, maximum_pitch)


## 콤보 종료 사유가 실패인지입니다.
##
## `ComboSystem.combo_finished(count, tier, awarded_score, reason)` 의 reason 은
## 열거값입니다. 정산으로 끝난 것과 시간이 끊겨 끝난 것을 소리로 갈라야 합니다.
## 점수가 안 붙었으면 실패로 봅니다 — reason 열거값에 의존하지 않아
## combo_system.gd 가 바뀌어도 따라 깨지지 않습니다.
func is_failed_finish(awarded_score: int) -> bool:
	return awarded_score <= 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if rise_cue == null:
		warnings.append("콤보 상승음이 없으면 콤보가 쌓이는 것을 소리로 모릅니다.")

	if rise_cue != null and tier_cue != null \
			and rise_cue.base_volume_db >= tier_cue.base_volume_db:
		warnings.append("상승음은 단계음보다 작아야 합니다. 수십 번 나기 때문입니다.")

	if pitch_step <= 0.0:
		warnings.append("피치 사다리가 0이면 콤보가 올라도 같은 소리가 납니다.")

	return warnings
