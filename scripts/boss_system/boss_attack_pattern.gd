@tool
class_name BossAttackPattern
extends Resource


@export var attack_id: StringName = &"teddy_arm_sweep"

@export_range(0.0, 60.0, 0.01, "suffix:s")
var telegraph_duration := 0.9:
	set(value):
		telegraph_duration = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 60.0, 0.01, "suffix:s")
var active_duration := 0.25:
	set(value):
		active_duration = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 60.0, 0.01, "suffix:s")
var recovery_duration := 0.7:
	set(value):
		recovery_duration = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 60.0, 0.01, "suffix:s")
var cooldown_duration := 1.5:
	set(value):
		cooldown_duration = maxf(value, 0.0)
		emit_changed()


func is_valid() -> bool:
	return not attack_id.is_empty()
