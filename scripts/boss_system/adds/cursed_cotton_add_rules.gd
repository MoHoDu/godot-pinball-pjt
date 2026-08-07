class_name CursedCottonAddRules
extends Resource


@export var collision_radius_px: float = 32.0
@export var speed_retention: float = 0.85


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(collision_radius_px) or collision_radius_px <= 0.0:
		errors.append("collision_radius_px must be finite and greater than 0.0.")
	if not is_finite(speed_retention) \
			or speed_retention <= 0.0 \
			or speed_retention > 1.0:
		errors.append(
			"speed_retention must be finite, greater than 0.0, "
			+ "and less than or equal to 1.0."
		)
	return errors
