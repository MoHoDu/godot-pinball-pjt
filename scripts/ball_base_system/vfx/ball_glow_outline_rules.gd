@tool
class_name BallGlowOutlineRules
extends Resource
## 공 발광 테두리(VFX ①) — "마법의 안개 오라"의 형태·색·반응 규칙입니다.
##
## 길이 값은 모두 공 반지름에 대한 비율로 저장합니다.
## 기획서 44px와 코드 기본값 64px이 다르므로 절대 px을 박아두지 않습니다.
##
## 2026-08-03 리디자인: Line2D 2겹(선) -> 셰이더(면).
## 안개는 선이 아니라 면이라 Line2D로는 표현할 수 없습니다.
## 갭(gap_half_width / gap_softness)은 링 전용 개념이라 삭제했습니다.


const MIN_RADIUS_RATIO: float = 1.0
const MAX_RADIUS_RATIO: float = 3.0
## 공 반지름 22px 기준 외곽 40px. 2026-08-03 형락님이 3안 중 안 B로 확정했습니다.
const DEFAULT_RADIUS_RATIO: float = 1.818

const MIN_PEAK_ALPHA: float = 0.05
const MAX_PEAK_ALPHA: float = 1.0
const DEFAULT_PEAK_ALPHA: float = 0.60

const MIN_BAND_COUNT: int = 2
const MAX_BAND_COUNT: int = 12
const DEFAULT_BAND_COUNT: int = 5

const MIN_FALLOFF_EXP: float = 0.3
const MAX_FALLOFF_EXP: float = 3.0
const DEFAULT_FALLOFF_EXP: float = 0.85

const MIN_PLUME: float = 0.0
const MAX_PLUME: float = 0.6
const DEFAULT_PLUME: float = 0.14

const MIN_LOBES: int = 2
const MAX_LOBES: int = 8
const DEFAULT_PLUME_LOBES: int = 5

const MIN_WISP: float = 0.0
const MAX_WISP: float = 1.0
const DEFAULT_WISP: float = 0.75

const MIN_WISP_LOBES: int = 3
const MAX_WISP_LOBES: int = 24
const DEFAULT_WISP_LOBES: int = 11

const MIN_WISP_RADIAL: int = 1
const MAX_WISP_RADIAL: int = 6
const DEFAULT_WISP_RADIAL: int = 1

const MIN_INNER_BLOOM: float = 0.0
const MAX_INNER_BLOOM: float = 1.0
const DEFAULT_INNER_BLOOM: float = 0.30

const MIN_GAZE_STRETCH: float = 0.0
const MAX_GAZE_STRETCH: float = 0.5
const DEFAULT_GAZE_STRETCH: float = 0.10

const MIN_CORE_ALPHA: float = 0.0
const MAX_CORE_ALPHA: float = 1.0
const DEFAULT_CORE_ALPHA: float = 0.72

const MIN_WIDTH_RATIO: float = 0.01
const MAX_WIDTH_RATIO: float = 0.5
const DEFAULT_CORE_WIDTH_RATIO: float = 0.062

const MIN_WOBBLE: float = 0.0
const MAX_WOBBLE: float = 0.2
const DEFAULT_WOBBLE: float = 0.05

const MIN_DRIFT_SPEED: float = 0.0
const MAX_DRIFT_SPEED: float = 6.0
const DEFAULT_DRIFT_SPEED: float = 0.6

const MIN_OUTER_DARKEN: float = 0.1
const MAX_OUTER_DARKEN: float = 1.0
## 바깥 색은 안개 색을 어둡게 해서 만듭니다. 상태마다 색을 3개씩 두면 손댈 곳이 늘어납니다.
const DEFAULT_OUTER_DARKEN: float = 0.58

const MIN_FLASH_SCALE: float = 1.0
const MAX_FLASH_SCALE: float = 3.0
const DEFAULT_FLASH_ALPHA_SCALE: float = 1.30

const MIN_TIME: float = 0.01
const MAX_TIME: float = 1.0
const DEFAULT_FLASH_HOLD_TIME: float = 0.04
const DEFAULT_FLASH_FADE_TIME: float = 0.18

const DEFAULT_NORMAL_GRADE_STRENGTH: float = 0.45


