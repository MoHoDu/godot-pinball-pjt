@tool
class_name BallTrailRules
extends Resource
## 공 이동 꼬리(VFX ②)의 형태·길이·반응 규칙입니다.
##
## 길이 값은 모두 공 반지름에 대한 비율로 저장합니다.
## 기획서 44px와 코드 기본값 64px이 다르므로 절대 px을 박아두지 않습니다.
##
## 2026-08-03 형락님 확정(안 D1): 공 44px 기준 길이 140px,
## 레이저 뿌리 9px / 블룸 뿌리 60px. 밝기는 길이 방향 4단 계단.


## 공 반지름에 대한 꼬리 길이 비율입니다. 6.364 x 22px = 140px.
## 비주얼 가이드의 60~100px을 의도적으로 초과합니다.
## 발광 테두리(VFX ①)가 40px까지 퍼져 꼬리 뿌리를 덮기 때문이고,
## 60px로 줄이면 알파 무게중심이 공 앞쪽에 잡혀 진행 방향이 거꾸로 읽힙니다.
const MIN_LENGTH_RATIO: float = 1.0
const MAX_LENGTH_RATIO: float = 12.0
const DEFAULT_LENGTH_RATIO: float = 6.364

const MIN_WIDTH_RATIO: float = 0.001
const MAX_WIDTH_RATIO: float = 8.0
## 블룸 뿌리 반폭 / 공 반지름. 1.35 x 22 x 2 = 59.4px (전체 폭)
## 2026-08-03 두께 3배(4.05)를 시도했다가 인게임에서 더 나빠져 되돌렸다.
## 178px 은 공 지름의 4배라 꼬리가 주인공이 되고 조작 대상을 가린다.
const DEFAULT_BLOOM_ROOT: float = 1.35
const DEFAULT_BLOOM_TIP: float = 0.02
## 레이저 뿌리 반폭 / 공 반지름. 0.20 x 22 x 2 = 8.8px (전체 폭)
const DEFAULT_CORE_ROOT: float = 0.20
const DEFAULT_CORE_TIP: float = 0.004

## 1.0 이면 옆면이 직선 = 삼각형(올챙이 꼬리). 1보다 크면 안쪽으로 휘어 물방울이 된다.
const MIN_POWER: float = 0.5
const MAX_POWER: float = 4.0
const DEFAULT_BLOOM_POWER: float = 1.0
const DEFAULT_CORE_POWER: float = 1.0

const MIN_STEPS: int = 2
const MAX_STEPS: int = 8
const DEFAULT_STEPS: int = 4

const MIN_GAMMA: float = 0.5
const MAX_GAMMA: float = 3.0
const DEFAULT_STEP_GAMMA: float = 1.15

## 레이저를 블룸보다 몇 계단 먼저 끄는지입니다.
## 1이면 마지막 계단은 블룸만 남습니다 — 스케치의 "투명 상태의 블룸" 구간입니다.
const MIN_CORE_DROP: int = 0
const MAX_CORE_DROP: int = 3
const DEFAULT_CORE_STEP_DROP: int = 1

const MIN_ALPHA: float = 0.0
const MAX_ALPHA: float = 1.0
const DEFAULT_BLOOM_ALPHA: float = 0.80
const DEFAULT_CORE_ALPHA: float = 0.95

## 이 속도에서 꼬리가 기준 길이가 됩니다.
const MIN_REF_SPEED: float = 100.0
const MAX_REF_SPEED: float = 4000.0
const DEFAULT_REFERENCE_SPEED: float = 900.0

## 속도로 길이를 조절하는 범위입니다. 문서 "속도에 따라 단계적으로 조절".
const DEFAULT_MIN_LENGTH_SCALE: float = 0.45
const DEFAULT_MAX_LENGTH_SCALE: float = 1.30

## 이 속도 미만이면 꼬리를 감춥니다.
## 문서: "발사 대기·정지 중에는 꼬리를 표시하지 않는다".
const MIN_HIDE_SPEED: float = 0.0
const MAX_HIDE_SPEED: float = 500.0
const DEFAULT_HIDE_BELOW_SPEED: float = 60.0

## ★ 점 하나가 살아 있는 시간입니다.
## 이게 없으면 공이 느려졌을 때 옛 점이 월드 좌표에 그대로 얼어붙어 잔상이 남습니다.
## 거리 기준으로만 자르면 공이 멈춘 동안에는 누적 길이가 줄지 않기 때문입니다.
const MIN_LIFETIME: float = 0.05
const MAX_LIFETIME: float = 1.0
const DEFAULT_POINT_LIFETIME: float = 0.22

