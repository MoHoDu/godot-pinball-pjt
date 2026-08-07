class_name CoinSpawnLayout
extends Resource


## 웨이브 하나의 코인 배치 데이터입니다.
##
## 기획서 레벨 디자인 탭: 웨이브당 12개 × 2코인 = 24코인.
## 현재 wave(웨이브 1)는 주요 경로 10개, 분기·위험 경로 2개입니다.
## 좌표는 보드 월드 기준(board_world_bounds Rect2(-1180, -700, 2360, 1400))입니다.


@export var coin_value := 2

## 웨이브 1 주요 경로 10개. wave.tscn의 에디터 배치와 같은 기본값입니다.
@export var main_path_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-850.0, -300.0),
	Vector2(850.0, -300.0),
	Vector2(-900.0, 0.0),
	Vector2(900.0, 0.0),
	Vector2(-850.0, 300.0),
	Vector2(850.0, 300.0),
	Vector2(0.0, -450.0),
	Vector2(0.0, 0.0),
	Vector2(-120.0, 330.0),
	Vector2(120.0, 330.0),
])

## 웨이브 1 분기·위험 경로 2개.
@export var risk_path_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-560.0, -520.0),
	Vector2(560.0, -520.0),
])


func all_positions() -> PackedVector2Array:
	var merged := PackedVector2Array(main_path_positions)
	merged.append_array(risk_path_positions)
	return merged


func total_coin() -> int:
	return coin_value * (main_path_positions.size() + risk_path_positions.size())
