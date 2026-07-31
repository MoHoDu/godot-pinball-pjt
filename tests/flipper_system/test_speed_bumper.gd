@tool
class_name TestSpeedBumper
extends StaticBody2D


@export_range(16.0, 160.0, 1.0, "suffix:px")
var radius: float = 64.0:
	set(value):
		radius = maxf(value, 1.0)
		_sync_collision_radius()
		queue_redraw()

@export_range(1.0, 3.0, 0.01)
var speed_multiplier: float = 1.18

@export_range(0.0, 1000.0, 1.0, "suffix:px/s")
var speed_addition: float = 120.0

@export_range(1.0, 5000.0, 1.0, "suffix:px/s")
var maximum_speed: float = 1700.0

@export var fill_color := Color(0.13, 0.62, 0.82, 1.0)
@export var rim_color := Color(0.65, 0.94, 1.0, 1.0)


func _ready() -> void:
	_sync_collision_radius()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(
		Vector2.ZERO,
		radius - 5.0,
		0.0,
		TAU,
		48,
		rim_color,
		6.0,
		true
	)
	draw_circle(Vector2.ZERO, radius * 0.34, rim_color)


## 공이 원래 물리 법선으로 반사되는 방향은 유지하고 속력만 더합니다.
func get_ball_impact(_context: Variant) -> BallImpactResult:
	var result := BallImpactResult.new()
	result.direction_mode = BallImpactResult.DirectionMode.PHYSICAL_REFLECTION
	result.speed_multiplier = maxf(speed_multiplier, 1.0)
	result.speed_addition = maxf(speed_addition, 0.0)
	result.maximum_speed = maxf(maximum_speed, 1.0)
	result.priority = 10
	return result


func _sync_collision_radius() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is CircleShape2D:
		return

	var circle := collision.shape as CircleShape2D
	if not circle.resource_local_to_scene:
		circle = circle.duplicate() as CircleShape2D
		circle.resource_local_to_scene = true
		collision.shape = circle
	circle.radius = radius