## 나타나고 사라지는 시간입니다. 갑자기 켜지면 깜빡임으로 보입니다.
const DEFAULT_FADE_IN_TIME: float = 0.05
const DEFAULT_FADE_OUT_TIME: float = 0.12

## 궤적을 몇 개의 점으로 담을지입니다. 많을수록 곡선이 부드럽지만 비용이 듭니다.
const MIN_POINTS: int = 8
const MAX_POINTS: int = 64
const DEFAULT_POINT_COUNT: int = 24


var _length_ratio: float = DEFAULT_LENGTH_RATIO
var _bloom_root: float = DEFAULT_BLOOM_ROOT
var _bloom_tip: float = DEFAULT_BLOOM_TIP
var _bloom_power: float = DEFAULT_BLOOM_POWER
var _core_root: float = DEFAULT_CORE_ROOT
var _core_tip: float = DEFAULT_CORE_TIP
var _core_power: float = DEFAULT_CORE_POWER
var _band_steps: int = DEFAULT_STEPS
var _step_gamma: float = DEFAULT_STEP_GAMMA
var _core_step_drop: int = DEFAULT_CORE_STEP_DROP
var _bloom_alpha: float = DEFAULT_BLOOM_ALPHA
var _core_alpha: float = DEFAULT_CORE_ALPHA
var _reference_speed: float = DEFAULT_REFERENCE_SPEED
var _min_length_scale: float = DEFAULT_MIN_LENGTH_SCALE
var _max_length_scale: float = DEFAULT_MAX_LENGTH_SCALE
var _hide_below_speed: float = DEFAULT_HIDE_BELOW_SPEED
var _fade_in_time: float = DEFAULT_FADE_IN_TIME
var _fade_out_time: float = DEFAULT_FADE_OUT_TIME
var _point_count: int = DEFAULT_POINT_COUNT
var _point_lifetime: float = DEFAULT_POINT_LIFETIME


@export_category("이동 꼬리")

@export_group("길이")

## 공 반지름에 대한 기준 꼬리 길이 비율입니다.
@export_range(1.0, 12.0, 0.001, "suffix:x")
var length_ratio: float:
	get:
		return _length_ratio
	set(value):
		_length_ratio = clampf(value, MIN_LENGTH_RATIO, MAX_LENGTH_RATIO)
		emit_changed()

## 이 속도에서 꼬리가 기준 길이가 됩니다.
@export_range(100.0, 4000.0, 10.0, "suffix:px/s")
var reference_speed: float:
	get:
		return _reference_speed
	set(value):
		_reference_speed = clampf(value, MIN_REF_SPEED, MAX_REF_SPEED)
		emit_changed()

## 속도가 느릴 때의 길이 하한 배율입니다.
@export_range(0.1, 1.0, 0.01, "suffix:x")
var min_length_scale: float:
	get:
		return _min_length_scale
	set(value):
		_min_length_scale = clampf(value, 0.1, 1.0)
		emit_changed()

## 고속에서의 길이 상한 배율입니다. 너무 키우면 이전 경로와 현재 위치가 혼동됩니다.
@export_range(1.0, 3.0, 0.01, "suffix:x")
var max_length_scale: float:
	get:
		return _max_length_scale
	set(value):
		_max_length_scale = clampf(value, 1.0, 3.0)
		emit_changed()

## 이 속도 미만이면 꼬리를 감춥니다.
@export_range(0.0, 500.0, 1.0, "suffix:px/s")
var hide_below_speed: float:
	get:
		return _hide_below_speed
	set(value):
		_hide_below_speed = clampf(value, MIN_HIDE_SPEED, MAX_HIDE_SPEED)
		emit_changed()

## 궤적을 담는 점의 개수입니다.
@export_range(8, 64, 1)
var point_count: int:
	get:
		return _point_count
	set(value):
		_point_count = clampi(value, MIN_POINTS, MAX_POINTS)
		emit_changed()


## 점 하나가 살아 있는 시간입니다. 짧을수록 꼬리가 공에 빨리 붙습니다.
@export_range(0.05, 1.0, 0.01, "suffix:s")
var point_lifetime: float:
	get:
		return _point_lifetime
	set(value):
		_point_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()


