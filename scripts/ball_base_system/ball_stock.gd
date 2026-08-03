class_name BallStock
extends Resource


@export var definition: BallDefinition
@export_range(0, 99, 1) var count: int = 1:
	set(value):
		count = maxi(value, 0)


func is_valid() -> bool:
	return definition != null and definition.is_valid() and count > 0
