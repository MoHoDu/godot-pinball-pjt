@tool
class_name BallParryWaveRules
extends Resource
## 패링 성공 원형 파동(VFX ③)의 형태·시간·색 규칙입니다.
##
## 길이 값은 모두 공 반지름에 대한 비율로 저장합니다.
## 기획서 44px와 코드 기본값 64px이 다르므로 절대 px을 박아두지 않습니다.
## 괄호 안의 px은 공 지름 44px(반지름 22px) 기준 환산값입니다.
##
## 2026-08-04 형락님이 3안 중 **안 A(문서 그대로)** 로 확정했습니다.
## 안 A = 중심 플래시가 꽉 찬 원, 방사선 균등, 중심 이동 없음, 링 대칭.
##
## 같은 날 인게임 확인 후 **가시성 개정**이 들어갔습니다.
## "가시성이 너무 없어 잘 안 보인다" → 지속 0.16→0.26s, 링 6→9px, 종료 105→95px.
##
## ★ 종료 반지름을 **줄인 것**이 핵심입니다. 같은 잉크를 좁은 둘레에 모아야 선이 굵게 읽힙니다.
##   크게 만드는 것과 잘 보이는 것은 반대 방향이었습니다.
##
## 지속 0.26s 와 링 9px 은 가이드 권장(0.12~0.20 / 4~8)을 **의도적으로 넘긴 값**입니다.
## 안개 오라 40px(문서 28~30), 이동 꼬리 140px(문서 60~100)과 같은 종류의 결정입니다.


## 비주얼 가이드 3-5 권장 범위입니다. 테스트가 이 값으로 이탈을 잡습니다.
const DOC_START_RADIUS_PX := Vector2(25.0, 30.0)
const DOC_END_RADIUS_PX := Vector2(90.0, 120.0)
const DOC_DURATION := Vector2(0.12, 0.20)
const DOC_FLASH_TIME := Vector2(0.03, 0.06)
const DOC_RING_WIDTH_PX := Vector2(4.0, 8.0)
const DOC_CENTER_SHIFT_PX := Vector2(2.0, 5.0)
## 위 px 범위를 비율로 환산할 때 쓰는 기준 반지름입니다.
const DOC_BALL_RADIUS := 22.0

const MIN_RADIUS_RATIO := 0.5
const MAX_RADIUS_RATIO := 12.0
## 27px. 권장 25~30의 중앙 부근입니다.
const DEFAULT_START_RADIUS_RATIO := 1.227
## 95px. 권장 90~120의 아래쪽. 가시성 개정에서 105 → 95 로 줄였습니다.
const DEFAULT_END_RADIUS_RATIO := 4.318

const MIN_WIDTH_RATIO := 0.02
const MAX_WIDTH_RATIO := 2.0
## 9px. 권장 4~8 **초과**. 가시성 개정에서 6 → 9 로 올렸습니다(1.5배 단위).
const DEFAULT_RING_WIDTH_RATIO := 0.409

const MIN_TIME := 0.01
const MAX_TIME := 1.0
## 0.26s. 권장 0.12~0.20 **초과**. 60fps 에서 잘 보이는 구간이 5.9 → 12.3프레임이 됩니다.
const DEFAULT_DURATION := 0.26
## 0.06s. 권장 0.03~0.06의 상한입니다.
const DEFAULT_FLASH_TIME := 0.06

const MIN_EXP := 0.5
const MAX_EXP := 6.0
## 빠르게 커지고 사라져야 한다(가이드 3-5). 1.0이면 등속이라 느리게 읽힙니다.
const DEFAULT_EXPAND_EXP := 1.5
const DEFAULT_FADE_EXP := 1.3

const DEFAULT_RING_WIDTH_SHRINK := 0.12
const DEFAULT_FADE_START := 0.70
const DEFAULT_SUB_DELAY := 0.18
const DEFAULT_SUB_WIDTH_SCALE := 0.5
const DEFAULT_SUB_APPEAR := 0.20

const MIN_SPOKE_COUNT := 0
const MAX_SPOKE_COUNT := 24
const DEFAULT_SPOKE_COUNT := 10
const DEFAULT_SPOKE_INNER_MUL := 1.06
const DEFAULT_SPOKE_OUTER_MUL := 1.26
const DEFAULT_SPOKE_WIDTH_DEG := 2.6
const DEFAULT_SPOKE_APPEAR := 0.05

