class_name ShotResponseStrategy
extends BumperResponseStrategy


func build_response(
	_context: BallImpactContext,
	bumper: Node
) -> BumperResponse:
	var response := BumperResponse.new()
	response.source_bumper_id = bumper.get(&"bumper_id")
	response.response_tag = &"shot"
	response.source_speed = 0.0
	response.direction_mode = BallImpactResult.DirectionMode.FIXED_WORLD
	response.direction = bumper.call(&"get_selected_launch_direction")
	response.speed_multiplier = 0.0
	response.speed_addition = float(bumper.call(&"get_launch_speed"))
	response.minimum_speed = response.speed_addition
	response.maximum_speed = response.speed_addition
	response.priority = 30
	return response
