extends RigidBody2D


## 수리 부품 단위 테스트용 공 스텁입니다.
## 실제 Pinball의 공개 속도 API 계약(get_limited_velocity)만 흉내 냅니다.
## 공 반지름 22, 최소 320, 최대 1540은 보드 리밸런스 수치를 따릅니다.


const BALL_RADIUS := 22.0
const MINIMUM_SPEED := 320.0
const MAXIMUM_SPEED := 1540.0
const STOPPED_SPEED_EPSILON := 1.0


func _init() -> void:
	gravity_scale = 0.0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	shape.shape = circle
	add_child(shape)


func get_limited_velocity(
	velocity: Vector2,
	maximum_speed_override: float = INF
) -> Vector2:
	var speed := velocity.length()
	if speed <= STOPPED_SPEED_EPSILON:
		return Vector2.ZERO
	var effective_maximum := minf(MAXIMUM_SPEED, maximum_speed_override)
	var effective_minimum := minf(MINIMUM_SPEED, effective_maximum)
	var limited_speed := clampf(speed, effective_minimum, effective_maximum)
	return velocity.normalized() * limited_speed
