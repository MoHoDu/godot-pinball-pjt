class_name NormalResponseStrategy
extends BumperResponseStrategy


func build_response(
	context: BallImpactContext,
	bumper: Node
) -> BumperResponse:
	var response := BumperResponse.new()
	response.source_bumper_id = bumper.get(&"bumper_id")
	response.response_tag = &"normal"
	response.source_speed = context.velocity.length()
	response.direction_mode = BallImpactResult.DirectionMode.PHYSICAL_REFLECTION
	response.speed_multiplier = float(bumper.call(&"get_speed_multiplier"))
	response.minimum_speed = 0.0
	response.maximum_speed = float(bumper.call(&"get_maximum_response_speed"))
	response.priority = 10
	return response
