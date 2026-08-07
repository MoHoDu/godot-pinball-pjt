@tool
class_name BossVfxRules
extends Resource
## 보스 VFX 수치·색 규칙입니다.
##
## 가이드 대응:
## - 9-1 공격 예고: 팔 주변 아래→위 굵은 위험선. **카툰식 붓획**이지 화살표 UI 가
##   아니다. 진홍·적자·핑크. 공을 덮는 큰 붉은 면·화면 플래시는 금지
## - 9-2 팔 공격: 팔 뒤 짧고 굵은 스윙 잔상 + 공 충돌 지점 방향성 충격선.
##   **히트스톱 금지** (공의 새 진행 방향을 즉시 추적해야 한다)
## - 10 일반 피격: "푹+팡" — 짧은 타격선 + 작은 솜 파편
## - 10 고콤보 피격: 굵은 원형 충격링 + 솜 파편 증가
## - 11 포효: 봉제선 사이 검은 연기 분출 + 검은 솜 떠오름
##
## 정확한 반격 VFX 는 **여기 없다.** 가이드 10절 메모 "패링 vfx 와 똑같은 거
## 쓰자!" 에 따라 기존 패링 연출을 재사용한다.
##
## 색 원칙 (가이드 6절): 위험 = 진홍·핑크, 저주 = 보라·라임.
## 보스 피격 VFX 가 공 진행 방향을 가리면 안 되므로 수명은 전부 짧다.


const MIN_COUNT: int = 0
const MAX_COUNT: int = 12
const MIN_LIFETIME: float = 0.03
const MAX_LIFETIME: float = 2.0
const MIN_RATIO: float = 0.0
const MAX_RATIO: float = 3.0
const MIN_WIDTH: float = 1.0
const MAX_WIDTH: float = 30.0


@export_category("공격 예고 위험선")

## 팔 하나당 붓획 수. 가이드가 "여러 개의 작은 화살표" 를 금지하므로 적게.
@export_range(1, 5, 1) var telegraph_strokes: int = 3:
	set(value):
		telegraph_strokes = clampi(value, 1, 5)
		emit_changed()

## 붓획 길이(인게임 px). 팔 길이(약 217)의 절반쯤이 팔 옆에 붙어 보인다.
@export_range(40.0, 300.0, 1.0, "suffix:px") var telegraph_length: float = 120.0:
	set(value):
		telegraph_length = clampf(value, 40.0, 300.0)
		emit_changed()

@export_range(MIN_WIDTH, MAX_WIDTH, 0.5, "suffix:px")
var telegraph_width: float = 16.0:
	set(value):
		telegraph_width = clampf(value, MIN_WIDTH, MAX_WIDTH)
		emit_changed()

## 위험선 맥동 속도. 예고 시간(첫 1.1s/이후 0.85s) 안에 2~3 번 뛰는 값.
@export_range(0.5, 8.0, 0.1, "suffix:Hz") var telegraph_pulse_hz: float = 2.6:
	set(value):
		telegraph_pulse_hz = clampf(value, 0.5, 8.0)
		emit_changed()

@export var telegraph_color := Color(0.686, 0.361, 0.878, 0.9):
	set(value):
		telegraph_color = value
		emit_changed()

@export var telegraph_color_bright := Color(0.855, 0.596, 1.0, 0.98):
	set(value):
		telegraph_color_bright = value
		emit_changed()


@export_category("팔 스윙 잔상")

## 잔상이 화면에 남는 시간. 활성 0.22s 와 겹치는 짧은 값이어야
## "팔이 지나갔다" 로 읽히고 공 추적을 방해하지 않는다.
@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var trail_lifetime: float = 0.11:
	set(value):
		trail_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

## 리본이 덮는 시간 창. 이 시간만큼의 팔 궤적이 잔상으로 보인다.
@export_range(0.04, 0.4, 0.01, "suffix:s") var trail_window: float = 0.13:
	set(value):
		trail_window = clampf(value, 0.04, 0.4)
		emit_changed()

## 잔상을 남기기 시작하는 팔 각속도(도/초). 대기 흔들림(수 도/초)은 걸리면 안 된다.
## 경직의 팔 낙하도 초반 ~370°/s 라 잡힌다 — 내려갈 때도 궤적을 따라와야 한다.
@export_range(30.0, 600.0, 5.0) var trail_min_speed: float = 80.0:
	set(value):
		trail_min_speed = clampf(value, 30.0, 600.0)
		emit_changed()

## 잔상 부채꼴의 안쪽 반지름 비율 (팔 길이 대비).
@export_range(MIN_RATIO, 1.0, 0.01) var trail_inner_ratio: float = 0.58:
	set(value):
		trail_inner_ratio = clampf(value, MIN_RATIO, 1.0)
		emit_changed()

