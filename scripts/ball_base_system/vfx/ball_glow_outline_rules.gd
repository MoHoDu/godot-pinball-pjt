@tool
class_name BallGlowOutlineRules
extends Resource
## 공 발광 테두리(VFX ①)의 형태·색·반응 규칙입니다.
##
## 길이 값은 모두 공 반지름에 대한 비율로 저장합니다.
## 기획서 44px와 코드 기본값 64px이 다르므로 절대 px을 박아두지 않습니다.


const MIN_RADIUS_RATIO: float = 1.0
const MAX_RADIUS_RATIO: float = 2.0
const DEFAULT_RADIUS_RATIO: float = 1.24

const MIN_WIDTH_RATIO: float = 0.01
const MAX_WIDTH_RATIO: float = 1.0
const DEFAULT_CORE_WIDTH_RATIO: float = 0.059
const DEFAULT_GLOW_WIDTH_RATIO: float = 0.282

const MIN_WOBBLE: float = 0.0
const MAX_WOBBLE: float = 0.2
const DEFAULT_WOBBLE: float = 0.04

const MIN_DRIFT_SPEED: float = 0.0
const MAX_DRIFT_SPEED: float = 6.0
const DEFAULT_DRIFT_SPEED: float = 0.6

const MIN_GAP_HALF_WIDTH: float = 0.0
const MAX_GAP_HALF_WIDTH: float = 0.6
const DEFAULT_GAP_HALF_WIDTH: float = 0.06

const MIN_GAP_SOFTNESS: float = 0.02
const MAX_GAP_SOFTNESS: float = 1.2
const DEFAULT_GAP_SOFTNESS: float = 0.55

const MIN_FLASH_WIDTH_SCALE: float = 1.0
const MAX_FLASH_WIDTH_SCALE: float = 3.0
const DEFAULT_FLASH_WIDTH_SCALE: float = 1.4

const MIN_TIME: float = 0.01
const MAX_TIME: float = 1.0
const DEFAULT_FLASH_HOLD_TIME: float = 0.04
const DEFAULT_FLASH_FADE_TIME: float = 0.18

const DEFAULT_NORMAL_GRADE_STRENGTH: float = 0.45


var _radius_ratio: float = DEFAULT_RADIUS_RATIO
var _core_width_ratio: float = DEFAULT_CORE_WIDTH_RATIO
var _glow_width_ratio: float = DEFAULT_GLOW_WIDTH_RATIO
var _wobble_amount: float = DEFAULT_WOBBLE
var _drift_speed: float = DEFAULT_DRIFT_SPEED
var _gap_half_width: float = DEFAULT_GAP_HALF_WIDTH
var _gap_softness: float = DEFAULT_GAP_SOFTNESS
var _flash_width_scale: float = DEFAULT_FLASH_WIDTH_SCALE
var _flash_hold_time: float = DEFAULT_FLASH_HOLD_TIME
var _flash_fade_time: float = DEFAULT_FLASH_FADE_TIME
var _normal_grade_strength: float = DEFAULT_NORMAL_GRADE_STRENGTH


@export_category("발광 테두리")

@export_group("형태")

## 공 반지름에 대한 링 중심 반지름 비율입니다.
## 기본 1.24는 공 지름 44px 기준 링 외곽이 문서 권장 28~30px에 들어갑니다.
@export_range(1.0, 2.0, 0.01, "suffix:x")
var radius_ratio: float:
	get:
		return _radius_ratio
	set(value):
		_radius_ratio = clampf(value, MIN_RADIUS_RATIO, MAX_RADIUS_RATIO)
		emit_changed()

## 공 반지름에 대한 코어 선 두께 비율입니다.
@export_range(0.01, 1.0, 0.001, "suffix:x")
var core_width_ratio: float:
	get:
		return _core_width_ratio
	set(value):
		_core_width_ratio = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 공 반지름에 대한 글로우 선 두께 비율입니다. 코어보다 넓고 흐립니다.
