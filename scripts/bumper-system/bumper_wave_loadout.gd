@tool
class_name BumperWaveLoadout
extends Resource


enum BoardShape {
	TRIANGLE,
	SQUARE,
}


@export var wave_id: StringName = &"wave"
@export var board_shape: BoardShape = BoardShape.TRIANGLE
@export var total_count_range := Vector2i(0, 0)
@export var normal_count_range := Vector2i(0, 0)
@export var bounce_count_range := Vector2i(0, 0)
@export var shot_count_range := Vector2i(0, 0)
@export_range(0, 1, 1) var maximum_cotton_count := 1
@export_range(0, 1, 1) var maximum_toy_drum_count := 1


func is_valid() -> bool:
	if wave_id.is_empty():
		return false
	for count_range: Vector2i in [
		total_count_range,
		normal_count_range,
		bounce_count_range,
		shot_count_range,
	]:
		if count_range.x < 0 or count_range.y < count_range.x:
			return false
	var minimum_sum := (
		normal_count_range.x
		+ bounce_count_range.x
		+ shot_count_range.x
	)
	var maximum_sum := (
		normal_count_range.y
		+ bounce_count_range.y
		+ shot_count_range.y
	)
	return (
		total_count_range.x >= minimum_sum
		and total_count_range.y <= maximum_sum
	)

