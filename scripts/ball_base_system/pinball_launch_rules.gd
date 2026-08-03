@tool
class_name PinballLaunchRules
extends Resource


const MIN_ADJUSTMENT_SPEED := 0.0
const MAX_ANGLE_ADJUSTMENT_SPEED := 720.0
const MAX_POWER_ADJUSTMENT_SPEED := 5000.0


@export_category("공 발사 공통 조작 규칙")

## 좌우 입력을 유지할 때 초당 변경되는 발사 각도입니다.
@export_range(0.0, 720.0, 1.0, "suffix:deg/s")
var angle_adjustment_speed := 90.0:
	set(value):
		angle_adjustment_speed = clampf(
			value,
			MIN_ADJUSTMENT_SPEED,
			MAX_ANGLE_ADJUSTMENT_SPEED
		)
		emit_changed()

## 상하 입력을 유지할 때 초당 변경되는 발사 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s²")
var power_adjustment_speed := 600.0:
	set(value):
		power_adjustment_speed = clampf(
			value,
			MIN_ADJUSTMENT_SPEED,
			MAX_POWER_ADJUSTMENT_SPEED
		)
		emit_changed()
