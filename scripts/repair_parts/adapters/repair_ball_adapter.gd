class_name RepairBallAdapter
extends Node


## 기존 Pinball의 공개 속도 API만 사용하는 어댑터입니다.
## 공의 위치·transform은 절대 변경하지 않고, 현재 방향을 보존한 목표 속도와의
## 차이를 impulse로 한 번 적용합니다.

const STOPPED_SPEED_EPSILON := 1.0


## 톱니바퀴 접촉 가속을 적용합니다. 과회전이면 overdrive_boost를 추가합니다.
## 공이 거의 정지한 경우 방향은 부품 중심 → 공 중심 벡터를 사용합니다.
## 반환값은 적용된 목표 속력이며, 적용 실패 시 -1.0입니다.
func apply_gear_boost(
	ball: RigidBody2D,
	part_global_position: Vector2,
	contact_boost: float,
	overdrive_boost: float,
	is_overdrive: bool
) -> float:
	if not is_instance_valid(ball):
		return -1.0

	var current_velocity := ball.linear_velocity
	var current_speed := current_velocity.length()
	var direction := current_velocity.normalized()
	if current_speed <= STOPPED_SPEED_EPSILON:
		direction = (
			ball.global_position - part_global_position
		).normalized()
	if direction.is_zero_approx():
		return -1.0

	var requested_speed := current_speed + maxf(contact_boost, 0.0)
	if is_overdrive:
		requested_speed += maxf(overdrive_boost, 0.0)

	var desired_velocity := direction * requested_speed
	if ball.has_method(&"get_limited_velocity"):
		# 공 종류별 최소·최대 속도 규칙을 침범하지 않습니다.
		desired_velocity = ball.call(
			&"get_limited_velocity",
			desired_velocity
		) as Vector2

	var impulse := (desired_velocity - current_velocity) * ball.mass
	ball.apply_central_impulse(impulse)
	return desired_velocity.length()
