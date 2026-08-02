@tool
class_name BallGazeRules
extends Resource


const MIN_GAZE_SPEED_THRESHOLD: float = 0.0
const MAX_GAZE_SPEED_THRESHOLD: float = 2000.0
const DEFAULT_GAZE_SPEED_THRESHOLD: float = 120.0

const MIN_GAZE_SHARPNESS: float = 1.0
const MAX_GAZE_SHARPNESS: float = 60.0
const DEFAULT_GAZE_SHARPNESS: float = 18.0

const DEFAULT_INSTANT_ON_SPAWN: bool = true


var _gaze_speed_threshold: float = DEFAULT_GAZE_SPEED_THRESHOLD
var _gaze_sharpness: float = DEFAULT_GAZE_SHARPNESS
var _instant_on_spawn: bool = DEFAULT_INSTANT_ON_SPAWN


@export_category("공 시선 설정")

@export_group("시선 갱신")

## 이 속력 미만에서는 시선을 갱신하지 않고 마지막 방향을 유지합니다.
## 거의 멈춘 공에서 눈이 떨리는 것을 막습니다.
@export_range(0.0, 2000.0, 5.0, "suffix:px/s")
var gaze_speed_threshold: float:
	get:
		return _gaze_speed_threshold
	set(value):
		_gaze_speed_threshold = clampf(
			value,
			MIN_GAZE_SPEED_THRESHOLD,
			MAX_GAZE_SPEED_THRESHOLD
		)
		emit_changed()

## 시선이 진행방향을 따라잡는 속도입니다.
## 클수록 즉각 반응하고, 작을수록 부드럽게 끌려옵니다.
## 프레임레이트와 무관하게 같은 체감이 되도록 지수 감쇠에 사용합니다.
@export_range(1.0, 60.0, 0.5)
var gaze_sharpness: float:
	get:
		return _gaze_sharpness
	set(value):
		_gaze_sharpness = clampf(value, MIN_GAZE_SHARPNESS, MAX_GAZE_SHARPNESS)
		emit_changed()

## 처음으로 임계 속력을 넘는 순간에는 보간 없이 즉시 정렬합니다.
## 발사 직후 공이 엉뚱한 곳을 보다가 돌아오는 것을 막습니다.
@export
var instant_on_spawn: bool:
	get:
		return _instant_on_spawn
	set(value):
		_instant_on_spawn = value
		emit_changed()
