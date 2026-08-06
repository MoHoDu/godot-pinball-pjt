@tool
class_name BumperAnimRules
extends Resource
## 범퍼 아트의 타격·상태 애니메이션 규칙입니다.
##
## 기획서 대응:
## - 5-1 단추: 얕은 눌림
## - 5-2 솜: 작게 흔들림 (큰 먼지 구름 금지 -> 흔들림도 작게)
## - 5-3 용수철 인형: 아래로 눌림 -> 빠르게 튕겨오름
## - 5-4 장난감 북: 크게 팽창. 북막만 변형 (34쪽)
## - 5-7 대포: 포획 시 받침대 눌림, 발사 시 짧은 반동
## - 3-2 복구 예고: 아주 약한 떨림 / 파괴: 비활성 표시
##
## 길이는 표시 반지름 비율로 저장합니다. 범퍼가 92~128px 로 제각각입니다.
##
## **회전은 쓰지 않습니다.** 대포 포신이 +X 기준이고 북막에 그림이 그려져 있어
## 아트를 돌리면 방향이 어긋납니다. 눌림은 균일 축소 + 법선 방향 이동으로 만듭니다.


const MIN_PRESS_DEPTH: float = 0.0
const MAX_PRESS_DEPTH: float = 0.35
const DEFAULT_PRESS_DEPTH: float = 0.08

const MIN_PRESS_OFFSET: float = 0.0
const MAX_PRESS_OFFSET: float = 0.30
const DEFAULT_PRESS_OFFSET: float = 0.06

const MIN_SECONDS: float = 0.01
const MAX_SECONDS: float = 1.50
const DEFAULT_PRESS_SECONDS: float = 0.05
const DEFAULT_RELEASE_SECONDS: float = 0.16

const MIN_OVERSHOOT: float = 0.0
const MAX_OVERSHOOT: float = 0.50
const DEFAULT_OVERSHOOT: float = 0.06

const MIN_SHAKE_AMPLITUDE: float = 0.0
const MAX_SHAKE_AMPLITUDE: float = 0.30
const DEFAULT_SHAKE_AMPLITUDE: float = 0.0

const MIN_HZ: float = 0.5
const MAX_HZ: float = 30.0
const DEFAULT_SHAKE_HZ: float = 14.0
const DEFAULT_TELEGRAPH_HZ: float = 5.0

const MIN_TELEGRAPH_AMPLITUDE: float = 0.0
const MAX_TELEGRAPH_AMPLITUDE: float = 0.12
const DEFAULT_TELEGRAPH_AMPLITUDE: float = 0.02

const MIN_ALPHA: float = 0.0
const MAX_ALPHA: float = 1.0
## `bumper_visual.gd` 의 DISABLED_ALPHA 와 같은 값입니다. 프로시저럴 Visual 을 끄면서
## 잃어버린 비활성 표시를 아트 쪽에서 되살립니다.
const DEFAULT_DESTROYED_ALPHA: float = 0.28


@export_category("타격 눌림")

## 눌릴 때 줄어드는 비율입니다. 0.08 이면 92% 로 축소됩니다.
@export_range(MIN_PRESS_DEPTH, MAX_PRESS_DEPTH, 0.005)
var press_depth: float = DEFAULT_PRESS_DEPTH:
	set(value):
		press_depth = clampf(value, MIN_PRESS_DEPTH, MAX_PRESS_DEPTH)
		emit_changed()

## 접촉 법선 방향으로 밀려 들어가는 거리입니다. 표시 반지름 비율입니다.
@export_range(MIN_PRESS_OFFSET, MAX_PRESS_OFFSET, 0.005)
var press_offset_ratio: float = DEFAULT_PRESS_OFFSET:
	set(value):
		press_offset_ratio = clampf(value, MIN_PRESS_OFFSET, MAX_PRESS_OFFSET)
		emit_changed()

@export_range(MIN_SECONDS, MAX_SECONDS, 0.01, "suffix:s")
var press_seconds: float = DEFAULT_PRESS_SECONDS:
	set(value):
		press_seconds = clampf(value, MIN_SECONDS, MAX_SECONDS)
		emit_changed()

