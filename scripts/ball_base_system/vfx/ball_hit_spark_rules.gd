@tool
class_name BallHitSparkRules
extends Resource
## 공 바운스 스파크의 감지·형태·색·수명 규칙입니다.
##
## 공이 벽·플리퍼·범퍼에 튕길 때마다 접촉 지점에 터지는 작은 스파크를 담당합니다.
## 범퍼 타격 VFX(BumperVfxRules)와 같은 형태 언어(타격선 + 조각 + 섬광)를 쓰되,
## 대상이 움직이는 공이라 **속도 변화량(Δv) 기반 감지 규칙**이 추가됩니다.
##
## 길이는 모두 **공 표시 반지름에 대한 비율**로 저장합니다.
## 공이 16~256px 로 변할 수 있어 절대 px 을 박아두면 큰 공에서 묻힙니다.
##
## GL Compatibility 렌더러라 GPUParticles 를 못 씁니다. 전부 `_draw()` 로 그립니다.


const MIN_DELTA_V: float = 40.0
const MAX_DELTA_V: float = 6000.0
const DEFAULT_MIN_BOUNCE_DELTA_V: float = 260.0
const DEFAULT_REFERENCE_DELTA_V: float = 1400.0

const MIN_COOLDOWN: float = 0.0
const MAX_COOLDOWN: float = 0.50
const DEFAULT_COOLDOWN: float = 0.06

const MIN_TICK_COUNT: int = 0
const MAX_TICK_COUNT: int = 24
const DEFAULT_TICK_COUNT: int = 15

## 조각의 모양입니다. 공별 개성(컨셉의 직선/튀김/번짐/4방향/고리파편)은 여기서 갈립니다.
enum ChipShape {
	CIRCLE,		## 원형 (기본)
	DROP,		## 물방울 — 폭발형(고무막)
	BUBBLE,		## 말랑 거품 — 완충형(완충 젤)
	FLAKE,		## 각진 금속 파편 — 정밀형(납심)
	RING,		## 고리 — 혼돈형(속빈 방울눈)
	STAR,		## 4갈래 별 — 혼돈형 보조
	GEAR,		## 톱니 — 안정형(정속 태엽눈)
}

const MIN_LIFETIME: float = 0.04
const MAX_LIFETIME: float = 1.20


@export_category("바운스 감지")

## 스파크를 터뜨리는 최소 속도 변화량입니다. 이보다 약한 접촉(굴러가기 등)은 무시합니다.
@export_range(MIN_DELTA_V, MAX_DELTA_V, 10.0, "suffix:px/s")
var min_bounce_delta_v: float = DEFAULT_MIN_BOUNCE_DELTA_V:
	set(value):
		min_bounce_delta_v = clampf(value, MIN_DELTA_V, MAX_DELTA_V)
		emit_changed()

## 스파크가 최대 크기에 도달하는 속도 변화량입니다. 세게 부딪힐수록 크게 터집니다.
@export_range(MIN_DELTA_V, MAX_DELTA_V, 10.0, "suffix:px/s")
var reference_delta_v: float = DEFAULT_REFERENCE_DELTA_V:
	set(value):
		reference_delta_v = clampf(value, MIN_DELTA_V, MAX_DELTA_V)
		emit_changed()

## 연속 바운스에서 스파크가 기관총처럼 이어지지 않게 하는 최소 간격입니다.
@export_range(MIN_COOLDOWN, MAX_COOLDOWN, 0.01, "suffix:s")
var cooldown: float = DEFAULT_COOLDOWN:
	set(value):
		cooldown = clampf(value, MIN_COOLDOWN, MAX_COOLDOWN)
		emit_changed()

## 가장 약한 바운스에서도 유지되는 최소 크기 배율입니다.
@export_range(0.1, 1.0, 0.05)
var min_burst_scale: float = 0.6:
	set(value):
		min_burst_scale = clampf(value, 0.1, 1.0)
		emit_changed()


@export_category("타격선")

## 접촉 지점에서 튕겨 나가는 방향으로 뻗는 짧은 타격선의 개수입니다.
@export_range(MIN_TICK_COUNT, MAX_TICK_COUNT, 1)
var tick_count: int = DEFAULT_TICK_COUNT:
	set(value):
		tick_count = clampi(value, MIN_TICK_COUNT, MAX_TICK_COUNT)
		emit_changed()