var _radius_ratio: float = DEFAULT_RADIUS_RATIO
var _peak_alpha: float = DEFAULT_PEAK_ALPHA
var _band_count: int = DEFAULT_BAND_COUNT
var _falloff_exp: float = DEFAULT_FALLOFF_EXP
var _plume_amount: float = DEFAULT_PLUME
var _plume_lobes: int = DEFAULT_PLUME_LOBES
var _wisp_amount: float = DEFAULT_WISP
var _wisp_lobes: int = DEFAULT_WISP_LOBES
var _wisp_radial: int = DEFAULT_WISP_RADIAL
var _inner_bloom: float = DEFAULT_INNER_BLOOM
var _gaze_stretch: float = DEFAULT_GAZE_STRETCH
var _core_alpha: float = DEFAULT_CORE_ALPHA
var _core_width_ratio: float = DEFAULT_CORE_WIDTH_RATIO
var _wobble_amount: float = DEFAULT_WOBBLE
var _drift_speed: float = DEFAULT_DRIFT_SPEED
var _outer_darken: float = DEFAULT_OUTER_DARKEN
var _flash_alpha_scale: float = DEFAULT_FLASH_ALPHA_SCALE
var _flash_hold_time: float = DEFAULT_FLASH_HOLD_TIME
var _flash_fade_time: float = DEFAULT_FLASH_FADE_TIME
var _normal_grade_strength: float = DEFAULT_NORMAL_GRADE_STRENGTH


@export_category("안개 오라")

@export_group("형태")

## 공 반지름에 대한 안개 최대 도달 반경의 비율입니다.
## 기본 1.818은 공 지름 44px 기준 외곽 40px(전체 지름 80px)입니다.
@export_range(1.0, 3.0, 0.001, "suffix:x")
var radius_ratio: float:
	get:
		return _radius_ratio
	set(value):
		_radius_ratio = clampf(value, MIN_RADIUS_RATIO, MAX_RADIUS_RATIO)
		emit_changed()

## 안개가 가장 진한 곳(공 표면 바로 바깥)의 알파입니다.
@export_range(0.05, 1.0, 0.01)
var peak_alpha: float:
	get:
		return _peak_alpha
	set(value):
		_peak_alpha = clampf(value, MIN_PEAK_ALPHA, MAX_PEAK_ALPHA)
		emit_changed()

## 명도 단차 수입니다. 다크 카툰의 핵심이라 이 값이 크면 매끈한 네온 글로우가 됩니다.
@export_range(2, 12, 1)
var band_count: int:
	get:
		return _band_count
	set(value):
		_band_count = clampi(value, MIN_BAND_COUNT, MAX_BAND_COUNT)
		emit_changed()

## 클수록 바깥이 빨리 옅어집니다. 1.0 미만이면 안개가 멀리까지 은은하게 깔립니다.
@export_range(0.3, 3.0, 0.01)
var falloff_exp: float:
	get:
		return _falloff_exp
	set(value):
		_falloff_exp = clampf(value, MIN_FALLOFF_EXP, MAX_FALLOFF_EXP)
		emit_changed()

## 각도별로 안개가 뻗는 길이의 편차입니다.
## 키우면 실루엣이 울퉁불퉁해져 "반드시 원으로 읽혀야 함" 기준에 걸립니다.
@export_range(0.0, 0.6, 0.01)
var plume_amount: float:
	get:
		return _plume_amount
	set(value):
		_plume_amount = clampf(value, MIN_PLUME, MAX_PLUME)
		emit_changed()

## 혓바닥 개수입니다. 저주파여야 44px에서 읽힙니다.
@export_range(2, 8, 1)
var plume_lobes: int:
	get:
		return _plume_lobes
	set(value):
		_plume_lobes = clampi(value, MIN_LOBES, MAX_LOBES)
		emit_changed()


@export_group("안개 결")

## 방사형 결(안개 가닥)의 세기입니다. 0이면 매끈한 글로우가 됩니다.
@export_range(0.0, 1.0, 0.01)
var wisp_amount: float:
	get:
		return _wisp_amount
	set(value):
		_wisp_amount = clampf(value, MIN_WISP, MAX_WISP)
		emit_changed()

## 결의 개수(각도 분할)입니다.
@export_range(3, 24, 1)
var wisp_lobes: int:
	get:
		return _wisp_lobes
	set(value):
		_wisp_lobes = clampi(value, MIN_WISP_LOBES, MAX_WISP_LOBES)
		emit_changed()

## 반경 분할입니다. 작을수록 결이 반경 방향으로 길쭉해집니다.
@export_range(1, 6, 1)
var wisp_radial: int:
	get:
		return _wisp_radial
	set(value):
		_wisp_radial = clampi(value, MIN_WISP_RADIAL, MAX_WISP_RADIAL)
		emit_changed()

## 공 바로 바깥을 한 겹 더 진하게 만듭니다.
@export_range(0.0, 1.0, 0.01)
var inner_bloom: float:
	get:
		return _inner_bloom
	set(value):
		_inner_bloom = clampf(value, MIN_INNER_BLOOM, MAX_INNER_BLOOM)
		emit_changed()