## 셰이더 루프 상한과 같습니다. 늘리려면 셰이더도 함께 고쳐야 합니다.
const MAX_SPARK_COUNT := 8
const DEFAULT_SPARK_COUNT := 5
## 12px / 4px
const DEFAULT_SPARK_LENGTH_RATIO := 0.545
const DEFAULT_SPARK_WIDTH_RATIO := 0.180
const DEFAULT_SPARK_APPEAR := 0.10
const DEFAULT_SPARK_VANISH := 0.80

const MIN_BAND_COUNT := 2
const MAX_BAND_COUNT := 12
const DEFAULT_BAND_COUNT := 5

const MIN_WOBBLE := 0.0
## 0.05를 넘기면 44px에서 원이 아니라 톱니바퀴로 읽힙니다.
const MAX_WOBBLE := 0.08
const DEFAULT_WOBBLE := 0.022

const MIN_LOBES := 3
const MAX_LOBES := 12
const DEFAULT_WOBBLE_LOBES := 7

const MIN_GAP_COUNT := 0
const MAX_GAP_COUNT := 6
const DEFAULT_GAP_COUNT := 1
const DEFAULT_GAP_WIDTH := 0.10

const MIN_QUAD_PADDING := 1.0
const MAX_QUAD_PADDING := 1.5
## ★ 1.06 이면 별 조각이 쿼드 경계를 스친다. 별은 링보다 바깥에 흩어지므로
##   방사선 끝(spoke_outer_mul)만으로는 여유가 모자란다.
const DEFAULT_QUAD_PADDING := 1.20

const MIN_CONCURRENT := 1
const MAX_CONCURRENT := 16
const DEFAULT_MAX_CONCURRENT := 6


var _start_radius_ratio: float = DEFAULT_START_RADIUS_RATIO
var _end_radius_ratio: float = DEFAULT_END_RADIUS_RATIO
var _duration: float = DEFAULT_DURATION
var _expand_exp: float = DEFAULT_EXPAND_EXP
var _fade_start: float = DEFAULT_FADE_START
var _fade_exp: float = DEFAULT_FADE_EXP
var _ring_width_ratio: float = DEFAULT_RING_WIDTH_RATIO
var _ring_width_shrink: float = DEFAULT_RING_WIDTH_SHRINK
var _sub_delay: float = DEFAULT_SUB_DELAY
var _sub_width_scale: float = DEFAULT_SUB_WIDTH_SCALE
var _sub_appear: float = DEFAULT_SUB_APPEAR
var _spoke_count: int = DEFAULT_SPOKE_COUNT
var _spoke_inner_mul: float = DEFAULT_SPOKE_INNER_MUL
var _spoke_outer_mul: float = DEFAULT_SPOKE_OUTER_MUL
var _spoke_width_deg: float = DEFAULT_SPOKE_WIDTH_DEG
var _spoke_appear: float = DEFAULT_SPOKE_APPEAR
var _spark_count: int = DEFAULT_SPARK_COUNT
var _spark_length_ratio: float = DEFAULT_SPARK_LENGTH_RATIO
var _spark_width_ratio: float = DEFAULT_SPARK_WIDTH_RATIO
var _spark_appear: float = DEFAULT_SPARK_APPEAR
var _spark_vanish: float = DEFAULT_SPARK_VANISH
var _flash_time: float = DEFAULT_FLASH_TIME
var _flash_hollow: bool = false
var _center_shift_ratio: float = 0.0
var _band_count: int = DEFAULT_BAND_COUNT
var _wobble_amount: float = DEFAULT_WOBBLE
var _wobble_lobes: int = DEFAULT_WOBBLE_LOBES
var _gap_count: int = DEFAULT_GAP_COUNT
var _gap_width: float = DEFAULT_GAP_WIDTH
var _quad_padding: float = DEFAULT_QUAD_PADDING
var _max_concurrent: int = DEFAULT_MAX_CONCURRENT


@export_category("패링 원형 파동")

@export_group("크기와 시간")

## 파동이 시작하는 반지름 / 공 반지름입니다. 기본 1.227은 44px 기준 27px입니다.
@export_range(0.5, 12.0, 0.001, "suffix:x")
var start_radius_ratio: float:
	get:
		return _start_radius_ratio
	set(value):
		_start_radius_ratio = clampf(value, MIN_RADIUS_RATIO, MAX_RADIUS_RATIO)
		emit_changed()

