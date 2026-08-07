@tool
class_name BallAudioProfile
extends Resource
## 공 한 종류의 사운드 정체성입니다.
##
## ★ 필드명 `hit_material_sfx` / `parry_accent_sfx` 는 **기획서가 지정한 이름**입니다
##   (p.106 12-4 공 종류 데이터 항목). 마음대로 바꾸지 않습니다.
##
## ★ 공별로 바뀌는 것은 **재질음과 패링 2번째 레이어뿐**입니다 (p.89 6-2, p.90 6-3).
##   공통 어택과 원형 파동은 모든 공이 공유합니다. 공 종류가 달라도 "충돌 시점을
##   인지하는 기준"은 유지돼야 하기 때문입니다.
##
## ★ `common_attack_sfx` 필드가 없는 것은 의도입니다.
##   충돌음 파일에 공통 어택이 이미 섞여 있습니다(파형 상관 실측). 따로 겹쳐 재생하면
##   어택이 두 번 찍힙니다. 필드가 없는 것이 방어입니다.


@export_category("공 사운드 프로파일")

## `BallDefinition.ball_id` 와 맞춥니다.
@export var ball_id: StringName = &"ball"

## 이 공이 무엇인지. 검수 때 소리와 대조하기 위한 것입니다.
@export_multiline var role: String = ""


@export_group("음원 (기획서 지정 필드명)")

## 공별 재질음입니다. 기획서는 공 종류당 3종 이상을 요구합니다 (p.105).
@export var hit_material_sfx: Array[AudioStream] = []

## 패링 3레이어 중 **2번째(밝은 팅)** 에 얹는 공별 악센트입니다.
## 1번째(탁)와 3번째(원형 파동)는 공통이라 여기 없습니다.
@export var parry_accent_sfx: AudioStream


@export_group("변조 덮어쓰기")

## 0보다 크면 기본 큐의 피치 폭 대신 이 값을 씁니다.
## 정속 태엽눈은 "피치 편차를 작게 유지한다"(p.93)라 여기서 줄입니다.
@export_range(0.0, 0.5, 0.01, "suffix:x")
var pitch_jitter_override: float = 0.0


## 기본 큐를 이 공의 재질음으로 갈아끼운 사본을 만듭니다.
##
## 원본을 건드리지 않고 복제해서 돌려줍니다. 큐 하나를 여러 공이 공유하는데
## 원본을 바꾸면 마지막에 로드된 공의 음원이 전부에 적용됩니다.
func build_hit_cue(base: SfxCue) -> SfxCue:
	if base == null:
		return null

	if hit_material_sfx.is_empty():
		return base

	var cue: SfxCue = base.duplicate()
	cue.cue_id = StringName("%s_%s" % [base.cue_id, ball_id])
	cue.streams = hit_material_sfx

	if pitch_jitter_override > 0.0:
		cue.pitch_jitter = pitch_jitter_override

	return cue


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if hit_material_sfx.is_empty():
		warnings.append("공별 재질음이 비어 있습니다. 기본 큐를 그대로 씁니다.")
	elif hit_material_sfx.size() < 3:
		warnings.append("기획서는 공 종류당 재질음 3종 이상을 요구합니다 (지금 %d개)."
			% hit_material_sfx.size())

	return warnings
