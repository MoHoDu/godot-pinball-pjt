class_name FlipperCollisionGuard
extends RefCounted


## 모든 플리퍼 인스턴스가 같은 공에서 공유하는 마지막 처리 물리 프레임입니다.
## 한 그룹의 두 서브 플리퍼가 동시에 공을 감지해도 먼저 처리한 한 쪽만 충돌을 소유합니다.
const LAST_RESOLVED_PHYSICS_FRAME_META: StringName = \
	&"_flipper_last_resolved_physics_frame"
## 한 번의 작동 중 이미 패링 결과를 알린 토큰 목록입니다.
## 후속 물리 보정은 허용하면서 같은 작동의 피드백 신호만 한 번으로 제한합니다.
const REPORTED_PARRY_ACTIVATION_TOKENS_META: StringName = \
	&"_flipper_reported_parry_activation_tokens"
const MAX_TRACKED_ACTIVATION_TOKENS := 8


func was_resolved_this_physics_frame(
	ball: RigidBody2D,
	physics_frame: int = Engine.get_physics_frames()
) -> bool:
	if not is_instance_valid(ball):
		return false
	return int(ball.get_meta(LAST_RESOLVED_PHYSICS_FRAME_META, -1)) \
		== physics_frame


func mark_resolved(
	ball: RigidBody2D,
	physics_frame: int = Engine.get_physics_frames()
) -> void:
	if not is_instance_valid(ball):
		return
	ball.set_meta(LAST_RESOLVED_PHYSICS_FRAME_META, physics_frame)


## 같은 컨트롤러 작동 토큰으로 이미 이 공의 패링 결과를 알렸는지 확인합니다.
func was_parry_reported_for_activation(
	ball: RigidBody2D,
	activation_token: int
) -> bool:
	if not is_instance_valid(ball) or activation_token <= 0:
		return false

	var resolved_tokens: Array = ball.get_meta(
		REPORTED_PARRY_ACTIVATION_TOKENS_META,
		[]
	)
	return resolved_tokens.has(activation_token)


func mark_parry_reported(
	ball: RigidBody2D,
	activation_token: int
) -> void:
	if not is_instance_valid(ball) or activation_token <= 0:
		return

	var resolved_tokens: Array = ball.get_meta(
		REPORTED_PARRY_ACTIVATION_TOKENS_META,
		[]
	).duplicate()
	if resolved_tokens.has(activation_token):
		return

	resolved_tokens.append(activation_token)
	while resolved_tokens.size() > MAX_TRACKED_ACTIVATION_TOKENS:
		resolved_tokens.pop_front()
	ball.set_meta(REPORTED_PARRY_ACTIVATION_TOKENS_META, resolved_tokens)
