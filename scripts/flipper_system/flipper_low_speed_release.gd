class_name PinballFlipperLowSpeedRelease
extends PinballFlipper


## 대기 플리퍼와 벽의 이음부에서 공이 저속으로 끼었을 때만 제한적으로 분리합니다.
## 일반 접촉과 고속 충돌은 부모의 연속 충돌 검사에 그대로 맡깁니다.

const LOW_SPEED_RELEASE_THRESHOLD := 120.0
const MINIMUM_RELEASE_NORMAL_SPEED := 100.0
const MAXIMUM_RELEASE_SPEED_CHANGE := 140.0
const CONTACT_RELEASE_CLEARANCE := 16.0
const MAX_RELEASES_PER_CONTACT := 2


var _contact_release_counts: Dictionary[int, int] = {}


func resolve_body_motion_sweep(
	previous_rotation: float,
	target_rotation: float,
	delta: float,
	state_type: int = -1
) -> int:
	var resolved_count := super(
		previous_rotation,
		target_rotation,
		delta,
		state_type
	)
	var collision_state_type := (
		get_current_state_type()
		if state_type < 0
		else state_type
	)
	if collision_state_type != FlipperStateClass.Type.IDLE:
		_contact_release_counts.clear()
		return resolved_count

	return resolved_count + _release_stalled_idle_contacts(target_rotation)


func _release_stalled_idle_contacts(test_rotation: float) -> int:
	if not is_inside_tree():
		return 0

	var active_contact_ids: Dictionary[int, bool] = {}
	var release_count := 0
	for candidate: Node in get_tree().get_nodes_in_group(PINBALL_GROUP):
		if not candidate is RigidBody2D:
			continue
		var ball := candidate as RigidBody2D
		var nearby_contact := _get_current_ball_contact(
			ball,
			test_rotation,
			CONTACT_RELEASE_CLEARANCE
		)
		if nearby_contact.is_empty():
			continue

		var ball_id := int(ball.get_instance_id())
		active_contact_ids[ball_id] = true
		var contact := _get_current_ball_contact(ball, test_rotation)
		if contact.is_empty():
			continue
		if (
			_contact_release_counts.get(ball_id, 0) >= MAX_RELEASES_PER_CONTACT
			or ball.linear_velocity.length() > LOW_SPEED_RELEASE_THRESHOLD
		):
			continue

		var normal: Vector2 = contact.get(&"normal", Vector2.ZERO)
		normal = normal.normalized()
		if normal.is_zero_approx():
			continue
		var normal_speed := ball.linear_velocity.dot(normal)
		var required_speed_change := MINIMUM_RELEASE_NORMAL_SPEED - normal_speed
		if required_speed_change <= 0.0:
			continue
		required_speed_change = minf(
			required_speed_change,
			MAXIMUM_RELEASE_SPEED_CHANGE
		)
		var previous_release_count: int = _contact_release_counts.get(
			ball_id,
			0
		)
		_contact_release_counts[ball_id] = previous_release_count + 1
		ball.sleeping = false
		ball.apply_central_impulse(
			normal * required_speed_change * ball.mass
		)
		release_count += 1

	for tracked_id: int in _contact_release_counts.keys():
		if not active_contact_ids.has(tracked_id):
			_contact_release_counts.erase(tracked_id)
	return release_count


func _get_current_ball_contact(
	ball: RigidBody2D,
	test_rotation: float,
	radius_addition: float = 0.0
) -> Dictionary:
	var ball_collision := ball.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if ball_collision == null or not ball_collision.shape is CircleShape2D:
		return {}
	var circle := ball_collision.shape as CircleShape2D
	var collision_scale := ball_collision.global_scale.abs()
	var radius := (
		circle.radius * maxf(collision_scale.x, collision_scale.y)
		+ maxf(radius_addition, 0.0)
	)
	return find_body_motion_sweep_hit(
		ball_collision.global_position,
		radius,
		Vector2.ZERO,
		test_rotation,
		test_rotation,
		true
	)