## 파동이 끝나는 반지름 / 공 반지름입니다. 기본 4.318은 44px 기준 95px입니다.
@export_range(0.5, 12.0, 0.001, "suffix:x")
var end_radius_ratio: float:
	get:
		return _end_radius_ratio
	set(value):
		_end_radius_ratio = clampf(value, MIN_RADIUS_RATIO, MAX_RADIUS_RATIO)
		emit_changed()

## 파동 전체 지속 시간입니다.
## 다음 공의 이동 방향을 판단해야 하는 시점까지 화면에 남으면 안 됩니다(가이드 3-5).
@export_range(0.01, 1.0, 0.005, "suffix:s")
var duration: float:
	get:
		return _duration
	set(value):
		_duration = clampf(value, MIN_TIME, MAX_TIME)
		emit_changed()

## 확대 곡선의 지수입니다. 클수록 초반에 확 커지고 뒤가 완만해집니다.
@export_range(0.5, 6.0, 0.05)
var expand_exp: float:
	get:
		return _expand_exp
	set(value):
		_expand_exp = clampf(value, MIN_EXP, MAX_EXP)
		emit_changed()

## 소멸이 시작되는 진행도입니다.
@export_range(0.0, 1.0, 0.01)
var fade_start: float:
	get:
		return _fade_start
	set(value):
		_fade_start = clampf(value, 0.0, 1.0)
		emit_changed()

## 소멸 곡선의 지수입니다.
@export_range(0.5, 6.0, 0.05)
var fade_exp: float:
	get:
		return _fade_exp
	set(value):
		_fade_exp = clampf(value, MIN_EXP, MAX_EXP)
		emit_changed()


@export_group("주요 링")

## 주요 링 두께 / 공 반지름입니다. 기본 0.409는 44px 기준 9px입니다.
## 가이드 권장 4~8을 의도적으로 넘긴 값입니다.
@export_range(0.02, 2.0, 0.001, "suffix:x")
var ring_width_ratio: float:
	get:
		return _ring_width_ratio
	set(value):
		_ring_width_ratio = clampf(value, MIN_WIDTH_RATIO, MAX_WIDTH_RATIO)
		emit_changed()

## 링이 커지면서 얇아지는 정도입니다.
## 두께를 고정하면 큰 원에서 선이 아니라 덩어리로 보입니다.
@export_range(0.0, 0.8, 0.01)
var ring_width_shrink: float:
	get:
		return _ring_width_shrink
	set(value):
		_ring_width_shrink = clampf(value, 0.0, 0.8)
		emit_changed()

## 링을 몇 군데 끊을지입니다. "매끈한 네온 원보다 약간 끊어지고 흔들리는 카툰형 원".
@export_range(0, 6, 1)
var gap_count: int:
	get:
		return _gap_count
	set(value):
		_gap_count = clampi(value, MIN_GAP_COUNT, MAX_GAP_COUNT)
		emit_changed()

@export_range(0.02, 0.5, 0.01)
var gap_width: float:
	get:
		return _gap_width
	set(value):
		_gap_width = clampf(value, 0.02, 0.5)
		emit_changed()

## 원의 손그림 흔들림입니다. 0.05를 넘으면 원이 아니라 톱니바퀴로 읽힙니다.
@export_range(0.0, 0.08, 0.001)
var wobble_amount: float:
	get:
		return _wobble_amount
	set(value):
		_wobble_amount = clampf(value, MIN_WOBBLE, MAX_WOBBLE)
		emit_changed()

@export_range(3, 12, 1)
var wobble_lobes: int:
	get:
		return _wobble_lobes
	set(value):
		_wobble_lobes = clampi(value, MIN_LOBES, MAX_LOBES)
		emit_changed()

## 명도 단차 수입니다. 크면 다크 카툰이 아니라 매끈한 네온이 됩니다.
@export_range(2, 12, 1)
var band_count: int:
	get:
		return _band_count
	set(value):
		_band_count = clampi(value, MIN_BAND_COUNT, MAX_BAND_COUNT)
		emit_changed()


@export_group("보조 링")

