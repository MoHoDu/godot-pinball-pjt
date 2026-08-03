@tool
class_name ComboBossSettings
extends Resource


@export var boss_id: StringName = &"boss"

@export_range(1, 100000000, 1)
var max_health: int = 1000:
	set(value):
		max_health = maxi(value, 1)
		emit_changed()

## 무게 배율 1.0인 공으로 처치하기를 기대하는 유효 타격 횟수입니다.
@export_range(1, 10000, 1)
var target_hit_count: int = 20:
	set(value):
		target_hit_count = maxi(value, 1)
		emit_changed()
