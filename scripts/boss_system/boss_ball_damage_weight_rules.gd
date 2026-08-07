class_name BossBallDamageWeightRules
extends Resource


enum WeightClass {
	LIGHT,
	NORMAL,
	HEAVY,
	SUPER_HEAVY,
}


const INVALID_WEIGHT_CLASS: int = -1


@export var light_multiplier: float = 0.80
@export var normal_multiplier: float = 1.00
@export var heavy_multiplier: float = 1.25
@export var super_heavy_multiplier: float = 1.50

@export var light_ball_ids: Array[StringName] = [&"light"]
@export var normal_ball_ids: Array[StringName] = [&"normal"]
@export var heavy_ball_ids: Array[StringName] = [&"heavy"]
@export var super_heavy_ball_ids: Array[StringName] = []


func has_profile(ball_id: StringName) -> bool:
	return get_weight_class(ball_id) != INVALID_WEIGHT_CLASS


func get_weight_class(ball_id: StringName) -> int:
	if ball_id.is_empty():
		return INVALID_WEIGHT_CLASS

	var matched_class: int = INVALID_WEIGHT_CLASS
	var match_count: int = 0
	for registered_id: StringName in light_ball_ids:
		if registered_id == ball_id:
			matched_class = WeightClass.LIGHT
			match_count += 1
	for registered_id: StringName in normal_ball_ids:
		if registered_id == ball_id:
			matched_class = WeightClass.NORMAL
			match_count += 1
	for registered_id: StringName in heavy_ball_ids:
		if registered_id == ball_id:
			matched_class = WeightClass.HEAVY
			match_count += 1
	for registered_id: StringName in super_heavy_ball_ids:
		if registered_id == ball_id:
			matched_class = WeightClass.SUPER_HEAVY
			match_count += 1

	return matched_class if match_count == 1 else INVALID_WEIGHT_CLASS


func get_damage_multiplier(ball_id: StringName) -> float:
	var weight_class: int = get_weight_class(ball_id)
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

	var classes_by_id: Dictionary = {}
	_validate_ball_ids(
		errors,
		&"light_ball_ids",
		WeightClass.LIGHT,
		light_ball_ids,
		classes_by_id
	)
	_validate_ball_ids(
		errors,
		&"normal_ball_ids",
		WeightClass.NORMAL,
		normal_ball_ids,
		classes_by_id
	)
	_validate_ball_ids(
		errors,
		&"heavy_ball_ids",
		WeightClass.HEAVY,
		heavy_ball_ids,
		classes_by_id
	)
	_validate_ball_ids(
		errors,
		&"super_heavy_ball_ids",
		WeightClass.SUPER_HEAVY,
		super_heavy_ball_ids,
		classes_by_id
	)

	for registered_id: StringName in classes_by_id:
		var registered_classes: Array = classes_by_id[registered_id]
		if registered_classes.size() > 1:
			errors.append(
				"ball_id '%s' must not be registered in multiple weight classes."
				% registered_id
			)
	return errors


func _validate_multiplier(
	errors: PackedStringArray,
	property_name: StringName,
	value: float
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and greater than 0.0." % property_name)


func _validate_ball_ids(
	errors: PackedStringArray,
	property_name: StringName,
	weight_class: WeightClass,
	ball_ids: Array[StringName],
	classes_by_id: Dictionary
) -> void:
	var ids_in_class: Dictionary[StringName, bool] = {}
	for index: int in ball_ids.size():
		var ball_id: StringName = ball_ids[index]
		if ball_id.is_empty():
			errors.append("%s[%d] must not be empty." % [property_name, index])
			continue
		if ids_in_class.has(ball_id):
			errors.append(
				"ball_id '%s' must not be duplicated in %s."
				% [ball_id, property_name]
			)
			continue

		ids_in_class[ball_id] = true
		if not classes_by_id.has(ball_id):
			classes_by_id[ball_id] = []
		var registered_classes: Array = classes_by_id[ball_id]
		registered_classes.append(int(weight_class))