## 진행 방향으로 안개를 늘리는 정도입니다. 사우론의 눈처럼 방향성을 줍니다.
@export_range(0.0, 0.5, 0.01)
var gaze_stretch: float:
	get:
		return _gaze_stretch
	set(value):
		_gaze_stretch = clampf(value, MIN_GAZE_STRETCH, MAX_GAZE_STRETCH)
		emit_changed()

## 안개가 흐르는 속도입니다. 노드를 돌리지 않고 결의 위상만 밀어 소용돌이를 만듭니다.
@export_range(0.0, 6.0, 0.05, "suffix:rad/s")
var drift_speed: float:
	get:
		return _drift_speed
	set(value):
		_drift_speed = clampf(value, MIN_DRIFT_SPEED, MAX_DRIFT_SPEED)
		emit_changed()


@export_group("코어 링")

## 공 실루엣을 못 박는 얇고 밝은 테두리의 알파입니다.
## 이게 없으면 안개만 남아 "전체 형태가 원으로 읽혀야 함" 기준에 걸립니다.
@export_range(0.0, 1.0, 0.01)
var core_alpha: float:
	get:
		return _core_alpha
	set(value):
		_core_alpha = clampf(value, MIN_CORE_ALPHA, MAX_CORE_ALPHA)
		emit_changed()

## 공 반지름에 대한 코어 링 두께 비율입니다.
@export_range(0.01, 0.5, 0.001, "suffix:x")
var core_width_ratio: float:
	get:
		return _core_width_ratio
	set(value):
		_core_width_ratio = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 코어 링의 손그림 느낌 흔들림입니다. 저주파만 섞어 원으로 읽히게 유지합니다.
@export_range(0.0, 0.2, 0.005)
var wobble_amount: float:
	get:
		return _wobble_amount
	set(value):
		_wobble_amount = clampf(value, MIN_WOBBLE, MAX_WOBBLE)
		emit_changed()


@export_group("점등 반응")

## 점등 시 안개·코어 알파에 곱하는 배율입니다.
@export_range(1.0, 3.0, 0.05, "suffix:x")
var flash_alpha_scale: float:
	get:
		return _flash_alpha_scale
	set(value):
		_flash_alpha_scale = clampf(value, MIN_FLASH_SCALE, MAX_FLASH_SCALE)
		emit_changed()

## 최대 점등을 유지하는 시간입니다.
@export_range(0.01, 1.0, 0.01, "suffix:s")
var flash_hold_time: float:
	get:
		return _flash_hold_time
	set(value):
		_flash_hold_time = clampf(value, MIN_TIME, MAX_TIME)
		emit_changed()

## 점등이 원래 상태로 돌아오는 시간입니다.
@export_range(0.01, 1.0, 0.01, "suffix:s")
var flash_fade_time: float:
	get:
		return _flash_fade_time
	set(value):
		_flash_fade_time = clampf(value, MIN_TIME, MAX_TIME)
		emit_changed()

## 일반 패링의 점등 세기입니다. 정확한 패링은 항상 1.0으로 점등합니다.
@export_range(0.0, 1.0, 0.05)
var normal_grade_strength: float:
	get:
		return _normal_grade_strength
	set(value):
		_normal_grade_strength = clampf(value, 0.0, 1.0)
		emit_changed()


@export_group("상태 색")

## 바깥 색은 안개 색에 이 배율을 곱해 만듭니다.
## 상태마다 색을 3개씩 두지 않기 위한 장치입니다.
@export_range(0.1, 1.0, 0.01, "suffix:x")
var outer_darken: float:
	get:
		return _outer_darken
	set(value):
		_outer_darken = clampf(value, MIN_OUTER_DARKEN, MAX_OUTER_DARKEN)
		emit_changed()

## 알파는 그대로 세기 배율로 쓰입니다.
## 코어는 공의 아이보리 테두리보다 밝지 않아야 합니다(공 본체가 가독성 1순위).
@export var normal_core_color := Color(0.498, 0.788, 0.706, 0.80)
@export var normal_mist_color := Color(0.310, 0.651, 0.573, 1.0)

@export var combo_core_color := Color(0.498, 0.788, 0.706, 0.92)
@export var combo_mist_color := Color(0.310, 0.651, 0.573, 1.0)

## 점등 색입니다. 금색은 VFX ③ 패링 파동의 언어이므로 테두리에는 쓰지 않습니다.
@export var flash_core_color := Color(0.941, 0.878, 0.765, 1.0)
@export var flash_mist_color := Color(0.608, 0.851, 0.769, 1.0)

@export var curse_core_color := Color(0.690, 0.839, 0.361, 0.70)
@export var curse_mist_color := Color(0.541, 0.388, 0.788, 1.0)

@export var danger_core_color := Color(1.0, 0.588, 0.667, 0.80)
@export var danger_mist_color := Color(0.839, 0.243, 0.376, 1.0)
