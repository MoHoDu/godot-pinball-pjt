@tool
class_name BossSfxRules
extends Resource
## 보스(눈 잃은 테디베어) SFX 규칙입니다.
##
## 근거: 보스 기획서 11장, 비주얼·사운드 가이드 13~16장.
## "거대한 괴물이 아니라, 저주에 잠식된 낡은 봉제 장난감이 움직이는 소리."
##
## ★ 보스 본체는 아직 씬에 없습니다. 지금 코드에 실재하는 시그널은
##   `ComboBossTarget` 의 boss_hit · defeated · boss_reset 뿐이고,
##   팔 공격·포효·솜뭉치는 기획서의 필수 이벤트 목록(boss_arm_* 등)으로
##   예정돼 있습니다. 바인더는 시그널 이름으로 찾아 잇기 때문에,
##   보스가 들어오는 순간 나머지도 **코드 수정 없이** 울리기 시작합니다.


@export_category("보스 SFX")

@export_group("팔 공격")

## 팔이 올라가는 예고. 굵은 실이 당겨지는 끼익 — 공격을 멈추라는 신호다.
@export var telegraph_cue: SfxCue

## 팔 휘두름. 금속이 아니라 큰 천 덩어리의 휙 + 속 빈 몸체의 턱.
@export var arm_swing_cue: SfxCue


@export_group("피격")

## 유효 타격. 쾅이 아니라 팡 — 푹/툭.
@export var hit_cue: SfxCue


@export_group("페이즈 2")

## 포효. 뒤틀린 오르골 + 천 찢어지는 숨. 암전의 시작을 알린다.
@export var roar_cue: SfxCue

## 솜뭉치 생성 예고 — 짧은 저주 점멸음.
@export var cotton_telegraph_cue: SfxCue

## 솜뭉치 생성 — 실 스르륵 + 솜 푹.
@export var cotton_spawn_cue: SfxCue


@export_group("장면")

## 처치. 봉제선이 풀리고, 유리가 울리고, 오르골 종이 닫는다.
@export var defeated_cue: SfxCue

## 기본 환경 — 하트 핵의 박동. 가장 작게 깔린다 (가이드 13장 우선순위 최하).
@export var heartbeat_cue: SfxCue


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if hit_cue == null:
		warnings.append("피격음이 없으면 보스를 때린 것이 소리로 확인되지 않습니다.")

	if telegraph_cue == null:
		warnings.append("예고음이 없으면 팔 공격을 소리로 피할 수 없습니다.")

	return warnings
