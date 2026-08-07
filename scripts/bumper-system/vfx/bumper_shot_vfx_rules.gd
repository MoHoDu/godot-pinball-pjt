@tool
class_name BumperShotVfxRules
extends BumperVfxRules
## Shot 타입 VFX 규칙입니다. `BumperVfxRules` 를 확장합니다.
##
## 기획서 3-3 Shot: **선택 경로 표시 · 포신 회전 · 짧은 발사 잔상/연기.**
## 5-7 절의 상태 3단계와 대응합니다.
## - 포획: 받침대 눌림, 공 고정
## - 선택: 선택 경로만 밝게, 비선택 경로는 낮은 강도
## - 발사: 짧은 반동, 제한된 연기, 굵은 방향 잔상
##
## 포신 회전은 아트 쪽 몫이라 여기서 그리지 않습니다.
## `_draw_cannon()` 이 이미 `get_selected_launch_direction()` 을 읽습니다.


const MIN_PATH_LENGTH_RATIO: float = 0.3
const MAX_PATH_LENGTH_RATIO: float = 3.0
const DEFAULT_PATH_LENGTH_RATIO: float = 1.15

const MIN_PATH_WIDTH: float = 1.0
const MAX_PATH_WIDTH: float = 10.0
const DEFAULT_SELECTED_WIDTH: float = 4.0
const DEFAULT_UNSELECTED_WIDTH: float = 2.0

const MIN_UNSELECTED_ALPHA: float = 0.0
const MAX_UNSELECTED_ALPHA: float = 0.6
const DEFAULT_UNSELECTED_ALPHA: float = 0.22

const DEFAULT_TRAIL_LIFETIME: float = 0.22

const MIN_SMOKE_COUNT: int = 0
const MAX_SMOKE_COUNT: int = 6
const DEFAULT_SMOKE_COUNT: int = 3

const MIN_CAPTURE_PRESS: float = 0.0
const MAX_CAPTURE_PRESS: float = 0.30
const DEFAULT_CAPTURE_PRESS: float = 0.10


@export_category("선택 경로")

## 발사 경로 표시선의 길이입니다. 충돌 반지름 비율입니다.
@export_range(MIN_PATH_LENGTH_RATIO, MAX_PATH_LENGTH_RATIO, 0.05)
var path_length_ratio: float = DEFAULT_PATH_LENGTH_RATIO:
	set(value):
		path_length_ratio = clampf(
			value, MIN_PATH_LENGTH_RATIO, MAX_PATH_LENGTH_RATIO
		)
		emit_changed()

@export_range(MIN_PATH_WIDTH, MAX_PATH_WIDTH, 0.5, "suffix:px")
var selected_path_width: float = DEFAULT_SELECTED_WIDTH:
	set(value):
		selected_path_width = clampf(value, MIN_PATH_WIDTH, MAX_PATH_WIDTH)
		emit_changed()

@export_range(MIN_PATH_WIDTH, MAX_PATH_WIDTH, 0.5, "suffix:px")
var unselected_path_width: float = DEFAULT_UNSELECTED_WIDTH:
	set(value):
		unselected_path_width = clampf(value, MIN_PATH_WIDTH, MAX_PATH_WIDTH)
		emit_changed()

## 비선택 경로의 밝기입니다. 0 이면 아예 안 그립니다.
@export_range(MIN_UNSELECTED_ALPHA, MAX_UNSELECTED_ALPHA, 0.01)
var unselected_path_alpha: float = DEFAULT_UNSELECTED_ALPHA:
	set(value):
		unselected_path_alpha = clampf(
			value, MIN_UNSELECTED_ALPHA, MAX_UNSELECTED_ALPHA
		)
		emit_changed()

@export var selected_path_color := Color(0.96, 0.86, 0.52, 0.85):
	set(value):
		selected_path_color = value
		emit_changed()


@export_category("포획 · 발사")

## 포획 시 받침대가 눌리는 정도입니다. 충돌 반지름 비율로 링을 좁힙니다.
@export_range(MIN_CAPTURE_PRESS, MAX_CAPTURE_PRESS, 0.01)
var capture_press_ratio: float = DEFAULT_CAPTURE_PRESS:
	set(value):
		capture_press_ratio = clampf(
			value, MIN_CAPTURE_PRESS, MAX_CAPTURE_PRESS
		)
		emit_changed()

## 발사 직후의 굵은 방향 잔상입니다. 길게 끌면 공 경로를 가립니다(3-1).
@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var trail_lifetime: float = DEFAULT_TRAIL_LIFETIME:
	set(value):
		trail_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

## 5-7 절이 "제한된 연기" 를 요구합니다. 많이 쓰지 않습니다.
@export_range(MIN_SMOKE_COUNT, MAX_SMOKE_COUNT, 1)
var smoke_count: int = DEFAULT_SMOKE_COUNT:
	set(value):
		smoke_count = clampi(value, MIN_SMOKE_COUNT, MAX_SMOKE_COUNT)
		emit_changed()

@export var smoke_color := Color(0.72, 0.70, 0.66, 0.45):
	set(value):
		smoke_color = value
		emit_changed()