@export var trail_color := Color(0.639, 0.337, 0.851, 0.28):
	set(value):
		trail_color = value
		emit_changed()

## 손끝 쪽 밝은 코어. 가이드 10쪽 레퍼런스(붉은 슬래시)의 밝은 심과 같다.
@export var trail_core_color := Color(0.902, 0.753, 1.0, 0.40):
	set(value):
		trail_core_color = value
		emit_changed()


@export_category("공 충돌 충격선")

@export_range(MIN_COUNT, MAX_COUNT, 1) var impact_ticks: int = 4:
	set(value):
		impact_ticks = clampi(value, MIN_COUNT, MAX_COUNT)
		emit_changed()

@export_range(20.0, 200.0, 1.0, "suffix:px") var impact_length: float = 96.0:
	set(value):
		impact_length = clampf(value, 20.0, 200.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var impact_lifetime: float = 0.14:
	set(value):
		impact_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var impact_color := Color(0.878, 0.784, 1.0, 0.97):
	set(value):
		impact_color = value
		emit_changed()


@export_category("피격 - 푹+팡")

@export_range(MIN_COUNT, MAX_COUNT, 1) var hit_ticks: int = 3:
	set(value):
		hit_ticks = clampi(value, MIN_COUNT, MAX_COUNT)
		emit_changed()

@export_range(20.0, 200.0, 1.0, "suffix:px") var hit_tick_length: float = 64.0:
	set(value):
		hit_tick_length = clampf(value, 20.0, 200.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var hit_lifetime: float = 0.16:
	set(value):
		hit_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var hit_tick_color := Color(0.851, 0.745, 0.984, 0.94):
	set(value):
		hit_tick_color = value
		emit_changed()

## 검은 솜 파편. 보스 몸에서 터지는 것이라 몸색보다 살짝 밝은 저주 보라.
@export_range(MIN_COUNT, MAX_COUNT, 1) var fluff_count: int = 4:
	set(value):
		fluff_count = clampi(value, MIN_COUNT, MAX_COUNT)
		emit_changed()

@export_range(2.0, 30.0, 0.5, "suffix:px") var fluff_radius: float = 9.0:
	set(value):
		fluff_radius = clampf(value, 2.0, 30.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var fluff_lifetime: float = 0.42:
	set(value):
		fluff_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var fluff_color := Color(0.318, 0.263, 0.427, 0.92):
	set(value):
		fluff_color = value
		emit_changed()

## 고콤보 충격링. 가이드 10 "굵은 원형 충격링".
@export_range(20.0, 300.0, 1.0, "suffix:px") var ring_end_radius: float = 175.0:
	set(value):
		ring_end_radius = clampf(value, 20.0, 300.0)
		emit_changed()

@export_range(MIN_WIDTH, MAX_WIDTH, 0.5, "suffix:px") var ring_width: float = 9.0:
	set(value):
		ring_width = clampf(value, MIN_WIDTH, MAX_WIDTH)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var ring_lifetime: float = 0.24:
	set(value):
		ring_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

@export var ring_color := Color(0.816, 0.671, 1.0, 0.9):
	set(value):
		ring_color = value
		emit_changed()


@export_category("포효 연기")

@export_range(MIN_COUNT, MAX_COUNT, 1) var smoke_count: int = 7:
	set(value):
		smoke_count = clampi(value, MIN_COUNT, MAX_COUNT)
		emit_changed()

@export_range(4.0, 60.0, 0.5, "suffix:px") var smoke_radius: float = 22.0:
	set(value):
		smoke_radius = clampf(value, 4.0, 60.0)
		emit_changed()

@export_range(MIN_LIFETIME, MAX_LIFETIME, 0.01, "suffix:s")
var smoke_lifetime: float = 0.9:
	set(value):
		smoke_lifetime = clampf(value, MIN_LIFETIME, MAX_LIFETIME)
		emit_changed()

## 검은 연기. 저주 보라가 스며든 먹색.
@export var smoke_color := Color(0.153, 0.118, 0.216, 0.94):
	set(value):
		smoke_color = value
		emit_changed()

@export var smoke_glow_color := Color(0.541, 0.373, 0.753, 0.8):
	set(value):
		smoke_glow_color = value
		emit_changed()


@export_category("공통")

## 가짜 글로우 세기. GL Compatibility 라 블룸이 없어 겹쳐 그린다.
@export_range(0.0, 1.0, 0.05) var glow_strength: float = 0.6:
	set(value):
		glow_strength = clampf(value, 0.0, 1.0)
		emit_changed()