## 타격선 길이입니다. 공 표시 반지름에 대한 비율입니다.
@export_range(0.2, 2.0, 0.05)
var tick_length_ratio: float = 0.95:
	set(value):
		tick_length_ratio = clampf(value, 0.2, 2.0)
		emit_changed()

@export_range(1.0, 8.0, 0.5, "suffix:px")
var tick_width: float = 3.0:
	set(value):
		tick_width = clampf(value, 1.0, 8.0)
		emit_changed()

## 튕겨 나가는 방향을 기준으로 타격선이 벌어지는 각도입니다.
@export_range(0.0, 90.0, 1.0, "suffix:°")
var tick_spread_degrees: float = 75.0:
	set(value):
		tick_spread_degrees = clampf(value, 0.0, 90.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var tick_lifetime: float = 0.16:
	set(value):
		tick_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var tick_color := Color(0.72, 0.92, 0.85, 0.95):
	set(value):
		tick_color = value
		emit_changed()


@export_category("재질 조각")

## 타격 시 튀어 나가는 작은 조각 수입니다.
@export_range(0, 32, 1)
var chip_count: int = 20:
	set(value):
		chip_count = clampi(value, 0, 32)
		emit_changed()

## 조각의 기본 모양입니다.
@export var chip_shape: ChipShape = ChipShape.CIRCLE:
	set(value):
		chip_shape = value
		emit_changed()

## 홀수 번째 조각에 섞을 두 번째 모양입니다. 기본 모양과 같으면 섞지 않습니다.
@export var chip_shape_secondary: ChipShape = ChipShape.CIRCLE:
	set(value):
		chip_shape_secondary = value
		emit_changed()

## 조각 크기·비거리의 무작위 편차입니다. 0이면 전부 균일(정속형), 1이면 최대 편차(혼돈형).
@export_range(0.0, 1.0, 0.05)
var chip_travel_jitter: float = 0.4:
	set(value):
		chip_travel_jitter = clampf(value, 0.0, 1.0)
		emit_changed()

## 조각 시작점을 접촉면을 따라 흩뿌리는 반경입니다. 공 표시 반지름에 대한 비율입니다.
## 0이면 전부 한 점에서 나와 뭉쳐 보이고, 클수록 넓게 흩뿌려집니다.
@export_range(0.0, 2.0, 0.05)
var chip_scatter_ratio: float = 0.6:
	set(value):
		chip_scatter_ratio = clampf(value, 0.0, 2.0)
		emit_changed()

## 조각 크기입니다. 공 표시 반지름에 대한 비율입니다.
@export_range(0.03, 0.35, 0.01)
var chip_radius_ratio: float = 0.14:
	set(value):
		chip_radius_ratio = clampf(value, 0.03, 0.35)
		emit_changed()

## 조각이 날아가는 거리입니다. 공 표시 반지름에 대한 비율입니다.
@export_range(0.2, 3.0, 0.05)
var chip_travel_ratio: float = 1.8:
	set(value):
		chip_travel_ratio = clampf(value, 0.2, 3.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var chip_lifetime: float = 0.38:
	set(value):
		chip_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var chip_color := Color(0.498, 0.788, 0.706, 0.9):
	set(value):
		chip_color = value
		emit_changed()


@export_category("섬광 · 글로우")

## 타격 순간 접촉 지점에 터지는 섬광의 크기입니다. 공 표시 반지름 비율, 0 이면 끕니다.
@export_range(0.0, 1.5, 0.01)
var flash_radius_ratio: float = 0.6:
	set(value):
		flash_radius_ratio = clampf(value, 0.0, 1.5)
		emit_changed()

@export_range(0.02, 0.60, 0.01, "suffix:s")
var flash_lifetime: float = 0.10:
	set(value):
		flash_lifetime = clampf(value, 0.02, 0.60)
		emit_changed()

@export var flash_color := Color(0.941, 0.878, 0.765, 0.8):
	set(value):
		flash_color = value
		emit_changed()

## 선을 여러 겹으로 그려 만드는 가짜 글로우 세기입니다. 0 이면 끕니다.
@export_range(0.0, 1.0, 0.05)
var glow_strength: float = 0.7:
	set(value):
		glow_strength = clampf(value, 0.0, 1.0)
		emit_changed()
