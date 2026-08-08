class_name BossBallDamageWeightRules
extends Resource


enum WeightClass {
	LIGHT,
	NORMAL,
	HEAVY,
	SUPER_HEAVY,
}


const INVALID_WEIGHT_CLASS: int = -1


@export var light_multiplier: float = 0.90
@export var normal_multiplier: float = 1.00
@export var heavy_multiplier: float = 1.15
@export var super_heavy_multiplier: float = 1.30

@export_category("Mass Thresholds")
@export var normal_minimum_mass: float = 1.0
@export var heavy_minimum_mass: float = 4.0
@export var super_heavy_minimum_mass: float = 16.0


func has_profile(ball_mass: float) -> bool:
	return get_weight_class(ball_mass) != INVALID_WEIGHT_CLASS


func get_weight_class(ball_mass: float) -> int:
	if not is_finite(ball_mass) or ball_mass <= 0.0:
		return INVALID_WEIGHT_CLASS
	if ball_mass < normal_minimum_mass:
		return WeightClass.LIGHT
	if ball_mass < heavy_minimum_mass:
		return WeightClass.NORMAL
	if ball_mass < super_heavy_minimum_mass:
		return WeightClass.HEAVY
	return WeightClass.SUPER_HEAVY


func get_damage_multiplier(ball_mass: float) -> float:
	var weight_class: int = get_weight_class(ball_mass)
	var multiplier: float = 0.0
	match weight_class:
		WeightClass.LIGHT:
			multiplier = light_multiplier
		WeightClass.NORMAL:
			multiplier = normal_multiplier
		WeightClass.HEAVY:
			multiplier = heavy_multiplier
		WeightClass.SUPER_HEAVY:
			multiplier = super_heavy_multiplier
		_:
			return 0.0

	return multiplier if is_finite(multiplier) and multiplier > 0.0 else 0.0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_multiplier(errors, &"light_multiplier", light_multiplier)
	_validate_multiplier(errors, &"normal_multiplier", normal_multiplier)
	_validate_multiplier(errors, &"heavy_multiplier", heavy_multiplier)
	_validate_multiplier(
		errors,
		&"super_heavy_multiplier",
		super_heavy_multiplier
	)
	_validate_mass_threshold(
		errors,
		&"normal_minimum_mass",
		normal_minimum_mass
	)
	_validate_mass_threshold(
		errors,
		&"heavy_minimum_mass",
		heavy_minimum_mass
	)
	_validate_mass_threshold(
		errors,
		&"super_heavy_minimum_mass",
		super_heavy_minimum_mass
	)
	if is_finite(normal_minimum_mass) \
			and is_finite(heavy_minimum_mass) \
			and normal_minimum_mass >= heavy_minimum_mass:
		errors.append(
			"normal_minimum_mass must be less than heavy_minimum_mass."
		)
	if is_finite(heavy_minimum_mass) \
			and is_finite(super_heavy_minimum_mass) \
			and heavy_minimum_mass >= super_heavy_minimum_mass:
		errors.append(
			"heavy_minimum_mass must be less than super_heavy_minimum_mass."
		)
	return errors


func _validate_multiplier(
	errors: PackedStringArray,
	property_name: StringName,
	value: float
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and greater than 0.0." % property_name)


func _validate_mass_threshold(
	errors: PackedStringArray,
	property_name: StringName,
	value: float
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and greater than 0.0." % property_name)