@export_range(MIN_SECONDS, MAX_SECONDS, 0.01, "suffix:s")
var release_seconds: float = DEFAULT_RELEASE_SECONDS:
	set(value):
		release_seconds = clampf(value, MIN_SECONDS, MAX_SECONDS)
		emit_changed()

## 복귀할 때 원래 크기를 넘어 부푸는 비율입니다. 북의 "크게 팽창"과
## 용수철 인형의 "빠르게 튕겨오름" 이 이 값으로 갈립니다.
@export_range(MIN_OVERSHOOT, MAX_OVERSHOOT, 0.005)
var overshoot: float = DEFAULT_OVERSHOOT:
	set(value):
		overshoot = clampf(value, MIN_OVERSHOOT, MAX_OVERSHOOT)
		emit_changed()


@export_category("흔들림")

## 타격 후 좌우로 흔들리는 폭입니다. 솜 전용에 가깝습니다 (5-2).
@export_range(MIN_SHAKE_AMPLITUDE, MAX_SHAKE_AMPLITUDE, 0.005)
var shake_amplitude_ratio: float = DEFAULT_SHAKE_AMPLITUDE:
	set(value):
		shake_amplitude_ratio = clampf(
			value, MIN_SHAKE_AMPLITUDE, MAX_SHAKE_AMPLITUDE
		)
		emit_changed()

@export_range(MIN_HZ, MAX_HZ, 0.5, "suffix:Hz")
var shake_hz: float = DEFAULT_SHAKE_HZ:
	set(value):
		shake_hz = clampf(value, MIN_HZ, MAX_HZ)
		emit_changed()


@export_category("타격 프레임")

## 눌림 구간 동안 갈아 끼울 타격 프레임입니다. 비워 두면 스쿼시만 씁니다.
##
## 용수철 인형 전용에 가깝습니다. 기획서 33쪽이 "얼굴과 용수철을 동시에 상시
## 노출하지 않고 **기본 상태와 타격 상태의 형태 변화로** Bounce 를 전달한다" 고
## 요구하는데, 스쿼시만으로는 숨어 있던 용수철이 드러나지 않습니다.
##
## 두 프레임은 **같은 캔버스에 정렬**돼 있어야 합니다. 알파 bbox 가 어긋나면
## 교체 순간 그림이 튑니다.
@export var hit_texture: Texture2D = null:
	set(value):
		hit_texture = value
		emit_changed()

## 타격 프레임을 유지하는 구간입니다. 눌림+복귀 전체에 대한 비율입니다.
## 너무 길면 복귀 동작이 안 보이고, 너무 짧으면 프레임이 스쳐 지나갑니다.
@export_range(0.05, 1.0, 0.05)
var hit_frame_window: float = 0.45:
	set(value):
		hit_frame_window = clampf(value, 0.05, 1.0)
		emit_changed()


@export_category("상태")

## 복구 예고의 떨림 폭입니다. 3-2 절이 "아주 약한 떨림" 을 요구합니다.
@export_range(MIN_TELEGRAPH_AMPLITUDE, MAX_TELEGRAPH_AMPLITUDE, 0.005)
var telegraph_amplitude_ratio: float = DEFAULT_TELEGRAPH_AMPLITUDE:
	set(value):
		telegraph_amplitude_ratio = clampf(
			value, MIN_TELEGRAPH_AMPLITUDE, MAX_TELEGRAPH_AMPLITUDE
		)
		emit_changed()

@export_range(MIN_HZ, MAX_HZ, 0.5, "suffix:Hz")
var telegraph_hz: float = DEFAULT_TELEGRAPH_HZ:
	set(value):
		telegraph_hz = clampf(value, MIN_HZ, MAX_HZ)
		emit_changed()

## 파괴 상태의 투명도입니다.
@export_range(MIN_ALPHA, MAX_ALPHA, 0.01)
var destroyed_alpha: float = DEFAULT_DESTROYED_ALPHA:
	set(value):
		destroyed_alpha = clampf(value, MIN_ALPHA, MAX_ALPHA)
		emit_changed()
