class_name RewardBallOffer
extends Resource


## 보상 상점의 공 카드 한 장입니다. (기획서 4-2, 10-2)
##
## 실제 공 씬 연결(해금)은 공 인벤토리 단계에서 하고,
## 상점은 ball_id와 가격·성능 계열만 다룹니다.


## 후보 구성 규칙(6-1)에 쓰는 성능 계열입니다.
## 보상 1은 GOOD·MID·HARDCORE 각 1장으로 차이를 학습시킵니다.
enum PerformanceGroup {
	GOOD,
	MID,
	HARDCORE,
}


@export var ball_id: StringName = &"ball"
@export var display_name: String = "공"
@export var price := 9
@export var performance_group := PerformanceGroup.MID
@export_range(1, 999, 1) var first_stage_num := 1
@export_range(1, 4, 1) var first_wave_num := 1
@export_range(0.0, 1000.0, 0.01) var probability := 1.0

## 카드에 장점과 대가를 같은 비중으로 표시합니다(7-3. 함정 카드가 아니다).
@export_multiline var merit_text := ""
@export_multiline var cost_text := ""


func is_valid() -> bool:
	return ball_id != &"" \
		and price > 0 \
		and first_stage_num >= 1 \
		and first_wave_num >= 1 \
		and first_wave_num <= 4 \
		and probability >= 0.0
