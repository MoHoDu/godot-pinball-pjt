class_name BossArmBallReflectionRules
extends Resource


@export var reflection_speed: float = 900.0
@export var outward_ratio: float = 0.65
@export var downward_ratio: float = 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_positive_finite(errors, &"reflection_speed", reflection_speed)
	_validate_positive_finite(errors, &"outward_ratio", outward_ratio)
	_validate_positive_finite(errors, &"downward_ratio", downward_ratio)
	return errors


func _validate_positive_finite(
	errors: PackedStringArray,
	property_name: StringName,
	value: float
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and greater than 0.0." % property_name)
