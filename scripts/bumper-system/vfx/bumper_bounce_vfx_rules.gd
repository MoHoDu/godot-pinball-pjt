@tool
class_name BumperBounceVfxRules
extends BumperVfxRules
## Bounce 타입 타격 VFX 규칙입니다. `BumperVfxRules` 를 확장합니다.
##
## 기획서 3-3 Bounce: **원형 파동 또는 방향성 방출선.**
## 두 범퍼가 같은 Bounce 지만 형태 강조점이 다릅니다.
## - 용수철 인형(5-3): 굵은 원형 충격선 + 짧은 방향 방출선
## - 장난감 북(5-4): 크게 팽창하는 넓은 원형 파동 + 짧은 주황 잔상
##
## 파동 반지름도 충돌 반지름 비율로 저장합니다.


const MIN_RING_COUNT: int = 0
const MAX_RING_COUNT: int = 3
const DEFAULT_RING_COUNT: int = 1

const MIN_RING_RATIO: float = 0.4
const MAX_RING_RATIO: float = 3.0
const DEFAULT_RING_START_RATIO: float = 0.85
const DEFAULT_RING_END_RATIO: float = 1.55

const MIN_RING_WIDTH: float = 1.0
const MAX_RING_WIDTH: float = 14.0
const DEFAULT_RING_WIDTH: float = 5.0

const DEFAULT_RING_LIFETIME: float = 0.20

const MIN_BURST_COUNT: int = 0
const MAX_BURST_COUNT: int = 8
const DEFAULT_BURST_COUNT: int = 3

const MIN_BURST_LENGTH_RATIO: float = 0.05
const MAX_BURST_LENGTH_RATIO: float = 1.20
const DEFAULT_BURST_LENGTH_RATIO: float = 0.52

const DEFAULT_BURST_LIFETIME: float = 0.16


@export_category("원형 파동")

@export_range(MIN_RING_COUNT, MAX_RING_COUNT, 1) var ring_count: int = DEFAULT_RING_COUNT:
	set(value):
		ring_count = clampi(value, MIN_RING_COUNT, MAX_RING_COUNT)
		emit_changed()

@export_range(MIN_RING_RATIO, MAX_RING_RATIO, 0.05)
var ring_start_ratio: float = DEFAULT_RING_START_RATIO:
	set(value):
		ring_start_ratio = clampf(value, MIN_RING_RATIO, MAX_RING_RATIO)
		emit_changed()

## 끝 반지름입니다. 3-6 절의 "실제 충돌체보다 훨씬 크게 보이는 상시 글로우 금지"에
## 걸리지 않도록 과하게 키우지 않습니다.
@export_range(MIN_RING_RATIO, MAX_RING_RATIO, 0.05)
var ring_end_ratio: float = DEFAULT_RING_END_RATIO:
	set(value):
		ring_end_ratio = clampf(value, MIN_RING_RATIO, MAX_RING_RATIO)
		emit_changed()

@export_range(MIN_RING_WIDTH, MAX_RING_WIDTH, 0.5, "suffix:px")
var ring_width: float = DEFAULT_RING_WIDTH:
	set(value):
		ring_width = clampf(value, MIN_RING_WIDTH, MAX_RING_WIDTH)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var ring_lifetime: float = DEFAULT_RING_LIFETIME:
	set(value):
		ring_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var ring_color := Color(0.95, 0.88, 0.72, 0.75):
	set(value):
		ring_color = value
		emit_changed()


@export_category("방향성 방출선")

## 공이 튕겨 나가는 방향으로 뻗는 짧은 선입니다. 길게 끌면 3-1 절의
## "공의 다음 경로를 가리지 않음" 에 걸립니다.
@export_range(MIN_BURST_COUNT, MAX_BURST_COUNT, 1)
var burst_count: int = DEFAULT_BURST_COUNT:
	set(value):
		burst_count = clampi(value, MIN_BURST_COUNT, MAX_BURST_COUNT)
		emit_changed()

@export_range(MIN_BURST_LENGTH_RATIO, MAX_BURST_LENGTH_RATIO, 0.01)
var burst_length_ratio: float = DEFAULT_BURST_LENGTH_RATIO:
	set(value):
		burst_length_ratio = clampf(
			value, MIN_BURST_LENGTH_RATIO, MAX_BURST_LENGTH_RATIO
		)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var burst_lifetime: float = DEFAULT_BURST_LIFETIME:
	set(value):
		burst_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var burst_color := Color(0.93, 0.66, 0.34, 0.8):
	set(value):
		burst_color = value
		emit_changed()
