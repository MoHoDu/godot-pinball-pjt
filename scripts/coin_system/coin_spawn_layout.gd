class_name CoinSpawnLayout
extends Resource


## 웨이브 하나의 코인 배치 데이터입니다.
##
## 기획서 3-1: 웨이브당 12개 × 2코인 = 24코인.
## 주요 경로 9개(18코인)는 목표 스코어를 정상적으로 노리는 플레이가 지나는 자리,
## 분기·위험 경로 3개(6코인)는 저축을 노리는 자리입니다.
## 좌표는 보드 월드 기준(board_world_bounds Rect2(-1180, -700, 2360, 1400))입니다.


@export var coin_value := 2

## 주요 경로 9개. 초기값은 자리표시자이며 레벨 디자인에서 조정합니다.
@export var main_path_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-800.0, -350.0),
	Vector2(-500.0, -500.0),
	Vector2(-200.0, -560.0),
	Vector2(100.0, -560.0),
	Vector2(400.0, -500.0),
	Vector2(700.0, -350.0),
	Vector2(-350.0, -150.0),
	Vector2(0.0, -100.0),
	Vector2(350.0, -150.0),
])

## 분기·위험 경로 3개.
@export var risk_path_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-1050.0, -580.0),
	Vector2(1050.0, -580.0),
	Vector2(0.0, -640.0),
])


func all_positions() -> PackedVector2Array:
	var merged := PackedVector2Array(main_path_positions)
	merged.append_array(risk_path_positions)
	return merged


func total_coin() -> int:
	return coin_value * (main_path_positions.size() + risk_path_positions.size())
