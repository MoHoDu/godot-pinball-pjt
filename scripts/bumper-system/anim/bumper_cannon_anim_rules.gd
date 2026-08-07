@tool
class_name BumperCannonAnimRules
extends BumperAnimRules
## Shot 범퍼(태엽 대포) 전용 애니메이션 규칙입니다. `BumperAnimRules` 를 확장합니다.
##
## 기획서 5-7 / 38쪽: **포신이 받침대 중심축을 기준으로 회전하고, 포신의 회전만으로도
## 현재 방향을 확인할 수 있어야 한다.** 선택 방향이 바뀌면 아트가 따라 돌아야 한다.
##
## 아트는 포신이 **+X(오른쪽)** 를 향하도록 뽑혀 있어서 회전각이 곧 발사 방향이다.
## 부모 규칙의 "회전을 쓰지 않는다" 는 눌림 스쿼시에 대한 것이고, 조준 회전은 예외다.


const MIN_TURN_SPEED: float = 1.0
const MAX_TURN_SPEED: float = 40.0
## 초당 회전 속도(라디안). 너무 느리면 선택이 즉시 안 읽히고,
## 즉시 스냅시키면 장난감이 아니라 기계로 보인다.
const DEFAULT_TURN_SPEED: float = 12.0

const MIN_SETTLE: float = 0.0
const MAX_SETTLE: float = 0.5
## 도착 직후 살짝 지나쳤다가 되돌아오는 폭(라디안). 손으로 돌린 장난감 느낌을 준다.
const DEFAULT_SETTLE: float = 0.10


@export_category("포신 조준")

@export_range(MIN_TURN_SPEED, MAX_TURN_SPEED, 0.5, "suffix:rad/s")
var aim_turn_speed: float = DEFAULT_TURN_SPEED:
	set(value):
		aim_turn_speed = clampf(value, MIN_TURN_SPEED, MAX_TURN_SPEED)
		emit_changed()

@export_range(MIN_SETTLE, MAX_SETTLE, 0.01, "suffix:rad")
var aim_settle_swing: float = DEFAULT_SETTLE:
	set(value):
		aim_settle_swing = clampf(value, MIN_SETTLE, MAX_SETTLE)
		emit_changed()

## 포획 중이 아닐 때도 조준 방향을 따라갈지 여부입니다.
## 3-2 절이 기본 상태를 "조용한 상태" 로 규정하므로 기본값은 끕니다.
@export var aim_while_idle := false:
	set(value):
		aim_while_idle = value
		emit_changed()
