class_name SfxPlayContext
extends RefCounted
## 한 번의 재생 요청에 딸린 상황 정보입니다.
##
## 기존 BallImpactContext / BallImpactResult 쌍과 같은 패턴입니다.
## SfxCue 가 "무엇을 어떻게"를 담는다면 이쪽은 "이번 한 번"을 담습니다.


## 요청한 주체입니다. 연타 사슬과 최소 간격을 이 단위로 셉니다.
## 보통 공의 instance_id 를 씁니다. 공이 둘이면 각자 따로 세야 합니다.
var source_id: int = 0

## 충돌 속도입니다(px/s). 음원 구간 선택과 음량에 쓰입니다.
var speed: float = 0.0

## 호출부가 계산해 얹는 오프셋입니다. 연타 감쇠가 여기로 들어옵니다.
var volume_offset_db: float = 0.0

## SEQUENTIAL 선택에 쓰는 순번입니다. 콤보 상승처럼 단계가 있는 소리용입니다.
var sequence_index: int = 0

## 0보다 크면 피치 랜덤 대신 이 값을 씁니다. 콤보 피치 사다리처럼
## 의도한 음정이 있을 때만 씁니다.
var pitch_override: float = 0.0


func _init(
	p_source_id: int = 0,
	p_speed: float = 0.0,
	p_volume_offset_db: float = 0.0
) -> void:
	source_id = p_source_id
	speed = p_speed
	volume_offset_db = p_volume_offset_db