@export_range(0.01, 1.0, 0.001, "suffix:x")
var glow_width_ratio: float:
	get:
		return _glow_width_ratio
	set(value):
		_glow_width_ratio = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 손그림 느낌을 만드는 반지름 흔들림 폭입니다.
## 고주파를 섞지 않으므로 값을 키워도 원으로 읽힙니다.
@export_range(0.0, 0.2, 0.005)
var wobble_amount: float:
	get:
		return _wobble_amount
	set(value):
		_wobble_amount = clampf(value, MIN_WOBBLE, MAX_WOBBLE)
		emit_changed()

## 링이 도는 각속도입니다. 빛이 원을 따라 흐르는 인상을 만듭니다.
@export_range(0.0, 6.0, 0.05, "suffix:rad/s")
var drift_speed: float:
	get:
		return _drift_speed
	set(value):
		_drift_speed = clampf(value, MIN_DRIFT_SPEED, MAX_DRIFT_SPEED)
		emit_changed()


@export_group("갭")

## 알파가 완전히 0이 되는 구간의 절반 각도입니다.
## 크게 하면 링이 조각난 호로 보여 "반드시 원으로 읽힐 것" 기준에 걸립니다.
@export_range(0.0, 0.6, 0.005, "suffix:rad")
var gap_half_width: float:
	get:
		return _gap_half_width
	set(value):
		_gap_half_width = clampf(value, MIN_GAP_HALF_WIDTH, MAX_GAP_HALF_WIDTH)
		emit_changed()

## 갭 양옆에서 알파가 회복되는 각도입니다. 넓을수록 끊김이 아니라 흐름으로 보입니다.
@export_range(0.02, 1.2, 0.01, "suffix:rad")
var gap_softness: float:
	get:
		return _gap_softness
	set(value):
		_gap_softness = clampf(value, MIN_GAP_SOFTNESS, MAX_GAP_SOFTNESS)
		emit_changed()


@export_group("점등 반응")

## 점등 시 선 두께에 곱하는 배율입니다.
@export_range(1.0, 3.0, 0.05, "suffix:x")
var flash_width_scale: float:
	get:
		return _flash_width_scale
	set(value):
		_flash_width_scale = clampf(
			value,
			MIN_FLASH_WIDTH_SCALE,
			MAX_FLASH_WIDTH_SCALE
		)
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
## 문서의 "일반 타격은 약한 순간 점등 / 정확한 패링은 강한 전체 점등"에 대응합니다.
@export_range(0.0, 1.0, 0.05)
var normal_grade_strength: float:
	get:
		return _normal_grade_strength
	set(value):
		_normal_grade_strength = clampf(value, 0.0, 1.0)
		emit_changed()


@export_group("상태 색")

## 알파 채널이 그대로 링의 불투명도가 됩니다.
## 코어는 공의 아이보리 테두리보다 밝지 않아야 합니다(공 본체가 가독성 1순위).
@export var normal_core_color := Color(0.498, 0.788, 0.706, 0.80)
@export var normal_glow_color := Color(0.310, 0.651, 0.573, 0.44)

@export var combo_core_color := Color(0.498, 0.788, 0.706, 0.92)
@export var combo_glow_color := Color(0.310, 0.651, 0.573, 0.48)

## 점등 색입니다. 금색은 VFX ③ 패링 파동의 언어이므로 테두리에는 쓰지 않습니다.
@export var flash_core_color := Color(0.941, 0.878, 0.765, 1.0)
@export var flash_glow_color := Color(0.498, 0.788, 0.706, 0.78)

@export var curse_core_color := Color(0.690, 0.839, 0.361, 0.70)
@export var curse_glow_color := Color(0.588, 0.424, 0.816, 0.46)

@export var danger_core_color := Color(1.0, 0.588, 0.667, 0.80)
@export var danger_glow_color := Color(0.839, 0.243, 0.376, 0.48)