## 보조 링이 주요 링보다 얼마나 늦게 출발하는지입니다(진행도 기준).
## 가이드 3-5 연출 순서 2단계 "금색 또는 아이보리 보조 링이 뒤따름".
@export_range(0.0, 0.6, 0.01)
var sub_delay: float:
	get:
		return _sub_delay
	set(value):
		_sub_delay = clampf(value, 0.0, 0.6)
		emit_changed()

## 주요 링 두께 대비 보조 링 두께 비율입니다. 가이드가 "얇은 보조 링"이라고 못 박습니다.
@export_range(0.1, 1.0, 0.01, "suffix:x")
var sub_width_scale: float:
	get:
		return _sub_width_scale
	set(value):
		_sub_width_scale = clampf(value, 0.1, 1.0)
		emit_changed()

## 보조 링이 보이기 시작하는 진행도입니다.
@export_range(0.0, 1.0, 0.01)
var sub_appear: float:
	get:
		return _sub_appear
	set(value):
		_sub_appear = clampf(value, 0.0, 1.0)
		emit_changed()


@export_group("방사형 선 · 별 조각")

## 링 주변의 방사형 선 개수입니다. 균등 배치입니다.
## 가시성 개정에서 12개 1.1도 → 10개 2.6도로 바꿨습니다.
## 적고 굵은 쪽이 빠른 연출에서 읽힙니다.
@export_range(0, 24, 1)
var spoke_count: int:
	get:
		return _spoke_count
	set(value):
		_spoke_count = clampi(value, MIN_SPOKE_COUNT, MAX_SPOKE_COUNT)
		emit_changed()

## 방사형 선의 안쪽 끝 / 주요 링 반경입니다.
## 1.0보다 작으면 선이 링을 가로질러 톱니바퀴처럼 보입니다.
@export_range(1.0, 1.5, 0.01, "suffix:x")
var spoke_inner_mul: float:
	get:
		return _spoke_inner_mul
	set(value):
		_spoke_inner_mul = clampf(value, 1.0, 1.5)
		emit_changed()

@export_range(1.0, 2.0, 0.01, "suffix:x")
var spoke_outer_mul: float:
	get:
		return _spoke_outer_mul
	set(value):
		_spoke_outer_mul = clampf(value, 1.0, 2.0)
		emit_changed()

