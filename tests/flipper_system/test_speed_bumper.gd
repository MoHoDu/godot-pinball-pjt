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

@export_range(1.0, 5000.0, 1.0, "suffix:px/s")
var maximum_speed: float = 1700.0

@export var fill_color := Color(0.13, 0.62, 0.82, 1.0)
@export var rim_color := Color(0.65, 0.94, 1.0, 1.0)


func _ready() -> void:
	_sync_collision_radius()
	var detection_area := get_node_or_null("SpeedDetectionArea") as Area2D
	if detection_area != null \
		and not detection_area.body_entered.is_connected(_on_body_entered):
		detection_area.body_entered.connect(_on_body_entered)
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


## 방향 정보 없이 공에 전달할 속도 배율만 반환합니다.
func get_speed_multiplier() -> float:
	return maxf(speed_multiplier, 1.0)


## Godot 물리가 확정한 반사 방향은 그대로 두고 속력 크기에만 배율을 적용합니다.
func apply_speed_multiplier(ball: RigidBody2D) -> bool:
	if not is_instance_valid(ball) or ball.linear_velocity.is_zero_approx():
		return false

	var current_speed := ball.linear_velocity.length()
	var boosted_speed := minf(
		current_speed * get_speed_multiplier(),
		maxf(maximum_speed, 1.0)
	)
	if is_equal_approx(current_speed, boosted_speed):
		return false

	ball.linear_velocity = ball.linear_velocity.normalized() * boosted_speed
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		# body_entered는 물리 스텝 중 발생합니다. Deferred 시점에는 정적 범퍼의
		# 기본 반사가 끝났으므로 확정된 방향을 읽어 속력만 조절할 수 있습니다.
		call_deferred(&"apply_speed_multiplier", body as RigidBody2D)


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

	var area_collision := get_node_or_null(
		"SpeedDetectionArea/CollisionShape2D"
	) as CollisionShape2D
	if area_collision == null or not area_collision.shape is CircleShape2D:
		return

	var area_circle := area_collision.shape as CircleShape2D
	if not area_circle.resource_local_to_scene:
		area_circle = area_circle.duplicate() as CircleShape2D
		area_circle.resource_local_to_scene = true
		area_collision.shape = area_circle
	# 정적 표면보다 약간 크게 두어 느린 공도 빠짐없이 감지합니다.
	# 이 영역은 방향을 바꾸지 않으며, 정적 충돌체가 실제 반사를 담당합니다.
	area_circle.radius = radius + 4.0
