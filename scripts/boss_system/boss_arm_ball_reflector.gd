class_name BossArmBallReflector
extends Node


signal ball_reflected(ball: Pinball)


var _rules: BossArmBallReflectionRules = null
var _attack: TeddyArmSweepAttack = null


func _exit_tree() -> void:
	unbind_attack()


func configure(rules: BossArmBallReflectionRules) -> bool:
	if rules == null or not is_instance_valid(rules):
		return false
	if not rules.validate().is_empty():
		return false

	_rules = rules
	return true


func bind_attack(attack: TeddyArmSweepAttack) -> bool:
	if attack == null or not is_instance_valid(attack):
		return false

	if attack == _attack:
		_connect_attack_signal()
		return true

	_disconnect_attack_signal()
	_attack = attack
	_connect_attack_signal()
	return true


func unbind_attack() -> void:
	_disconnect_attack_signal()
	_attack = null


func is_bound() -> bool:
	return _attack != null \
		and is_instance_valid(_attack) \
		and _attack.attack_hit.is_connected(_on_attack_hit)


func _on_attack_hit(target: Node) -> void:
	if _rules == null \
			or not is_instance_valid(_rules) \
			or not _rules.validate().is_empty() \
			or not is_bound():
		return
	if target == null \
			or not is_instance_valid(target) \
			or not target is Pinball \
			or not target.is_inside_tree() \
			or not target.is_in_group(Pinball.PINBALL_GROUP):
		return

	var ball: Pinball = target as Pinball
	var side: float = _infer_outward_side(ball)
	var direction := Vector2(
		side * _rules.outward_ratio,
		_rules.downward_ratio
	).normalized()
	var target_velocity: Vector2 = ball.get_limited_velocity(
		direction * _rules.reflection_speed
	)
	var velocity_change: Vector2 = target_velocity - ball.linear_velocity
	ball.sleeping = false
	if not velocity_change.is_zero_approx():
		ball.apply_central_impulse(velocity_change * ball.mass)
		ball_reflected.emit(ball)


func _infer_outward_side(ball: Pinball) -> float:
	var overlaps_left: bool = _area_overlaps_ball(_attack.left_hit_area, ball)
	var overlaps_right: bool = _area_overlaps_ball(_attack.right_hit_area, ball)
	if overlaps_left != overlaps_right:
		return -1.0 if overlaps_left else 1.0

	var horizontal_offset: float = ball.global_position.x - _attack.global_position.x
	if horizontal_offset < 0.0:
		return -1.0
	if horizontal_offset > 0.0:
		return 1.0
	if ball.linear_velocity.x < 0.0:
		return -1.0
	if ball.linear_velocity.x > 0.0:
		return 1.0

	var left_distance: float = _horizontal_distance_to_area(
		_attack.left_hit_area,
		ball
	)
	var right_distance: float = _horizontal_distance_to_area(
		_attack.right_hit_area,
		ball
	)
	return -1.0 if left_distance <= right_distance else 1.0


func _area_overlaps_ball(area: Area2D, ball: Pinball) -> bool:
	return is_instance_valid(area) \
		and area.is_inside_tree() \
		and area.overlaps_body(ball)


func _horizontal_distance_to_area(area: Area2D, ball: Pinball) -> float:
	if not is_instance_valid(area) or not area.is_inside_tree():
		return INF
	return absf(ball.global_position.x - area.global_position.x)


func _connect_attack_signal() -> void:
	if is_instance_valid(_attack) \
			and not _attack.attack_hit.is_connected(_on_attack_hit):
		_attack.attack_hit.connect(_on_attack_hit)


func _disconnect_attack_signal() -> void:
	if is_instance_valid(_attack) \
			and _attack.attack_hit.is_connected(_on_attack_hit):
		_attack.attack_hit.disconnect(_on_attack_hit)