@export_range(0.2, 6.0, 0.1, "suffix:deg")
var spoke_width_deg: float:
	get:
		return _spoke_width_deg
	set(value):
		_spoke_width_deg = clampf(value, 0.2, 6.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var spoke_appear: float:
	get:
		return _spoke_appear
	set(value):
		_spoke_appear = clampf(value, 0.0, 1.0)
		emit_changed()

## 짧은 별 조각 개수입니다. 셰이더 루프 상한이 8이라 그 위로는 못 올립니다.
@export_range(0, 8, 1)
var spark_count: int:
	get:
		return _spark_count
	set(value):
		_spark_count = clampi(value, 0, MAX_SPARK_COUNT)
		emit_changed()

@export_range(0.05, 2.0, 0.001, "suffix:x")
var spark_length_ratio: float:
	get:
		return _spark_length_ratio
	set(value):
		_spark_length_ratio = clampf(value, 0.05, 2.0)
		emit_changed()

@export_range(0.01, 1.0, 0.001, "suffix:x")
var spark_width_ratio: float:
	get:
		return _spark_width_ratio
	set(value):
		_spark_width_ratio = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var spark_appear: float:
	get:
		return _spark_appear
	set(value):
		_spark_appear = clampf(value, 0.0, 1.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var spark_vanish: float:
	get:
		return _spark_vanish
	set(value):
		_spark_vanish = clampf(value, 0.0, 1.0)
		emit_changed()


@export_group("중심 플래시")

## 중심 플래시가 유지되는 시간입니다.
@export_range(0.01, 1.0, 0.005, "suffix:s")
var flash_time: float:
	get:
		return _flash_time
	set(value):
		_flash_time = clampf(value, MIN_TIME, MAX_TIME)
		emit_changed()

## ★ 되돌릴 수 있게 남긴 스위치입니다.
##
## 가이드 3-5는 "중심의 짧은 플래시"를 요구하고,
## 가이드 3-2는 "원형 파동이 동공을 가리지 않도록 한다"고 합니다. 둘이 부딪힙니다.
##
## false = 꽉 찬 원. 44px 공의 동공(약 14px)이 0.045초 동안 덮입니다. **확정된 안 A**
## true  = 공 바깥 고리. 동공이 그대로 보입니다(안 B·C).
##
## 강보현님 검수에서 "파동이 공을 가린다"로 걸리면 이 스위치를 켭니다.
@export var flash_hollow: bool:
	get:
		return _flash_hollow
	set(value):
		_flash_hollow = value
		emit_changed()

## 파동 중심을 타격 방향으로 옮기는 거리 / 공 반지름입니다.
## 가이드 권장은 2~5px(= 0.091~0.227)이지만 확정된 안 A는 이동 없음(0)입니다.
@export_range(0.0, 0.5, 0.001, "suffix:x")
var center_shift_ratio: float:
	get:
		return _center_shift_ratio
	set(value):
		_center_shift_ratio = clampf(value, 0.0, 0.5)
		emit_changed()


@export_group("렌더")

## 쿼드가 파동 최대 도달보다 얼마나 여유를 두는지입니다.
## 여유가 없으면 파동이 쿼드 경계에서 잘려 네모난 자국이 남습니다.
@export_range(1.0, 1.5, 0.01, "suffix:x")
var quad_padding: float:
	get:
		return _quad_padding
	set(value):
		_quad_padding = clampf(value, MIN_QUAD_PADDING, MAX_QUAD_PADDING)
		emit_changed()

## 동시에 살아 있을 수 있는 파동 개수입니다. 넘으면 가장 오래된 것을 재사용합니다.
@export_range(1, 16, 1)
var max_concurrent: int:
	get:
		return _max_concurrent
	set(value):
		_max_concurrent = clampi(value, MIN_CONCURRENT, MAX_CONCURRENT)
		emit_changed()


@export_group("색")

## 주요 링. 밝은 청록(가이드 3-5).
@export var ring_color := Color(0.435, 0.890, 0.784, 1.0)

## 보조 링. 금색 = 성공 포인트입니다.
## 발광 테두리에는 금색을 쓰지 않습니다. 겹치면 파동의 언어가 뭉개집니다.
@export var sub_color := Color(1.0, 0.780, 0.120, 1.0)

## 중심 플래시. 아이보리 또는 흰색(가이드 3-5).
@export var flash_color := Color(0.941, 0.878, 0.765, 1.0)

## 별 조각. 청록·아이보리 중심(가이드 3-5).
@export var spark_color := Color(0.941, 0.878, 0.765, 1.0)


## 쿼드 반지름 / 공 반지름입니다. 방사형 선 끝까지 담아야 잘리지 않습니다.
func get_quad_radius_ratio() -> float:
	return end_radius_ratio * maxf(spoke_outer_mul, 1.0) * quad_padding


## 진행도 t(0~1)에서의 주요 링 반경 / 공 반지름입니다.
func get_main_radius_ratio(t: float) -> float:
	var e := get_expand_curve(t)
	return start_radius_ratio + (end_radius_ratio - start_radius_ratio) * e


## 보조 링은 sub_delay 만큼 늦게 출발해 주요 링을 뒤따릅니다.
func get_sub_radius_ratio(t: float) -> float:
	var span := maxf(1.0 - sub_delay, 0.001)
	var ts := clampf((t - sub_delay) / span, 0.0, 1.0)
	var e := get_expand_curve(ts)
	return start_radius_ratio + (end_radius_ratio - start_radius_ratio) * e


## 빠르게 커지고 사라진다(가이드 3-5). 초반에 확 커지는 ease-out 입니다.
func get_expand_curve(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, expand_exp)


func get_fade(t: float) -> float:
	var span := maxf(1.0 - fade_start, 0.001)
	var x := clampf((t - fade_start) / span, 0.0, 1.0)
	return clampf(1.0 - pow(x, fade_exp), 0.0, 1.0)


## 중심 플래시의 세기입니다. flash_time 이 지나면 0입니다.
func get_flash_amount(elapsed_seconds: float) -> float:
	if flash_time <= 0.0 or elapsed_seconds >= flash_time:
		return 0.0

	var x := clampf(elapsed_seconds / flash_time, 0.0, 1.0)
	return clampf(pow(1.0 - x, 0.8), 0.0, 1.0)


## 링이 커지면서 얇아진 현재 두께 / 공 반지름입니다.
func get_ring_width_ratio(t: float) -> float:
	var e := get_expand_curve(t)
	return ring_width_ratio * (1.0 - ring_width_shrink * e)
