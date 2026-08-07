class_name CoinDefinition
extends Resource


## 보드 코인의 정적 데이터입니다. 픽업 인스턴스와 배치가 같은 값을 공유합니다.


@export var coin_id: StringName = &"basic_coin"
@export var display_name := "기본 코인"
@export_range(1, 999, 1) var value := 2
@export_range(4.0, 64.0, 1.0, "suffix:px") var visual_radius := 14.0
@export var fill_color := Color(0.90, 0.72, 0.25)
@export var rim_color := Color(0.96, 0.93, 0.82)


func is_valid() -> bool:
	return not coin_id.is_empty() and value > 0 and visual_radius > 0.0