@export_group("② 블룸")

## 블룸 뿌리 반폭 / 공 반지름. 1.35면 공 44px 기준 전체 폭 약 60px입니다.
@export_range(0.001, 8.0, 0.001, "suffix:x")
var bloom_root: float:
	get:
		return _bloom_root
	set(value):
		_bloom_root = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 블룸 끝 반폭 / 공 반지름입니다.
@export_range(0.001, 8.0, 0.001, "suffix:x")
var bloom_tip: float:
	get:
		return _bloom_tip
	set(value):
		_bloom_tip = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 블룸 테이퍼 곡률입니다.
@export_range(0.5, 4.0, 0.01)
var bloom_power: float:
	get:
		return _bloom_power
	set(value):
		_bloom_power = clampf(value, MIN_POWER, MAX_POWER)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var bloom_alpha: float:
	get:
		return _bloom_alpha
	set(value):
		_bloom_alpha = clampf(value, MIN_ALPHA, MAX_ALPHA)
		emit_changed()


@export_group("① 레이저")

## 레이저 뿌리 반폭 / 공 반지름. 0.20이면 공 44px 기준 전체 폭 약 9px입니다.
## 블룸 대비 2.5배 이상 좁아야 "감싸는 2겹"으로 읽힙니다.
@export_range(0.001, 8.0, 0.001, "suffix:x")
var core_root: float:
	get:
		return _core_root
	set(value):
		_core_root = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

@export_range(0.001, 8.0, 0.001, "suffix:x")
var core_tip: float:
	get:
		return _core_tip
	set(value):
		_core_tip = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

@export_range(0.5, 4.0, 0.01)
var core_power: float:
	get:
		return _core_power
	set(value):
		_core_power = clampf(value, MIN_POWER, MAX_POWER)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var core_alpha: float:
	get:
		return _core_alpha
	set(value):
		_core_alpha = clampf(value, MIN_ALPHA, MAX_ALPHA)
		emit_changed()


@export_group("밝기 계단")

## 길이 방향 밝기 계단 수입니다. 형락님 스케치의 4단입니다.
@export_range(2, 8, 1)
var band_steps: int:
	get:
		return _band_steps
	set(value):
		_band_steps = clampi(value, MIN_STEPS, MAX_STEPS)
		emit_changed()

## 계단 간격의 곡률입니다. 크면 공 쪽에 밝은 구간이 몰립니다.
@export_range(0.5, 3.0, 0.01)
var step_gamma: float:
	get:
		return _step_gamma
	set(value):
		_step_gamma = clampf(value, MIN_GAMMA, MAX_GAMMA)
		emit_changed()


## 레이저를 블룸보다 몇 계단 먼저 끌지입니다. 1이면 꼬리 끝은 블룸만 남습니다.
@export_range(0, 3, 1)
var core_step_drop: int:
	get:
		return _core_step_drop
	set(value):
		_core_step_drop = clampi(value, MIN_CORE_DROP, MAX_CORE_DROP)
		emit_changed()


@export_group("전환")

@export_range(0.01, 1.0, 0.01, "suffix:s")
var fade_in_time: float:
	get:
		return _fade_in_time
	set(value):
		_fade_in_time = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01, "suffix:s")
var fade_out_time: float:
	get:
		return _fade_out_time
	set(value):
		_fade_out_time = clampf(value, 0.01, 1.0)
		emit_changed()


@export_group("색")

## 레이저는 순백에서 아이보리로 갑니다.
## ★ 순백(휘도 1.0)은 공 본체(0.99)보다 밝아 가이드의 가독성 우선순위를 넘습니다.
##   2026-08-03 형락님이 그대로 두기로 확정했습니다.
##   검수에서 걸리면 laser_hot 을 아이보리(0.941, 0.878, 0.765)로 내리면 규칙을 지킵니다.
@export var laser_hot := Color(1.0, 1.0, 0.996, 1.0)
@export var laser_tip := Color(0.941, 0.878, 0.765, 1.0)

## 블룸은 발광 테두리(VFX ①)와 같은 청록입니다. 두 VFX의 색은 통일합니다.
@export var bloom_in := Color(0.498, 0.788, 0.706, 1.0)
@export var bloom_mid := Color(0.310, 0.651, 0.573, 1.0)
@export var bloom_out := Color(0.180, 0.378, 0.332, 1.0)
