@tool
class_name BumperVfxRules
extends Resource
## 범퍼 타격 VFX 의 형태·색·수명 규칙입니다.
##
## 기획서 3-3 절의 타입별 방향 중 **Normal**(작고 단순한 타격선, 재질 중심 반응)을
## 담당합니다. Bounce/Track/Shot 은 형태 언어가 달라 별도 규칙으로 뺍니다.
##
## 길이는 모두 **범퍼 충돌 반지름에 대한 비율**로 저장합니다.
## 범퍼가 88~240px 로 제각각이라 절대 px 을 박아두면 큰 범퍼에서 묻힙니다.
##
## GL Compatibility 렌더러라 GPUParticles 를 못 씁니다. 조각은 `_draw()` 로 그립니다.


const MIN_TICK_COUNT: int = 0
const MAX_TICK_COUNT: int = 6
const DEFAULT_TICK_COUNT: int = 3

const MIN_TICK_LENGTH_RATIO: float = 0.05
const MAX_TICK_LENGTH_RATIO: float = 0.60
const DEFAULT_TICK_LENGTH_RATIO: float = 0.26

const MIN_TICK_WIDTH: float = 1.0
const MAX_TICK_WIDTH: float = 8.0
const DEFAULT_TICK_WIDTH: float = 3.0

const MIN_TICK_SPREAD_DEG: float = 0.0
const MAX_TICK_SPREAD_DEG: float = 90.0
const DEFAULT_TICK_SPREAD_DEG: float = 34.0

## 기획서 5-2: 솜은 작은 조각 3~5 개. 큰 먼지 구름은 금지입니다.
const MIN_CHIP_COUNT: int = 0
const MAX_CHIP_COUNT: int = 8
const DEFAULT_CHIP_COUNT: int = 4

const MIN_CHIP_RADIUS_RATIO: float = 0.02
const MAX_CHIP_RADIUS_RATIO: float = 0.20
const DEFAULT_CHIP_RADIUS_RATIO: float = 0.07

const MIN_CHIP_TRAVEL_RATIO: float = 0.05
const MAX_CHIP_TRAVEL_RATIO: float = 1.20
const DEFAULT_CHIP_TRAVEL_RATIO: float = 0.45

const MIN_LIFETIME: float = 0.04
const MAX_LIFETIME: float = 1.20
const DEFAULT_TICK_LIFETIME: float = 0.12
const DEFAULT_CHIP_LIFETIME: float = 0.26
const DEFAULT_DEBRIS_LIFETIME: float = 0.55

## 파괴는 "폭발이 아니라 장난감이 망가지는 느낌"이라 조각을 크고 적게 씁니다(3-2).
const MIN_DEBRIS_COUNT: int = 0
const MAX_DEBRIS_COUNT: int = 12
const DEFAULT_DEBRIS_COUNT: int = 6

const MIN_TELEGRAPH_AMPLITUDE: float = 0.0
const MAX_TELEGRAPH_AMPLITUDE: float = 0.20
const DEFAULT_TELEGRAPH_AMPLITUDE: float = 0.045

const MIN_TELEGRAPH_HZ: float = 0.5
const MAX_TELEGRAPH_HZ: float = 12.0
const DEFAULT_TELEGRAPH_HZ: float = 5.0


@export_category("타격선")

## 접촉 지점에서 뻗는 짧은 타격선의 개수입니다.
@export_range(MIN_TICK_COUNT, MAX_TICK_COUNT, 1) var tick_count: int = DEFAULT_TICK_COUNT:
	set(value):
		tick_count = clampi(value, MIN_TICK_COUNT, MAX_TICK_COUNT)
		emit_changed()

## 타격선 길이입니다. 범퍼 충돌 반지름에 대한 비율입니다.
@export_range(MIN_TICK_LENGTH_RATIO, MAX_TICK_LENGTH_RATIO, 0.01)
var tick_length_ratio: float = DEFAULT_TICK_LENGTH_RATIO:
	set(value):
		tick_length_ratio = clampf(value, MIN_TICK_LENGTH_RATIO, MAX_TICK_LENGTH_RATIO)
		emit_changed()

@export_range(MIN_TICK_WIDTH, MAX_TICK_WIDTH, 0.5, "suffix:px")
var tick_width: float = DEFAULT_TICK_WIDTH:
	set(value):
		tick_width = clampf(value, MIN_TICK_WIDTH, MAX_TICK_WIDTH)
		emit_changed()

## 접촉 법선을 기준으로 타격선이 벌어지는 각도입니다.
@export_range(MIN_TICK_SPREAD_DEG, MAX_TICK_SPREAD_DEG, 1.0, "suffix:°")
var tick_spread_degrees: float = DEFAULT_TICK_SPREAD_DEG:
	set(value):
		tick_spread_degrees = clampf(
			value, MIN_TICK_SPREAD_DEG, MAX_TICK_SPREAD_DEG
		)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var tick_lifetime: float = DEFAULT_TICK_LIFETIME:
	set(value):
		tick_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var tick_color := Color(0.94, 0.90, 0.80, 0.85):
	set(value):
		tick_color = value
		emit_changed()


@export_category("재질 조각")

## 타격 시 튀는 재질 조각 수입니다. 솜은 3~5 개, 단추는 더 적게 씁니다.
@export_range(MIN_CHIP_COUNT, MAX_CHIP_COUNT, 1) var chip_count: int = DEFAULT_CHIP_COUNT:
	set(value):
		chip_count = clampi(value, MIN_CHIP_COUNT, MAX_CHIP_COUNT)
		emit_changed()

