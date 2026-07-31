class_name FlipperCollisionGuard
extends RefCounted


## 모든 플리퍼 인스턴스가 같은 공에서 공유하는 마지막 처리 물리 프레임입니다.
## 한 그룹의 두 서브 플리퍼가 동시에 공을 감지해도 먼저 처리한 한 쪽만 충돌을 소유합니다.
const LAST_RESOLVED_PHYSICS_FRAME_META: StringName = \
	&"_flipper_last_resolved_physics_frame"


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
