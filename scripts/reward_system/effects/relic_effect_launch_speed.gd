@tool
class_name RelicEffectLaunchSpeed
extends RelicEffect


## 태엽 및 톱니바퀴 — 발사 속력을 올립니다.
## PinballLauncher의 기본값과 상한을 함께 올려야 실제로 더 빠르게 나갑니다.
## 상한만 올리면 기본 선택값이 그대로라 체감이 없습니다.


const LAUNCH_SPEED_PROPERTIES: Array[StringName] = [
	&"default_launch_speed",
	&"maximum_launch_speed",
]


@export_range(0.0, 2.0, 0.01, "suffix:x")
var bonus_per_stack: float = 0.1:
	set(value):
		bonus_per_stack = maxf(value, 0.0)
		emit_changed()


func apply(runtime: RelicRuntime, stack_count: int) -> bool:
	if runtime == null or runtime.launcher == null:
		return false
	var factor := 1.0 + bonus_per_stack * maxi(stack_count, 0)
	var changed := false
	for property: StringName in LAUNCH_SPEED_PROPERTIES:
		changed = runtime.set_scaled(runtime.launcher, property, factor) or changed
	return changed


func describe(stack_count: int = 1) -> String:
	return "발사 속력 +%d%%" % roundi(bonus_per_stack * maxi(stack_count, 1) * 100.0)
