class_name CursedCottonAdd
extends Area2D


signal cotton_hit(ball: Pinball)
signal cotton_cleared


@export var rules: CursedCottonAddRules = null
@export var collision_shape: CollisionShape2D = null


var _is_configured: bool = false
var _is_spent: bool = false
var _clear_scheduled: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if rules != null:
		configure(rules)


func configure(new_rules: CursedCottonAddRules) -> bool:
	if new_rules == null \
			or not is_instance_valid(new_rules) \
			or not new_rules.validate().is_empty():
		return false

	rules = new_rules
	_is_configured = true
	_apply_collision_radius()
	return true


func _on_body_entered(body: Node2D) -> void:
	if _is_spent \
			or not _is_configured \
			or rules == null \
			or not is_instance_valid(rules) \
			or not rules.validate().is_empty():
		return
	if body == null \
			or not is_instance_valid(body) \
			or not body is Pinball \
			or not body.is_inside_tree() \
			or not body.is_in_group(Pinball.PINBALL_GROUP):
		return

	_is_spent = true
	var ball: Pinball = body as Pinball
	var direction: Vector2 = _get_outward_direction(ball)
	var current_speed: float = ball.linear_velocity.length()
	var target_speed: float = current_speed * rules.speed_retention
	var target_velocity: Vector2 = ball.get_limited_velocity(
		direction * target_speed
	)
	var velocity_change: Vector2 = target_velocity - ball.linear_velocity
	ball.sleeping = false
	if not velocity_change.is_zero_approx():
		ball.apply_central_impulse(velocity_change * ball.mass)

	cotton_hit.emit(ball)
	_schedule_clear()


func _get_outward_direction(ball: Pinball) -> Vector2:
	var center_offset: Vector2 = ball.global_position - global_position
	if not center_offset.is_zero_approx():
		return center_offset.normalized()
	if not ball.linear_velocity.is_zero_approx():
		return -ball.linear_velocity.normalized()
	return Vector2.RIGHT


func _apply_collision_radius() -> void:
	if not is_instance_valid(collision_shape) \
			or not collision_shape.shape is CircleShape2D:
		return
	var circle: CircleShape2D = collision_shape.shape as CircleShape2D
	circle.radius = rules.collision_radius_px


func _schedule_clear() -> void:
	if _clear_scheduled:
		return
	_clear_scheduled = true
	call_deferred(&"_clear_after_hit")


func _clear_after_hit() -> void:
	if not is_inside_tree():
		return
	cotton_cleared.emit()
	queue_free()
