@tool
class_name BumperSpinAnimRules
extends BumperAnimRules
## 타격 시 아트가 한 바퀴 도는 부품의 규칙입니다. `BumperAnimRules` 를 확장합니다.
##
## 별빛 브로치처럼 **눌림에 더해 회전이 붙는** 부품에 씁니다.
##
## 수리 부품 가이드 4-1 E: 기본 상태에는 "상시 회전이나 강한 점멸을 사용하지 않는다".
## 그래서 상시 회전이 아니라 **타격 순간에만** 돌고 감속하며 멈춘다.


const MIN_SPIN_ARC: float = 0.5
const MAX_SPIN_ARC: float = 12.6
const DEFAULT_SPIN_ARC: float = TAU

const MIN_DECAY: float = 2.0
const MAX_DECAY: float = 20.0
## 남은 각도에 비례해 속도를 준다. 올리면 빨리 멈추고 내리면 오래 미끄러진다.
const DEFAULT_DECAY: float = 7.0

const MIN_SPEED_FLOOR: float = 0.2
const MAX_SPEED_FLOOR: float = 6.0
## 감속만 쓰면 목표에 무한히 가까워지기만 하므로 바닥 속도를 둔다.
const DEFAULT_SPEED_FLOOR: float = 1.2

const MIN_SPEED_CAP: float = 6.0
const MAX_SPEED_CAP: float = 60.0
const DEFAULT_SPEED_CAP: float = 26.0


@export_category("타격 회전")

@export_range(MIN_SPIN_ARC, MAX_SPIN_ARC, 0.1, "suffix:rad")
var spin_arc: float = DEFAULT_SPIN_ARC:
	set(value):
		spin_arc = clampf(value, MIN_SPIN_ARC, MAX_SPIN_ARC)
		emit_changed()

@export_range(MIN_DECAY, MAX_DECAY, 0.5)
var spin_decay: float = DEFAULT_DECAY:
	set(value):
		spin_decay = clampf(value, MIN_DECAY, MAX_DECAY)
		emit_changed()

@export_range(MIN_SPEED_FLOOR, MAX_SPEED_FLOOR, 0.1, "suffix:rad/s")
var spin_min_speed: float = DEFAULT_SPEED_FLOOR:
	set(value):
		spin_min_speed = clampf(value, MIN_SPEED_FLOOR, MAX_SPEED_FLOOR)
		emit_changed()

@export_range(MIN_SPEED_CAP, MAX_SPEED_CAP, 1.0, "suffix:rad/s")
var spin_max_speed: float = DEFAULT_SPEED_CAP:
	set(value):
		spin_max_speed = clampf(value, MIN_SPEED_CAP, MAX_SPEED_CAP)
		emit_changed()
