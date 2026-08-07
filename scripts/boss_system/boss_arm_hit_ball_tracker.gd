class_name BossArmHitBallTracker
extends Node


class TrackedBallEntry extends RefCounted:
	var ball: Pinball
	var remaining_time_sec: float
	var tree_exited_callback: Callable


var _tracking_duration_sec: float = 0.0
var _is_configured: bool = false
var _attack: TeddyArmSweepAttack = null
var _tracked_balls: Dictionary[int, TrackedBallEntry] = {}


func _exit_tree() -> void:
	unbind_attack()


func configure(tracking_duration_sec: float) -> bool:
	if not is_finite(tracking_duration_sec) or tracking_duration_sec <= 0.0:
		return false

	_tracking_duration_sec = tracking_duration_sec
	_is_configured = true
	return true


func bind_attack(attack: TeddyArmSweepAttack) -> bool:
	if attack == null or not is_instance_valid(attack):
		return false

	if attack == _attack:
		_connect_attack_signal()
		return true

	_disconnect_attack_signal()
	clear()
	_attack = attack
	_connect_attack_signal()
	return true


func unbind_attack() -> void:
	_disconnect_attack_signal()
	_attack = null
	clear()


func is_bound() -> bool:
	return _attack != null \
		and is_instance_valid(_attack) \
		and _attack.attack_hit.is_connected(_on_attack_hit)


func is_ball_tracked(ball: Pinball) -> bool:
	if ball == null or not is_instance_valid(ball):
		return false

	var ball_id: int = ball.get_instance_id()
	var entry: TrackedBallEntry = _tracked_balls.get(ball_id)
	return entry != null \
		and is_instance_valid(entry.ball) \
		and entry.ball == ball \
		and entry.remaining_time_sec > 0.0


func consume_ball(ball: Pinball) -> bool:
	if not is_ball_tracked(ball):
		return false

	_remove_tracked_ball(ball.get_instance_id())
	return true


func clear() -> void:
	var tracked_ids: Array[int] = []
	tracked_ids.assign(_tracked_balls.keys())
	for ball_id: int in tracked_ids:
		_remove_tracked_ball(ball_id)


func get_remaining_time_sec(ball: Pinball) -> float:
	if not is_ball_tracked(ball):
		return 0.0

	var entry: TrackedBallEntry = _tracked_balls.get(ball.get_instance_id())
	return entry.remaining_time_sec


func _process(delta: float) -> void:
	var expired_ids: Array[int] = []
	for ball_id: int in _tracked_balls:
		var entry: TrackedBallEntry = _tracked_balls[ball_id]
		if not is_instance_valid(entry.ball) \
				or not entry.ball.is_inside_tree():
			expired_ids.append(ball_id)
			continue

		entry.remaining_time_sec -= maxf(delta, 0.0)
		if entry.remaining_time_sec <= 0.0:
			expired_ids.append(ball_id)

	for ball_id: int in expired_ids:
		_remove_tracked_ball(ball_id)


func _on_attack_hit(target: Node) -> void:
	if not _is_configured \
			or target == null \
			or not is_instance_valid(target) \
			or not target is Pinball \
			or not target.is_inside_tree() \
			or not target.is_in_group(Pinball.PINBALL_GROUP):
		return

	var ball := target as Pinball
	var ball_id: int = ball.get_instance_id()
	var existing_entry: TrackedBallEntry = _tracked_balls.get(ball_id)
	if existing_entry != null and existing_entry.ball == ball:
		existing_entry.remaining_time_sec = _tracking_duration_sec
		return

	if existing_entry != null:
		_remove_tracked_ball(ball_id)

	var entry := TrackedBallEntry.new()
	entry.ball = ball
	entry.remaining_time_sec = _tracking_duration_sec
	entry.tree_exited_callback = _on_tracked_ball_tree_exited.bind(ball_id)
	_tracked_balls[ball_id] = entry
	if not ball.tree_exited.is_connected(entry.tree_exited_callback):
		ball.tree_exited.connect(entry.tree_exited_callback)


func _on_tracked_ball_tree_exited(ball_id: int) -> void:
	_remove_tracked_ball(ball_id)


func _remove_tracked_ball(ball_id: int) -> void:
	var entry: TrackedBallEntry = _tracked_balls.get(ball_id)
	if entry == null:
		return

	if is_instance_valid(entry.ball) \
			and entry.ball.tree_exited.is_connected(entry.tree_exited_callback):
		entry.ball.tree_exited.disconnect(entry.tree_exited_callback)
	_tracked_balls.erase(ball_id)


func _connect_attack_signal() -> void:
	if is_instance_valid(_attack) \
			and not _attack.attack_hit.is_connected(_on_attack_hit):
		_attack.attack_hit.connect(_on_attack_hit)


func _disconnect_attack_signal() -> void:
	if is_instance_valid(_attack) \
			and _attack.attack_hit.is_connected(_on_attack_hit):
		_attack.attack_hit.disconnect(_on_attack_hit)