@export_range(MIN_CHIP_RADIUS_RATIO, MAX_CHIP_RADIUS_RATIO, 0.005)
var chip_radius_ratio: float = DEFAULT_CHIP_RADIUS_RATIO:
	set(value):
		chip_radius_ratio = clampf(
			value, MIN_CHIP_RADIUS_RATIO, MAX_CHIP_RADIUS_RATIO
		)
		emit_changed()

@export_range(MIN_CHIP_TRAVEL_RATIO, MAX_CHIP_TRAVEL_RATIO, 0.01)
var chip_travel_ratio: float = DEFAULT_CHIP_TRAVEL_RATIO:
	set(value):
		chip_travel_ratio = clampf(
			value, MIN_CHIP_TRAVEL_RATIO, MAX_CHIP_TRAVEL_RATIO
		)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var chip_lifetime: float = DEFAULT_CHIP_LIFETIME:
	set(value):
		chip_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

## 조각을 별 모양으로 그릴 때의 꼭짓점 수입니다. **0 이면 원**입니다.
##
## 수리 부품 가이드 4-1(별빛 브로치)·4-4(잊혀진 별방울)가 "별 모양 파티클" 을
## 요구합니다. 텍스처를 쓰지 않고 폴리곤으로 그리는 이유는 조각이 화면에서
## 4~6px 라 래스터로 만들면 뭉개지고, 색을 규칙에서 못 바꾸기 때문입니다.
@export_range(0, 8, 1)
var chip_star_points: int = 0:
	set(value):
		chip_star_points = clampi(value, 0, 8)
		emit_changed()

@export var chip_color := Color(0.86, 0.82, 0.72, 0.90):
	set(value):
		chip_color = value
		emit_changed()


@export_category("화려함")

## 선과 원호를 여러 겹으로 그려 만드는 가짜 글로우 세기입니다. 0 이면 끕니다.
##
## GL Compatibility 라 실제 블룸을 못 씁니다. 대신 같은 도형을 **넓고 옅게 →
## 중간 → 좁고 진하게** 세 번 겹쳐 그려 빛나 보이게 합니다. 알파 블렌딩이라
## 겹친 부분이 밝아집니다.
@export_range(0.0, 1.0, 0.05)
var glow_strength: float = 0.55:
	set(value):
		glow_strength = clampf(value, 0.0, 1.0)
		emit_changed()

## 타격 순간 접촉 지점에 터지는 섬광의 크기입니다. 0 이면 끕니다.
@export_range(0.0, 0.8, 0.01)
var flash_radius_ratio: float = 0.30:
	set(value):
		flash_radius_ratio = clampf(value, 0.0, 0.8)
		emit_changed()

@export_range(0.02, 0.60, 0.01, "suffix:s")
var flash_lifetime: float = 0.14:
	set(value):
		flash_lifetime = clampf(value, 0.02, 0.60)
		emit_changed()

@export var flash_color := Color(1.0, 0.96, 0.86, 0.75):
	set(value):
		flash_color = value
		emit_changed()

## 튀는 네 갈래 반짝임의 개수입니다. 별 파티클과 달리 제자리에서 커졌다 사라집니다.
@export_range(0, 6, 1)
var sparkle_count: int = 2:
	set(value):
		sparkle_count = clampi(value, 0, 6)
		emit_changed()

@export_range(0.05, 0.60, 0.01)
var sparkle_radius_ratio: float = 0.22:
	set(value):
		sparkle_radius_ratio = clampf(value, 0.05, 0.60)
		emit_changed()

@export var sparkle_color := Color(1.0, 0.98, 0.90, 0.9):
	set(value):
		sparkle_color = value
		emit_changed()


@export_category("파괴 · 복구 예고")

@export_range(MIN_DEBRIS_COUNT, MAX_DEBRIS_COUNT, 1)
var debris_count: int = DEFAULT_DEBRIS_COUNT:
	set(value):
		debris_count = clampi(value, MIN_DEBRIS_COUNT, MAX_DEBRIS_COUNT)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var debris_lifetime: float = DEFAULT_DEBRIS_LIFETIME:
	set(value):
		debris_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

## 복구 예고의 떨림 폭입니다. 3-2 절이 "아주 약한 떨림"을 요구합니다.
@export_range(MIN_TELEGRAPH_AMPLITUDE, MAX_TELEGRAPH_AMPLITUDE, 0.005)
var telegraph_amplitude_ratio: float = DEFAULT_TELEGRAPH_AMPLITUDE:
	set(value):
		telegraph_amplitude_ratio = clampf(
			value, MIN_TELEGRAPH_AMPLITUDE, MAX_TELEGRAPH_AMPLITUDE
		)
		emit_changed()

@export_range(MIN_TELEGRAPH_HZ, MAX_TELEGRAPH_HZ, 0.5, "suffix:Hz")
var telegraph_hz: float = DEFAULT_TELEGRAPH_HZ:
	set(value):
		telegraph_hz = clampf(value, MIN_TELEGRAPH_HZ, MAX_TELEGRAPH_HZ)
		emit_changed()

@export var telegraph_color := Color(0.80, 0.86, 0.84, 0.45):
	set(value):
		telegraph_color = value
		emit_changed()
